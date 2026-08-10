#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )
    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$skillPath = Join-Path $repoRoot 'skills\lane-closeout\SKILL.md'
$evalPath = Join-Path $repoRoot 'skills\lane-closeout\eval.yaml'
$workflowRefPath = Join-Path $repoRoot 'skills\lane-closeout\references\workflow.md'
$hookManifestPath = Join-Path $repoRoot '.github\template-repos\repo-template\.github\hooks\40-lane-closeout.json'
$hookScriptPath = Join-Path $repoRoot '.github\template-repos\repo-template\scripts\hooks\lane-closeout-safe.ps1'
$bashHookScriptPath = Join-Path $repoRoot '.github\template-repos\repo-template\scripts\hooks\lane-closeout-safe.sh'

foreach ($path in @($skillPath, $evalPath, $workflowRefPath, $hookManifestPath, $hookScriptPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing lane-closeout asset: $path"
    }
}

$skill = Get-Content $skillPath -Raw
Assert-Match $skill '(?m)^visibility:\s+public\r?$' 'lane-closeout must be publicly visible'
Assert-Match $skill '(?m)^compatibility:\s+\[.*github-copilot-cli.*\]\r?$' 'lane-closeout must support Copilot CLI'
foreach ($state in @('MERGED', 'HANDED_OFF', 'ABANDONED', 'PARKED')) {
    Assert-Match $skill $state "lane-closeout skill missing terminal state $state"
}
foreach ($guardrail in @('git worktree list --porcelain', '@branch-hygiene-sweeper', 'git-worktrees', 'Safe mode never rebases')) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "lane-closeout skill missing guardrail: $guardrail"
}

$eval = Get-Content $evalPath -Raw
foreach ($scenario in @('finish-lane-positive', 'blocked-pr-handoff-positive', 'conflict-parking-positive', 'safe-session-stop-positive', 'branch-list-negative', 'sprint-closeout-negative')) {
    Assert-Match $eval ([regex]::Escape($scenario)) "lane-closeout eval missing scenario: $scenario"
}

$routingFiles = @(
    'instructions\basecoat-10-core-intent-routing.instructions.md',
    'instructions\intent-routing.instructions.md',
    '.github\instructions\routing-decision-tree.md',
    'docs\guides\intent-prefixes.md'
)
foreach ($relative in $routingFiles) {
    $content = Get-Content (Join-Path $repoRoot $relative) -Raw
    Assert-Match $content 'lane-closeout' "$relative missing lane-closeout routing"
}

$orchestrator = Get-Content (Join-Path $repoRoot 'agents\basecoat-60-workflow-ship-it-orchestrator.agent.md') -Raw
Assert-Match $orchestrator 'allowed_skills:\s+\[ship-it,\s*lane-closeout\]' 'ship-it orchestrator must allow lane-closeout'
Assert-Match $orchestrator 'Invoke `lane-closeout` for every in-scope branch/worktree' 'ship-it workflow must invoke lane-closeout per lane'

$profileManifest = Get-Content (Join-Path $repoRoot '.github\template-repos\repo-template\.github\basecoat-hook-profiles.json') -Raw | ConvertFrom-Json
if (-not $profileManifest.profiles.'lane-closeout') {
    throw 'Hook profiles must expose lane-closeout safe mode'
}
if (@($profileManifest.profiles.standard.enabledHookPacks) -notcontains '40-lane-closeout') {
    throw 'Standard hook profile must include 40-lane-closeout'
}
$bashHook = Get-Content $bashHookScriptPath -Raw
if ($bashHook -match '(?m)^\s*python3?\b') {
    throw 'Bash lane closeout hook must not require Python for ledger writes'
}
Assert-Match $bashHook 'if ! git status --porcelain=v1 -z' 'Bash hook must fail closed when status inspection fails'
if ($bashHook -match 'git status[^\r\n]*\|\| true') {
    throw 'Bash hook must not turn status inspection failures into a clean lane'
}
if ($bashHook -match 'git hash-object') {
    throw 'Bash lane ledger keys must hash raw UTF-8 bytes, not Git object bytes'
}
foreach ($hashTool in @('sha256sum', 'shasum', 'openssl dgst -sha256')) {
    Assert-Match $bashHook ([regex]::Escape($hashTool)) "Bash hook missing SHA-256 fallback: $hashTool"
}
Assert-Match $bashHook 'Unable to compute the required raw UTF-8 SHA-256 lane key' 'Bash hook must PARK explicitly when no SHA-256 tool is available'
foreach ($hookContent in @((Get-Content $hookScriptPath -Raw), $bashHook)) {
    if ($hookContent -notmatch 'stash_before|stashBefore' -or $hookContent -notmatch 'stash_after|stashAfter') {
        throw 'Lane closeout hooks must verify that stash capture creates a new snapshot'
    }
}

