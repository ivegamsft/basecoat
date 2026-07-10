# Guardrail: Deployment RCA — Retry Caps, Path Lock, Bootstrap Immutability

> **Rule:** When a deployment fails, extract the failure signature before retrying.
> After repeated failure of the same class, switch to RCA-only mode. Do not mutate
> bootstrap-owned state during incident execution.

---

## Retry Cap Guardrail

Repeating a failed deployment without extracting the failure signature causes
execution drift. The deployment context accumulates stale state, subsequent failures
become harder to diagnose, and retry loops mask the root cause.

**Enforcement:**

- **First failure**: Extract the stage name and exact error signature before any rerun.
- **Second failure of the same class**: Stop executing. Route to RCA-only mode.
- **RCA-only mode**: All deployment commands are suspended. The session goal is
  diagnosis, not re-execution.

To transition back to execution mode, the user must:

1. Confirm the root cause is identified.
2. Confirm the remediation step is distinct from prior attempts.
3. Re-issue a `deploy:` intent explicitly to resume execution.

### Identifying a Repeated Failure

A failure is "repeated" when any of the following are true:

- The same stage or resource fails in consecutive attempts.
- The error signature (exit code, provider error code, resource type) matches
  the prior failure.
- The user message contains `rca`, `stop and rca`, `why is it failing`,
  `same error`, or `still broken`.
- The deployment has been retried three or more times without a confirmed root
  cause between attempts.

---

## Path Hygiene Guardrail

Deployments running in an incorrect workspace directory produce silent drift:
scripts reference wrong paths, state files diverge, and infrastructure changes
land in the wrong environment.

**At session start for any in-place deployment session:**

1. Confirm the canonical repo path from bootstrap configuration or the
   `BASECOAT_REPO` environment variable.
2. Verify the session working directory matches that canonical path.
3. If a second checkout of the same repo exists at a different path, warn
   before proceeding.

**Block or warn when:**

| Condition | Action |
|---|---|
| Session path differs from canonical path and another checkout exists | Warn — require explicit user confirmation to continue |
| `BASECOAT_REPO` or equivalent env var is unset | Warn — path hygiene cannot be verified |
| Git remote origin differs from expected repository | Block — session may be operating on the wrong repo |

---

## Bootstrap Immutability Protocol

During an incident or active deployment session, bootstrap-owned variables and
secrets are treated as immutable. Changing them mid-execution shifts the
environment state, invalidates prior failure context, and risks the next retry
running against a different configuration than the one that failed.

**During incident or deployment execution, do not:**

- Modify GitHub Actions secrets, environment variables, or OIDC configurations
  owned by bootstrap.
- Re-run bootstrap workflows to rotate credentials unless the user explicitly
  requests re-bootstrap.
- Change `azure.yaml`, `.env`, or environment-specific `infra/` files that
  bootstrap manages.

**Prefer instead:**

- Local or ephemeral overrides that do not persist beyond the session.
- Explicit re-bootstrap only after the incident is resolved and the session
  is in a clean state.

**Permitted exceptions** (require explicit user request with stated reason):

- Rotating a compromised secret during an active security incident.
- Correcting a misconfigured bootstrap value that is the confirmed root cause
  of the current failure.

---

## Firewall Discipline — Non-Optional Sequence

"Disable the firewall" is not a valid troubleshooting step. Weakening network
controls to unblock a deployment introduces a security exposure that outlasts
the incident.

**Required sequence (non-negotiable):**

1. Capture current firewall rules.
2. Add the runner IP using `az` CLI (not Terraform — Terraform causes state drift).
3. Perform the deployment work.
4. Remove the runner IP in an `always()` cleanup step.

**Forbidden troubleshooting shortcuts:**

- `az storage account update --default-action Allow` — disables the firewall entirely.
- Commenting out firewall rule steps to test without network restrictions.
- Leaving runner IPs in place after a deployment completes.

See [`instructions/basecoat-60-workflow-ci-firewall.instructions.md`](/instructions/basecoat-60-workflow-ci-firewall.instructions.md)
for the full pattern, YAML template, and anti-patterns.

---

## RCA Routing Before Re-Execution

When a prompt contains any of the following signals, route to triage/audit mode
before allowing any execution path:

| Signal | Action |
|---|---|
| Contains `rca` or `stop and rca` | Suspend execution. Enter RCA-only mode. Route to `@rca`. |
| Same error repeated two or more times | Force RCA step before next retry. |
| User asks "why" after a failure | Treat as RCA signal. Do not retry until root cause is stated. |
| Deployment retried three or more times | Hard block on further retries. Require `rca:` prefix to diagnose. |

---

## References

- Deployment cancellation pre-flight: [`deployment-cancellation.md`](deployment-cancellation.md)
- Firewall pattern: [`instructions/basecoat-60-workflow-ci-firewall.instructions.md`](/instructions/basecoat-60-workflow-ci-firewall.instructions.md)
- Intent routing: [`instructions/basecoat-10-core-intent-routing.instructions.md`](/instructions/basecoat-10-core-intent-routing.instructions.md)
- Bootstrap structure: [`instructions/basecoat-10-core-bootstrap-structure.instructions.md`](/instructions/basecoat-10-core-bootstrap-structure.instructions.md)
- CI concurrency: [`ci-concurrency.md`](ci-concurrency.md)
