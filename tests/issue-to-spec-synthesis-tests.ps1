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
Assert-Match $synthesis 'Recovering existing synthesis branch without a PR' 'Synthesis retries must recover a branch created before PR creation failed.'
Assert-Match $synthesis 'workflow_dispatch:' 'Synthesis must support manual/backfill reconciliation.'
Assert-Match $synthesis 'workflow_run:' 'Synthesis must reconcile labels after issue-triage completes because workflow-token label events do not trigger workflows.'
Assert-Match $synthesis 'findPendingIssue' 'Synthesis must find the oldest open needs-prd issue when reconciling.'
Assert-Match $synthesis 'writeGithub\.rest\.issues\.removeLabel' 'Synthesis must remove stale intake labels with the configured write-token client.'
Assert-Match $synthesis 'name: label' 'Synthesis label cleanup must remove the current stale label from the helper loop.'
Assert-Match $synthesis "'needs-prd', 'synthesize-spec', 'needs-info'" 'Synthesis must clear needs-prd, synthesize-spec, and obsolete needs-info labels.'
Assert-Match $synthesis ":\s+'\*Not specified\.\*'" 'Generated fallback text must use MarkdownLint-compliant asterisk emphasis.'
Assert-Match $synthesis '`- Issue: <https://github\.com/\$\{context\.repo\.owner\}/\$\{context\.repo\.repo\}/issues/\$\{issueNum\}>' 'Generated issue references must use MarkdownLint-compliant angle-bracketed URLs.'

Write-Host 'PASS needs-prd to PRD/spec synthesis contract.'
