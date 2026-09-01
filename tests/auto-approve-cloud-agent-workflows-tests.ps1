$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github\workflows\auto-approve-cloud-agent-workflows.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\auto-approve-cloud-agent-workflows.yml'

foreach ($path in @($workflowPath, $templatePath)) {
    if (-not (Test-Path $path)) {
        throw "Missing workflow file: $path"
    }
}

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$runtime = Get-Content $workflowPath -Raw
$template = Get-Content $templatePath -Raw

foreach ($entry in @(
        @{ Name = '.github/workflows/auto-approve-cloud-agent-workflows.yml'; Content = $runtime; WorkflowId = 'pr-auto-merge-executor.yml'; ReviewWorkflow = 'code-review-agent'; ReviewWorkflowFile = 'code-review-agent.lock.yml' },
        @{ Name = '.github/base-coat/workflows/auto-approve-cloud-agent-workflows.yml'; Content = $template; WorkflowId = 'basecoat-pr-auto-merge-executor.yml'; ReviewWorkflow = 'BaseCoat Agent Template - Code Review'; ReviewWorkflowFile = 'basecoat-agent-code-review.yml' }
    )) {
    $name = $entry.Name
    $content = $entry.Content

    Assert-Match $content 'pull_request_target:\s*\r?\n\s*types:\s*\[opened,\s*reopened,\s*synchronize\]' "$name must retain trusted pull_request_target auto-approval."
    Assert-Match $content "if:\s*github\.event_name == 'pull_request_target'\s*&&\s*github\.event\.pull_request\.user\.id == 198982749" "$name must gate auto-approval on the stable Copilot cloud-agent author ID."
    Assert-Match $content 'cancel-in-progress:\s*true' "$name must cancel superseded approval work."
    Assert-Match $content 'const headSha = await getCurrentHeadSha\(\)' "$name must select runs against the live pull request head."
    Assert-Match $content 'run\.head_sha === headSha' "$name must filter approval candidates to the current head."
    Assert-Match $content 'const currentHeadSha = await getCurrentHeadSha\(\)' "$name must revalidate the head before approving each run."
    Assert-Match $content 'if \(currentHeadSha !== headSha\)' "$name must stop approval when the pull request advances."
    Assert-Match $content 'github\.paginate\(github\.rest\.actions\.listWorkflowRunsForRepo' "$name must paginate requested workflow runs."
    Assert-Match $content 'new Map\(' "$name must de-duplicate requested workflow runs."
    Assert-Match $content 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}' "$name must load governance only from the trusted default branch."
    Assert-Match $content "if:\s*steps\.policy-pack\.outputs\.auto_approve != 'true'" "$name must record an explicit policy-pack approval skip."
    Assert-Match $content ("workflow_run:\s*\r?\n(?:\s*#[^\r\n]*\r?\n)*\s*workflows:\s*\[" + [regex]::Escape('"' + $entry.ReviewWorkflow + '"') + "\]\s*\r?\n\s*types:\s*\[completed\]") "$name must react to completed installed code-review workflow runs."
    if ($content -match 'BaseCoat (Template - )?PR Auto Merge Executor') {
        throw "$name must not trigger on PR Auto Merge Executor workflow_run events; the unprivileged review actor makes those runs action_required."
    }
    Assert-Match $content 're-evaluate-after-automated-review:' "$name missing post-review eligibility dispatch job."
    Assert-Match $content "if:\s*github\.event_name == 'workflow_run'" "$name must limit post-review dispatch to workflow_run events."
    $postReviewJob = ($content -split 're-evaluate-after-automated-review:', 2)[1]
    Assert-Match $postReviewJob 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}' "$name must load post-review governance only from the trusted default branch."
    Assert-Match $content 're-evaluate-after-automated-review:[\s\S]*?timeout-minutes:\s*7' "$name must allow the review poll to complete cleanly."
    Assert-Match $content "if:\s*steps\.policy-pack\.outputs\.auto_approve == 'true'" "$name must honor the cloud-agent auto-approval policy gate."
    Assert-Match $content 'jq -r --arg p' "$name must use the policy pack as a jq argument, not interpolate it into a filter."
    Assert-Match $content 'jq -c --arg p' "$name must safely load automated-review policy."
    Assert-Match $content "run\.conclusion !== 'success'" "$name must dispatch eligibility evaluation only after a successful automated review."
    Assert-Match $content ([regex]::Escape("workflow_id: '$($entry.ReviewWorkflowFile)'")) "$name must resolve the trusted installed review workflow by file."
    Assert-Match $content 'run\.workflow_id !== trustedReviewWorkflow\.id' "$name must reject same-name workflow runs that do not match the trusted workflow ID."
    Assert-Match $content 'run\.pull_requests\?\.?\[0\]\?\.number' "$name must require an associated pull request."
    Assert-Match $content "pullRequest\.state !== 'open' \|\| pullRequest\.head\.sha !== run\.head_sha" "$name must skip closed or stale-head pull requests."
    Assert-Match $content 'github\.rest\.pulls\.listReviews' "$name must poll for the required current-head automated review."
    Assert-Match $content 'for \(let attempt = 1; attempt <= 20; attempt \+= 1\)' "$name must retry review observation to avoid an unordered-review race."
    Assert-Match $content 'reviewObserved \|\| attempt === 20' "$name must not sleep after the final review poll."
    Assert-Match $content 'review\.commit_id === run\.head_sha' "$name must require review evidence for the reviewed head."
    Assert-Match $content 'accepted_states \|\| \[\]\)\.map\(state => String\(state\)\.toUpperCase\(\)\)' "$name must normalize configured accepted review states."
    Assert-Match $content "states\.has\(String\(review\.state \|\| ''\)\.toUpperCase\(\)\)" "$name must compare GitHub review states case-insensitively."
    Assert-Match $content 'Required automated-review policy must define reviewer_logins and accepted_states' "$name must fail explicitly when required automated-review policy evidence is incomplete."
    Assert-Match $content 'github\.rest\.actions\.createWorkflowDispatch' "$name must dispatch the merge eligibility workflow."
    Assert-Match $content ([regex]::Escape("workflow_id: '$($entry.WorkflowId)'")) "$name must dispatch the correct installed merge eligibility workflow."
    Assert-Match $content 'schedule:\s*\r?\n\s*-\s*cron:\s*"?\*/15 \* \* \* \*"?' "$name must periodically reconcile later human-review changes from a trusted default-branch run."
    Assert-Match $content 'reconcile-open-auto-merge-pull-requests:' "$name missing scheduled auto-merge reconciliation."
    Assert-Match $content "if:\s*github\.event_name == 'schedule'" "$name must limit scheduled reconciliation to schedule events."
    Assert-Match $content 'main\.reconcile_merge_eligibility // false' "$name must load a reconciliation policy distinct from workflow-run auto-approval."
    Assert-Match $content "reconcile-open-auto-merge-pull-requests:[\s\S]*?if:\s*steps\.policy-pack\.outputs\.reconcile == 'true'" "$name must apply the dedicated governance policy gate to scheduled reconciliation."
    if ($content -match 'github\.graphql') {
        throw "$name must not use GitHub GraphQL for scheduled reconciliation; GITHUB_TOKEN cannot read every requested field there."
    }
    Assert-Match $content 'github\.paginate\(github\.rest\.pulls\.list' "$name must page through open pull requests with REST."
    Assert-Match $content "base:\s*defaultBranch" "$name must limit scheduled reconciliation to the protected default branch."
    Assert-Match $content 'github\.paginate\(github\.rest\.pulls\.listReviews' "$name must inspect review evidence with REST."
    if ($content -match 'getCombinedStatusForRef') {
        throw "$name must not use combined status for reconciliation; it collapses the status timeline and weakens the watermark."
    }
    Assert-Match $content 'github\.paginate\(github\.rest\.repos\.listCommitStatusesForRef' "$name must inspect merge eligibility status timeline with REST."
    Assert-Match $content "status\.context === 'BaseCoat merge eligibility'" "$name must inspect the latest merge eligibility watermark."
    Assert-Match $content 'new Date\(right\.created_at\) - new Date\(left\.created_at\)' "$name must use REST status timestamps when ordering merge eligibility statuses."
    Assert-Match $content 'new Date\(latestReview\.submitted_at \|\| latestReview\.created_at\) <=' "$name must skip reconciliation when review evidence has already been evaluated."
}

function Get-NormalizedDispatchJob {
    param([string]$Content)

    $job = ($Content -split 're-evaluate-after-automated-review:', 2)[1]
    $job = $job -replace "workflow_id: '(?:pr-auto-merge-executor|basecoat-pr-auto-merge-executor)\.yml'", "workflow_id: '<normalized>'"
    $job = $job -replace "workflow_id: '(?:code-review-agent\.lock|basecoat-agent-code-review)\.yml'", "workflow_id: '<review-normalized>'"
    return (($job -split "\r?\n" | Where-Object { $_.TrimStart() -notmatch '^(#|//)' }) -join "`n")
}

if ((Get-NormalizedDispatchJob $runtime) -ne (Get-NormalizedDispatchJob $template)) {
    throw 'Runtime and template post-review dispatch jobs must remain equivalent except for the installed executor filename and comments.'
}

Write-Host 'Auto-approve cloud-agent workflows tests passed.'
