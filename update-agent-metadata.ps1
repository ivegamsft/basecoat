param([string]$AgentFile)

$colorMap = @{
    'Security & Compliance' = 'red'
    'Development & Review' = 'blue'
    'Development & Engineering' = 'blue'
    'API & Integration' = 'purple'
    'Data & Analytics' = 'yellow'
    'Infrastructure & DevOps' = 'green'
    'Operations & Monitoring' = 'cyan'
    'Process & Management' = 'teal'
    'Testing & Quality' = 'orange'
    'AI & ML' = 'magenta'
    'Orchestration' = 'indigo'
    'Guidance & Authoring' = 'pink'
    'AI & Development' = 'blue'
}

$content = Get-Content $AgentFile -Raw

# Split by frontmatter markers
if ($content -notmatch '^---\s*\n') {
    Write-Host "SKIP: No frontmatter in $AgentFile"
    exit 0
}

# Extract frontmatter and body
$split = $content -split '(?m)^---\s*$'
if ($split.Count -lt 3) {
    Write-Host "SKIP: Malformed frontmatter in $AgentFile"
    exit 0
}

$frontmatter = $split[1].Trim()
$body = $split[2]

# Check what's missing
$hasColor = $frontmatter -match '(?m)^color:\s+\w'
$hasTools = $frontmatter -match '(?m)^tools:\s+\['
$hasHandoffs = $frontmatter -match '(?m)^handoffs:\s*$' -or $frontmatter -match '(?m)^handoffs:\s*\[' -or ($frontmatter -match '(?m)^handoffs:' -and $frontmatter -match '(?m)^handoffs:\s*-')

if ($hasColor -and $hasTools -and $hasHandoffs) {
    Write-Host "SKIP: $AgentFile already complete"
    exit 0
}

# Extract category
$categoryMatch = $frontmatter -match '(?m)^category:\s*["\']?([^"\'\n]+)'
$category = if ($Matches) { $Matches[1].Trim() } else { 'Development & Engineering' }
$color = $colorMap[$category] ?? 'blue'

# Prepare updates
$updates = @{}
if (-not $hasColor) { $updates['color'] = "color: $color" }
if (-not $hasTools) { $updates['tools'] = "tools: [bash, git, gh, grep, find]" }
if (-not $hasHandoffs) { $updates['handoffs'] = "handoffs: []" }

if ($updates.Count -eq 0) {
    Write-Host "SKIP: $AgentFile - nothing to add"
    exit 0
}

# Parse frontmatter lines
$fmLines = $frontmatter -split "`n"
$newFM = @()
$insertedColor = $false
$insertedTools = $false
$insertedHandoffs = $false

for ($i = 0; $i -lt $fmLines.Count; $i++) {
    $line = $fmLines[$i]
    
    # Insert color after type
    if (-not $insertedColor -and $updates['color'] -and $line -match '^\s*type:') {
        $newFM += $line
        $newFM += $updates['color']
        $insertedColor = $true
        continue
    }
    
    # Insert tools before allowed-tools
    if (-not $insertedTools -and $updates['tools'] -and $line -match '^\s*allowed-tools:') {
        $newFM += $updates['tools']
        $insertedTools = $true
    }
    
    # Insert handoffs before allowed_skills (but only if not already present)
    if (-not $insertedHandoffs -and $updates['handoffs'] -and $line -match '^\s*allowed_skills:') {
        $newFM += $updates['handoffs']
        $insertedHandoffs = $true
    }
    
    $newFM += $line
}

# Add remaining fields at the end
if ($updates['color'] -and -not $insertedColor) { $newFM += $updates['color'] }
if ($updates['tools'] -and -not $insertedTools) { $newFM += $updates['tools'] }
if ($updates['handoffs'] -and -not $insertedHandoffs) { $newFM += $updates['handoffs'] }

# Reconstruct
$newContent = "---`n" + ($newFM -join "`n") + "`n---" + $body

# Write back
Set-Content -Path $AgentFile -Value $newContent -Encoding UTF8 -NoNewline
if ($newContent -notmatch '\n$') {
    Add-Content -Path $AgentFile -Value "`n" -Encoding UTF8
}

Write-Host "UPDATE: $AgentFile - added $(($updates.Keys | Join-String ', '))"
