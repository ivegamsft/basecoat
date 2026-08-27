# Rollout BaseCoat — Detail Reference

## Distribution Channels

| Channel | When to Use | Command |
|---|---|---|
| GitHub Release ZIP | Air-gapped / restricted egress | Download from releases page, extract to `.github/` |
| Sync script (PowerShell) | Windows CI / local dev | `$env:BASECOAT_REF="<version>"; pwsh sync.ps1` |
| Sync script (Bash) | Linux/macOS CI | `BASECOAT_REF=<version> ./sync.sh` |

## Validation Checklist

After installation, verify (paths as installed under `.github/`):

- [ ] `.github/agents/*.agent.md` files are present (no taxonomy subdirs)
- [ ] `.github/instructions/*.instructions.md` files are present
- [ ] `.github/skills/*/SKILL.md` directories are intact
- [ ] `.github/prompts/*.prompt.md` files are present
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
