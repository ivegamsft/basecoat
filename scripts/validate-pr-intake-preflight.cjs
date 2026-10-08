'use strict';

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const {
  evaluateDecomposition,
  parseScope
} = require('../.github/base-coat/scripts/pr-decomposition-evaluator.cjs');

function runGit(args) {
  return execFileSync('git', args, { encoding: 'utf8' });
}

function parseNameStatus(output) {
  const tokens = output.split('\0');
  const files = [];
  for (let index = 0; index < tokens.length;) {
    const status = tokens[index++];
    if (!status) continue;
    if (/^[RC]/.test(status)) {
      const previousFilename = tokens[index++];
      const filename = tokens[index++];
      if (!previousFilename || !filename) {
        throw new Error('Git returned an incomplete rename/copy inventory.');
      }
      files.push({
        filename,
        previous_filename: previousFilename,
        status: status[0] === 'R' ? 'renamed' : 'copied'
      });
      continue;
    }
    const filename = tokens[index++];
    if (!filename) throw new Error('Git returned an incomplete changed-file inventory.');
    files.push({ filename, status });
  }
  return files;
}

function parseNumstat(output) {
  const tokens = output.split('\0');
  let additions = 0;
  let deletions = 0;
  let records = 0;
  for (let index = 0; index < tokens.length;) {
    const record = tokens[index++];
    if (!record) continue;
    const firstTab = record.indexOf('\t');
    const secondTab = record.indexOf('\t', firstTab + 1);
    if (firstTab < 0 || secondTab < 0) {
      throw new Error('Git returned malformed changed-line statistics.');
    }
    const addedText = record.slice(0, firstTab);
    const deletedText = record.slice(firstTab + 1, secondTab);
    const filename = record.slice(secondTab + 1);
    const added = addedText === '-' ? 0 : Number(addedText);
    const deleted = deletedText === '-' ? 0 : Number(deletedText);
    if (!Number.isSafeInteger(added) || !Number.isSafeInteger(deleted)) {
      throw new Error('Git returned invalid changed-line statistics.');
    }
    additions += added;
    deletions += deleted;
    records += 1;
    if (!filename) {
      const previousFilename = tokens[index++];
      const newFilename = tokens[index++];
      if (!previousFilename || !newFilename) {
        throw new Error('Git returned incomplete rename statistics.');
      }
    }
  }
  return { additions, deletions, records };
}

function collectChangeSet(baseRef, headRef, run = runGit) {
  if (!baseRef || !headRef || baseRef.startsWith('-') || headRef.startsWith('-')) {
    throw new Error('Both base and head Git revisions are required.');
  }
  const range = `${baseRef}...${headRef}`;
  const files = parseNameStatus(run(['diff', '--name-status', '-z', '--find-renames', range]));
  const stats = parseNumstat(run(['diff', '--numstat', '-z', '--find-renames', range]));
  if (files.length !== stats.records) {
    throw new Error('Git file inventory and changed-line statistics do not agree.');
  }
  return {
    files,
    changedFiles: files.length,
    additions: stats.additions,
    deletions: stats.deletions,
    baseSha: run(['rev-parse', baseRef]).trim(),
    headSha: run(['rev-parse', headRef]).trim()
  };
}

async function validateBody(body, changeSet) {
  const scope = parseScope(body);
  const changedLines = changeSet.additions + changeSet.deletions;
  if (
    scope.expectedFiles !== changeSet.changedFiles ||
    scope.expectedLines !== changedLines
  ) {
    throw new Error(
      `Intake counts do not match the current diff: body reports ${scope.expectedFiles} files/${scope.expectedLines} lines; ` +
      `diff has ${changeSet.changedFiles} files/${changedLines} lines.`
    );
  }
  const result = await evaluateDecomposition({
    body,
    ...changeSet,
    reviews: []
  });
  if (result.decision !== 'pass') {
    throw new Error(`PR decomposition preflight ${result.decision}: ${result.reason}`);
  }
  return result;
}

async function main(args) {
  const [bodyPath, baseRef, headRef] = args;
  if (!bodyPath || !baseRef || !headRef || args.length !== 3) {
    throw new Error('Usage: node scripts/validate-pr-intake-preflight.cjs <body-file> <base-ref> <head-ref>');
  }
  const body = fs.readFileSync(path.resolve(bodyPath), 'utf8');
  const changeSet = collectChangeSet(baseRef, headRef);
  const result = await validateBody(body, changeSet);
  process.stdout.write(
    `PR intake preflight passed: ${result.counts.changedFiles} files, ${result.counts.changedLines} changed lines, scope ${result.scope}.\n`
  );
}

if (require.main === module) {
  main(process.argv.slice(2)).catch(error => {
    process.stderr.write(`PR intake preflight failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = { collectChangeSet, parseNameStatus, parseNumstat, validateBody };
