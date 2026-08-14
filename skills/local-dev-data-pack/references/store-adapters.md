# Store Adapters

This skill uses store-specific loaders rather than a single generic importer.

## PostgreSQL adapter

- Input: ordered SQL scripts under `postgres/`.
- Execution: `psql` against local service.
- Required behavior:
  - schema before seed
  - idempotent DDL
  - deterministic sample IDs

## SQL Server adapter

- Input: ordered SQL scripts under `sqlserver/`.
- Execution: `sqlcmd` against local service.
- Required behavior:
  - schema before seed
  - rerunnable script semantics
  - deterministic sample IDs

## Cosmos adapter

- Input:
  - `containers.json` for container/partition metadata
  - `items.<container>.json` for documents
- Execution: `python cosmos/load-cosmos.py --dir cosmos/` (bundled loader; the
  Cosmos emulator ships no `psql`/`sqlcmd`-style seed CLI, so the pack provides
  this executable). Requires `azure-cosmos`; targets the local emulator via
  `COSMOS_ENDPOINT`/`COSMOS_KEY` (emulator defaults built in). Local-only: the
  loader refuses any non-loopback `COSMOS_ENDPOINT` so it can never mutate a
  shared/cloud account.
- Required behavior:
  - create database and container if missing (partition key from metadata)
  - enforce partition key presence per document
  - partition-key-aware upserts with deterministic IDs and timestamps

## Verification contract

Each adapter returns:

- `store`
- `applied_artifacts`
- `inserted_count`
- `updated_count`
- `errors[]`
