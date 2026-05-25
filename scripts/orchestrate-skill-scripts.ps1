<#
.SYNOPSIS
Orchestrate composable skill scripts — chain assessment, planning, validation, and execution steps.

.DESCRIPTION
Reads a skill's SKILL.md frontmatter to discover executable script steps, runs them in sequence,
passes outputs from one step to the next, and returns combined results.

This enables skills to be broken into composable, debuggable, unit-testable pieces instead of
monolithic prompts.

.PARAMETER SkillPath
Path to the skill's SKILL.md file (required).

.PARAMETER Step
Run a single step by name instead of all steps (optional).

.PARAMETER Raw
Output raw JSON instead of formatted text.

.PARAMETER List
List all available steps without running them.

.EXAMPLE
# List available steps
./orchestrate-skill-scripts.ps1 -SkillPath skills/container-build-assessment/SKILL.md -List

.EXAMPLE
# Run all steps for container-assessment skill
./orchestrate-skill-scripts.ps1 -SkillPath skills/container-build-assessment/SKILL.md -dockerfile_path Dockerfile

.EXAMPLE
# Run only the analyze-dockerfile step
./orchestrate-skill-scripts.ps1 -SkillPath skills/container-build-assessment/SKILL.md -Step analyze-dockerfile -dockerfile_path Dockerfile

#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SkillPath,

    [Parameter(Mandatory = $false)]
    [string]$Step,

    [switch]$Raw,
    [switch]$List,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

# ===== HELPERS =====

function Parse-YamlFrontmatter {
    param([string]$Path)
    
    $content = Get-Content $Path -Raw
    
    # Extract frontmatter between first and second ---
    if ($content -match '(?s)^---\s*\n(.+?)\n---') {
        $frontmatterText = $matches[1]
        
        # Simple YAML parser for scripts section
        $scripts = @()
        $currentScript = $null
        $inScripts = $false
        
        $inInputs = $false

        $frontmatterText -split "`n" | ForEach-Object {
            $line = $_
            
            if ($line -match '^\s*scripts:\s*$') {
                $inScripts = $true
            }
            elseif ($inScripts -and $line -match '^\s+- name:\s*(.+)$') {
                if ($currentScript) { $scripts += $currentScript }
                $currentScript = @{
                    name = $matches[1].Trim()
                    inputs = @()
                }
                $inInputs = $false
            }
            elseif ($inScripts -and $currentScript) {
                if ($line -match '^\s+description:\s*(.+)$') {
                    $currentScript.description = $matches[1].Trim().Trim('"')
                }
                elseif ($line -match '^\s+entrypoint:\s*(.+)$') {
                    $currentScript.entrypoint = $matches[1].Trim()
                }
                elseif ($line -match '^\s+inputs:\s*\[\s*\]') {
                    $currentScript.inputs = @()
                }
                elseif ($line -match '^\s+inputs:\s*$') {
                    $inInputs = $true
                }
                elseif ($inInputs -and $line -match '^\s+- name:\s*(.+)$') {
                    $currentScript.inputs += @{ name = $matches[1].Trim() }
                }
                elseif ($line -match '^\s+outputs:') {
                    $currentScript.outputs = @()
                    $inInputs = $false
                }
            }
        }
        
        if ($currentScript) { $scripts += $currentScript }
        
        return @{ scripts = $scripts }
    }
    
    throw "No frontmatter found in $Path"
}

