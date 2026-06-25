$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$failures = @()
$testCount = 0

# Helper function to extract frontmatter from a file
function Get-Frontmatter {
    param([string]$Path)
    
    $content = Get-Content $Path -Raw
    if ($content -match '^---\r?\n([\s\S]+?)\r?\n---\r?\n') {
        return $matches[1]
    }
    return $null
}

# Helper: ensure frontmatter closes near top-of-file (CI guardrail compatibility)
function Test-FrontmatterClosingWithinLineLimit {
    param(
        [string]$Path,
        [int]$LineLimit = 30
    )

    $lines = Get-Content -Path $Path
    if ($lines.Count -eq 0) { return $false }
    if ($lines[0].Trim() -ne '---') { return $false }

    $maxIndex = [Math]::Min($LineLimit - 1, $lines.Count - 1)
    for ($i = 1; $i -le $maxIndex; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            return $true
        }
    }

    return $false
}

# Helper function to get content after frontmatter
function Get-ContentAfterFrontmatter {
    param([string]$Path)
    
    $content = Get-Content $Path -Raw
    if ($content -match '^---\r?\n[\s\S]+?\r?\n---\r?\n([\s\S]*)$') {
        return $matches[1]
    }
    return $content
}

# Helper function to extract YAML field value
function Get-YamlField {
    param(
        [string]$Content,
        [string]$FieldName
    )
    
    # Remove carriage returns for consistent line splitting
    $content = $content -replace "`r", ""
    $lines = $content -split "`n"
    
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($FieldName))\s*:\s*(.+)$") {
            $value = $matches[1].Trim()
            # Remove surrounding quotes if present
            $value = $value -replace '^[`"](.+)[`"]$', '$1'
            return $value
        }
    }
    return $null
}

# Helper: check whether a YAML field is present (including with an empty value)
function Test-YamlFieldPresent {
    param(
        [string]$Content,
        [string]$FieldName
    )
    
    $normalizedContent = $Content -replace "`r", ""
    $lines = $normalizedContent -split "`n"
    
    foreach ($line in $lines) {
        if ($line -match "^$([regex]::Escape($FieldName))\s*:") {
            return $true
        }
    }
    return $false
}

# Helper: extract inline YAML array items from a field like "tools: [a, b, c]"
# Also supports multi-line YAML list syntax:
#   tools:
#     - a
#     - b
# Returns $null if the field is absent; returns an empty array for "field: []"
function Get-YamlArrayField {
    param(
        [string]$Content,
        [string]$FieldName
    )
    
    $normalizedContent = $Content -replace "`r", ""
    $lines = $normalizedContent -split "`n"
    
    $fieldIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^$([regex]::Escape($FieldName))\s*:\s*(.*)$") {
            $fieldIndex = $i
            $raw = $matches[1].Trim()

            # Empty value or empty inline brackets — field is present with empty list
            if ([string]::IsNullOrWhiteSpace($raw) -or $raw -eq '[]') {
                # Check if the next lines have "  - item" entries
                $items = @()
                for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                    if ($lines[$j] -match '^\s+-\s+(.+)$') {
                        $items += $matches[1].Trim()
                    } elseif ($lines[$j] -match '^\S') {
                        break  # Next top-level key reached
                    }
                }
                return $items
            }

            # Inline array: [a, b, c]
            if ($raw -match '^\[(.+)\]$') {
                $inner = $matches[1]
                return @($inner -split '\s*,\s*' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
            }

            # Scalar value — not a valid array format
            return $null
        }
    }
    return $null  # Field not present
}

Write-Host 'Starting agent integration tests...' -ForegroundColor Cyan

# ============================================================================
# Test 1: Agent frontmatter validation (description required)
# ============================================================================
Write-Host "`nTest 1: Agent frontmatter validation" -ForegroundColor Yellow

$agentFiles = Get-ChildItem agents -Filter '*.agent.md' -File
foreach ($file in $agentFiles) {
    $testCount++
    $frontmatter = Get-Frontmatter $file.FullName
    
    if ($null -eq $frontmatter) {
        $failures += "$($file.Name): Missing YAML frontmatter"
        continue
    }
    
    $description = Get-YamlField $frontmatter 'description'
    
    if ($null -eq $description -or [string]::IsNullOrWhiteSpace($description)) {
        $failures += "$($file.Name): Missing or empty 'description' field in frontmatter"
    }

    if (-not (Test-FrontmatterClosingWithinLineLimit -Path $file.FullName -LineLimit 30)) {
        $failures += "$($file.Name): Missing YAML frontmatter closing '---' within first 30 lines"
    }
}

