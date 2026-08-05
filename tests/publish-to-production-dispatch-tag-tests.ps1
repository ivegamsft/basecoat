$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running publish-to-production dispatch tag tests...'

$workflowPath = Join-Path $repoRoot '.github\workflows\publish-to-production.yml'
if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}

$content = Get-Content $workflowPath -Raw

if ($content -notmatch '(?m)^\s{2}workflow_dispatch:\s*$') {
    throw 'publish-to-production.yml is missing workflow_dispatch trigger'
}

if ($content -match '(?m)^\s{8}default:\s*"v\d+\.\d+\.\d+"\s*$') {
    throw 'publish-to-production.yml still contains a hard-coded semver default for workflow_dispatch tag input'
}

if ($content -notmatch '(?m)^\s{8}required:\s*false\s*$') {
    throw 'publish-to-production.yml should make workflow_dispatch tag input optional to allow latest-tag resolution'
}

if ($content -notmatch '(?m)^\s{6}- name:\s*Resolve publish tag\s*$') {
    throw 'publish-to-production.yml is missing "Resolve publish tag" step'
}

if ($content -notmatch '(?m)^\s{8}id:\s*resolve_tag\s*$') {
    throw 'publish-to-production.yml is missing resolve_tag step id'
}

if ($content -notmatch "git tag --list 'v\[0-9\]\*\.\[0-9\]\*\.\[0-9\]\*' --sort=-v:refname") {
    throw 'publish-to-production.yml does not resolve latest semver tag when input is empty'
}

if ($content -notmatch '(?m)^\s{10}ref:\s*refs/tags/\$\{\{\s*steps\.resolve_tag\.outputs\.tag\s*\}\}\s*$') {
    throw 'publish-to-production.yml checkout step is not pinned to resolved publish tag'
}

if ($content -match 'TAG:\s*\$\{\{\s*inputs\.tag\s*\|\|\s*github\.ref_name\s*\}\}') {
    throw 'publish-to-production.yml still uses legacy TAG fallback expression'
}

if ($content -notmatch 'TAG:\s*\$\{\{\s*steps\.resolve_tag\.outputs\.tag\s*\}\}') {
    throw 'publish-to-production.yml does not propagate resolved tag into publish steps'
}

# Regression (#2703): the production mirror must not receive internal workflows or
# Dependabot configuration. docs.yml is the only public workflow because the source
# repository dispatches it after a successful publish.
if ($content -notmatch "(?m)^\s{12}'\.github/dependabot\.yml'\s*$") {
    throw 'publish-to-production.yml must remove .github/dependabot.yml from the public mirror payload'
}

$publicWorkflowBlock = [regex]::Match(
    $content,
    "(?ms)^\s{10}PUBLIC_WORKFLOWS=\(\s*\r?\n(?<entries>.*?)^\s{10}\)\s*$"
)
if (-not $publicWorkflowBlock.Success) {
    throw 'publish-to-production.yml is missing the explicit public workflow allowlist'
}

$publicWorkflows = @(
    [regex]::Matches($publicWorkflowBlock.Groups['entries'].Value, "'([^']+)'") |
        ForEach-Object { $_.Groups[1].Value }
)
if ($publicWorkflows.Count -ne 1 -or $publicWorkflows[0] -ne '.github/workflows/docs.yml') {
    throw 'publish-to-production.yml must retain only docs.yml for production documentation dispatch'
}

if ($content -notmatch "git ls-files -- ':\(glob\)\.github/workflows/\*\*'") {
    throw 'publish-to-production.yml must recursively enumerate every mirrored workflow for internal workflow removal'
}

if ($content -notmatch 'if is_public_workflow "\$workflow"') {
    throw 'publish-to-production.yml must preserve only allowlisted public workflows'
}

foreach ($requiredInternalPattern in @(
        'tests/**',
        ':(glob)**/tests/**',
        ':(glob)**/*.test.*',
        'analysis/**',
        'docs/archive/**',
        'docs/operations/github-secrets.md',
        '.github/instructions/**'
    )) {
    if ($content -notmatch [regex]::Escape("'$requiredInternalPattern'")) {
        throw "publish-to-production.yml must remove internal artifact pattern: $requiredInternalPattern"
    }
}

