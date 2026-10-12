[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path,
    [string]$ProfileName = '',
    [string]$Path = ''
)

# Agent Skills required-field validation (#3655). Profiles come only from the trusted
# root mapping below; they are never inferred from file content. Agent files are out of
# scope and keep their own checks in validate-basecoat.ps1.
#
# Parser: a fail-closed reader for the YAML 1.2 core-schema subset used by skill
# frontmatter. It never constructs objects or resolves tags; anchors, aliases, tags,
# merge keys, duplicate keys, multiple documents and unsupported top-level syntax are
# rejected instead of guessed. Size and depth limits are enforced before values resolve.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$profileRoots = [ordered]@{ 'source-skill' = 'skills'; 'portable-skill' = '.agents/skills' }
$maxBytes = 65536; $maxDepth = 32; $maxNodes = 10000
$namePattern = '^[a-z0-9]+(?:-[a-z0-9]+)*$'
$canonicalHosts = @('copilot-chat', 'copilot-coding-agent', 'github-copilot-cli', 'vscode-chat', 'mcp', 'github-actions')
$script:errorCount = 0

function Write-SkillError([string]$ProfileId, [string]$RelPath, [string]$Field, [string]$Reason) {
    Write-Host "ERROR: [$ProfileId] ${RelPath}: ${Field}: $Reason" -ForegroundColor Red
    $script:errorCount++
}

