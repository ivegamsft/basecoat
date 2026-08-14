---
name: local-dev-data-pack
compatibility: [github-copilot-cli]
description: "Create a local Docker Compose test environment with store-specific sample data packs that load into persistent stores. USE FOR: scaffold local compose profiles, build seed packs for postgres/sqlserver/cosmos, load sample data locally, verify dev-desktop startup parity with app persistence. DO NOT USE FOR: production data migration, cloud provisioning, or destructive changes against shared environments."
visibility: public
category: infrastructure
metadata:
  category: infrastructure
  maturity: beta
  audience:
    - developer
    - platform-engineer
allowed-tools: [bash, powershell]
---

# Local Dev Data Pack

Create a reproducible local test stack with Docker Compose profiles and
store-specific sample data for **local dev desktop** workflows needing
realistic seed data in the app's own persistence engines.

## Companion Orchestrator

Pair with `local-dev-data-pack-orchestrator` when the repo needs topology
discovery first (detecting active stores, generating the right pack).

## Inputs

1. Target stores (`postgres`, `sqlserver`, `cosmos`) plus optional services.
2. Scenario (`minimal`, `integration`, `perf-lite`).
3. Reset mode (`reuse-volumes` or `drop-and-reseed`).
4. Output paths (default `local-dev/compose`, `local-dev/data-pack`).

## Outputs

1. Compose file with profile-gated store services.
2. Data-pack manifest plus store-specific seed artifacts.
3. Loader plan and verification report.

## Operation Modes

Four explicit semantics — see `references/lifecycle-operations.md` for full
rules and safety checks:

1. `generate` — create compose + data-pack artifacts from templates.
2. `validate` — verify integrity, compatibility, seed idempotence.
3. `update` — modify artifacts, preserving manifest/version guarantees.
4. `delete` — remove packs/profiles safely with dry-run preview.

## Reference Files

| File | Purpose |
|---|---|
| `references/workflow.md` | End-to-end flow and commands |
| `references/data-pack-contract.md` | Manifest and artifact layout |
| `references/store-adapters.md` | Postgres/SQL Server/Cosmos adapters |
| `references/lifecycle-operations.md` | Mode semantics and safety |
| `templates/docker-compose.local.template.yml` | Compose template |
| `templates/data-pack.manifest.template.yaml` | Manifest template |

## Guardrails

- Keep operations local; never target shared/prod endpoints.
- Data packs must be deterministic and idempotent.
- Seeds must match store semantics (SQL for SQL stores, partition-aware
  JSON for Cosmos).
- Never embed secrets in artifacts.
