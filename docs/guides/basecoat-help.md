# BaseCoat Help

Discovery surface for intents, agents, skills, and workflows. Use
`/basecoat help` in chat, or open this page when you do not yet know
which asset to load.

The catalogs stay in sync because this page points at generated and
canonical sources rather than copying them:

- Intents: `docs/guides/intent-prefixes.md`
- Agents and skills (with sample prompts): `docs/reference/prompt-library.md`
- Workflows: `docs/guides/workflows-getting-started.md`
- Overloaded terms: `docs/reference/glossary.md`

Regenerate the prompt library with `pwsh scripts/generate-prompt-library.ps1`
after adding or renaming agents or skills.

## Commands

| Command | Shows | Source |
|---|---|---|
| `/basecoat help` | The four topics and one sample prompt each | this page |
| `/basecoat help intent` | Intent prefixes, timing, and routing | `intent-prefixes.md` |
| `/basecoat help agents` | Agent inventory with copy-ready prompts | `prompt-library.md` |
| `/basecoat help skills` | Skill inventory with copy-ready prompts | `prompt-library.md` |
| `/basecoat help workflows` | Contributor-facing CI and how to unblock | workflow guides |

Bare `/basecoat help` is documentation-driven. The `basecoat-help` skill
loads the same sources in Copilot Chat, Copilot CLI, and coding agent.

## Starter prompts

Copy one of these as-is, then replace the bracketed bits.

### Intents

```text
bug: the PR validation Markdown lint job failed on a file I only touched
in passing. Show the rule and the smallest fix.
```

```text
ship-it: land issue #<n> from spec to merge. Do not start a fleet burndown.
```

```text
fleet: ship-it: reduce the backlog. Start with the oldest issue.
```

### Agents

```text
@issue-triage label and size this issue, then say whether it is ready for
ship-it or still needs a PRD.
```

```text
@broken-build-troubleshooter this GitHub Actions run is red. Identify the
required check versus advisory jobs and the smallest fix.
```

### Skills

```text
Use the 'ship-it' skill. Task: implement, open a PR, and merge issue #<n>
without editing the main worktree.
```

```text
Use the 'basecoat-help' skill. Task: list intent prefixes a new contributor
should try first, with one sample prompt each.
```

### Workflows

```text
workflow: merge eligibility is blocked. Tell me which required checks are
pending and whether gh-aw agent failures are merge-blocking.
```

```text
actions: why did release-label-gate fail and which label do I add?
```

## Unblocking common workflow states

| State | What it usually means | What to do |
|---|---|---|
| Merge eligibility blocked | A required check is pending or failed | Wait for `validate-windows` / `test`; gh-aw `agent` failures are not required |
| `action_required` after a bot merge commit | Workflows need a Copilot-attributed SHA | Rebase as Copilot and `--force-with-lease` |
| Release label gate | Missing release label on the PR | Add the label the gate names; do not `--admin` merge |
| Markdown lint | Entire changed `.md` files are linted | Fix pre-existing MD036/MD031 on files you touched |

## Related

- Skill: `skills/basecoat-help/SKILL.md`
- Prompt library: `docs/reference/prompt-library.md`
