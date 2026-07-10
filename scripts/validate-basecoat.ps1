[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path,
    [switch]$Strict,
    [switch]$FailOnWarning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location $RootDir

$required = @('README.md', 'CHANGELOG.md', 'version.json', 'asset-manifest.json', 'sync.sh', 'sync.ps1', 'instructions', 'skills', 'prompts', 'agents')
foreach ($item in $required) {
    if (-not (Test-Path $item)) {
        throw "Missing required path: $item"
    }
}

# INVENTORY.md may be at root or in docs/reference/ (accepts lowercase after Phase 3+4 rename)
$inventoryPath = if (Test-Path 'INVENTORY.md') { 'INVENTORY.md' } elseif (Test-Path 'docs/reference/INVENTORY.md') { 'docs/reference/INVENTORY.md' } elseif (Test-Path 'docs/reference/inventory.md') { 'docs/reference/inventory.md' } else { $null }
if (-not $inventoryPath) {
    throw "Missing required path: INVENTORY.md (checked root and docs/reference/)"
}

$files = Get-ChildItem instructions, prompts, agents, skills -Recurse -File | Where-Object {
    $_.Name -eq 'SKILL.md' -or $_.Name -eq 'AGENT.md' -or $_.Name -like '*.instructions.md' -or $_.Name -like '*.prompt.md' -or $_.Name -like '*.agent.md'
}

# Also scan .agents/skills/ for cross-client Agent Skills interop (if present)
if (Test-Path '.agents/skills') {
    $files += Get-ChildItem '.agents/skills' -Recurse -File | Where-Object {
        $_.Name -eq 'SKILL.md'
    }
}

$errors = 0
$warnings = 0
$metadataStale = $false
$tokenBudgetThreshold = 500

function Test-AgentMetadataFreshness {
    $agentFiles = @(Get-ChildItem 'agents' -Filter '*.agent.md' -File | Sort-Object Name)
    $agentNames = @($agentFiles | ForEach-Object { $_.BaseName -replace '\.agent$', '' })
    $metadataPath = Join-Path (Get-Location) 'basecoat-metadata.json'

    if (-not (Test-Path $metadataPath)) {
        Write-Host "ERROR: Missing required file: basecoat-metadata.json" -ForegroundColor Red
        $script:errors++
        return
    }

    try {
        $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "ERROR: basecoat-metadata.json is invalid ($($_.Exception.Message))" -ForegroundColor Red
        $script:errors++
        return
    }

    $metadataAgentNames = @($metadata.agents | ForEach-Object { $_.name } | Where-Object { $_ })
    $missingAgents = @($agentNames | Where-Object { $_ -notin $metadataAgentNames })
    $extraAgents = @($metadataAgentNames | Where-Object { $_ -notin $agentNames })

    if ($missingAgents.Count -gt 0 -or $extraAgents.Count -gt 0 -or $agentNames.Count -ne $metadataAgentNames.Count) {
        Write-Host "WARNING: basecoat-metadata.json is stale: found $($agentNames.Count) agent file(s) but $($metadataAgentNames.Count) metadata entry(ies). Run 'pwsh scripts/update-metadata.ps1'." -ForegroundColor Yellow

        if ($missingAgents.Count -gt 0) {
            Write-Host "WARNING: Missing metadata entries for agents: $($missingAgents -join ', ')" -ForegroundColor Yellow
        }

        if ($extraAgents.Count -gt 0) {
            Write-Host "INFO: Metadata entries without matching agent files: $($extraAgents -join ', ')" -ForegroundColor DarkYellow
        }

        $script:warnings++
        $script:metadataStale = $true
    }
}

function Test-LogFirstGate {
    $govPath = Join-Path (Get-Location) 'instructions/governance.instructions.md'
    if (-not (Test-Path $govPath)) {
        Write-Host "ERROR: instructions/governance.instructions.md is missing" -ForegroundColor Red
        $script:errors++
        return
    }

    $content = Get-Content $govPath -Raw
    $missing = @()

    if ($content -notmatch '##\s+LOG-FIRST Gate') {
        $missing += "'## LOG-FIRST Gate' section"
    }
    if ($content -notmatch 'hard block') {
        $missing += "explicit 'hard block' language"
    }
    if ($content -notmatch 'tracking issue') {
        $missing += "reference to tracking issue requirement"
    }

    if ($missing.Count -gt 0) {
        Write-Host "ERROR: instructions/governance.instructions.md is missing required LOG-FIRST gate elements: $($missing -join '; ')" -ForegroundColor Red
        $script:errors++
    }
}

function Test-DocsHomepageAssetCounts {
    $docsIndexPath = Join-Path (Get-Location) 'docs/index.md'
    if (-not (Test-Path $docsIndexPath)) {
        Write-Host "ERROR: docs/index.md is missing" -ForegroundColor Red
        $script:errors++
        return
    }

    $content = Get-Content $docsIndexPath -Raw
    $patterns = @{
        Agents       = '\|\s+\*\*Agents\*\*\s+\|\s+(\d+)\s+\|'
        Skills       = '\|\s+\*\*Skills\*\*\s+\|\s+(\d+)\s+\|'
        Instructions = '\|\s+\*\*Instructions\*\*\s+\|\s+(\d+)\s+\|'
        Prompts      = '\|\s+\*\*Prompts\*\*\s+\|\s+(\d+)\s+\|'
    }

    $expected = @{
        Agents       = @(Get-ChildItem 'agents' -Filter '*.agent.md' -File).Count
        Skills       = @(Get-ChildItem 'skills' -Recurse -Filter 'SKILL.md' -File).Count
        Instructions = @(Get-ChildItem 'instructions' -Filter '*.instructions.md' -File).Count
        Prompts      = @(Get-ChildItem 'prompts' -Filter '*.prompt.md' -File).Count
    }

    foreach ($key in $patterns.Keys) {
        $match = [regex]::Match($content, $patterns[$key])
        if (-not $match.Success) {
            Write-Host "ERROR: docs/index.md is missing table row for $key count" -ForegroundColor Red
            $script:errors++
            continue
        }

        $actual = [int]$match.Groups[1].Value
        if ($actual -ne $expected[$key]) {
            Write-Host "ERROR: docs/index.md $key count is stale (found $actual, expected $($expected[$key])). Update docs/index.md." -ForegroundColor Red
            $script:errors++
        }
    }
}

function Test-IntentRoutingSkillReferences {
    $intentRoutingPath = Join-Path (Get-Location) 'instructions/intent-routing.instructions.md'
    if (-not (Test-Path $intentRoutingPath)) {
        return
    }

    $content = Get-Content $intentRoutingPath -Raw

    # Validate enforcement contract section exists with required routing rules
    $contractMissing = @()
    if ($content -notmatch '##\s+Enforcement Contract') {
        $contractMissing += "'## Enforcement Contract' section"
    }
    if ($content -notmatch '`bug:`\s+routes') {
        $contractMissing += "explicit 'bug:' routing rule"
    }
    if ($content -notmatch '`feature:`\s+routes') {
        $contractMissing += "explicit 'feature:' routing rule"
    }
    if ($contractMissing.Count -gt 0) {
        Write-Host "ERROR: instructions/intent-routing.instructions.md is missing required enforcement contract elements: $($contractMissing -join '; ')" -ForegroundColor Red
        $script:errors++
    }

    $sectionMatch = [regex]::Match(
        $content,
        '(?ms)## Prefix-to-Skill Routing\s*\r?\n\r?\n\| Prefix \| Skills to consult \|\r?\n\|---\|---\|\r?\n(?<rows>.*?)(?:\r?\n---|\z)'
    )
    if (-not $sectionMatch.Success) {
        return
    }

    $rowLines = $sectionMatch.Groups['rows'].Value -split '\r?\n'
    foreach ($line in $rowLines) {
        if ($line -notmatch '^\|\s*`[^`]+`\s*\|\s*(.+?)\s*\|$') {
            continue
        }

        $skillsCell = $matches[1]
        $skillRefs = @([regex]::Matches($skillsCell, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() })

        foreach ($skillRef in $skillRefs) {
            if (-not $skillRef) {
                continue
            }

            $skillPath = Join-Path (Get-Location) "skills/$skillRef/SKILL.md"
            if (-not (Test-Path $skillPath)) {
                Write-Host "ERROR: instructions/intent-routing.instructions.md references missing skill '$skillRef' in Prefix-to-Skill Routing" -ForegroundColor Red
                $script:errors++
            }
        }
    }
}

foreach ($file in $files) {
    $lines = Get-Content $file.FullName -TotalCount 50
    $content = Get-Content $file.FullName -Raw
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') {
        Write-Host "ERROR: Missing frontmatter start in $($file.FullName)" -ForegroundColor Red
        $errors++
        continue
    }

    # Common: all assets require description
    if (-not ($lines | Select-String -Pattern '^description:' -Quiet)) {
        Write-Host "ERROR: $($file.Name) missing 'description' in frontmatter" -ForegroundColor Red
        $errors++
    }

    # Optional per-asset version must be SemVer if present
    $versionLine = $lines | Select-String -Pattern '^version:\s*' | Select-Object -First 1
    if ($versionLine) {
        $ver = ($versionLine -replace '^version:\s*', '').Trim().Trim('"').Trim("'")
        if ($ver -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
            Write-Host "ERROR: $($file.Name) has invalid version '$ver' (expected SemVer X.Y.Z)" -ForegroundColor Red
            $errors++
        }
    }

    # Agents and Skills require name
    if (($file.Name -eq 'SKILL.md' -or $file.Name -like '*.agent.md') -and -not ($lines | Select-String -Pattern '^name:' -Quiet)) {
        Write-Host "ERROR: $($file.Name) missing 'name' in frontmatter" -ForegroundColor Red
        $errors++
    }

    if ($file.Name -like '*.agent.md') {
        $maxFrontmatterLine = [Math]::Min($lines.Count, 30)
        $frontmatterClosed = $false
        for ($i = 1; $i -lt $maxFrontmatterLine; $i++) {
            if ($lines[$i] -eq '---') {
                $frontmatterClosed = $true
                break
            }
        }

        if (-not $frontmatterClosed) {
            Write-Host "ERROR: Missing YAML frontmatter closing '---' within first 30 lines in $($file.FullName)" -ForegroundColor Red
            $errors++
            continue
        }

        if ($content -notmatch '(?im)^##\s+Inputs\s*$') {
            Write-Host "ERROR: Missing required section '## Inputs' in $($file.FullName)" -ForegroundColor Red
            $errors++
        }

        if ($content -notmatch '(?im)^##\s+(Process|Workflow)\s*$') {
            Write-Host "ERROR: Missing required section '## Process' or '## Workflow' in $($file.FullName)" -ForegroundColor Red
            $errors++
        }

        if ($content -notmatch '(?im)^##.*\b(Output|Report|Results)\b') {
            Write-Host "ERROR: Missing required output/report/results section in $($file.FullName)" -ForegroundColor Red
            $errors++
        }
    }

    # Instructions require applyTo
    if ($file.Name -like '*.instructions.md' -and -not ($lines | Select-String -Pattern '^applyTo:' -Quiet)) {
        Write-Host "ERROR: $($file.Name) missing 'applyTo' in frontmatter" -ForegroundColor Red
        $errors++
    }

    # Agent Skills spec: SKILL.md and .agent.md should have compatibility, metadata, allowed-tools
    if ($file.Name -eq 'SKILL.md' -or $file.Name -like '*.agent.md') {
        # Check for spec compliance (optional but encouraged)
        if (-not ($lines | Select-String -Pattern '^compatibility:' -Quiet)) {
            Write-Host "WARNING: $($file.FullName) missing 'compatibility' in Agent Skills spec" -ForegroundColor Yellow
            $warnings++
        }
        if (-not ($lines | Select-String -Pattern '^metadata:' -Quiet)) {
            Write-Host "WARNING: $($file.FullName) missing 'metadata' in Agent Skills spec" -ForegroundColor Yellow
            $warnings++
        }
        if (-not ($lines | Select-String -Pattern '^allowed-tools:' -Quiet)) {
            Write-Host "WARNING: $($file.FullName) missing 'allowed-tools' in Agent Skills spec" -ForegroundColor Yellow
            $warnings++
        }

        # Validate skill name format (lowercase, hyphens/numbers only)
        $skillName = $lines | Select-String -Pattern '^name:\s*"?([a-z0-9\-]+)"?' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
        if ($skillName -and -not ($skillName -match '^[a-z0-9\-]{1,64}$')) {
            Write-Host "ERROR: $($file.Name) skill name '$skillName' is invalid (must be lowercase alphanumeric with hyphens, max 64 chars)" -ForegroundColor Red
            $errors++
        }

        # Check that skill directory name matches skill name
        if ($file.Name -eq 'SKILL.md') {
            $dirName = Split-Path -Leaf (Split-Path $file.FullName)
            if ($skillName -and $dirName -ne $skillName) {
                Write-Host "ERROR: $($file.FullName) skill name '$skillName' does not match directory name '$dirName'" -ForegroundColor Red
                $errors++
            }
        }

        # Check 1: Token budget — word count * 1.35 > 500 → warning
        $wordCount = ($content -split '\s+' | Where-Object { $_ -ne '' }).Count
        $approxTokens = [math]::Round($wordCount * 1.35)
        if ($approxTokens -gt $tokenBudgetThreshold) {
            Write-Host "WARNING: $($file.FullName) exceeds approx $tokenBudgetThreshold-token budget target (approx $approxTokens tokens)" -ForegroundColor Yellow
            $warnings++
        }

        # Validate description length
        $descLine = $lines | Select-String -Pattern '^description:\s*'
        if ($descLine) {
            $descContent = $lines | Select-String -Pattern '^description:' | ForEach-Object { $_ -replace 'description:\s*' }
            if ($descContent.Length -lt 1 -or $descContent.Length -gt 1024) {
                Write-Host "ERROR: $($file.Name) description must be 1-1024 characters (found {$($descContent.Length)})" -ForegroundColor Red
                $errors++
            }
        }

        # Validate context_policy subfields when present (issue #2008)
        $fmMatch = [regex]::Match($content, '(?ms)^---[ \t]*\r?\n(.*?)\r?\n^[ \t]*---[ \t]*(?:\r?\n|$)')
        $hasContextPolicy = $lines | Select-String -Pattern '^context_policy:\s*' -Quiet
        if ($hasContextPolicy) {
            if (-not $fmMatch.Success) {
                Write-Host "ERROR: $($file.FullName) contains 'context_policy:' but frontmatter could not be parsed" -ForegroundColor Red
                $errors++
            } else {
                # Extract only the lines belonging to the context_policy block (indented lines
                # immediately following the context_policy: key) to avoid matching same-named
                # keys that appear elsewhere in the frontmatter.
                $cpBlockMatch = [regex]::Match(
                    $fmMatch.Groups[1].Value,
                    '(?m)^context_policy:\s*\r?\n((?:[ \t]+[^\r\n]*(?:\r?\n|$))+)'
                )
                if (-not $cpBlockMatch.Success) {
                    Write-Host "ERROR: $($file.FullName) context_policy must be a YAML block mapping" -ForegroundColor Red
                    $errors++
                } else {
                    $cpBlock = $cpBlockMatch.Groups[1].Value

                    $lsMatch = [regex]::Match($cpBlock, '(?m)^[ \t]+load_scope:\s*([^#\r\n]*)')
                    if ($lsMatch.Success) {
                        $lsVal = $lsMatch.Groups[1].Value.Trim().Trim('"').Trim("'")
                        if ($lsVal -notmatch '^(minimal|standard|full)$') {
                            Write-Host "ERROR: $($file.FullName) context_policy.load_scope '$lsVal' is invalid (expected: minimal|standard|full)" -ForegroundColor Red
                            $errors++
                        }
                    }

                    $rtMatch = [regex]::Match($cpBlock, '(?m)^[ \t]+retention:\s*([^#\r\n]*)')
                    if ($rtMatch.Success) {
                        $rtVal = $rtMatch.Groups[1].Value.Trim().Trim('"').Trim("'")
                        $rtPattern = if ($file.Name -eq 'SKILL.md') { '^(none|turn)$' } else { '^(none|turn|session)$' }
                        $rtValid = if ($file.Name -eq 'SKILL.md') { 'none|turn' } else { 'none|turn|session' }
                        if ($rtVal -notmatch $rtPattern) {
                            Write-Host "ERROR: $($file.FullName) context_policy.retention '$rtVal' is invalid (expected: $rtValid)" -ForegroundColor Red
                            $errors++
                        }
                    }

                    $mbMatch = [regex]::Match($cpBlock, '(?m)^[ \t]+max_context_budget:\s*([^#\r\n]*)')
                    if ($mbMatch.Success) {
                        $mbVal = $mbMatch.Groups[1].Value.Trim().Trim('"').Trim("'")
                        $maxBudget = 0L
                        if (-not [System.Int64]::TryParse($mbVal, [ref]$maxBudget) -or $maxBudget -le 0) {
                            Write-Host "ERROR: $($file.FullName) context_policy.max_context_budget '$mbVal' must be a positive integer" -ForegroundColor Red
                            $errors++
                        }
                    }
                }
            }
        }
    }
}

