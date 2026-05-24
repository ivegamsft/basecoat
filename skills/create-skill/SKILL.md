---

name: create-skill
description: "Use when creating a new reusable skill with clear triggers, workflow steps, and starter assets in a customization repository. USE FOR: add a new SKILL.md file, design skill trigger phrases, decide if work belongs in a skill, scaffold skill folder with templates, write discovery-focused skill frontmatter. DO NOT USE FOR: creating a file instruction only, writing application business logic, generating a one-off prompt response."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Create A Skill

Use this skill when the goal is to add a new `SKILL.md` to a shared customization repository.

## Workflow

1. Define the exact problem the skill should solve repeatedly.
2. Confirm a skill is the right primitive instead of an instruction, prompt, or agent.
3. Create a folder with a stable, discoverable name.
4. Add frontmatter with `name` matching the folder and a description that includes trigger phrases.
5. Write a short workflow with guardrails, expected output, and non-goals.
6. Keep the skill concise: target roughly ≤500 tokens so validation stays advisory instead of noisy. Move long examples into templates or docs.
7. Add templates or examples if the workflow benefits from starter assets.
8. Validate frontmatter and update any catalog or inventory.

## Guardrails

- Keep the skill scoped to one clear workflow.
- Put discovery keywords in the description, not only in the body.
- Keep `SKILL.md` under the token-budget target; move detail into templates or supporting docs.
- Avoid broad descriptions that overlap heavily with existing skills.
- Do not create a skill when a file instruction would be sufficient.

## Starter Assets

- Template: `templates/SKILL.template.md`
- Consider adding `examples/` or `templates/` only when they reduce repeated work
