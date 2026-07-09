[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")]
  [string]$Repo,

  [Parameter(Mandatory)]
  [ValidateSet("issue_to_pr", "ready_to_merge", "merge_to_release")]
  [string]$Stage,

  [Parameter(Mandatory)]
  [ValidateSet("issue", "pr")]
  [string]$EntityType,

  [Parameter(Mandatory)]
  [int]$EntityNumber,

  [Parameter(Mandatory)]
  [string]$Owner,

  [Parameter(Mandatory)]
  [string]$EvidenceUrl,

  [Parameter(Mandatory)]
  [string]$NextAction,

  [switch]$DryRun,
  [string]$OutputPath = "test-results\delivery-autopilot\escalation-payload.json"
)

$ErrorActionPreference = "Stop"

function Write-JsonOutput {
  param([object]$Data, [string]$Path)
  $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
  $directory = Split-Path -Path $fullPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $fullPath -Encoding utf8
}

$fingerprint = "$Stage`:$EntityType`:$EntityNumber"
$payload = [ordered]@{
  mode = if ($DryRun) { "dry-run" } else { "live" }
  generated_at = if ($DryRun) { "dry-run-static" } else { (Get-Date).ToUniversalTime().ToString("o") }
  repo = $Repo
  stage = $Stage
  entity_type = $EntityType
  entity_number = $EntityNumber
  fingerprint = $fingerprint
  labels = @("remediation", "escalated", "automation")
  owner = $Owner
  evidence_url = $EvidenceUrl
  next_action = $NextAction
  title = "[Delivery Autopilot][$Stage] $($EntityType.ToUpper()) #$EntityNumber requires escalation"
  body_lines = @(
    "<!-- delivery-autopilot:escalation:v1 -->",
    "<!-- delivery-autopilot:fingerprint:$fingerprint -->",
    "Stage: $Stage",
    "Entity: $($EntityType.ToUpper()) #$EntityNumber",
    "Owner: @$Owner",
    "Evidence: $EvidenceUrl",
    "Next action: $NextAction"
  )
}

Write-JsonOutput -Data $payload -Path $OutputPath
$payload | ConvertTo-Json -Depth 10 | Write-Output
