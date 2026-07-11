# Project Onboarding — Detail Reference

## Root File Templates

### `.gitignore`

```gitignore
# Secrets — never commit
*.env
.env.*
**/appsettings.*.json
!**/appsettings.json
**/local.settings.json
*.pfx
*.pem
*.key

# OS
.DS_Store
Thumbs.db
desktop.ini

# IDE
.vs/
.vscode/
.idea/

# Build output
bin/
obj/
dist/
node_modules/
__pycache__/
*.pyc

# Temp
*.tmp
*.bak
*.log
```

### `setup.ps1`

```powershell
$ErrorActionPreference = 'Stop'
Write-Host '--- Project Setup ---'
Write-Host 'Syncing BaseCoat...'
& "$PSScriptRoot\sync.ps1"
$hooksDir = Join-Path $PSScriptRoot '.githooks'
if (Test-Path $hooksDir) {
    git config core.hooksPath .githooks
    Write-Host 'Git hooks configured.'
}
Write-Host 'Setup complete.'
```

### `sync.ps1` / `sync.sh`

Pull from `https://raw.githubusercontent.com/ivegamsft/basecoat/$basecoat_version/sync.ps1` (or `.sh`).

### `README.md`

```markdown
# {repo_name}

## Getting Started

1. Run `setup.ps1` to configure hooks and local defaults.
2. Run `sync.ps1` to pull the pinned BaseCoat governance version.
3. Review the generated Sprint 1 issue and complete the acceptance criteria.
4. Verify the generated scaffolding files and open the repository in your editor.
```

## Hook Profile Behavior

| Profile | Packs enabled |
|---|---|
| `none` | No hook packs |
| `memory` | `10-session-memory.json` |
| `guardrails` | `20-tool-guardrails.json`, `30-error-and-budget.json` |
| `standard` | All three packs |

Hook validation rules:

1. Use native event names: `Stop`, `preToolUse`, `postToolUse`, `errorOccurred`.
2. Route budget threshold through `postToolUse`.
3. Every hook command must point to both a bash and PowerShell handler.

## Issue Templates

### `.github/ISSUE_TEMPLATE/feature.yml`

```yaml
name: Feature Request
description: Propose a new feature or enhancement
labels: ["enhancement"]
body:
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What do you want to achieve?
    validations:
      required: true
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria
    validations:
      required: true
```

### `.github/ISSUE_TEMPLATE/bug.yml`

```yaml
name: Bug Report
description: Report a defect
labels: ["bug"]
body:
  - type: textarea
    id: description
    attributes:
      label: What happened?
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
    validations:
      required: true
  - type: textarea
    id: repro
    attributes:
      label: Steps to reproduce
    validations:
      required: true
```

## Expected Directory Structure After Sync

```text
.github/base-coat/
├── README.md
├── CHANGELOG.md
├── INVENTORY.md
├── version.json
├── instructions/
├── skills/
├── prompts/
└── agents/
```

## Output Report Table

| Item | Status |
|---|---|
| Repository | `$github_org/$repo_name` — created or already existed |
| Visibility | `$visibility` |
| BaseCoat version | `$basecoat_version` synced into `.github/base-coat/` |
| Hook profile | `$hook_profile` applied |
| Sync mechanism | `sync.ps1` / `sync.sh` at repo root |
| Setup script | `setup.ps1` at repo root |
| `.gitignore` | Configured with secrets protection |
| Issue templates | `.github/ISSUE_TEMPLATE/feature.yml`, `bug.yml` |
| Sprint-1 issue | `#<number>` — "$sprint_1_goal" |
| README | Created with Getting Started section |

## Idempotency Notes

- Repo creation skipped if repo already exists; clones instead.
- Root files written only if absent; existing files preserved.
- BaseCoat sync replaces `.github/base-coat/` cleanly on each run.
- Issue templates created only if `.github/ISSUE_TEMPLATE/` directory is missing.
- Sprint-1 issue is created each run; check for duplicates before re-running.
