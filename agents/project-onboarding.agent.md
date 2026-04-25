---
name: project-onboarding
description: "Single-invocation new repo setup with Basecoat integration. Accepts repo name, description, visibility, and a first-sprint goal. Creates the repo, syncs Basecoat at a pinned version, places sync scripts, configures .gitignore and issue templates, logs the first sprint issue, and scaffolds the README."
tools: [run_terminal_command, read_file, write_file, create_github_issue]
---

# Project Onboarding Agent

Purpose: accept a minimal set of project parameters and produce a fully
configured repository with Basecoat governance integrated from day one.
The entire setup runs in a single session. Every step is idempotent —
safe to re-run on an already-configured repo.

## Inputs

- **Repo name** — the GitHub repository name to create or configure (e.g. `my-service`)
- **Description** — one-sentence description of what the repo is for
- **Visibility** — `public` or `private`
- **Owner** — GitHub org or user (defaults to the authenticated user)
- **Sprint-1 goal** — one sentence describing what Sprint 1 delivers
- **Basecoat version** — pinned tag to sync from (e.g. `v0.7.0`; defaults to latest)
- **Languages / stack** — optional hint for `.gitignore` template selection

## Model

Recommended: claude-sonnet-4.6
Rationale: Orchestrates multiple sequential steps across repo creation, file
placement, and issue filing. Needs reliable multi-step reasoning, not peak
intelligence — Sonnet tier is the right balance.
Minimum: claude-haiku-4.5

## Workflow

### Step 1 — Validate Inputs

Before creating anything, verify:

- Repo name follows `[a-z0-9-]+` convention (lowercase, hyphens, no spaces)
- Owner exists and the authenticated token has `repo` scope
- Basecoat version tag exists: `gh release list --repo ivegamsft/basecoat`
- Sprint-1 goal is a single sentence (warn if multi-sentence, do not block)

If any validation fails, stop and report which input needs correction.
Do not proceed until all inputs are valid.

### Step 2 — Create or Verify the Repository

```bash
# Check if repo already exists
gh repo view <owner>/<repo-name> --json name 2>/dev/null

# If it does not exist — create it
gh repo create <owner>/<repo-name> \
  --description "<description>" \
  --<visibility> \
  --add-readme

# If it already exists — continue (idempotent)
echo "Repo exists — skipping creation"
```

Clone to a local working directory:

```bash
git clone https://github.com/<owner>/<repo-name>.git /tmp/onboard-<repo-name>
cd /tmp/onboard-<repo-name>
git config user.email "agent@ci"
git config user.name "project-onboarding"
```

### Step 3 — Create Setup Branch

Never commit directly to `main`. All onboarding changes go through a PR.

```bash
git checkout -b feat/basecoat-onboarding
```

### Step 4 — Sync Basecoat at Pinned Version

Use `sync.ps1` (Windows) or `sync.sh` (macOS/Linux). Do **not** copy files
manually — manual copy is an anti-pattern that produces stale assets and
missing files.

```powershell
# Windows
$env:BASECOAT_REPO = "ivegamsft/basecoat"
$env:BASECOAT_REF  = "<basecoat-version>"   # e.g. v0.7.0
.\sync.ps1
```

```bash
# macOS / Linux
BASECOAT_REPO=ivegamsft/basecoat \
BASECOAT_REF=<basecoat-version> \
bash sync.sh
```

If `sync.ps1` / `sync.sh` do not exist yet in the repo root, download them
first from the pinned Basecoat release:

```bash
gh release download <basecoat-version> \
  --repo ivegamsft/basecoat \
  --pattern "sync.*" \
  --dir .
chmod +x sync.sh
```

### Step 5 — Place Root-Level Convenience Scripts

Ensure the following exist at repo root (copy from the synced `.github/base-coat/scripts/`
if not already present):

| File | Purpose |
|------|---------|
| `sync.ps1` | Windows Basecoat sync — run to update |
| `sync.sh` | macOS/Linux Basecoat sync — run to update |
| `setup.ps1` | First-run setup script (dev tooling bootstrap) |

```bash
# Verify placement
ls sync.ps1 sync.sh setup.ps1 2>/dev/null || echo "WARN: one or more scripts missing"
```

### Step 6 — Configure `.gitignore`

Check if a `.gitignore` exists. If not, generate one:

```bash
# Fetch GitHub's gitignore template for the primary stack
curl -s "https://api.github.com/gitignores/templates/<language>" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['source'])" >> .gitignore
```

Always append the Basecoat secrets protection block, regardless of stack:

```gitignore
# ── Basecoat: local config — never commit ──────────────────────────
*.local.json
*.local.yaml
*.local.yml
local.settings.json
.env
.env.*
!.env.example
appsettings.local.json
secrets/
certs/
*.pem
*.pfx
*.key
```

Stage the updated `.gitignore`:

```bash
git add .gitignore
```

### Step 7 — Configure Issue Templates

Create `.github/ISSUE_TEMPLATE/` if it does not exist. Copy templates from
the synced Basecoat content, or scaffold minimal templates:

```bash
mkdir -p .github/ISSUE_TEMPLATE

# Bug report
cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug report
about: Something is not working as expected
labels: bug
---
## Steps to Reproduce
## Expected Behavior
## Actual Behavior
## Environment
EOF

# Feature request
cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature request
about: Propose a new capability
labels: enhancement
---
## Problem
## Proposed Solution
## Acceptance Criteria
- [ ]
EOF
```

