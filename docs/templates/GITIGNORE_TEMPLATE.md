# Standard `.gitignore` Entries — Basecoat Template

Every repository based on or consuming basecoat must include the following `.gitignore` entries. Copy this block into your root `.gitignore` before your first commit.

---

## Local Config — Never Commit

```gitignore
# Local config — never commit
# See docs/CONFIG_PATTERN.md for the full pattern
config/settings.json
config/settings.local.json
.env
.env.local
*.local.json
```

---

## Build and Distribution Artifacts

```gitignore
# Build outputs
dist/
build/
out/
*.tgz
*.zip
*.tar.gz
```

---

## Dependency Directories

```gitignore
# Dependencies
node_modules/
.venv/
__pycache__/
*.pyc
.packages/
vendor/
```

---

## IDE and Editor Files

```gitignore
# Editor
.vscode/settings.json
.idea/
*.suo
*.user
.DS_Store
Thumbs.db
```

> **Note:** `.vscode/extensions.json` and `.vscode/tasks.json` (non-secret) are generally safe to commit and aid team consistency.

---

## OS and Tool Artifacts

```gitignore
# OS
.DS_Store
Thumbs.db
desktop.ini

# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfvars
```

---

## Test and Coverage Outputs

```gitignore
# Test outputs
coverage/
*.lcov
.nyc_output/
TestResults/
```

---

## Logs

```gitignore
# Logs
*.log
logs/
npm-debug.log*
yarn-debug.log*
```

---

## Minimum Required Block

At a minimum, every basecoat repo **must** include:

```gitignore
# Local config — never commit
config/settings.json
config/settings.local.json
.env
.env.local
*.local.json
```

Verify coverage for any new config file with:

```bash
git check-ignore -v <path/to/file>
```

---

## Enforcement

- The `config-auditor` agent (`agents/config-auditor.agent.md`) checks gitignore coverage as part of its scan.
- The `config.instructions.md` agent instructions require verifying gitignore coverage before staging.
- CI (`validate-basecoat.yml`) may validate that the minimum entries are present.

---

## Related

- `docs/CONFIG_PATTERN.md` — full local config pattern
- `agents/config-auditor.agent.md` — automated secret scanner
- `instructions/config.instructions.md` — agent config safety instructions
