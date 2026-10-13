$ErrorActionPreference = 'Stop'

# Validates docs/reference/intent-work-unit-contracts.md: every proposed intent
# verb keeps the shared contract shape and stays unsupported syntax.

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$docPath = Join-Path $repoRoot 'docs\reference\intent-work-unit-contracts.md'
$docDir = Split-Path $docPath -Parent

$expectedVerbs = [ordered]@{
    'prepare' = @{ Issue = 3626; States = @('prepared', 'blocked', 'limited', 'cancelled', 'unsupported_action_scope'); Forbids = @('issue or label mutation', 'approval directives or labels', 'agent assignment', 'workflow dispatch', 'implementation', 'merge', 'release', 'deployment', 'lasting access grant') }
    'spec' = @{ Issue = 3627; States = @('Reviewable', 'Blocked', 'Limited', 'Cancelled'); Forbids = @('approval fields or labels', 'approval directives', 'agent assignment', 'runtime asset edits', 'ready promotion', 'merge or release requests', 'overwriting semantic conflicts') }
}

$requiredSubsections = @(
    'Inputs',
    'Completion evidence',
    'Authorization boundary',
    'Failure and hold states',
    'Handoff',
    'Distinctness decision',
    'Verification fixtures'
)

$routeFiles = @(
    'instructions\basecoat-10-core-intent-routing.instructions.md',
    'docs\guides\intent-prefixes.md'
)

$failures = [System.Collections.Generic.List[string]]::new()
function Add-Failure([string]$message) { $failures.Add($message) }

if (-not (Test-Path $docPath)) { throw "Intent contract reference not found: $docPath" }
$content = (Get-Content -Path $docPath -Raw) -replace "`r`n", "`n"

$sections = @{}
$matches2 = [regex]::Matches($content, '(?m)^## `([a-z-]+):` [^\n]*\n')
for ($i = 0; $i -lt $matches2.Count; $i++) {
    $start = $matches2[$i].Index + $matches2[$i].Length
    $end = if ($i + 1 -lt $matches2.Count) { $matches2[$i + 1].Index } else { $content.Length }
    $sections[$matches2[$i].Groups[1].Value] = $content.Substring($start, $end - $start)
}

foreach ($verb in $sections.Keys) {
    if (-not $expectedVerbs.Contains($verb)) { Add-Failure "Undocumented verb section '${verb}:' is not in the expected verb list" }
}

$overview = [regex]::Match($content, '(?ms)^## Contract overview\n(.*?)(?=^## )').Groups[1].Value
$parserText = Get-Content (Join-Path $repoRoot 'tests\approval-contract-tests.cjs') -Raw
$candidateBlock = [regex]::Match($parserText, '(?s)for \(const token of \[([^\]]+)\]\) \{\s*for \(const \[shape, body\] of \[(.*?)\]\) addCase\(`P3725-candidate-\$\{token\}-\$\{shape\}`, body, "([^"]+)"\);')
$candidateList = $candidateBlock.Groups[1].Value
if (-not $candidateBlock.Success) {
    Add-Failure "Disabled-baseline candidate fixture block not found in tests/approval-contract-tests.cjs"
} else {
    if ($candidateBlock.Groups[3].Value -ne 'none') {
        Add-Failure "Disabled-baseline candidate fixtures must expect 'none', found '$($candidateBlock.Groups[3].Value)'"
    }
    foreach ($shape in @('leading', 'quoted', 'fenced', 'bulleted', 'embedded', 'collision')) {
        if ($candidateBlock.Groups[2].Value -notmatch "\[`"$shape`", [^\r\n]*\$\{token\}:") {
            Add-Failure "Disabled-baseline candidate fixtures are missing the '$shape' shape"
        }
    }
}

foreach ($fixtureId in @('P3725-prepare-modifier-', 'P3725-prepare-dual-prefix', 'P3725-prepare-dual-lines', 'P3725-prepare-unauthorized-actor')) {
    if (-not $parserText.Contains($fixtureId)) { Add-Failure "Disabled-baseline fixture '$fixtureId' for 'prepare:' is missing from tests/approval-contract-tests.cjs" }
}
if ($parserText -notmatch 'for \(const modifier of \["defer", "stop"\]\) \{\s*addCase\(`P3725-prepare-modifier-') {
    Add-Failure "'prepare:' defer/stop modifier fixtures are missing from tests/approval-contract-tests.cjs"
}

foreach ($verb in $expectedVerbs.Keys) {
    $meta = $expectedVerbs[$verb]
    if (-not $sections.ContainsKey($verb)) { Add-Failure "Missing section for '${verb}:'"; continue }
    $body = $sections[$verb]

    if ($body -notmatch "#$($meta.Issue)\b") { Add-Failure "'${verb}:' section does not cite #$($meta.Issue)" }
    if ($overview -notmatch "(?m)^\| ``${verb}:``") { Add-Failure "'${verb}:' missing from contract overview table" }

    $headings = [regex]::Matches($body, '(?m)^### (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() }
    if ((@($headings) -join '|') -ne ($requiredSubsections -join '|')) {
        Add-Failure "'${verb}:' subsections must be exactly, in order: $($requiredSubsections -join ', '). Found: $(@($headings) -join ', ')"
    }

    $specLink = [regex]::Match($body, 'Pinned spec:\s*\n?\[[^\]]+\]\(([^)]+)\)')
    if (-not $specLink.Success) {
        Add-Failure "'${verb}:' section lacks a 'Pinned spec:' link"
    } elseif (-not (Test-Path (Join-Path $docDir $specLink.Groups[1].Value))) {
        Add-Failure "'${verb}:' pinned spec link does not resolve: $($specLink.Groups[1].Value)"
    }

    $authz = [regex]::Match($body, '(?ms)^### Authorization boundary\n(.*?)(?=^### )').Groups[1].Value
    $neverImplied = [regex]::Match($authz, '(?ms)^Never implied:(.*?)(?:\n\n|\z)')
    if (-not $neverImplied.Success) {
        Add-Failure "'${verb}:' authorization boundary lacks a 'Never implied:' list"
    } else {
        foreach ($effect in $meta.Forbids) {
            if (($neverImplied.Groups[1].Value -replace '\s+', ' ') -notmatch "\b$([regex]::Escape($effect))\b") {
                Add-Failure "'${verb}:' 'Never implied:' list does not prohibit '$effect'"
            }
        }
    }

    $failureSection = [regex]::Match($body, '(?ms)^### Failure and hold states\n(.*?)(?=^### )').Groups[1].Value
    $completion = [regex]::Match($body, '(?ms)^### Completion evidence\n(.*?)(?=^### )').Groups[1].Value
    foreach ($state in $meta.States) {
        if (($failureSection + $completion) -notmatch "\b$([regex]::Escape($state))\b") {
            Add-Failure "'${verb}:' does not define outcome state '$state'"
        }
    }

    if ($candidateList -notmatch "`"$verb`"") {
        Add-Failure "'${verb}:' has no disabled-baseline parser fixtures in tests/approval-contract-tests.cjs"
    }

    foreach ($routeFile in $routeFiles) {
        $routeText = Get-Content (Join-Path $repoRoot $routeFile) -Raw
        if ($routeText -match "(?m)^\| ``$([regex]::Escape($verb)):``") {
            Add-Failure "'${verb}:' is registered as a supported route in $routeFile but must stay unsupported"
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Intent work-unit contract tests passed ($($expectedVerbs.Count) verbs)"
exit 0
