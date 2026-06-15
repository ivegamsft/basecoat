---
description: "Inventory count drift prevention and remediation"
applyTo: "**/*"
---

# Inventory Count Drift: Prevention and Remediation

## Problem Statement

The `docs/index.md` file contains a summary table of BaseCoat asset counts (Agents, Skills, Instructions, Prompts). These counts can become stale when new assets are added to the repository without updating the documentation.

**Failure Evidence** (Issue #1574):
- CI validation detected mismatches:
  - Instructions: found 90, expected 91
  - Skills: found 104, expected 116
  - Agents: found 105, expected 116

## Root Cause

The inventory counts in `docs/index.md` are manually maintained. When developers add new agents, skills, or instructions, they often forget to update the homepage table. This causes:

1. **Broken CI/validation runs** — the `validate-basecoat.ps1` script (line 109–146) checks that documented counts match actual repository state
2. **Out-of-sync documentation** — users see incorrect asset totals
3. **Mainline blocker** — stale counts break the PR merge gate

## Solution

### 1. **Automated Refresh Script**

Run the refresh script to automatically update `docs/index.md` with current counts:

```bash
pwsh scripts/refresh-docs-inventory-counts.ps1
```

This script:
- Counts actual assets in `agents/`, `skills/`, `instructions/`, `prompts/` directories
- Updates the "What's included" table in `docs/index.md` to match
- Reports the new counts for verification

### 2. **Guardrails in CI**

The existing `validate-basecoat.ps1` test runs during CI and will catch drift automatically:

```bash
pwsh scripts/validate-basecoat.ps1
```

This is included in the full test suite (`pwsh tests/run-tests.ps1`).

### 3. **When to Refresh Counts**

Update counts when:
- Adding a new agent (`.agent.md` file)
- Adding a new skill (subdirectory with `SKILL.md`)
- Adding a new instruction file (`.instructions.md`)
- Adding a new prompt (`.prompt.md`)

**Before committing**, run:
```bash
pwsh scripts/refresh-docs-inventory-counts.ps1
pwsh scripts/validate-basecoat.ps1
```

## Prevention Strategies

### For Individual Contributors

1. **After creating new assets**, run the refresh script:
   ```bash
   pwsh scripts/refresh-docs-inventory-counts.ps1
   ```

2. **Validate before pushing**:
   ```bash
   pwsh scripts/validate-basecoat.ps1
   ```

3. **Include the docs change in your commit**:
   ```bash
   git add docs/index.md
   git commit -m "fix: update inventory counts (Agents: 116, Skills: 116, Instructions: 91)"
   ```

### For Maintainers / Automation

1. **Run full validation in pre-merge checks** — already done via CI
2. **Periodic audits** — consider a scheduled job to alert on drift (e.g., weekly)
3. **Documentation** — link to this guide in contribution templates

## Troubleshooting

**Q: My counts don't match after running the refresh script**

- Ensure you're running the script from the repository root:
  ```bash
  cd /path/to/basecoat
  pwsh scripts/refresh-docs-inventory-counts.ps1
  ```

**Q: How do I verify the counts are correct?**

- Run the validation script:
  ```bash
  pwsh scripts/validate-basecoat.ps1
  ```

- If validation passes without inventory errors, counts are correct.

**Q: What if CI still fails after I refresh?**

- This may indicate:
  - Assets are in an unexpected location
  - Asset naming convention changed (e.g., file extension)
  - Multiple asset sources (e.g., `.agents/skills/` subdirectory for cross-client interop)
  
- Check `scripts/validate-basecoat.ps1` lines 126–129 for the exact counting logic.

## Related Issues

- **#1482** — Prior instance of stale counts (closed)
- **#1574** — Current issue (resolved by this fix)

## References

- `docs/index.md` — The file being updated
- `scripts/validate-basecoat.ps1` — Validation logic (lines 109–146)
- `scripts/refresh-docs-inventory-counts.ps1` — Automated refresh script
