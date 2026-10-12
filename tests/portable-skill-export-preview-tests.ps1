$ErrorActionPreference = 'Stop'

# Fixtures for scripts/preview-portable-skill-export.ps1 (#3654 part 1).
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$preview = Join-Path $repoRoot 'scripts' 'preview-portable-skill-export.ps1'
$tempRoot = Join-Path $PSScriptRoot 'tmp-portable-skill-preview-tests'
$failures = [System.Collections.Generic.List[string]]::new()
$utf8 = [Text.UTF8Encoding]::new($false)
$compat = "compatibility:`n  - github-copilot-cli"

function New-Skill([string]$Name, [string]$Content) {
    $dir = Join-Path $tempRoot 'skills' $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $dir 'SKILL.md'), $utf8.GetBytes($Content))
}

function Invoke-Preview([string[]]$Names) {
    $out = & pwsh -NoProfile -Command "& '$preview' -RootDir '$tempRoot' -Skill $($Names -join ',')" 2>&1 | Out-String
    $code = $LASTEXITCODE
    $json = try { $out | ConvertFrom-Json } catch { $null }
    return @{ Passed = ($code -eq 0); Output = $out; Results = if ($json) { @($json.results) } else { @() } }
}

function Assert-That([string]$Label, [bool]$Condition, [hashtable]$Run) {
    if (-not $Condition) { $failures.Add("${Label}. Output: $($Run.Output)") }
}

function Get-Sha([byte[]]$Bytes) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant() }

try {
    if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
    $richBody = "`r`n# Rich`r`n`r`nSee [guide](references/guide.md).  `r`n"
    New-Skill 'rich' "---`nname: rich`ndescription: >-`n  Folded text with `"quotes`"`n  over lines.`n$compat`nallowed-tools: []`nmetadata:`n  category: tools`nvisibility: public`n---$richBody"
    New-Skill 'empty-body' "---`nname: empty-body`ndescription: 'It''s minimal.'`n$compat`n---"
    New-Skill 'mismatch' "---`nname: other`ndescription: x`n$compat`n---`n"
    New-Skill 'nested-dup' "---`nname: nested-dup`ndescription: x`n$compat`nmetadata:`n  owner: a`n  owner: b`n---`n"
    New-Skill 'backslash' "---`nname: backslash`ndescription: C:\path`n$compat`n---`n"
    $richFile = Join-Path $tempRoot 'skills' 'rich' 'SKILL.md'
    $before = Get-Sha ([IO.File]::ReadAllBytes($richFile))
    $treeBefore = @(Get-ChildItem $tempRoot -Recurse -Force).Count

    $run = Invoke-Preview @('rich', 'empty-body')
    Assert-That 'valid batch exits zero' $run.Passed $run
    $rich = $run.Results | Where-Object skill -eq 'rich'
    Assert-That 'rich is projectable and unpublished' ($rich.status -eq 'projectable' -and $rich.published -eq $false -and $rich.companions -eq 'not-evaluated' -and $rich.host -eq 'unverified') $run
    Assert-That 'only name and description are projected' ($rich.projected_frontmatter -ceq "---`nname: rich`ndescription: `"Folded text with \`"quotes\`" over lines.`"`n---") $run
    Assert-That 'body digest matches exact CRLF source bytes' ($rich.body_sha256 -eq (Get-Sha $utf8.GetBytes($richBody)) -and $rich.projected_body_sha256 -eq $rich.body_sha256) $run
    $omitted = @{}; $rich.omitted_fields | ForEach-Object { $omitted[$_.field] = $_.reason }
    Assert-That 'source-only fields are omitted with reasons' ((@('allowed-tools', 'compatibility', 'metadata', 'visibility') | Where-Object { -not $omitted[$_] }).Count -eq 0) $run
    Assert-That 'empty allowed-tools gains no deny-all semantics' ($omitted['allowed-tools'] -match 'no allow/deny semantics are inferred') $run
    $empty = $run.Results | Where-Object skill -eq 'empty-body'
    Assert-That 'empty body projects with matching digests' ($empty.status -eq 'projectable' -and $empty.body_sha256 -eq (Get-Sha ([byte[]]::new(0)))) $run
    Assert-That 'source bytes unchanged and nothing written' ((Get-Sha ([IO.File]::ReadAllBytes($richFile))) -eq $before -and @(Get-ChildItem $tempRoot -Recurse -Force).Count -eq $treeBefore) $run

    $negatives = @(
        @('mismatch', 'must match the skill directory name'),
        @('nested-dup', "duplicate key 'metadata.owner'"),
        @('backslash', 'cannot be projected losslessly'),
        @('missing', 'source SKILL.md not found'),
        @('..\rich', 'must be a source directory name')
    )
    foreach ($case in $negatives) {
        $run = Invoke-Preview @("'$($case[0])'")
        $result = $run.Results | Select-Object -First 1
        Assert-That "$($case[0]) is invalid" (-not $run.Passed -and $result.status -eq 'invalid' -and (@($result.errors) -join ' ').Contains($case[1])) $run
    }

    $run = Invoke-Preview @('rich', 'mismatch')
    Assert-That 'one invalid member fails the whole request' (-not $run.Passed -and ($run.Results | Where-Object skill -eq 'rich').status -eq 'projectable') $run
    $run = Invoke-Preview @('rich', 'rich')
    Assert-That 'duplicate selection is rejected' (-not $run.Passed -and $run.Output.Contains('duplicate skill selection')) $run

    $badBytes = [byte[]]($utf8.GetBytes("---`nname: bad-utf8`ndescription: x`n$compat`n---`n") + [byte[]](0xFF, 0x0A))
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'skills' 'bad-utf8') -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $tempRoot 'skills' 'bad-utf8' 'SKILL.md'), $badBytes)
    $run = Invoke-Preview @('bad-utf8')
    Assert-That 'malformed UTF-8 is invalid' (-not $run.Passed -and (@($run.Results[0].errors) -join ' ').Contains('not valid UTF-8')) $run

    # A linked skills root must not let reads escape the requested root.
    $linkedRoot = Join-Path $tempRoot 'linked-root'
    New-Item -ItemType Directory -Path $linkedRoot -Force | Out-Null
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path (Join-Path $linkedRoot 'skills') -Target (Join-Path $tempRoot 'skills') | Out-Null
    $out = & pwsh -NoProfile -Command "& '$preview' -RootDir '$linkedRoot' -Skill rich" 2>&1 | Out-String
    $linkRun = @{ Passed = ($LASTEXITCODE -eq 0); Output = $out }
    Assert-That 'symlinked skills root is rejected' (-not $linkRun.Passed -and $out.Contains('symlinked source paths are not exported')) $linkRun
    (Get-Item (Join-Path $linkedRoot 'skills')).Delete()
}
finally {
    if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    throw "Portable skill preview tests failed: $($failures.Count) case(s)"
}
Write-Host 'Portable skill preview tests passed.' -ForegroundColor Green
