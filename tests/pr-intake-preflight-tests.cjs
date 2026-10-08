'use strict';

const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const {
  collectChangeSet,
  parseNameStatus,
  parseNumstat,
  validateBody
} = require('../scripts/validate-pr-intake-preflight.cjs');

function git(cwd, ...args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' }).trim();
}

function makeRepository() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'basecoat-intake-preflight-'));
  git(directory, 'init', '-q');
  git(directory, 'config', 'user.name', 'Test');
  git(directory, 'config', 'user.email', 'test@example.invalid');
  fs.writeFileSync(path.join(directory, 'README.md'), 'base\n');
  git(directory, 'add', 'README.md');
  git(directory, 'commit', '-qm', 'base');
  const base = git(directory, 'rev-parse', 'HEAD');
  fs.writeFileSync(path.join(directory, 'README.md'), 'base\nchange\n');
  fs.writeFileSync(path.join(directory, 'new.txt'), 'new\n');
  git(directory, 'add', 'README.md', 'new.txt');
  git(directory, 'commit', '-qm', 'change');
  return { directory, base, head: git(directory, 'rev-parse', 'HEAD') };
}

function body({
  scope = 'individual',
  issues = '#3662',
  files = 2,
  lines = 2,
  units = 1,
  unitInventory = 'intake preflight',
  rationale = 'One shared preflight validates each generated delivery PR before publication.'
} = {}) {
  return [
    '## Intake Contract',
    '',
    '### Design',
    '',
    '| Order of work | Files that change | Planned change / acceptance |',
    '|---|---|---|',
    '| 1 | scripts and workflows | Validate generated PR metadata before create/edit. |',
    '',
    `Change scope: ${scope}`,
    `Source issues: ${issues}`,
    `Independently deliverable units: ${units}`,
    `Unit inventory: ${unitInventory}`,
    `Expected files: ${files}`,
    `Expected changed lines (additions + deletions): ${lines}`,
    `Classification rationale: ${rationale}`,
    'Mechanical batch exception evidence: none',
    '',
    '### Derived Classification'
  ].join('\n');
}

test('reads exact Git inventory and validates a current individual PR body', async () => {
  const repo = makeRepository();
  const changeSet = collectChangeSet(repo.base, repo.head, args =>
    execFileSync('git', args, { cwd: repo.directory, encoding: 'utf8' })
  );
  assert.equal(changeSet.changedFiles, 2);
  assert.equal(changeSet.additions + changeSet.deletions, 2);
  const result = await validateBody(body(), changeSet);
  assert.equal(result.decision, 'pass');
  fs.rmSync(repo.directory, { recursive: true, force: true });
});

test('rejects body counts that differ from the current diff', async () => {
  const changeSet = {
    files: [{ filename: 'README.md', status: 'modified' }],
    changedFiles: 1,
    additions: 1,
    deletions: 0,
    baseSha: 'a'.repeat(40),
    headSha: 'b'.repeat(40)
  };
  await assert.rejects(
    validateBody(body({ files: 2, lines: 1 }), changeSet),
    /body reports 2 files\/1 lines; diff has 1 files\/1 lines/
  );
});

test('rejects unsupported scope values such as the observed single alias', async () => {
  const changeSet = {
    files: [{ filename: 'README.md', status: 'modified' }],
    changedFiles: 1,
    additions: 1,
    deletions: 0,
    baseSha: 'a'.repeat(40),
    headSha: 'b'.repeat(40)
  };
  await assert.rejects(
    validateBody(body({ scope: 'single', files: 1, lines: 1 }), changeSet),
    /'Change scope' must be 'individual' or 'batch'/
  );
});

test('uses the shared decomposition evaluator to reject over-limit unapproved batches', async () => {
  const changeSet = {
    files: Array.from({ length: 16 }, (_, index) => ({
      filename: `docs/${index}.md`,
      status: 'modified'
    })),
    changedFiles: 16,
    additions: 1,
    deletions: 0,
    baseSha: 'a'.repeat(40),
    headSha: 'b'.repeat(40)
  };
  await assert.rejects(
    validateBody(body({
      scope: 'batch',
      files: 16,
      lines: 1,
      units: 2,
      unitInventory: 'unit A; unit B'
    }), changeSet),
    /Batch exceeds the limits/
  );
});

test('parses rename inventories and binary numstat records', () => {
  assert.deepEqual(
    parseNameStatus('R100\0old.md\0new.md\0'),
    [{ filename: 'new.md', previous_filename: 'old.md', status: 'renamed' }]
  );
  assert.deepEqual(
    parseNumstat('-\t-\timage.png\0'),
    { additions: 0, deletions: 0, records: 1 }
  );
});

test('runs before every generated delivery PR create or edit', () => {
  const root = path.resolve(__dirname, '..');
  for (const workflow of [
    '.github/workflows/dependency-graph-pages.yml',
    '.github/workflows/model-capability-refresh.yml',
    '.github/workflows/release-changelog-generation.yml',
    '.github/workflows/token-inventory.yml'
  ]) {
    const contents = fs.readFileSync(path.join(root, workflow), 'utf8');
    const preflight = contents.indexOf('scripts/validate-pr-intake-preflight.cjs');
    assert.notEqual(preflight, -1, `${workflow} must run the shared preflight`);
    for (const command of ['gh pr create', 'gh pr edit']) {
      const mutation = contents.indexOf(command, preflight);
      const earlierMutation = contents.indexOf(command);
      assert.ok(
        mutation === -1 || earlierMutation === mutation,
        `${workflow} must run the preflight before ${command}`
      );
    }
  }
});

test('synthesized draft PRs use the trusted template and pass evaluator before creation', () => {
  const workflow = fs.readFileSync(
    path.resolve(__dirname, '..', '.github/workflows/issue-to-spec-synthesis.yml'),
    'utf8'
  );
  const preflight = workflow.indexOf('preflight.decision !== \'pass\'');
  const create = workflow.indexOf('writeGithub.rest.pulls.create');
  assert.notEqual(preflight, -1);
  assert.ok(create > preflight, 'the GitHub PR create API must follow successful preflight');
  assert.match(workflow, /path:\s*'\.github\/PULL_REQUEST_TEMPLATE\.md'[\s\S]*?ref:\s*baseSha/);
  assert.match(workflow, /path:\s*'\.github\/base-coat\/scripts\/pr-decomposition-evaluator\.cjs'[\s\S]*?ref:\s*baseSha/);
  assert.match(workflow, /compareCommits\(\{[\s\S]*?base:\s*baseSha,[\s\S]*?head:\s*branchRef\.data\.object\.sha/);
  assert.match(workflow, /currentMain\.data\.object\.sha !== baseSha/);
});
