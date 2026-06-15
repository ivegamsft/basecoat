---
name: config-secrets-audit
description: "Config and secret exposure audit skill for repository and IaC config files. USE FOR: scanning Azure Key Vault references, hardcoded connection strings, GitHub Actions env secrets, .env/YAML/Bicep/Terraform parameter secrets, severity scoring, and SARIF output generation. DO NOT USE FOR: runtime penetration testing, live incident response, or deploying remediation changes."
compatibility:
  - GHCP
---
# Config Secrets Audit Skill

Use this skill to identify likely secrets exposure in configuration surfaces and produce CI-ingestable findings.

## Core Coverage

1. Azure Key Vault reference usage checks
2. Hardcoded connection string detection
3. GitHub Actions workflow `env:` secret exposure checks
4. Base64-like secret token detection
5. YAML and `.env` configuration scanning
6. Bicep/Terraform parameter secret checks
7. Severity classification (`critical`, `high`, `medium`, `low`)
8. SARIF output for code-scanning ingestion
9. Exclusion and custom-regex extensibility
10. Summary report grouped by category and severity

## Scripts

| Script | Purpose |
|---|---|
| [`scripts/audit-config-secrets.ps1`](scripts/audit-config-secrets.ps1) | Runs pattern-based config secret scanning and optionally emits SARIF |

## Recommended Workflow

1. Run scanner in repo root and review summary findings.
2. Triage by severity:
   - `critical`: direct credential material or production secret literals
   - `high`: probable secret exposure in workflows or config
   - `medium`: risky patterns needing review
   - `low`: informational or potentially safe references
3. Re-run with exclusions for known-safe patterns.
4. Export SARIF and upload to code scanning in CI.

## Example Commands

```powershell
pwsh skills/config-secrets-audit/scripts/audit-config-secrets.ps1 -RootPath . -SarifPath .\artifacts\config-secrets.sarif
pwsh skills/config-secrets-audit/scripts/audit-config-secrets.ps1 -RootPath . -ExclusionFile .\config\secret-audit-exclusions.txt
pwsh skills/config-secrets-audit/scripts/audit-config-secrets.ps1 -RootPath . -CustomPatternFile .\config\secret-patterns.json
```

## Integration Notes

- For Azure policy and compliance rollups, forward SARIF + summary output into your policy reporting pipeline.
- Use with `github-security-posture`, `security-analyst`, or `devops-audit` for remediation planning.
