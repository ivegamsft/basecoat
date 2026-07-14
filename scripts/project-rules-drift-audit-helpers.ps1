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

        # Note: condition/action drift detection is deferred.
        # The GraphQL response shape (triggers[]/actions[]) differs from the baseline manifest
        # shape (condition{}/action{}), so a raw JSON comparison produces false positives on
        # every rule. Deep normalization is tracked as a future enhancement.
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