$testRoot = Join-Path $repoRoot ('test-results\lane-closeout-e2e-' + [Guid]::NewGuid().ToString('N'))
$remote = Join-Path $testRoot 'origin.git'
$work = Join-Path $testRoot 'work'

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    git init --bare $remote | Out-Null
    git init $work | Out-Null
    Push-Location $work
    git config user.name 'lane-closeout-test'
    git config user.email 'lane-closeout-test@example.com'
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish lane baseline' | Out-Null
    git branch -M feat/lane-closeout-test
    git remote add origin $remote
    git push --set-upstream origin feat/lane-closeout-test | Out-Null

    $headBefore = (git rev-parse HEAD).Trim()
    Set-Content tracked.txt 'changed'
    Set-Content untracked.txt 'new'

    & pwsh -NoProfile -File $hookScriptPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Safe lane-closeout hook returned non-zero'
    }

    $statusAfter = @(git status --porcelain=v1 --untracked-files=all)
    if ($statusAfter.Count -ne 2) {
        throw "Safe hook must restore dirty WIP; found $($statusAfter.Count) status entries"
    }
    if ((git rev-parse HEAD).Trim() -ne $headBefore) {
        throw 'Safe hook must not change lane HEAD'
    }
    if (@(git stash list).Count -ne 0) {
        throw 'Safe hook must drop its stash after successful restore'
    }

    $wipRefs = @(git ls-remote --heads origin 'refs/heads/wip/*')
    if ($wipRefs.Count -ne 1) {
        throw "Safe hook must publish exactly one WIP ref; found $($wipRefs.Count)"
    }

    & pwsh -NoProfile -File $hookScriptPath
    $wipRefsAfterRerun = @(git ls-remote --heads origin 'refs/heads/wip/*')
    if ($wipRefsAfterRerun.Count -ne 1) {
        throw 'Safe hook rerun must be idempotent for unchanged WIP'
    }

    $gitDir = (git rev-parse --absolute-git-dir).Trim()
    $ledgerPath = Get-ChildItem (Join-Path $gitDir 'basecoat\lane-closeout') -Filter '*.json' | Select-Object -First 1
    if (-not $ledgerPath) {
        throw 'Safe hook did not write a lane ledger'
    }
    $ledger = Get-Content $ledgerPath.FullName -Raw | ConvertFrom-Json
    if ($ledger.terminalState -ne 'PARKED' -or -not $ledger.pushSucceeded -or -not $ledger.restoreSucceeded) {
        throw 'Safe hook ledger must record a successfully published and restored PARKED lane'
    }

    git add tracked.txt untracked.txt
    git commit -m 'test: advance lane fixture' | Out-Null
    git push origin feat/lane-closeout-test | Out-Null

    & pwsh -NoProfile -File $hookScriptPath
    $cleanLedger = Get-Content $ledgerPath.FullName -Raw | ConvertFrom-Json
    if ($cleanLedger.terminalState -ne 'PARKED' -or -not $cleanLedger.pushSucceeded) {
        throw 'Safe hook must conservatively PARK a clean published lane until full PR classification'
    }

    Set-Content public-token.txt 'synthetic-test-value'
    git add public-token.txt
    git commit -m 'test: add rename source fixture' | Out-Null
    git push origin feat/lane-closeout-test | Out-Null
    New-Item -ItemType Directory -Path secrets -Force | Out-Null
    git mv public-token.txt secrets\api-token.txt

    & pwsh -NoProfile -File $hookScriptPath
    if (@(git ls-remote --heads origin 'refs/heads/wip/*').Count -ne 1) {
        throw 'Safe hook must not publish candidates beneath sensitive directories'
    }
    if (@(git stash list).Count -ne 1) {
        throw 'Safe hook must retain one local stash for sensitive-path review'
    }
    if (@(git status --porcelain=v1 --untracked-files=all).Count -ne 1) {
        throw 'Safe hook must restore the sensitive-path candidate to the working tree'
    }
    $firstSensitiveLedger = Get-Content $ledgerPath.FullName -Raw | ConvertFrom-Json
    if (-not $firstSensitiveLedger.restoreSucceeded -or $firstSensitiveLedger.pushSucceeded -or $firstSensitiveLedger.nextAction -notmatch 'sensitive-path') {
        throw 'First sensitive capture must preserve the sensitive-review action after successful restore'
    }
    $firstSensitiveSnapshot = $firstSensitiveLedger.snapshot

    & pwsh -NoProfile -File $hookScriptPath
    if (@(git stash list).Count -ne 1) {
        throw 'Safe hook rerun must not duplicate a retained sensitive-path stash'
    }
    $sensitiveLedger = Get-Content $ledgerPath.FullName -Raw | ConvertFrom-Json
    if ($sensitiveLedger.pushSucceeded -or $sensitiveLedger.nextAction -notmatch 'sensitive-path') {
        throw 'Safe hook must record sensitive-directory review without publishing'
    }
    if ($sensitiveLedger.snapshot -ne $firstSensitiveSnapshot -or -not $sensitiveLedger.restoreSucceeded) {
        throw 'Duplicate sensitive capture must retain the original snapshot and successful restore state'
    }
}
finally {
    Pop-Location
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force
    }
}

