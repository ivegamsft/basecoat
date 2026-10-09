#!/usr/bin/env pwsh
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running adoption metrics parser tests...'

$modulePath = (Join-Path $repoRoot 'scripts\metrics\repo_inputs.py')
$collectorPath = (Join-Path $repoRoot 'scripts\metrics\collect-metrics.py')
$fixturePath = (Join-Path $repoRoot 'tests\fixtures\adoption-metrics\scalar-repo.json')

foreach ($workflowPath in @('.github\workflows\adoption-metrics.yml', '.github\base-coat\workflows\adoption-metrics.yml')) {
    $workflow = Get-Content (Join-Path $repoRoot $workflowPath) -Raw
    $permissions = [regex]::Match($workflow, '(?ms)^permissions:\r?\n(?<body>(?:[ \t]+[^\r\n]*\r?\n)+)').Groups['body'].Value
    foreach ($permission in @('pull-requests', 'actions')) {
        if ($permissions -notmatch "(?m)^  ${permission}: read\r?$") {
            throw "$workflowPath must grant ${permission}: read"
        }
    }
}
$distributedCollector = Join-Path $repoRoot '.github\base-coat\scripts\metrics\collect-metrics.py'
if ((Get-Content $collectorPath -Raw) -cne (Get-Content $distributedCollector -Raw)) {
    throw 'Source and distributed adoption collectors must remain identical'
}

$testScript = @"
import importlib.util
import copy
import io
import os
import tempfile
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

