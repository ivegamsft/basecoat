function Get-DriftTypeSummary {
    param([object]$Findings)

    # @() guards keep .Count valid under Set-StrictMode when a drift type has zero matches.
    return [ordered]@{
        missing  = @($Findings | Where-Object drift_type -eq 'missing').Count
        modified = @($Findings | Where-Object drift_type -eq 'modified').Count
        extra    = @($Findings | Where-Object drift_type -eq 'extra').Count
    }
}

function Get-DriftOutcome {
    # Maps per-severity finding counts to the overall audit outcome defined in
    # docs/specs/aidl-portfolio/sprint-41/portfolio-drift-detection-rules.md section 2a:
    #   any critical or high finding -> fail
    #   any medium or low finding (no critical/high) -> warn
    #   no findings -> pass
    param([hashtable]$Summary)

    $critical = if ($Summary.ContainsKey('critical')) { [int]$Summary['critical'] } else { 0 }
    $high = if ($Summary.ContainsKey('high')) { [int]$Summary['high'] } else { 0 }
    $medium = if ($Summary.ContainsKey('medium')) { [int]$Summary['medium'] } else { 0 }
    $low = if ($Summary.ContainsKey('low')) { [int]$Summary['low'] } else { 0 }

    if ($critical -gt 0 -or $high -gt 0) { return 'fail' }
    if ($medium -gt 0 -or $low -gt 0) { return 'warn' }
    return 'pass'
}

function Get-BaselineConditionSignature {
    param([object]$Condition)
    if (-not $Condition) { return $null }
    switch ($Condition.type) {
        'pull_request_event' { return "pull_request:$($Condition.event)" }
        'issue_event' { return "issue:$($Condition.event)" }
        'field_value_change' { return "field_value:$($Condition.field)=$($Condition.value)" }
        'label_added' { return "label_added:$($Condition.label_prefix)" }
        'item_added_to_project' { return 'item_added' }
        default { return "unknown:$($Condition.type)" }
    }
}

function Get-BaselineActionSignature {
    param([object]$Action)
    if (-not $Action) { return $null }
    switch ($Action.type) {
        'set_field' { return "set_field:$($Action.field)=$($Action.value)" }
        'archive_item' { return 'archive' }
        'add_to_project' { return 'add_to_project' }
        default { return "unknown:$($Action.type)" }
    }
}

function Test-ConditionSignatureMatch {
    param(
        [object]$Condition,
        [string]$ExpectedSignature,
        [array]$LiveSignatures
    )
    # label_added baseline conditions declare a label *prefix* (e.g. "sprint:"),
    # not an exact label name, so the baseline signature ("label_added:sprint:")
    # and a live signature built from an actual applied label ("label_added:sprint:42")
    # are expected to differ. Match by prefix for this condition type; every
    # other condition type still requires an exact signature match.
    if ($Condition -and $Condition.type -eq 'label_added') {
        $prefix = "label_added:$($Condition.label_prefix)"
        return [bool]($LiveSignatures | Where-Object { $_.StartsWith($prefix) } | Select-Object -First 1)
    }
    return $LiveSignatures -contains $ExpectedSignature
}

function Get-OptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$Name
    )
    # GraphQL union-typed objects (trigger/action variants) only carry the
    # fields belonging to whichever concrete variant was returned; fields
    # from other variants are entirely absent from the object, not merely
    # $null. Under this script's Set-StrictMode -Version Latest, a direct
    # `$obj.SomeAbsentField` access throws PropertyNotFoundException instead
    # of returning $null, so every optional union field must be looked up
    # via PSObject.Properties first.
    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-LiveTriggerSignature {
    param([object]$Trigger)
    if (-not $Trigger) { return 'unknown' }
    $pullRequestEvent = Get-OptionalPropertyValue -InputObject $Trigger -Name 'pullRequestEvent'
    if ($null -ne $pullRequestEvent) { return "pull_request:$pullRequestEvent" }
    $issueEvent = Get-OptionalPropertyValue -InputObject $Trigger -Name 'issueEvent'
    if ($null -ne $issueEvent) { return "issue:$issueEvent" }
    $field = Get-OptionalPropertyValue -InputObject $Trigger -Name 'field'
    if ($null -ne $field) {
        $fieldName = Get-OptionalPropertyValue -InputObject $field -Name 'name'
        $value = Get-OptionalPropertyValue -InputObject $Trigger -Name 'value'
        return "field_value:$fieldName=$value"
    }
    $label = Get-OptionalPropertyValue -InputObject $Trigger -Name 'label'
    if ($null -ne $label) {
        $labelName = Get-OptionalPropertyValue -InputObject $label -Name 'name'
        return "label_added:$labelName"
    }
    $addWhen = Get-OptionalPropertyValue -InputObject $Trigger -Name 'addWhen'
    if ($null -ne $addWhen) { return 'item_added' }
    $archiveWhen = Get-OptionalPropertyValue -InputObject $Trigger -Name 'archiveWhen'
    if ($null -ne $archiveWhen) { return "archive_trigger:$archiveWhen" }
    $type = Get-OptionalPropertyValue -InputObject $Trigger -Name 'type'
    return "unknown:$type"
}

