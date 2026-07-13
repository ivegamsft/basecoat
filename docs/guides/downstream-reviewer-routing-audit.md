# Downstream Reviewer-Routing Audit

This guide covers the fleet loop for detecting reviewer-routing failures across BaseCoat consumer repositories.

- Workflow: `.github/workflows/downstream-reviewer-routing-audit.yml`
- Opt-in registry: `.github/downstream-reviewer-routing-targets.json`
- Companion loop: `.github/workflows/post-onboarding-drift-loop.yml` for full post-onboarding drift detection (branch/ruleset, intake, reviewer-routing, metadata hygiene) plus remediation issue dedupe and trend scorecards.

## What the audit checks

For each opted-in repo, the audit evaluates non-draft open PRs and classifies routing health into one of these states:

1. `downstream repo inaccessible (audit could not be evaluated)`
2. `no reviewer-routing automation installed`
3. `automation installed but not configured`
4. `automation configured but ineffective in live PRs`
5. `healthy`

The audit scorecard also reports:

- Ready PR count
- Ready PRs with no requested reviewers
- PRs in `BEHIND` or `DIRTY` mergeable state with no requested reviewers
- Reviewer-routing workflow runs in the last 30 days
- Detected routing workflow files

## How repositories opt in

1. Edit `.github/downstream-reviewer-routing-targets.json`.
2. Add a repository entry with `owner/repo` and `"enabled": true`.
3. Merge to `main`.

Example:

```json
{
  "repo": "IBuySpy-Dev/example-repo",
  "enabled": true
}
```

## Run the audit manually

```bash
gh workflow run downstream-reviewer-routing-audit.yml
gh run watch --workflow downstream-reviewer-routing-audit.yml
```

Optional: override targets at dispatch time:

```bash
gh workflow run downstream-reviewer-routing-audit.yml \
  --field repositories="IBuySpy-Dev/work-tracker,IBuySpy-Dev/luxesite" \
  --field ineffective_threshold=5
```

## Remediation playbook by state

### downstream repo inaccessible (audit could not be evaluated)

1. Confirm the audit token can read the repository (open pull requests could not be listed).
2. Check for a transient GitHub API error or rate limiting and re-run.
3. If the repo was removed or made private, update the target registry.

### no reviewer-routing automation installed

1. Add reviewer-routing workflows in the consumer repo:
   - `.github/workflows/reviewer-autoassign.yml`
   - `.github/workflows/pr-flow-hygiene.yml`
2. Confirm both workflows are enabled in Actions.
3. Re-run the audit.

### automation installed but not configured

1. Verify workflows are enabled and not disabled by repo/org policy.
2. Trigger each workflow manually once.
3. Confirm workflow runs appear in the last 30 days.
4. Re-run the audit.

### automation configured but ineffective in live PRs

1. Inspect open non-draft PRs with no requested reviewers.
2. Verify reviewer eligibility/collaborator access for the repo.
3. Confirm `pull_request_target` triggers and permissions are intact.
4. Review `pr-flow-hygiene` comments for readiness blockers (`pr-readiness-blocked`, BEHIND, owner/release label gaps).
5. Re-run the audit and verify the scorecard drops below threshold.
