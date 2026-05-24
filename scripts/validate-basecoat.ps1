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

# INVENTORY.md may be at root or in docs/reference/ after reorganization
$inventoryPath = if (Test-Path 'INVENTORY.md') { 'INVENTORY.md' } elseif (Test-Path 'docs/reference/INVENTORY.md') { 'docs/reference/INVENTORY.md' } else { $null }
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
