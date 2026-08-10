# The Integrate Prompt
<!-- markdownlint-disable -->

The `integrate` prompt is your zero-to-working starting point for any repository.
Open your editor or the Copilot CLI and say:

```
integrate and audit BaseCoat from https://github.com/YOUR-ORG/YOUR-REPO
```

That single sentence triggers a guided two-phase workflow:
**integration** then **audit**. No docs-hunting, no guessing.

---

## What it does

### Phase 1 — Integrate

The prompt inspects the target repository (tech stack, existing Copilot customizations,
CI workflows, team size signals) and then:

1. Recommends the right sync path for the context — direct sync, fork-first, or org-wide rollout
2. Generates the exact sync commands for the detected OS and shell
3. Drafts a tailored `.basecoat.yml` with only the agents, skills, and instructions
   relevant to the stack — no noise
4. Validates the sync completed correctly and diagnoses failures if it didn't

### Phase 2 — Audit

After integration, it runs a baseline audit across five dimensions:

| Dimension | What it checks |
|---|---|
| **Instruction coverage** | Global file size (token cost), scoped instructions, duplicate rules |
| **Agent relevance** | Stack match, required sections, `allowed_skills` wiring |
| **Skill coverage** | Skills present, frontmatter valid |
| **CI integration** | Drift detection workflow, undefined secrets, test validation |
| **Naming and taxonomy** | File naming conventions, deprecated terminology |

Each finding is classified by severity (🔴 Critical / 🟠 High / 🟡 Medium / ⚪ Low)
and comes with a specific recommended fix.

---

## How to invoke it

The prompt works in any Copilot-enabled surface:

### GitHub Copilot CLI

```bash
gh copilot suggest "integrate and audit BaseCoat from https://github.com/YOUR-ORG/YOUR-REPO"
```

### VS Code Copilot Chat

Open the chat panel and type:

```
@workspace /integrate integrate and audit BaseCoat from https://github.com/YOUR-ORG/YOUR-REPO
```

Or, if the prompt file is synced to your repo, select it from the prompt picker (`/`) and pass the URL.

### In your repo (already inside the target)

If you are already working inside the target repository, you can omit the URL:

```
integrate and audit BaseCoat
```

The prompt will use the `codebase` tool to inspect the current repo.

---

## What you get back

A structured report with three sections:

**1. Repo profile** — detected tech stack, sync method chosen, assets overlaid, BaseCoat version pinned.

**2. Audit findings table** — every finding grouped by severity with a one-line fix for each.

**3. Top 3 recommended next steps** — highest-impact actions in priority order, each with exact instructions.

Then the prompt asks: *"Would you like me to implement any of these now?"*

---

## Example output (abbreviated)

```
Repo: https://github.com/acme/payments-api
Tech stack: Python 3.12, FastAPI, PostgreSQL, GitHub Actions
Sync method: Direct sync (solo team, public repo)
Assets overlaid: 12 agents, 4 skills, 6 instructions
BaseCoat version: v4.1.0

AUDIT FINDINGS

🔴 Critical (1)
  [INSTR-001] Global instruction file is 5.2KB — adds ~5,200 tokens to every session.
              Fix: Extract Python-specific rules to a scoped instruction file (applyTo: "**/*.py").

🟠 High (2)
  [AGENT-001] No agent matches the detected FastAPI/Python stack.
              Fix: Add agents/fastapi-review.agent.md or use the code-review agent with Python examples.
  [CI-001]    No version drift detection workflow found.
              Fix: Call .github/workflows/check-basecoat-version-callable.yml from your CI pipeline.

🟡 Medium (1)
  [NAME-001]  agents/Deploy_Prod.agent.md uses PascalCase.
              Fix: Rename to agents/deploy-prod.agent.md (kebab-case required).

TOP 3 NEXT STEPS
1. Split the global instruction file — saves ~5K tokens per session
2. Add drift detection to CI — prevents silent BaseCoat rot
3. Rename the miscased agent file
```

---

## The prompt file

The prompt is located at `prompts/integrate.prompt.md`
in the BaseCoat repository. After running sync, it lands in your repo at
`.github/prompts/integrate.prompt.md` and is immediately available in VS Code's
prompt picker.

---

## Related

- [Make It Your Own](customization.md) — deeper customization options
- [Enterprise Setup](enterprise-setup.md) — org-wide rollout
- [Agent Examples](agent-examples.md) — what to do after integration
- [Consumer Sync Guide](consumer-sync.md) — sync reference
