$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$releasePath = Join-Path $repoRoot '.github\workflows\release.yml'
$changelogPath = Join-Path $repoRoot '.github\workflows\release-changelog-generation.yml'

function Assert-Match {
    param([string]$Content, [string]$Pattern, [string]$Message)

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$release = Get-Content $releasePath -Raw
$changelog = Get-Content $changelogPath -Raw

Assert-Match $release 'actions:\s+write' 'Release workflow must have actions: write to dispatch changelog publication.'
Assert-Match $release 'gh workflow run release-changelog-generation\.yml' 'Release workflow must explicitly dispatch changelog publication.'
Assert-Match $release '-f "tag=\$\{GITHUB_REF_NAME\}"' 'Release workflow must dispatch the tag being released.'
Assert-Match $changelog 'reports/release-notes/latest\.md' 'Changelog workflow must publish the latest release notes surface.'
Assert-Match $changelog 'git add CHANGELOG\.md "\$latest_notes_file"' 'Changelog workflow must commit both changelog and latest release notes.'
Assert-Match $changelog 'git diff --quiet -- CHANGELOG\.md "\$latest_notes_file"' 'Changelog workflow must publish latest notes even when the changelog entry exists.'
Assert-Match $changelog '(?m)^[ ]{10}PY\r?$' 'The Python heredoc terminator must align with the run block, producing shell column zero.'

Write-Host 'PASS release-note publication contract.'
