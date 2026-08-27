# Config Auditor — Detail

Supporting detail for [`agents/basecoat-50-security-config-auditor.agent.md`](../basecoat-50-security-config-auditor.agent.md).

## Secret Patterns

Use these executable regex patterns; the `|` characters are alternation operators:

```regex
(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
(?i)(tenantId|clientId|clientSecret|appId|applicationId)\s*[:=]\s*["\']?[^<\s"\']+
(?i)(apiKey|api_key|apikey|x-api-key)\s*[:=]\s*["\']?[^<\s"\']+
(?i)(password|passwd|pwd)\s*[:=]\s*["\']?[^<\s"\']+
(?i)(connectionString|connection_string)\s*[:=]\s*["\']?[^<\s"\']+
(?i)(token|bearer|secret)\s*[:=]\s*["\']?[^<\s"\']+
https?://[^@\s]+:[^@\s]+@
(?i)"aliases"\s*:\s*\[.*@
(?i)subscriptionId\s*[:=]\s*["\']?[^<\s"\']+
```

Suppress matches where the value is a `<PLACEHOLDER>` token (e.g., `<AZURE_TENANT_ID>`).

## Config Files That Should Be Gitignored

- `config/settings.json`, `config/settings.local.json`, `*.local.json`
- `.env` (root level), `.env.local`, any `*.env` file with a non-template name

## Missing Template Check

For each config file found (tracked or untracked), verify a `.template` companion exists:

- `config/settings.json` → expect `config/settings.template.json`
- `.env` → expect `.env.template` or `.env.example`

Report missing templates as a **MISSING TEMPLATE** finding.

## Git History Scan (optional, on request)

```bash
git log --all --diff-filter=A --name-only --format="%H %s" | grep -E "(settings\.json|\.env$|\.local\.json)"
```

Report any commits that added sensitive-named files to history.

## Findings Report Format

```markdown
## Config Audit Report
**Date:** <ISO 8601>
**Repo:** <path or remote URL>

### Critical — Secrets in Tracked Files
| File | Line | Pattern | Finding |
| --- | --- | --- | --- |
| config/settings.json | 12 | tenantId | Non-placeholder value detected |

### High — Config Files That Should Be Gitignored
| File | Status |
| --- | --- |
| config/settings.json | Tracked — should be gitignored |

### Medium — Missing Template Companions
| Live Config | Expected Template | Status |
| --- | --- | --- |
| config/settings.json | config/settings.template.json | Missing |

### Info — Gitignore Coverage Gaps
Missing entries in .gitignore:
- config/settings.local.json
- *.local.json

### Clean
No findings in: <list of scanned paths>
```

## Remediation Actions

### Secret in a tracked file

Rotate or revoke the exposed credential before cleanup; untracking alone does not invalidate
existing credentials or copies in repository history.

```bash
git rm --cached config/settings.json
echo "config/settings.json" >> .gitignore
cp config/settings.json config/settings.template.json
# Then replace all secret values with <PLACEHOLDER> tokens
git add .gitignore config/settings.template.json
git commit -m "fix: remove settings.json from tracking, add template"
```

### Secret in git history (requires history rewrite)

```bash
# WARNING: History rewrite — coordinate with team before running
pip install git-filter-repo
git filter-repo --path config/settings.json --invert-paths
# Or: java -jar bfg.jar --delete-files settings.json
# After either option: force-push all branches, rotate ALL exposed credentials, notify the team
```

### Missing gitignore entries

```bash
cat >> .gitignore << 'EOF'
# Local config — never commit
config/settings.json
config/settings.local.json
.env
.env.local
*.local.json
EOF
```