$bashPath = $null
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
if ($bashCommand) {
    & $bashCommand.Source --version *> $null
    if ($LASTEXITCODE -eq 0) {
        $bashPath = $bashCommand.Source
    }
}
if (-not $bashPath) {
    $bashPath = @(
        'C:\Program Files\Git\bin\bash.exe',
        'C:\Program Files\Git\usr\bin\bash.exe'
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $bashPath) {
    throw 'Lane closeout Bash E2E requires a working bash executable'
}

function Test-SubmoduleOnlyCapture {
    param(
        [ValidateSet('PowerShell', 'Bash')]
        [string]$HookKind
    )

    $fixtureRoot = Join-Path $repoRoot ('test-results\lane-closeout-submodule-' + $HookKind.ToLowerInvariant() + '-' + [Guid]::NewGuid().ToString('N'))
    $submoduleRepo = Join-Path $fixtureRoot 'submodule'
    $remoteRepo = Join-Path $fixtureRoot 'origin.git'
    $workRepo = Join-Path $fixtureRoot 'work'
    $locationPushed = $false
    try {
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        git init $submoduleRepo | Out-Null
        Push-Location $submoduleRepo
        $locationPushed = $true
        git config user.name 'lane-closeout-submodule-test'
        git config user.email 'lane-closeout-submodule-test@example.com'
        Set-Content module.txt 'baseline'
        git add module.txt
        git commit -m 'test: establish submodule fixture' | Out-Null
        Pop-Location
        $locationPushed = $false

        git init --bare $remoteRepo | Out-Null
        git init $workRepo | Out-Null
        Push-Location $workRepo
        $locationPushed = $true
        git config user.name 'lane-closeout-submodule-test'
        git config user.email 'lane-closeout-submodule-test@example.com'
        Set-Content tracked.txt 'baseline'
        git add tracked.txt
        git commit -m 'test: establish parent fixture' | Out-Null
        git -c protocol.file.allow=always submodule add $submoduleRepo module | Out-Null
        git commit -am 'test: add submodule fixture' | Out-Null
        $branch = "feat/submodule-$($HookKind.ToLowerInvariant())"
        git branch -M $branch
        git remote add origin $remoteRepo
        git push --set-upstream origin $branch | Out-Null

        Set-Content tracked.txt 'existing stash'
        git stash push --message 'test: pre-existing stash' --quiet
        $existingStash = (git rev-parse refs/stash).Trim()
        Set-Content module\module.txt 'submodule-only WIP'

        if ($HookKind -eq 'PowerShell') {
            & pwsh -NoProfile -File $hookScriptPath
        }
        else {
            & $bashPath $bashHookScriptPath
        }
        if ($LASTEXITCODE -ne 0) {
            throw "$HookKind hook returned non-zero for submodule-only WIP"
        }
        if ((git rev-parse refs/stash).Trim() -ne $existingStash -or @(git stash list).Count -ne 1) {
            throw "$HookKind hook must not mistake a pre-existing stash for a new snapshot"
        }
        if (@(git ls-remote --heads origin 'refs/heads/wip/*').Count -ne 0) {
            throw "$HookKind hook must not publish a pre-existing stash for submodule-only WIP"
        }
        if (((git status --porcelain=v1) -join "`n") -notmatch 'module') {
            throw "$HookKind hook must leave submodule-only WIP intact"
        }

        $gitDir = (git rev-parse --absolute-git-dir).Trim()
        $ledgerPath = Get-ChildItem (Join-Path $gitDir 'basecoat\lane-closeout') -Filter '*.json' | Select-Object -First 1
        $ledger = Get-Content $ledgerPath.FullName -Raw | ConvertFrom-Json
        if ($ledger.pushSucceeded -or $ledger.error -notmatch 'did not create a new WIP snapshot') {
            throw "$HookKind hook must park when stash capture produces no new snapshot"
        }
    }
    finally {
        if ($locationPushed) {
            Pop-Location
        }
        if (Test-Path $fixtureRoot) {
            Remove-Item $fixtureRoot -Recurse -Force
        }
    }
}

Test-SubmoduleOnlyCapture -HookKind PowerShell
Test-SubmoduleOnlyCapture -HookKind Bash

$restoreFailureRoot = Join-Path $repoRoot ('test-results\lane-closeout-restore-failure-' + [Guid]::NewGuid().ToString('N'))
$restoreFailureRemote = Join-Path $restoreFailureRoot 'origin.git'
$restoreFailureWork = Join-Path $restoreFailureRoot 'work'
$restoreFailureFakeBin = Join-Path $restoreFailureRoot 'bin'
$restoreFailureLocationPushed = $false
$originalPath = $env:PATH
$originalRealGit = $env:BASECOAT_REAL_GIT
try {
    New-Item -ItemType Directory -Path $restoreFailureRoot, $restoreFailureFakeBin -Force | Out-Null
    $realGit = (Get-Command git).Source
    @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
if ($Arguments.Count -ge 2 -and $Arguments[0] -eq 'stash' -and $Arguments[1] -eq 'apply') {
    [Console]::Error.WriteLine('simulated stash apply failure')
    exit 43
}
& $env:BASECOAT_REAL_GIT @Arguments
exit $LASTEXITCODE
'@ | Set-Content -Path (Join-Path $restoreFailureFakeBin 'fake-git.ps1')
    Set-Content -Path (Join-Path $restoreFailureFakeBin 'git.cmd') -Value '@pwsh -NoProfile -File "%~dp0fake-git.ps1" %*'
    @'
#!/usr/bin/env bash
if [[ "$1" == "stash" && "$2" == "apply" ]]; then
  printf '%s\n' 'simulated stash apply failure' >&2
  exit 43
fi
exec "$BASECOAT_REAL_GIT" "$@"
'@ | Set-Content -Path (Join-Path $restoreFailureFakeBin 'git') -NoNewline
    if (-not $IsWindows) {
        chmod +x (Join-Path $restoreFailureFakeBin 'git')
    }

    git init --bare $restoreFailureRemote | Out-Null
    git init $restoreFailureWork | Out-Null
    Push-Location $restoreFailureWork
    $restoreFailureLocationPushed = $true
    git config user.name 'lane-closeout-restore-test'
    git config user.email 'lane-closeout-restore-test@example.com'
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish restore fixture' | Out-Null
    git branch -M feat/restore-failure
    git remote add origin $restoreFailureRemote
    git push --set-upstream origin feat/restore-failure | Out-Null
    New-Item -ItemType Directory -Path secrets -Force | Out-Null
    Set-Content secrets\token.txt 'synthetic-test-value'

    $env:BASECOAT_REAL_GIT = $realGit
    $env:PATH = "$restoreFailureFakeBin$([IO.Path]::PathSeparator)$originalPath"
    & pwsh -NoProfile -File $hookScriptPath
    $hookExitCode = $LASTEXITCODE
    $env:PATH = $originalPath
    if ($hookExitCode -ne 0) {
        throw 'PowerShell hook returned non-zero for simulated restore failure'
    }

    $gitDir = (git rev-parse --absolute-git-dir).Trim()
    $restoreFailureLedgerPath = Get-ChildItem (Join-Path $gitDir 'basecoat\lane-closeout') -Filter '*.json' | Select-Object -First 1
    $restoreFailureLedger = Get-Content $restoreFailureLedgerPath.FullName -Raw | ConvertFrom-Json
    if ($restoreFailureLedger.restoreSucceeded -or $restoreFailureLedger.nextAction -notmatch 'Restore the retained stash manually') {
        throw 'Manual restore action must be emitted only when stash restore actually fails'
    }
    if (@(git stash list).Count -ne 1) {
        throw 'Restore failure must retain the captured stash for manual recovery'
    }
}
finally {
    $env:PATH = $originalPath
    $env:BASECOAT_REAL_GIT = $originalRealGit
    if ($restoreFailureLocationPushed) {
        Pop-Location
    }
    if (Test-Path $restoreFailureRoot) {
        Remove-Item $restoreFailureRoot -Recurse -Force
    }
}

function Get-ExpectedLaneLedgerName {
    param([string]$Branch)

    $prefix = ($Branch -replace '[^A-Za-z0-9._-]+', '-').Trim('-')
    if (-not $prefix) {
        $prefix = 'lane'
    }
    if ($prefix.Length -gt 60) {
        $prefix = $prefix.Substring(0, 60).TrimEnd('-')
    }
    if (-not $prefix) {
        $prefix = 'lane'
    }
    $digest = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Branch))
    ).ToLowerInvariant()
    return "$prefix-$($digest.Substring(0, 12)).json"
}