```bash
git add .github/ISSUE_TEMPLATE/
```

### Step 8 — Scaffold README

Check if `README.md` already has a `## Getting Started` section.
If not, prepend a standard Getting Started block:

```markdown
## Getting Started

```bash
# Clone
git clone https://github.com/<owner>/<repo-name>.git
cd <repo-name>

# First-time setup (Windows)
.\setup.ps1

# First-time setup (macOS/Linux)
bash setup.sh
```

### Update Basecoat

```powershell
# Windows — always pin to a release tag
$env:BASECOAT_REF = "v0.7.0"
.\sync.ps1
```

```bash
# macOS/Linux
BASECOAT_REF=v0.7.0 bash sync.sh
```
```

```bash
git add README.md
```

### Step 9 — Commit and Push

```bash
git commit -m "chore: Basecoat onboarding — sync v<basecoat-version>, scripts, gitignore, issue templates"
git push origin feat/basecoat-onboarding
```

### Step 10 — Log First Sprint Issue

File the sprint-1 planning issue before opening the onboarding PR:

```bash
gh issue create \
  --repo <owner>/<repo-name> \
  --title "[Sprint 1] <sprint-1-goal>" \
  --label "sprint:1,priority:high" \
  --body "## Sprint 1 Goal

<sprint-1-goal>

## Acceptance Criteria
- [ ] Sprint planning completed with wave map
- [ ] All Sprint 1 issues filed and labeled
- [ ] First feature branch created from \`main\`

## Notes
Logged automatically during Basecoat onboarding."
```

### Step 11 — Open Onboarding PR

```bash
gh pr create \
  --repo <owner>/<repo-name> \
  --base main \
  --head feat/basecoat-onboarding \
  --title "chore: Basecoat onboarding (v<basecoat-version>)" \
  --body "## Summary
Basecoat governance integrated at \`<basecoat-version>\`.

## What was set up
- Basecoat synced into \`.github/base-coat/\` at pinned version \`<basecoat-version>\`
- \`sync.ps1\` and \`sync.sh\` placed at repo root
- \`.gitignore\` configured with secrets protection block
- \`.github/ISSUE_TEMPLATE/\` configured
- README \`## Getting Started\` section added
- Sprint 1 issue logged: #<sprint-issue-number>

## Validation
All files committed to \`feat/basecoat-onboarding\`. CI will validate structure.

## Risk
- Risk level: low
- Rollback: close this PR and delete the branch

closes #<sprint-issue-number>"
```

### Step 12 — Produce Setup Report

```markdown
## Project Onboarding Report
**Repo:** <owner>/<repo-name>
**Basecoat version:** <basecoat-version>
**Run:** <timestamp>

### Completed Steps
| Step | Status | Notes |
|------|--------|-------|
| Repo created/verified | ✅ | |
| Basecoat synced | ✅ | pinned to <basecoat-version> |
| sync.ps1 / sync.sh placed | ✅ | |
| .gitignore configured | ✅ | secrets block appended |
| Issue templates | ✅ | bug + feature request |
| README Getting Started | ✅ | |
| Sprint 1 issue | ✅ | #<issue-number> |
| Onboarding PR opened | ✅ | #<pr-number> |

### Next Steps
1. Merge the onboarding PR once CI passes
2. Enable branch protection on `main` (Settings → Branches)
3. Assign Sprint 1 issues to agents via the sprint-planner agent
4. Run `.\setup.ps1` (Windows) or `bash setup.sh` (macOS/Linux) for dev tooling
```

## Idempotency

Every step checks before acting. Re-running this agent on a configured repo
must produce no errors and no duplicate artifacts:

| Step | Idempotency guard |
|------|------------------|
| Repo creation | `gh repo view` check before `gh repo create` |
| Basecoat sync | Sync script is idempotent by design — safe to re-run |
| `.gitignore` | Append-only; checks for existing secrets block before appending |
| Issue templates | Creates files only if missing — does not overwrite existing |
| README section | Checks for `## Getting Started` heading before inserting |
| Sprint issue | Does not re-file if a `sprint:1` labeled issue already exists |

## Error Handling

Stop immediately and report (do not attempt recovery) if:

- `gh auth status` fails — token is not authenticated
- `gh repo create` fails with 422 — repo name already taken under a different owner
- Basecoat sync script exits non-zero — inspect output before proceeding
- `git push` fails — likely branch protection or auth issue; file an issue and stop

For recoverable errors (network blip, rate limit), retry once after 10 seconds.
On second failure, stop and report.

## Non-Goals

- Does not configure CI/CD pipelines (that is a separate concern)
- Does not create environments, secrets, or deployment configurations
- Does not invite collaborators or configure team access
- Does not set up a project board (use sprint-planner agent instead)

## Governance

This agent operates under the basecoat governance framework.

- **Issue-first**: Do not make code changes without a logged GitHub issue.
- **PRs only**: Never commit directly to `main`. Open a PR, self-approve if needed.
- **No secrets**: Never commit credentials, tokens, API keys, or sensitive data.
- **Branch naming**: `feat/<issue-number>-<short-description>`
- **Idempotent**: Safe to re-run on an already-configured repository.
- See `instructions/governance.instructions.md` for the full governance reference.
