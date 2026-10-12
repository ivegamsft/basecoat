[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path,
    [Parameter(Mandatory)][string[]]$Skill
)

# Portable Agent Skills projection preview (#3654, part 1). For each explicitly named source
# skill it validates the BaseCoat source profile, projects only the fields this contract can
# map without a target profile (name, description), validates the projection independently
# with the portable-skill profile and proves the Markdown body bytes are unchanged.
# It never writes files: companions, the reference validator and host loaders are not
# evaluated, so a projectable result is not a published or supported portable export.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$skillRoot = [IO.Path]::GetFullPath((Join-Path (Resolve-Path -LiteralPath $RootDir).Path 'skills'))
. (Join-Path $PSScriptRoot 'validate-skill-frontmatter.ps1') -RootDir $RootDir
$script:issues = [Collections.Generic.List[string]]::new()
function Write-SkillError([string]$ProfileId, [string]$RelPath, [string]$Field, [string]$Reason) { $script:issues.Add("[$ProfileId] ${Field}: $Reason") }

$omissionReasons = @{
    'compatibility' = 'no target-profile compatibility mapping; the BaseCoat host list is not joined or reinterpreted'
    'allowed-tools' = 'no authoritative versioned tool policy; the source list is not projected and no allow/deny semantics are inferred'
    'metadata'      = 'no metadata allowlist; values are not stringified or exported'
    'license'       = 'license passthrough is not enabled by a target profile'
}
$utf8 = [Text.UTF8Encoding]::new($false, $true)

function Get-Sha256([byte[]]$Bytes) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant() }

function Get-BodyOffset([byte[]]$Bytes) {
    # Byte offset immediately after the closing '---' delimiter (its line ending belongs to the body).
    $text = $utf8.GetString($Bytes)
    $open = [regex]::Match($text, '\A\uFEFF?---[ \t]*\r?\n')
    if (-not $open.Success) { return -1 }
    $close = [regex]::Match($text.Substring($open.Length), '(?m)^---[ \t]*(?=\r?\n|\z)')
    if (-not $close.Success) { return -1 }
    return $utf8.GetByteCount($text.Substring(0, $open.Length + $close.Index + $close.Length))
}

function ConvertTo-YamlDoubleQuoted([string]$Value) {
    if ($Value -match '[\x00-\x08\x0B-\x1F\x7F\\]') { return $null }
    return '"' + ($Value -replace '"', '\"' -replace "`n", '\n' -replace "`t", '\t') + '"'
}

function Invoke-SkillPreview([string]$Name) {
    $entry = [ordered]@{ skill = $Name; status = 'invalid'; source = "skills/$Name/SKILL.md"; errors = @() }
    $script:issues.Clear()
    if ($Name -cnotmatch $namePattern -or $Name.Length -gt 64) { $entry.errors = @('skill must be a source directory name (lowercase letters/digits and single hyphens)'); return $entry }
    $file = Join-Path $skillRoot $Name 'SKILL.md'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { $entry.errors = @('source SKILL.md not found'); return $entry }
    $fileItem = Get-Item -LiteralPath $file
    $linked = [bool]($fileItem.Attributes -band [IO.FileAttributes]::ReparsePoint)
    for ($dir = $fileItem.Directory; $dir; $dir = $dir.Parent) {
        $linked = $linked -or [bool]($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)
        if ($dir.FullName.TrimEnd('\', '/') -eq $skillRoot.TrimEnd('\', '/')) { break }
    }
    if ($linked) { $entry.errors = @('symlinked source paths are not exported'); return $entry }

    $bytes = [IO.File]::ReadAllBytes($file)
    $entry.source_sha256 = Get-Sha256 $bytes
    try { $sourceText = $utf8.GetString($bytes) }
    catch [Text.DecoderFallbackException] { $entry.errors = @('source: SKILL.md is not valid UTF-8'); return $entry }
    $parsed = Read-SkillFrontmatterText $sourceText
    $offset = Get-BodyOffset $bytes
    if ($parsed.Error -or $offset -lt 0) { $entry.errors = @("[source-skill] frontmatter: $(if ($parsed.Error) { $parsed.Error } else { 'delimiters not found' })"); return $entry }
    Test-SkillFields 'source-skill' $parsed.Fields $Name $entry.source
    $entry.source_profile = if ($script:issues.Count -eq 0) { 'passed' } else { 'failed' }
    if ($script:issues.Count -gt 0) { $entry.errors = @($script:issues); return $entry }

    $quoted = ConvertTo-YamlDoubleQuoted $parsed.Fields['description'].Value
    if ($null -eq $quoted) { $entry.errors = @('[portable-skill] description: control characters and backslashes cannot be projected losslessly'); return $entry }
    $frontmatter = "---`nname: $($parsed.Fields['name'].Value)`ndescription: $quoted`n---"
    [byte[]]$body = @(); if ($offset -lt $bytes.Length) { $body = $bytes[$offset..($bytes.Length - 1)] }
    $projected = [byte[]]($utf8.GetBytes($frontmatter) + $body)

    $reparsed = Read-SkillFrontmatterText ($utf8.GetString($projected))
    if ($reparsed.Error) { $script:issues.Add("[portable-skill] frontmatter: $($reparsed.Error)") }
    else {
        Test-SkillFields 'portable-skill' $reparsed.Fields $Name $entry.source
        if (@($reparsed.Fields.Keys) -join ',' -ne 'name,description' -or $reparsed.Fields['description'].Value -cne $parsed.Fields['description'].Value) {
            $script:issues.Add('[portable-skill] projection: projected fields do not round-trip to the source values')
        }
    }
    $projectedOffset = Get-BodyOffset $projected
    [byte[]]$projectedBody = @(); if ($projectedOffset -lt $projected.Length) { $projectedBody = $projected[$projectedOffset..($projected.Length - 1)] }
    $entry.body_sha256 = Get-Sha256 $body
    $entry.projected_body_sha256 = Get-Sha256 $projectedBody
    if ($entry.body_sha256 -ne $entry.projected_body_sha256) { $script:issues.Add('[portable-skill] body: projected body bytes differ from the source body') }
    if ((Get-Sha256 ([IO.File]::ReadAllBytes($file))) -ne $entry.source_sha256) { $script:issues.Add('source: SKILL.md changed during preview') }

    $entry.projected_fields = @('name', 'description')
    $entry.omitted_fields = @($parsed.Fields.Keys | Where-Object { $_ -notin 'name', 'description' } | ForEach-Object {
            [ordered]@{ field = $_; reason = $omissionReasons[$_] ?? 'BaseCoat source-only field; preserved in source and not a portable field' }
        })
    $entry.projected_frontmatter = $frontmatter
    $entry.companions = 'not-evaluated'
    $entry.reference_validation = 'not-run'
    $entry.host = 'unverified'
    $entry.published = $false
    $entry.portable_profile = if ($script:issues.Count -eq 0) { 'passed' } else { 'failed' }
    if ($script:issues.Count -eq 0) { $entry.status = 'projectable' } else { $entry.errors = @($script:issues) }
    return $entry
}

$duplicates = @($Skill | Group-Object -CaseSensitive | Where-Object Count -gt 1 | ForEach-Object Name)
if ($duplicates.Count -gt 0) { throw "Portable skill preview: duplicate skill selection: $($duplicates -join ', ')" }
$results = @($Skill | ForEach-Object { Invoke-SkillPreview $_ })
[ordered]@{ contract = 'portable-skill-projection-preview/v1'; results = $results } | ConvertTo-Json -Depth 6
if (@($results | Where-Object { $_.status -ne 'projectable' }).Count -gt 0) { exit 1 }
