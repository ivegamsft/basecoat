---
name: basecoat-help
compatibility: [copilot-chat, copilot-coding-agent, github-copilot-cli, vscode-chat]
description: "Use when a contributor asks /basecoat help or needs discovery of intents, agents, skills, or workflows. USE FOR: /basecoat help, help intent, help agents, help skills, help workflows, sample prompts, onboarding vocabulary. DO NOT USE FOR: implementing features, triaging a red CI job, writing new agents."
category: documentation
metadata:
  category: documentation
  domain: onboarding
  maturity: production
  audience:
    - developer
    - maintainer
allowed-tools:
  - Read
visibility: public
---

# BaseCoat Help

Answer `/basecoat help` (and `help intent|agents|skills|workflows`) from
generated catalogs. Do not invent names.

## Workflow

1. Read `docs/guides/basecoat-help.md` for command shape and sample prompts.
2. Topic sources (load only what the user asked for):
   - intents: `docs/guides/intent-prefixes.md`
   - agents/skills: `docs/reference/prompt-library.md`
   - workflows: `docs/guides/workflows-getting-started.md` and
     `docs/guides/workflows-reference.md`
   - overloaded words: `docs/reference/glossary.md`
3. Reply with a short table plus one ready-to-copy prompt per row.
4. If the topic is unknown, list the four topics and stop.

## Guardrails

- Reuse `prompt-library.md`; do not duplicate asset lists in this skill.
- Prefer `docs/guides/basecoat-help.md` sample prompts over improvising.
- Do not start implementation from a help request.
