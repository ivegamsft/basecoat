# Security Remediation Traceability Workflow

> **Issue linkage:** [#1771](https://github.com/IBuySpy-Shared/basecoat/issues/1771), [#1657](https://github.com/IBuySpy-Shared/basecoat/issues/1657)

## Objective

Maintain a repeatable, audit-ready pattern that distinguishes security backlog
movement from true remediation closure by requiring implementation-linked
evidence for every closed security item.

## Required closure fields

Every security finding or security-scoped issue marked closed must include:

1. Owner (`@handle`)
2. Due date
3. Closure type (`fixed` or `risk_accepted`)
4. Evidence link(s): merged PR URL and/or formal risk-acceptance record
5. Verification artifact: scanner output, workflow run, or policy check

If any field is missing, the item remains open.

## Workflow

### Step 1: Build and rank the active backlog

Use the existing security operating stack:

- `github-security-posture` for inventory and severity ranking
- `supply-chain-security` for dependency risk order
- `security-operations` for SLA and escalation handling

### Step 2: Assign ownership and due dates

For each finding, create or update a GitHub issue with:

- severity label
- security category label (`security`, `supply-chain`, `dependency`, etc.)
- owner and due date in the issue body checklist

### Step 3: Execute remediation

Implementation must land through a linked PR with:

- explicit reference to the security issue (`Fixes #...` or `Relates-to #...`)
- scoped change summary
- verification notes in PR body or linked artifact

### Step 4: Record closure evidence

Update the ledger in `docs/audit/security-remediation-traceability-2026-06-23.md`
or its successor audit file:

- add the issue row
- link PR and commit evidence
- include verification artifact
- set closure type

### Step 5: Exception and risk acceptance path

When remediation is deferred:

1. Create a risk-acceptance record with owner and expiration date.
2. Document compensating controls.
3. Link approver decision.
4. Keep the issue open until acceptance is documented and approved.

## SLA defaults

| Severity | Target |
|---|---|
| Critical | mitigation started immediately; resolved or accepted within 24 hours |
| High | resolved or accepted within 7 days |
| Medium | resolved or accepted within 30 days |
| Low | backlog with explicit owner and due date |

## Closure gate checklist

- [ ] Owner and due date recorded
- [ ] PR or risk-acceptance evidence linked
- [ ] Verification evidence attached
- [ ] Ledger entry updated
- [ ] Closure reason auditable (`fixed` or `risk_accepted`)
