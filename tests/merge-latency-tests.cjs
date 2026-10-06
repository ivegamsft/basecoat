const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const workflow = fs.readFileSync(path.join(root, '.github/workflows/pr-auto-merge-executor.yml'), 'utf8')
  .replace(/\r\n/g, '\n');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const validation = fs.readFileSync(path.join(root, '.github/workflows/validate-basecoat.yml'), 'utf8')
  .replace(/\r\n/g, '\n');
const windowsLaneRunner = fs.readFileSync(path.join(root, 'scripts/run-windows-validation-lane.ps1'), 'utf8')
  .replace(/\r\n/g, '\n');

test('Windows validation keeps the required check on one Windows runner', () => {
  const validateWindows = validation.split('  validate-windows:')[1];
  assert.ok(validateWindows.includes('runs-on: windows-latest'));
  assert.equal(validation.includes('\n  windows-core:'), false);
  assert.equal(validation.includes('\n  windows-sync:'), false);
  assert.ok(validateWindows.includes("Name = 'core'"));
  assert.ok(validateWindows.includes("Name = 'sync'"));
  assert.ok(validateWindows.includes('Start-Process -FilePath pwsh'));
  assert.ok(validateWindows.includes('Wait-Process -Id ($processes.Process.Id)'));
  assert.ok(validateWindows.includes('scripts/run-windows-validation-lane.ps1'));
  assert.ok(validateWindows.includes('-LaneName core'));
  assert.ok(validateWindows.includes('-LaneName sync'));
  assert.ok(windowsLaneRunner.includes('-SkipSyncProcessTests'));
  assert.ok(windowsLaneRunner.includes('tests\\sync-tests.ps1'));
  assert.ok(validateWindows.includes('Windows validation failed:'));
});
const routing = workflow.split('  route-ci-completion:')[1].split('  route-pr-acknowledgement:')[0];
const routingScript = routing.split('          script: |\n')[1]
  .split('\n').map(line => line.replace(/^ {12}/, '')).join('\n');

test('completion routing dispatches only open main PRs at the completed head', async () => {
  const dispatches = [];
  const pulls = [
    { number: 1, state: 'open', base: { ref: 'main' }, head: { sha: 'current' } },
    { number: 2, state: 'open', base: { ref: 'main' }, head: { sha: 'newer' } },
    { number: 3, state: 'closed', base: { ref: 'main' }, head: { sha: 'current' } },
    { number: 4, state: 'open', base: { ref: 'other' }, head: { sha: 'current' } }
  ];
  const github = {
    paginate: async () => pulls,
    rest: {
      repos: { listPullRequestsAssociatedWithCommit() {} },
      actions: { createWorkflowDispatch: async input => dispatches.push(input) }
    }
  };
  await new AsyncFunction('github', 'context', 'core', 'process', routingScript)(
    github,
    { repo: { owner: 'owner', repo: 'repo' }, payload: {
      workflow_run: { head_sha: 'current' }, repository: { default_branch: 'main' }
    } },
    { info() {} },
    { env: { WORKFLOW_REF: 'owner/repo/.github/workflows/pr-auto-merge-executor.yml@refs/heads/main' } }
  );
  assert.deepEqual(dispatches.map(item => item.inputs), [{ pr_number: '1' }]);
  assert.equal(dispatches[0].ref, 'main');
});

const checkScript = workflow.slice(
  workflow.indexOf('            const readRequiredCheckState = async () => {'),
  workflow.indexOf('            const unsatisfiedChecks = requiredCheckState')
) + '\nreturn requiredCheckState;';

for (const [name, check, pending, satisfied] of [
  ['passing', { status: 'completed', conclusion: 'success' }, false, true],
  ['running', { status: 'in_progress', conclusion: null }, true, false],
  ['failed', { status: 'completed', conclusion: 'failure' }, false, false],
  ['cancelled', { status: 'completed', conclusion: 'cancelled' }, false, false],
  ['missing', null, true, false]
]) {
  test(`single check evaluation preserves ${name} state without waiting`, async () => {
    let reads = 0;
    const github = { rest: {
      repos: { getCombinedStatusForRef: async () => ({ data: { statuses: [] } }) },
      checks: { listForRef: async () => {
        reads++;
        return { data: { check_runs: check ? [{
          name: 'validate-windows', app: { id: 15368 }, started_at: '2026-10-05T19:00:00Z', ...check
        }] : [] } };
      } }
    } };
    const result = await new AsyncFunction(
      'github', 'core', 'owner', 'repo', 'headSha', 'pr', 'requiredChecks',
      'githubActionsIntegrationId', checkScript
    )(github, { info() {} }, 'owner', 'repo', 'head', {}, ['validate-windows'], 15368);
    assert.equal(reads, 1);
    assert.equal(result.hasPendingChecks, pending);
    assert.equal(result.unsatisfiedChecks.length, satisfied ? 0 : 1);
  });
}
