# Guardrail: Plan-First and Azure Preflight

> **Rule:** Multi-file implementation requires a confirmed plan before execution
> begins. Azure-scoped operations require a preflight advisory before any
> deployment step runs.

---

## Plan-First Guardrail

Jumping directly into implementation on multi-file or multi-step work produces
drift, scope creep, and rework. A brief explicit plan catches design conflicts
before they reach the file system.

**Trigger condition:** A standalone `feature:`, `refactor:`, or `architect:`
message that would produce changes spanning more than one file, or that involves
an architectural or API decision.

**Required sequence:**

1. Emit a plan covering scope, approach, risks, and verification criteria.
2. Present the plan and wait for user confirmation.
3. Only begin implementation after explicit confirmation or explicit waiver.

**Waiver:** The user may waive the plan step by saying "no plan needed", "skip
planning", or "implement directly". Record the waiver in the session state so
that downstream agents do not re-prompt for planning on the same task.

**Sprint-style requests:**

When the user requests "plan and execute the next sprint" or any phrasing that
combines planning and execution in one message:

1. Route to `@sprint-planner` first.
2. Present the sprint plan and wait for confirmation.
3. Begin execution with the oldest actionable item only after confirmation.

Do not collapse the plan and execution steps into a single pass.

### Enforcement Table

| Prefix | Multi-file or design decision? | Required before implementation |
|---|---|---|
| `feature:` | Yes | Confirmed plan |
| `refactor:` | Yes | Confirmed plan |
| `architect:` | Yes | Confirmed plan |
| `bug:` | Not required | Fix immediately |
| `chore:` | If > 2 files | Confirmed plan |
| `plan:` | Always | This prefix IS the plan step |

---

## Azure Preflight Guardrail

Deploying to Azure without verifying firewall and RBAC configuration is a
common source of rework. The preflight advisory surfaces the relevant
instruction files before any deployment step runs.

**Trigger condition:** Any standalone `azure:`, `infra:`, or `deploy:` message.

**Required advisory (emit before routing output):**

```text
Azure preflight: ci-firewall and rbac-authentication checks apply.
See instructions/basecoat-60-workflow-ci-firewall.instructions.md and instructions/basecoat-50-security-rbac-authentication.instructions.md.
```

**Preflight checks:**

1. **CI Firewall** — Does the workflow access Azure resources behind a network
   firewall (Storage, Key Vault, SQL, Cosmos)?
   - If yes: confirm the single-job runner IP pattern is in place.
   - Reference: `instructions/basecoat-60-workflow-ci-firewall.instructions.md`

2. **RBAC Authentication** — Does the change provision or configure Azure
   resources?
   - If yes: confirm RBAC-only auth is enforced (no shared keys, SAS tokens,
     or connection string auth).
   - Reference: `instructions/basecoat-50-security-rbac-authentication.instructions.md`

**Blocking condition:** If a preflight check reveals a firewall or RBAC gap,
surface the finding and wait for explicit user confirmation before continuing.
Do not call `azure-deploy` until both checks have been acknowledged.

### Preflight Decision Matrix

| Scenario | Action |
|---|---|
| Workflow accesses firewalled Azure resource | Block until single-job IP pattern confirmed |
| Resource provisioned without RBAC-only auth | Block until RBAC-only auth confirmed |
| No firewall or RBAC-sensitive resources involved | Advisory only — proceed |
| User explicitly acknowledges both checks | Proceed to `azure-prepare` |

---

## Interaction with Deployment RCA Guardrail

The plan-first and Azure preflight guardrails fire **before** the deployment
sequence begins. The deployment RCA guardrail fires **during** execution if
failures occur.

Order of precedence:

1. Plan-first check (before any implementation)
2. Azure preflight advisory (before any Azure operation)
3. Deployment sequence: `azure-prepare` → `azure-validate` → `azure-deploy`
4. Deployment RCA guardrail (on first failure)

---

## References

- Plan-first workflow: [`instructions/basecoat-10-core-plan-first.instructions.md`](/instructions/basecoat-10-core-plan-first.instructions.md)
- CI firewall pattern: [`instructions/basecoat-60-workflow-ci-firewall.instructions.md`](/instructions/basecoat-60-workflow-ci-firewall.instructions.md)
- RBAC authentication: [`instructions/basecoat-50-security-rbac-authentication.instructions.md`](/instructions/basecoat-50-security-rbac-authentication.instructions.md)
- Deployment RCA: [`deployment-rca.md`](deployment-rca.md)
- Intent routing: [`instructions/basecoat-10-core-intent-routing.instructions.md`](/instructions/basecoat-10-core-intent-routing.instructions.md)
