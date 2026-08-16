#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates a dependency graph of BaseCoat agents, skills, and instructions.

.DESCRIPTION
    Scans agent frontmatter for `allowed_skills` and `handoffs[].agent` relationships,
    and instruction frontmatter for `applyTo` glob coverage. Outputs a Mermaid diagram
    and highlights orphaned nodes (no incoming or outgoing edges).

.PARAMETER Format
    Output format: Mermaid (default) or DOT (Graphviz).

.PARAMETER OutputFile
    Optional path to write the graph. If omitted, writes to stdout.

.PARAMETER ShowOrphans
    When set, orphaned nodes (no edges) are listed separately. Default: true.

.PARAMETER IncludeInstructions
    When set, include instruction applyTo coverage edges. Default: false (clutters graph).

.EXAMPLE
    pwsh scripts/graph-dependencies.ps1
    pwsh scripts/graph-dependencies.ps1 -Format DOT -OutputFile graph.dot
    pwsh scripts/graph-dependencies.ps1 -ShowOrphans
#>
[CmdletBinding()]
param(
    [ValidateSet('Mermaid', 'DOT')]
    [string]$Format = 'Mermaid',

    [string]$OutputFile = '',

    [switch]$ShowOrphans,

    [switch]$IncludeInstructions
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent

# ── Helpers ──────────────────────────────────────────────────────────────────

function Read-Frontmatter {
    param([string]$FilePath)
    $lines = Get-Content $FilePath -Raw
    if (-not $lines.StartsWith('---')) { return @{} }
    $end = $lines.IndexOf('---', 3)
    if ($end -lt 0) { return @{} }
    $yaml = $lines.Substring(3, $end - 3).Trim()

    $result = @{}
    $currentKey = $null
    $listMode = $false
    $listItems = @()

    foreach ($line in ($yaml -split "`n")) {
        $line = $line.TrimEnd()
        if ($line -match '^\s*$') { continue }

        # Detect list continuation
        if ($listMode -and $line -match '^\s+-\s+(.+)') {
            $listItems += $Matches[1].Trim().Trim('"').Trim("'")
            continue
        } elseif ($listMode) {
            $result[$currentKey] = $listItems
            $listMode = $false
        }

        if ($line -match '^(\w[\w\-_]*):\s*\[(.+)\]') {
            # Inline array: key: [a, b, c]
            $key = $Matches[1]
            $val = $Matches[2]
            $result[$key] = $val -split ',\s*' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ }
        } elseif ($line -match '^(\w[\w\-_]*):\s*(.+)') {
            $key = $Matches[1]
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            $result[$key] = $val
        } elseif ($line -match '^(\w[\w\-_]*):\s*$') {
            $currentKey = $Matches[1]
            $listMode = $true
            $listItems = @()
        }
    }
    if ($listMode -and $currentKey) {
        $result[$currentKey] = $listItems
    }
    return $result
}

function Read-HandoffAgents {
    param([string]$FilePath)
    # Parse handoffs block: lines with "agent: <name>"
    $content = Get-Content $FilePath -Raw
    $agents = [System.Collections.Generic.List[string]]::new()
    $inHandoffs = $false
    foreach ($line in ($content -split "`n")) {
        $trimmed = $line.TrimEnd()
        if ($trimmed -match '^handoffs:') { $inHandoffs = $true; continue }
        if ($inHandoffs) {
            if ($trimmed -match '^\w' -and $trimmed -notmatch '^\s+-') { $inHandoffs = $false; continue }
            if ($trimmed -match '^\s+agent:\s+(.+)') {
                $agents.Add($Matches[1].Trim().Trim('"').Trim("'"))
            }
        }
    }
    return $agents
}

# ── Collect nodes ─────────────────────────────────────────────────────────────

$agents = @{}
foreach ($f in Get-ChildItem "$RepoRoot\agents" -Filter '*.agent.md') {
    $fm = Read-Frontmatter $f.FullName
    $name = if ($fm['name']) { $fm['name'] } else { $f.BaseName -replace '\.agent$', '' }
    $agents[$name] = @{
        file       = $f.Name
        skills     = if ($fm['allowed_skills']) { @($fm['allowed_skills']) } else { @() }
        handoffs   = @(Read-HandoffAgents $f.FullName)
    }
}

$skills = @{}
foreach ($d in Get-ChildItem "$RepoRoot\skills" -Directory) {
    $skill_md = Join-Path $d.FullName 'SKILL.md'
    if (Test-Path $skill_md) {
        $fm = Read-Frontmatter $skill_md
        $name = if ($fm['name']) { $fm['name'] } else { $d.Name }
        $skills[$name] = @{ dir = $d.Name }
    }
}

$instructions = @{}
if ($IncludeInstructions) {
    foreach ($f in Get-ChildItem "$RepoRoot\instructions" -Filter '*.instructions.md') {
        $fm = Read-Frontmatter $f.FullName
        $name = $f.BaseName -replace '\.instructions$', ''
        $instructions[$name] = @{
            applyTo = if ($fm['applyTo']) { $fm['applyTo'] } else { '' }
        }
    }
}

# ── Build edge list ──────────────────────────────────────────────────────────

$edges = [System.Collections.Generic.List[hashtable]]::new()
$allNodes = [System.Collections.Generic.HashSet[string]]::new()

foreach ($agentName in $agents.Keys) {
    $null = $allNodes.Add("agent:$agentName")

    foreach ($skill in $agents[$agentName].skills) {
        if (-not $skill) { continue }
        $null = $allNodes.Add("skill:$skill")
        $edges.Add(@{ from = "agent:$agentName"; to = "skill:$skill"; type = 'uses' })
    }

    foreach ($target in $agents[$agentName].handoffs) {
        if (-not $target) { continue }
        $null = $allNodes.Add("agent:$target")
        $edges.Add(@{ from = "agent:$agentName"; to = "agent:$target"; type = 'handoff' })
    }
}

