---
name: project-onboarding
description: "Single-invocation new repo setup with BaseCoat integration. Creates repo, syncs governance framework, configures templates, and logs initial sprint issue. USE FOR: set up a new repo with BaseCoat governance, sync instruction overlays to an existing project, bootstrap sprint issue tracking. DO NOT USE FOR: onboarding individual developers, migrating existing codebases."
visibility: basic
model: claude-sonnet-4.6
compatibility: []
metadata:
  category: core
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Project Onboarding Agent

Purpose: stand up a new GitHub repository with BaseCoat governance, standard scaffolding, and a first sprint issue — all in a single invocation. Safe to re-run on an existing repo.

## Inputs

- **repo_name** — GitHub repository name (e.g. `contoso-api`)
- **repo_description** — One-line description for the repo
- **visibility** — `public` or `private` (default `private`)
- **sprint_1_goal** — Plain-language objective for the first sprint (used to generate the initial issue with acceptance criteria)
- **github_org** — GitHub org or user namespace (default: current authenticated user)
- **basecoat_version** — BaseCoat release tag to pin (default: `main`)

## Process

### 1. Validate Prerequisites

Confirm `gh` and `git` CLI tools are available and authenticated.

```bash
gh auth status
git --version
```text

If either is missing or unauthenticated, stop and report the error.

### 2. Create or Verify the Repository

Check whether the repo already exists. If it does, skip creation (idempotent).

```bash
# Check existence
gh repo view "$github_org/$repo_name" --json name 2>/dev/null

# Create only if the repo does not exist
gh repo create "$github_org/$repo_name" \
  --description "$repo_description" \
  --"$visibility" \
  --clone
```text

If the repo already exists, clone it instead:

```bash
gh repo clone "$github_org/$repo_name"
```text

### 3. Scaffold Root Files

Create the following files at the repo root if they do not already exist:

**`sync.ps1`** — copy from the BaseCoat source repo at the pinned version:

```powershell
# Pull sync.ps1 from BaseCoat at the pinned version
$basecoatRef = "$basecoat_version"   # e.g. "v0.6.0" or "main"
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/ivegamsft/basecoat/$basecoatRef/sync.ps1" `
  -OutFile "sync.ps1"
```text

**`sync.sh`** — same approach:

```bash
curl -fsSL \
  "https://raw.githubusercontent.com/ivegamsft/basecoat/$basecoat_version/sync.sh" \
  -o sync.sh
chmod +x sync.sh
```text

**`setup.ps1`** — bootstrap script that runs the BaseCoat sync and any first-time setup:

```powershell
$ErrorActionPreference = 'Stop'

Write-Host '--- Project Setup ---'

# 1. Sync BaseCoat governance framework
Write-Host 'Syncing BaseCoat...'
& "$PSScriptRoot\sync.ps1"

# 2. Install pre-commit hooks (if .githooks exists after sync)
$hooksDir = Join-Path $PSScriptRoot '.githooks'
if (Test-Path $hooksDir) {
    git config core.hooksPath .githooks
    Write-Host 'Git hooks configured.'
}

Write-Host 'Setup complete.'
```text

**`.gitignore`** — standard ignore list with secrets protection:

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
*.suo
*.user
*.swp

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
```text

**`README.md`** — project readme with Getting Started section:

````markdown
# $repo_name

