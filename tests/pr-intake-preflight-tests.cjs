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
const { checkBody } = require('../scripts/check-pr-intake-metadata.cjs');

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

test('author-time check names every invalid template field with its expected format', () => {
  const template = fs.readFileSync(path.resolve(__dirname, '..', '.github/PULL_REQUEST_TEMPLATE.md'), 'utf8');
  const result = checkBody(template);
  assert.equal(result.ok, false);
  assert.deepEqual(result.errors.map(error => error.field), [
    'Change scope',
    'Source issues',
    'Independently deliverable units',
    'Unit inventory',
    'Expected files',
    'Expected changed lines (additions + deletions)',
    'Classification rationale'
  ]);
  assert.ok(result.errors.every(error => error.format.startsWith(`${error.field}: `)));
});

test('author-time check rejects approximate counts and accepts plain integers', () => {
  const approximate = checkBody(body({ lines: '~250' }));
  assert.equal(approximate.ok, false);
  assert.equal(approximate.errors.length, 1);
  assert.equal(approximate.errors[0].field, 'Expected changed lines (additions + deletions)');
  assert.match(approximate.errors[0].format, /plain integer/);

  const valid = checkBody(body(), { changedFiles: 2, additions: 1, deletions: 1 });
  assert.equal(valid.ok, true);
  assert.deepEqual(valid.warnings, []);

  const stale = checkBody(body(), { changedFiles: 3, additions: 5, deletions: 0 });
  assert.equal(stale.ok, true);
  assert.equal(stale.warnings.length, 2);
});

test('author-time check keeps scope relationships intact while collecting every bad field', () => {
  const batch = checkBody(body({
    scope: 'batch',
    units: 'TBD',
    unitInventory: 'unit A; unit B',
    files: 'TBD',
    lines: '~250',
    rationale: 'TBD'
  }));
  assert.deepEqual(batch.errors.map(error => error.field), [
    'Independently deliverable units',
    'Expected files',
    'Expected changed lines (additions + deletions)',
    'Classification rationale'
  ]);

  const missing = checkBody(body().replace(/^Expected files: .*$/m, '').replace(/^Classification rationale: .*$/m, 'Classification rationale: TBD'));
  assert.deepEqual(missing.errors.map(error => error.field), ['Expected files', 'Classification rationale']);

  const largeBatch = checkBody(body({ scope: 'batch', units: 101, unitInventory: 'TBD', files: 'TBD' }));
  assert.deepEqual(largeBatch.errors.map(error => error.field), ['Unit inventory', 'Expected files']);

  const contradiction = checkBody(body({
    units: 2,
    unitInventory: 'unit A; unit B',
    files: 'TBD',
    lines: '~250',
    rationale: 'TBD'
  }));
  assert.match(contradiction.errors[0].message, /'individual' scope contradicts/);
  assert.deepEqual(contradiction.errors.slice(1).map(error => error.field), [
    'Expected files',
    'Expected changed lines (additions + deletions)',
    'Classification rationale'
  ]);
});

test('author-time workflow runs on body edits and passes the body only through env', () => {
  const workflow = fs.readFileSync(
    path.resolve(__dirname, '..', '.github/workflows/pr-intake-metadata.yml'),
    'utf8'
  );
  for (const type of ['opened', 'edited', 'synchronize']) {
    assert.match(workflow, new RegExp(`^\\s+- ${type}$`, 'm'));
  }
  assert.doesNotMatch(workflow, /pull_request_target/);
  assert.match(workflow, /^permissions:\s*\n\s+contents: read\s*\n\s*\n/m);
  assert.match(workflow, /PR_BODY: \$\{\{ github\.event\.pull_request\.body \}\}/);
  const runLines = workflow.split('\n').filter(line => /^\s+run:/.test(line));
  assert.deepEqual(runLines.map(line => line.trim()), ['run: node scripts/check-pr-intake-metadata.cjs']);
});