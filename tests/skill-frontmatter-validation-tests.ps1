$ErrorActionPreference = 'Stop'

# Positive/negative fixtures for scripts/validate-skill-frontmatter.ps1 (#3655).
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$validator = Join-Path $repoRoot 'scripts' 'validate-skill-frontmatter.ps1'
$tempRoot = Join-Path $PSScriptRoot 'tmp-skill-frontmatter-tests'
$failures = [System.Collections.Generic.List[string]]::new()

function New-Fixture([string]$Root, [string]$RelPath, [string]$Content) {
    $full = Join-Path $Root $RelPath
    New-Item -ItemType Directory -Path (Split-Path -Parent $full) -Force | Out-Null
    [IO.File]::WriteAllText($full, $Content)
}

function Invoke-Validator([string]$Root, [string[]]$Arguments) {
    $output = & pwsh -NoProfile -File $validator -RootDir $Root @Arguments 2>&1 | Out-String
    return @{ Passed = ($LASTEXITCODE -eq 0); Output = $output }
}

function Assert-Case([string]$Label, [hashtable]$Result, [bool]$ExpectPass, [string]$Diagnostic) {
    if ($Result.Passed -ne $ExpectPass) { $failures.Add("${Label}: expected pass=$ExpectPass. Output: $($Result.Output)"); return }
    if ($Diagnostic -and -not $Result.Output.Contains($Diagnostic)) { $failures.Add("${Label}: missing diagnostic '$Diagnostic'. Output: $($Result.Output)") }
}

$ok = 'compatibility: [github-copilot-cli]'
$longDesc = 'd' * 1024
$name64 = 'a' * 64

# Each case: profile, skill directory, frontmatter body (delimiters are added), expect pass, diagnostic.
$cases = @(
    @('source-skill', 'minimal', "name: minimal`ndescription: Minimal skill.`n$ok", $true, ''),
    @('source-skill', 'rich', "name: `"rich`"`ndescription: >-`n  Folded text, with *stars*`n  and: colons inside.`ncompatibility:`n  - github-copilot-cli`n  - vscode-chat`nmetadata:`n  category: tools`n  audience:`n    - developer`nallowed-tools:`n- bash`nvisibility: public  # comment", $true, ''),
    @('source-skill', $name64, "name: $name64`ndescription: $longDesc`n$ok", $true, ''),
    @('portable-skill', 'portable-min', "name: portable-min`ndescription: Only required fields.", $true, ''),
    @('portable-skill', 'portable-opt', "name: portable-opt`ndescription: ok`ncompatibility: Requires git.`nlicense: MIT`nmetadata:`n  author: team`n  version: `"1.0`"`nallowed-tools: Bash(git:*) Read", $true, ''),
    @('source-skill', 'no-name', "description: x`n$ok", $false, 'name: required field is missing'),
    @('source-skill', 'dup', "name: dup`nname: dup`ndescription: x`n$ok", $false, "duplicate key 'name'"),
    @('source-skill', '123', "name: 123`ndescription: x`n$ok", $false, 'must be a string (found number)'),
    @('source-skill', 'seq-desc', "name: seq-desc`ndescription: [a]`n$ok", $false, 'must be a string (found sequence)'),
    @('source-skill', 'long-desc', "name: long-desc`ndescription: $longDesc-`n$ok", $false, 'must be 1-1024 characters (found 1025)'),
    @('source-skill', 'Upper', "name: Upper`ndescription: x`n$ok", $false, 'lowercase letters/digits'),
    @('source-skill', 'dir-name', "name: other-name`ndescription: x`n$ok", $false, 'must match the skill directory name'),
    @('source-skill', 'colon', "name: colon`ndescription: USE FOR: x`n$ok", $false, "malformed value for 'description'"),
    @('source-skill', 'anchor', "name: &n anchor`ndescription: x`n$ok", $false, 'anchors, aliases'),
    @('source-skill', 'no-compat', "name: no-compat`ndescription: x", $false, 'require a non-empty host list'),
    @('source-skill', 'bad-host', "name: bad-host`ndescription: x`ncompatibility: [github-copilot-cli, true]", $false, 'entries must be unique canonical host strings'),
    @('source-skill', 'open-flow', "name: open-flow`ndescription: x`n$ok`nextra: [unterminated", $false, "malformed flow collection for 'extra'"),
    @('portable-skill', 'p-compat', "name: p-compat`ndescription: x`n$ok", $false, 'compatibility: must be a 1-500 character string'),
    @('portable-skill', 'p-meta', "name: p-meta`ndescription: x`nmetadata:`n  tags:`n    - a", $false, 'metadata: keys and values must be strings'),
    @('source-skill', 'too-big', "name: too-big`ndescription: x`n$ok`n# $('x' * 65536)", $false, 'exceeds 65536 bytes')
)

try {
    if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
    $caseRoot = Join-Path $tempRoot 'cases'
    $roots = @{ 'source-skill' = 'skills'; 'portable-skill' = '.agents/skills' }
    foreach ($case in $cases) {
        $rel = "$($roots[$case[0]])/$($case[1])/SKILL.md"
        New-Fixture $caseRoot $rel "---`n$($case[2])`n---`n# Body`n`n``````yaml`nname: Not-Frontmatter`n```````n"
        Assert-Case "$($case[0]) $($case[1])" (Invoke-Validator $caseRoot @('-ProfileName', $case[0], '-Path', $rel)) $case[3] $case[4]
    }


    # Routing: profiles come from trusted configuration only.
    Assert-Case 'path traversal' (Invoke-Validator $caseRoot @('-ProfileName', 'source-skill', '-Path', 'skills/../.agents/skills/portable-min/SKILL.md')) $false 'routing error'

    # Agents are outside the skill profiles: a skill-field-free agent passes and does not mask a bad skill.
    $agentRoot = Join-Path $tempRoot 'agents-only'
    New-Fixture $agentRoot 'agents/sample.agent.md' "---`nname: sample`ndescription: Agent.`nvisibility: public`n---`n"
    New-Fixture $agentRoot 'skills/good/SKILL.md' "---`nname: good`ndescription: x`n$ok`n---`n"
    Assert-Case 'agent without skill fields' (Invoke-Validator $agentRoot @()) $true 'Skill frontmatter validation passed.'
    New-Fixture $agentRoot 'skills/bad/SKILL.md' "---`nname: wrong`ndescription: x`n$ok`n---`n"
    Assert-Case 'invalid skill beside agent' (Invoke-Validator $agentRoot @()) $false 'skills/bad/SKILL.md: name: must match the skill directory name'
}
finally {
    if (Test-Path $tempRoot) { Remove-Item $tempRoot -Recurse -Force }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    throw "Skill frontmatter validation tests failed: $($failures.Count) case(s)"
}
Write-Host "Skill frontmatter validation tests passed ($($cases.Count + 4) cases)." -ForegroundColor Green