function Get-BashCommandPath {
    param([string]$Command)

    $resolved = (& $bashPath -c 'command -v "$1"' -- $Command).Trim()
    if (-not $resolved) {
        throw "Required Bash command is unavailable for fallback testing: $Command"
    }
    return $resolved
}

function New-RestrictedHashPath {
    param(
        [string]$Directory,
        [ValidateSet('sha256sum', 'shasum', 'openssl', 'none')]
        [string]$Mode
    )

    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $bashExecutable = Get-BashCommandPath -Command 'bash'
    foreach ($command in @('bash', 'mkdir', 'sed', 'cut', 'awk', 'tr', 'cat', 'date', 'rm', 'grep')) {
        $commandPath = Get-BashCommandPath -Command $command
        $wrapper = "#!$bashExecutable`nexec '$commandPath' " + '"$@"' + "`n"
        Set-Content -Path (Join-Path $Directory $command) -Value $wrapper -NoNewline
    }
    $gitPath = Get-BashCommandPath -Command 'git'
    $gitWrapper = "#!$bashExecutable`nif [[ " + '"$1"' + " == 'push' ]]; then exit 1; fi`nexec '$gitPath' " + '"$@"' + "`n"
    Set-Content -Path (Join-Path $Directory 'git') -Value $gitWrapper -NoNewline

    $sha256Path = Get-BashCommandPath -Command 'sha256sum'
    if ($Mode -eq 'sha256sum') {
        $wrapper = "#!$bashExecutable`nexec '$sha256Path' " + '"$@"' + "`n"
        Set-Content -Path (Join-Path $Directory 'sha256sum') -Value $wrapper -NoNewline
    }
    elseif ($Mode -eq 'shasum') {
        $wrapper = "#!$bashExecutable`nif [[ " + '"$1"' + " == '-a' && " + '"$2"' + " == '256' ]]; then shift 2; fi`nexec '$sha256Path' " + '"$@"' + "`n"
        Set-Content -Path (Join-Path $Directory 'shasum') -Value $wrapper -NoNewline
    }
    elseif ($Mode -eq 'openssl') {
        $opensslPath = Get-BashCommandPath -Command 'openssl'
        $wrapper = "#!$bashExecutable`nexec '$opensslPath' " + '"$@"' + "`n"
        Set-Content -Path (Join-Path $Directory 'openssl') -Value $wrapper -NoNewline
    }

    $bashDirectory = if ($IsWindows) {
        (& $bashPath -c 'cygpath -u "$1"' -- $Directory).Trim()
    }
    else {
        $Directory
    }
    & $bashPath -c 'chmod +x "$1"/*' -- $bashDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to prepare restricted Bash PATH for mode '$Mode'"
    }
    return $bashDirectory
}

