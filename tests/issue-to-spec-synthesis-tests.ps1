$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$triagePath = Join-Path $repoRoot '.github\workflows\issue-triage.md'
$synthesisPath = Join-Path $repoRoot '.github\workflows\issue-to-spec-synthesis.yml'
$skillRefPath = Join-Path $repoRoot 'skills\issue-triage\references\triage-workflow.md'

function Assert-Match {
    param([string]$Content, [string]$Pattern, [string]$Message)

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$triage = Get-Content $triagePath -Raw
$synthesis = Get-Content $synthesisPath -Raw
$skillRef = Get-Content $skillRefPath -Raw

$compileScripts = @'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync(process.argv[2], 'utf8').replace(/\r\n/g, '\n');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const blocks = [...source.matchAll(/^(\s*)script: \|\n((?:\1  .*(?:\n|$)|\s*\n)+)/gm)];
if (blocks.length === 0) throw new Error('No github-script bodies found.');
async function main() {
for (const [, indent, body] of blocks) {
  const script = body.split('\n').map(line => line.slice(indent.length + 2)).join('\n');
  new AsyncFunction('github', 'context', 'core', 'require', 'getOctokit', script);
  const extractStart = script.indexOf('const extractSection =');
  const extractEnd = script.indexOf('// Scan the complete source', extractStart);
  const extract = new Function('issueNum', script.slice(extractStart, extractEnd) + 'return extractSection;')(3660);
  const intake = '## Description\r\nProblem\r\n## Intake Contract\r\n### RCA\r\nCause\r\n### Design\r\nPlan\r\n#### Detail\r\nNested\r\n### Debate\r\nExcluded';
  assert.equal(extract(intake, ['description']), 'Problem');
  assert.equal(extract(intake, ['design']), 'Plan\n### Detail\nNested');
  assert.equal(extract(intake, ['rca']), 'Cause');
  const longFence = '## Description\n````text\n## Scope\nnot a section\n```\n# still code\n````\nTail\n## Scope\nReal';
  assert.equal(extract(longFence, ['description']), '````text\n## Scope\nnot a section\n```\n# still code\n````\nTail');
  assert.equal(extract(longFence, ['scope']), 'Real');
  assert.throws(() => extract('## Description\n~~~text\nunclosed', []), /unclosed fenced block/);
  assert.throws(() => extract('## Description\nText <!-- unclosed\n## Scope\nPlan', []), /unclosed HTML comment/);
  assert.equal(extract('No headings\n' + 'full source\n'.repeat(12), ['description']), undefined);
assert.equal(extract('Intro\n## Scope\nPlan\n#### Detail\n```md\n# code\n```', null), 'Intro\n### Scope\nPlan\n##### Detail\n```md\n# code\n```');
assert.equal(extract('Plain text', null), 'Plain text');
  const start = script.indexOf('const normalizeSection =');
  const end = script.indexOf('const problem =', start);
  assert.ok(start >= 0 && end > start, 'Normalization helper must be exercised.');
  const normalize = new Function(script.slice(start, end) + 'return normalizeSection;')();
  assert.equal(normalize('## Description\nText\n### RCA\nCause'),
    '## Description\n\nText\n\n### RCA\n\nCause');
  const valid = '## Description\n\nText\n\n### RCA\n\nCause';
  assert.equal(normalize(valid), valid);
  for (const marker of ['```', '~~~', '````']) {
    const fenced = `${marker}text\n# not a heading\ncontent\n${marker}`;
    assert.equal(normalize(fenced), fenced);
  }
  assert.equal(normalize('````text\n```\n# code\n```\n````'),
    '````text\n```\n# code\n```\n````');
  assert.equal(normalize('## Description\r\nText'), '## Description\n\nText');
  assert.equal(normalize('```bad`\n## Scope\nPlan'), '```bad`\n\n## Scope\n\nPlan');
  assert.equal(normalize('Result:\n- one\n  more\n- two\nlazy\n1. three'), 'Result:\n\n- one\n  more\n- two\nlazy\n1. three');
  assert.equal(normalize('Text\n1) first\n\n- after blank'), 'Text\n\n1) first\n\n- after blank');
  assert.equal(normalize('Intro\n\n    - code\nText\n- one'), 'Intro\n\n    - code\nText\n\n- one');
  for (const literal of ['Version\n2. not a list', 'Rule\n- - -', '<div>\n- inside html\n</div>', '```md\nText\n- in fence\n```']) {
    assert.equal(normalize(literal), literal);
  }

  const publicationStart = script.indexOf('const publicationRef =');
  if (publicationStart >= 0) {
    const publicationEnd = script.indexOf('// Open PR', publicationStart);
    const guard = new AsyncFunction('github', 'owner', 'repo', 'branchName', 'baseSha', 'prdPath', 'specPath', 'issueNum',
      'branchExists', 'prdContent', 'specContent', script.slice(publicationStart, publicationEnd));
    for (const state of ['ahead', 'diverged', 'main-advanced', 'branch-moved']) {
      let branchReads = 0;
      const api = { rest: {
        git: { getRef: async request => ({ data: { object: { sha:
          request.ref === 'heads/main' ? (state === 'main-advanced' ? 'b'.repeat(40) : 'a'.repeat(40)) :
            ++branchReads > 1 && state === 'branch-moved' ? 'c'.repeat(40) : 'a'.repeat(40) } } }) },
        repos: { compareCommits: async () => ({ data: {
          status: state === 'diverged' ? 'diverged' : 'ahead',
          files: [{ filename: 'prd.md' }, { filename: 'spec.md' }],
        } }) },
      } };
      const result = guard(api, 'owner', 'repo', 'branch', 'a'.repeat(40), 'prd.md', 'spec.md', 3660, false, '', '');
      if (state === 'ahead') await result;
      else await assert.rejects(result, { diverged: /complete generated-file diff/, 'main-advanced': /Main advanced/,
        'branch-moved': /changed after validation/ }[state]);
    }
  }

  const countStart = script.indexOf('const branchRef =');
  if (countStart >= 0) {
    // Compare-commits responses carry only per-file line counts (#3857).
    const countEnd = script.indexOf('const evaluatorResponse =', countStart);
    assert.ok(countEnd > countStart, 'Changed-line computation must precede the trusted evaluator read.');
    const countLines = new AsyncFunction('github', 'owner', 'repo', 'branchName', 'baseSha', 'prdPath', 'specPath', 'issueNum',
      'branchExists', 'prdContent', 'specContent', 'recordSynthesisConflict',
      script.slice(countStart, countEnd) + 'return { additions, deletions, expectedLines };');
    const compare = data => countLines({ rest: {
      git: { getRef: async () => ({ data: { object: { sha: 'a'.repeat(40) } } }) },
      repos: { compareCommits: async () => ({ data }) },
    } }, 'owner', 'repo', 'branch', 'b'.repeat(40), 'prd.md', 'spec.md', 3748, false, '', '', async () => {});
    const files = [{ filename: 'prd.md', additions: 57, deletions: 0 }, { filename: 'spec.md', additions: 59, deletions: 2 }];
    assert.deepEqual(await compare({ status: 'ahead', files }), { additions: 116, deletions: 2, expectedLines: 118 });
    await assert.rejects(compare({ status: 'ahead', files: [{ filename: 'prd.md' }, files[1]] }), /lacks per-file line counts/);
    await assert.rejects(compare({ status: 'ahead', files: [{ ...files[0], additions: -1 }, files[1]] }), /lacks per-file line counts/);
    await assert.rejects(compare({ status: 'ahead', additions: 116, deletions: 2 }), /complete generated-file diff/);
    const truncated = [...files, ...Array.from({ length: 298 }, (_, i) => ({ filename: `f${i}`, additions: 1, deletions: 0 }))];
    await assert.rejects(compare({ status: 'ahead', files: truncated }), /complete generated-file diff/);

    // The generated body must satisfy the real author-time and merge-time intake validators (#3866).
    const repoRoot = require('node:path').resolve(process.argv[2], '..', '..', '..');
    const readRepo = file => fs.readFileSync(require('node:path').join(repoRoot, file));
    const { checkBody } = require(require('node:path').join(repoRoot, 'scripts', 'check-pr-intake-metadata.cjs'));
    const evaluator = require(require('node:path').join(repoRoot, '.github', 'base-coat', 'scripts', 'pr-decomposition-evaluator.cjs'));
    const bodyEnd = script.indexOf('// Open PR', countStart);
    const buildBody = new AsyncFunction('github', 'owner', 'repo', 'branchName', 'baseSha', 'prdPath', 'specPath', 'issueNum',
      'branchExists', 'prdContent', 'specContent', 'recordSynthesisConflict', 'require',
      script.slice(countStart, bodyEnd) + 'return prBody;');
    const generate = template => buildBody({ rest: {
      git: { getRef: async () => ({ data: { object: { sha: 'a'.repeat(40) } } }) },
      repos: {
        compareCommits: async () => ({ data: { status: 'ahead', files: files.map(file => ({ ...file, status: 'added' })) } }),
        getContent: async request => {
          assert.equal(request.ref, 'a'.repeat(40));
          const content = request.path === '.github/PULL_REQUEST_TEMPLATE.md' ? template
            : readRepo('.github/base-coat/scripts/pr-decomposition-evaluator.cjs');
          return { data: { type: 'file', content: Buffer.from(content).toString('base64') } };
        },
      },
    } }, 'owner', 'repo', 'branch', 'a'.repeat(40), 'prd.md', 'spec.md', 3748, false, '', '', async () => {}, require);
    const template = readRepo('.github/PULL_REQUEST_TEMPLATE.md').toString('utf8').replace(/\r\n/g, '\n');
    const generated = await generate(template);
    const checked = checkBody(generated, { changedFiles: 2, additions: 116, deletions: 2 });
    assert.deepEqual({ errors: checked.errors, warnings: checked.warnings }, { errors: [], warnings: [] });
    assert.match(checked.scope.rationale, new RegExp(`^individual scope; .*#3748; 2 files and 118 changed lines .*${evaluator.MAX_FILES} files and ${evaluator.MAX_LINES} lines\\.$`));
    const verdict = await evaluator.evaluateDecomposition({ body: generated, changedFiles: 2, additions: 116, deletions: 2,
      files: files.map(file => ({ filename: file.filename, status: 'added' })), headSha: 'a'.repeat(40), baseSha: 'a'.repeat(40) });
    assert.equal(verdict.decision, 'pass');
    assert.doesNotMatch(generated, /^[^<\n]*:\s*TBD\s*$/m);
    await assert.rejects(generate(template.replace('- Rollout plan:', '- Rollout plan:\n- Owner:')), /leaves required template fields empty: - Owner:/);
  }

  assert.equal(extract('## Problem \t Statement\nSpaced', ['problem statement']), 'Spaced');
  const hidden = '<!--\n## Problem Statement\nCopied approval text\n-->\n## Description\nActual problem';
  assert.equal(extract(hidden, ['problem statement']), undefined);
  assert.equal(extract(hidden, ['description']), 'Actual problem');
  assert.equal(extract('<!-- note -->\n## Scope\nPlan\n<!--\n# hidden\n-->\nTail\n## Next', ['scope']), 'Plan\n<!--\n# hidden\n-->\nTail');
  assert.equal(extract('```\n<!--\n```\n## Scope\nPlan', ['scope']), 'Plan');
  const midLine = 'Context <!--\n## Problem Statement\nHidden\n-->\n## Description\nActual problem';
  assert.equal(extract(midLine, ['problem statement']), undefined);
  assert.equal(extract(midLine, ['description']), 'Actual problem');
  assert.equal(extract('Use `<!--` literally\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('a <!-- x --> b <!-- y -->\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('Use ``code <!--\nstill code`` here\n## Scope\nPlan', ['scope']), 'Plan');
  assert.throws(() => extract('Use ``code\n<!--\nstill code``', []), /unclosed HTML comment/);
  assert.equal(extract('Unmatched ` tick <!-- x -->\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('## Scope#\nWrong\n## Scope ##\nPlan', ['scope']), 'Plan');
  assert.equal(extract('## Notes\n```bad`\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('Intro\n##\nEmpty\n## ##\nClosed', null), 'Intro\n###\nEmpty\n### ##\nClosed');
  assert.equal(extract('## Scope\nPlan\n##\nAfter', ['scope']), 'Plan');
  const escaped = 'Context \\`<!-- hidden \\`\n## Problem Statement\nHidden\n-->\n## Description\nActual problem';
  assert.equal(extract(escaped, ['problem statement']), undefined);
  assert.equal(extract(escaped, ['description']), 'Actual problem');
  assert.equal(extract('Use \\``<!--` and \\<!-- literally\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('## Problem <!-- note -->\nCanonical\n## Description\nLower', ['problem']), 'Canonical');
  assert.equal(extract('## Pro<!-- x -->blem\nJoined\n## Description\nLower', ['problem']), 'Joined');
  assert.equal(extract('## Problem<!-- x -->Statement\nWrong', ['problem', 'problem statement']) ?? null, null);
  // Indented code is literal after a blank line or heading, including tab indentation.
  assert.equal(extract('## Description\nExample:\n\n    <!-- literal code text\n## Scope\nPlan', ['description']), 'Example:\n\n    <!-- literal code text');
  assert.equal(extract('## Description\nExample:\n\n    <!-- literal code text\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('## Description\n\t<!-- tab code\n\n    ``` not a fence\n## Scope\nPlan', ['scope']), 'Plan');
  // Fail closed: list continuation and paragraph continuation are not indented code.
  for (const unsafe of ['- item\n\n    <!--\n## Problem Statement\nHidden\n-->', '1. item\n   more\n\n    <!--\n## Problem Statement\nHidden\n-->',
    '- item\n\n  text\n\n    <!--\n## Problem Statement\nHidden\n-->', 'Text\n    <!--\n## Problem Statement\nHidden\n-->']) {
    assert.equal(extract(unsafe + '\n## Description\nActual', ['problem statement']), undefined);
    assert.throws(() => extract(unsafe.slice(0, unsafe.lastIndexOf('\n')), []), /unclosed HTML comment/);
  }
  assert.equal(extract('- item\n\nAfter list\n\n    <!-- code\n## Scope\nPlan', ['scope']), 'Plan');
  assert.equal(extract('- item\n## Description\n    <!-- literal\n## Scope\nPlan', ['scope']), 'Plan');

  const noClosingPrs = async () => ({ repository: { issue: { closedByPullRequestsReferences: { nodes: [] } } } });
  for (const scenario of ['valid', 'invalid', 'conflicting-retry', 'priority', 'directive']) {
    const failure = ['invalid', 'directive'].includes(scenario);
    const artifacts = new Map();
    const writes = [];
    const comments = [];
    let staleReads = false;
    let cleaned = false;
    let linted = false;
    const mocks = {
      'node:fs/promises': {
        mkdtemp: async () => '/bounded/synthesis',
        writeFile: async (name, content) => artifacts.set(name, content.toString()),
        rm: async () => { cleaned = true; },
      },
      'node:child_process': {
        execFile: (command, args, options, callback) => {
          assert.equal(command, 'markdownlint');
          assert.equal(options.timeout, 30000);
          assert.equal(args.length, 4);
          const file = name => require('node:path').join(options.cwd, name);
          assert.ok(artifacts.get(file(args[2])).includes('Problem beyond eight lines'));
          assert.ok(artifacts.get(file(args[3])).includes('Plan'));
          assert.equal(artifacts.get(file(args[1])), '{"default":true}');
          if (scenario === 'priority') {
            assert.ok(!artifacts.get(file(args[2])).includes('Lower'));
            assert.ok(!artifacts.get(file(args[3])).includes('Lower'));
          }
          linted = true;
          callback(failure ? new Error('secret-bearing CLI diagnostic') : null, '', '');
        },
      },
    };
    const api = {
      git: {
        getRef: async () => ({ data: { object: { sha: 'a'.repeat(40) } } }),
        createRef: async () => {
          assert.ok(linted && cleaned);
          if (scenario === 'conflicting-retry') throw Object.assign(new Error('exists'), { status: 422 });
          writes.push('branch');
          throw new Error('stop after validation');
        },
      },
      pulls: { list: async () => ({ data: [] }) },
      issues: {
        get: async () => ({ data: { ...issue, labels: staleReads ? [] : issue.labels } }),
        listComments: async () => {},
        createLabel: async () => { writes.push('create-label'); },
        addLabels: async request => {
          writes.push('label');
          issue.labels.push(...request.labels.map(name => ({ name })));
        },
        createComment: async request => {
          writes.push('comment');
          const comment = { id: comments.length + 1, user: { login: 'bot' }, body: request.body };
          comments.push(comment);
          return { data: comment };
        },
        deleteComment: async request => {
          writes.push('delete');
          comments.splice(comments.findIndex(comment => comment.id === request.comment_id), 1);
        },
      },
      repos: {
        getContent: async request => {
          if (request.path !== '.markdownlint.json') {
            assert.equal(scenario, 'conflicting-retry');
            return { data: { type: 'file', content: Buffer.from('User-edited artifact').toString('base64') } };
          }
          assert.equal(request.path, '.markdownlint.json');
          assert.equal(request.ref, 'a'.repeat(40));
          return { data: { type: 'file', content: Buffer.from('{"default":true}').toString('base64') } };
        },
      },
    };
    const issue = {
      number: 3660, title: 'Quoted "title": example', user: { login: 'owner' },
      labels: [{ name: 'quote"label' }],
      body: scenario === 'priority'
        ? '## Description\nLower problem\n## Design\nLower design\n## RCA\nLower why\n' +
          '## Problem\tStatement\nProblem beyond eight lines\n## Suggested  Scope\nPlan\n## Why  this matters\nImpact'
        : '## Description\n' + '\n'.repeat(10) + 'Problem beyond eight lines\n' +
          (scenario === 'directive' ? '<!-- markdownlint-disable -->\n' : '') + '## Intake Contract\n### Design\nPlan',
    };
    const run = new AsyncFunction('github', 'context', 'core', 'require', 'getOctokit', script);
    const trigger = eventName => run({ rest: api, graphql: noClosingPrs,
      paginate: async fn => fn === api.issues.listComments ? [...comments] : [issue] },
      { repo: { owner: 'owner', repo: 'repo' }, eventName, payload: { issue } },
      { notice: () => {}, warning: () => {} }, name => mocks[name] || require(name),
      () => { throw new Error('Unexpected write token'); });
    if (scenario === 'conflicting-retry') {
      // Concurrent runs that both miss the label keep one comment; later triggers skip without lint or writes.
      staleReads = true;
      await Promise.all([trigger('issues'), trigger('issues')]);
      staleReads = false;
      assert.equal(comments.length, 1);
      assert.equal(writes.filter(write => write === 'delete').length, 1);
      const recorded = writes.length;
      linted = false;
      await trigger('workflow_run');
      await trigger('issues');
      assert.equal(linted, false);
      assert.equal(writes.length, recorded);
      assert.equal(comments.length, 1);
      continue;
    }
    await assert.rejects(trigger('issues'),
      failure ? /Markdown validation failed.*#3660/ : /stop after validation/);
    assert.ok(cleaned);
    assert.equal(linted, scenario !== 'directive');
    assert.deepEqual(writes, ['valid', 'priority'].includes(scenario) ? ['branch'] : []);
  }

  // The oldest-first picker skips conflicted, closed, and already-delivered issues.
  const picked = [];
  const queue = [
    { number: 1, state: 'open', labels: [{ name: 'synthesis-conflict' }], created_at: '2026-01-01' },
    { number: 2, state: 'closed', labels: [], created_at: '2026-01-02' },
    { number: 3, state: 'open', labels: [], created_at: '2026-01-03' },
    { number: 4, state: 'open', labels: [], created_at: '2026-01-04', title: 'Next', user: { login: 'o' },
      body: '## Description\nProblem' },
  ];
  const pickerRun = new AsyncFunction('github', 'context', 'core', 'require', 'getOctokit', script);
  await assert.rejects(pickerRun({
    graphql: async (query, vars) => ({ repository: { issue: { closedByPullRequestsReferences: {
      nodes: vars.number === 3 ? [{ merged: true }] : [] } } } }),
    paginate: async () => [...queue].reverse(),
    rest: { issues: {}, repos: { getContent: async () => { picked.push('content'); throw new Error('picked'); } },
      git: { getRef: async () => ({ data: { object: { sha: 'a'.repeat(40) } } }) } },
  }, { repo: { owner: 'owner', repo: 'repo' }, eventName: 'workflow_run', payload: {} },
  { notice: message => picked.push(message), warning: () => {} }, require, () => {}), /picked/);
  assert.deepEqual(picked, ['Skipping #1: issue is labelled synthesis-conflict.',
    'Skipping #2: issue is closed.', 'Skipping #3: issue is already closed by a merged PR.', 'content']);
}
console.log(`Compiled ${blocks.length} synthesis script bodies.`);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
'@
$compileScripts | node - $synthesisPath
if ($LASTEXITCODE -ne 0) {
    throw 'Synthesis github-script bodies must compile before workflow execution.'
}
$compileScripts | node - (Join-Path $repoRoot '.github\base-coat\workflows\issue-to-spec-synthesis.yml')
if ($LASTEXITCODE -ne 0) {
    throw 'Distributed synthesis github-script bodies must pass the same regressions.'
}

# Step 7 only skips the advisory when BOTH a PRD link and a spec link are present.
# The skill reference decision tree previously said OR, which would let an issue
# carrying just one of the two artifacts skip synthesis entirely.
if ($skillRef -match 'contain\s+a\s+PRD\s+link[^\r\n]*\bOR\b') {
    throw 'Skill reference PRD/spec decision tree must require BOTH links, matching Step 7 of issue-triage.md.'
}
Assert-Match $skillRef 'contain\s+BOTH\s+a\s+PRD\s+link' 'Skill reference must state that both a PRD link and a spec link are required.'

# Prompt prose is hard-wrapped, so these contract phrases can legitimately span a
# line break. Match on \s+ instead of a literal space so re-wrapping the guidance
# cannot fail the contract while the guidance itself is still present.
Assert-Match $triage 'Apply\s+the\s+`synthesize-spec`\s+label' 'Triage must trigger synthesis when it applies needs-prd.'
Assert-Match $triage 'Only\s+apply\s+`needs-info`\s+when\s+the\s+issue\s+failed' 'Triage must not add needs-info to otherwise actionable issues.'
Assert-Match $synthesis 'const prdPath = `docs/prd/synthesized/' 'Synthesis must generate a PRD artifact.'
Assert-Match $synthesis 'const specPath = `docs/spec/synthesized/' 'Synthesis must generate a spec artifact.'
Assert-Match $synthesis 'path: prdPath' 'Synthesis must write the generated PRD.'
Assert-Match $synthesis 'PRD and spec synthesized from this issue' 'Source issue must link to the generated artifacts.'
Assert-Match $synthesis 'WRITE_TOKEN: \$\{\{ secrets\.GH_AW_GITHUB_TOKEN \}\}' 'Synthesis must expose only the optional org write-token override for mutations.'
if ($synthesis -match 'secrets\.PRODUCTION_REPO_TOKEN') {
    throw 'Synthesis must not use PRODUCTION_REPO_TOKEN: it is scoped to the public mirror repo and has no access to this source repo.'
}
Assert-Match $synthesis 'github-token: \$\{\{ github\.token \}\}' 'Synthesis must keep the default GitHub token for source repository reads.'
Assert-Match $synthesis 'const writeGithub = process\.env\.WRITE_TOKEN \? getOctokit\(process\.env\.WRITE_TOKEN\) : github;' 'Synthesis must create a separate write-token client while preserving the default read client.'
if ($synthesis -match "const \{ getOctokit \} = require\('@actions/github'\)") {
    throw 'Synthesis must use the getOctokit helper provided by github-script instead of redeclaring it.'
}
Assert-Match $synthesis 'writeGithub\.rest\.pulls\.create' 'Synthesis must open the PR with the configured write-token client.'
Assert-Match $synthesis '(?s)Synthesis branch changed after validation.*writeGithub\.rest\.pulls\.create' 'Synthesis must re-read the branch head immediately before opening the PR.'
Assert-Match $synthesis 'Recovering existing synthesis branch without a PR' 'Synthesis retries must recover a branch created before PR creation failed.'
Assert-Match $synthesis 'workflow_dispatch:' 'Synthesis must support manual/backfill reconciliation.'
Assert-Match $synthesis 'workflow_run:' 'Synthesis must reconcile labels after issue-triage completes because workflow-token label events do not trigger workflows.'
Assert-Match $synthesis 'findPendingIssue' 'Synthesis must find the oldest open needs-prd issue when reconciling.'
Assert-Match $synthesis 'writeGithub\.rest\.issues\.removeLabel' 'Synthesis must remove stale intake labels with the configured write-token client.'
Assert-Match $synthesis 'name: label' 'Synthesis label cleanup must remove the current stale label from the helper loop.'
Assert-Match $synthesis "'needs-prd', 'synthesize-spec', 'needs-info'" 'Synthesis must clear needs-prd, synthesize-spec, and obsolete needs-info labels.'
Assert-Match $synthesis "\?\?\s+'\*Not specified\.\*'" 'Generated fallback text must use MarkdownLint-compliant asterisk emphasis.'
Assert-Match $synthesis '`- Issue: <https://github\.com/\$\{context\.repo\.owner\}/\$\{context\.repo\.repo\}/issues/\$\{issueNum\}>' 'Generated issue references must use MarkdownLint-compliant angle-bracketed URLs.'

Write-Host 'PASS needs-prd to PRD/spec synthesis contract.'
