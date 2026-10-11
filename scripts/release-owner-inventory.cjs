#!/usr/bin/env node
'use strict';

// Read-only release-window inventory collector (#3594 report-only rollout).
// It reads local git history and GitHub API data and prints the derived
// report. It never writes refs, tags, releases, or GitHub state.

const { execFileSync } = require('node:child_process');
const { deriveWindowReport, parseReceipt, selectBaseline } = require('./release-owner-report.cjs');

const SEMVER_TAG = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const RECEIPT_PATH = /^receipts\/([1-9]\d*)\/([0-9a-f]{40})\/([0-9a-f]{64})$/;
const SEARCH_LIMIT = 1000;
const SEARCH_QUERY = `query($q:String!,$after:String){search(query:$q,type:ISSUE,first:100,after:$after){
issueCount pageInfo{hasNextPage endCursor} nodes{...on PullRequest{number mergedAt headRefOid mergeCommit{oid}}}}}`;

// Lines from `git for-each-ref --format=name TAB type TAB object TAB *type TAB *object`.
function parseTagRefs(text) {
  return text.split('\n').filter(Boolean).flatMap(line => {
    const [name, type, object, peeledType, peeled] = line.split('\t');
    if (type === 'commit') return [{ name, sha: object }];
    if (type === 'tag' && peeledType === 'commit') return [{ name, sha: peeled }];
    return [];
  });
}

function groupReceiptBlobs(blobs) {
  if (blobs === null) return {};
  const receipts = {};
  for (const { path, text } of blobs) {
    const match = RECEIPT_PATH.exec(path);
    if (!match) return [];
    let headMatches = true;
    try {
      headMatches = parseReceipt(text).head === match[2];
    } catch {
      // Malformed text keeps its stored value so the report records receipt-malformed.
    }
    (receipts[match[1]] ||= []).push({ text: headMatches ? text : null, digest: match[3] });
  }
  return receipts;
}

// Pure: search PRs carry a git `position` of window, before-baseline,
// after-candidate, or anomaly. Anomalies stay in the API set so reconciliation blocks.
function assembleInventory(raw) {
  const kept = (raw.searchPulls || []).filter(pr => pr.position === 'window' || pr.position === 'anomaly');
  return {
    repositoryId: raw.repositoryId,
    tags: raw.tags,
    candidateSha: raw.candidateSha,
    candidateTreeSha: raw.candidateTreeSha,
    baselineIsAncestor: raw.baselineIsAncestor,
    inventoryComplete: raw.searchComplete === true && Array.isArray(raw.windowCommits),
    pullRequests: kept.map(({ number, mergeSha, headSha }) => ({ number, mergeSha, headSha })),
    reachableMergeShas: raw.windowCommits,
    receipts: groupReceiptBlobs(raw.receiptBlobs)
  };
}

function git(args, cwd) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

