<!-- markdownlint-disable-next-line MD041 -->
## CI Fast Guardrails Design (Issue #1666)

- **Status:** Design complete (ready for implementation in Sprint 39)
- **Issue:** <https://github.com/IBuySpy-Shared/basecoat/issues/1666>
- **Related finding:** `docs/audit/ci-cd-findings-2026-06-14.md`

---

## Problem statement

Core CI and PR workflows currently discover invalid runtime assumptions late (missing tools, missing required env values, broken token/secret configuration), which causes cryptic downstream failures and slower remediation.

The current secret-scanning posture is intentionally warn-only in some paths, but we do not have one consistent contract for what can be logged, what must be redacted, and how secret-related failures are surfaced to contributors versus maintainers.

## Design decisions

### 1. CI preconditions every run verifies first

Every CI workflow should start with a lightweight **`preflight` job** (under 60 seconds) before expensive validation/test jobs.

Required checks:

| Check | Purpose | Failure class | Blocking |
|---|---|---|---|
| Event payload integrity (`GITHUB_EVENT_PATH`, required fields) | Prevent null/invalid PR context errors | `precondition:event-payload` | Yes |
| Base-ref resolvability (`git fetch origin <base_ref>`) | Prevent silent diff and scan drift | `precondition:base-ref` | Yes |
| Toolchain presence (`bash`, `pwsh`, `jq`, `git`, `node` where needed) | Fail early with clear diagnostics | `precondition:toolchain` | Yes |
| Required environment variables (non-secret) are present and non-empty | Avoid late-stage "unset variable" crashes | `precondition:env-missing` | Yes |
| Required secrets are configured for workflows that require them | Prevent cascading auth failures | `precondition:secret-missing` | Yes |
| Permission sanity (`permissions` contract for token scopes) | Ensure least-privilege with required capabilities | `precondition:permission-mismatch` | Yes |

Implementation pattern:

1. Add reusable workflow: `.github/workflows/ci-preflight.yml` (called by `ci.yml`, `pr-validation.yml`, `validate-basecoat.yml`).
2. Standardize outputs: `preflight_ok=true|false`, `failure_code`, `failure_hint`.
3. Gate downstream jobs with `needs: preflight` and `if: needs.preflight.outputs.preflight_ok == 'true'`.

### 2. Secret-safe logging guardrails

Adopt a strict "never echo sensitive material" policy in all CI scripts and workflow steps.

Policy:

1. Do not print raw values of any variable whose name matches secret patterns (`*_TOKEN`, `*_SECRET`, `*_KEY`, `PASSWORD`, `PAT`, `CONNECTION_STRING`).
2. Use `::add-mask::` for dynamically derived sensitive values before any command that may echo arguments.
3. Disable command tracing around sensitive operations (`set +x` / avoid PowerShell transcript of secret-bearing commands).
4. Log only metadata for secrets: configured/missing, source (`secret`, `env`, `input`), and last-updated context when available.
5. Keep gitleaks warn-only behavior for contributor ergonomics, but classify true secret exposure in workflow logs as **blocking** when detected by preflight policy checks.

Implementation pattern:

1. Add script helpers:
   - `scripts/ci/logging-guardrails.sh`
   - `scripts/ci/logging-guardrails.ps1`
2. Add repository test coverage in `tests/workflow-guardrails-tests.ps1` for:
   - banned raw secret echo patterns
   - required masking and safe-log helper usage in targeted workflows
3. Add one guidance doc for contributors/maintainers:
   - `docs/reference/ci-guardrails.md`

### 3. Guard failure surfacing contract

Guard failures should be immediately understandable and triageable from the PR checks UI without opening raw logs first.

Failure surface contract:

| Surface | Requirement |
|---|---|
| Check run title | Prefix with `Guardrail:` and failure code |
| GitHub annotation | One actionable `::error` with remediation steps |
| Step summary | Include "What failed", "Why it matters", "How to fix", "Owner hint" |
| Artifacts | Attach `guardrail-report.json` with structured fields |
| Exit behavior | Preflight failures are hard-fail; downstream jobs skipped, not failed |

Structured report schema (`guardrail-report.json`):

```json
{
  "workflow": "pr-validation",
  "failure_code": "precondition:secret-missing",
  "severity": "error",
  "blocking": true,
  "failed_checks": ["PRODUCTION_REPO_TOKEN configured"],
  "remediation": [
    "Set PRODUCTION_REPO_TOKEN in repository secrets",
    "Re-run workflow"
  ]
}
```

## Scope and non-goals

In scope:

- Preflight contract and reusable workflow design.
- Secret-safe logging policy and enforcement approach.
- Failure surfacing standard across CI entry workflows.

Out of scope:

- Full implementation of all guardrails in this issue.
- Changes to branch protection policy.
- Converting every historical workflow in one pass (incremental adoption is intended).

## Rollout plan

1. **Phase 1 (core):** Implement reusable preflight and wire into `ci.yml`, `pr-validation.yml`, `validate-basecoat.yml`.
2. **Phase 2 (security hardening):** Add secret-safe logging helpers + tests + docs.
3. **Phase 3 (expansion):** Adopt the same contract in deployment and agent workflows with highest failure rates.

## Acceptance criteria

- [ ] Reusable `ci-preflight.yml` exists and is consumed by core CI workflows.
- [ ] Core workflows fail within 60 seconds when required preconditions are missing.
- [ ] No targeted workflow logs raw secret values in preflight and auth-related steps.
- [ ] Guardrail failures produce consistent failure code taxonomy, remediation text, and structured artifact.
- [ ] `tests/workflow-guardrails-tests.ps1` enforces new policy checks.
- [ ] Follow-on implementation issues/PRs reference this design doc and issue #1666.

## Dependency note

Issue #1665 (local + cloud testing workflow design) depends on this contract; it should reuse the same preflight and failure-surfacing model to avoid divergent behavior between local and cloud lanes.
