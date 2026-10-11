#Requires -Version 7.0
# Regression test for #3766: Copilot CLI parses every markdown file under
# .github/agents as a custom agent, so agent references must be projected elsewhere.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'scripts/dogfood-projection.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
$plan = @(Get-BaseCoatProjectionPlan -SourceRoot $repoRoot -Mode Consumer)
$sourceReferences = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'agents/references') -Recurse -File)
$projectedReferences = @($plan | Where-Object { $_.Kind -eq 'reference' })

if ($sourceReferences.Count -eq 0 -or $projectedReferences.Count -ne $sourceReferences.Count) {
    $failures.Add("Projected $($projectedReferences.Count) references, expected $($sourceReferences.Count).")
}
$misplaced = @($projectedReferences | Where-Object { $_.DestinationPath -notlike '.github/agent-references/*' })
if ($misplaced.Count -gt 0) { $failures.Add("References outside .github/agent-references: $($misplaced.Count)") }
$nonAgents = @($plan | Where-Object { $_.DestinationPath -like '.github/agents/*' -and $_.DestinationPath -notmatch '^\.github/agents/[^/]+\.agent\.md$' })
if ($nonAgents.Count -gt 0) { $failures.Add("Non-agent files projected under .github/agents: $($nonAgents.Count)") }

# Rewritten links must resolve inside the projected consumer layout, where sync installs
# BaseCoat docs (reference, guides, diagrams) under .github/base-coat/docs.
$projectedPaths = [System.Collections.Generic.HashSet[string]]::new([string[]]@($plan | ForEach-Object { $_.DestinationPath }))
foreach ($entry in $plan | Where-Object { $_.Kind -in @('agent', 'reference') }) {
    $text = Convert-BaseCoatProjectedText -Content (Get-Content -LiteralPath $entry.SourcePath -Raw) -Kind $entry.Kind -DocsPrefix '../../.github/base-coat/docs/'
    $baseDir = [System.IO.Path]::GetDirectoryName($entry.DestinationPath)
    $linkPattern = if ($entry.Kind -eq 'reference') { '\]\((\.\./[^)#\s]+)' } else { '\]\((\.\./(?:agent-references|agents)/[^)#\s]+)' }
    foreach ($link in [regex]::Matches($text, $linkPattern)) {
        $full = [System.IO.Path]::GetFullPath("/r/$baseDir/$($link.Groups[1].Value)")
        $target = ($full -replace '^.*?[\\/]r[\\/]', '') -replace '\\', '/'
        $resolved = if ($target -match '^\.github/base-coat/(docs/(?:reference|guides|diagrams)/.+)$') { Test-Path -LiteralPath (Join-Path $repoRoot $Matches[1]) } else { $projectedPaths.Contains($target) }
        if (-not $resolved) { $failures.Add("$($entry.DestinationPath): unresolved link $($link.Groups[1].Value)") }
    }
}

# CLI-backed discovery check. Runs when Copilot CLI is on PATH (skip with
# BASECOAT_SKIP_COPILOT_CLI=1); BASECOAT_REQUIRE_COPILOT_CLI=1 turns a missing CLI into a failure.
# An unknown --agent makes the CLI list discovered agents and exit before any model call.
# Adding the projected references must not change the discovered agent set.
$cli = if ($env:BASECOAT_SKIP_COPILOT_CLI -eq '1') { $null } else { Get-Command copilot -ErrorAction SilentlyContinue }
if (-not $cli) {
    if ($env:BASECOAT_REQUIRE_COPILOT_CLI -eq '1') { $failures.Add('Copilot CLI is required (BASECOAT_REQUIRE_COPILOT_CLI=1) but unavailable.') }
    else { Write-Host 'SKIP: Copilot CLI discovery check (copilot not on PATH).' }
}
else {
    $cliRoot = Join-Path $repoRoot 'test-results/agent-reference-cli'
    Remove-Item -LiteralPath $cliRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $cliRoot -Force | Out-Null
    git -C $cliRoot init -q
    $discover = {
        param([string]$Kind)
        foreach ($entry in $plan | Where-Object Kind -eq $Kind) {
            $destination = Join-Path $cliRoot $entry.DestinationPath
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            $text = Convert-BaseCoatProjectedText -Content (Get-Content -LiteralPath $entry.SourcePath -Raw) -Kind $Kind
            [System.IO.File]::WriteAllText($destination, $text, [System.Text.UTF8Encoding]::new($false))
        }
        Push-Location $cliRoot
        try { $output = (& $cli.Source --agent basecoat-discovery-probe -p probe 2>&1 | Out-String) }
        finally { Pop-Location }
        $listed = [regex]::Match($output, 'available:\s*(.+)')
        if (-not $listed.Success) { throw "Copilot CLI did not report discovered agents: $($output.Trim())" }
        [pscustomobject]@{ Output = $output; Agents = @($listed.Groups[1].Value.Trim() -split ',\s*' | Sort-Object) }
    }
    try {
        $baseline = & $discover 'agent'
        $withReferences = & $discover 'reference'
        if ($baseline.Agents.Count -lt 2) { $failures.Add('Copilot CLI discovered no projected agents.') }
        if (($baseline.Agents -join '|') -cne ($withReferences.Agents -join '|')) { $failures.Add('Projected references changed the Copilot CLI agent set.') }
        foreach ($reference in $projectedReferences) {
            if ($withReferences.Agents -contains [System.IO.Path]::GetFileNameWithoutExtension($reference.DestinationPath)) { $failures.Add("Copilot CLI discovered reference '$($reference.DestinationPath)' as an agent.") }
        }
        if ($withReferences.Output -match '(?i)frontmatter') { $failures.Add('Copilot CLI reported frontmatter diagnostics.') }
        Write-Host "Copilot CLI discovered $($withReferences.Agents.Count) agents; references were not discovered."
    }
    catch { $failures.Add($_.Exception.Message) }
    finally { Remove-Item -LiteralPath $cliRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
if ($failures.Count -gt 0) {
    $failures | Select-Object -First 20 | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host "Agent reference layout tests passed ($($sourceReferences.Count) references)."
