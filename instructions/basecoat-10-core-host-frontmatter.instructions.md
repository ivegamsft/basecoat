---
description: "Use when authoring or reviewing host-specific agent, skill, instruction, or prompt frontmatter and copyable examples."
applyTo: "agents/**/*.agent.md,skills/**/SKILL.md,instructions/**/*.instructions.md,prompts/**/*.prompt.md"
---

# Host-Aware Frontmatter Contract

## Contract Version 1.0

This is BaseCoat's authoring contract, not a claim that every host enforces its
extensions. Contract version is independent of library/asset `version`.
Existing assets need no mass rewrite. Native projections must use the target
host's schema; preserve canonical source metadata rather than deleting it.

## Artifact and Host Matrix

| Artifact | BaseCoat source | Native host boundary |
|---|---|---|
| Agent | `name`, `description`, discovery `visibility`; optional `tools` | GitHub/CLI agent profiles require `description`; `name` is optional display metadata; `tools` is optional |
| Skill | `name`, `description`, canonical host-list `compatibility` | Agent Skills requires `name` and `description`; optional `compatibility` is a string, not BaseCoat's list |
| Instruction | `description`, `applyTo` | Host-specific instruction loading/globs; do not treat agent names as paths |
| Prompt | Follow the target prompt-file schema | Do not infer agent tool restrictions or skill activation from prompt metadata |

BaseCoat's nested/list metadata, capability policies, and `allowed_skills`
are extensions. A native host ignoring a key is not proof of enforcement.
For VS Code-specific fields such as `handoffs`, use its own schema; GitHub cloud
agent does not support that UI field. Host/version support must be rechecked
when exporting. Documented behavior below is not a live loader experiment.

## Tool Fields and Precedence

1. Agent `tools` is the native tool selector. Use documented host aliases
   (`read`, `edit`, `search`, `execute`) or supported namespaced MCP names.
   GitHub documents omitted `tools` or `["*"]` as all available tools, and
   `tools: []` as no tools. An empty list is valid for a text-only agent.
2. An agent's legacy `allowed-tools` does not override or merge with `tools`.
   If `tools` is absent, do not assume `allowed-tools` restricts the native host.
3. Skill `allowed-tools` is an experimental Agent Skills string. BaseCoat's
   existing list form is source metadata; native export requires host-specific
   conversion and verification. Neither form grants tools denied by the host.
4. Unknown native agent tool names are documented as ignored. Do not claim
   `read_file` or `create_github_issue` works without an adapter mapping.

An adapter enforcing BaseCoat tool or skill restrictions must validate mappings
before invocation and fail closed on unsupported required capabilities.
No adapter is installed or permission granted by this instruction.
For model selectors, use `basecoat-10-core-capability-frontmatter.instructions.md`;
host-native `model` defaults do not establish BaseCoat orchestrator inheritance.

## Compatibility, Dependencies, and Visibility

- Skill source `compatibility` lists intended tested hosts:
  `copilot-chat`, `copilot-coding-agent`, `github-copilot-cli`, `vscode-chat`,
  `mcp`, `github-actions`. It is not a dependency or entitlement list.
- `GHCP`, `agent:<name>`, and `skill:<name>` are historical metadata, not
  canonical skill host values. Record dependencies in the body and use
  `allowed_skills` for the BaseCoat invocation policy, not host compatibility.
- Agent `visibility` (`basic`, `specialized`, `advanced`, `internal`) is
  discovery classification. Skill `visibility` (`public`, `private`) is
  BaseCoat classification. Neither is an access-control or authorization boundary.
- Native `user-invocable` and `disable-model-invocation` control documented
  invocation behavior, not access to secrets or approval to mutate resources.
- `ships`, `dogfood`, and `status` are distribution metadata. Do not assume
  runtime hiding or sync filtering unless the relevant installer implements it.

## Names and Copyable Examples

Bare agent filenames match `name`; prefixed
`basecoat-NN-<category>-<short-name>.agent.md` matches the short-name suffix.
Native file-based deduplication can still use the whole filename. Skill `name`
matches its directory. Do not mass-rename assets to remove prefixes.

Copyable BaseCoat agent frontmatter for
`agents/basecoat-10-core-example-agent.agent.md`:

```yaml
---
name: example-agent
description: "Review text. USE FOR: bounded text review. DO NOT USE FOR: code edits, deployments, incident containment."
visibility: specialized
tools: []
allowed_skills: []
---
```

Copyable BaseCoat skill source for `skills/example-skill/SKILL.md`:

```yaml
---
name: example-skill
description: "Review supplied text. USE FOR: findings-only text review. DO NOT USE FOR: code edits, deployments, live operations."
compatibility: [github-copilot-cli]
visibility: public
allowed-tools: []
---
```

Copyable native Agent Skills projection (different schema, not a replacement
for the canonical source):

```yaml
---
name: example-skill
description: Review supplied text without making changes.
compatibility: Designed for GitHub Copilot CLI.
---
```

## Validation and Evidence

BaseCoat validation checks repository conventions; it does not prove native
loader acceptance, permission isolation, or routing accuracy. Before claiming
host enforcement, record host/version, projected file, observed available
tools, positive/negative invocation, and failure behavior in a bounded smoke
test. If unverified, label the claim unverified rather than assuming support.

Documentation checked 2026-10-05:

- [GitHub custom agent configuration](https://docs.github.com/en/copilot/reference/custom-agents-configuration)
- [Agent Skills specification](https://agentskills.io/specification)
