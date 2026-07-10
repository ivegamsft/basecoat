#Requires -Version 7.0
<#
.SYNOPSIS
Remove unsupported frontmatter fields from skill SKILL.md files.

#>
param(
  [switch]$Fix
)

$repoRoot = git rev-parse --show-toplevel
$skillsDir = "$repoRoot\skills"

$unsupported = @('type', 'compatibility', 'metadata', 'allowed-tools', 'allowed_skills', 'color', 'handoffs', 'trigger')
$filesFixed = 0

Get-ChildItem "$skillsDir" -Directory | ForEach-Object {
  $skillPath = "$($_.FullName)\SKILL.md"
  if (-not (Test-Path $skillPath)) { return }
  
  $content = Get-Content $skillPath -Raw
  
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
        $skipUntilNextField = $true
      } elseif ($skipUntilNextField) {
        # Empty lines might be between fields
        if (-not $trimmed) {
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
        Set-Content $skillPath -Value $newContent -NoNewline
        Write-Host "FIXED: $($_.Name)/SKILL.md" -ForegroundColor Green
        $filesFixed++
      } else {
        Write-Host "WOULD FIX: $($_.Name)/SKILL.md" -ForegroundColor Yellow
      }
    }
  }
}

Write-Host ""
if ($Fix) {
  Write-Host "Fixed $filesFixed skills" -ForegroundColor Green
} else {
  Write-Host "Would fix $filesFixed skills" -ForegroundColor Yellow
}
