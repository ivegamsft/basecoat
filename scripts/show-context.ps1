<#
.SYNOPSIS
    Estimates the Copilot context budget for a basecoat-enabled repository.

.DESCRIPTION
    Scans the current repo's basecoat configuration and displays an estimated
    context composition: which instructions, agents, skills, and memory files
    would be loaded, their processing order, token estimates, and cumulative
    budget against the target model's context window.

    This is a SIDECAR ESTIMATOR — it cannot observe Copilot's actual runtime
    context. It shows what SHOULD be loaded based on file-system state.

.PARAMETER File
    Target file path to filter instructions by applyTo glob match.
    When specified, only instructions whose applyTo pattern matches this file are shown.

.PARAMETER Agent
    Agent name (without .agent.md suffix) to include in the context estimate.
    Adds the agent definition and its referenced skills.

.PARAMETER Model
    Model name for context window budget calculation.
    Default: claude-sonnet-4.6

.PARAMETER Json
    Output structured JSON instead of terminal-formatted table.

.PARAMETER Summary
    Show only the budget summary, not individual items.

.EXAMPLE
    pwsh scripts/show-context.ps1
    pwsh scripts/show-context.ps1 -File src/api/auth.ts
    pwsh scripts/show-context.ps1 -Agent solution-architect -Model claude-opus-4.7
    pwsh scripts/show-context.ps1 -Json | ConvertFrom-Json

.LINK
    https://github.com/IBuySpy-Shared/basecoat/issues/1033
#>

[CmdletBinding()]
param(
    [string]$File,
    [string]$Agent,
    [string]$Model = "claude-sonnet-4.6",
    [switch]$Json,
    [switch]$Summary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Model Registry -----------------------------------------------------------

$ModelRegistry = @{
    "claude-opus-4.7"      = @{ ContextWindow = 200000; Tier = "Premium";  TokenRatio = 3.5 }
    "claude-opus-4.6"      = @{ ContextWindow = 200000; Tier = "Premium";  TokenRatio = 3.5 }
    "claude-sonnet-4.6"    = @{ ContextWindow = 200000; Tier = "Standard"; TokenRatio = 3.5 }
    "claude-sonnet-4.5"    = @{ ContextWindow = 200000; Tier = "Standard"; TokenRatio = 3.5 }
    "claude-haiku-4.5"     = @{ ContextWindow = 200000; Tier = "Fast";     TokenRatio = 3.5 }
    "gpt-5.5"              = @{ ContextWindow = 1000000; Tier = "Premium"; TokenRatio = 4.0 }
    "gpt-5.4"              = @{ ContextWindow = 1000000; Tier = "Standard"; TokenRatio = 4.0 }
    "gpt-5.3-codex"        = @{ ContextWindow = 200000; Tier = "Code";    TokenRatio = 4.0 }
    "gpt-5.2-codex"        = @{ ContextWindow = 200000; Tier = "Code";    TokenRatio = 4.0 }
    "gpt-5.2"              = @{ ContextWindow = 200000; Tier = "Standard"; TokenRatio = 4.0 }
    "gpt-5.4-mini"         = @{ ContextWindow = 128000; Tier = "Fast";    TokenRatio = 4.0 }
    "gpt-5-mini"           = @{ ContextWindow = 128000; Tier = "Fast";    TokenRatio = 4.0 }
    "gpt-4.1"              = @{ ContextWindow = 1000000; Tier = "Fast";   TokenRatio = 4.0 }
}

# --- Helpers ------------------------------------------------------------------

function Get-RepoRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if (-not $root) {
        Write-Error "Not inside a git repository."
        exit 1
    }
    return $root.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

function Estimate-Tokens {
    param([string]$Content, [double]$Ratio)
    if (-not $Content) { return 0 }
    return [math]::Ceiling($Content.Length / $Ratio)
}

function Parse-Frontmatter {
    param([string]$FilePath)
    $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return @{} }

    $result = @{ Content = $content; Frontmatter = @{} }

    if ($content -match "(?s)^---\r?\n(.+?)\r?\n---") {
        $yamlBlock = $Matches[1]
        foreach ($line in $yamlBlock -split "`n") {
            $line = $line.Trim()
            if ($line -match "^(\w[\w\-]*):\s*(.+)$") {
                $key = $Matches[1]
                $value = $Matches[2].Trim('"', "'", " ")
                $result.Frontmatter[$key] = $value
            }
        }
    }
    return $result
}

