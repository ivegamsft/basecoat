[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\auto-approve-cloud-agent-workflows.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\auto-approve-cloud-agent-workflows.yml'

if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}
if (-not (Test-Path $templatePath)) {
    throw "Missing template workflow file: $templatePath"
}

$files = @(
    @{ Name = '.github/workflows/auto-approve-cloud-agent-workflows.yml'; Content = (Get-Content -Path $workflowPath -Raw) },
    @{ Name = '.github/base-coat/workflows/auto-approve-cloud-agent-workflows.yml'; Content = (Get-Content -Path $templatePath -Raw) }
)

foreach ($entry in $files) {
    $name = $entry.Name
    $content = $entry.Content

    $jobMarker = 'auto-retrigger-merge-eligibility-review-race:'
    $jobIndex = $content.IndexOf($jobMarker)
    if ($jobIndex -lt 0) {
        throw "${name}: must define the auto-retrigger-merge-eligibility-review-race job."
    }
    $reDispatchJobContent = $content.Substring($jobIndex)
    $topLevelTriggerContent = $content.Substring(0, $jobIndex)

    # --- top-level trigger contract: must listen for the finalized workflow_run
    # completion, not "requested" (which fires before status/conclusion settle
    # and would leave a still-blocked action_required run with no later event
    # to retry against). ---
    if ($topLevelTriggerContent -notmatch 'workflow_run:\s*\r?\n(\s*#[^\r\n]*\r?\n)*\s*workflows:\s*\[[^\]]*"BaseCoat - PR Auto Merge Executor"[^\]]*\]\s*\r?\n(\s*#[^\r\n]*\r?\n)*\s*types:\s*\[completed\]') {
        throw "${name}: workflow_run trigger must watch 'BaseCoat - PR Auto Merge Executor' with types: [completed], not [requested]."
    }
    if ($topLevelTriggerContent -match 'workflow_run:(?:(?!\r?\n\S).)*types:\s*\[requested\]') {
        throw "${name}: workflow_run trigger must not use types: [requested] -- that fires before the run's terminal action_required conclusion is set."
    }

    # --- the template copy must also watch the downstream-installed executor's
    # renamed workflow (scripts/configure-downstream-workflows.ps1 renames
    # pr-auto-merge-executor.yml's `name:` to "BaseCoat Template - PR Auto
    # Merge Executor" when installed), or its workflow_run filter would never
    # match downstream. The in-repo runtime copy never sees a renamed
    # executor, so this only applies to the template file. ---
    if ($name -like '*base-coat*' -and $topLevelTriggerContent -notmatch 'workflows:\s*\[[^\]]*"BaseCoat Template - PR Auto Merge Executor"[^\]]*\]') {
        throw "${name}: template's workflow_run filter must also include 'BaseCoat Template - PR Auto Merge Executor' to match the downstream-installed executor's renamed workflow."
    }

    # --- auto-approve-workflows job: restricted to app/copilot-swe-agent ---
    if ($content -notmatch "auto-approve-workflows:\s*\r?\n\s*if:\s*github\.actor == 'app/copilot-swe-agent'") {
        throw "${name}: auto-approve-workflows job must remain gated on github.actor == 'app/copilot-swe-agent'."
    }

    # --- both jobs' checkouts must pin the default branch, so a PR can never
    # get this auto-approval gate to trust a PR-modified copy of
    # .github/governance/policy-packs.json ---
    $checkoutSections = $content -split '(?=- name: Checkout repository)' | Where-Object { $_ -match 'Checkout repository' }
    if ($checkoutSections.Count -lt 2) {
        throw "${name}: expected two 'Checkout repository' steps (one per job)."
    }
    foreach ($section in $checkoutSections) {
        $nextStepIndex = $section.IndexOf("`n      - name:", 1)
        $block = if ($nextStepIndex -ge 0) { $section.Substring(0, $nextStepIndex) } else { $section }
        if ($block -notmatch 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}') {
            throw "${name}: every checkout that precedes a policy-packs.json read must pin ref: `${{ github.event.repository.default_branch }}` so a PR cannot supply its own governance policy."
        }
    }

    # --- re-dispatch job: must only trigger via workflow_run ---
    if ($reDispatchJobContent -notmatch "if:\s*github\.event_name == 'workflow_run'") {
        throw "${name}: re-dispatch job must be gated on github.event_name == 'workflow_run'."
    }

    # --- must restrict to the exact copilot-pull-request-reviewer review-race scenario ---
    if ($reDispatchJobContent -notmatch "run\.event !== 'pull_request_review'") {
        throw "${name}: re-dispatch script must check run.event === 'pull_request_review' before acting."
    }
    if ($reDispatchJobContent -notmatch 'copilotReviewerActorId\s*=\s*175728472') {
        throw "${name}: re-dispatch script must pin the immutable copilot-pull-request-reviewer[bot] actor ID (175728472)."
    }
    if ($reDispatchJobContent -notmatch 'triggering_actor\?\.id\s*!==\s*copilotReviewerActorId') {
        throw "${name}: re-dispatch script must compare triggering_actor.id against the pinned Copilot reviewer actor ID."
    }

    # --- must use createWorkflowDispatch, not approveWorkflowRun (proven non-functional for this scenario) ---
    if ($reDispatchJobContent -match 'approveWorkflowRun') {
        throw "${name}: re-dispatch job must not call approveWorkflowRun -- verified via the live GitHub API that it 403s for same-repo actor-gated runs ('This run is not from a fork pull request or queued by the Actions bot')."
    }
    if ($reDispatchJobContent -notmatch 'createWorkflowDispatch') {
        throw "${name}: re-dispatch job must call createWorkflowDispatch to unblock the stuck run."
    }
    if ($name -like '*base-coat*') {
        if ($reDispatchJobContent -notmatch "workflow_id:\s*'basecoat-pr-auto-merge-executor\.yml'") {
            throw "${name}: template re-dispatch job must target basecoat-pr-auto-merge-executor.yml -- the filename the downstream installer actually writes (scripts/configure-downstream-workflows.ps1)."
        }
    } else {
        if ($reDispatchJobContent -notmatch "workflow_id:\s*'pr-auto-merge-executor\.yml'") {
            throw "${name}: re-dispatch job must target pr-auto-merge-executor.yml."
        }
    }
    if ($reDispatchJobContent -notmatch 'inputs:\s*\{\s*pr_number:') {
        throw "${name}: re-dispatch job must pass the blocked run's PR number as the pr_number input."
    }

    # --- must gate action_required detection so it doesn't act on unrelated run states ---
    if ($reDispatchJobContent -notmatch "run\.status !== 'action_required' && run\.conclusion !== 'action_required'") {
        throw "${name}: re-dispatch script must verify the run is actually action_required before dispatching."
    }

    # --- must respect the cloud_agent.auto_approve_workflow_runs policy-pack flag ---
    if ($reDispatchJobContent -notmatch 'cloud_agent\.auto_approve_workflow_runs') {
        throw "${name}: must gate on the cloud_agent.auto_approve_workflow_runs policy-pack flag."
    }

    # --- must not silently swallow missing PR number ---
    if ($reDispatchJobContent -notmatch 'cannot re-dispatch') {
        throw "${name}: re-dispatch script must log and skip (not throw) when no PR number is resolvable."
    }

    # --- run.pull_requests is not guaranteed populated (e.g. review-triggered
    # events); must fall back to resolving the PR from the run's head commit ---
    if ($reDispatchJobContent -notmatch 'listPullRequestsAssociatedWithCommit') {
        throw "${name}: re-dispatch script must fall back to listPullRequestsAssociatedWithCommit when run.pull_requests is empty."
    }
    if ($reDispatchJobContent -notmatch 'commit_sha:\s*run\.head_sha') {
        throw "${name}: fallback PR lookup must query by run.head_sha."
    }
    $jobHeaderContent = ($reDispatchJobContent -split '(?s)steps:')[0]
    if ($jobHeaderContent -notmatch 'pull-requests:\s*read') {
        throw "${name}: re-dispatch job must declare pull-requests: read permission for the listPullRequestsAssociatedWithCommit fallback."
    }
}

if ($files[0].Content -ne $files[1].Content) {
    $jobMarker = 'auto-retrigger-merge-eligibility-review-race:'
    $bodies = $files | ForEach-Object {
        $body = $_.Content.Substring($_.Content.IndexOf($jobMarker))
        # Normalize the two other intentional divergences: the workflow_id the
        # template dispatches (installed filename) vs. the runtime's own filename,
        # and any comment-only lines explaining that divergence.
        $body = $body -replace "workflow_id:\s*'(?:pr-auto-merge-executor|basecoat-pr-auto-merge-executor)\.yml'", "workflow_id: '<normalized>'"
        ($body -split "\r?\n" | Where-Object { $_.TrimStart() -notmatch '^(#|//)' }) -join "`n"
    }
    if ($bodies[0] -ne $bodies[1]) {
        throw 'auto-approve-cloud-agent-workflows.yml and its base-coat template copy must be identical below the workflow_run trigger (aside from the workflows: name list, the dispatched workflow_id filename, and explanatory comments, which intentionally differ to account for the downstream-renamed executor).'
    }
}


Write-Host 'Auto-approve cloud-agent workflows tests passed.'
