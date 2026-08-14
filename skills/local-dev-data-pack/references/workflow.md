# Local Dev Data Pack Workflow

Use this flow to build a local Docker Desktop test environment that matches the app's real persistence layer.

## Operation Modes

The orchestrator runs one of four explicit modes:

- `generate`: scaffold compose/profile + manifest + store artifacts
- `validate` (audit): verify artifact contract, compose validity, and seed idempotence
- `update`: patch selected artifacts and re-run validation gates
- `delete`: remove scoped artifacts with dry-run support and scope checks

## 1) Discover persistence topology

Inspect the repo for active stores:

- PostgreSQL indicators: `Npgsql`, `postgres`, `DATABASE_URL`, Prisma `provider = "postgresql"`.
- SQL Server indicators: `SqlConnection`, `UseSqlServer`, `mssql`, `Server=`.
- Cosmos indicators: `CosmosClient`, `UseCosmos`, emulator endpoints, partition-key config.

Emit a resolved store set (for example: `postgres + cosmos`).

## 2) Materialize compose profiles

Start from `templates/docker-compose.local.template.yml` and keep only the required profiles/services.

Recommended command shape:

```powershell
docker compose -f local-dev/compose/docker-compose.local.yml --profile postgres --profile cosmos up -d
```

## 3) Apply mode-specific artifact operation

- `generate`: create `local-dev/data-pack/artifacts/<scenario>/` from templates
- `update`: apply targeted artifact changes while preserving manifest invariants
- `delete`: remove selected artifacts (or whole scenario) after dry-run preview

Typical artifact set:

- `manifest.yaml`
- `postgres/*.sql`
- `sqlserver/*.sql`
- `cosmos/*.json` plus `cosmos/load-cosmos.py` (bundled loader)

## 4) Load or audit data by store adapter

- Postgres: execute schema then seed scripts in dependency order.
- SQL Server: execute schema then seed scripts with `sqlcmd`.
- Cosmos: run `cosmos/load-cosmos.py` to create containers (if missing), then upsert partition-aware items.

`delete` mode skips load and performs post-delete consistency checks instead.

## 5) Validate and report

Run checks:

- table/document counts
- key lookup by known sample IDs
- app startup/readiness with expected baseline dataset
- mode-specific invariants (`validate` must be read-only, `delete` must prove scope)

Return a deterministic summary with loaded entities per store and failed steps (if any).

## Invoking the Orchestrator

`local-dev-data-pack-orchestrator` is a Copilot **custom agent**, not a shell
binary — there is no `local-dev-data-pack-orchestrator` executable on `PATH`.
Invoke it conversationally by selecting/naming the agent and stating the mode,
stores, and a supported scenario (`minimal`, `integration`, or `perf-lite`).
The agent then runs the real underlying tools (`docker compose`, `psql`,
`sqlcmd`, the Cosmos loader) on your behalf.

```text
# Detect topology (agent inspects the repo, no artifacts written)
@local-dev-data-pack-orchestrator detect the persistence stores in this repo

# Generate
@local-dev-data-pack-orchestrator generate a data pack for postgres,sqlserver,cosmos
using the integration scenario

# Validate / audit
@local-dev-data-pack-orchestrator validate the pack at
local-dev/data-pack/artifacts/integration/manifest.yaml

# Update
@local-dev-data-pack-orchestrator update the postgres slice of the integration
pack with a seed-refresh, then re-validate

# Delete (safe preview first)
@local-dev-data-pack-orchestrator delete the cosmos slice of the integration
pack — dry-run first
```

The underlying executables the agent drives are ordinary tools, e.g.:

```powershell
docker compose -f local-dev/compose/docker-compose.local.yml --profile postgres --profile cosmos up -d
```
