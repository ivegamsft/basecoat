'use strict';

const { execFileSync } = require('node:child_process');
const isSha = value => /^[0-9a-f]{40}$/i.test(String(value || ''));

const isReleaseLabel = label => {
  const normalized = String(label || '').toLowerCase();
  return /^(wave:|sprint:|wave-|sprint-).+/.test(normalized) ||
    normalized === 'wave/sprint';
};

const RELEASE_COVERAGE_POLICY_VERSION = '1';
const MAX_UNCOVERED_PERCENT = 10;
// Ordered rules: release-label classification wins over exemptions.
const COVERAGE_RULES = [
  ['release-label', isReleaseLabel, 'release label'],
  ['explicit-exemption', label => label.toLowerCase() === 'skip-release-label-gate', 'skip-release-label-gate label'],
  ['dependency-exemption', label => label.toLowerCase() === 'dependencies', 'dependencies label']
];

const normalizeLabelNames = labels => {
  if (!Array.isArray(labels)) throw new Error('Pull-request label data is incomplete.');
  return labels.map(label => {
    const name = typeof label === 'string' ? label : label?.name;
    if (typeof name !== 'string' || !name.trim()) {
      throw new Error('Pull-request label data is incomplete: every label needs a nonempty name.');
    }
    return name;
  });
};

// Single authoritative policy shared by the PR gate, the merge-group gate and
// the release coverage gate. Labels are data; no title, author, fork status or
// body text is an implicit exemption.
const classifyPullRequestLabels = pullRequest => {
  const labels = normalizeLabelNames(pullRequest?.labels);
  for (const [reason, matches] of COVERAGE_RULES) {
    const label = labels.find(matches);
    if (label) return { covered: true, reason, label };
  }
  return { covered: false, reason: 'uncovered', label: null };
};

const evaluatePullRequestLabels = pullRequest => {
  const result = classifyPullRequestLabels(pullRequest);
  const rule = COVERAGE_RULES.find(([reason]) => reason === result.reason);
  return { valid: result.covered, reason: rule ? rule[2] : 'missing release label' };
};

const evaluateReleaseCoverage = pullRequests => {
  if (!Array.isArray(pullRequests)) {
    throw new Error('Release pull-request inventory is incomplete.');
  }
  const seen = new Set();
  const results = pullRequests.map(pullRequest => {
    const number = pullRequest?.number;
    if (!Number.isSafeInteger(number) || number < 1) {
      throw new Error('Release pull-request inventory contains a malformed PR number.');
    }
    if (seen.has(number)) {
      throw new Error(`Release pull-request inventory contains duplicate PR #${number}.`);
    }
    seen.add(number);
    return { number, ...classifyPullRequestLabels(pullRequest) };
  });
  const count = reason => results.filter(result => result.reason === reason).length;
  const total = results.length;
  const uncovered = results.filter(result => !result.covered);
  const status = total === 0 ? 'empty'
    : uncovered.length * 100 > total * MAX_UNCOVERED_PERCENT ? 'fail'
      : uncovered.length > 0 ? 'partial' : 'pass';
  return {
    policyVersion: RELEASE_COVERAGE_POLICY_VERSION,
    status,
    total,
    releaseLabelCovered: count('release-label'),
    exemptCovered: count('explicit-exemption') + count('dependency-exemption'),
    uncovered: uncovered.length,
    uncoveredNumbers: uncovered.map(result => result.number),
    results
  };
};

