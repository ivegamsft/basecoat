$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$triagePath = Join-Path $repoRoot '.github\workflows\issue-triage.md'
$synthesisPath = Join-Path $repoRoot '.github\workflows\issue-to-spec-synthesis.yml'

function Assert-Match {
    param([string]$Content, [string]$Pattern, [string]$Message)

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$triage = Get-Content $triagePath -Raw
$synthesis = Get-Content $synthesisPath -Raw

Assert-Match $triage 'Apply the `synthesize-spec` label' 'Triage must trigger synthesis when it applies needs-prd.'
Assert-Match $triage 'Only apply `needs-info` when the issue failed' 'Triage must not add needs-info to otherwise actionable issues.'
Assert-Match $synthesis 'const prdPath = `docs/prd/synthesized/' 'Synthesis must generate a PRD artifact.'
Assert-Match $synthesis 'const specPath = `docs/spec/synthesized/' 'Synthesis must generate a spec artifact.'
Assert-Match $synthesis 'path: prdPath' 'Synthesis must write the generated PRD.'
Assert-Match $synthesis 'PRD and spec synthesized from this issue' 'Source issue must link to the generated artifacts.'

Write-Host 'PASS needs-prd to PRD/spec synthesis contract.'
