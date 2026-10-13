#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$auditScript = Join-Path $repoRoot 'scripts/label-taxonomy-audit.ps1'
$registryPath = Join-Path $repoRoot '.github/governance/label-taxonomy.json'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) { Write-Host "  PASS $Name" } else { Write-Host "  FAIL $Name $Detail" -ForegroundColor Red; $failures.Add($Name) }
}

Write-Host 'Label taxonomy tests'

& pwsh -NoProfile -File $auditScript -RepoRoot $repoRoot | Out-Null
Assert-True 'repository registry is valid and no workflow or script writes a deprecated label' ($LASTEXITCODE -eq 0) "(exit $LASTEXITCODE)"

. $auditScript -RepoRoot $repoRoot
$taxonomy = Get-Content -Path $registryPath -Raw | ConvertFrom-Json

$fixture = Join-Path $PSScriptRoot ".label-taxonomy-fixture-$PID"
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture '.github/workflows'), (Join-Path $fixture 'scripts'), (Join-Path $fixture 'skills/demo') -Force | Out-Null
    Set-Content -Path (Join-Path $fixture '.github/workflows/writer.yml') -Value @("          labels: ['size/m', 'size:M']", "          if (labels.includes('risk-high')) return 'high';",
        "          labels:", "            - risk-critical", "            - 'size:M'", "      - run: gh label create P1-high --color FF0000", "      - run: gh issue list --label risk-high", "      - run: gh label edit risk-high --name risk:high", "      - run: gh issue edit 1 --remove-label 'risk-high' --add-label size/l", "      - run: gh issue edit 2 --add-label ""size/s,bug""", "          labels: [sprint-7, bug]")
    Set-Content -Path (Join-Path $fixture 'scripts/dispatch.ps1') -Value @('$commonLabels = @("intent-control-plane", "risk-$RiskBand")', '$sprintLabel = "sprint:$week"',
        '$legacyPriorityLabels = @(', '    "P1-high"', ')')
    Set-Content -Path (Join-Path $fixture '.github/workflows/agent.md') -Value 'Add the `good-first-issue` label when approachable; keep `docs/` links.'; Set-Content -Path (Join-Path $fixture 'skills/demo/SKILL.md') -Value @('Apply the `risk-medium` label to risky changes.', 'Legacy labels (`P1-high`) are normalized during triage.')

    $findings = Find-DeprecatedLabelWrite -Root $fixture -Taxonomy $taxonomy
    $found = ($findings | ForEach-Object { "$($_.Path)=$($_.Deprecated)" } | Sort-Object) -join ','
    Assert-True 'scan flags literal, multiline, bare, interpolated, and prompt writes but not readers or canonical labels' `
        ($found -eq '.github/workflows/agent.md=good-first-issue,.github/workflows/writer.yml=P1-high,.github/workflows/writer.yml=risk-critical,.github/workflows/writer.yml=size/l,.github/workflows/writer.yml=size/m,.github/workflows/writer.yml=size/s,.github/workflows/writer.yml=sprint-7,scripts/dispatch.ps1=risk-low,skills/demo/SKILL.md=risk-medium') "(found: $found)"

    & pwsh -NoProfile -File $auditScript -RepoRoot $fixture -RegistryPath $registryPath *> $null
    Assert-True 'audit exits non-zero when a deprecated label is written' ($LASTEXITCODE -eq 1) "(exit $LASTEXITCODE)"

    $live = @('size/m', 'size:M', 'risk-high', 'sprint-7', 'sprint-2026-07', 'mystery', 'sprint:2026-W41', 'wave:2', 'wave/sprint', 'bug')
    $drift = Get-LabelDrift -LiveLabels $live -Taxonomy $taxonomy
    $ops = ($drift.Deprecated | ForEach-Object { "$($_.Name)>$($_.Operation)>$($_.Replacement)" }) -join ','
    Assert-True 'drift picks migrate-delete when the canonical label exists and rename when it does not' `
        ($ops -eq 'risk-high>rename>risk:high,size/m>migrate-delete>size:M,sprint-2026-07>remove>,sprint-7>rename>sprint:7') "(ops: $ops)"
    Assert-True 'drift reports labels outside the taxonomy as unknown' (($drift.Unknown -join ',') -eq 'mystery') "(unknown: $($drift.Unknown -join ','))"
    Assert-True 'missing canonical labels exclude rename targets' (('enhancement' -in $drift.Missing) -and ('risk:high' -notin $drift.Missing))
    $aliasOps = ((Get-LabelDrift -LiveLabels @('P1-high', 'priority/high') -Taxonomy $taxonomy).Deprecated | ForEach-Object Operation) -join ','
    Assert-True 'only one alias renames to an absent canonical target' ($aliasOps -eq 'rename,migrate-delete') "(ops: $aliasOps)"

    $labelsJson = Join-Path $fixture 'labels.json'
    ConvertTo-Json -InputObject @($live | ForEach-Object { @{ name = $_ } }) | Set-Content -Path $labelsJson
    $reportPath = Join-Path $fixture 'drift.md'
    & pwsh -NoProfile -File $auditScript -RepoRoot $repoRoot -LabelsJsonPath $labelsJson -ReportPath $reportPath -FailOnDrift *> $null
    Assert-True '-FailOnDrift rejects non-canonical live labels' ($LASTEXITCODE -eq 1) "(exit $LASTEXITCODE)"
    Assert-True 'drift report lists proposed operations' ((Get-Content -Path $reportPath -Raw) -match '\| `size/m` \| migrate-delete \| `size:M` \|')
    $canonicalOnly = @((Get-CanonicalLabelSet -Taxonomy $taxonomy) | Where-Object { $_ -ne 'enhancement' })
    ConvertTo-Json -InputObject @($canonicalOnly | ForEach-Object { @{ name = $_ } }) | Set-Content -Path $labelsJson
    & pwsh -NoProfile -File $auditScript -RepoRoot $repoRoot -LabelsJsonPath $labelsJson -FailOnDrift *> $null
    Assert-True '-FailOnDrift rejects missing canonical labels' ($LASTEXITCODE -eq 1) "(exit $LASTEXITCODE)"

    $broken = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $broken.deprecated += [pscustomobject]@{ name = 'bug'; replacement = 'defect'; operation = 'migrate-delete' }
    $errors = Test-LabelTaxonomy -Taxonomy $broken
    Assert-True 'registry validation rejects canonical-and-deprecated names and non-canonical replacements' ($errors.Count -eq 2) "(errors: $($errors -join '; '))"
}
finally {
    Remove-Item -Path $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

if ($failures.Count) {
    Write-Host "$($failures.Count) label taxonomy test(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'Label taxonomy tests passed.'