// Membership comes from the exact first-parent commit range ("<sha>\t<subject>"
// lines): squash merges end with "(#N)", merge commits start with
// "Merge pull request #N". Unassociated commits fail closed.
const parseReleaseCommits = lines => lines.map(line => {
  const [sha, subject = ''] = line.split('\t');
  const match = /\(#(\d+)\)\s*$/.exec(subject) || /^Merge pull request #(\d+)\b/.exec(subject);
  if (!isSha(sha) || !match) {
    throw new Error(`Release range commit ${sha} has no pull-request association: ${subject}`);
  }
  return { sha, number: Number(match[1]) };
});

const runReleaseCoverage = ({ repository, previousTag, tag, runCommand, log }) => {
  const run = runCommand || ((cmd, args) => execFileSync(cmd, args, { encoding: 'utf8' }).trim());
  const write = log || (line => console.log(line));
  if (!/^[\w.-]+\/[\w.-]+$/.test(String(repository || '')) || !previousTag || !tag) {
    throw new Error('Release coverage requires a repository, previous tag and tag.');
  }
  const previousSha = run('git', ['rev-parse', `${previousTag}^{commit}`]);
  const tagSha = run('git', ['rev-parse', `${tag}^{commit}`]);
  if (![previousSha, tagSha].every(isSha)) {
    throw new Error('Release coverage could not resolve immutable tag commits.');
  }
  try {
    run('git', ['merge-base', '--is-ancestor', previousSha, tagSha]);
  } catch {
    throw new Error(`Previous tag ${previousTag} (${previousSha}) is not an ancestor of ${tag} (${tagSha}); release scope is ambiguous.`);
  }
  const rangeLog = run('git', ['log', '--first-parent', '--format=%H%x09%s', `${previousSha}..${tagSha}`]);
  const commits = parseReleaseCommits(rangeLog ? rangeLog.split(/\r?\n/) : []);
  const pullRequests = commits.map(({ sha, number }) => {
    const raw = run('gh', ['api', `repos/${repository}/pulls/${number}`,
      '--jq', '{number: .number, merged: (.merged_at != null), mergeCommitSha: .merge_commit_sha, labels: [.labels[].name]}']);
    const pullRequest = JSON.parse(raw);
    if (pullRequest.number !== number || pullRequest.merged !== true ||
        String(pullRequest.mergeCommitSha).toLowerCase() !== sha.toLowerCase()) {
      throw new Error(`PR #${number} did not produce release range commit ${sha}; refusing unreconciled membership.`);
    }
    return pullRequest;
  });
  const coverage = evaluateReleaseCoverage(pullRequests);
  write(`Release label coverage window: ${previousTag} (${previousSha})..${tag} (${tagSha}); policy version ${coverage.policyVersion}; commits in range: ${commits.length}`);
  write(`Total: ${coverage.total}; release-label covered: ${coverage.releaseLabelCovered}; exempt covered: ${coverage.exemptCovered}; uncovered: ${coverage.uncovered}`);
  coverage.results.slice(0, 30).forEach(result => write(`- PR #${result.number}: ${result.reason}${result.label ? ` (${result.label})` : ''}`));
  if (coverage.results.length > 30) write(`... ${coverage.results.length - 30} more in the JSON inventory`);
  return { previousSha, tagSha, ...coverage };
};

const selectCurrentMergeGroupPullRequests = ({
  baseRef,
  groupHeadSha,
  queueEntries
}) => {
  if (!baseRef || !isSha(groupHeadSha) || !Array.isArray(queueEntries)) {
    throw new Error('Merge-group queue data is incomplete.');
  }

  const entries = queueEntries.filter(entry =>
    String(entry.headCommit?.oid || '').toLowerCase() === groupHeadSha.toLowerCase()
  );
  if (entries.length !== 1) {
    throw new Error('Serialized merge group must resolve to exactly one live queue entry.');
  }
  const entry = entries[0];
  const pullRequest = entry.pullRequest;
  if (entry.state !== 'AWAITING_CHECKS' || pullRequest?.state !== 'OPEN' ||
      pullRequest.baseRefName !== baseRef || !isSha(pullRequest.headRefOid) ||
      !Number.isSafeInteger(pullRequest.number) || pullRequest.number < 1) {
    throw new Error('Merge-group queue entry has stale or incomplete pull-request membership.');
  }
  return [{
    number: pullRequest.number,
    state: 'open',
    base: { ref: pullRequest.baseRefName },
    head: { sha: pullRequest.headRefOid }
  }];
};

const verifyCurrentSquashMergeTree = ({ baseSha, groupHeadSha, pullRequestHeadSha, runGit }) => {
  if (![baseSha, groupHeadSha, pullRequestHeadSha].every(isSha)) {
    throw new Error('Merge-group tree verification requires complete commit SHAs.');
  }
  const git = runGit || (args => execFileSync('git', args, { encoding: 'utf8' }).trim());
  git(['fetch', '--no-tags', 'origin', pullRequestHeadSha]);
  const expectedTree = git(['merge-tree', '--write-tree', baseSha, pullRequestHeadSha]).split(/\r?\n/)[0];
  const groupTree = git(['rev-parse', `${groupHeadSha}^{tree}`]);
  const parents = git(['rev-list', '--parents', '-n', '1', groupHeadSha]).split(/\s+/);
  if (!isSha(expectedTree) || expectedTree !== groupTree ||
      parents.length !== 2 || parents[1] !== baseSha) {
    throw new Error('Generated squash group does not match the current PR head and event base; refusing stale membership.');
  }
};

module.exports = {
  MAX_UNCOVERED_PERCENT,
  RELEASE_COVERAGE_POLICY_VERSION,
  classifyPullRequestLabels,
  evaluatePullRequestLabels,
  evaluateReleaseCoverage,
  isReleaseLabel,
  parseReleaseCommits,
  runReleaseCoverage,
  selectCurrentMergeGroupPullRequests,
  verifyCurrentSquashMergeTree
};

if (require.main === module) {
  const [mode, previousTag, tag, outputFile] = process.argv.slice(2);
  if (mode !== 'release-coverage') {
    console.error('Usage: merge-group-release-labels.cjs release-coverage <previous-tag> <tag> [output.json]');
    process.exit(2);
  }
  try {
    const coverage = runReleaseCoverage({
      repository: process.env.GITHUB_REPOSITORY,
      previousTag,
      tag
    });
    if (outputFile) {
      require('node:fs').writeFileSync(outputFile, `${JSON.stringify(coverage, null, 2)}\n`);
    }
    const detail = `${coverage.uncovered}/${coverage.total} uncovered; uncovered PRs: ${coverage.uncoveredNumbers.map(n => `#${n}`).join(', ') || 'none'}`;
    const messages = {
      empty: '::warning::No merged PRs found in the exact release range; coverage provides no releasable PR evidence.',
      fail: `::error::Release label coverage below threshold (>${MAX_UNCOVERED_PERCENT}%): ${detail}`,
      partial: `::warning::Release label coverage is partial (<=${MAX_UNCOVERED_PERCENT}%): ${detail}`,
      pass: 'Release label coverage gate passed.'
    };
    console.log(messages[coverage.status]);
    if (coverage.status === 'fail') process.exitCode = 1;
  } catch (error) {
    console.log(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