function Convert-GlobToRegex {
    param([string]$Glob)

    $regex = ""
    $i = 0
    $chars = $Glob.ToCharArray()

    while ($i -lt $chars.Length) {
        $c = $chars[$i]

        if ($c -eq '*') {
            if (($i + 1) -lt $chars.Length -and $chars[$i + 1] -eq '*') {
                # ** pattern
                if (($i + 2) -lt $chars.Length -and $chars[$i + 2] -eq '/') {
                    # **/ — match any number of path segments (including zero)
                    $regex += "(.+/)?"
                    $i += 3
                }
                else {
                    # ** at end — match everything remaining
                    $regex += ".*"
                    $i += 2
                }
            }
            else {
                # Single * — match within one path segment
                $regex += "[^/]*"
                $i++
            }
        }
        elseif ($c -eq '?') {
            $regex += "[^/]"
            $i++
        }
        elseif ($c -eq '{') {
            # Brace expansion — collect until closing }
            $braceEnd = $Glob.IndexOf('}', $i)
            if ($braceEnd -gt $i) {
                $inner = $Glob.Substring($i + 1, $braceEnd - $i - 1)
                $alts = $inner -split "," | ForEach-Object { [regex]::Escape($_.Trim()) }
                $regex += "(" + ($alts -join "|") + ")"
                $i = $braceEnd + 1
            }
            else {
                $regex += [regex]::Escape($c)
                $i++
            }
        }
        elseif ($c -eq '.') {
            $regex += "\."
            $i++
        }
        else {
            $regex += [regex]::Escape($c)
            $i++
        }
    }

    return "^$regex$"
}

function Test-GlobMatch {
    param([string]$Pattern, [string]$FilePath)

    $patterns = Split-PatternList -Pattern $Pattern

    foreach ($p in $patterns) {
        if (-not $p) { continue }
        $regex = Convert-GlobToRegex -Glob $p
        if ($FilePath -match $regex) {
            return $true
        }
    }
    return $false
}

function Split-PatternList {
    param([string]$Pattern)

    $patterns = [System.Collections.ArrayList]::new()
    if (-not $Pattern) { return $patterns }

    $depth = 0
    $current = ""
    foreach ($ch in $Pattern.ToCharArray()) {
        if ($ch -eq '{') { $depth++; $current += $ch }
        elseif ($ch -eq '}') { $depth--; $current += $ch }
        elseif ($ch -eq ',' -and $depth -eq 0) {
            [void]$patterns.Add($current.Trim().Trim('"', "'"))
            $current = ""
        }
        else { $current += $ch }
    }
    if ($current.Trim()) {
        [void]$patterns.Add($current.Trim().Trim('"', "'"))
    }

    return $patterns
}

