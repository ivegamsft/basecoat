#Requires -Version 7.0
# Verifies the retired fix-skill-frontmatter.ps1 guard (#3656) never mutates files.
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts/fix-skill-frontmatter.ps1'
$failures = [System.Collections.Generic.List[string]]::new()

function Get-TreeSnapshot {
    param([string]$Root)
    $map = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName | ForEach-Object {
        $map[[IO.Path]::GetRelativePath($Root, $_.FullName)] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    return $map
}

function Assert-SnapshotEqual {
    param($Before, $After, [string]$Label)
    $b = ($Before.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n"
    $a = ($After.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n"
    if ($b -ne $a) { $failures.Add("$Label`: file inventory or SHA-256 hashes changed") }
}

function Invoke-Guard {
    param([string]$Script, [string]$WorkDir, [string[]]$Arguments, [hashtable]$Env = @{})
    $saved = @{}
    foreach ($k in $Env.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, $Env[$k]) }
    Push-Location $WorkDir
    try {
        $output = & pwsh -NoProfile -File $Script @Arguments 2>&1 | Out-String
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
    } finally {
        Pop-Location
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

# Fixture workspace with content the legacy regex used to delete or rewrite.
$fixtureRoot = Join-Path $repoRoot 'test-results/fix-skill-frontmatter-retirement'
if (Test-Path $fixtureRoot) { Remove-Item $fixtureRoot -Recurse -Force }
$skillDir = New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'skills/policy-skill') -Force
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'scripts') -Force | Out-Null
Copy-Item $scriptPath (Join-Path $fixtureRoot 'scripts/fix-skill-frontmatter.ps1')
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText((Join-Path $skillDir 'SKILL.md'), "---`r`nname: policy-skill`r`ndescription: |`r`n  Multiline caf$([char]0xE9) description.`r`ncompatibility:`r`n  - copilot`r`nmetadata:`r`n  policy:`r`n    level: strict`r`nallowed-tools: []`r`nallowed_skills: [a, b]`r`nx-custom: keep`r`n---`r`n# Body`r`n`r`n``````yaml`r`ntype: not-frontmatter`r`n```````r`n", $utf8)
[IO.File]::WriteAllText((Join-Path $skillDir 'eval.yaml'), "cases: []`n", $utf8)
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'skills/broken') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $fixtureRoot 'skills/broken/SKILL.md'), "---`nname: [unclosed`nmetadata:`n  a: b`n---`nbody", $utf8)
$fixtureScript = Join-Path $fixtureRoot 'scripts/fix-skill-frontmatter.ps1'

$repoSkills = Join-Path $repoRoot 'skills'
$noGit = @{ GIT_DIR = (Join-Path $fixtureRoot 'no-such-git-dir'); GIT_CEILING_DIRECTORIES = $fixtureRoot }

$cases = @(
    @{ Label = 'repo default'; Script = $scriptPath; Dir = $repoRoot; Args = @(); Env = @{}; Exit = 0; Tree = $repoSkills },
    @{ Label = 'repo -Fix'; Script = $scriptPath; Dir = $repoRoot; Args = @('-Fix'); Env = @{}; Exit = 2; Tree = $repoSkills },
    @{ Label = 'fixture default outside Git'; Script = $fixtureScript; Dir = $fixtureRoot; Args = @(); Env = $noGit; Exit = 0; Tree = $fixtureRoot },
    @{ Label = 'fixture -Fix outside Git'; Script = $fixtureScript; Dir = $fixtureRoot; Args = @('-Fix'); Env = $noGit; Exit = 2; Tree = $fixtureRoot },
    @{ Label = 'unknown parameter'; Script = $fixtureScript; Dir = $fixtureRoot; Args = @('-Force'); Env = @{}; Exit = 1; Tree = $fixtureRoot }
)

foreach ($case in $cases) {
    $before = Get-TreeSnapshot $case.Tree
    $result = Invoke-Guard -Script $case.Script -WorkDir $case.Dir -Arguments $case.Args -Env $case.Env
    $after = Get-TreeSnapshot $case.Tree
    Assert-SnapshotEqual $before $after $case.Label
    if ($result.ExitCode -ne $case.Exit) { $failures.Add("$($case.Label): expected exit $($case.Exit), got $($result.ExitCode)") }
    if ($case.Exit -ne 1) {
        foreach ($needle in @('DEPRECATED', '#3656', '#3654', '#3655', 'No files were read or modified')) {
            if ($result.Output -notmatch [regex]::Escape($needle)) { $failures.Add("$($case.Label): output missing '$needle'") }
        }
        if ($result.Output -match '(?i)would fix|fixed \d|schema valid|nothing to fix') { $failures.Add("$($case.Label): success-shaped or validation-claiming output") }
    }
    if ($case.Exit -eq 2 -and $result.Output -notmatch 'ERROR \[deprecation\] mode=Fix exit=2') { $failures.Add("$($case.Label): missing stable refusal diagnostic") }
}

# Inaccessible catalog: exclusive locks on skill files plus a non-listable skills
# directory make any traversal or read surface as an access error in the output.
$lockedSkills = Join-Path $fixtureRoot 'skills'
$before = Get-TreeSnapshot $fixtureRoot
foreach ($mode in @(@{ Args = @(); Exit = 0 }, @{ Args = @('-Fix'); Exit = 2 })) {
    $label = "inaccessible catalog $($mode.Args -join ' ')".Trim()
    $locks = Get-ChildItem $lockedSkills -Recurse -File | ForEach-Object {
        [IO.File]::Open($_.FullName, 'Open', 'ReadWrite', 'None')
    }
    if ($IsWindows) {
        & icacls $lockedSkills /deny "$([Environment]::UserDomainName)\$([Environment]::UserName):(RD)" | Out-Null
    } else {
        & chmod 000 $lockedSkills
    }
    try {
        $result = Invoke-Guard -Script $fixtureScript -WorkDir $fixtureRoot -Arguments $mode.Args -Env $noGit
    } finally {
        if ($IsWindows) {
            & icacls $lockedSkills /remove:d "$([Environment]::UserDomainName)\$([Environment]::UserName)" | Out-Null
        } else {
            & chmod 755 $lockedSkills
        }
        $locks | ForEach-Object { $_.Dispose() }
    }
    if ($result.ExitCode -ne $mode.Exit) { $failures.Add("$label`: expected exit $($mode.Exit), got $($result.ExitCode)") }
    if ($result.Output -match '(?i)denied|being used by another process|UnauthorizedAccess|permission') {
        $failures.Add("$label`: guard attempted to traverse or read the catalog")
    }
}
Assert-SnapshotEqual $before (Get-TreeSnapshot $fixtureRoot) 'inaccessible catalog'

# A wrapping caller must observe the refusal rather than a silent success.
$wrapper = "& pwsh -NoProfile -File '$fixtureScript' -Fix 2>`$null; exit `$LASTEXITCODE"
& pwsh -NoProfile -Command $wrapper | Out-Null
if ($LASTEXITCODE -ne 2) { $failures.Add("wrapped caller: expected propagated exit 2, got $LASTEXITCODE") }

Remove-Item $fixtureRoot -Recurse -Force

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'fix-skill-frontmatter retirement guard tests passed' -ForegroundColor Green
