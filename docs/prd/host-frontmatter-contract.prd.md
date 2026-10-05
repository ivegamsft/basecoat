# PRD: Host-Aware Frontmatter Contract

## Problem and Requirements

Issue #3336 identifies inconsistent tool requirements, mixed compatibility and
dependency metadata, discovery/access ambiguity, prefixed-name guidance, and
a contradictory lifecycle skeleton.

1. Publish authoring contract v1.0 with explicit artifact/host boundaries.
2. Distinguish native agent `tools` from skill `allowed-tools` and legacy fields.
3. Keep host compatibility separate from dependencies and visibility from access.
4. Align prefixed naming and copyable examples without mass-renaming assets.
5. Label documentation-based host semantics versus measured loader evidence.

## Non-Goals, Success, and Rollout

No native adapter, permission grant, asset/model migration, or consumer patching.
Success means aligned authoring references and passing regression checks for
the documented boundaries and skeleton consistency. Actual loader behavior
remains unverified until a host/version-specific smoke test is recorded.
Ship via normal release/sync; rollback by reverting this contract change.

## References

- [Spec](../spec/host-frontmatter-contract.spec.md)
- Tracking: #3336; parent: #3324