Write-Host "  Checked $($agentFiles.Count) agent files for frontmatter" -ForegroundColor Green

# ============================================================================
# Test 1b: Agent tools field must be a valid array when present
# ============================================================================
Write-Host "`nTest 1b: Agent 'tools' field array validation" -ForegroundColor Yellow

$toolsChecked = 0
foreach ($file in $agentFiles) {
    $testCount++
    $frontmatter = Get-Frontmatter $file.FullName
    if ($null -eq $frontmatter) { continue }

    if (Test-YamlFieldPresent $frontmatter 'tools') {
        $toolsChecked++
        $tools = Get-YamlArrayField $frontmatter 'tools'
        if ($null -eq $tools) {
            $failures += "$($file.Name): 'tools' field is present but is not a valid YAML array (expected inline array like [tool1, tool2] or [])"
        }
    }
}

Write-Host "  Checked $toolsChecked agent files with 'tools' field for array format" -ForegroundColor Green

# ============================================================================
# Test 1c: Agent allowed_skills field must be a valid array when present,
#          and every named skill must correspond to a directory under skills/
# ============================================================================
Write-Host "`nTest 1c: Agent 'allowed_skills' field validation" -ForegroundColor Yellow

$allowedSkillsChecked = 0
$skillDirNames = (Get-ChildItem skills -Directory).Name

foreach ($file in $agentFiles) {
    $testCount++
    $frontmatter = Get-Frontmatter $file.FullName
    if ($null -eq $frontmatter) { continue }

    if (-not (Test-YamlFieldPresent $frontmatter 'allowed_skills')) { continue }

    $allowedSkillsChecked++
    # Use @(...) to preserve empty-array distinction (PowerShell collapses @() to $null on function return)
    $rawSkillsLine = ($frontmatter -replace "`r","" -split "`n") |
        Where-Object { $_ -match "^allowed_skills\s*:" } | Select-Object -First 1
    $skills = @(Get-YamlArrayField $frontmatter 'allowed_skills')

    if ($skills.Count -eq 0 -and $rawSkillsLine -notmatch "^allowed_skills\s*:\s*(\[\]|\s*$)") {
        $failures += "$($file.Name): 'allowed_skills' field is present but is not a valid YAML array (expected inline array like [skill1, skill2] or [])"
        continue
    }

    foreach ($skill in $skills) {
        if ($skill -notin $skillDirNames) {
            $failures += "$($file.Name): 'allowed_skills' references '$skill' but no matching directory exists under skills/"
        }
    }
}

Write-Host "  Checked $allowedSkillsChecked agent files with 'allowed_skills' field" -ForegroundColor Green

# ============================================================================
# Test 2: Agent required sections (Inputs, Workflow/Process, Output/Report)
# ============================================================================
Write-Host "`nTest 2: Agent required sections validation" -ForegroundColor Yellow

foreach ($file in $agentFiles) {
    $testCount++
    $content = Get-ContentAfterFrontmatter $file.FullName
    
    # Check for ## Inputs section (case-insensitive)
    if ($content -inotmatch '##\s+inputs\b') {
        $failures += "$($file.Name): Missing '## Inputs' section"
    }
    
    # Check for ## Workflow or ## Process (case-insensitive)
    if ($content -inotmatch '##\s+workflow\b' -and $content -inotmatch '##\s+process\b') {
        $failures += "$($file.Name): Missing '## Workflow' or '## Process' section"
    }
    
    # Check for output-like sections (## Output, ## Expected Output, ## Report, ## Results, etc.)
    # This catches any heading with output, report, or results in it
    if ($content -inotmatch '##.*\b(output|report|results)\b') {
        $failures += "$($file.Name): Missing output section (## Output, ## Expected Output, ## Report, etc.)"
    }
}

Write-Host "  Checked $($agentFiles.Count) agent files for required sections" -ForegroundColor Green

# ============================================================================
# Test 3: Instruction file frontmatter validation
# ============================================================================
Write-Host "`nTest 3: Instruction frontmatter validation" -ForegroundColor Yellow

$instructionFiles = Get-ChildItem instructions -Filter '*.instructions.md' -File
foreach ($file in $instructionFiles) {
    $testCount++
    $frontmatter = Get-Frontmatter $file.FullName
    
    if ($null -eq $frontmatter) {
        $failures += "$($file.Name): Missing YAML frontmatter"
        continue
    }
    
    $description = Get-YamlField $frontmatter 'description'
    $applyTo = Get-YamlField $frontmatter 'applyTo'
    
    if ($null -eq $description -or [string]::IsNullOrWhiteSpace($description)) {
        $failures += "$($file.Name): Missing or empty 'description' field in frontmatter"
    }
    
    if ($null -eq $applyTo -or [string]::IsNullOrWhiteSpace($applyTo)) {
        $failures += "$($file.Name): Missing or empty 'applyTo' field in frontmatter"
    }
}