$ledgerKeyRoot = Join-Path $repoRoot ('test-results\lane-closeout-ledger-keys-' + [Guid]::NewGuid().ToString('N'))
$ledgerKeyRemote = Join-Path $ledgerKeyRoot 'origin.git'
$ledgerKeyWork = Join-Path $ledgerKeyRoot 'work'
$ledgerKeyLocationPushed = $false
try {
    New-Item -ItemType Directory -Path $ledgerKeyRoot -Force | Out-Null
    git init --bare $ledgerKeyRemote | Out-Null
    git init $ledgerKeyWork | Out-Null
    Push-Location $ledgerKeyWork
    $ledgerKeyLocationPushed = $true
    git config user.name 'lane-closeout-ledger-key-test'
    git config user.email 'lane-closeout-ledger-key-test@example.com'
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish ledger key fixture' | Out-Null
    git branch -M main
    git remote add origin $ledgerKeyRemote
    git push --set-upstream origin main | Out-Null

    $keyBranches = @('feat/ünicode', 'feat/a-b', 'feat/a/b')
    $expectedNames = @{}
    foreach ($branch in $keyBranches) {
        $expectedNames[$branch] = Get-ExpectedLaneLedgerName -Branch $branch
        git checkout -b $branch main | Out-Null
        git push --set-upstream origin $branch | Out-Null
        & pwsh -NoProfile -File $hookScriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "PowerShell hook failed for ledger-key branch '$branch'"
        }
        $gitDir = (git rev-parse --absolute-git-dir).Trim()
        if (-not (Test-Path (Join-Path $gitDir "basecoat\lane-closeout\$($expectedNames[$branch])"))) {
            throw "PowerShell hook wrote the wrong raw UTF-8 SHA-256 ledger key for '$branch'"
        }
        git checkout main | Out-Null
    }
    if ($expectedNames['feat/a-b'] -eq $expectedNames['feat/a/b'] -or
        $expectedNames['feat/a-b'] -notmatch '^feat-a-b-' -or
        $expectedNames['feat/a/b'] -notmatch '^feat-a-b-') {
        throw 'Slash/dash normalized-prefix collisions must be distinguished by raw branch SHA-256'
    }

    $ledgerDirectory = Join-Path $gitDir 'basecoat\lane-closeout'
    Remove-Item (Join-Path $ledgerDirectory '*.json') -Force
    foreach ($branch in $keyBranches) {
        git checkout $branch | Out-Null
        & $bashPath $bashHookScriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "Bash hook failed for ledger-key branch '$branch'"
        }
        if (-not (Test-Path (Join-Path $ledgerDirectory $expectedNames[$branch]))) {
            throw "Bash and PowerShell hooks disagree on the ledger key for '$branch'"
        }
        git checkout main | Out-Null
    }
    $actualBashNames = @(Get-ChildItem $ledgerDirectory -Filter '*.json' | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedBashNames = @($expectedNames.Values | Sort-Object)
    if (($actualBashNames -join "`n") -ne ($expectedBashNames -join "`n")) {
        throw 'Bash and PowerShell ledger key golden sets differ'
    }

    git checkout 'feat/ünicode' | Out-Null
    $originalHashTestPath = $env:BASECOAT_HASH_TEST_PATH
    try {
        foreach ($mode in @('sha256sum', 'shasum', 'openssl', 'none')) {
            Remove-Item (Join-Path $ledgerDirectory '*.json') -Force
            $restrictedPath = New-RestrictedHashPath -Directory (Join-Path $ledgerKeyRoot "hash-$mode") -Mode $mode
            $env:BASECOAT_HASH_TEST_PATH = $restrictedPath
            & $bashPath -c 'export PATH="$BASECOAT_HASH_TEST_PATH"; bash "$1"' -- $bashHookScriptPath
            if ($LASTEXITCODE -ne 0) {
                throw "Bash hook failed for SHA-256 fallback mode '$mode'"
            }

            if ($mode -eq 'none') {
                $unavailableLedgerPath = Get-ChildItem $ledgerDirectory -Filter '*-hash-unavailable.json' | Select-Object -First 1
                if (-not $unavailableLedgerPath) {
                    throw 'No-hash-tool mode must write an explicit fallback ledger'
                }
                $unavailableLedger = Get-Content $unavailableLedgerPath.FullName -Raw | ConvertFrom-Json
                if ($unavailableLedger.terminalState -ne 'PARKED' -or
                    $unavailableLedger.error -notmatch 'raw UTF-8 SHA-256 lane key') {
                    throw 'No-hash-tool mode must PARK with an explicit hash-tool error'
                }
            }
            elseif (-not (Test-Path (Join-Path $ledgerDirectory $expectedNames['feat/ünicode']))) {
                throw "Bash SHA-256 fallback '$mode' disagrees with the PowerShell golden key"
            }
        }
    }
    finally {
        $env:BASECOAT_HASH_TEST_PATH = $originalHashTestPath
    }
    git checkout main | Out-Null
}
finally {
    if ($ledgerKeyLocationPushed) {
        Pop-Location
    }
    if (Test-Path $ledgerKeyRoot) {
        Remove-Item $ledgerKeyRoot -Recurse -Force
    }
}

