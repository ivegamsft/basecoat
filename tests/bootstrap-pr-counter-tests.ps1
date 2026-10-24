$ErrorActionPreference = 'Stop'

# #3812: bootstrap-basecoat.ps1 counts real writes; the optional PR opens only when committable files changed.

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$bootstrap = Join-Path $repoRoot 'scripts/bootstrap-basecoat.ps1'
$workRoot = Join-Path ([System.IO.Path]::GetTempPath()) "bootstrap-pr-counter-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$failures = New-Object System.Collections.Generic.List[string]

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { $failures.Add($Message) } }
function Invoke-Git {
    param([string]$Path, [string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    $output = & git -C $Path @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed in ${Path}: $output" }
    return $output
}

function New-GitRepo([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
    Invoke-Git $Path @('init', '--quiet', '-b', 'main') | Out-Null
    foreach ($cfg in @(@('user.name', 'Bootstrap Test'), @('user.email', 'bootstrap-test@example.invalid'), @('commit.gpgsign', 'false'))) { Invoke-Git $Path (@('config') + $cfg) | Out-Null }
}

function New-SourceRepo([string]$Path) {
    New-GitRepo $Path
    $files = @{
        'README.md'                          = '# BaseCoat'
        'CHANGELOG.md'                       = '# Changelog'
        'version.json'                       = '{ "version": "9.9.9" }'
        'instructions/a.instructions.md'     = 'instruction'
        'instructions/b.instructions.md'     = 'retired instruction'
        'skills/demo/SKILL.md'               = 'skill'
        'prompts/p.prompt.md'                = 'prompt'
        'agents/x.agent.md'                  = "---`nname: x`ndescription: x`n---`nbody"
        'templates/t.md'                     = 'template'
    }
    foreach ($rel in $files.Keys) {
        $dest = Join-Path $Path $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Set-Content -LiteralPath $dest -Value $files[$rel] -Encoding UTF8
    }
    # Stub sync.ps1: mirrors the payload into the consumer overlay paths (bootstrap runs it from the consumer root).
    $syncStub = @'
$source = $env:BASECOAT_TEST_SOURCE_PATH
$target = Join-Path (Get-Location) $env:BASECOAT_TARGET_DIR
New-Item -ItemType Directory -Force -Path $target | Out-Null
foreach ($item in @('README.md', 'CHANGELOG.md', 'version.json', 'instructions', 'skills', 'prompts', 'agents', 'templates')) {
    $dest = Join-Path $target $item
    if (Test-Path $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-Item -Path (Join-Path $source $item) -Destination $target -Recurse -Force
}
foreach ($dir in @('instructions', 'prompts', 'skills', 'agents')) {
    $dest = Join-Path (Get-Location) ".github/$dir"
    if (Test-Path $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $source "$dir/*") -Destination $dest -Recurse -Force
}
'@
    Set-Content -LiteralPath (Join-Path $Path 'sync.ps1') -Value $syncStub -Encoding UTF8
    Invoke-Git $Path @('add', '-A') | Out-Null
    Invoke-Git $Path @('commit', '--quiet', '-m', 'seed') | Out-Null
}

function New-ConsumerRepo([string]$Path) {
    New-GitRepo $Path
    Set-Content -LiteralPath (Join-Path $Path 'README.md') -Value '# consumer' -Encoding UTF8
    Invoke-Git $Path @('add', '-A') | Out-Null
    Invoke-Git $Path @('commit', '--quiet', '-m', 'init') | Out-Null
}

# Runs bootstrap in a child pwsh with gh and `git push` mocked; mocked calls are logged.
function Invoke-Bootstrap {
    param([string]$Consumer, [string]$SourceUrl, [string]$LogPath, [switch]$DryRun)
    if (Test-Path $LogPath) { Remove-Item -LiteralPath $LogPath -Force }
    $harness = Join-Path $workRoot 'harness.ps1'
    $harnessBody = @'
param([string]$Bootstrap, [string]$Consumer, [string]$SourceUrl, [string]$LogPath, [switch]$DryRun)
$realGit = (Get-Command git -CommandType Application | Select-Object -First 1).Source
function global:gh {
    if ($args[0] -eq '--version') { 'gh version 0.0.0-mock'; return }
    Add-Content -LiteralPath $LogPath -Value ("gh " + ($args -join ' '))
    $global:LASTEXITCODE = 0
}
function global:git {
    if ($args[0] -eq 'push') { Add-Content -LiteralPath $LogPath -Value ("git " + ($args -join ' ')); $global:LASTEXITCODE = 0; return }
    & $realGit @args
}
Set-Location $Consumer
$splat = @{ BasecoatRepo = $SourceUrl; Ref = 'main'; Silent = $true }
if ($DryRun) { $splat.DryRun = $true }
& $Bootstrap @splat
exit $LASTEXITCODE
'@
    Set-Content -LiteralPath $harness -Value $harnessBody -Encoding UTF8
    $harnessArgs = @('-Bootstrap', $bootstrap, '-Consumer', $Consumer, '-SourceUrl', $SourceUrl, '-LogPath', $LogPath)
    if ($DryRun) { $harnessArgs += '-DryRun' }
    # Launch the child with the current host so a Windows PowerShell 5.1 run exercises 5.1.
    $hostExe = (Get-Process -Id $PID).Path
    $output = & $hostExe -NoProfile -ExecutionPolicy Bypass -File $harness @harnessArgs 2>&1 | Out-String
    $calls = if (Test-Path $LogPath) { @(Get-Content -LiteralPath $LogPath) } else { @() }
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output; Calls = $calls }
}

try {
    New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
    $source = Join-Path $workRoot 'source'
    New-SourceRepo $source
    $sourceUrl = 'file:///' + ($source -replace '\\', '/').TrimStart('/')
    $logPath = Join-Path $workRoot 'calls.log'

    # 1. Real run that changes files attempts to push and open a PR.
    $consumer = Join-Path $workRoot 'consumer'
    New-ConsumerRepo $consumer
    # Unrelated staged work must stay out of the generated commit.
    Set-Content -LiteralPath (Join-Path $consumer 'notes.txt') -Value 'wip' -Encoding UTF8
    Invoke-Git $consumer @('add', 'notes.txt') | Out-Null
    $run = Invoke-Bootstrap -Consumer $consumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.ExitCode -eq 0) "real run exited $($run.ExitCode): $($run.Output)"
    Assert-True (@($run.Calls | Where-Object { $_ -like 'gh pr create*' }).Count -eq 1) "real run with changes should call 'gh pr create' once; calls: $($run.Calls -join '; ')`n$($run.Output)"
    Assert-True (@($run.Calls | Where-Object { $_ -like 'git push*' }).Count -eq 1) "real run with changes should push the PR branch; calls: $($run.Calls -join '; ')"
    Assert-True ($run.Output -match 'Added:\s+(\d+)' -and [int]$Matches[1] -gt 0) "real run should report a non-zero Added count: $($run.Output)"
    $committed = @(Invoke-Git $consumer @('show', '--name-only', '--pretty=format:', 'HEAD') | Where-Object { $_ })
    Assert-True ($committed -contains '.github/base-coat/version.json' -and $committed -contains '.github/agents/x.agent.md') "PR commit should contain the written overlay files; got: $($committed -join ', ')"
    Assert-True ($committed -notcontains 'notes.txt') 'PR commit should not include unrelated staged files'
    Assert-True (@(Invoke-Git $consumer @('diff', '--cached', '--name-only')) -contains 'notes.txt') 'unrelated staged work should remain staged'

    # 2. Re-running with nothing to change skips the PR.
    $run = Invoke-Bootstrap -Consumer $consumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.ExitCode -eq 0) "no-change run exited $($run.ExitCode): $($run.Output)"
    Assert-True ($run.Calls.Count -eq 0) "no-change run should not push or open a PR; calls: $($run.Calls -join '; ')"
    Assert-True ($run.Output -match 'No committable overlay changes detected') "no-change run should report that the PR was skipped: $($run.Output)"

    # 3. Refresh after upstream modifies and removes assets counts updates and removals and commits both.
    Set-Content -LiteralPath (Join-Path $source 'version.json') -Value '{ "version": "9.9.10" }' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $source 'README.md') -Value '# BaseCoat refreshed' -Encoding UTF8
    Invoke-Git $source @('rm', '--quiet', 'instructions/b.instructions.md') | Out-Null
    Invoke-Git $source @('commit', '--quiet', '-am', 'refresh') | Out-Null
    $run = Invoke-Bootstrap -Consumer $consumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.ExitCode -eq 0) "refresh run exited $($run.ExitCode): $($run.Output)"
    Assert-True ($run.Output -match 'Updated:\s+2\b' -and $run.Output -match 'Removed:\s+2\b') "refresh should report 2 updated and 2 removed files: $($run.Output)"
    Assert-True (@($run.Calls | Where-Object { $_ -like 'gh pr create*' }).Count -eq 1) "refresh with changes should call 'gh pr create' once; calls: $($run.Calls -join '; ')"
    $status = @(Invoke-Git $consumer @('show', '--name-status', '--pretty=format:', 'HEAD') | Where-Object { $_ } | ForEach-Object { ($_ -split '\s+') -join ' ' })
    foreach ($expected in @('M .github/base-coat/README.md', 'M .github/base-coat/version.json', 'D .github/base-coat/instructions/b.instructions.md', 'D .github/instructions/b.instructions.md')) {
        Assert-True ($status -contains $expected) "refresh commit should contain '$expected'; got: $($status -join ', ')"
    }

    # 4. A custom TargetDir outside .github is snapshotted: an update confined to it opens the PR.
    $customConsumer = Join-Path $workRoot 'custom-consumer'
    New-ConsumerRepo $customConsumer
    $env:BASECOAT_TARGET_DIR = 'vendor/basecoat'
    $null = Invoke-Bootstrap -Consumer $customConsumer -SourceUrl $sourceUrl -LogPath $logPath
    Set-Content -LiteralPath (Join-Path $source 'version.json') -Value '{ "version": "9.9.11" }' -Encoding UTF8
    Invoke-Git $source @('commit', '--quiet', '-am', 'bump') | Out-Null
    $run = Invoke-Bootstrap -Consumer $customConsumer -SourceUrl $sourceUrl -LogPath $logPath
    $env:BASECOAT_TARGET_DIR = $null
    $committed = @(Invoke-Git $customConsumer @('show', '--name-only', '--pretty=format:', 'HEAD') | Where-Object { $_ })
    Assert-True ($run.Output -match 'Updated:\s+1\b' -and @($run.Calls | Where-Object { $_ -like 'gh pr create*' }).Count -eq 1) "custom TargetDir update should count 1 file and open a PR: $($run.Output)"
    Assert-True ($committed -contains 'vendor/basecoat/version.json') "custom TargetDir commit should contain vendor/basecoat/version.json; got: $($committed -join ', ')"

    # 5. Dry run previews sync at file level in a temporary clone (#3818): its counts match a real run,
    #    and it neither writes files nor opens a PR.
    $dryConsumer = Join-Path $workRoot 'dry-consumer'
    New-ConsumerRepo $dryConsumer
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath -DryRun
    Assert-True ($run.ExitCode -eq 0) "dry run exited $($run.ExitCode): $($run.Output)"
    Assert-True ($run.Output -match 'Would add \.github/base-coat/version\.json') "dry run should list file-level additions: $($run.Output)"
    $dryAdded = if ($run.Output -match 'Added:\s+(\d+)') { [int]$Matches[1] } else { -1 }
    Assert-True ($dryAdded -gt 0) "dry run should report a non-zero Added count: $($run.Output)"
    Assert-True ($run.Calls.Count -eq 0) "dry run should not push or open a PR; calls: $($run.Calls -join '; ')"
    Assert-True (-not (Test-Path (Join-Path $dryConsumer '.github'))) 'dry run should not write overlay files'
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.Output -match 'Added:\s+(\d+)' -and [int]$Matches[1] -eq $dryAdded) "dry run Added ($dryAdded) should match the real run: $($run.Output)"

    # 6. A dry refresh counts only files whose content would change and leaves the consumer untouched.
    Set-Content -LiteralPath (Join-Path $source 'version.json') -Value '{ "version": "9.9.12" }' -Encoding UTF8
    Invoke-Git $source @('commit', '--quiet', '-am', 'bump again') | Out-Null
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath -DryRun
    Assert-True ($run.Output -match 'Added:\s+0\b' -and $run.Output -match 'Updated:\s+1\b' -and $run.Output -match 'Removed:\s+0\b') "dry refresh should report 0 added, 1 updated, 0 removed: $($run.Output)"
    Assert-True ($run.Output -match 'Would update \.github/base-coat/version\.json') "dry refresh should name the updated file: $($run.Output)"
    Assert-True ((Get-Content -LiteralPath (Join-Path $dryConsumer '.github/base-coat/version.json') -Raw) -match '9\.9\.11') 'dry refresh should not modify the consumer'
    Assert-True (@(Invoke-Git $dryConsumer @('status', '--porcelain')).Count -eq 0) 'dry refresh should leave the consumer working tree clean'

    # 7. An upstream case-only rename is committed with its new casing, including on case-insensitive
    #    filesystems where core.ignorecase=true hides it from git status (#3821).
    Invoke-Git $source @('mv', 'prompts/p.prompt.md', 'prompts/P.prompt.md') | Out-Null
    Invoke-Git $source @('commit', '--quiet', '-m', 'case rename') | Out-Null
    Set-Content -LiteralPath (Join-Path $dryConsumer 'notes.txt') -Value 'wip' -Encoding UTF8
    Invoke-Git $dryConsumer @('add', 'notes.txt') | Out-Null
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.Output -match 'Added:\s+2\b' -and $run.Output -match 'Updated:\s+1\b' -and $run.Output -match 'Removed:\s+2\b') "case rename should report 2 added, 1 updated, 2 removed: $($run.Output)"
    $status = @(Invoke-Git $dryConsumer @('show', '--name-status', '--no-renames', '--pretty=format:', 'HEAD') | Where-Object { $_ } | ForEach-Object { ($_ -split '\s+') -join ' ' })
    foreach ($expected in @('D .github/prompts/p.prompt.md', 'A .github/prompts/P.prompt.md', 'D .github/base-coat/prompts/p.prompt.md', 'A .github/base-coat/prompts/P.prompt.md')) {
        Assert-True ($status -ccontains $expected) "case rename commit should contain '$expected'; got: $($status -join ', ')"
    }
    $tracked = @(Invoke-Git $dryConsumer @('ls-files', '.github/prompts'))
    Assert-True ($tracked -ccontains '.github/prompts/P.prompt.md' -and $tracked -cnotcontains '.github/prompts/p.prompt.md') "index should track only the new casing; got: $($tracked -join ', ')"
    Assert-True ((@(Invoke-Git $dryConsumer @('status', '--porcelain')) -join ',') -eq 'A  notes.txt') "case rename run should leave only unrelated staged work in the working tree: $($run.Output)"

    # 8. A case-only rename of a force-tracked file under an ignored directory still commits the new casing.
    Set-Content -LiteralPath (Join-Path $dryConsumer '.gitignore') -Value '.github/prompts/' -Encoding UTF8
    Invoke-Git $dryConsumer @('add', '.gitignore') | Out-Null
    Invoke-Git $dryConsumer @('commit', '--quiet', '-m', 'ignore prompts') | Out-Null
    Invoke-Git $source @('mv', 'prompts/P.prompt.md', 'prompts/p.prompt.md') | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'version.json') -Value '{ "version": "9.9.13" }' -Encoding UTF8
    Invoke-Git $source @('commit', '--quiet', '-am', 'case rename back') | Out-Null
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath
    Assert-True ($run.ExitCode -eq 0 -and @($run.Calls | Where-Object { $_ -like 'gh pr create*' }).Count -eq 1) "ignored case rename should open a PR; exit $($run.ExitCode): $($run.Output)"
    $tracked = @(Invoke-Git $dryConsumer @('ls-files', '.github/prompts'))
    Assert-True ($tracked -ccontains '.github/prompts/p.prompt.md' -and $tracked -cnotcontains '.github/prompts/P.prompt.md') "ignored case rename should track only the new casing; got: $($tracked -join ', ')"

    # 9. A removed file replaced by a directory never stages that directory's ignored children.
    Invoke-Git $source @('rm', '--quiet', 'prompts/p.prompt.md') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'prompts/p.prompt.md') | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'prompts/p.prompt.md/child.prompt.md') -Value '# child' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $source 'version.json') -Value '{ "version": "9.9.14" }' -Encoding UTF8
    Invoke-Git $source @('add', '-A') | Out-Null
    Invoke-Git $source @('commit', '--quiet', '-m', 'file to directory') | Out-Null
    $run = Invoke-Bootstrap -Consumer $dryConsumer -SourceUrl $sourceUrl -LogPath $logPath
    $committed = @(Invoke-Git $dryConsumer @('show', '--name-only', '--pretty=format:', 'HEAD') | Where-Object { $_ })
    Assert-True ($run.ExitCode -eq 0 -and $committed -contains '.github/prompts/p.prompt.md') "file-to-directory run should commit the removal; exit $($run.ExitCode), got: $($committed -join ', ')"
    Assert-True ($committed -notcontains '.github/prompts/p.prompt.md/child.prompt.md') "ignored child of a replaced file must not be committed; got: $($committed -join ', ')"
}
finally {
    Set-Location $repoRoot
    if (Test-Path $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($failures.Count -gt 0) {
    Write-Host 'Bootstrap PR counter tests failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Bootstrap PR counter tests passed (9 scenarios)' -ForegroundColor Green