Write-Host "  Checked $($instructionFiles.Count) instruction files for frontmatter" -ForegroundColor Green

# ============================================================================
# Test 4: Skill directory and SKILL.md frontmatter validation
# ============================================================================
Write-Host "`nTest 4: Skill frontmatter validation" -ForegroundColor Yellow

$skillDirs = Get-ChildItem skills -Directory
$skillCount = 0

foreach ($dir in $skillDirs) {
    $skillMd = Join-Path $dir.FullName 'SKILL.md'
    
    if (-not (Test-Path $skillMd)) {
        $testCount++
        $failures += "$($dir.Name): Missing SKILL.md file"
        continue
    }
    
    $testCount++
    $skillCount++
    $frontmatter = Get-Frontmatter $skillMd
    
    if ($null -eq $frontmatter) {
        $failures += "$($dir.Name)/SKILL.md: Missing YAML frontmatter"
        continue
    }
    
    $name = Get-YamlField $frontmatter 'name'
    $description = Get-YamlField $frontmatter 'description'
    
    if ($null -eq $name -or [string]::IsNullOrWhiteSpace($name)) {
        $failures += "$($dir.Name)/SKILL.md: Missing or empty 'name' field in frontmatter"
    }
    
    if ($null -eq $description -or [string]::IsNullOrWhiteSpace($description)) {
        $failures += "$($dir.Name)/SKILL.md: Missing or empty 'description' field in frontmatter"
    }
}

Write-Host "  Checked $skillCount skill directories for SKILL.md and frontmatter" -ForegroundColor Green

# ============================================================================
# Test 5: Prompt file frontmatter validation
# ============================================================================
Write-Host "`nTest 5: Prompt frontmatter validation" -ForegroundColor Yellow

$promptFiles = Get-ChildItem prompts -Filter '*.prompt.md' -File -ErrorAction SilentlyContinue
$promptCount = 0

foreach ($file in $promptFiles) {
    $testCount++
    $promptCount++
    $frontmatter = Get-Frontmatter $file.FullName
    
    if ($null -eq $frontmatter) {
        $failures += "$($file.Name): Missing YAML frontmatter"
    } else {
        $description = Get-YamlField $frontmatter 'description'
        if ($null -eq $description -or [string]::IsNullOrWhiteSpace($description)) {
            $failures += "$($file.Name): Missing or empty 'description' field in frontmatter"
        }
    }
}

if ($promptCount -gt 0) {
    Write-Host "  Checked $promptCount prompt files for frontmatter" -ForegroundColor Green
} else {
    Write-Host "  No prompt files found" -ForegroundColor Green
}

# ============================================================================
# Test 6: Allowed Skills section validation
# ============================================================================
Write-Host "`nTest 6: Allowed Skills section validation" -ForegroundColor Yellow

$skillDirNames = (Get-ChildItem skills -Directory).Name
$agentsWithAllowedSkills = 0

foreach ($file in $agentFiles) {
    $testCount++
    $content = Get-ContentAfterFrontmatter $file.FullName

    # Extract the ## Allowed Skills section (content between this heading and the next ##)
    if ($content -match '(?ms)##\s+Allowed Skills\s*\r?\n(.*?)(?=\r?\n##\s|\z)') {
        $agentsWithAllowedSkills++
        $sectionBody = $matches[1]

        # Parse skill names from list items (lines starting with "- ").
        # Capture the first word after "- " to allow trailing comments or descriptions.
        $listedSkills = $sectionBody -split "`n" |
            Where-Object { $_ -match '^\s*-\s+(\S+)' } |
            ForEach-Object { if ($_ -match '^\s*-\s+(\S+)') { $matches[1] } }

        foreach ($skillName in $listedSkills) {
            if ($skillName -notin $skillDirNames) {
                $failures += "$($file.Name): Allowed Skills lists '$skillName' but no matching skills/$skillName/ directory exists"
            }
        }
    }
}

Write-Host "  Checked $($agentFiles.Count) agent files for Allowed Skills section ($agentsWithAllowedSkills had the section)" -ForegroundColor Green

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n`n================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($failures.Count -gt 0) {
    Write-Host "`nFAILED: $($failures.Count) issues found" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nTotal checks performed: $testCount" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nAll integration tests passed ($testCount checks)" -ForegroundColor Green
