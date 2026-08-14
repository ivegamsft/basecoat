# Lifecycle Operations

This skill defines four operation semantics for local data-pack lifecycle management.

## Generate

Purpose: create a new scenario pack and compose profile mapping.

Requirements:

- resolved target store set
- scenario name
- deterministic seed IDs

Output:

- `manifest.yaml`
- store artifacts under scenario path

## Validate (Audit)

Purpose: prove the pack is structurally and operationally correct without mutating baseline data.

Checks:

- manifest schema + artifact path consistency
- compose profile references exist and are valid
- adapter execution plan is complete
- seed idempotence simulation or no-op replay

Output:

- audit report with pass/fail by check and store

## Update

Purpose: modify an existing pack while retaining compatibility guarantees.

Rules:

- preserve manifest identity: the `scenario` name and `version` contract
  semantics must remain unchanged across an update (the manifest defines no
  separate `id` field; scenario is the pack's stable identity)
- reject unknown adapter/store target names
- require post-update validate pass

## Delete

Purpose: safely remove a scoped pack, store slice, or scenario.

Guardrails:

- dry-run preview first
- explicit target scope required (`store`, `scenario`, or artifact path)
- path containment: canonicalize every resolved target (resolve symlinks and
  `..` segments to an absolute real path) and verify it stays under the selected
  scenario/output root before previewing or deleting — reject any path that
  escapes the root, and never follow symlinks that point outside it
- after the preview, stop and require explicit user confirmation of the exact
  file list before any destructive removal — never auto-proceed from preview
- reject cross-scenario wildcard delete
- emit deleted file list + residual consistency check
