$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releasePath = Join-Path $repoRoot '.github\workflows\release.yml'
$changelogPath = Join-Path $repoRoot '.github\workflows\release-changelog-generation.yml'
$publishPath = Join-Path $repoRoot '.github\workflows\publish-to-production.yml'

function Assert-Match {
    param([string]$Content, [string]$Pattern, [string]$Message)

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$release = Get-Content $releasePath -Raw
$changelog = Get-Content $changelogPath -Raw
$publish = Get-Content $publishPath -Raw

Assert-Match $release 'actions:\s+write' 'Release workflow must have actions: write to dispatch changelog publication.'
Assert-Match $release 'gh workflow run release-changelog-generation\.yml' 'Release workflow must explicitly dispatch changelog publication.'
Assert-Match $release '-f "tag=\$\{GITHUB_REF_NAME\}"' 'Release workflow must dispatch the tag being released.'
Assert-Match $changelog 'reports/release-notes/latest\.md' 'Changelog workflow must publish the latest release notes surface.'
Assert-Match $changelog 'git add CHANGELOG\.md "\$latest_notes_file"' 'Changelog workflow must commit both changelog and latest release notes.'
Assert-Match $changelog 'git diff --quiet -- CHANGELOG\.md "\$latest_notes_file"' 'Changelog workflow must publish latest notes even when the changelog entry exists.'
Assert-Match $changelog 'GH_TOKEN:\s*\$\{\{\s*secrets\.GH_AW_GITHUB_TOKEN\s*\|\|\s*github\.token\s*\}\}' 'Changelog PR creation must use the configured write token when available.'
Assert-Match $changelog '(?m)^[ ]{10}PY\r?$' 'The Python heredoc terminator must align with the run block, producing shell column zero.'

# Reconstruct the 'Generate changelog entry' run script exactly as bash receives
# it (YAML dedents the block scalar) and confirm the embedded Python heredoc
# compiles. This exercises the real IndentationError failure mode across every
# top-level statement, not just the first import line (regression guard for #3363).
$changelogLines = Get-Content $changelogPath
$runIdx = -1
for ($i = 0; $i -lt $changelogLines.Count; $i++) {
    if ($changelogLines[$i] -match 'name:\s*Generate changelog entry') {
        for ($j = $i; $j -lt $changelogLines.Count; $j++) {
            if ($changelogLines[$j] -match '^\s*run:\s*\|') { $runIdx = $j; break }
        }
        break
    }
}
if ($runIdx -lt 0) { throw 'Could not locate the Generate changelog entry run block.' }
$keyIndent = $changelogLines[$runIdx].Length - $changelogLines[$runIdx].TrimStart().Length
$runLines = @()
for ($i = $runIdx + 1; $i -lt $changelogLines.Count; $i++) {
    $line = $changelogLines[$i]
    if ($line.Trim() -eq '') { $runLines += ''; continue }
    $lead = $line.Length - $line.TrimStart().Length
    if ($lead -le $keyIndent) { break }
    $runLines += $line
}
$nonEmpty = $runLines | Where-Object { $_ -ne '' }
$minIndent = ($nonEmpty | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
$dedented = @($runLines | ForEach-Object { if ($_ -eq '') { '' } else { $_.Substring($minIndent) } })
$startIdx = -1
for ($i = 0; $i -lt $dedented.Count; $i++) { if ($dedented[$i] -match "<<'PY'") { $startIdx = $i; break } }
if ($startIdx -lt 0) { throw 'Could not locate the Python heredoc opener.' }
$endIdx = -1
for ($i = $startIdx + 1; $i -lt $dedented.Count; $i++) { if ($dedented[$i] -eq 'PY') { $endIdx = $i; break } }
if ($endIdx -lt 0) { throw 'Could not locate the Python heredoc terminator.' }
$heredocBody = ($dedented[($startIdx + 1)..($endIdx - 1)] -join "`n")
$heredocBody | python -c 'import sys; compile(sys.stdin.read(), "<changelog-heredoc>", "exec")'
if ($LASTEXITCODE -ne 0) {
    throw 'The changelog heredoc body does not compile (IndentationError regression from #3363).'
}
Assert-Match $publish "'docs/operations/repo-story\.md'" 'Publication must exclude repo-story because it contains internal chronicle details and issue links.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/issues/\[0-9\]\+' 'Publication must redact private source issue URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/pull/\[0-9\]\+' 'Publication must redact private source PR URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/actions/runs/\[0-9\]\+' 'Publication must redact private source workflow-run URLs before generic repo rewrites.'
Assert-Match $publish "git grep -inI -E 'ibuyspy-shared\|ibuyspy-dev'" 'Publication must fail if internal organization identifiers remain in the public payload.'

Write-Host 'PASS release-note publication contract.'
