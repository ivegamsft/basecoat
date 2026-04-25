# Secret Scanning — Setup & Runbook

> **Part of:** basecoat Enterprise Governance Framework · Issue #43 · Sprint 5 / v1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Installing Gitleaks Locally](#installing-gitleaks-locally)
3. [Installing the Pre-Commit Hook](#installing-the-pre-commit-hook)
4. [How the CI Workflow Works](#how-the-ci-workflow-works)
5. [Allowlisting False Positives](#allowlisting-false-positives)
6. [I Accidentally Committed a Secret — Now What?](#i-accidentally-committed-a-secret--now-what)
7. [Configuration Reference](#configuration-reference)

---

## Overview

Basecoat implements a **defence-in-depth** approach to secret scanning:

| Layer | Tool | Enforcement | Description |
|-------|------|-------------|-------------|
| **Local pre-commit** | gitleaks | 🔴 **Blocks commit** | First line of defence — scans staged changes before commit reaches the remote |
| **CI / PR scan** | gitleaks (GitHub Actions) | 🟡 **Warn only** | Annotates PRs and surfaces findings; never blocks a merge |

> **Why warn-only CI?**
> Enterprise GitHub policy may override required status checks or the
> `GitHub Advanced Security` licence may be restricted. We cannot rely on CI
> blocking as an enterprise-proof gate. The pre-commit hook IS the enforcer.

---

## Installing Gitleaks Locally

### macOS

```bash
# Homebrew (recommended)
brew install gitleaks

# Verify
gitleaks version
```

### Linux

```bash
# Automatic via install script (see next section)
bash scripts/install-hooks.sh

# Manual
GITLEAKS_VERSION=8.18.4
curl -sSfL \
  "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
  | tar -xz -C /usr/local/bin gitleaks

gitleaks version
```

### Windows

```powershell
# winget
winget install gitleaks

# OR Scoop
scoop install gitleaks

# OR Chocolatey
choco install gitleaks
```

Then run the hook installer from **Git Bash** or **WSL2** (see below).

### Verify installation

```bash
gitleaks version
# Expected: v8.x.x or later
```

---

## Installing the Pre-Commit Hook

The `install-hooks.sh` script installs gitleaks as a **pre-commit** git hook.
Run it once per cloned repo. It will also auto-install gitleaks if it is not found.

```bash
# From repo root (macOS / Linux / Git Bash / WSL2)
bash scripts/install-hooks.sh

# Specify a different repo path
bash scripts/install-hooks.sh /path/to/your/repo

# Use .git/hooks/pre-commit instead of core.hooksPath (advanced)
HOOK_STRATEGY=pre_commit_file bash scripts/install-hooks.sh
```

### What the script does

1. Detects your OS and architecture.
2. Installs gitleaks if it is not already on `$PATH` (Homebrew on macOS,
   direct download on Linux).
3. Writes a `pre-commit` script to `.githooks/pre-commit`.
4. Sets `git config core.hooksPath .githooks` so git uses that directory.
5. Runs a quick verification scan.

### Windows (native PowerShell)

The installer is a bash script. Windows users should either:

- Use **WSL2** or **Git Bash** to run `bash scripts/install-hooks.sh`, or
- Install gitleaks manually via `winget install gitleaks`, then add a
  `pre-commit` hook manually (see the hook script inside `install-hooks.sh`
  for the template).

### Testing the hook

```bash
# Stage a dummy secret and verify the hook fires
echo 'MY_SECRET="AKIAIOSFODNN7EXAMPLE"' > /tmp/test-secret.txt
git add /tmp/test-secret.txt
git commit -m "test"   # <-- should be BLOCKED by the hook

# Clean up
git rm --cached /tmp/test-secret.txt
rm /tmp/test-secret.txt
```

### Emergency bypass (use sparingly!)

```bash
git commit --no-verify -m "your message"
```

> ⚠️ Only use `--no-verify` if you are certain there is no real secret and you
> have a documented reason (e.g., CI false-positive coordination, hotfix under
> incident). Log the bypass in your PR description.

---

## How the CI Workflow Works

File: `.github/workflows/secret-scan.yml`

### Triggers

- Every **pull request** (all branches → any target)
- Every **push to `main`**
- Manual dispatch via `workflow_dispatch`

### Steps

1. **Checkout** full history (needed for commit-range diffing).
2. **Install gitleaks** (pinned version for reproducibility).
3. **Run scan** over the PR's commit range (or pushed range on `main`).
4. **Post PR comment** with a summary — either ✅ all-clear or ⚠️ findings.
5. **Upload `gitleaks-report.json`** as a workflow artifact (90-day retention).
6. **Exit 0** unconditionally — this check **never** blocks a merge.

### Reading the report

1. Open the PR → **Checks** tab → **Secret Scanning (warn only)**.
2. Expand the workflow summary for a human-readable list.
3. Download the `gitleaks-report` artifact for the full JSON finding list.

```json
// Example finding in gitleaks-report.json
{
  "RuleID": "generic-api-key",
  "File": "config/settings.js",
  "StartLine": 14,
  "EndLine": 14,
  "Secret": "REDACTED",
  "Commit": "abc123...",
  "Author": "Dev Name",
  "Date": "2026-04-25T10:00:00Z",
  "Message": "feat: add config"
}
```

---

## Allowlisting False Positives

Gitleaks sometimes flags test data, example tokens, or documentation snippets
that are not real secrets. Use `.gitleaks.toml` to suppress them.

### Approach 1 — Path-based allowlist (recommended for test fixtures)

```toml
# .gitleaks.toml
[allowlist]
paths = [
  '''(^|/)tests?/fixtures/''',
  '''(^|/)docs/examples/''',
]
```

### Approach 2 — Regex-based allowlist (suppress a specific pattern)

```toml
[allowlist]
regexes = [
  # Our internal mock token format used in unit tests
  '''MOCK_TOKEN_[0-9]{4}''',
]
```

### Approach 3 — Commit-based allowlist (one-off suppression)

```toml
[allowlist]
commits = [
  "abc123def456...",   # commit SHA that introduced known test data
]
```

### Approach 4 — Inline `gitleaks:allow` comment

Add a comment on the same line as the false positive:

```javascript
// This is a test value — not a real secret
const exampleKey = "AKIAIOSFODNN7EXAMPLE"; // gitleaks:allow
```

> **Best practice:** prefer adding to `.gitleaks.toml` so the allowlist is
> visible, reviewable, and consistent across the team. Inline comments are
> fine for one-off cases but can accumulate noise.

### After adding an allowlist entry

```bash
# Verify the allowlist works
gitleaks detect --config .gitleaks.toml --source . --log-opts HEAD~1..HEAD

# Stage and commit the .gitleaks.toml change
git add .gitleaks.toml
git commit -m "fix(security): allowlist false positive in .gitleaks.toml [#43]"
```

---

## I Accidentally Committed a Secret — Now What?

> 🚨 **Treat every accidentally committed secret as compromised, regardless of
> whether the branch is public or private.** Rotate the credential first, then
> clean history.

### Step 1 — Rotate the credential IMMEDIATELY

Before doing anything else, invalidate the secret so it is useless to any
attacker who may have seen it:

| Secret type | How to rotate |
|-------------|---------------|
| GitHub PAT / token | GitHub → Settings → Developer settings → Personal access tokens → Delete & regenerate |
| AWS access key | AWS IAM → Users → Security credentials → Deactivate & create new |
| Azure service principal | Azure Portal → Entra ID → App registrations → Certificates & secrets → Delete & create new |
| Azure Storage key | Azure Portal → Storage account → Access keys → Rotate |
| npm / PyPI token | Package registry settings → Revoke token |
| Database password | Database admin console → ALTER USER / rotate password |
| Generic API key | Provider dashboard → Revoke & regenerate |

**Do not skip this step.** History rewriting takes time; the attacker may have
already cloned the repo.

### Step 2 — Assess exposure

- Was the branch ever pushed to a remote? If yes, assume the secret is exposed.
- Was a PR opened? GitHub caches PR diffs — even after force-push, the diff may
  be viewable. Contact GitHub Support if the PR is public.
- Check your git provider's audit log for clone/fork activity.

### Step 3 — Remove from git history

**Option A — Only in the last commit (not yet pushed)**

```bash
git reset HEAD~1              # undo last commit, keep changes staged
# edit the file to remove the secret
git add <file>
git commit -m "fix: remove secret [#43]"
```

**Option B — In recent commits (already pushed, no public forks)**

```bash
# Use git-filter-repo (recommended over BFG for modern repos)
pip install git-filter-repo

# Remove the specific file containing the secret
git filter-repo --path <secret-file> --invert-paths

# OR replace the specific string with a placeholder
git filter-repo --replace-text <(echo 'ACTUAL_SECRET_VALUE==>REDACTED')

# Force-push all branches (⚠️ coordinates with teammates first)
git push origin --force --all
git push origin --force --tags
```

**Option C — Secret deep in history or in public forks**

Contact your security team. Options include:
- GitHub repository security advisory
- GitHub Support for cache purge (public repos)
- BFG Repo Cleaner: `java -jar bfg.jar --replace-text <patterns-file>`

### Step 4 — Verify the secret is gone

```bash
# Run gitleaks over the full history
gitleaks detect --config .gitleaks.toml --source . --log-opts HEAD

# Also search git objects (catches unreachable commits)
git log --all --full-history -- "**/<filename>"
```

### Step 5 — Notify stakeholders

- Security team: file an incident ticket.
- Repository owners: note the force-push and history rewrite.
- Affected service owners: confirm the rotated credential is working.

### Step 6 — Post-incident review

Add a `.gitleaks.toml` allowlist or strengthen your local hook configuration
to prevent the same class of secret from being committed again.

---

## Configuration Reference

| File | Purpose |
|------|---------|
| `.gitleaks.toml` | Gitleaks config: custom rules, allowlists, entropy tuning |
| `.github/workflows/secret-scan.yml` | CI workflow — warn-only scanning |
| `scripts/install-hooks.sh` | Local pre-commit hook installer |
| `docs/security/SECRET_SCANNING.md` | This file |
| `docs/security/BRANCH_PROTECTION.md` | Branch protection recommendations |

### Updating gitleaks version

1. Edit the `GITLEAKS_VERSION` environment variable in `.github/workflows/secret-scan.yml`.
2. Edit the default in `scripts/install-hooks.sh` (`GITLEAKS_VERSION="${GITLEAKS_VERSION:-X.Y.Z}"`).
3. Re-run `bash scripts/install-hooks.sh` on developer machines.

### Running a full-history scan

```bash
# Scan entire repo history (slow on large repos — run once during setup)
gitleaks detect --config .gitleaks.toml --source . --log-opts ""

# Scan only since a specific tag
gitleaks detect --config .gitleaks.toml --source . --log-opts "v0.5.0..HEAD"
```

---

> **Maintainer:** Security tooling owned by the security_analyst squad agent.
> Issues → [#43](https://github.com/ivegamsft/basecoat/issues/43)
