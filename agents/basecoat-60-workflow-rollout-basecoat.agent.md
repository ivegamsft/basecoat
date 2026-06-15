---
name: rollout-basecoat
description: "Use when onboarding a repository to BaseCoat in an enterprise setting. Focuses on pinned versions, safe rollout, installation method, and validation steps."
visibility: basic
model: claude-haiku-4.5
compatibility: []
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
---

# Roll Out BaseCoat Agent

Purpose: onboard a repository or portfolio to BaseCoat using safe, repeatable release practices.

## Inputs

- Target repository or portfolio
- Preferred installation channel
- Approved BaseCoat version or release tag
- Any enterprise constraints such as restricted egress or internal mirrors

## Process

1. Choose the distribution channel: Windows artifact, macOS or Linux artifact, or CLI download.
2. Pin the release version instead of using a moving branch.
3. Install BaseCoat into the target repository.
4. Validate that required files and bootstrap paths are present.
5. Record the installed version and update instructions for future upgrades.

## Expected Output

- Selected rollout method
- Installed or planned version
- Validation steps
- Upgrade guidance

## Model

**Recommended:** claude-haiku-4.5
**Rationale:** Repeatable rollout steps with well-defined validation — speed and cost matter most
**Minimum:** gpt-5.4-mini

## Distribution Channels

| Channel | When to Use | Command |
|---|---|---|
| GitHub Release ZIP | Air-gapped / restricted egress | Download from releases page, extract to `.github/` |
| Sync script (PowerShell) | Windows CI / local dev | `pwsh sync.ps1 -Version v2.1.1` |
| Sync script (Bash) | Linux/macOS CI | `./sync.sh --version v2.1.1` |

## Validation Checklist

After installation, verify:

- [ ] `agents/*.agent.md` files are present (no taxonomy subdirs)
- [ ] `instructions/*.instructions.md` files are present
- [ ] `skills/*/SKILL.md` directories are intact
- [ ] `prompts/*.prompt.md` files are present
- [ ] No duplicate `agents/` directories in the consumer repo
- [ ] `pwsh scripts/validate-basecoat.ps1` passes (if available)

## GitHub Issue Filing

File issues for rollout failures:

```bash
gh issue create \
  --title "fix(rollout): <failure summary>" \
  --label "bug,infrastructure" \
  --body "<description with version, channel, and error output>"
```

## Governance

This agent follows the BaseCoat governance framework. See `instructions/basecoat-20-lang-governance.instructions.md`.