function Test-FlowCollection([string]$Value) {
    $closers = [Collections.Generic.Stack[char]]::new(); $quote = [char]0
    for ($i = 0; $i -lt $Value.Length; $i++) {
        $ch = $Value[$i]
        if ($quote -ne [char]0) {
            if ($quote -eq '"' -and $ch -eq '\') { $i++ }
            elseif ($ch -eq $quote) { if ($quote -eq "'" -and $i + 1 -lt $Value.Length -and $Value[$i + 1] -eq "'") { $i++ } else { $quote = [char]0 } }
            continue
        }
        if ($ch -in '"', "'") { $quote = $ch }
        elseif ($ch -eq '[') { $closers.Push(']') }
        elseif ($ch -eq '{') { $closers.Push('}') }
        elseif ($ch -in ']', '}') {
            if ($closers.Count -eq 0 -or $closers.Pop() -ne $ch) { return $false }
            if ($closers.Count -eq 0) { return ($Value.Substring($i + 1).Trim() -eq '') }
        }
    }
    return $false
}

function Resolve-YamlScalar([string]$Raw) {
    $v = $Raw.Trim()
    if ($v -match '^"((?:[^"\\]|\\.)*)"$') {
        return @{ Type = 'string'; Value = ($Matches[1] -replace '\\(["\\/])', '$1' -replace '\\n', "`n" -replace '\\t', "`t") }
    }
    if ($v -match "^'((?:[^']|'')*)'$") { return @{ Type = 'string'; Value = ($Matches[1] -replace "''", "'") } }
    if ($v -match '^["'']') { return @{ Type = 'invalid'; Value = $null } }
    if ($v -match '^[\[{]' -and -not (Test-FlowCollection $v)) { return @{ Type = 'invalid'; Value = $null } }
    if ($v -match '^\[') { return @{ Type = 'sequence'; Value = $null } }
    if ($v -match '^\{') { return @{ Type = 'mapping'; Value = $null } }
    if ($v -match '^(~|null|Null|NULL)?$') { return @{ Type = 'null'; Value = $null } }
    if ($v -cmatch '^(true|True|TRUE|false|False|FALSE)$') { return @{ Type = 'boolean'; Value = $null } }
    if ($v -match '^[-+]?([0-9]+|0o[0-7]+|0x[0-9a-fA-F]+|(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?|\.(inf|Inf|INF)|\.(nan|NaN|NAN))$') {
        return @{ Type = 'number'; Value = $null }
    }
    if ($v -match ':(\s|$)' -or $v -match '^[@`%|>,\]}]' -or $v -match '^[-?:](\s|$)') { return @{ Type = 'invalid'; Value = $null } }
    return @{ Type = 'string'; Value = $v }
}

function Read-SkillFrontmatter([string]$FilePath) { return Read-SkillFrontmatterText ([IO.File]::ReadAllText($FilePath, [Text.Encoding]::UTF8)) }

function Read-SkillFrontmatterText([string]$Text) {
    $result = @{ Fields = [ordered]@{}; Error = $null }
    $lines = $Text.TrimStart([char]0xFEFF) -split '\r?\n'
    if ($lines.Count -lt 2 -or $lines[0] -notmatch '^---\s*$') { $result.Error = 'missing opening frontmatter delimiter'; return $result }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^---\s*$') { $end = $i; break } }
    if ($end -lt 0) { $result.Error = 'missing closing frontmatter delimiter'; return $result }
    $fm = @(if ($end -gt 1) { $lines[1..($end - 1)] })
    if ([Text.Encoding]::UTF8.GetByteCount(($fm -join "`n")) -gt $maxBytes) { $result.Error = "frontmatter exceeds $maxBytes bytes"; return $result }

    $nodes = 0; $stack = [Collections.Generic.List[int]]::new(); $current = $null; $blockIndent = -1
    foreach ($line in $fm) {
        if ($line -match '^\s*(#.*)?$') { if ($current) { $current.Children.Add($line) }; continue }
        if ($line -match '^\.\.\.\s*$' -or $line -match '^%') { $result.Error = 'multiple documents or directives are not supported'; return $result }
        $indent = $line.Length - $line.TrimStart(' ').Length
        if ($line.Substring($indent).StartsWith("`t")) { $result.Error = 'tab indentation is not valid YAML'; return $result }
        if ($blockIndent -ge 0 -and $indent -ge $blockIndent) { $current.Children.Add($line); $nodes++; continue }
        $blockIndent = -1
        while ($stack.Count -gt 0 -and $stack[$stack.Count - 1] -ge $indent) { $stack.RemoveAt($stack.Count - 1) }
        $stack.Add($indent)
        $body = $line.Substring($indent)
        $flowDepth = 0; $maxFlow = 0
        foreach ($ch in $body.ToCharArray()) { if ($ch -in '[', '{') { $flowDepth++; $maxFlow = [Math]::Max($maxFlow, $flowDepth) } elseif ($ch -in ']', '}') { $flowDepth-- } }
        $seqDepth = ([regex]::Match($body, '^(-\s+)*')).Value.Split('-').Count - 1
        $nodes += 1 + $seqDepth + ([regex]::Matches($body, ',')).Count
        if ($stack.Count + $seqDepth + $maxFlow -gt $maxDepth) { $result.Error = "frontmatter nesting exceeds depth $maxDepth"; return $result }
        if ($nodes -gt $maxNodes) { $result.Error = "frontmatter exceeds $maxNodes nodes"; return $result }
        $unquoted = $body -replace '"(?:[^"\\]|\\.)*"', '""' -replace "'(?:[^']|'')*'", "''"
        if ($unquoted -match '^(-\s+)*(<<|[^\s:]+:\s+<<)\s*:' -or $unquoted -match '^(-\s+)*([^\s:"''][^:]*:\s+)?[&*!]' -or $unquoted -match '^(-\s+)*([^\s:]+:\s+)?[\[{].*[\[{,]\s*[&*!]') {
            $result.Error = 'anchors, aliases, tags and merge keys are not supported'; return $result
        }
        if ($indent -gt 0 -or $body -match '^-(\s|$)') {
            if (-not $current) { $result.Error = 'frontmatter root must be a mapping'; return $result }
            $current.Children.Add($line)
            if ($body -match '^(-\s+)?[^\s:"''#][^:]*:\s*[|>][-+0-9]*\s*(#.*)?$') { $blockIndent = $indent + 1 }
            continue
        }
        if ($body -notmatch '^([A-Za-z0-9_][A-Za-z0-9_.-]*):(?:\s+(.*))?$') { $result.Error = 'unsupported or malformed top-level entry; frontmatter root must be a simple mapping'; return $result }
        $key = $Matches[1]; $inline = if ($Matches.Count -gt 2) { $Matches[2] } else { '' }
        if ($result.Fields.Contains($key)) { $result.Error = "duplicate key '$key'"; return $result }
        $current = @{ Inline = ($inline -replace '\s+#.*$', '').Trim(); Children = [Collections.Generic.List[string]]::new() }
        $result.Fields[$key] = $current
        if ($current.Inline -match '^[|>][-+0-9]*$') { $blockIndent = 1 }
    }

    foreach ($key in @($result.Fields.Keys)) {
        $f = $result.Fields[$key]; $kids = @($f.Children | Where-Object { $_ -notmatch '^\s*(#.*)?$' })
        if ($f.Inline -match '^[|>]') {
            $f.Type = 'string'; $f.Value = (@($f.Children | ForEach-Object { $_.Trim() }) -join $(if ($f.Inline -like '|*') { "`n" } else { ' ' })).Trim()
        }
        elseif ($f.Inline) {
            $joined = (@($f.Inline) + @($kids | ForEach-Object { $_.Trim() })) -join ' '
            if ($joined -match '^[\[{]' -and -not (Test-FlowCollection $joined)) { $result.Error = "malformed flow collection for '$key'"; return $result }
            if ($joined -match '^\[(.*)\]$') {
                $f.Type = 'sequence'; $f.Items = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            }
            else { $r = Resolve-YamlScalar $joined; $f.Type = $r.Type; $f.Value = $r.Value }
        }
        elseif ($kids.Count -eq 0) { $f.Type = 'null'; $f.Value = $null }
        elseif ($kids[0].TrimStart() -match '^-(\s|$)') {
            $minIndent = $kids[0].Length - $kids[0].TrimStart(' ').Length
            $f.Type = 'sequence'; $f.Items = @($kids | Where-Object { ($_.Length - $_.TrimStart(' ').Length) -eq $minIndent } | ForEach-Object { ($_.Trim() -replace '^-\s*', '') })
        }
        else {
            $minIndent = $kids[0].Length - $kids[0].TrimStart(' ').Length
            $f.Type = 'mapping'; $f.Entries = [ordered]@{}
            for ($k = 0; $k -lt $kids.Count; $k++) {
                $kidIndent = $kids[$k].Length - $kids[$k].TrimStart(' ').Length
                if ($kidIndent -gt $minIndent) { continue }
                if ($k -gt 0 -and $kids[$k].Trim() -match '^-(\s|$)') { $f.Entries[$childKey] = @{ Type = 'collection' }; continue }
                if ($kidIndent -lt $minIndent -or $kids[$k].Trim() -notmatch '^([^\s:"''#][^:]*):(?:\s+(.*))?$') { $result.Error = "malformed mapping under '$key'"; return $result }
                $childKey = $Matches[1]; $childRaw = if ($Matches.Count -gt 2) { $Matches[2] -replace '\s+#.*$', '' } else { '' }
                if ($f.Entries.Contains($childKey)) { $result.Error = "duplicate key '$key.$childKey'"; return $result }
                $nested = ($k + 1 -lt $kids.Count) -and (($kids[$k + 1].Length - $kids[$k + 1].TrimStart(' ').Length) -gt $minIndent)
                $f.Entries[$childKey] = if ($nested -and -not $childRaw) { @{ Type = 'collection' } } else { Resolve-YamlScalar $childRaw }
            }
        }
        if ($f.Type -eq 'invalid') { $result.Error = "malformed value for '$key'"; return $result }
    }
    return $result
}

function Test-SkillFile([string]$ProfileId, [IO.FileInfo]$File, [string]$RelPath) {
    $linked = [bool]($File.Attributes -band [IO.FileAttributes]::ReparsePoint)
    for ($dir = $File.Directory; $dir -and $dir.FullName.TrimEnd('\', '/') -ne $root.TrimEnd('\', '/'); $dir = $dir.Parent) {
        $linked = $linked -or [bool]($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)
    }
    if ($linked) { Write-SkillError $ProfileId $RelPath 'routing' 'symlinked skill paths are not allowed'; return }
    $parsed = Read-SkillFrontmatter $File.FullName
    if ($parsed.Error) { Write-SkillError $ProfileId $RelPath 'frontmatter' $parsed.Error; return }
    Test-SkillFields $ProfileId $parsed.Fields $File.Directory.Name $RelPath
}

function Test-SkillFields([string]$ProfileId, $Fields, [string]$DirName, [string]$RelPath) {
    $name = if ($fields.Contains('name')) { $fields['name'] } else { $null }
    if (-not $name) { Write-SkillError $ProfileId $RelPath 'name' 'required field is missing' }
    elseif ($name.Type -ne 'string') { Write-SkillError $ProfileId $RelPath 'name' "must be a string (found $($name.Type))" }
    elseif ($name.Value.Length -lt 1 -or $name.Value.Length -gt 64 -or $name.Value -cnotmatch $namePattern) {
        Write-SkillError $ProfileId $RelPath 'name' 'must be 1-64 lowercase letters/digits separated by single hyphens'
    }
    elseif ($name.Value -cne $DirName) { Write-SkillError $ProfileId $RelPath 'name' 'must match the skill directory name' }

    $desc = if ($fields.Contains('description')) { $fields['description'] } else { $null }
    if (-not $desc) { Write-SkillError $ProfileId $RelPath 'description' 'required field is missing' }
    elseif ($desc.Type -ne 'string') { Write-SkillError $ProfileId $RelPath 'description' "must be a string (found $($desc.Type))" }
    elseif ($desc.Value.Length -lt 1 -or $desc.Value.Length -gt 1024) {
        Write-SkillError $ProfileId $RelPath 'description' "must be 1-1024 characters (found $($desc.Value.Length))"
    }

    $compat = if ($fields.Contains('compatibility')) { $fields['compatibility'] } else { $null }
    if ($ProfileId -eq 'source-skill') {
        if (-not $compat -or $compat.Type -ne 'sequence' -or @($compat.Items).Count -eq 0) {
            Write-SkillError $ProfileId $RelPath 'compatibility' 'BaseCoat source skills require a non-empty host list'
        }
        else {
            $hosts = @($compat.Items | ForEach-Object { $r = Resolve-YamlScalar $_; if ($r.Type -eq 'string') { $r.Value } else { "<$($r.Type)>" } })
            if (@($hosts | Where-Object { $_ -cnotin $canonicalHosts }).Count -gt 0 -or @($hosts | Select-Object -Unique).Count -ne $hosts.Count) {
                Write-SkillError $ProfileId $RelPath 'compatibility' 'entries must be unique canonical host strings'
            }
        }
        return
    }

    if ($compat -and ($compat.Type -ne 'string' -or $compat.Value.Length -lt 1 -or $compat.Value.Length -gt 500)) {
        Write-SkillError $ProfileId $RelPath 'compatibility' 'must be a 1-500 character string when present'
    }
    foreach ($optional in 'license', 'allowed-tools') {
        if ($fields.Contains($optional) -and $fields[$optional].Type -ne 'string') { Write-SkillError $ProfileId $RelPath $optional 'must be a string when present' }
    }
    if ($fields.Contains('metadata')) {
        $meta = $fields['metadata']
        if ($meta.Type -ne 'mapping') { Write-SkillError $ProfileId $RelPath 'metadata' 'must be a mapping when present' }
        elseif (@($meta.Entries.Values | Where-Object { $_.Type -ne 'string' }).Count -gt 0) {
            Write-SkillError $ProfileId $RelPath 'metadata' 'keys and values must be strings'
        }
    }
}

# Dot-sourcing (for example by preview-portable-skill-export.ps1) loads the parser and field checks only.
if ($MyInvocation.InvocationName -eq '.') { return }

$root = (Resolve-Path -LiteralPath $RootDir).Path
$rootPaths = @{}
foreach ($entry in $profileRoots.GetEnumerator()) { $rootPaths[$entry.Key] = [IO.Path]::GetFullPath((Join-Path $root $entry.Value)) }
foreach ($a in $rootPaths.Keys) {
    foreach ($b in $rootPaths.Keys) {
        if ($a -ne $b -and ($rootPaths[$a] + [IO.Path]::DirectorySeparatorChar).StartsWith($rootPaths[$b] + [IO.Path]::DirectorySeparatorChar)) {
            throw "Skill frontmatter routing error: configured roots for '$a' and '$b' overlap"
        }
    }
}

if ($ProfileName -or $Path) {
    if (-not $rootPaths.ContainsKey($ProfileName)) { throw "Skill frontmatter routing error: unknown or missing profile '$ProfileName'" }
    $full = [IO.Path]::GetFullPath((Join-Path $root $Path))
    $parent = Split-Path -Parent (Split-Path -Parent $full)
    if (-not $Path -or (Split-Path -Leaf $full) -ne 'SKILL.md' -or $parent -ne $rootPaths[$ProfileName] -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Skill frontmatter routing error: '$Path' is not a <directory>/SKILL.md beneath the '$ProfileName' root"
    }
    Test-SkillFile $ProfileName (Get-Item -LiteralPath $full) $Path
}
else {
    foreach ($profileId in $rootPaths.Keys) {
        if (-not (Test-Path -LiteralPath $rootPaths[$profileId] -PathType Container)) { continue }
        Get-ChildItem -LiteralPath $rootPaths[$profileId] -Recurse -Filter 'SKILL.md' -File | Sort-Object FullName | ForEach-Object {
            $rel = [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/'
            if ($_.Directory.Parent.FullName -ne $rootPaths[$profileId]) { Write-SkillError $profileId $rel 'routing' 'SKILL.md must be directly inside <root>/<directory>/' }
            else { Test-SkillFile $profileId $_ $rel }
        }
    }
}

if ($script:errorCount -gt 0) { throw "Skill frontmatter validation failed with $($script:errorCount) error(s)" }
Write-Host 'Skill frontmatter validation passed.'
