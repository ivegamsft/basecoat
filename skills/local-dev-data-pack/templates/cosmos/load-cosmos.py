#!/usr/bin/env python3
"""Deterministic Cosmos DB local-emulator loader for data-pack artifacts.

Reads ``containers.json`` (database + container/partition metadata) and each
``items.<container>.json`` document array, creates the database and containers
if missing, and performs partition-key-aware upserts with deterministic IDs.

This is the concrete "Cosmos loader" the orchestrator invokes for the Cosmos
store adapter (the analogue of ``psql`` / ``sqlcmd`` for the SQL adapters);
Cosmos ships no standard seed CLI, so the pack provides this executable.

Usage:
    python load-cosmos.py [--dir <artifact-dir>]

Environment (all optional; defaults target the local Azure Cosmos emulator):
    COSMOS_ENDPOINT              default https://localhost:8081
    COSMOS_KEY                   default well-known public emulator key
    COSMOS_EMULATOR_INSECURE_TLS set to 1 ONLY for the local emulator's
                                 self-signed certificate; never for real Cosmos

Requires the ``azure-cosmos`` package (``pip install azure-cosmos``).
Emits a JSON summary matching the store-adapter verification contract.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# Well-known, public, non-secret Azure Cosmos DB emulator key (documented by
# Microsoft). It is NOT a real credential and only works against the local
# emulator; production keys must be supplied via COSMOS_KEY.
EMULATOR_DEFAULT_KEY = (
    "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
)


def _partition_field(partition_key_path: str) -> str:
    # "/tenantId" -> "tenantId"; only top-level single-segment keys are seeded.
    field = partition_key_path.strip("/")
    if not field or "/" in field:
        raise ValueError(
            f"unsupported partition key path '{partition_key_path}': "
            "only single top-level fields are supported by this loader"
        )
    return field


# Loopback-only hosts. This loader is a LOCAL development seeder and must never
# be able to mutate a shared or cloud Cosmos account, so the endpoint is pinned
# to the loopback interface (mirroring the skill's local-only guardrail).
_LOOPBACK_HOSTNAMES = {"localhost"}


def _require_local_endpoint(endpoint: str) -> None:
    import ipaddress
    from urllib.parse import urlparse

    host = (urlparse(endpoint).hostname or "").lower()
    is_local = host in _LOOPBACK_HOSTNAMES
    if not is_local:
        # Only accept IP literals that are genuinely loopback. A hostname such
        # as "127.attacker.example" is NOT a valid IP address and is rejected,
        # so it cannot slip past via a string prefix and resolve remotely.
        try:
            is_local = ipaddress.ip_address(host).is_loopback
        except ValueError:
            is_local = False
    if not is_local:
        raise ValueError(
            f"refusing to target non-loopback Cosmos endpoint '{endpoint}': "
            "this loader is local-only and may only seed a loopback emulator "
            "(allowed: 'localhost' or a loopback IP such as 127.0.0.1 / ::1)"
        )


def load(artifact_dir: Path) -> dict:
    from azure.cosmos import CosmosClient, PartitionKey  # type: ignore
    from azure.cosmos import exceptions as cosmos_exceptions  # type: ignore

    endpoint = os.environ.get("COSMOS_ENDPOINT", "https://localhost:8081")
    key = os.environ.get("COSMOS_KEY", EMULATOR_DEFAULT_KEY)
    # Hard local-only guardrail: never allow this seeder to reach a shared/cloud
    # account, regardless of the supplied endpoint.
    _require_local_endpoint(endpoint)
    # The local emulator uses a self-signed certificate. Verification stays ON
    # by default and may only be disabled for the (already loopback) emulator.
    verify = os.environ.get("COSMOS_EMULATOR_INSECURE_TLS", "0") != "1"

    manifest_path = artifact_dir / "containers.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    database_id = manifest["databaseId"]

    client = CosmosClient(endpoint, credential=key, connection_verify=verify)
    database = client.create_database_if_not_exists(id=database_id)

    applied_artifacts: list[str] = ["containers.json"]
    inserted_count = 0
    updated_count = 0
    errors: list[str] = []

    for container_meta in manifest.get("containers", []):
        container_id = container_meta["id"]
        pk_path = container_meta["partitionKeyPath"]
        pk_field = _partition_field(pk_path)
        throughput = container_meta.get("throughput", 400)

        container = database.create_container_if_not_exists(
            id=container_id,
            partition_key=PartitionKey(path=pk_path),
            offer_throughput=throughput,
        )

        items_path = artifact_dir / f"items.{container_id}.json"
        if not items_path.exists():
            continue
        applied_artifacts.append(items_path.name)
        documents = json.loads(items_path.read_text(encoding="utf-8"))

        for doc in documents:
            doc_id = doc.get("id")
            if doc_id is None:
                errors.append(f"{container_id}: document missing deterministic 'id'")
                continue
            if pk_field not in doc:
                errors.append(
                    f"{container_id}: document '{doc_id}' missing partition key "
                    f"field '{pk_field}'"
                )
                continue
            pk_value = doc[pk_field]
            try:
                existed = True
                try:
                    container.read_item(item=doc_id, partition_key=pk_value)
                except cosmos_exceptions.CosmosResourceNotFoundError:
                    existed = False
                container.upsert_item(body=doc)
                if existed:
                    updated_count += 1
                else:
                    inserted_count += 1
            except cosmos_exceptions.CosmosHttpResponseError as exc:  # pragma: no cover
                errors.append(f"{container_id}: '{doc_id}' upsert failed: {exc.message}")

    return {
        "store": "cosmos",
        "applied_artifacts": applied_artifacts,
        "inserted_count": inserted_count,
        "updated_count": updated_count,
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Load Cosmos data-pack artifacts.")
    parser.add_argument(
        "--dir",
        default=str(Path(__file__).resolve().parent),
        help="Directory containing containers.json and items.<container>.json",
    )
    args = parser.parse_args()

    try:
        summary = load(Path(args.dir))
    except Exception as exc:  # surface a contract-shaped failure
        summary = {
            "store": "cosmos",
            "applied_artifacts": [],
            "inserted_count": 0,
            "updated_count": 0,
            "errors": [str(exc)],
        }

    print(json.dumps(summary, indent=2))
    return 1 if summary["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
