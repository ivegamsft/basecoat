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
if ($changelog -match 'Closes #183\.') {
    throw 'Changelog PR creation must not close unrelated tracking issues from the generated PR body.'
}
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

# Behavioral regression guard for the changelog insertion logic (issue #3365).
# Execute the extracted insertion heredoc against a fixture CHANGELOG and a
# generator-style notes file (which carries its own "## <version>" heading, an
# Unreleased section with stale body, and a prior release). Assert the result
# has exactly one dated version heading (no duplicate H2), a reset Unreleased
# placeholder with the stale body dropped, and preserved prior history.
$fixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("changelog-insert-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureDir | Out-Null
try {
    $changelogFixture = @'
# Changelog

## Unreleased

- Stale pending note that must not survive insertion.

## 4.4.0 - 2026-09-11

### Fixed

- old fix (#1)
'@
    $notesFixture = @'
## 5.0.0

### Added

- feat: brand new capability (#100)
'@
    Set-Content -Path (Join-Path $fixtureDir 'CHANGELOG.md') -Value $changelogFixture -NoNewline
    $notesPath = Join-Path $fixtureDir 'notes.md'
    Set-Content -Path $notesPath -Value $notesFixture -NoNewline

    $env:NOTES_FILE = $notesPath
    $env:VERSION = '5.0.0'
    $env:DATE_UTC = '2026-10-01'
    Push-Location $fixtureDir
    try {
        $heredocBody | python -
        if ($LASTEXITCODE -ne 0) { throw 'The changelog insertion heredoc failed to execute against the fixture.' }
    } finally {
        Pop-Location
    }

    $result = ((Get-Content (Join-Path $fixtureDir 'CHANGELOG.md') -Raw) -replace "`r", '')

    $versionHeadingCount = ([regex]::Matches($result, '(?m)^## 5\.0\.0')).Count
    if ($versionHeadingCount -ne 1) {
        throw "Changelog insertion produced $versionHeadingCount H2 headings for the new version; expected exactly one (duplicate-heading regression, issue #3365)."
    }
    Assert-Match $result '(?m)^## 5\.0\.0 - 2026-10-01$' 'Inserted release section must carry the single dated version heading.'
    if ($result -match 'Stale pending note that must not survive') {
        throw 'Changelog insertion re-emitted the previous Unreleased body (stale-Unreleased regression, issue #3365).'
    }
    Assert-Match $result '(?m)^- No unreleased changes\.$' 'Insertion must reset the Unreleased section to an empty placeholder.'
    Assert-Match $result '(?m)^## 4\.4\.0 - 2026-09-11$' 'Insertion must preserve prior release history.'

    $newIdx = $result.IndexOf('## 5.0.0 - 2026-10-01')
    $oldIdx = $result.IndexOf('## 4.4.0 - 2026-09-11')
    if ($newIdx -lt 0 -or $oldIdx -lt 0 -or $newIdx -ge $oldIdx) {
        throw 'The inserted release section must appear above the previous release entry.'
    }
    Write-Host 'PASS changelog insertion logic (single dated heading, reset Unreleased, preserved history).'
} finally {
    Remove-Item -Path $fixtureDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item Env:NOTES_FILE -ErrorAction SilentlyContinue
    Remove-Item Env:VERSION -ErrorAction SilentlyContinue
    Remove-Item Env:DATE_UTC -ErrorAction SilentlyContinue
}

# Behavioral regression guard for the release fail-closed version assertion
# (issue #3366). The release workflow must refuse to publish when the tagged
# commit's version.json does not already match the release tag, so a tag can
# never silently outrun the committed tree. Extract the actual step body from
# release.yml and execute it against a fixture for a matching and a mismatching
# tag, asserting the mismatch exits nonzero.
function Get-WorkflowStepRunBlock {
    param([string[]]$Lines, [string]$StepName)

    $runIdx = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match [regex]::Escape("name: $StepName")) {
            for ($j = $i; $j -lt $Lines.Count; $j++) {
                if ($Lines[$j] -match '^\s*run:\s*\|') { $runIdx = $j; break }
            }
            break
        }
    }
    if ($runIdx -lt 0) { throw "Could not locate the '$StepName' run block in release.yml." }

    $keyIndent = $Lines[$runIdx].Length - $Lines[$runIdx].TrimStart().Length
    $blockLines = @()
    for ($i = $runIdx + 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line.Trim() -eq '') { $blockLines += ''; continue }
        $lead = $line.Length - $line.TrimStart().Length
        if ($lead -le $keyIndent) { break }
        $blockLines += $line
    }
    $nonEmpty = $blockLines | Where-Object { $_ -ne '' }
    $minIndent = ($nonEmpty | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    return (@($blockLines | ForEach-Object { if ($_ -eq '') { '' } else { $_.Substring($minIndent) } }) -join "`n")
}

function Get-WorkingBash {
    $candidates = @('bash')
    if ($IsWindows) {
        $candidates += @(
            (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
        )
    }
    foreach ($candidate in $candidates) {
        $resolved = (Get-Command $candidate -ErrorAction SilentlyContinue)?.Source
        if (-not $resolved) { continue }
        try {
            & $resolved -c 'exit 0' *> $null
            if ($LASTEXITCODE -eq 0) { return $resolved }
        } catch { }
    }
    return $null
}

$bashExe = Get-WorkingBash
if ($bashExe) {
    # Every tag publisher must fail closed when version.json does not already
    # match the release tag (issue #3366). Exercise the extracted step from each
    # publishing workflow for a matching and a mismatching tag.
    $tagPublishers = @(
        $releasePath,
        (Join-Path $repoRoot '.github\workflows\package-basecoat.yml')
    )

    function Invoke-ReleaseAssertStep {
        param([string]$StepBody, [string]$Tag, [string]$Bash)

        $harness = @"
set -euo pipefail
export GITHUB_REF_NAME='$Tag'
work="`$(mktemp -d)"
cd "`$work"
printf '%s' '{ "name": "base-coat", "version": "4.4.0" }' > version.json
$StepBody
"@
        & $Bash -c $harness *> $null
        return $LASTEXITCODE
    }

    foreach ($publisher in $tagPublishers) {
        $publisherName = Split-Path $publisher -Leaf
        $publisherLines = Get-Content $publisher
        $assertStep = Get-WorkflowStepRunBlock -Lines $publisherLines -StepName 'Assert committed version metadata matches release tag'

        if ($assertStep -notmatch 'committed_version.*!=.*expected_version' -and $assertStep -notmatch 'expected_version.*!=.*committed_version') {
            throw "$publisherName version-assertion step no longer compares committed version.json against the release tag."
        }

        $matchExit = Invoke-ReleaseAssertStep -StepBody $assertStep -Tag 'v4.4.0' -Bash $bashExe
        $mismatchExit = Invoke-ReleaseAssertStep -StepBody $assertStep -Tag 'v4.5.0' -Bash $bashExe

        if ($matchExit -ne 0) {
            throw "$publisherName version-assertion step failed for a matching tag (exit $matchExit); it must allow release when version.json matches the tag."
        }
        if ($mismatchExit -eq 0) {
            throw "$publisherName version-assertion step passed for a mismatched tag; it must fail closed when version.json does not match the tag."
        }
        Write-Host "PASS $publisherName fail-closed version assertion (match=0, mismatch=nonzero)."
    }
} else {
    throw 'A working bash is required to exercise the release fail-closed version assertion.'
}

Assert-Match $publish "'docs/operations/repo-story\.md'" 'Publication must exclude repo-story because it contains internal chronicle details and issue links.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/issues/\[0-9\]\+' 'Publication must redact private source issue URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/pull/\[0-9\]\+' 'Publication must redact private source PR URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/actions/runs/\[0-9\]\+' 'Publication must redact private source workflow-run URLs before generic repo rewrites.'
Assert-Match $publish "git grep -inI -E 'ibuyspy-shared\|ibuyspy-dev'" 'Publication must fail if internal organization identifiers remain in the public payload.'

Write-Host 'PASS release-note publication contract.'