function Get-LiveActionSignature {
    param([object]$Action)
    if (-not $Action) { return 'unknown' }
    $field = Get-OptionalPropertyValue -InputObject $Action -Name 'field'
    if ($null -ne $field) {
        $fieldName = Get-OptionalPropertyValue -InputObject $field -Name 'name'
        $value = Get-OptionalPropertyValue -InputObject $Action -Name 'value'
        return "set_field:$fieldName=$value"
    }
    $archived = Get-OptionalPropertyValue -InputObject $Action -Name 'archived'
    if ($null -ne $archived) { return 'archive' }
    if ($Action.PSObject.Properties.Name -contains 'dummy') { return 'add_to_project' }
    $type = Get-OptionalPropertyValue -InputObject $Action -Name 'type'
    return "unknown:$type"
}

function Compare-Rules {
    param(
        [array]$BaselineRules,
        [object]$LiveProject
    )

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
    $liveWorkflows = if ($LiveProject.workflows.nodes) { $LiveProject.workflows.nodes } else { @() }

    foreach ($rule in $BaselineRules) {
        $matched = $liveWorkflows | Where-Object { $_.name -ieq $rule.name } | Select-Object -First 1

        if (-not $matched) {
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-missing"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'missing'
                severity       = $rule.severity_if_missing
                baseline_value = @{
                    enabled   = $rule.enabled
                    condition = $rule.condition
                    action    = $rule.action
                }
                live_value     = $null
                remediation    = "Add automation rule '$($rule.name)'. Condition: $($rule.condition | ConvertTo-Json -Compress). Action: $($rule.action | ConvertTo-Json -Compress)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
            continue
        }

        # Check enabled state drift — use severity_if_missing when a required rule is disabled
        if ($rule.enabled -ne $matched.enabled) {
            $enabledSeverity = if ($rule.enabled -and -not $matched.enabled) {
                $rule.severity_if_missing
            } else {
                'medium'
            }
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-modified-enabled"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'modified'
                severity       = $enabledSeverity
                baseline_value = @{ enabled = $rule.enabled }
                live_value     = @{ enabled = $matched.enabled }
                remediation    = "Set rule '$($rule.name)' enabled=$($rule.enabled)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
        }

        # Check condition/action drift: compare the baseline's declarative
        # condition/action shape against the live workflow's GraphQL
        # triggers[]/actions[] shape (using the type-specific field group each
        # union member carries, since the schemas differ structurally). This
        # catches a rule silently redirected to a different event/field while
        # still reporting enabled=true, which name/enabled comparison alone
        # would miss.
        $expectedConditionSignature = Get-BaselineConditionSignature $rule.condition
        $expectedActionSignature = Get-BaselineActionSignature $rule.action
        $liveTriggers = if ($matched.triggers) { @($matched.triggers) } else { @() }
        $liveActions = if ($matched.actions) { @($matched.actions) } else { @() }
        $liveTriggerSignatures = @($liveTriggers | ForEach-Object { Get-LiveTriggerSignature $_ })
        $liveActionSignatures = @($liveActions | ForEach-Object { Get-LiveActionSignature $_ })

        if ($expectedConditionSignature -and (-not (Test-ConditionSignatureMatch -Condition $rule.condition -ExpectedSignature $expectedConditionSignature -LiveSignatures $liveTriggerSignatures))) {
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-modified-condition"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'modified'
                # skills/project-rules-drift-audit/SKILL.md:57 classifies
                # "Condition or action deviates from baseline" as `high`
                # severity unconditionally -- it is not scaled by the rule's
                # own severity_if_missing (which governs the *absent* case,
                # not the *deviated* case). Using severity_if_missing here
                # let a low/medium-severity baseline rule produce a
                # non-blocking condition-drift finding, contrary to the
                # documented contract.
                severity       = 'high'
                baseline_value = @{ condition = $rule.condition }
                live_value     = @{ triggers = $liveTriggerSignatures }
                remediation    = "Restore rule '$($rule.name)' trigger to match the baseline condition: $($rule.condition | ConvertTo-Json -Compress)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
        }

        if ($expectedActionSignature -and ($liveActionSignatures -notcontains $expectedActionSignature)) {
            $findings.Add([PSCustomObject]@{
                finding_id     = "$($rule.rule_id)-modified-action"
                rule_id        = $rule.rule_id
                rule_name      = $rule.name
                drift_type     = 'modified'
                # See the modified-condition finding above: SKILL.md:57 fixes
                # this at `high` regardless of severity_if_missing.
                severity       = 'high'
                baseline_value = @{ action = $rule.action }
                live_value     = @{ actions = $liveActionSignatures }
                remediation    = "Restore rule '$($rule.name)' action to match the baseline: $($rule.action | ConvertTo-Json -Compress)."
                effort         = 'minutes'
                rationale      = $rule.rationale
            })
        }
    }

    # Report extra rules not in baseline — use unique rule_id per extra rule for determinism
    foreach ($liveRule in $liveWorkflows) {
        $inBaseline = $BaselineRules | Where-Object { $_.name -ieq $liveRule.name }
        if (-not $inBaseline) {
            $safeRuleId = "EXTRA-$($liveRule.name -replace '[^a-zA-Z0-9]', '-')"
            $findings.Add([PSCustomObject]@{
                finding_id     = "$safeRuleId-extra"
                rule_id        = $safeRuleId
                rule_name      = $liveRule.name
                drift_type     = 'extra'
                severity       = 'low'
                baseline_value = $null
                live_value     = @{
                    enabled = $liveRule.enabled
                    name    = $liveRule.name
                }
                remediation    = "Rule '$($liveRule.name)' is not in the baseline. Review and either add it to the baseline or remove it from the project."
                effort         = 'minutes'
                rationale      = 'Extra rules outside the guardrail baseline may introduce unintended board behavior.'
            })
        }
    }

    return $findings
}
