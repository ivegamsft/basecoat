# PRODUCTION_REPO_TOKEN Setup Guide

## Overview

The `PRODUCTION_REPO_TOKEN` is a fine-grained Personal Access Token (PAT) that authenticates the `BaseCoat - Publish to Production` workflow when syncing releases from the internal `IBuySpy-Shared/basecoat` repository to the public production mirror at `ivegamsft/basecoat`.

**Status:** Issue #1352 — Token currently lacks push access, blocking releases.

---

## Problem

The current `PRODUCTION_REPO_TOKEN` has `permissions.push=False`, preventing the publish workflow from pushing to `ivegamsft/basecoat`.

**Symptoms:**
- Workflow `BaseCoat - Publish to Production` fails at the `Push to production repository` step
- Error: `PRODUCTION_REPO_TOKEN cannot push to ivegamsft/basecoat (permissions.push=False)`
- Release cannot reach the production mirror

**Root Cause:**
Fine-grained PATs are scoped to their **resource owner**. The current token was likely created by an IBuySpy-Shared org member. Only the `ivegamsft` account owner can create a token with access to the `ivegamsft/basecoat` repository.

---

## Solution: Generate a New Token (Action Required by ivegamsft Account Owner)

### Step 1: Sign In as ivegamsft

1. Go to [github.com](https://github.com)
2. Sign out of any current account
3. Sign in as **ivegamsft** (the account that owns the production mirror)

### Step 2: Create a Fine-Grained PAT

1. Click your profile icon → **Settings**
2. Left sidebar → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
3. Click **Generate new token**
4. Fill in the token details:

| Field | Value |
|-------|-------|
| **Token name** | `BaseCoat PRODUCTION_REPO_TOKEN` |
| **Description** (optional) | "Syncs releases from IBuySpy-Shared/basecoat to ivegamsft/basecoat" |
| **Resource owner** | `ivegamsft` ⚠️ **MUST be ivegamsft, not IBuySpy-Shared** |
| **Repository access** | Only select repositories |
| **Select repositories** | `ivegamsft/basecoat` (the production mirror) |
| **Permissions** | See table below |
| **Expiration** | 90 days (recommended for security) |

### Step 3: Set Required Permissions

Select **Repository Permissions** and configure:

| Permission | Setting |
|-----------|---------|
| **Contents** | ✓ Read and write |
| **Administration** | ✓ Read and write |
| **Workflows** | ✓ Read and write |

All other permissions can remain unchecked (not applicable for this workflow).

**Why these permissions?**
- **Contents**: Push commits and create releases
- **Administration**: Temporarily disable/restore branch protection during force-push
- **Workflows**: Update GitHub Actions workflows in the production repo (if needed)

### Step 4: Generate Token

1. Click **Generate token**
2. **Copy the token immediately** — GitHub will not show it again
3. Keep it safe (do not commit to source control or paste in issues)

### Step 5: Validate the Token (Optional but Recommended)

Before setting it as a secret, validate that the token has the correct permissions:

**Bash:**
```bash
export PRODUCTION_REPO_TOKEN="ghp_YourTokenHere"
bash scripts/validate-production-token.sh
```

**PowerShell:**
```powershell
.\scripts\validate-production-token.ps1 -Token "ghp_YourTokenHere"
```

**Manual verification (curl):**
```bash
curl -s -H "Authorization: token ghp_YourTokenHere" \
  https://api.github.com/repos/ivegamsft/basecoat | \
  jq '.permissions'

# Expected output:
# {
#   "push": true,
#   "pull": true,
#   "admin": true
# }
```

### Step 6: Set the Secret in IBuySpy-Shared/basecoat

Once the token is validated, add it as a repository secret in IBuySpy-Shared/basecoat:

```bash
gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat
# When prompted, paste the token value
```

Alternatively, using the GitHub UI:
1. Go to `https://github.com/IBuySpy-Shared/basecoat`
2. Settings → Secrets and variables → Actions
3. Click **New repository secret**
4. Name: `PRODUCTION_REPO_TOKEN`
5. Secret: Paste the token value
6. Click **Add secret**

### Step 7: Re-run the Publish Workflow

Once the secret is set, re-trigger the publish workflow for the stuck release:

**From CLI:**
```bash
gh workflow run publish-to-production.yml --repo IBuySpy-Shared/basecoat --ref v3.30.6
```

**From GitHub UI:**
1. Go to `https://github.com/IBuySpy-Shared/basecoat/actions`
2. Find **BaseCoat - Publish to Production**
3. Click **Run workflow** → Select branch/tag and run

### Step 8: Verify Success

The workflow should now complete successfully:

- ✅ `preflight-token-check` passes (token validates)
- ✅ `publish` job runs without permission errors
- ✅ Commits pushed to `ivegamsft/basecoat`
- ✅ Release tag synced
- ✅ GitHub release created on production mirror
- ✅ Branch protection restored

---

## Troubleshooting

### Token Validation Fails

If the validation script or workflow preflight fails, check:

1. **Token not signed in by ivegamsft?**
   - Delete the current token
   - Sign in as `ivegamsft` (not IBuySpy-Shared org member)
   - Create a new token with `ivegamsft` as resource owner

2. **Repository access misconfigured?**
   - Verify token's "Repository access" includes `ivegamsft/basecoat`
   - Check if token permissions include Contents, Administration, Workflows (RW)

3. **Token expired?**
   - Check GitHub token settings: Settings → Developer settings → Fine-grained tokens
   - If expired, generate a new one

4. **Still getting permission errors?**
   - Token may be revoked; create a new one
   - Verify no other agents are overwriting the secret with an old token

### Workflow Still Fails After Secret Update

1. **Ensure secret was updated in the correct repository:**
   ```bash
   gh secret list --repo IBuySpy-Shared/basecoat | grep PRODUCTION_REPO_TOKEN
   ```

2. **Check workflow preflight logs:**
   ```bash
   gh run list --repo IBuySpy-Shared/basecoat --workflow publish-to-production.yml --limit 1
   ```

3. **Verify token is accessible in workflow:**
   ```bash
   # Re-run the token preflight check manually
   gh workflow run token-preflight.yml --repo IBuySpy-Shared/basecoat
   ```

---

## Security Best Practices

1. **Token Scope:** Fine-grained tokens are scoped to a single repository (`ivegamsft/basecoat`), limiting blast radius if leaked.

2. **Permissions:** Only the minimum required permissions are granted:
   - Contents (push commits/releases)
   - Administration (manage branch protection)
   - Workflows (GitHub Actions only, not repo workflows)

3. **Expiration:** Token expires after 90 days, requiring periodic renewal and reducing long-term exposure.

4. **Rotation:** If the token is ever suspected to be compromised:
   - Delete the token immediately
   - Generate a new one
   - Update the secret: `gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat`

---

## Related Issues & Documentation

- **Issue #1352** — This issue (token lacks push access, blocking releases)
- **Issue #575** — Original token setup guidance (closed, regex applied)
- **Issue #1353** — Enhancement: add preflight gate to catch similar failures
- **Workflow:** `.github/workflows/publish-to-production.yml`
- **Validation Helper:** `scripts/validate-production-token.sh` (bash) | `scripts/validate-production-token.ps1` (PowerShell)

---

## FAQs

**Q: Why does the token need to be owned by ivegamsft, not IBuySpy-Shared?**
A: Fine-grained PATs are scoped to their resource owner. GitHub will not grant access to another user's repositories to a token owned by an organization. The `ivegamsft` account must own the token to authenticate against `ivegamsft/basecoat`.

**Q: Can I use a classic PAT instead of a fine-grained token?**
A: Not recommended. Classic PATs grant access to all repositories owned by the user, violating the principle of least privilege. Fine-grained tokens are scoped to a single repository, making them more secure.

**Q: How often does the token need to be renewed?**
A: The token is set to expire after 90 days. GitHub will not notify when it expires — the workflow will simply fail at the preflight step. Plan to rotate the token every 90 days.

**Q: What if I accidentally commit the token to the repository?**
A: GitHub's secret scanning should flag it. Immediately:
1. Delete the token from GitHub (Settings → Developer settings → Fine-grained tokens)
2. Generate a new one
3. Update the secret in IBuySpy-Shared/basecoat
4. Rotate any affected systems

**Q: Can multiple workflows use the same PRODUCTION_REPO_TOKEN?**
A: Yes, any workflow that needs to push to `ivegamsft/basecoat` can use the same token. The token is stored as a repository secret, accessible to all workflows.

**Q: Who can set the secret in IBuySpy-Shared/basecoat?**
A: Anyone with Admin or Maintain access to the IBuySpy-Shared/basecoat repository can set repository secrets via GitHub UI or CLI.

---

**Document Owner:** BaseCoat Platform Team  
**Last Updated:** 2026-06-25  
**Next Review:** 2026-07-25 (Monthly)
