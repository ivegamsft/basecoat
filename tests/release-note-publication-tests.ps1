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
Assert-Match $publish "'docs/operations/repo-story\.md'" 'Publication must exclude repo-story because it contains internal chronicle details and issue links.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/issues/\[0-9\]\+' 'Publication must redact private source issue URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/pull/\[0-9\]\+' 'Publication must redact private source PR URLs before generic repo rewrites.'
Assert-Match $publish 'https://github\\\.com/IBuySpy-Shared/basecoat/actions/runs/\[0-9\]\+' 'Publication must redact private source workflow-run URLs before generic repo rewrites.'
Assert-Match $publish "git grep -inI -E 'ibuyspy-shared\|ibuyspy-dev'" 'Publication must fail if internal organization identifiers remain in the public payload.'

Write-Host 'PASS release-note publication contract.'
