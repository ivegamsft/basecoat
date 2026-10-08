# Host-Aware Frontmatter Contract

BaseCoat authoring contract **v1.0** is maintained in the distributed instruction
`instructions/basecoat-10-core-host-frontmatter.instructions.md`. Its version
is independent of the BaseCoat library and individual asset versions.

## Boundaries

| Concern | Contract |
| --- | --- |
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
the portable fields below. Checked 2026-10-07; these are documented host contracts,
not measured loader results for every installed version.

Keep existing source assets, model assignments, and names. Convert only at a
supported host projection boundary. Before asserting enforcement, record
host/version, exact projected file, available tools, positive/negative
invocations, and failure behavior. Unsupported required restrictions must
fail closed in the adapter; this documentation installs no adapter.

## Portable Agent Skills Format

The specification applies to `SKILL.md`, not `.agent.md` host profiles. A skill
directory contains YAML frontmatter and a Markdown body in `SKILL.md`; companion
directories are optional. BaseCoat source requirements are a separate profile,
not additional requirements imposed by the portable specification.

| Field | Portable contract |
| --- | --- |
| `name` | Required string, 1-64 characters; only lowercase ASCII letters (`a-z`), digits (`0-9`) and single hyphens; no leading, trailing or consecutive hyphen; matches the directory name |
| `description` | Required non-empty string, 1-1024 characters; should explain what the skill does and when to use it |
| `license` | Optional string naming a license or referencing a bundled license file |
| `compatibility` | Optional string, 1-500 characters when present; describes environment requirements, not a host-selector list |
| `metadata` | Optional map of string keys to string values; nested policy objects and lists are not portable metadata values |
| `allowed-tools` | Optional, experimental space-separated string; support and enforcement vary by host |

Omission of optional fields is not a portable-format violation. Conversely,
passing BaseCoat source checks does not validate native field types or prove that
a host enforces tool policy. Preserve rich source metadata and perform any
conversion at an explicit export boundary; do not delete source contracts or
stringify policy objects merely to produce superficially valid YAML.

### Current Alignment and Open Gaps

Inventory baseline: `ea407f976502617f8b85f592338e740be28c9b7a`, reviewed
2026-10-07. A YAML-based scan of all 143 source skills found valid required
names, directory matches and description lengths; every `SKILL.md` is below
500 lines. This scan is not a full reference-library validation or a measured
host activation test.

Of those source files, 142 use compatibility lists, 142 use allowed-tools lists,
and all 143 contain nonstring metadata values. These are BaseCoat source
extensions, not strict portable field shapes. Current installation and sync
copy source assets; projection alone does not prove portable conversion.
Do not describe the source catalog as fully portable or its policy as
universally enforced.

| Gap | Follow-up |
| --- | --- |
| Portable export and host verification, preserving source contracts and companion files | #3654 |
| Validator conflates skill/agent schemas, treats optional fields as specification expectations and uses incomplete name extraction | #3655 |
| Legacy `fix-skill-frontmatter.ps1` classifies supported fields as unsupported and can remove source contracts with `-Fix` | #3656 |

Do not use the legacy cleanup helper as a portable migration procedure. These
follow-ups do not approve an asset migration or install an enforcement adapter.

## Authoring and Evaluation Guidance

Keep a skill a coherent, task-grounded unit. Its description should include
realistic trigger language and distinguish neighboring skills, not just list
generic verbs. Load resources conditionally instead of repeating material the
model already knows.

The specification recommends progressive disclosure: name/description in the
catalog, the body on activation, and companion resources only when needed.
Keep `SKILL.md` below 500 lines and its instructions below approximately 5,000
tokens where practical. These are authoring recommendations, not universal
hard schema limits. Use relative references from the skill root, keep links
shallow and verify them in the installed package. `scripts`, `references` and
`assets` are conventional directories, not the only permitted directory names.

Document script prerequisites, pinned dependencies where applicable, inputs,
outputs and meaningful failure behavior. Compatibility text does not install
dependencies or establish credentials, entitlement or network access.

Evaluate activation separately from execution. Include realistic paraphrases
and near-miss negatives for description tests; use fresh contexts and compare
with/without the skill or old/new versions for output tests. Record assertions,
failures, timing and token use, then refine from execution traces. The upstream
`evals/evals.json` examples do not invalidate BaseCoat's existing `eval.yaml`
coverage or require replacing its format.

For a portable export, validate the emitted artifact with the reference
library's `skills-ref validate <skill-directory>` as well as relevant BaseCoat
checks. Record the reference-tool version. Then verify discovery, activation,
relative resources and required restrictions on the target host/version;
source lint and reference validation are not substitutes for loader evidence.
`.agents/skills` is a widely adopted cross-client discovery location, not a
directory mandated by the portable specification. Preserve host-specific
locations and explicitly test precedence and project trust.

## Upstream References

- [Specification](https://agentskills.io/specification)
- [Authoring best practices](https://agentskills.io/skill-creation/best-practices)
- [Evaluating skills](https://agentskills.io/skill-creation/evaluating-skills)
- [Optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
- [Using scripts](https://agentskills.io/skill-creation/using-scripts)
- [Client integration](https://agentskills.io/client-implementation/adding-skills-support)
- [Documentation index](https://agentskills.io/llms.txt)

Tracking: #3336; parent: #3324; standards review: #3653.
