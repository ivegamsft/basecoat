---
description: Tracking for known limitations and prerequisites for certain features.
---

# Known Limitations & Blocked Issues

## Known Failure Patterns

### PR Blocked With All Checks Passing — Unresolved Review Threads

**Status:** ACTIVE PATTERN (discovered 2026-06-24, issue #1763 hotfix)

**Symptom:** `mergeStateStatus: BLOCKED`, `mergeable: MERGEABLE`, all six required status checks
`SUCCESS`, no `pr-readiness-blocked` label — yet `gh pr merge` fails with
`"the base branch policy prohibits the merge"`.

**Root Cause:**
`required_conversation_resolution: true` is set in branch protection for `main`.
Copilot code review bots (Copilot PR Reviewer, Security Analyst agent, etc.) leave inline comment
threads that are never auto-resolved. Each push to the PR branch can add new threads.
The GitHub API `mergeable_state` will return `blocked` even when no human reviewer action is
pending — the blocker is entirely the open bot-authored threads.

**How to Detect:**

```bash
gh api graphql -f query='{ repository(owner: "IBuySpy-Shared", name: "basecoat") {
  pullRequest(number: <N>) {
    reviewThreads(first: 50) { nodes { id isResolved } }
  }
} }' | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
```

If the count is non-zero and all required checks are green, this is the blocker.

**Resolution:**

Resolve all open threads via GraphQL mutations (safe — does not dismiss reviews, just marks threads resolved):

```bash
# Replace THREAD_ID with each thread node ID from the query above
gh api graphql -f query='mutation {
  resolveReviewThread(input: { threadId: "THREAD_ID" }) {
    thread { id isResolved }
  }
}'
```

Auto-merge fires immediately after the last thread is resolved if it was already enabled.

**Enable auto-merge first to get instant merge after resolution:**

```bash
gh pr merge <N> --repo IBuySpy-Shared/basecoat --merge --auto
```

**Prevention (proposed):** Add a step in `pr-flow-hygiene.yml` to surface unresolved thread count
as a readiness comment so the blocker is visible without manual API inspection.

---

## Blocked by External Constraints

### SHA Pin Scanner False Positives from Synced BaseCoat Templates

**Status:** KNOWN ISSUE (documentation and consumer configuration guidance)

**Description:** Downstream repositories that scan all YAML for unpinned `uses:` values can report false positives from synced BaseCoat example/template content under `.github/base-coat/**` and `.github/skills/**`, even when executable workflows in `.github/workflows/**` are fully pinned.

**Why It Happens:**

- BaseCoat sync includes documentation examples and templates intended as starter content
- Those assets intentionally contain version-tagged or placeholder `uses:` references for readability
- Broad scanners treat all YAML as executable workflow material

**Guidance (scanner boundary):**

1. Use a positive allowlist for executable workflows: `.github/workflows/**`
2. Exclude synced sample/template paths from hash-enforcement scans:
   - `.github/base-coat/docs/examples/**`
   - `.github/base-coat/docs/templates/**`
   - `.github/base-coat/.github/workflow-templates/**`
   - `.github/skills/**/takt-time-workflow.yml`

**Implementation Note:** Apply exclusions in the scanner file selection step (script or `rg --glob '!pattern'`) rather than rewriting BaseCoat docs/templates.

---

### #283: GitHub API Per-Model Premium Billing Data

**Status:** WONTFIX (API Limitation)

**Description:** GitHub API does not expose per-model premium billing breakdown. This data is only available through the GitHub web UI's billing dashboard.

**Why It's Blocked:**

- GitHub REST API v3 and GraphQL API do not include granular billing data per model
- Enterprise billing aggregation only available via web UI

**Workaround:**

- Navigate to: GitHub Settings → Billing and plans → Usage metrics
- Export billing data manually from web dashboard
- Use Azure Cost Management for Azure OpenAI consumption instead

**Related:** Model optimization discussions require this data (see docs/model-optimization.md)

---

### #282: Copilot Usage Metrics Policy Configuration

**Status:** RESOLVED (2026-05-08)

**Description:** Enterprise admin has enabled the "Copilot usage metrics" policy. The new
`/copilot/metrics/reports/` API endpoints are live and returning data.

**Note:** The old `GET /orgs/{org}/copilot/metrics` endpoint was sunset 2026-04-02 and replaced
by `/orgs/{org}/copilot/metrics/reports/organization-28-day/latest`. See
`instructions/basecoat-10-core-enterprise-configuration.instructions.md` for updated API reference.

---

### #1073: Register GitHub App for BaseCoat Copilot Extension

**Status:** BLOCKED (External org-admin prerequisite)

**Description:** The GitHub App required for the BaseCoat Copilot Extension cannot be fully registered from repository-only changes.

**Why It's Blocked:**

- GitHub App creation and org installation require organization owner/admin permissions in GitHub UI
- Extension endpoint and OAuth callback wiring depend on deployed backend URL and org secret provisioning

**What Is Ready in Repo:**

- Registration runbook: `docs/operations/COPILOT_EXTENSION_GITHUB_APP_REGISTRATION.md`
- Config scaffold: `docs/templates/copilot-extension/github-app-registration.template.json`
- PRD references updated to the runbook for handoff completion

**Follow-up Tracker:** [#1127](https://github.com/IBuySpy-Shared/basecoat/issues/1127) (owner checklist + evidence collection)

**Next Action Owner:** `IBuySpy-Shared` organization admin + platform engineer for extension backend

---

## Design Limitations

### Skill Refactoring (>5KB Files) — Phase 2 #330

**Status:** COMPLETE (closed Sprint 15–16)

**Resolved:** All 12 skills that exceeded 5KB have been modularized using the `references/` pattern. Each `SKILL.md` is now a ≤5KB overview + nav table pointing to focused `references/*.md` files.

**Skills modularized:**

- Sprint 15 (batch 1): `cqrs-event-sourcing`, `e2e-testing`, `penetration-testing`, `microservices-migration`, `service-bus-migration`
- Sprint 16 (batch 2): `identity-migration`, `basecoat`, `tech-debt`, `dev-containers`, `api-security`, `ha-resilience`, `azure-devops-rest`

**Remaining skills >5KB for Sprint 17 (batch 3):** `electron-apps` 6.4KB, `database-migration` 6.1KB, `github-security-posture` 6.1KB, `contract-testing` 5.6KB, `azure-waf-review` 5.3KB, `copilot-usage-analytics` 5.1KB

---

## Enterprise Prerequisites

### Copilot Usage Metrics

**Requires:**

- ✅ GitHub Enterprise Cloud subscription
- ⏳ Enterprise admin enablement (external action)
- ⏳ 24-48h activation period
- ⏳ Permissions: `admin:enterprise` scope

**Post-Enablement:**

- Organization usage dashboard available
- Per-seat active user tracking
- Model adoption metrics
- Cost per seat reporting

---

## Workarounds & Alternatives

| Blocked Feature | Workaround | Alternative |
|---|---|---|
| GitHub API per-model billing | Manual export from web UI | Azure Cost Analysis for Azure OpenAI models |
| Copilot metrics collection | Enable enterprise policy (admin action) | GitHub API audit logs (`GET /repos/{owner}/{repo}/audit-log`) |
| Large skill navigation | Modular `references/` pattern | Link to specific reference file in SKILL.md nav |

---

## Issue Resolution Path

### For Blocked Issues

1. **Assess blocker type:** External (API), Enterprise prerequisite, or Design limitation
2. **Document prerequisite:** Link to setup guides or admin actions
3. **Provide workaround:** Offer alternative if available
4. **Label issue:** `blocked`, `prerequisite`, or `wontfix`
5. **Re-evaluate quarterly:** Check if API limitations lifted or enterprise policies updated

### For Design Limitations

1. **Prototype solution:** Create proof-of-concept (e.g., modular skill refactoring)
2. **Test at scale:** Apply to 2-3 large skills before full rollout
3. **Document pattern:** Add to `docs/` for future contributors
4. **Track effort:** Estimate hours needed for full implementation
5. **Prioritize:** Include in next sprint if high-value

---

**Last Updated:** 2026-05-31  
**Reviewed By:** Copilot  
**Next Review:** 2026-06-21