function Invoke-ScriptStep {
    param(
        [hashtable]$StepDef,
        [string]$SkillDir,
        [object]$PreviousOutput,
        [hashtable]$UserArgs
    )
    
    $skillRoot = (Resolve-Path -LiteralPath $SkillDir).Path
    $scriptPath = Join-Path $SkillDir $StepDef.entrypoint
    
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Script not found: $scriptPath"
    }
    
    $resolvedScriptPath = (Resolve-Path -LiteralPath $scriptPath).Path
    $skillRootWithSep = $skillRoot.TrimEnd('\', '/') + '\'
    
    if (-not ($resolvedScriptPath.StartsWith($skillRootWithSep, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Entrypoint path escapes skill directory: $($StepDef.entrypoint)"
    }
    
    Write-Verbose "Executing: $resolvedScriptPath"
    
    # Build command array
    $args = @()
    
    # Add previous output as parameter if step expects it
    if ($PreviousOutput -and $StepDef.inputs -and $StepDef.inputs.Count -gt 0) {
        $inputName = $StepDef.inputs[0].name
        $args += "-$inputName"
        $args += ($PreviousOutput | ConvertTo-Json -Compress)
    }
    
    # Add user arguments
    $UserArgs.GetEnumerator() | ForEach-Object {
        $args += "-$($_.Key)"
        $args += $_.Value
    }
    
    Write-Verbose "  Command: pwsh $resolvedScriptPath $($args -join ' ')"
    
    # Execute — invoke directly in this PowerShell context
    try {
        $output = & $resolvedScriptPath @args 2>&1
        
        # Try to parse as JSON
        try {
            $output = $output | ConvertFrom-Json
            Write-Verbose "Output parsed as JSON"
        }
        catch {
            Write-Verbose "Output is not JSON, returning as string"
        }
        
        return $output
    }
    catch {
        throw "Step execution failed: $($_.Exception.Message)`n$($_ | Out-String)"
    }
}

# ===== MAIN =====

try {
    # Validate skill file exists
    if (-not (Test-Path $SkillPath)) {
        throw "Skill file not found: $SkillPath"
    }
    
    $skillDir = Split-Path $SkillPath -Parent
    $skillName = (Split-Path $SkillPath -Leaf) -replace '\.md$', ''
    
    # Parse frontmatter
    $skillDef = Parse-YamlFrontmatter -Path $SkillPath
    
    if (-not $skillDef.scripts -or $skillDef.scripts.Count -eq 0) {
        throw "No scripts defined in $SkillPath"
    }
    
    # If List flag set, just show available steps
    if ($List) {
        Write-Host "Available steps for: $skillName" -ForegroundColor Cyan
        Write-Host "─" * 60 -ForegroundColor Cyan
        $skillDef.scripts | ForEach-Object {
            Write-Host "  ▶ $($_.name)" -ForegroundColor Green
            Write-Host "    $($_.description)" -ForegroundColor Gray
            Write-Host "    Entrypoint: $($_.entrypoint)" -ForegroundColor Gray
            Write-Host ""
        }
        exit 0
    }
    
    # Parse remaining args into hashtable
    $userArgs = @{}
    for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {
        if ($RemainingArgs[$i] -like '-*') {
            $key = $RemainingArgs[$i].TrimStart('-')
            if ($i + 1 -lt $RemainingArgs.Count -and $RemainingArgs[$i + 1] -notlike '-*') {
                $userArgs[$key] = $RemainingArgs[$i + 1]
                $i++
            }
        }
    }
    
    # Determine which steps to run
    $stepsToRun = if ($Step) {
        $filtered = $skillDef.scripts | Where-Object { $_.name -eq $Step }
        if (-not $filtered) {
            throw "Step not found: $Step"
        }
        @($filtered)
    }
    else {
        $skillDef.scripts
    }
    
    # Run steps
    $previousOutput = $null
    $allResults = @()
    
    foreach ($stepDef in $stepsToRun) {
        Write-Host "▶ $($stepDef.name)" -ForegroundColor Green
        
        $result = @{
            name = $stepDef.name
            description = $stepDef.description
            status = 'pending'
            output = $null
            error = $null
            timestamp = Get-Date -Format 'o'
        }
        
        try {
            $output = Invoke-ScriptStep -StepDef $stepDef -SkillDir $skillDir `
                -PreviousOutput $previousOutput -UserArgs $userArgs
            
            $result.status = 'success'
            $result.output = $output
            $previousOutput = $output
            
            Write-Host "  ✓ Success" -ForegroundColor Green
        }
        catch {
            $result.status = 'error'
            $result.error = $_.Exception.Message
            Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            throw $_
        }
        
        $allResults += $result
    }
    
    # Format output
    $finalResult = @{
        skill = $skillName
        totalSteps = $stepsToRun.Count
        completedSteps = ($allResults | Where-Object { $_.status -eq 'success' }).Count
        results = $allResults
        finalOutput = $previousOutput
        executedAt = Get-Date -Format 'o'
    }
    
    if ($Raw) {
        $finalResult | ConvertTo-Json -Depth 10
    }
    else {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "✓ Orchestration Complete" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Skill: $($finalResult.skill)"
        Write-Host "Steps: $($finalResult.completedSteps) / $($finalResult.totalSteps) completed"
        Write-Host "Executed: $($finalResult.executedAt)"
        Write-Host ""
        
        if ($previousOutput) {
            Write-Host "Final Output:" -ForegroundColor Cyan
            if ($previousOutput -is [string]) {
                Write-Host $previousOutput
            }
            else {
                Write-Host ($previousOutput | ConvertTo-Json -Depth 5)
            }
        }
    }
    
    exit 0
}
catch {
    Write-Host ""
    Write-Host "✗ Orchestration failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($VerbosePreference -eq 'Continue') {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    }
    exit 1
}
