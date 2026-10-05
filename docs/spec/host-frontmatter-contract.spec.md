# Spec: Host-Aware Frontmatter Contract

## Design and Interfaces

Publish `basecoat-10-core-host-frontmatter.instructions.md`, authoring contract
v1.0 independent of library/asset version. Cover agent, skill, instruction, and
prompt boundaries. GitHub documents agent `tools` omission as all available,
empty as none, and native aliases; skill `allowed-tools` is an experimental
string. BaseCoat's list/nested metadata and policy keys are extensions.
Native agent `tools` wins over legacy agent `allowed-tools`; no implied union.

Align agent authoring, lifecycle skeleton, handoff/index guidance, and contributor
instructions. Preserve source assets and existing models. Add a published
reference page and regression assertions in existing compatibility tests.

## Security, Failure Modes, and Risks

Visibility is not ACL; compatibility is not dependency/entitlement; guidance
does not install a runtime policy adapter. Unsupported required restrictions
must fail closed at the adapter boundary. Documented native semantics are
not evidence that all installed loaders enforce BaseCoat keys.
The main risk is treating source examples as portable native profiles; separate
source/native examples and require explicit export verification.

## Validation and Operational Readiness

Run compatibility/frontmatter tests, structure validation, Markdown lint, and
documentation build. Tests detect obsolete universal tool/filter claims,
missing contract boundaries, and skeleton/body disagreement. They do not prove
live routing, tool isolation, or host load behavior. Future measured claims must
record host/version, exact file, tool inventory, invocations, and failure output.

## Rollout and Rollback

No new schema selector key or mandatory asset migration. Existing consumers use
the normal BaseCoat update flow. Review the diff and tests before release;
rollback by reverting the instruction, aligned references, and manifest entry.

## References

- [PRD](../prd/host-frontmatter-contract.prd.md)
- [Published reference](../reference/frontmatter-host-contract.md)
- Tracking: #3336; [governance](../reference/governance-contract.md)