function Test-IsMetaApplyTo {
    param([string]$ApplyTo)

    if (-not $ApplyTo) { return $false }

    $patterns = Split-PatternList -Pattern $ApplyTo
    foreach ($p in $patterns) {
        $normalized = $p.Replace("\", "/").Trim().ToLowerInvariant()
        if ($normalized -match "^(?:\./)?(?:\*\*/)?(agents|skills|instructions)/") {
            return $true
        }
    }

    return $false
}

# --- Main Logic ---------------------------------------------------------------

$RepoRoot = Get-RepoRoot

# Validate model
if (-not $ModelRegistry.ContainsKey($Model)) {
    $available = ($ModelRegistry.Keys | Sort-Object) -join ", "
    Write-Error "Unknown model '$Model'. Available: $available"
    exit 1
}

$ModelInfo = $ModelRegistry[$Model]
$TokenRatio = $ModelInfo.TokenRatio
$ContextWindow = $ModelInfo.ContextWindow

# Collect context items in processing order
$ContextItems = [System.Collections.ArrayList]::new()

# --- Layer 1: .github/copilot-instructions.md ---------------------------------

$copilotInstructions = Join-Path $RepoRoot ".github" "copilot-instructions.md"
if (Test-Path $copilotInstructions) {
    $content = Get-Content -Path $copilotInstructions -Raw
    $tokens = Estimate-Tokens -Content $content -Ratio $TokenRatio
    [void]$ContextItems.Add(@{
        Order    = 1
        Name     = "copilot-instructions"
        Source   = ".github/"
        Type     = "repo-instructions"
        ApplyTo  = "**/*"
        Tokens   = $tokens
        Chars    = $content.Length
        FilePath = $copilotInstructions
        Internal = $false
    })
}

# --- Layer 2: instructions/*.instructions.md ----------------------------------

$instructionsDir = Join-Path $RepoRoot "instructions"
if (Test-Path $instructionsDir) {
    # Check .basecoat.yml for allow-list
    $allowList = $null
    $basecoatYml = Join-Path $RepoRoot ".basecoat.yml"
    if (Test-Path $basecoatYml) {
        $ymlContent = Get-Content -Path $basecoatYml -Raw
        if ($ymlContent -match "(?m)^instructions:\s*\r?\n((?:\s+-\s+.+\r?\n?)+)") {
            $allowList = @()
            foreach ($line in ($Matches[1] -split "`n")) {
                if ($line -match "^\s+-\s+(.+)$") {
                    $allowList += $Matches[1].Trim()
                }
            }
        }
    }

    $instructionFiles = Get-ChildItem -Path $instructionsDir -Filter "*.instructions.md" | Sort-Object Name
    foreach ($instrFile in $instructionFiles) {
        $baseName = $instrFile.BaseName -replace "\.instructions$", ""

        # Skip if allow-list exists and this file isn't in it
        if ($allowList -and ($baseName -notin $allowList)) { continue }

        $parsed = Parse-Frontmatter -FilePath $instrFile.FullName
        $applyTo = $parsed.Frontmatter["applyTo"]
        if (-not $applyTo) { $applyTo = "**/*" }

        $distribute = $parsed.Frontmatter["distribute"]
        $isInternal = ($distribute -eq "false")

        # If -File specified, filter by applyTo match
        if ($File) {
            $normalizedFile = $File.Replace("\", "/")
            if (-not (Test-GlobMatch -Pattern $applyTo -FilePath $normalizedFile)) {
                continue
            }
        }

        $tokens = Estimate-Tokens -Content $parsed.Content -Ratio $TokenRatio
        [void]$ContextItems.Add(@{
            Order    = 2
            Name     = $baseName
            Source   = "instructions/"
            Type     = "instruction"
            ApplyTo  = $applyTo
            Tokens   = $tokens
            Chars    = $parsed.Content.Length
            FilePath = $instrFile.FullName
            Internal = $isInternal
        })
    }
}

# --- Layer 3: Agent definition ------------------------------------------------

if ($Agent) {
    # Find agent file matching the short name (may have prefix in new naming convention)
    $agentDir = Join-Path $RepoRoot "agents"
    $agentFile = Get-ChildItem -Path $agentDir -Filter "*$Agent.agent.md" -File | Where-Object {
        $baseName = $_.BaseName -replace '\.agent$', ''
        $shortName = $baseName -replace '^basecoat-\d+-\w+-', ''
        $shortName -eq $Agent
    } | Select-Object -First 1
    
    if (-not $agentFile) {
        Write-Warning "Agent file not found: $Agent.agent.md (or with naming prefix)"
    }
    else {
        $parsed = Parse-Frontmatter -FilePath $agentFile.FullName
        $tokens = Estimate-Tokens -Content $parsed.Content -Ratio $TokenRatio
        [void]$ContextItems.Add(@{
            Order    = 3
            Name     = $Agent
            Source   = "agents/"
            Type     = "agent"
            ApplyTo  = "(agent mode)"
            Tokens   = $tokens
            Chars    = $parsed.Content.Length
            FilePath = $agentFile.FullName
            Internal = $false
        })

        # --- Layer 4: Skills referenced by agent ---
        # Parse allowed_skills from frontmatter
        $skillsDir = Join-Path $RepoRoot "skills"
        if (Test-Path $skillsDir) {
            $agentContent = $parsed.Content
            $referencedSkills = @()

            # Extract allowed_skills list from frontmatter
            if ($agentContent -match "(?m)^allowed_skills:\s*\[([^\]]*)\]") {
                $skillList = $Matches[1]
                $referencedSkills = $skillList -split "," | ForEach-Object {
                    $_.Trim().Trim('"', "'", " ")
                } | Where-Object { $_ }
            }
            elseif ($agentContent -match "(?m)^allowed-skills:\s*\[([^\]]*)\]") {
                $skillList = $Matches[1]
                $referencedSkills = $skillList -split "," | ForEach-Object {
                    $_.Trim().Trim('"', "'", " ")
                } | Where-Object { $_ }
            }

            # Fallback for current agent format: parse markdown "## Allowed Skills" bullet list
            if ((@($referencedSkills)).Count -eq 0) {
                $allowedSkillsMatch = [regex]::Match(
                    $agentContent,
                    "(?ms)^##\s+Allowed Skills\s*$\s*(.+?)(?=^##\s+|\z)"
                )
                if ($allowedSkillsMatch.Success) {
                    $referencedSkills = @(
                        $allowedSkillsMatch.Groups[1].Value -split "`n" | ForEach-Object {
                            if ($_ -match "^\s*-\s+([A-Za-z0-9._-]+)\b.*$") {
                                $Matches[1]
                            }
                        } | Where-Object { $_ }
                    )
                }
            }

            $referencedSkills = @($referencedSkills | Select-Object -Unique)

            foreach ($skillName in $referencedSkills) {
                $skillPath = Join-Path $skillsDir $skillName
                if (Test-Path $skillPath) {
                    $skillFile = Join-Path $skillPath "SKILL.md"
                    if (Test-Path $skillFile) {
                        $skillContent = Get-Content -Path $skillFile -Raw
                        $skillTokens = Estimate-Tokens -Content $skillContent -Ratio $TokenRatio
                        [void]$ContextItems.Add(@{
                            Order    = 4
                            Name     = $skillName
                            Source   = "skills/"
                            Type     = "skill"
                            ApplyTo  = "(via $Agent)"
                            Tokens   = $skillTokens
                            Chars    = $skillContent.Length
                            FilePath = $skillFile
                            Internal = $false
                        })
                    }
                }
            }
        }
    }
}

# --- Layer 5: Prompt templates ------------------------------------------------

$promptsDir = Join-Path $RepoRoot "prompts"
if (Test-Path $promptsDir) {
    $promptFiles = Get-ChildItem -Path $promptsDir -Filter "*.prompt.md" -ErrorAction SilentlyContinue
    $promptCount = 0
    $promptTokensTotal = 0
    foreach ($pf in $promptFiles) {
        $content = Get-Content -Path $pf.FullName -Raw
        $promptTokensTotal += (Estimate-Tokens -Content $content -Ratio $TokenRatio)
        $promptCount++
    }
    if ($promptCount -gt 0) {
        [void]$ContextItems.Add(@{
            Order    = 5
            Name     = "prompts ($promptCount available)"
            Source   = "prompts/"
            Type     = "prompt"
            ApplyTo  = "(on invocation only)"
            Tokens   = $promptTokensTotal
            Chars    = 0
            FilePath = $promptsDir
            Internal = $false
            OnDemand = $true
        })
    }
}

# --- Layer 6: Repo memory ----------------------------------------------------

$memoryDir = Join-Path $RepoRoot ".memory"
if (Test-Path $memoryDir) {
    $memFiles = @(Get-ChildItem -Path $memoryDir -File -Recurse | Where-Object { $_.Name -ne ".gitkeep" })
    $memTokensTotal = 0
    $memCharsTotal = 0
    foreach ($mf in $memFiles) {
        $content = Get-Content -Path $mf.FullName -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $memTokensTotal += (Estimate-Tokens -Content $content -Ratio $TokenRatio)
            $memCharsTotal += $content.Length
        }
    }
    if ($memTokensTotal -gt 0) {
        [void]$ContextItems.Add(@{
            Order    = 6
            Name     = "repo memory ($($memFiles.Count) files)"
            Source   = ".memory/"
            Type     = "memory"
            ApplyTo  = "(always)"
            Tokens   = $memTokensTotal
            Chars    = $memCharsTotal
            FilePath = $memoryDir
            Internal = $false
        })
    }
}

# --- Output -------------------------------------------------------------------

# Sort by order then name
$ContextItems = $ContextItems | Sort-Object { $_.Order }, { $_.Name }

# Calculate cumulative tokens (exclude on-demand items from running total)
$cumulative = 0
foreach ($item in $ContextItems) {
    $isOnDemand = $item.ContainsKey("OnDemand") -and $item.OnDemand
    if (-not $isOnDemand) {
        $cumulative += $item.Tokens
    }
    $item.Cumulative = $cumulative
    $item.BudgetPct = [math]::Round(($cumulative / $ContextWindow) * 100, 1)
    if (-not $item.ContainsKey("OnDemand")) { $item.OnDemand = $false }
    if (-not $item.ContainsKey("Internal")) { $item.Internal = $false }
    if (-not $item.ContainsKey("SourceLabel")) { $item.SourceLabel = "$($item.Type)@$($item.Source)" }
    if (-not $item.ContainsKey("Meta")) {
        $item.Meta = (($item.Type -in @("agent", "skill")) -or (Test-IsMetaApplyTo -ApplyTo $item.ApplyTo))
    }
}

$totalTokens = $cumulative
$totalPct = [math]::Round(($totalTokens / $ContextWindow) * 100, 1)
$hasMetaItems = @($ContextItems | Where-Object { $_.Meta }).Count -gt 0

# --- JSON output ---
if ($Json) {
    $output = @{
        model          = $Model
        tier           = $ModelInfo.Tier
        contextWindow  = $ContextWindow
        tokenRatio     = $TokenRatio
        totalTokens    = $totalTokens
        budgetPercent  = $totalPct
        filter         = @{ file = $File; agent = $Agent }
        items          = $ContextItems | ForEach-Object {
            @{
                order      = $_.Order
                name       = $_.Name
                source     = $_.Source
                sourceLabel = $_.SourceLabel
                type       = $_.Type
                applyTo    = $_.ApplyTo
                tokens     = $_.Tokens
                cumulative = $_.Cumulative
                budgetPct  = $_.BudgetPct
                internal   = $_.Internal
                onDemand   = $_.OnDemand
                meta       = $_.Meta
            }
        }
    }
    $output | ConvertTo-Json -Depth 4
    return
}

# --- Terminal output ---

$separator = [string]::new([char]0x2500, 84)

# Header
Write-Host ""
Write-Host " BASECOAT CONTEXT BUDGET ESTIMATOR" -ForegroundColor Cyan
Write-Host " $separator" -ForegroundColor DarkGray
Write-Host "  Model:    " -NoNewline -ForegroundColor Gray
Write-Host "$Model" -NoNewline -ForegroundColor White
Write-Host " ($($ModelInfo.Tier), $($ContextWindow.ToString('N0')) tokens)" -ForegroundColor DarkGray
if ($File) {
    Write-Host "  File:     " -NoNewline -ForegroundColor Gray
    Write-Host "$File" -ForegroundColor Yellow
}
if ($Agent) {
    Write-Host "  Agent:    " -NoNewline -ForegroundColor Gray
    Write-Host "$Agent" -ForegroundColor Magenta
}
Write-Host " $separator" -ForegroundColor DarkGray
Write-Host ""

if (-not $Summary) {
    # Column headers
    $fmt = " {0,-4} {1,-28} {2,-24} {3,8} {4,8} {5,7}"
    Write-Host ($fmt -f "#", "Name", "Source (type@path)", "Tokens", "Cumul.", "Budget") -ForegroundColor DarkCyan
    Write-Host " $separator" -ForegroundColor DarkGray

    $index = 0
    foreach ($item in $ContextItems) {
        $index++
        $name = $item.Name
        # Add markers for internal/on-demand items
        if ($item.Internal) { $name = "$name [internal]" }
        if ($item.OnDemand) { $name = "$name [on-demand]" }
        if ($item.Meta) { $name = "$name [meta]" }
        if ($name.Length -gt 28) { $name = $name.Substring(0, 25) + "..." }
        $sourceLabel = $item.SourceLabel
        if ($sourceLabel.Length -gt 24) { $sourceLabel = $sourceLabel.Substring(0, 21) + "..." }

        $tokenStr = $item.Tokens.ToString("N0")
        $cumulStr = if ($item.OnDemand) { "---" } else { $item.Cumulative.ToString("N0") }
        $pctStr = if ($item.OnDemand) { "---" } else { "$($item.BudgetPct)%" }

        # Color by type
        $typeColor = switch ($item.Type) {
            "repo-instructions" { "Green" }
            "instruction"       { "Green" }
            "agent"             { "Magenta" }
            "skill"             { "Blue" }
            "prompt"            { "Yellow" }
            "memory"            { "DarkYellow" }
            default             { "White" }
        }

        # Dim internal items
        if ($item.Internal) { $typeColor = "DarkGray" }

        # Budget color
        $budgetColor = if ($item.OnDemand) { "DarkGray" }
                       elseif ($item.BudgetPct -lt 25) { "Green" }
                       elseif ($item.BudgetPct -lt 50) { "Yellow" }
                       elseif ($item.BudgetPct -lt 75) { "DarkYellow" }
                       else { "Red" }

        Write-Host (" {0,-4} " -f "$index.") -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-28} " -f $name) -NoNewline -ForegroundColor $typeColor
        Write-Host ("{0,-24} " -f $sourceLabel) -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,7} " -f $tokenStr) -NoNewline -ForegroundColor White
        Write-Host ("{0,8} " -f $cumulStr) -NoNewline -ForegroundColor Gray
        Write-Host ("{0,6}" -f $pctStr) -ForegroundColor $budgetColor
    }

    Write-Host " $separator" -ForegroundColor DarkGray
}

