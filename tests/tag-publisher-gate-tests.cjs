'use strict';

// Regression tests for #3843: every tag publisher enforces the shared release
// label policy gate (scripts/release-label-gate.sh) before it publishes.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');

const repoRoot = path.resolve(__dirname, '..');
const workflowDirs = ['.github/workflows', '.github/base-coat/workflows'];
const gateScript = 'scripts/release-label-gate.sh';
const publisherPattern = new RegExp([
  String.raw`\bgh release (create|upload|edit)\b`,
  String.raw`\bgit tag (-[afs]\b|-[a-z]*f)`,
  String.raw`\bgit push\b[^\n]*(refs/tags/|--tags\b)`,
  String.raw`createRef\([^)]*refs/tags/`,
  String.raw`\bgit/refs/tags\b`,
  String.raw`\b(createRelease|uploadReleaseAsset|createTag)\(`
].join('|'));
const knownPublishers = [
  '.github/workflows/package-basecoat.yml#release',
  '.github/workflows/publish-to-production.yml#publish',
  '.github/workflows/release.yml#release'
];

const splitJobs = text => {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex(line => /^jobs:\s*$/.test(line));
  if (start < 0) return [];
  const jobs = [];
  for (const line of lines.slice(start + 1)) {
    const header = /^ {2}([A-Za-z0-9_-]+):\s*$/.exec(line);
    if (header) jobs.push({ name: header[1], lines: [] });
    else if (/^\S/.test(line)) break;
    else if (jobs.length) jobs[jobs.length - 1].lines.push(line);
  }
  return jobs;
};

const findPublisherJobs = () => {
  const found = [];
  for (const dir of workflowDirs) {
    const absolute = path.join(repoRoot, dir);
    if (!fs.existsSync(absolute)) continue;
    for (const file of fs.readdirSync(absolute).filter(name => /\.ya?ml$/.test(name)).sort()) {
      const text = fs.readFileSync(path.join(absolute, file), 'utf8');
      for (const job of splitJobs(text)) {
        const publishIndex = job.lines.findIndex(line => publisherPattern.test(line) && !/^\s*#/.test(line));
        if (publishIndex < 0) continue;
        found.push({ id: `${dir}/${file}#${job.name}`, job, publishIndex });
      }
    }
  }
  return found;
};

test('known tag publishers are detected so the gate check cannot pass vacuously', () => {
  const ids = findPublisherJobs().map(publisher => publisher.id);
  for (const id of knownPublishers) assert.ok(ids.includes(id), `${id} not detected as a tag publisher`);
});

test('every tag publisher job runs the release label policy gate before publishing', () => {
  for (const { id, job, publishIndex } of findPublisherJobs()) {
    const gateIndex = job.lines.findIndex(line => line.includes(`bash ${gateScript} `));
    assert.ok(gateIndex >= 0, `${id} publishes tags or releases without calling ${gateScript}`);
    assert.ok(gateIndex < publishIndex, `${id} must call ${gateScript} before its first publish command`);
    const body = job.lines.join('\n');
    assert.match(body, /GH_TOKEN: \$\{\{ github\.token \}\}/, `${id} gate needs GH_TOKEN to read PR labels`);
    assert.doesNotMatch(body, /release-label-gate\.sh[^\n]*\|\|\s*true/, `${id} must not suppress gate failures`);
  }
});

test('gate delegates to the shared #3829 classifier and creates no refs', () => {
  const script = fs.readFileSync(path.join(repoRoot, gateScript), 'utf8');
  assert.match(script, /merge-group-release-labels\.cjs" release-coverage/);
  assert.doesNotMatch(script, /git (push|tag -|update-ref)|gh release (create|upload|edit)|gh api/);
});

const bashAvailable = spawnSync('bash', ['--version']).status === 0;

const runGate = (cwd, tag, env = {}) => spawnSync('bash', [path.join(repoRoot, gateScript), 'test-publisher', tag, 'out.json'], {
  cwd,
  encoding: 'utf8',
  env: { ...process.env, GITHUB_OUTPUT: '', EXPECTED_TAG_SHA: '', ...env }
});

const makeRepo = tags => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'release-label-gate-'));
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' }).trim();
  git('init', '-q');
  git('-c', 'user.name=t', '-c', 'user.email=t@example.com', 'commit', '-q', '--allow-empty', '-m', 'init');
  for (const tag of tags) git('tag', tag);
  return { dir, sha: git('rev-parse', 'HEAD') };
};

test('gate fails closed on malformed, missing or moved tags', { skip: !bashAvailable }, () => {
  const { dir, sha } = makeRepo(['v1.0.0']);
  try {
    for (const [tag, env, reason] of [
      ['main', {}, /not a release semver tag/],
      ['v9.9.9', {}, /not present locally/],
      ['v1.0.0', { EXPECTED_TAG_SHA: '0'.repeat(40) }, /this run is bound to/]
    ]) {
      const result = runGate(dir, tag, env);
      assert.equal(result.status, 1, `${tag} should fail closed`);
      assert.match(result.stdout, reason);
      assert.match(result.stdout, /test-publisher will not publish/);
    }
    const first = runGate(dir, 'v1.0.0', { EXPECTED_TAG_SHA: sha });
    assert.equal(first.status, 0, first.stdout + first.stderr);
    assert.match(first.stdout, /No previous semver tag found/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