foreach ($skillName in $skills.Keys) {
    $null = $allNodes.Add("skill:$skillName")
}

if ($IncludeInstructions) {
    foreach ($instrName in $instructions.Keys) {
        $null = $allNodes.Add("instr:$instrName")
        $applyTo = $instructions[$instrName].applyTo
        if ($applyTo -like 'agents/**') {
            foreach ($a in $agents.Keys) {
                $edges.Add(@{ from = "instr:$instrName"; to = "agent:$a"; type = 'applies' })
            }
        }
    }
}

# ── Find orphans ─────────────────────────────────────────────────────────────

$connectedNodes = [System.Collections.Generic.HashSet[string]]::new()
foreach ($e in $edges) {
    $null = $connectedNodes.Add($e.from)
    $null = $connectedNodes.Add($e.to)
}

$orphans = $allNodes | Where-Object { -not $connectedNodes.Contains($_) } | Sort-Object

# ── Safe node ID (no hyphens in Mermaid IDs) ─────────────────────────────────

function NodeId {
    param([string]$n)
    $n -replace '[^a-zA-Z0-9_]', '_'
}

# ── Render ────────────────────────────────────────────────────────────────────

$sb = [System.Text.StringBuilder]::new()

if ($Format -eq 'Mermaid') {
    $null = $sb.AppendLine('```mermaid')
    $null = $sb.AppendLine('graph LR')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    %% Agents (blue)')

    foreach ($a in ($agents.Keys | Sort-Object)) {
        $id = NodeId "agent_$a"
        $null = $sb.AppendLine("    $id[[$a]]:::agent")
    }

    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    %% Skills (green)')
    foreach ($s in ($skills.Keys | Sort-Object)) {
        $id = NodeId "skill_$s"
        $null = $sb.AppendLine("    $id(($s)):::skill")
    }

    if ($IncludeInstructions) {
        $null = $sb.AppendLine()
        $null = $sb.AppendLine('    %% Instructions (yellow)')
        foreach ($i in ($instructions.Keys | Sort-Object)) {
            $id = NodeId "instr_$i"
            $null = $sb.AppendLine("    $id{$i}:::instr")
        }
    }

    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    %% Edges')
    foreach ($e in $edges) {
        $fromId = NodeId ($e.from -replace ':', '_')
        $toId   = NodeId ($e.to   -replace ':', '_')
        $arrow  = if ($e.type -eq 'handoff') { '-->' } else { '-.->' }
        $null = $sb.AppendLine("    $fromId $arrow $toId")
    }

    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    classDef agent fill:#4a90d9,color:#fff,stroke:#2c5f8a')
    $null = $sb.AppendLine('    classDef skill fill:#5cb85c,color:#fff,stroke:#3a7a3a')
    $null = $sb.AppendLine('    classDef instr fill:#f0ad4e,color:#fff,stroke:#b07a1e')
    $null = $sb.AppendLine('```')
} else {
    # DOT format
    $null = $sb.AppendLine('digraph BaseCoat {')
    $null = $sb.AppendLine('    rankdir=LR;')
    $null = $sb.AppendLine('    node [fontname="Helvetica"];')
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    // Agents')
    foreach ($a in ($agents.Keys | Sort-Object)) {
        $id = NodeId "agent_$a"
        $null = $sb.AppendLine("    $id [label=""$a"" shape=box style=filled fillcolor=""#4a90d9"" fontcolor=white];")
    }
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    // Skills')
    foreach ($s in ($skills.Keys | Sort-Object)) {
        $id = NodeId "skill_$s"
        $null = $sb.AppendLine("    $id [label=""$s"" shape=ellipse style=filled fillcolor=""#5cb85c"" fontcolor=white];")
    }
    $null = $sb.AppendLine()
    $null = $sb.AppendLine('    // Edges')
    foreach ($e in $edges) {
        $fromId = NodeId ($e.from -replace ':', '_')
        $toId   = NodeId ($e.to   -replace ':', '_')
        $style  = if ($e.type -eq 'handoff') { '' } else { ' style=dashed' }
        $null = $sb.AppendLine("    $fromId -> $toId [$style];")
    }
    $null = $sb.AppendLine('}')
}

# ── Orphan report ─────────────────────────────────────────────────────────────

if ($ShowOrphans -or (-not $OutputFile)) {
    $orphanSection = [System.Text.StringBuilder]::new()
    $null = $orphanSection.AppendLine()
    $null = $orphanSection.AppendLine("## Orphaned nodes ($($orphans.Count) total — no incoming or outgoing edges)")
    $null = $orphanSection.AppendLine()
    if ($orphans) {
        foreach ($o in $orphans) {
            $null = $orphanSection.AppendLine("- $o")
        }
    } else {
        $null = $orphanSection.AppendLine('_None — all nodes have at least one edge._')
    }
    $null = $sb.Append($orphanSection)
}

# ── Summary stats ─────────────────────────────────────────────────────────────

$stats = "Graph: $($agents.Count) agents, $($skills.Count) skills, $($edges.Count) edges, $($orphans.Count) orphans"

# ── Output ────────────────────────────────────────────────────────────────────

$output = $sb.ToString()

if ($OutputFile) {
    $output | Set-Content -Path $OutputFile -Encoding UTF8
    Write-Host $stats
    Write-Host "Written to: $OutputFile"
} else {
    Write-Output $output
    Write-Host $stats -ForegroundColor Cyan
}
