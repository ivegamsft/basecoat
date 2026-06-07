#Requires -Version 7.0
<#
.SYNOPSIS
Remove unsupported frontmatter fields from agent files (line-by-line processing).

.DESCRIPTION
Processes agent YAML frontmatter line by line to remove unsupported fields and their nested content.

Supported fields: name, description, visibility, model, allowed_skills
Unsupported fields removed: type, compatibility, metadata, allowed-tools, allowed_skills (with hyphen), color, handoffs, trigger

#>
param(
  [switch]$Fix
)

$repoRoot = git rev-parse --show-toplevel
$agentDir = "$repoRoot\agents"

$unsupported = @('type', 'compatibility', 'metadata', 'allowed-tools', 'allowed_skills', 'color', 'handoffs', 'trigger')
$filesFixed = 0

Get-ChildItem "$agentDir\*.agent.md" | ForEach-Object {
  $filePath = $_.FullName
  $content = Get-Content $filePath -Raw
  
  # Extract frontmatter
  if ($content -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)$') {
    $frontmatter = $matches[1]
    $body = $matches[2]
    
    $lines = @($frontmatter -split "`n")
    $keepLines = @()
    $skipUntilNextField = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      $trimmed = $line.Trim()
      
      # Check if line starts an unsupported field
      $isUnsupportedField = $false
      foreach ($field in $unsupported) {
        if ($trimmed -match "^$([regex]::Escape($field))\s*(:|\-|\[)") {
          $isUnsupportedField = $true
          break
        }
      }
      
      if ($isUnsupportedField) {
        # Skip this line and mark to skip nested content
        $skipUntilNextField = $true
      } elseif ($skipUntilNextField) {
        # Empty lines might be between fields
        if (-not $trimmed) {
          # Keep blank lines for now, will clean up later
          $keepLines += $line
        } elseif ($line -match '^\s+') {
          # This line is indented, skip it (nested content)
          continue
        } else {
          # This is a new top-level field, stop skipping
          $skipUntilNextField = $false
          $keepLines += $line
        }
      } else {
        # Normal keep
        $keepLines += $line
      }
    }
    
    # Clean up formatting
    $cleaned = ($keepLines -join "`n").Trim()
    
    # Remove excessive blank lines (more than 1 consecutive)
    $cleaned = $cleaned -replace '`n\s*`n\s*`n+', "`n`n"
    
    # Ensure ends with newline before ---
    $newContent = "---`n$cleaned`n---`n$body"
    
    # Check if content actually changed
    if ($newContent -ne $content) {
      if ($Fix) {
        Set-Content $filePath -Value $newContent -NoNewline
        Write-Host "FIXED: $($_.Name)" -ForegroundColor Green
        $filesFixed++
      } else {
        Write-Host "WOULD FIX: $($_.Name)" -ForegroundColor Yellow
      }
    }
  }
}

Write-Host ""
if ($Fix) {
  Write-Host "Fixed $filesFixed files" -ForegroundColor Green
} else {
  Write-Host "Would fix $filesFixed files" -ForegroundColor Yellow
}
