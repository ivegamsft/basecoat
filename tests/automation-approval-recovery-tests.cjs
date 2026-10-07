const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const root = path.resolve(__dirname, '..');

for (const file of [
  '.github/workflows/auto-approve-cloud-agent-workflows.yml',
  '.github/base-coat/workflows/auto-approve-cloud-agent-workflows.yml'
]) {
  const content = fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
  const job = content.split('  approve-pending-automation-runs:')[1];
  const script = job.split('          script: |\n')[1]
    .split('\n').map(line => line.replace(/^ {12}/, '')).join('\n');
  const execute = new AsyncFunction('github', 'context', 'core', script);
  const predicateStart = job.indexOf('    if: |\n');
  const predicateEnd = job.indexOf('\n    name: Approve pending in-repo automation workflow runs', predicateStart);
  assert.ok(predicateStart >= 0 && predicateEnd > predicateStart,
    `${file}: recovery job must retain its job-level event filter`);
  const condition = job.slice(predicateStart + '    if: |\n'.length, predicateEnd)
    .split('\n').map(line => line.replace(/^ {6}/, '')).join(' ').trim();

  for (const scenario of [
    'eligible', 'shared-head', 'fork', 'stale', 'closed', 'advanced', 'unassociated',
    'wrong-event', 'already-approved', 'changed-run-head', 'changed-association',
    'removed-association', 'changed-event', 'delayed-hold-after-producer',
    'forbidden', 'approved-race', 'api-error'
  ]) {
    test(`${file}: ${scenario}`, async () => {
      const approvals = [];
      const failures = [];
      const pr = { number: 3532, state: 'open', head: {
        sha: 'current', repo: { full_name: 'owner/repo' }
      } };
      const run = { id: 123, name: 'CI', head_sha: 'current',
        head_repository: { full_name: 'owner/repo' }, event: 'pull_request',
        conclusion: 'action_required', pull_requests: [{ number: 3532 }] };
      if (scenario === 'fork') run.head_repository.full_name = 'fork/repo';
      if (scenario === 'stale') run.head_sha = 'older';
      if (scenario === 'unassociated') run.pull_requests = [];
      if (scenario === 'wrong-event') run.event = 'push';
      const currentPr = structuredClone(pr);
      if (scenario === 'closed') currentPr.state = 'closed';
      if (scenario === 'advanced') currentPr.head.sha = 'newer';
      const currentRun = structuredClone(run);
      if (scenario === 'already-approved') currentRun.conclusion = null;
      if (scenario === 'changed-run-head') currentRun.head_sha = 'newer';
      if (scenario === 'changed-association') currentRun.pull_requests = [{ number: 999 }];
      if (scenario === 'removed-association') currentRun.pull_requests = [];
      if (scenario === 'changed-event') currentRun.event = 'push';
      const github = {
        rest: {
          pulls: { list() {}, get: async () => ({ data: currentPr }) },
          actions: {
            listWorkflowRunsForRepo() {},
            getWorkflowRun: async () => ({ data: currentRun }),
            approveWorkflowRun: async ({ run_id }) => {
              if (scenario === 'forbidden' || scenario === 'approved-race' || scenario === 'api-error') {
                if (scenario === 'approved-race') currentRun.conclusion = 'success';
                throw Object.assign(new Error('approval failed'), {
                  status: scenario === 'api-error' ? 500 : 403
                });
              }
              approvals.push(run_id);
            }
          }
        },
        paginate: async endpoint => endpoint === github.rest.pulls.list
          ? (scenario === 'shared-head' ? [pr, { ...pr, number: 3533 }] : [pr]) : [run]
      };
      const invocation = () => execute(github, { repo: { owner: 'owner', repo: 'repo' } },
        { setFailed: message => failures.push(message), info() {} });
      if (scenario === 'api-error') {
        await assert.rejects(invocation, /approval failed/);
      } else {
        await invocation();
        assert.deepEqual(approvals, ['eligible', 'shared-head', 'delayed-hold-after-producer'].includes(scenario) ? [123] : []);
        assert.equal(failures.length, scenario === 'forbidden' ? 1 : 0);
      }
    });
  }

  test(`${file}: recovery event predicate retains trusted producer and manual triggers`, () => {
    const evaluate = (eventName, event) => {
      const github = { event_name: eventName, event, repository: 'owner/repo' };
      return Function('github', `return (${condition});`)(github);
    };
    assert.equal(evaluate('schedule', {}), true);
    assert.equal(evaluate('workflow_dispatch', {}), true);
    assert.equal(evaluate('workflow_run', { workflow_run: {
      head_repository: { full_name: 'owner/repo' }
    } }), true);
    assert.equal(evaluate('workflow_run', { workflow_run: {
      head_repository: { full_name: 'fork/repo' }
    } }), false);
  });
}