$repo_description

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [GitHub CLI (`gh`)](https://cli.github.com/) — authenticated
- PowerShell 7+ (Windows/macOS/Linux) or Bash

### Initial Setup

1. Clone the repository:

   ```bash
   gh repo clone $github_org/$repo_name
   cd $repo_name
   ```text

2. Run the setup script to sync BaseCoat governance and configure hooks:

   **PowerShell:**
   ```powershell
   .\setup.ps1
   ```text

   **Bash:**
   ```bash
   ./sync.sh
   ```text

3. Start working — all governance instructions, agents, and skills are now available under `.github/base-coat/`.

### Keeping BaseCoat Up to Date

Re-run the sync script at any time to pull the latest BaseCoat version:

```powershell
.\sync.ps1
```text

Or pin to a specific release tag:

```powershell
$env:BASECOAT_REF = "v0.6.0"
.\sync.ps1
```text

## Contributing

See `.github/base-coat/instructions/basecoat-20-lang-governance.instructions.md` for the full governance framework.

## License

See [LICENSE](LICENSE) for details.
````

### 4. Sync BaseCoat into `.github/base-coat/`

Use `sync.ps1` to pull the governance framework at the pinned version. This is the canonical sync mechanism — never copy files manually.

```powershell
$env:BASECOAT_REPO = 'https://github.com/ivegamsft/basecoat.git'
$env:BASECOAT_REF  = "$basecoat_version"
.\sync.ps1
```text

Verify the sync produced the expected structure:

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
```text

### 5. Configure Issue Templates

Create `.github/ISSUE_TEMPLATE/` with two templates if the directory does not already exist:

**`.github/ISSUE_TEMPLATE/feature.yml`**:

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
      description: How will we know this is done?
    validations:
      required: true
```text

**`.github/ISSUE_TEMPLATE/bug.yml`**:

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
```text

### 6. Log the First Sprint Issue

Create a GitHub issue for the sprint-1 goal with acceptance criteria:

```bash
gh issue create \
  --repo "$github_org/$repo_name" \
  --title "Sprint 1: $sprint_1_goal" \
  --label "sprint-1" \
  --body "## Sprint 1 Goal

$sprint_1_goal

## Acceptance Criteria

- [ ] Implementation complete and passing tests
- [ ] Code reviewed via PR
- [ ] No secrets committed
- [ ] Documentation updated in README or docs/

## Context

Created by the project-onboarding agent during initial repo setup."
```text

### 7. Commit and Push

Stage all scaffolded files, commit with a conventional message, and push:

```bash
git add -A
git commit -m "feat: initial project scaffolding with BaseCoat integration

- Synced BaseCoat governance framework
- Added sync.ps1, sync.sh, setup.ps1
- Configured .gitignore with secrets protection
- Added issue templates (feature + bug)
- Created README with Getting Started section

Ref #<sprint-1-issue-number>"

git push origin main
```text

> **Note:** This initial scaffolding commit is the one exception where a direct push to `main` is acceptable — the repo has no branch protection yet and no prior history. All subsequent changes must follow the PR workflow per `governance.instructions.md`.

## Output Report

After completion, report the following:

| Item | Status |
|---|---|
| Repository | `$github_org/$repo_name` — created or already existed |
| Visibility | `$visibility` |
| BaseCoat version | `$basecoat_version` synced into `.github/base-coat/` |
| Sync mechanism | `sync.ps1` / `sync.sh` at repo root |
| Setup script | `setup.ps1` at repo root |
| `.gitignore` | Configured with secrets protection |
| Issue templates | `.github/ISSUE_TEMPLATE/feature.yml`, `bug.yml` |
| Sprint-1 issue | `#<number>` — "$sprint_1_goal" |
| README | Created with Getting Started section |

### Files Created

```text
$repo_name/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── feature.yml
│   │   └── bug.yml
│   └── base-coat/          ← synced via sync.ps1
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── INVENTORY.md
│       ├── version.json
│       ├── instructions/
│       ├── skills/
│       ├── prompts/
│       └── agents/
├── .gitignore
├── README.md
├── setup.ps1
├── sync.ps1
└── sync.sh
```text

### Next Steps

1. Enable branch protection on `main` (require PR reviews, status checks).
2. Add CI workflows as needed (lint, build, test).
3. Begin Sprint 1 — work from the sprint-1 issue created above.
4. Run `.\sync.ps1` periodically to pick up BaseCoat updates.

## Idempotency

This agent is safe to re-run on an existing repository:

- **Repo creation** — skipped if the repo already exists; clones instead.
- **Root files** — only written if they do not already exist; existing files are preserved.
- **BaseCoat sync** — `sync.ps1` replaces the `.github/base-coat/` directory cleanly on each run.
- **Issue templates** — only created if the `.github/ISSUE_TEMPLATE/` directory is missing.
- **Sprint-1 issue** — a new issue is created each run. Check for duplicates before re-running if this is undesirable.

## Model

**Recommended:** claude-sonnet-4.6
**Rationale:** Repo scaffolding decisions and sprint goal decomposition need good reasoning depth
**Minimum:** claude-haiku-4.5

## Governance

This agent operates under the BaseCoat governance framework.

- **Issue-first**: Do not make code changes without a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a PR, self-approve if needed.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feature/<issue-number>-<short-description>` or `fix/<issue-number>-<short-description>`
- See `instructions/basecoat-20-lang-governance.instructions.md` for the full governance reference.
