# Verification-First Closure Gate for Security and Quality Remediation

## Context

Issue: #1734  
Parent feature: #1737 (Wave 3)

Findings are occasionally closed after code changes but before independent
verification evidence is attached. This causes false closure and reopened work.

## Policy Statement

A finding cannot move to `resolved` until required verification evidence is
present and linked to the remediation artifact.

## Allowed Lifecycle Transitions

1. `open -> fixed_pending_verification`
2. `fixed_pending_verification -> verified`
3. `verified -> resolved`

Direct transitions that bypass verification are prohibited.

## Verification Checklist by Finding Type

| Finding type | Required verification evidence |
|---|---|
| Dependency/security advisory | updated scan result + passing dependency tests + remediation PR |
| Static/code quality rule | passing targeted test/lint check + remediation PR |
| Secret scanning | evidence of secret revocation/rotation + scan confirmation + remediation PR |
| Workflow policy violation | passing workflow run + policy check output + remediation PR |

## Evidence Schema

Required before transition to `verified`:

- `remediation_pr_url`
- `verification_run_url`
- `verification_timestamp`
- `verifier` (human or approved automation identity)
- `environment` (`ci`, `staging`, `prod` where applicable)

Required before transition to `resolved`:

- all `verified` evidence
- source artifact state link showing closed/remediated status

## Gate Enforcement

1. Transition requests are validated against evidence schema.
2. Missing fields block the transition and emit explicit reason codes.
3. Any reopened source artifact automatically reverts issue status to `open`.

No silent defaults and no auto-resolution without evidence.

## Acceptance Criteria Mapping

- [x] Verification gate policy documented.
- [x] Required evidence schema defined.
- [x] Resolution without verification explicitly prohibited.