function gitSucceeds(args, cwd) {
  try {
    execFileSync('git', args, { cwd, stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function ghJson(args) {
  return JSON.parse(execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }));
}

function ghSearchPage(q, after) {
  const args = ['api', 'graphql', '-f', `query=${SEARCH_QUERY}`, '-f', `q=${q}`];
  if (after) args.push('-f', `after=${after}`);
  return ghJson(args).data.search;
}

// Complete only when every page was read and the total fits under the search cap.
function searchMergedPulls(repo, base, since, fetchPage = ghSearchPage) {
  const q = `repo:${repo} is:pr is:merged base:${base} merged:>=${since}`;
  const pulls = [];
  let after = null;
  let total = 0;
  for (;;) {
    const search = fetchPage(q, after);
    total = search.issueCount;
    for (const node of search.nodes) {
      pulls.push({
        number: node.number, mergedAt: node.mergedAt, headSha: node.headRefOid,
        mergeSha: node.mergeCommit && node.mergeCommit.oid
      });
    }
    if (!search.pageInfo.hasNextPage) break;
    const next = search.pageInfo.endCursor;
    if (!next || next === after) return { pulls, complete: false };
    after = next;
  }
  return { pulls, complete: total <= SEARCH_LIMIT && pulls.length === total };
}

function readReceiptBlobs(remote, cwd) {
  const line = git(['ls-remote', '--heads', remote, 'release-receipts'], cwd);
  if (!line) return null;
  const sha = line.split('\t')[0];
  git(['fetch', '--quiet', '--no-tags', remote, 'refs/heads/release-receipts'], cwd);
  return git(['ls-tree', '-r', '--full-tree', sha], cwd).split('\n').filter(Boolean).map(entry => {
    const [meta, path] = entry.split('\t');
    // Read blob bytes verbatim; trimming would hide digest mismatches.
    const text = execFileSync('git', ['cat-file', 'blob', meta.split(' ')[2]], {
      cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']
    });
    return { path, text };
  });
}

function collect({ repo, base = 'main', candidateRef = `origin/${base}`, remote = 'origin', cwd = process.cwd() }) {
  const repositoryId = ghJson(['api', `repos/${repo}`]).id;
  const candidateSha = git(['rev-parse', '--verify', `${candidateRef}^{commit}`], cwd);
  const candidateTreeSha = git(['rev-parse', '--verify', `${candidateSha}^{tree}`], cwd);
  const isAncestor = (sha, of) => gitSucceeds(['merge-base', '--is-ancestor', sha, of], cwd);
  const format = '%(refname:strip=2)%09%(objecttype)%09%(objectname)%09%(*objecttype)%09%(*objectname)';
  // A tag is verified only when it is canonical SemVer and on the candidate history.
  const tags = parseTagRefs(git(['for-each-ref', 'refs/tags', `--format=${format}`], cwd))
    .map(tag => ({ ...tag, verified: SEMVER_TAG.test(tag.name) && isAncestor(tag.sha, candidateSha) }));
  const baseline = selectBaseline(tags);
  const raw = { repositoryId, tags, candidateSha, candidateTreeSha, receiptBlobs: readReceiptBlobs(remote, cwd) };
  if (!baseline) return { baseline, raw };

  raw.baselineIsAncestor = isAncestor(baseline.sha, candidateSha);
  raw.windowCommits = git(['rev-list', '--first-parent', `${baseline.sha}..${candidateSha}`], cwd)
    .split('\n').filter(Boolean);
  const window = new Set(raw.windowCommits);
  const candidateTime = Date.parse(git(['show', '-s', '--format=%cI', candidateSha], cwd));
  const baselineTime = Date.parse(git(['show', '-s', '--format=%cI', baseline.sha], cwd));
  const since = new Date(baselineTime - 86400000).toISOString().slice(0, 10);
  const search = searchMergedPulls(repo, base, since);
  raw.searchComplete = search.complete;
  raw.searchPulls = search.pulls.map(pr => {
    let position = 'anomaly';
    if (window.has(pr.mergeSha)) position = 'window';
    else if (pr.mergeSha && isAncestor(pr.mergeSha, baseline.sha)) position = 'before-baseline';
    else if (Date.parse(pr.mergedAt) > candidateTime && !(pr.mergeSha && isAncestor(pr.mergeSha, candidateSha))) {
      position = 'after-candidate';
    }
    return { ...pr, position };
  });
  return { baseline, raw };
}

function parseArgs(argv) {
  const options = {};
  for (let index = 0; index < argv.length; index += 2) {
    const key = { '--repo': 'repo', '--base': 'base', '--candidate': 'candidateRef', '--remote': 'remote' }[argv[index]];
    if (!key || argv[index + 1] === undefined) throw new Error(`Unknown or incomplete option: ${argv[index]}`);
    options[key] = argv[index + 1];
  }
  if (!options.repo) throw new Error('--repo owner/name is required.');
  return options;
}

if (require.main === module) {
  try {
    const { baseline, raw } = collect(parseArgs(process.argv.slice(2)));
    const report = deriveWindowReport(assembleInventory(raw));
    const positions = {};
    for (const pr of raw.searchPulls || []) positions[pr.position] = (positions[pr.position] || 0) + 1;
    console.log(JSON.stringify({
      collected: {
        baseline, windowCommits: (raw.windowCommits || []).length, searchComplete: raw.searchComplete === true,
        searchPositions: positions, receiptRef: raw.receiptBlobs === null ? 'absent' : 'present'
      },
      report
    }, null, 2));
  } catch (error) {
    console.error(`release-owner inventory failed: ${error.message}`);
    process.exit(2);
  }
}

module.exports = { assembleInventory, groupReceiptBlobs, parseTagRefs, searchMergedPulls };
