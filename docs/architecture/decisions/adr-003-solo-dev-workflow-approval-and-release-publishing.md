# ADR-003: Solo-Developer Workflow Approval and Release Publishing

**Date:** 2026-08-30

**Status:** Accepted

**Related issues:** [#2837](https://github.com/IBuySpy-Shared/basecoat/issues/2837),
[#2953](https://github.com/IBuySpy-Shared/basecoat/issues/2953), and
[#2956](https://github.com/IBuySpy-Shared/basecoat/issues/2956)

---

## Context

BaseCoat is maintained by a solo developer but uses automation that can create
workflow-approval requests. A trusted cloud-agent PR needs timely CI execution,
while untrusted PR content must never gain approval privileges. Separately,
protected production environments intentionally require a human deployment
approval and cannot be treated as routine CI approval.

Release publication also previously read the administrative reusable-Actions
sharing endpoint with `BASECOAT_RELEASE_AUDIT_TOKEN`. BaseCoat is now internal;
the extra long-lived credential caused releases to fail when it was absent or
scoped only to the production mirror.

## Decision

1. Automatically approve requested workflow runs only from the trusted
   default-branch `pull_request_target` workflow and only when the author has
   the stable Copilot cloud-agent identity. The policy pack controls this
   behavior. Approval is limited to unique runs for the live PR head and is
   revalidated immediately before approval.
2. Do not approve Copilot reviewer `pull_request_review` artifacts. Those
   records are GitHub platform artifacts rather than pending Actions approval
   requests. Dispatch a trusted merge-eligibility evaluation when needed.
3. Preserve protected production environment approval rules. Cancel stale
   queued runs and runs still waiting for protected-environment approval rather
   than weakening the production environment; do not interrupt active
   deployments without the cancellation preflight.
4. Remove the reusable-Actions administrative audit from release workflows and
   retire `BASECOAT_RELEASE_AUDIT_TOKEN`. Reusable workflow sharing remains an
   administrator-controlled setting; actual consumer workflow invocation is
   the compatibility check. `PRODUCTION_REPO_TOKEN` remains required only for
   publishing to the production mirror.

## Consequences

### Positive

- Trusted cloud-agent CI no longer waits for an unavailable second approver.
- Release publication no longer depends on an unnecessary long-lived
  administration credential.
- Production deployment protection remains explicit and separate from CI.

### Negative

- Sharing configuration problems are detected by consumer invocation instead
  of a release-time administrative API call.
- Reviewer-event artifacts can remain visible as completed action-required
  records even though no approval action is available.

## Risks

- An incorrectly broadened approval trigger could approve untrusted runs.
  Mitigation: keep the trusted trigger, stable author ID, policy gate,
  current-head filtering, pagination, deduplication, and live revalidation
  covered by workflow contract tests.
- Removing the audit can hide a sharing configuration error until a consumer
  calls the workflow. Mitigation: preserve consumer compatibility validation
  and document the sharing setting.

## Rollout

1. Deploy the trusted cloud-agent approval workflow.
2. Remove the release audit from both release entry points and bootstrap
   secret discovery.
3. Publish this decision with the operational documentation.
4. Validate a release using only the production-mirror token preflight.

## Alternatives Considered

### A. Approve every workflow request

Rejected. It would allow untrusted PR content to influence privileged approval.

### B. Remove production environment protection

Rejected. Production deployment is a distinct security boundary.

### C. Keep the audit token with a broader fallback

Rejected. It adds a long-lived administrative credential without improving the
internal repository's release path.
