---
name: rollout-basecoat
description: "Use when refreshing a consumer repository to the latest BaseCoat build or a pinned BaseCoat release tag. USE FOR: refresh basecoat, update basecoat in a consumer repo, run sync.ps1 or sync.sh with .basecoat.yml defaults, verify installed basecoat version after sync, recover when rollout-basecoat skill invocation fails. DO NOT USE FOR: editing BaseCoat framework internals, designing new agents or skills, running unrelated CI/CD deployments."
visibility: public
---

# Rollout BaseCoat Skill

Use this skill to refresh a consumer repository to the latest BaseCoat build or to
a pinned BaseCoat release.

## Shortcut Phrases

- refresh basecoat
- update basecoat
- sync basecoat to latest
- upgrade basecoat in this repo

## Workflow

1. Read `.basecoat.yml` (if present) for `source` and `ref`.
2. Run sync using the platform script:
   - Windows: `pwsh sync.ps1`
   - Linux or macOS: `./sync.sh`
3. Verify `.github/base-coat/version.json` in the consumer repo.
4. Compare installed version with latest upstream release:
   `gh release list --repo IBuySpy-Shared/basecoat --limit 1`.
5. Report exactly what changed and any follow-up steps.

## Fallback When Skill Routing Fails

If the environment reports `Skill not found: rollout-basecoat`, run direct sync
commands instead of stopping:

```powershell
# PowerShell fallback (from consumer repo root)
$env:BASECOAT_REPO = 'https://github.com/IBuySpy-Shared/basecoat.git'
$env:BASECOAT_REF  = 'main'  # or vX.Y.Z
pwsh .\sync.ps1
```

```bash
# Bash fallback (from consumer repo root)
BASECOAT_REPO=https://github.com/IBuySpy-Shared/basecoat.git \
BASECOAT_REF=main ./sync.sh
```
