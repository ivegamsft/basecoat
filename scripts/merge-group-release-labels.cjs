'use strict';

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
  commitShas,
  pullRequests
}) => {
  if (!baseRef || !Array.isArray(commitShas) || !Array.isArray(pullRequests)) {
    throw new Error('Merge-group comparison or pull-request data is incomplete.');
  }

  const commits = new Set(commitShas.map(sha => String(sha).toLowerCase()));
  const constituents = pullRequests.filter(pullRequest =>
    pullRequest.state === 'open' &&
    pullRequest.base?.ref === baseRef &&
    commits.has(String(pullRequest.head?.sha || '').toLowerCase())
  );

  if (constituents.length === 0) {
    throw new Error(
      `No open ${baseRef}-targeting pull request has a current head in the merge-group commit range.`
    );
  }

  const distinctNumbers = new Set(constituents.map(pullRequest => pullRequest.number));
  if (distinctNumbers.size !== constituents.length) {
    throw new Error('Merge-group constituent pull-request identities are ambiguous.');
  }

  return constituents;
};

module.exports = {
  evaluatePullRequestLabels,
  isReleaseLabel,
  selectCurrentMergeGroupPullRequests
};
