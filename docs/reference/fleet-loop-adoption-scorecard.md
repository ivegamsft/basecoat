# Fleet Loop Adoption Scorecard

This document records the findings of the BaseCoat fleet audit. `basecoat` serves as
the baseline reference; `work-tracker`, `gh-devops-runners`, and `luxesite` are the
downstream consumer repositories evaluated against it. It exists so audit findings are
reusable guidance for future rollouts rather than session-trapped history.

- Audit scope: `basecoat`, `work-tracker`, `gh-devops-runners`, `luxesite`
- Tracking issue: [#1827](https://github.com/ivegamsft/basecoat/issues/1827)
- Follow-on automation issue: [#1828](https://github.com/ivegamsft/basecoat/issues/1828)
- Companion audit guide: `docs/guides/downstream-reviewer-routing-audit.md`

---

## Summary

The audit found a consistent pattern: downstream repos have broadly adopted BaseCoat
instruction and agent surfaces. Automated loops are real and active. The gap is not in
tooling deployment; it is in human-review governance closing the loop that automation
opens.

| Dimension | Fleet-Wide Finding |
|---|---|
| Instruction/agent surface adoption | Broad; all four repos carry BaseCoat assets |
| Cron/hook/agent loop activity | Real and active across triage, remediation, CI hygiene, compliance |
| Human-review governance | Weaker than documented intent in all four repos |
| Reviewer-request closure | Most consistent gap across the fleet |
| Intake surface presence | Present but drifting from BaseCoat defaults in two repos |
| Label and priority normalization | Active drift downstream; legacy labels persist |
| Local Copilot session usage | Clusters around unblock/recovery, not proactive governance closure |

---

## Repo-by-Repo Scorecard

### basecoat

| Dimension | Policy | Implementation | Live Behavior |
|---|---|---|---|
| Reviewer-routing automation | Required | Installed: `reviewer-autoassign.yml`, `pr-flow-hygiene.yml` | Active; no open PRs with unrouted ready state detected |
| Intake surface | Required (PR template + issue template) | Present; `.github/PULL_REQUEST_TEMPLATE.md` and `.github/ISSUE_TEMPLATE/` exist | Compliant |
| Label/priority normalization | Canonical taxonomy enforced by triage agent | Triage agent runs on open event | Recent labels normalized; legacy labels present in older closed issues |
| Branch/merge governance | PR-only to `main`; branch protection enabled | Enforced via ruleset | Compliant; direct-to-main pushes blocked |
| Cron loop activity | Expected: triage, compliance, sprint hygiene | Scheduled workflows active in `.github/workflows/` | Active; runs confirmed in Actions history |
| Session usage pattern | Proactive governance and sprint execution | Mix of sprint execution and reactive unblock sessions | Session cadence leans reactive during high-backlog periods |

**Status: Healthy baseline, minor label debt.**

---

### work-tracker

| Dimension | Policy | Implementation | Live Behavior |
|---|---|---|---|
| Reviewer-routing automation | Required per BaseCoat contract | Installed | Configured but classified as `automation configured but ineffective in live PRs` at last audit run |
| Intake surface | Required | PR template present; issue template minimal | Intake surface below BaseCoat minimum: issue template does not include `priority` field |
| Label/priority normalization | Expected to track BaseCoat canonical taxonomy | Legacy `P0/P1/P2/P3` labels in active use; `priority:*` not fully adopted | Drift confirmed; triage agent creates `priority:*` labels but legacy labels co-exist |
| Branch/merge governance | PR-only; branch protection expected | Branch protection rules installed | One direct-to-main event detected in audit window; traced to admin override |
| Cron loop activity | Expected: capacity tracking, compliance | Capacity and remediation loops active | Active; sprint hygiene loop firing on schedule |
| Session usage pattern | Proactive governance | Sessions primarily used to unblock stalled PRs and resolve CI failures | Recovery-oriented; governance closure sessions rare |

**Status: Reviewer-routing gap. Label drift. Intake surface below minimum.**

Remediation:

1. Follow `docs/guides/downstream-reviewer-routing-audit.md` remediation playbook for `automation configured but ineffective` state.
2. Normalize intake issue template to include `priority` field per BaseCoat contract.
3. Run `gh label create` to add canonical `priority:*` labels and update triage agent configuration to stop emitting legacy labels.

---

### gh-devops-runners

| Dimension | Policy | Implementation | Live Behavior |
|---|---|---|---|
| Reviewer-routing automation | Required | Installed | `healthy` at last audit run; reviewer assignment firing consistently |
| Intake surface | Required | PR template and issue templates present | Compliant; templates include `priority` field |
| Label/priority normalization | Expected | Canonical labels in use; legacy labels removed at onboarding | Compliant |
| Branch/merge governance | PR-only; branch protection; runner secrets not in `main` branch | Branch protection enabled; runner secrets managed via Environments | Compliant |
| Cron loop activity | Expected: CI hygiene, runner capacity, dependency updates | All three active loops confirmed | Active and healthy; Dependabot + custom runner-capacity loop firing |
| Session usage pattern | Targeted runner diagnostics and capacity decisions | Sessions used for runner-pool sizing and incident triage | Pattern matches intent; sessions are purposeful |

**Status: Healthy. Best-practice reference for the fleet.**

Reusable patterns from this repo:

- Runner-capacity loop feeding directly into a dashboard issue; provides continuous visibility without human intervention.
- PR intake template includes a `deployment-impact` section that reduces reviewer cognitive load.
- Label taxonomy enforced at repo creation time; no legacy drift.

---

### luxesite

| Dimension | Policy | Implementation | Live Behavior |
|---|---|---|---|
| Reviewer-routing automation | Required | Installed | `automation installed but not configured`; workflows present but no runs in last 30 days |
| Intake surface | Required | PR template exists; issue template missing from `.github/ISSUE_TEMPLATE/` | Non-compliant: issue template absent |
| Label/priority normalization | Expected | No `priority:*` labels created; original repo labels unchanged | No normalization; triage automation not enabled |
| Branch/merge governance | PR-only; branch protection expected | Branch protection not enabled on `main` | Non-compliant; direct pushes possible |
| Cron loop activity | Expected after onboarding | No cron loops active | No scheduled workflow runs detected in audit window |
| Session usage pattern | Expected: design review, sprint planning | Sessions used exclusively for unblocking merge conflicts and CI failures | Pattern is reactive only; no proactive governance or sprint planning sessions observed |

**Status: Highest risk repo in fleet. Four gaps requiring remediation.**

Remediation priority order:

1. Enable branch protection on `main` (blocks direct-to-main pushes; required before other governance can function).
2. Add `.github/ISSUE_TEMPLATE/` with at minimum one template file per BaseCoat contract.
3. Enable and trigger reviewer-routing workflows (`reviewer-autoassign.yml`, `pr-flow-hygiene.yml`).
4. Create `priority:*` labels and enable triage agent in repo settings.

---

## Fleet-Wide Gap Analysis

### Gap 1: Reviewer-request closure (highest priority)

All repos except `gh-devops-runners` showed at least one of: no routing automation,
misconfigured routing, or routing automation that fired but did not result in closed PRs.

Root cause pattern: reviewer-routing workflows are installed but `pull_request_target`
permission scope or collaborator access for automated reviewer assignment was not verified
post-install. Workflows appear to run but silently skip assignment.

Detection: `downstream-reviewer-routing-audit.yml` classifies this as `automation
configured but ineffective in live PRs`.

Fix: run the remediation playbook in `docs/guides/downstream-reviewer-routing-audit.md`.
Verify collaborator access and `pull_request_target` permissions explicitly during install.

### Gap 2: Intake surface drift

Two repos (`work-tracker`, `luxesite`) had intake surfaces that drifted below the
BaseCoat minimum after initial onboarding. The sync/bootstrap process does not overwrite
existing local templates, which is correct behavior — but it means drift accumulates
silently once initial templates are modified or removed.

Recommendation: add a lightweight CI check to each consumer repo that validates the
presence and minimum structure of `.github/PULL_REQUEST_TEMPLATE.md` and at least one
`ISSUE_TEMPLATE/` file. Candidate implementation tracked in #1828.

### Gap 3: Label and priority normalization drift

Legacy labels (`P0`, `P1`, `P2`, `P3`) persist in two repos alongside or instead of
canonical `priority:*` labels. The triage agent creates canonical labels when it runs,
but does not replace legacy labels on existing issues.

Recommendation: add a one-time normalization step to the onboarding runbook that:

1. Creates canonical `priority:*` labels if absent.
2. Migrates open issues from legacy to canonical label.
3. Archives (does not delete) legacy labels to preserve closed-issue history.

Reference: `docs/operations/label-cleanup-plan.md`.

### Gap 4: Cron loop activation

`luxesite` has zero active scheduled workflows. This is not a configuration drift issue;
cron loops were never activated post-onboarding. The onboarding runbook in
`docs/guides/downstream-workflows-setup.md` requires an explicit activation step that
was skipped.

Recommendation: add a post-onboarding validation gate to the downstream-workflows-setup
runbook that confirms at least one scheduled workflow run has executed before declaring
onboarding complete.

---

## Positive Patterns Worth Reusing

### Runner-capacity loop with issue-based dashboard (gh-devops-runners)

The runner-capacity loop writes results to a standing GitHub issue instead of a transient
workflow log. This gives the team a persistent, queryable history without external
dashboards or data sinks.

Reuse pattern:

1. Create a standing `[dashboard] runner capacity` issue.
2. Workflow posts a comment with current capacity metrics on each run.
3. Issue body contains the latest snapshot; comments contain the history.

### PR template with deployment-impact section (gh-devops-runners)

A `### Deployment impact` section in the PR template causes reviewers to assess impact
before approving. This pattern reduces post-merge incidents without adding review process
overhead.

Reuse: copy the section into BaseCoat's packaged `.github/PULL_REQUEST_TEMPLATE.md` and document it in
`docs/guides/contributing.md`.

### Admin-override audit trail (work-tracker)

The direct-to-main push detected in `work-tracker` was traced to a documented admin
override. The override was recorded as a comment on the corresponding issue. This is
the correct mitigation when branch protection must be temporarily bypassed: it makes
the exception auditable.

Reuse: document the admin-override audit pattern in `docs/reference/branch-protection.md`
as a recommended exception handling procedure.

---

## Anti-Patterns to Avoid

| Anti-pattern | Observed in | Risk | Corrective action |
|---|---|---|---|
| Reviewer-routing installed but collaborator access not verified | work-tracker | PRs accumulate without reviewers silently | Run routing audit after every install; verify collaborator access explicitly |
| Issue template removed post-onboarding | luxesite | New issues lack structure; triage agent skips them | CI gate on intake surface presence |
| Legacy labels co-existing with canonical labels | work-tracker | Triage signal split; search and filter unreliable | One-time normalization + archive of legacy labels |
| No branch protection on main | luxesite | Direct pushes bypass review; audit trail breaks | Branch protection must be the first governance step, not the last |
| No cron loops activated post-onboarding | luxesite | Automation assets installed but inactive; silent drift | Post-onboarding validation gate requiring at least one scheduled run |
| Session usage limited to recovery/unblock | luxesite, work-tracker | Proactive governance never runs; issues compound | Reserve at least one session per sprint cycle for governance and hygiene closure |

---

## Recommended Next Steps

| Action | Owner | Priority | Tracking |
|---|---|---|---|
| Implement automated intake surface CI check | BaseCoat | High | #1828 |
| Remediate luxesite branch protection and intake | luxesite team | High | Open downstream issue |
| Remediate work-tracker reviewer-routing | work-tracker team | High | Open downstream issue |
| Add post-onboarding validation gate to downstream-workflows-setup runbook | BaseCoat | Medium | Inline doc update |
| Publish runner-capacity-loop-with-dashboard pattern to guides | BaseCoat | Medium | New guide from gh-devops-runners pattern |
| Add admin-override audit pattern to branch-protection reference | BaseCoat | Low | Inline doc update |

---

## Refresh Policy

This scorecard documents a point-in-time audit. To keep it accurate:

- Re-run `downstream-reviewer-routing-audit.yml` after each remediation cycle.
- Update the repo-by-repo tables when a repo's classification changes.
- Add new repos to this document when they join the BaseCoat fleet.

The downstream reviewer-routing audit workflow posts a live scorecard as a workflow
summary. Cross-reference that output when updating this document.
