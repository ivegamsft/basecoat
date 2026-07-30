#Requires -Version 7.0
<#
.SYNOPSIS
    Landing gate for the autopilot: backlog delivery loop. Turns the declared
    merge posture in autopilot.config.json into a concrete, testable decision.

.DESCRIPTION
    The autopilot advertises a serialized, conflict-free landing lane. This gate
    is what actually consumes the `merge` block of autopilot.config.json so the
    posture is enforced instead of merely declared:

      - serialize_merges / max_in_flight_merges bound how many autopilot PRs may
        be mid-landing at once (default: one). Given the current in-flight count
        the gate reports whether the next PR may be armed.

      - prefer_native_merge_queue picks the landing path: when the target branch
        has a GitHub-native merge queue configured (-HasNativeMergeQueue) the
        gate selects "native-merge-queue". Otherwise, because
        pr-auto-merge-executor blocks auto-merge under `required` posture, the
        gate reports a policy block ("blocked-native-queue-required",
        can_arm=false) so the loop escalates instead of attempting a forbidden
        auto-merge. Enabling the native queue is an org/branch-protection setting
        the agent does not mutate (see docs/design/backlog-autopilot-intent.md,
        Out of Scope). A non-required posture keeps the plain serialized
        auto-merge path.

      - require_green_checks is surfaced so the caller never force-merges red.

    Emits a JSON decision; no side effects. -InFlightCount is mandatory and
    range-validated: the caller must supply the current validated count of
    autopilot PRs already mid-landing so the serialization guardrail cannot be
    silently defeated by a permissive default.

.NOTES
    Part of the backlog-autopilot agent. See docs/design/backlog-autopilot-intent.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$InFlightCount,
    [switch]$HasNativeMergeQueue,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "autopilot.config.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConfigPath)) {
    throw "Missing autopilot config: $ConfigPath"
}
$merge = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).merge

$maxInFlight = if ($merge.serialize_merges) {
    1
} elseif ($merge.max_in_flight_merges -and [int]$merge.max_in_flight_merges -gt 0) {
    [int]$merge.max_in_flight_merges
} else {
    1
}

$canArm = ($InFlightCount -lt $maxInFlight)

$posture = "$($merge.merge_queue_posture)"
$policyBlock = $false
if ($HasNativeMergeQueue -and $merge.prefer_native_merge_queue) {
    $landing = "native-merge-queue"
} elseif ($posture -eq "required") {
    # pr-auto-merge-executor blocks auto-merge under `required` posture (it
    # defers to the branch merge queue). With no native queue configured the
    # lane cannot land unattended, so this is a policy block to escalate rather
    # than a fallback the executor would reject.
    $landing = "blocked-native-queue-required"
    $policyBlock = $true
} else {
    $landing = "serialized-auto-merge"
}

if ($policyBlock) { $canArm = $false }

$decision = [ordered]@{
    posture              = $posture
    landing              = $landing
    policy_block         = $policyBlock
    serialize_merges     = [bool]$merge.serialize_merges
    max_in_flight        = $maxInFlight
    in_flight            = $InFlightCount
    can_arm              = $canArm
    require_green_checks = [bool]$merge.require_green_checks
}

[pscustomobject]$decision | ConvertTo-Json -Depth 4

exit 0