if ($content -notmatch "git grep -inI -E 'ibuyspy-shared\|ibuyspy-dev'") {
    throw 'publish-to-production.yml must scan the generated payload for forbidden internal identifiers'
}

if (-not $content.Contains('^LICENSE:3:Copyright \(c\) 2025 IBuySpy-Shared$')) {
    throw 'publish-to-production.yml must narrowly allowlist only the LICENSE legal attribution'
}

$removeStepStart = $content.IndexOf('      - name: Remove internal-only content before publish')
$nextStepStart = $content.IndexOf('      - name: Stamp published version')
if ($removeStepStart -lt 0 -or $nextStepStart -le $removeStepStart) {
    throw 'Unable to extract the internal-only content removal step for payload validation'
}

$removeStep = $content.Substring($removeStepStart, $nextStepStart - $removeStepStart)
$runMarker = '        run: |'
$runMarkerStart = $removeStep.IndexOf($runMarker)
if ($runMarkerStart -lt 0) {
    throw 'Internal-only content removal step is missing its run block'
}

$scriptBlock = $removeStep.Substring($runMarkerStart + $runMarker.Length) -replace "^\r?\n", ''
$scriptLines = @(
    $scriptBlock -split "\r?\n" |
        ForEach-Object {
            if ($_.StartsWith('          ')) {
                $_.Substring(10)
            }
            else {
                $_
            }
        }
)

$sanitizeStepStart = $content.IndexOf('      - name: Sanitize internal identifiers for production')
$pushStepStart = $content.IndexOf('      - name: Push to production repository')
if ($sanitizeStepStart -lt 0 -or $pushStepStart -le $sanitizeStepStart) {
    throw 'Unable to extract the identifier sanitization step for payload validation'
}

$sanitizeStep = $content.Substring($sanitizeStepStart, $pushStepStart - $sanitizeStepStart)
$sanitizeRunMarkerStart = $sanitizeStep.IndexOf($runMarker)
if ($sanitizeRunMarkerStart -lt 0) {
    throw 'Identifier sanitization step is missing its run block'
}

$sanitizeScriptBlock = $sanitizeStep.Substring($sanitizeRunMarkerStart + $runMarker.Length) -replace "^\r?\n", ''
$sanitizeScriptLines = @(
    $sanitizeScriptBlock -split "\r?\n" |
        ForEach-Object {
            if ($_.StartsWith('          ')) {
                $_.Substring(10)
            }
            else {
                $_
            }
        }
)

