# Downstream Repo Read and Remap Contract for Project Metadata Enforcement

## Context

Issue: #1731  
Parent feature: #1737 (Wave 2)

BaseCoat must enforce canonical governance metadata while preserving useful
downstream repository conventions.

## Contract Goals

1. Define canonical minimum fields and statuses required in all downstream repos.
2. Define remap behavior from downstream labels/fields to canonical values.
3. Preserve non-conflicting downstream delivery metadata.
4. Define enforcement behavior for invalid canonical metadata.

## Canonical Minimums (Required)

| Canonical field | Allowed values |
|---|---|
| `risk_domain` | `security`, `quality`, `reliability`, `compliance` |
| `severity` | `critical`, `high`, `medium`, `low` |
| `lifecycle_status` | `open`, `fixed_pending_verification`, `verified`, `resolved` |
| `verification_status` | `unverified`, `pending_verification`, `verified` |
| `owner` | non-empty owner id |
| `due_date` | valid date |

## Preserved Fields (Pass-Through)

- team-specific labels (for example, `area:*`, `service:*`)
- sprint and release planning labels
- delivery metadata (story points, iteration, component tags)
- repository-local process annotations

Preserved fields must not override canonical minimums.

## Mapping Table (Example Scenario)

| Downstream input | Canonical output |
|---|---|
| `priority:P0` | `severity:critical` |
| `priority:P1` | `severity:high` |
| `state:done-pending-qa` | `lifecycle_status:fixed_pending_verification` |
| `state:qa-verified` | `lifecycle_status:verified`, `verification_status:verified` |
| `risk:sec` | `risk_domain:security` |
| `risk:quality` | `risk_domain:quality` |

## Enforcement Behavior

1. **Read phase:** ingest downstream issue/PR metadata.
2. **Remap phase:** apply mapping table and canonical defaults.
3. **Validate phase:** verify canonical minimums.
4. **Enforce phase:**
   - if valid: persist canonical metadata and preserve pass-through fields.
   - if invalid: block progression and label as metadata-noncompliant.

## Failure Modes

1. Missing required canonical fields -> block transitions beyond `open`.
2. Invalid enum values -> replace with `unknown` sentinel and create triage task.
3. Downstream value conflicts with canonical rule -> canonical value wins and
   conflict annotation is added.

## Acceptance Criteria Mapping

- [x] Contract documented in governance/reference docs.
- [x] Required vs. preserved fields explicitly listed.
- [x] Enforcement behavior for missing/invalid metadata documented.
- [x] Includes an explicit downstream mapping example.
