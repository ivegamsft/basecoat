const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const read = file => fs.readFileSync(path.join(root, file), 'utf8').replace(/\r\n/g, '\n');
const script = (file, step) => read(file).split(`      - name: ${step}\n`)[1]
  .split('          script: |\n')[1].split(/\n(?=      - name:|  [\w-]+:)/)[0]
  .split('\n').map(line => line.replace(/^ {12}/, '')).join('\n');
const context = { repo: { owner: 'owner', repo: 'repo' },
  payload: { repository: { default_branch: 'main' } }, eventName: 'workflow_dispatch' };
const fresh = () => ({ number: 42, state: 'open', draft: false, labels: [],
  head: { sha: 'a'.repeat(40), repo: { full_name: 'owner/repo' } },
  base: { ref: 'main', sha: 'b'.repeat(40) } });
test('root and distributed evidence helpers remain byte-identical', () => {
  assert.equal(read('scripts/delivery-recovery-evidence.cjs'),
    read('.github/base-coat/scripts/delivery-recovery-evidence.cjs'));
});

for (const prefix of ['.github/workflows/', '.github/base-coat/workflows/']) {
  const recoveryFile = `${prefix}auto-approve-cloud-agent-workflows.yml`;
  const recoveryJob = read(recoveryFile).split('  reconcile-open-auto-merge-pull-requests:')[1]
    .split('  approve-pending-automation-runs:')[0];
  const gate = recoveryJob.split('      - name: Dispatch current eligibility evaluations\n')[1]
    .match(/^\s*if: (.*)$/m)[1];
  test(`${prefix} trusted profile recovery routing preserves authorization policy`, () => {
    for (const permission of ['statuses', 'checks', 'issues']) {
      assert.match(recoveryJob, new RegExp(`^      ${permission}: read$`, 'm'));
    }
    const profiles = JSON.parse(read('.github/governance/policy-packs.json')).profiles;
    assert.equal(profiles['solo-dev'].main.reconcile_merge_eligibility, false);
    assert.match(recoveryJob, /echo "selected_pack=\$\{SELECTED_PACK\}"/);
    for (const [selected_pack, profile] of Object.entries(profiles)) {
      const steps = { 'policy-pack': { outputs: { selected_pack,
        reconcile: String(profile.main.reconcile_merge_eligibility) } } };
      const expression = gate.replace(/steps\.policy-pack/g, "steps['policy-pack']");
      assert.equal(Function('steps', `return (${expression});`)(steps), true);
    }
  });
  const execute = new AsyncFunction('github', 'context', 'core', 'Date', 'require',
    script(`${prefix}auto-approve-cloud-agent-workflows.yml`, 'Dispatch current eligibility evaluations'));
  for (const scenario of ['zero-review', 'draft', 'held', 'fork', 'advanced', 'closed',
    'hold-added', 'recent-pending', 'recent-success', 'old-failure', 'old-pending',
    'active-executor', 'bounded', 'dispatch-error', 'second-tick', 'empty-page',
    'unchanged-replay', 'check-transition', 'issue-transition', 'main-transition',
    'finite-cap', 'status-budget', 'evidence-truncated', 'changing-evidence-cap']) {
    test(`${prefix} recovery: ${scenario}`, async () => {
      process.env.GITHUB_WORKSPACE = root;
      process.env.SELECTED_PACK = 'solo-dev';
      const pr = fresh();
      if (scenario === 'issue-transition') pr.body = 'Fixes #3590';
      if (scenario === 'draft') pr.draft = true;
      if (scenario === 'held') pr.labels = [{ name: 'delivery-hold' }];
      if (scenario === 'fork') pr.head.repo.full_name = 'fork/repo';
      const live = structuredClone(pr);
      if (scenario === 'advanced') live.head.sha = 'c'.repeat(40);
      if (scenario === 'closed') live.state = 'closed';
      if (scenario === 'hold-added') live.labels = [{ name: 'delivery-hold' }];
      const requests = [], queries = [], summaries = [];
      let evidenceVersion = 0;
      const status = scenario.startsWith('recent-') || scenario.startsWith('old-')
        ? [{ context: 'BaseCoat merge eligibility', state: scenario.split('-')[1],
          created_at: new Date(Date.now() - (scenario.startsWith('old-') ? 3600000 : 1000)).toISOString() }]
        : [];
      if (scenario === 'finite-cap') {
        status.push(...Array.from({ length: 50 }, (_, id) => ({
          context: 'BaseCoat merge eligibility', state: 'failure',
          creator: { login: 'github-actions[bot]' }, created_at: '2020-01-01T00:00:00Z',
          target_url: `https://github.com/owner/repo/actions/runs/${id}?recovery_evidence=${'a'.repeat(64)}`
        })));
      }
      if (scenario === 'status-budget') {
        status.push(...Array.from({ length: 200 }, () => ({
          context: 'BaseCoat merge eligibility', state: 'failure', created_at: '2020-01-01T00:00:00Z'
        })));
      }
      const github = { rest: {
        actions: {
          listWorkflowRuns: async args => {
            queries.push(args);
            return { data: { total_count: scenario === 'active-executor' ? 1 : 0 } };
          },
          createWorkflowDispatch: async args => {
            if (scenario === 'dispatch-error') throw new Error('dispatch denied');
            requests.push(args);
            if (['unchanged-replay', 'check-transition', 'issue-transition', 'main-transition', 'changing-evidence-cap'].includes(scenario)) {
              const observed = {
                context: 'BaseCoat merge eligibility', state: 'failure',
                creator: { login: 'github-actions[bot]' }, created_at: '2020-01-01T00:00:00Z',
                target_url: `https://github.com/owner/repo/actions/runs/${requests.length}?recovery_evidence=${args.inputs.recovery_fingerprint}`
              };
              status.unshift(observed, { ...observed, state: 'pending' });
            }
            if (scenario === 'second-tick') status.push({
              context: 'BaseCoat merge eligibility', state: 'pending', created_at: new Date().toISOString()
            });
          }
        },
        pulls: {
          list: async args => {
            queries.push(args);
            if (scenario === 'empty-page' && args.page !== 1) return { data: [] };
            return { data: scenario === 'bounded'
              ? Array.from({ length: 100 }, (_, i) => ({ ...pr, number: i + 1 })) : [pr] };
          },
          get: async ({ pull_number }) => ({ data: { ...live, number: pull_number } }),
          listReviews: async () => ({ data: [] })
        },
        repos: {
          getBranch: async () => ({ data: { commit: { sha:
            scenario === 'main-transition' ? `main-${evidenceVersion}` : 'main' } } }),
          listCommitStatusesForRef: async args => {
            queries.push(args); assert.equal(args.ref, pr.head.sha);
            return { data: status.slice((args.page - 1) * 100, args.page * 100) };
          }
        },
        checks: { listForRef: async () => ({ data: { check_runs:
          scenario === 'evidence-truncated' ? Array(100).fill({}) :
            ['check-transition', 'changing-evidence-cap'].includes(scenario) ? [{ id: evidenceVersion, conclusion:
              evidenceVersion ? 'success' : 'failure' }] : [] } }) },
        issues: {
          get: async () => ({ data: { number: 3590, labels: evidenceVersion ? ['approved'] : [] } }),
          listComments: async () => ({ data: requests.length ? [{
            user: { login: 'github-actions[bot]' },
            body: `<!-- pr-auto-merge-executor:v1 --> evaluated ${requests.length}`
          }] : [] })
        }
      } };
      const summary = { addRaw(value) { summaries.push(value); return this; }, async write() {} };
      const clock = scenario === 'empty-page'
        ? { now: () => 900000, parse: Date.parse } : Date;
      const invocation = () => execute(github, context, { info() {}, summary }, clock, require);
      if (scenario === 'dispatch-error') await assert.rejects(invocation, /dispatch denied/);
      else await invocation();
      if (scenario === 'second-tick') await invocation();
      if (scenario === 'changing-evidence-cap') {
        for (let repeat = 0; repeat < 550; repeat += 1) {
          evidenceVersion += 1;
          await invocation();
        }
        assert.equal(status.length, 100, 'stop at 50 two-status attempts, reserving status capacity');
      }
      if (['unchanged-replay', 'check-transition', 'issue-transition', 'main-transition'].includes(scenario)) {
        for (let repeat = 0; repeat < 550; repeat += 1) await invocation();
        assert.equal(requests.length, 1, 'unchanged blocked head must not spend 1,000 status slots');
        if (scenario !== 'unchanged-replay') {
          evidenceVersion += 1;
          await invocation();
          assert.notEqual(requests[0].inputs.recovery_fingerprint, requests[1].inputs.recovery_fingerprint);
          for (let repeat = 0; repeat < 550; repeat += 1) await invocation();
        }
      }
      assert.equal(requests.length, scenario === 'changing-evidence-cap' ? 50 : scenario === 'bounded' ? 5 :
        ['check-transition', 'issue-transition', 'main-transition'].includes(scenario) ? 2 :
        ['zero-review', 'old-failure', 'old-pending', 'second-tick', 'empty-page', 'unchanged-replay'].includes(scenario) ? 1 : 0);
      if (scenario === 'empty-page') assert.equal(queries.filter(args => args.state === 'open').length, 2);
      for (const args of queries) {
        assert.ok(args.per_page <= 100);
        if (args.page) assert.ok(args.page >= 1 && args.page <= 10);
      }
      for (const request of requests) {
        assert.equal(request.ref, 'main');
        assert.equal(request.workflow_id, prefix.includes('base-coat')
          ? 'basecoat-pr-auto-merge-executor.yml' : 'pr-auto-merge-executor.yml');
      }
      if (summaries.length) assert.match(summaries[0], /not queue success.*#3604/);
    });
  }
}

// Execute the real authorization evaluator, not a test-only authorization model.
for (const prefix of ['.github/workflows/', '.github/base-coat/workflows/']) {
const evaluate = new AsyncFunction('github', 'context', 'core', 'require',
  script(`${prefix}pr-auto-merge-executor.yml`, 'Evaluate policy and merge readiness'));
for (const scenario of ['solo-zero-review', 'solo-feature-approved', 'team-zero-review', 'regulated-zero-review',
  'team-approved', 'held', 'draft', 'changed-head', 'missing-check', 'untrusted-check',
  'changes-requested', 'stale-review', 'unauthorized-feature', 'missing-spec',
  'candidate-reconcile-drift', 'candidate-approval-drift', 'candidate-binding-drift',
  'production-digest-updated', 'production-digest-mismatch', 'production-binding-mismatch']) {
  test(`${prefix} existing evaluator: ${scenario}`, async () => {
    process.env.GITHUB_WORKSPACE = root;
    process.env.PR_NUMBER_INPUT = '42';
    process.env.RECOVERY_FINGERPRINT = 'a'.repeat(64);
    process.env.POLICY_PACK = scenario.startsWith('team-') || scenario === 'stale-review'
      ? 'team-dev' : scenario.startsWith('regulated-') ? 'regulated-team' : 'solo-dev';
    process.env.WORKFLOW_REF = 'owner/repo/.github/workflows/pr-auto-merge-executor.yml@refs/heads/main';
    const pr = { ...fresh(), user: { login: 'author', type: 'User' }, title: 'Recovery fixture',
      changed_files: 1, additions: 5, deletions: 0, mergeable_state: 'clean',
      labels: [{ name: 'size:S' }],
      body: '## Intake Contract\n\n### Design\n\nChange scope: individual\nSource issues: #1\nIndependently deliverable units: 1\n' +
        'Unit inventory: 1 recovery\nExpected files: 1\nExpected changed lines (additions + deletions): 5\n' +
        'Classification rationale: One cohesive fix.\nMechanical batch exception evidence: none\n\n### Derived Classification\n' };
    if (scenario === 'held') pr.labels.push({ name: 'delivery-hold' });
    if (scenario === 'draft') pr.draft = true;
    if (['solo-feature-approved', 'unauthorized-feature', 'missing-spec'].includes(scenario)) {
      pr.body += '\n<!-- basecoat-feature-handoff:v1 source-issue:#1 -->\nCloses #1';
    }
    const reviews = ['team-approved', 'stale-review', 'changes-requested'].includes(scenario)
      ? [{ id: 1, user: { login: 'maintainer', type: 'User' },
        commit_id: scenario === 'stale-review' ? 'c'.repeat(40) : pr.head.sha,
        state: scenario === 'changes-requested' ? 'CHANGES_REQUESTED' : 'APPROVED',
        submitted_at: new Date().toISOString() }] : [];
    const outputs = {}, statuses = [], failures = [];
    const core = { info() {}, warning() {}, setOutput(key, value) { outputs[key] = value; },
      setFailed(value) { failures.push(value); } };
    let reads = 0;
    const json = file => JSON.parse(read(file));
    const policy = json('.github/governance/policy-packs.json');
    const candidatePolicy = structuredClone(policy);
    if (scenario === 'candidate-reconcile-drift') {
      candidatePolicy.profiles['solo-dev'].main.reconcile_merge_eligibility = true;
    }
    if (scenario === 'candidate-approval-drift') {
      candidatePolicy.profiles['team-dev'].main.required_approvals_by_risk_tier.high = 0;
    }
    const productionPath = '.github/workflows/docs-production.yml';
    if (scenario === 'candidate-binding-drift') {
      candidatePolicy.production_environment.workflow_bindings[productionPath].expected_job_environment = 'staging';
    }
    let productionText = read(productionPath) + '\n# Digest-only update fixture\n';
    if (scenario === 'production-binding-mismatch') {
      productionText = productionText.replace('environment: production', 'environment: staging');
      assert.match(productionText, /environment: staging/);
    }
    if (scenario.startsWith('production-')) {
      candidatePolicy.production_environment.workflow_bindings[productionPath].expected_workflow_sha256 =
        scenario === 'production-digest-mismatch' ? '0'.repeat(64) :
          require('node:crypto').createHash('sha256').update(productionText).digest('hex');
    }
    const profile = policy.profiles[process.env.POLICY_PACK];
    const files = [{ filename: scenario.startsWith('production-')
      ? productionPath : 'scripts/recovery-fixture.ps1', status: 'modified', additions: 5, deletions: 0 }];
    const comment = async args => ({ data: { ...args, id: 123 } });
    const github = { rest: {
      pulls: { get: async () => ({ data: scenario === 'changed-head' && ++reads > 1
        ? { ...pr, head: { ...pr.head, sha: 'c'.repeat(40) } } : pr }), listFiles() {}, listReviews() {} },
      issues: { listComments() {}, createComment: comment, updateComment: comment,
        get: async () => ({ data: { number: 1, state: 'open', title: 'Feature fixture',
          user: { login: 'author', type: 'User' },
          labels: scenario === 'unauthorized-feature' ? [] : [{ name: 'approved' }],
          body: '<!-- basecoat-feature-origin:v1 -->\nBaseCoat Source scope: Recovery fixture\n' +
            (scenario === 'missing-spec' ? '- Spec: N/A' :
              '- Spec: https://github.com/IBuySpy-Shared/basecoat/blob/main/docs/reference/delivery-recovery-spec.md') } }) },
      repos: {
        getContent: async ({ path: file, ref }) => {
          assert.ok(ref === 'main' || ref === pr.head.sha);
          const content = file === '.github/governance/policy-packs.json'
            ? JSON.stringify(ref === 'main' ? policy : candidatePolicy) :
              file === productionPath && ref === pr.head.sha ? productionText : read(file);
          return { data: { content: Buffer.from(content).toString('base64'), encoding: 'base64' } };
        },
        getEnvironment: async () => ({ data: {
          protection_rules: [{ type: 'required_reviewers', prevent_self_review: false,
            reviewers: [{ reviewer: { login: 'maintainer' } }] }],
          deployment_branch_policy: { protected_branches: true }
        } }),
        getCollaboratorPermissionLevel: async () => ({ data: { permission: 'write' } }),
        getCombinedStatusForRef: async () => ({ data: { statuses: [] } }),
        createCommitStatus: async args => { statuses.push(args); }
      },
      actions: { createWorkflowDispatch: async () => {} },
      checks: { listForRef: async () => ({ data: { check_runs:
        scenario === 'missing-check' ? [] : profile.main.required_checks.map((name, id) => ({
          name, id, app: { id: scenario === 'untrusted-check' ? 999 : 15368 },
          status: 'completed', conclusion: 'success', started_at: '2026-10-07T13:00:00Z'
        })) } }) }
    }, paginate: async (endpoint, args) => endpoint === github.rest.pulls.listFiles ? files :
      endpoint === github.rest.pulls.listReviews ? reviews :
        args.issue_number === 1 && ['missing-spec', 'solo-feature-approved'].includes(scenario)
          ? ['/approve', 'ship-it: Recovery fixture'].map(body => ({
            body, user: { login: 'maintainer', type: 'User' }, created_at: '2026-10-07T13:00:00Z'
          })) : [] };
    await evaluate(github, context, core, require);
    assert.ok(statuses.filter(status => status.sha === pr.head.sha)
      .every(status => status.target_url.includes(`recovery_evidence=${'a'.repeat(64)}`)),
      'existing initial/final status writes must persist the marker without extra status writes');
    if (scenario.startsWith('candidate-')) {
      assert.notEqual(outputs.eligible, 'true');
      assert.match(failures.join('\n'), /all other policy fields must remain trusted/);
      assert.equal(statuses.at(-1).state, 'failure');
      return;
    }
    assert.equal(outputs.eligible, ['solo-zero-review', 'solo-feature-approved', 'team-approved', 'production-digest-updated'].includes(scenario) ? 'true' : 'false',
      failures.join('\n'));
    assert.equal(statuses.at(-1).state, ['solo-zero-review', 'solo-feature-approved', 'team-approved', 'production-digest-updated'].includes(scenario) ? 'success' :
      ['missing-check', 'untrusted-check', 'changed-head'].includes(scenario) ? 'pending' : 'failure');
    if (scenario === 'team-zero-review') assert.match(failures.join('\n'), /Insufficient approvals/);
    if (scenario === 'unauthorized-feature') assert.match(failures.join('\n'), /approval|approved/i);
    if (scenario === 'missing-spec') assert.match(failures.join('\n'), /Spec URL/);
    if (scenario === 'production-digest-mismatch') assert.match(failures.join('\n'), /trusted full-workflow digest/);
    if (scenario === 'production-binding-mismatch') assert.match(failures.join('\n'), /trusted production environment binding/);
  });
}
}