$scratchRoot = Join-Path $repoRoot ('test-results\publish-payload-' + [Guid]::NewGuid().ToString('N'))
$locationPushed = $false
try {
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot '.github\workflows') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot '.github\workflows\nested') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot '.github\instructions') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'analysis') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'component\tests') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'docs\memory') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'docs\sprint-plans') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'scripts\adoption') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scratchRoot 'skills\dotnet-modernization') -Force | Out-Null
    Set-Content -Path (Join-Path $scratchRoot '.github\workflows\docs.yml') -Value 'name: Public docs'
    Set-Content -Path (Join-Path $scratchRoot '.github\workflows\internal.yml') -Value 'name: Internal automation'
    Set-Content -Path (Join-Path $scratchRoot '.github\workflows\internal.md') -Value 'Internal agentic workflow source'
    Set-Content -Path (Join-Path $scratchRoot '.github\workflows\nested\internal.yml') -Value 'name: Nested internal automation'
    Set-Content -Path (Join-Path $scratchRoot '.github\instructions\internal.md') -Value 'IBuySpy-Shared internal instructions'
    Set-Content -Path (Join-Path $scratchRoot '.github\dependabot.yml') -Value 'version: 2'
    Set-Content -Path (Join-Path $scratchRoot 'analysis\evidence.json') -Value '{"org":"IBuySpy-Dev"}'
    Set-Content -Path (Join-Path $scratchRoot 'component\tests\internal.ps1') -Value 'IBuySpy-Shared test fixture'
    Set-Content -Path (Join-Path $scratchRoot 'component\widget.test.js') -Value 'const org = "IBuySpy-Dev";'
    Set-Content -Path (Join-Path $scratchRoot 'docs\sprint-plans\internal.md') -Value 'IBuySpy-Shared internal plan'
    Set-Content -Path (Join-Path $scratchRoot 'docs\public.md') -Value 'Install from https://github.com/IBuySpy-Shared/basecoat.'
    Set-Content -Path (Join-Path $scratchRoot 'SPRINT-99-EXECUTION-SUMMARY.md') -Value 'Internal summary'
    Set-Content -Path (Join-Path $scratchRoot 'CHANGELOG.md') -Value @(
        'IBuySpy-Shared repos received this feature.',
        'Shared memory used IBuySpy-Shared/basecoat-memory.'
    )
    Set-Content -Path (Join-Path $scratchRoot 'CONTRIBUTING.md') -Value 'export DASHBOARD_ORG="IBuySpy-Shared"'
    Set-Content -Path (Join-Path $scratchRoot 'docs\memory\shared-memory-guide.md') `
        -Value 'Template example: IBuySpy-Shared/basecoat-memory'
    Set-Content -Path (Join-Path $scratchRoot 'LICENSE') -Value @(
        'MIT License',
        '',
        'Copyright (c) 2025 IBuySpy-Shared'
    )
    Set-Content -Path (Join-Path $scratchRoot 'mkdocs.yml') -Value @(
        "copyright: 'Copyright &copy; IBuySpy-Shared contributors. Licensed under MIT.'",
        'nav:',
        '  - PR Flow Hygiene: reference/workflows/pr-flow-hygiene.md'
    )
    Set-Content -Path (Join-Path $scratchRoot 'scripts\adoption\detect-basecoat.ps1') -Value '[string]$Org = "IBuySpy-Shared"'
    Set-Content -Path (Join-Path $scratchRoot 'scripts\submit-learning.sh') -Value @(
        '# --memory-repo (default: IBuySpy-Shared/basecoat-memory)',
        'MEMORY_REPO="${BASECOAT_SHARED_MEMORY_REPO:-IBuySpy-Shared/basecoat-memory}"',
        'errors=()'
    )
    Set-Content -Path (Join-Path $scratchRoot 'scripts\submit-learning.ps1') -Value @(
        'Target memory repository. Default: env BASECOAT_SHARED_MEMORY_REPO or IBuySpy-Shared/basecoat-memory.',
        '[string]$MemoryRepo = ($env:BASECOAT_SHARED_MEMORY_REPO ?? "IBuySpy-Shared/basecoat-memory"),',
        '$errors = [System.Collections.Generic.List[string]]::new()'
    )
    Set-Content -Path (Join-Path $scratchRoot 'skills\dotnet-modernization\SKILL.md') -Value 'author: IBuySpy-Shared'

    Push-Location $scratchRoot
    $locationPushed = $true
    git init --quiet
    git config user.name 'publish-payload-test'
    git config user.email 'publish-payload-test@example.com'
    git config commit.gpgsign false
    git add .
    git commit --quiet -m 'test fixture'

    $scriptPath = Join-Path $scratchRoot '.test-remove-internal.sh'
    [System.IO.File]::WriteAllText(
        $scriptPath,
        (($scriptLines -join "`n") + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $sanitizeScriptPath = Join-Path $scratchRoot '.test-sanitize-identifiers.sh'
    [System.IO.File]::WriteAllText(
        $sanitizeScriptPath,
        (($sanitizeScriptLines -join "`n") + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )

    $bashPath = $null
    if ($IsWindows) {
        $gitCommand = Get-Command git -ErrorAction SilentlyContinue
        if ($gitCommand) {
            $gitRoot = Split-Path (Split-Path $gitCommand.Source -Parent) -Parent
            $gitBashPath = Join-Path $gitRoot 'bin\bash.exe'
            if (Test-Path $gitBashPath) {
                $bashPath = $gitBashPath
            }
        }
    }
    if (-not $bashPath) {
        $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
        if ($bashCommand) {
            $bashPath = $bashCommand.Source
        }
    }
    if (-not $bashPath) {
        throw 'Publish payload validation requires bash, but bash is not available'
    }

    $env:TAG = 'v-test'
    & $bashPath '.test-remove-internal.sh'
    if ($LASTEXITCODE -ne 0) {
        throw "Internal-only content removal script failed with exit code $LASTEXITCODE"
    }

    & $bashPath '.test-sanitize-identifiers.sh'
    if ($LASTEXITCODE -ne 0) {
        throw "Identifier sanitization script failed with exit code $LASTEXITCODE"
    }

    $mirroredWorkflows = @(git ls-files -- '.github/workflows/*')
    if ($mirroredWorkflows.Count -ne 1 -or $mirroredWorkflows[0] -ne '.github/workflows/docs.yml') {
        throw "Publish payload retained unexpected workflows: $($mirroredWorkflows -join ', ')"
    }
    if (Test-Path '.github\dependabot.yml') {
        throw 'Publish payload retained .github/dependabot.yml'
    }
    if (Test-Path 'docs\sprint-plans\internal.md') {
        throw 'Publish payload retained internal sprint planning content'
    }
    if (Test-Path 'SPRINT-99-EXECUTION-SUMMARY.md') {
        throw 'Publish payload retained an internal sprint execution summary'
    }
    foreach ($removedPath in @(
            '.github\instructions\internal.md',
            'analysis\evidence.json',
            'component\tests\internal.ps1',
            'component\widget.test.js'
        )) {
        if (Test-Path $removedPath) {
            throw "Publish payload retained internal artifact: $removedPath"
        }
    }

    $publicDoc = Get-Content 'docs\public.md' -Raw
    if ($publicDoc -notmatch 'github\.com/ivegamsft/basecoat' -or $publicDoc -match 'IBuySpy-Shared') {
        throw 'Publish payload did not rewrite the canonical source repository to the public mirror'
    }
    if ((Get-Content 'CONTRIBUTING.md' -Raw) -notmatch 'example-org') {
        throw 'Publish payload did not neutralize a public organization example'
    }
    if ((Get-Content 'CHANGELOG.md' -Raw) -notmatch 'source organization') {
        throw 'Publish payload did not neutralize historical source-organization wording'
    }
    if ((Get-Content 'docs\memory\shared-memory-guide.md' -Raw) -notmatch 'example-org/basecoat-memory') {
        throw 'Publish payload did not neutralize the private shared-memory repository example'
    }
    $submitLearningSh = Get-Content 'scripts\submit-learning.sh' -Raw
    if ($submitLearningSh -notmatch 'MEMORY_REPO="\$\{BASECOAT_SHARED_MEMORY_REPO:-\}"' -or
        $submitLearningSh -notmatch '--memory-repo or BASECOAT_SHARED_MEMORY_REPO is required') {
        throw 'Publish payload did not require an explicit shared-memory repository in submit-learning.sh'
    }
    $submitLearningPs1 = Get-Content 'scripts\submit-learning.ps1' -Raw
    if ($submitLearningPs1 -notmatch '\[string\]\$MemoryRepo = \$env:BASECOAT_SHARED_MEMORY_REPO,' -or
        $submitLearningPs1 -notmatch 'MemoryRepo or BASECOAT_SHARED_MEMORY_REPO is required') {
        throw 'Publish payload did not require an explicit shared-memory repository in submit-learning.ps1'
    }
    if (@(git grep -inI 'ivegamsft/basecoat-memory' -- .).Count -ne 0) {
        throw 'Publish payload falsely rewrote the private basecoat-memory repository as a public repository'
    }
    $publicMkDocs = Get-Content 'mkdocs.yml' -Raw
    if ($publicMkDocs -notmatch 'BaseCoat contributors') {
        throw 'Publish payload did not neutralize public documentation attribution'
    }
    if ($publicMkDocs -match 'reference/workflows/pr-flow-hygiene\.md') {
        throw 'Publish payload retained navigation to a removed internal workflow page'
    }
    if ((Get-Content 'skills\dotnet-modernization\SKILL.md' -Raw) -notmatch 'author: BaseCoat contributors') {
        throw 'Publish payload did not neutralize public skill attribution'
    }

    $forbiddenMatches = @(git grep -inI -E 'ibuyspy-shared|ibuyspy-dev' -- .)
    if ($forbiddenMatches.Count -ne 1 -or
        $forbiddenMatches[0] -ne 'LICENSE:3:Copyright (c) 2025 IBuySpy-Shared') {
        throw "Publish payload identifier allowlist mismatch: $($forbiddenMatches -join '; ')"
    }
}
finally {
    Remove-Item Env:TAG -ErrorAction SilentlyContinue
    if ($locationPushed) {
        Pop-Location
    }
    Remove-Item -Path $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Publish-to-production dispatch tag tests passed' -ForegroundColor Green
exit 0