$bashTestRoot = Join-Path $repoRoot ('test-results\lane-closeout-bash-e2e-' + [Guid]::NewGuid().ToString('N'))
$bashRemote = Join-Path $bashTestRoot 'origin.git'
$bashWork = Join-Path $bashTestRoot 'work'
$bashHookPath = Join-Path $repoRoot '.github\template-repos\repo-template\scripts\hooks\lane-closeout-safe.sh'
try {
    New-Item -ItemType Directory -Path $bashTestRoot -Force | Out-Null
    git init --bare $bashRemote | Out-Null
    git init $bashWork | Out-Null
    Push-Location $bashWork
    git config user.name 'lane-closeout-bash-test'
    git config user.email 'lane-closeout-bash-test@example.com'
    Set-Content tracked.txt 'baseline'
    git add tracked.txt
    git commit -m 'test: establish bash lane baseline' | Out-Null
    git branch -M feat/lane-closeout-bash-test
    git remote add origin $bashRemote
    git push --set-upstream origin feat/lane-closeout-bash-test | Out-Null
    Set-Content tracked.txt 'changed'

    & $bashPath $bashHookPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Bash safe lane-closeout hook returned non-zero'
    }
    if (@(git status --porcelain=v1).Count -ne 1) {
        throw 'Bash safe hook must restore dirty WIP'
    }
    if (@(git ls-remote --heads origin 'refs/heads/wip/*').Count -ne 1) {
        throw 'Bash safe hook must publish one WIP ref'
    }

    Set-Content public-token.txt 'synthetic-test-value'
    git add tracked.txt public-token.txt
    git commit -m 'test: advance bash lane fixture' | Out-Null
    git push origin feat/lane-closeout-bash-test | Out-Null
    New-Item -ItemType Directory -Path credentials -Force | Out-Null
    git mv public-token.txt credentials\api-token.txt

    & $bashPath $bashHookPath
    if ($LASTEXITCODE -ne 0) {
        throw 'Bash sensitive-directory lane-closeout hook returned non-zero'
    }
    if (@(git ls-remote --heads origin 'refs/heads/wip/*').Count -ne 1) {
        throw 'Bash safe hook must not publish candidates beneath sensitive directories'
    }
    if (@(git stash list).Count -ne 1) {
        throw 'Bash safe hook must retain one local stash for sensitive-directory review'
    }
}
finally {
    Pop-Location
    if (Test-Path $bashTestRoot) {
        Remove-Item $bashTestRoot -Recurse -Force
    }
}