module_path = r'''$modulePath'''
spec = importlib.util.spec_from_file_location('repo_inputs', module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

cases = [
    ('org/repo', ['org/repo']),
    ('["org/repo1", "org/repo2"]', ['org/repo1', 'org/repo2']),
    ('org/repo1, org/repo2;org/repo3', ['org/repo1', 'org/repo2', 'org/repo3']),
    ('  org/repo4  ', ['org/repo4']),
]

for raw, expected in cases:
    actual = module.normalize_dashboard_repos(raw)
    if actual != expected:
        raise SystemExit(f'{raw!r} -> {actual!r}, expected {expected!r}')

collector_path = r'''$collectorPath'''
collector_spec = importlib.util.spec_from_file_location('collect_metrics', collector_path)
collector = importlib.util.module_from_spec(collector_spec)
collector_spec.loader.exec_module(collector)

fixture_path = r'''$fixturePath'''
import json
with open(fixture_path, 'r', encoding='utf-8') as handle:
    metrics = json.load(handle)

summary = collector.render_summary(metrics)
if summary.count('| org/repo |') != 1:
    raise SystemExit(f'expected exactly one full repo row, got:\n{summary}')
if '| repo |' in summary:
    raise SystemExit(f'shortened repo row detected:\n{summary}')

for surface, collect in [('pull_requests', collector.collect_pr_metrics), ('ci', collector.collect_ci_metrics)]:
    with patch.object(collector, 'github_api', side_effect=[{}, None]):
        result = collect('org/repo', 'fixture-token')
    assert result['available'] is False, (surface, result)
    assert result['error'].endswith('collection_failed'), (surface, result)
    assert 'pull_requests' not in result and 'ci' not in result, result
    key = 'prs_merged_28d' if surface == 'pull_requests' else 'success_rate'
    assert result[key] is None, (surface, result)
    if surface == 'pull_requests':
        assert result['cycle_time_p95_hours'] is None
    with patch.object(collector, 'github_api', return_value=None):
        inaccessible = collect('org/repo', 'fixture-token')
    assert inaccessible['available'] is False and inaccessible['error'] == 'inaccessible_repo'

with patch.object(collector, 'github_api', side_effect=[{}, []]) as api:
    empty_prs = collector.collect_pr_metrics('org/repo', 'fixture-token')
assert 'sort=updated&direction=desc&per_page=50' in api.call_args_list[1].args[0]
assert empty_prs['available'] is True and empty_prs['prs_merged_28d'] == 0

for runs in [[], [{'name': 'CI', 'conclusion': 'skipped'}], [{'name': 'CI', 'conclusion': 'cancelled'}]]:
    with patch.object(collector, 'github_api', side_effect=[{}, {'workflow_runs': runs}]):
        empty_ci = collector.collect_ci_metrics('org/repo', 'fixture-token')
    assert empty_ci['available'] is False and empty_ci['success_rate'] is None
    assert empty_ci['error'] == 'no_measurable_runs' and empty_ci['total_runs_sampled'] == 0

for conclusions, expected in [(['failure'], 0), (['success'], 100), (['success', 'failure'], 50)]:
    runs = [{'name': 'CI', 'conclusion': value} for value in conclusions]
    with patch.object(collector, 'github_api', side_effect=[{}, {'workflow_runs': runs}]):
        ci = collector.collect_ci_metrics('org/repo', 'fixture-token')
    assert ci['available'] is True and ci['success_rate'] == expected
    assert ci['runs_sampled_last_20'] == len(conclusions)

unknown = copy.deepcopy(metrics)
unknown['repos']['org/repo']['pull_requests'] = collector.unavailable_repo_metrics('pr_collection_failed')['pull_requests']
unknown['repos']['org/repo']['ci'] = empty_ci
assert '| org/repo | unknown | unknown | unknown | unknown |' in collector.render_summary(unknown)
assert collector.detect_degradation(unknown, [metrics, unknown]) == []
assert collector.detect_degradation(metrics, [unknown, metrics]) == []
failed = copy.deepcopy(metrics)
failed['repos']['org/repo']['ci'].update(available=True, success_rate=0)
assert any(a['type'] == 'ci_success_drop' for a in collector.detect_degradation(failed, [metrics, failed]))
partial_previous = copy.deepcopy(metrics)
partial_previous['repos']['org/repo']['available'] = False
partial_previous['repos']['org/repo']['pull_requests'] = unknown['repos']['org/repo']['pull_requests']
assert collector.detect_degradation(failed, [partial_previous, failed]) == []
partial_current = copy.deepcopy(failed)
partial_current['repos']['org/repo']['available'] = False
assert collector.detect_degradation(partial_current, [metrics, partial_current]) == []

def denied_endpoints(request):
    url = request.full_url
    if '/pulls?' in url or '/actions/runs?' in url:
        raise HTTPError(url, 403, 'Forbidden', None, None)
    if '/copilot/' in url:
        raise HTTPError(url, 404, 'Not Found', None, None)
    payload = [] if '/contents/' in url or '/issues?' in url else {}
    return io.BytesIO(json.dumps(payload).encode())

with tempfile.TemporaryDirectory() as output:
    Path(output, 'history.json').write_text(json.dumps([metrics]), encoding='utf-8')
    env = {'GITHUB_TOKEN': 'fixture-token', 'DASHBOARD_ORG': 'org', 'DASHBOARD_REPOS': '["org/repo"]', 'OUTPUT_DIR': output}
    warnings = io.StringIO()
    with patch.dict(os.environ, env), patch.object(collector, 'urlopen', side_effect=denied_endpoints), redirect_stdout(io.StringIO()), redirect_stderr(warnings):
        collector.main()
    latest = json.loads(Path(output, 'latest.json').read_text())
    repo = latest['repos']['org/repo']
    assert repo['available'] is False and repo['error'] == 'incomplete_pr_ci_metrics'
    assert repo['pull_requests']['prs_merged_28d'] is None and repo['ci']['success_rate'] is None
    assert 'API error 403' in warnings.getvalue()
    assert '| org/repo | unavailable | unavailable | unavailable | unavailable | unavailable |' in Path(output, 'SUMMARY.md').read_text()
    assert json.loads(Path(output, 'alerts.json').read_text()) == []
    assert len(json.loads(Path(output, 'history.json').read_text())) == 2

print('Adoption metrics parser tests passed')
"@

$output = $testScript | python -
if ($LASTEXITCODE -ne 0) {
    throw "Adoption metrics parser tests failed: $output"
}

Write-Host $output

foreach ($dashboardRelativePath in @('docs\dashboard\index.html', 'portal\app\dashboard\index.html')) {
$dashboardPath = Join-Path $repoRoot $dashboardRelativePath
$dashboardPathJson = ConvertTo-Json -Compress $dashboardPath
$fixturePathJson = ConvertTo-Json -Compress $fixturePath
$dashboardTest = @"
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync($dashboardPathJson, 'utf8');
const source = html.match(/function renderDashboard\([\s\S]*?(?=\r?\n    loadMetrics\(\);)/)[0];
const measured = JSON.parse(fs.readFileSync($fixturePathJson, 'utf8'));
const unknown = structuredClone(measured);
unknown.repos['org/repo'].available = false;
unknown.repos['org/repo'].ci.success_rate = null;
function render(latest, history) {
    const app = { innerHTML: '' };
    let chart;
    vm.runInNewContext(source + '; renderDashboard(latest, history);', {
        latest, history,
        document: { getElementById: () => app },
        Chart: function(_element, options) { chart = options; }
    });
    return { html: app.innerHTML, chart };
}
const unavailable = render(unknown, [measured, unknown]);
assert.match(unavailable.html, /unavailable/);
assert.doesNotMatch(unavailable.html, /0%|0\.0%|null%/);
assert.equal(unavailable.chart.data.datasets[0].data[1], null);
assert.equal(unavailable.chart.data.datasets[1].data[1], null);
const empty = render({ ...measured, repos: {} }, []);
assert.doesNotMatch(empty.html, /0%|0\.0%/);
const failed = structuredClone(measured);
failed.repos['org/repo'].ci.success_rate = 0;
assert.match(render(failed, []).html, /0\.0%/);
const mixed = render({ ...measured, repos: { ...measured.repos, other: unknown.repos['org/repo'] } }, []);
assert.match(mixed.html, /100\.0%/);
console.log('Adoption dashboard unknown/zero rendering tests passed');
"@
$dashboardOutput = $dashboardTest | node -
if ($LASTEXITCODE -ne 0) {
    throw "Adoption dashboard tests failed: $dashboardOutput"
}
Write-Host $dashboardOutput
}
