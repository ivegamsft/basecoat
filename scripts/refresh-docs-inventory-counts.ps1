[CmdletBinding()]
param(
    [string]$RootDir = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location $RootDir

# Count actual assets
$agents = @(Get-ChildItem 'agents' -Filter '*.agent.md' -File | Sort-Object Name)
$skills = @(Get-ChildItem 'skills' -Recurse -Filter 'SKILL.md' -File)
$instructions = @(Get-ChildItem 'instructions' -Filter '*.instructions.md' -File)
$prompts = @(Get-ChildItem 'prompts' -Filter '*.prompt.md' -File)

$docsIndexPath = Join-Path (Get-Location) 'docs/index.md'
if (-not (Test-Path $docsIndexPath)) {
    throw "ERROR: docs/index.md not found at $docsIndexPath"
}

$content = Get-Content $docsIndexPath -Raw

# Replace counts in the What's included table
# The regex matches the exact table format with markdown pipes and bold asset names
$patterns = @{
    Agents       = '\|\s+\*\*Agents\*\*\s+\|\s+\d+\s+\|'
    Skills       = '\|\s+\*\*Skills\*\*\s+\|\s+\d+\s+\|'
    Instructions = '\|\s+\*\*Instructions\*\*\s+\|\s+\d+\s+\|'
    Prompts      = '\|\s+\*\*Prompts\*\*\s+\|\s+\d+\s+\|'
}

$replacements = @{
    Agents       = "| **Agents** | $($agents.Count) |"
    Skills       = "| **Skills** | $($skills.Count) |"
    Instructions = "| **Instructions** | $($instructions.Count) |"
    Prompts      = "| **Prompts** | $($prompts.Count) |"
}

foreach ($key in $patterns.Keys) {
    $pattern = $patterns[$key]
    $replacement = $replacements[$key]
    
    if ($content -match $pattern) {
        $content = $content -replace $pattern, $replacement
        Write-Host "✓ Updated $key count to $($replacements[$key].Split('|')[2].Trim())"
    } else {
        Write-Host "✗ Could not find pattern for $key in docs/index.md"
        exit 1
    }
}

# Write the updated content back
Set-Content -Path $docsIndexPath -Value $content -NoNewline

Write-Host "`nDocumentation inventory counts refreshed successfully:"
Write-Host "  Agents: $($agents.Count)"
Write-Host "  Skills: $($skills.Count)"
Write-Host "  Instructions: $($instructions.Count)"
Write-Host "  Prompts: $($prompts.Count)"