$publisherRoot = Join-Path $repoRoot ('test-results\lane-ledger-publisher-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $publisherRoot -Force | Out-Null
    $ledgerFixture = Join-Path $publisherRoot 'ledger.json'
    $bodyPath = Join-Path $publisherRoot 'issue.md'
    @{
        generatedAt = '2026-08-04T00:00:00Z'
        lanes = @(
            @{
                lane = 'feat/blocked'
                source = 'remote'
                terminalState = 'HANDED_OFF'
                state = 'stale-open-pr-#42'
                prNumber = 42
                owner = 'octocat'
                action = 'retained'
                nextAction = 'Resolve PR #42 gates, then rerun lane-closeout.'
            }
        )
    } | ConvertTo-Json -Depth 5 | Set-Content $ledgerFixture

    & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\publish-orphaned-lane-ledger.ps1') `
        -LedgerPath $ledgerFixture -BodyPath $bodyPath -DryRun
    $body = Get-Content $bodyPath -Raw
    Assert-Match $body 'basecoat-orphaned-lane-ledger' 'Publisher dry run missing idempotence marker'
    Assert-Match $body 'feat/blocked' 'Publisher dry run missing orphaned lane'
    Assert-Match $body 'HANDED_OFF' 'Publisher dry run missing terminal state'
    Assert-Match $body 'octocat' 'Publisher dry run missing lane owner'
    Assert-Match $body 'Resolve PR #42 gates' 'Publisher dry run missing ledger next action'
}
finally {
    if (Test-Path $publisherRoot) {
        Remove-Item $publisherRoot -Recurse -Force
    }
}

Write-Host 'Lane closeout tests passed' -ForegroundColor Green