if ($errors -gt 0) {
    throw "Validation failed with $errors error(s)"
}

# Validate asset-manifest basic shape
try {
    $manifest = Get-Content 'asset-manifest.json' -Raw | ConvertFrom-Json
    if (-not $manifest.schemaVersion -or -not $manifest.libraryVersion -or -not $manifest.assets) {
        throw 'missing required keys'
    }
}
catch {
    throw "Validation failed: asset-manifest.json is invalid ($($_.Exception.Message))"
}

Test-AgentMetadataFreshness
Test-IntentRoutingSkillReferences
Test-LogFirstGate
Test-DocsHomepageAssetCounts

if ($errors -gt 0) {
    throw "Validation failed with $errors error(s)"
}

if ($warnings -gt 0) {
    Write-Host "Base Coat validation passed with $warnings warning(s)" -ForegroundColor Yellow
} else {
    Write-Host 'Base Coat validation passed' -ForegroundColor Green
}

if ($FailOnWarning -and $warnings -gt 0) {
    Write-Host "Validation failed in fail-on-warning mode: $warnings warning(s) found." -ForegroundColor Red
    exit 1
}

if ($Strict -and $metadataStale) {
    Write-Host 'Registry metadata freshness check failed in strict mode.' -ForegroundColor Red
    exit 1
}
