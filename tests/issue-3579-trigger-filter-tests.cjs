const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const fixture = JSON.parse(fs.readFileSync(
  path.join(__dirname, 'fixtures', 'issue-3579-routing-minutes.json'),
  'utf8'
));

function readWorkflow(file) {
  return fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
}

function jobCondition(workflow, jobName) {
  const jobSection = workflow.split(`  ${jobName}:\n`)[1];
  assert.ok(jobSection, `missing job ${jobName}`);
  const condition = jobSection.match(/^\s+if:\s*(.+)$/m);
  assert.ok(condition, `missing job-level if for ${jobName}`);
  return condition[1].trim();
}

function evaluate(expression, eventName, event = {}) {
  return vm.runInNewContext(expression, {
    github: { event_name: eventName, event }
  });
}

function tokenInventoryPushPaths(workflow) {
  const push = workflow.match(/^  push:\n([\s\S]*?)^  schedule:/m);
  assert.ok(push, 'token inventory must retain its push trigger');
  const paths = push[1].match(/^\s+- '([^']+)'$/gm) || [];
  return paths.map(line => line.match(/'([^']+)'/)[1]);
}

function matchesGitHubPath(pattern, file) {
  const prefix = pattern.endsWith('/**') ? pattern.slice(0, -3) : pattern;
  return file.startsWith(`${prefix}/`);
}

test('Build Guard filters upstream success/cancellation before resolver allocation', () => {
  const files = [
    '.github/workflows/ship-it-build-guard.yml',
    '.github/base-coat/workflows/ship-it-build-guard.yml'
  ];
  const conditions = files.map(file =>
    jobCondition(readWorkflow(file), 'resolve-inputs')
  );
  assert.equal(conditions[0], conditions[1]);
  const condition = conditions[0];

  for (const [eventName, conclusion, expected] of [
    ['workflow_dispatch', null, true],
    ['workflow_run', 'failure', true],
    ['workflow_run', 'success', false],
    ['workflow_run', 'cancelled', false],
    ['workflow_run', null, false],
    ['push', null, false]
  ]) {
    assert.equal(
      evaluate(condition, eventName, { workflow_run: { conclusion } }),
      expected,
      `${eventName}/${conclusion} routing`
    );
  }
});

test('token inventory push filters match generator inputs and preserve other triggers', () => {
  const files = [
    '.github/workflows/token-inventory.yml',
    '.github/base-coat/workflows/token-inventory.yml'
  ];
  const workflows = files.map(readWorkflow);
  const patterns = workflows.map(tokenInventoryPushPaths);
  assert.deepEqual(patterns[0], ['agents/**', 'skills/**', 'instructions/**']);
  assert.deepEqual(patterns[1], patterns[0]);

  for (const sourceFile of [
    'agents/example.agent.md',
    'skills/example/SKILL.md',
    'instructions/example.instructions.md'
  ]) {
    assert.ok(patterns[0].some(pattern => matchesGitHubPath(pattern, sourceFile)));
  }
  for (const unrelatedFile of ['docs/README.md', 'scripts/generate-token-context-inventory.py']) {
    assert.equal(patterns[0].some(pattern => matchesGitHubPath(pattern, unrelatedFile)), false);
  }

  for (const workflow of workflows) {
    assert.match(workflow, /^  schedule:/m);
    assert.match(workflow, /^  workflow_dispatch:/m);
    assert.match(workflow, /^  pull_request:\n    types: \[closed\]/m);
    assert.match(workflow, /if: github\.event_name != 'pull_request'/);
  }
});

test('other housekeeping job predicates preserve useful events before allocation', () => {
  const routes = [
    ['.github/workflows/dependency-graph-pages.yml', 'graph', 'schedule', true],
    ['.github/workflows/dependency-graph-pages.yml', 'graph', 'workflow_dispatch', true],
    ['.github/workflows/dependency-graph-pages.yml', 'graph', 'pull_request', false],
    ['.github/workflows/model-capability-refresh.yml', 'refresh', 'schedule', true],
    ['.github/workflows/model-capability-refresh.yml', 'refresh', 'workflow_dispatch', true],
    ['.github/workflows/model-capability-refresh.yml', 'refresh', 'pull_request', false]
  ];
  for (const [file, job, eventName, expected] of routes) {
    assert.equal(
      evaluate(jobCondition(readWorkflow(file), job), eventName),
      expected,
      `${file}/${eventName}`
    );
  }

  const memoryCondition = jobCondition(
    readWorkflow('.github/workflows/memory-contribution-issue.yml'),
    'process'
  );
  assert.equal(evaluate(memoryCondition, 'issues', { label: { name: 'memory-contribution' } }), true);
  assert.equal(evaluate(memoryCondition, 'issues', { label: { name: 'bug' } }), false);
});

test('fixture quantifies routing separately from production telemetry', () => {
  assert.match(fixture.description, /not production telemetry/);
  let beforeJobs = 0;
  let beforeMinutes = 0;
  let afterJobs = 0;
  let afterMinutes = 0;

  for (const sample of fixture.buildGuard) {
    const relevant = evaluate(
      jobCondition(readWorkflow('.github/workflows/ship-it-build-guard.yml'), 'resolve-inputs'),
      sample.event,
      { workflow_run: { conclusion: sample.conclusion } }
    );
    const detectorRuns = sample.event === 'workflow_dispatch' || sample.conclusion === 'failure';
    const jobs = 1 + Number(detectorRuns);
    const minutes = sample.resolverMinutes + (detectorRuns ? sample.detectorMinutes : 0);
    beforeJobs += jobs;
    beforeMinutes += minutes;
    if (relevant) {
      afterJobs += jobs;
      afterMinutes += minutes;
    }
  }

  assert.deepEqual(
    { beforeJobs, beforeMinutes, afterJobs, afterMinutes, avoidedJobs: beforeJobs - afterJobs, avoidedMinutes: beforeMinutes - afterMinutes },
    { beforeJobs: 6, beforeMinutes: 17, afterJobs: 4, afterMinutes: 14, avoidedJobs: 2, avoidedMinutes: 3 }
  );
});