# Budget summary bar
$barWidth = 40
$filledWidth = [math]::Min($barWidth, [math]::Floor(($totalPct / 100) * $barWidth))
$emptyWidth = $barWidth - $filledWidth
$filledChar = [char]0x2588
$emptyChar = [char]0x2591

$barColor = if ($totalPct -lt 25) { "Green" }
            elseif ($totalPct -lt 50) { "Yellow" }
            elseif ($totalPct -lt 75) { "DarkYellow" }
            else { "Red" }

Write-Host ""
Write-Host "  Total: " -NoNewline -ForegroundColor Gray
Write-Host "$($totalTokens.ToString('N0'))" -NoNewline -ForegroundColor White
Write-Host " / $($ContextWindow.ToString('N0')) tokens " -NoNewline -ForegroundColor DarkGray
Write-Host "($totalPct%)" -ForegroundColor $barColor
Write-Host "  " -NoNewline
Write-Host ([string]::new($filledChar, $filledWidth)) -NoNewline -ForegroundColor $barColor
Write-Host ([string]::new($emptyChar, $emptyWidth)) -ForegroundColor DarkGray
Write-Host ""

# Legend
Write-Host "  Legend: " -NoNewline -ForegroundColor DarkGray
Write-Host "instructions" -NoNewline -ForegroundColor Green
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "agents" -NoNewline -ForegroundColor Magenta
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "skills" -NoNewline -ForegroundColor Blue
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "prompts" -NoNewline -ForegroundColor Yellow
Write-Host " | " -NoNewline -ForegroundColor DarkGray
Write-Host "memory" -ForegroundColor DarkYellow
Write-Host ""

# Processing hints
Write-Host "  Processing hints:" -ForegroundColor DarkCyan
Write-Host "   - Items are loaded in priority order (repo instructions first)" -ForegroundColor DarkGray
Write-Host "   - Instructions with applyTo: '**/*' load for ALL files" -ForegroundColor DarkGray
Write-Host "   - Scoped instructions only load when editing matching files" -ForegroundColor DarkGray
Write-Host "   - Name collisions across skills/instructions are expected; use Source (type@path)" -ForegroundColor DarkGray
if ($hasMetaItems) {
    Write-Host "   - [meta] marks context scoped to agents/, skills/, or instructions/" -ForegroundColor DarkGray
    Write-Host "   - Runtime context applies to regular project files under active work" -ForegroundColor DarkGray
}
if ($totalPct -gt 50) {
    Write-Host "   - WARNING: Estimated context exceeds 50% of window" -ForegroundColor Yellow
    Write-Host "     Consider narrowing .basecoat.yml allow-lists" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Note: This is an ESTIMATE. Actual context depends on Copilot's" -ForegroundColor DarkGray
Write-Host "  runtime assembly logic, conversation history, and tool outputs." -ForegroundColor DarkGray
Write-Host ""
