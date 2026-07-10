param(
    [int]$ReleaseCount = 3,
    [string]$OutputDir = 'reports/release-notes'
)

$ErrorActionPreference = 'Stop'

if ($ReleaseCount -lt 1) {
    throw 'ReleaseCount must be >= 1.'
}

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'Run this script inside a git repository.'
}

Set-Location $repoRoot

$tags = git --no-pager tag --sort=-creatordate | Where-Object { $_ -match '^v' } | Select-Object -First ([Math]::Max($ReleaseCount + 1, 2))
if ($tags.Count -lt 2) {
    throw 'Need at least two version tags to validate release-note ranges.'
}

$ranges = @()
for ($i = 0; $i -lt [Math]::Min($ReleaseCount, $tags.Count - 1); $i++) {
    $ranges += [pscustomobject]@{
        Head = $tags[$i]
        Base = $tags[$i + 1]
    }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $OutputDir "validation-$timestamp.md"
$latestPath = Join-Path $OutputDir "latest.md"

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Release Notes Validation Report')
$lines.Add('')
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ssK')")
$lines.Add("Repository: $(git remote get-url origin 2>$null)")
$lines.Add('')

foreach ($r in $ranges) {
    $baseDate = git --no-pager log -1 --format=%cI $r.Base
    $headDate = git --no-pager log -1 --format=%cI $r.Head
    $search = "base:main merged:>=$baseDate merged:<=$headDate"
    $prs = gh pr list --state merged --limit 400 --search $search --json number,title,labels,author | ConvertFrom-Json

    $waveLabels = @($prs | ForEach-Object { $_.labels | ForEach-Object { $_.name } } | Where-Object { $_ -match '^wave:' } | Sort-Object -Unique)
    $sprintLabels = @($prs | ForEach-Object { $_.labels | ForEach-Object { $_.name } } | Where-Object { $_ -match '^sprint:' } | Sort-Object -Unique)
    $highlights = @($prs | Where-Object { $_.title -match '^(feat|perf|refactor)(\(|:)' } | Select-Object -First 5)
    $fixes = @($prs | Where-Object { $_.title -match '^(fix|hotfix)(\(|:)' -or $_.title -match 'bug|error|resolve' } | Select-Object -First 5)

    $lines.Add("## $($r.Head) ($($r.Base)..$($r.Head))")
    $lines.Add('')
    $lines.Add("- PRs in window: $($prs.Count)")
    $lines.Add("- Waves: $(if ($waveLabels.Count) { $waveLabels -join ', ' } else { 'N/A' })")
    $lines.Add("- Sprints: $(if ($sprintLabels.Count) { $sprintLabels -join ', ' } else { 'N/A' })")
    $lines.Add("- Binding status: $(if ($waveLabels.Count -or $sprintLabels.Count) { 'OK' } else { 'Needs confirmation' })")
    $lines.Add('')
    $lines.Add('### Highlights')
    if ($highlights.Count) {
        foreach ($pr in $highlights) {
            $lines.Add("- $($pr.title) (PR #$($pr.number))")
        }
    } else {
        $lines.Add('- None identified')
    }
    $lines.Add('')
    $lines.Add('### Fixes and improvements')
    if ($fixes.Count) {
        foreach ($pr in $fixes) {
            $lines.Add("- $($pr.title) (PR #$($pr.number))")
        }
    } else {
        $lines.Add('- None identified')
    }
    $lines.Add('')
}

Set-Content -Path $reportPath -Value ($lines -join "`n") -NoNewline
Set-Content -Path $latestPath -Value ($lines -join "`n") -NoNewline

Write-Host "Release-note validation report written:"
Write-Host " - $reportPath"
Write-Host " - $latestPath"
