# Host-Aware Frontmatter Contract

BaseCoat authoring contract **v1.0** is maintained in the distributed instruction
`instructions/basecoat-10-core-host-frontmatter.instructions.md`. Its version
is independent of the BaseCoat library and individual asset versions.

## Boundaries

| Concern | Contract |
|---|---|
| Agent tools | Optional native `tools`; omitted/all and empty/none are distinct; legacy agent `allowed-tools` does not override it |
| Skill tools | Native `allowed-tools` is an experimental string; BaseCoat's list is source metadata, not proven host restriction |
| Skill compatibility | BaseCoat uses a canonical host list; native Agent Skills uses an optional environment string; neither is a dependency list |
| Dependencies | Body references and BaseCoat `allowed_skills` policy; no implied native catalog filtering |
| Visibility | Discovery/classification, never authorization or access control |
| Naming | Bare filename or prefixed short-name suffix; skill name matches directory |
| Examples | Lifecycle skeleton has `allowed_skills: []` and an empty Allowed Skills body |

## Evidence and Migration

GitHub documents agent tool defaults and aliases in its
[configuration reference](https://docs.github.com/en/copilot/reference/custom-agents-configuration).
The [Agent Skills specification](https://agentskills.io/specification) defines
the native string fields. Checked 2026-10-05; these are documented host contracts,
not measured loader results for every installed version.

Keep existing source assets, model assignments, and names. Convert only at a
supported host projection boundary. Before asserting enforcement, record
host/version, exact projected file, available tools, positive/negative
invocations, and failure behavior. Unsupported required restrictions must
fail closed in the adapter; this documentation installs no adapter.

Tracking: #3336; parent: #3324.
