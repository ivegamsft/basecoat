const { createHash } = require('node:crypto');

// This is notification deduplication, not an authorization decision. All
// evidence is re-evaluated by the unchanged trusted executor before delivery.
async function recoveryEvidence({ github, owner, repo, pr, defaultBranch, selectedPack }) {
  const eligibilityContext = 'BaseCoat merge eligibility';
  const statuses = [];
  let complete = false;
  for (let page = 1; page <= 3; page += 1) {
    const { data } = await github.rest.repos.listCommitStatusesForRef({
      owner, repo, ref: pr.head.sha, per_page: 100, page
    });
    statuses.push(...data);
    // Reserve at least 800 of GitHub's 1,000 per-SHA/context status slots
    // for genuine event-driven evidence changes and final delivery.
    if (statuses.filter(status => status.context === eligibilityContext).length >= 198) return null;
    if (data.length < 100) { complete = true; break; }
  }
  if (!complete) return null;
  const eligibility = statuses.filter(status => status.context === eligibilityContext);
  const attempts = new Set(eligibility.filter(status =>
    status.creator?.login === 'github-actions[bot]' &&
    /[?&]recovery_evidence=[0-9a-f]{64}(?:&|$)/.test(status.target_url || '')
  ).map(status => status.target_url));
  if (attempts.size >= 50) return null;
  const latest = eligibility[0];
  if (latest && Date.now() - Date.parse(latest.created_at) < 30 * 60 * 1000) return null;
  const bounded = async (endpoint, args) => {
    const { data } = await endpoint({ owner, repo, ...args, per_page: 100, page: 1 });
    const entries = Array.isArray(data) ? data : data.check_runs;
    return Array.isArray(entries) && entries.length < 100 ? entries : null;
  };
  const reviews = await bounded(github.rest.pulls.listReviews, { pull_number: pr.number });
  const comments = await bounded(github.rest.issues.listComments, { issue_number: pr.number });
  const checks = [];
  for (const ref of new Set([pr.head.sha, pr.merge_commit_sha].filter(Boolean))) {
    const runs = await bounded(github.rest.checks.listForRef, { ref });
    if (!runs) return null;
    checks.push([ref, runs]);
  }
  if (!reviews || !comments) return null;
  const issueNumbers = [...new Set([...`${pr.title || ''}\n${pr.body || ''}`.matchAll(/#(\d+)\b/g)]
    .map(match => Number(match[1])))];
  if (issueNumbers.length > 10) return null;
  const issues = [];
  for (const issue_number of issueNumbers.sort((a, b) => a - b)) {
    const { data: issue } = await github.rest.issues.get({ owner, repo, issue_number });
    const issueComments = await bounded(github.rest.issues.listComments, { issue_number });
    if (!issueComments) return null;
    issues.push([issue, issueComments]);
  }
  const { data: branch } = await github.rest.repos.getBranch({ owner, repo, branch: defaultBranch });
  // Ignore our own eligibility statuses and reporting comments: they are
  // effects of evaluation, not new approval/spec/check evidence.
  const evidenceComments = entries => entries.filter(comment =>
    !(comment.user?.login === 'github-actions[bot]' &&
      /<!-- pr-auto-merge-(?:executor|head):v1/.test(comment.body || '')));
  const fingerprint = createHash('sha256').update(JSON.stringify({
    selectedPack, trustedMain: branch.commit.sha,
    head: pr.head.sha, base: pr.base, title: pr.title, body: pr.body,
    state: pr.state, draft: pr.draft, labels: pr.labels, mergeable_state: pr.mergeable_state,
    changed_files: pr.changed_files, additions: pr.additions, deletions: pr.deletions,
    reviews, comments: evidenceComments(comments), checks,
    statuses: statuses.filter(status => status.context !== eligibilityContext),
    issues: issues.map(([issue, entries]) => [issue, evidenceComments(entries)])
  })).digest('hex');
  if (eligibility.some(status => status.creator?.login === 'github-actions[bot]' &&
    (status.target_url || '').includes(`recovery_evidence=${fingerprint}`))) return null;
  return fingerprint;
}

module.exports = { recoveryEvidence };
