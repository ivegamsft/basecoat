'use strict';

const { execFileSync } = require('node:child_process');
const isSha = value => /^[0-9a-f]{40}$/i.test(String(value || ''));

const isReleaseLabel = label => {
  const normalized = String(label || '').toLowerCase();
  return /^(wave:|sprint:|wave-|sprint-).+/.test(normalized) ||
    normalized === 'wave/sprint';
};

const evaluatePullRequestLabels = pullRequest => {
  if (!pullRequest || !Array.isArray(pullRequest.labels)) {
    throw new Error('Pull-request label data is incomplete.');
  }

  const labels = pullRequest.labels.map(label =>
    String(typeof label === 'string' ? label : label?.name || '')
  );
  if (labels.some(isReleaseLabel)) {
    return { valid: true, reason: 'release label' };
  }

  const normalized = labels.map(label => label.toLowerCase());
  if (normalized.includes('skip-release-label-gate')) {
    return { valid: true, reason: 'skip-release-label-gate label' };
  }
  if (normalized.includes('dependencies')) {
    return { valid: true, reason: 'dependencies label' };
  }

  return { valid: false, reason: 'missing release label' };
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
  evaluatePullRequestLabels,
  isReleaseLabel,
  selectCurrentMergeGroupPullRequests,
  verifyCurrentSquashMergeTree
};
