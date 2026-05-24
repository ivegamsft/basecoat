# Setting Up Basecoat Memory Contributions — External Orgs

This guide is for teams **outside the IBuySpy-Shared org** who want to
contribute learnings to basecoat memory from their own organization's repos.

## Overview

External contributors need to:

1. Create a personal access token (PAT) with write access to `basecoat-memory` and expiration set to 30 days or less
2. Store it as a secret in their org or repo
3. Enlist their repo with the `basecoat-enabled` topic
4. Choose a contribution path

## Prerequisites

- A GitHub account with access to the `IBuySpy-Shared` org
  (contact an IBuySpy-Shared admin if you need access)
- The `gh` CLI installed, or access to GitHub's web UI

## Step 1 — Create a PAT

1. Go to <https://github.com/settings/personal-access-tokens/new>
2. Set **Resource owner** to **IBuySpy-Shared**
   *(requires org membership — ask an IBuySpy-Shared admin if needed)*
3. **Repository access**: Only select repositories → `IBuySpy-Shared/basecoat-memory`
4. **Permissions**:
   - Contents: **Read and Write**
   - Pull requests: **Read and Write**
   - Metadata: Read (implicit)
5. Set PAT expiry to **30 days or less** and note the renewal date
6. Click **Generate token** — copy it immediately

## Step 2 — Store the Secret

### Option A — Org-level secret (recommended if enlisting multiple repos)

Store once, all org repos inherit it:

```sh
gh secret set MEMORY_REPO_TOKEN \
  --org YOUR_ORG \
  --visibility all \
  --body "ghp_..."
```

Or via the GitHub UI:
`https://github.com/organizations/YOUR_ORG/settings/secrets/actions`

### Option B — Per-repo secret

If you only have one repo to enlist:

```sh
gh secret set MEMORY_REPO_TOKEN \
  --repo YOUR_ORG/YOUR_REPO \
  --body "ghp_..."
```

Or via the GitHub UI:
`https://github.com/YOUR_ORG/YOUR_REPO/settings/secrets/actions`

## Step 3 — Enlist Your Repo

```sh
bash <(curl -fsSL \
  https://raw.githubusercontent.com/IBuySpy-Shared/basecoat/main/scripts/onboard-basecoat.sh) \
  --repo YOUR_ORG/YOUR_REPO
```

This adds the `basecoat-enabled` topic and creates the three learning labels.

Verify enlistment:

```sh
gh api "search/repositories?q=topic:basecoat-enabled+org:YOUR_ORG" \
  --jq '.items[].full_name'
```

## Step 4 — Choose a Contribution Path

### Passive (zero ongoing effort)

Label merged PRs or closed issues `learning`, `retrospective`, or `decision`.
The weekly sweep picks them up automatically.

### Active push via callable workflow

Copy this to `.github/workflows/submit-learning.yml` in your repo:

```yaml
name: Submit learning to basecoat
on:
  workflow_dispatch:
    inputs:
      subject:  { required: true,  type: string, description: "domain:key" }
      fact:     { required: true,  type: string, description: "Pattern (≤ 300 chars)" }
      evidence: { required: true,  type: string, description: "Evidence URL" }
      domain:
        required: true
        type: choice
        options: [ci, git, authoring, process, security, portal, testing, governance, memory, infra]

jobs:
  submit:
    uses: IBuySpy-Shared/basecoat/.github/workflows/submit-learning-callable.yml@main
    with:
      subject:  ${{ inputs.subject }}
      fact:     ${{ inputs.fact }}
      evidence: ${{ inputs.evidence }}
      domain:   ${{ inputs.domain }}
      source:   ${{ github.repository }}
    secrets:
      memory_repo_token: ${{ secrets.MEMORY_REPO_TOKEN }}
```

Trigger it:

```sh
gh workflow run submit-learning.yml \
  -f subject="ci:my-finding" \
  -f fact="One-sentence generic pattern." \
  -f evidence="https://github.com/YOUR_ORG/YOUR_REPO/pull/42" \
  -f domain="ci"
```

### Bash script (Linux/macOS, no PowerShell needed)

```sh
export MEMORY_REPO_TOKEN="ghp_..."

bash <(curl -fsSL \
  https://raw.githubusercontent.com/IBuySpy-Shared/basecoat/main/scripts/submit-learning.sh) \
  --subject  "ci:my-finding" \
  --fact     "One-sentence generic pattern." \
  --evidence "https://github.com/YOUR_ORG/YOUR_REPO/pull/42" \
  --domain   "ci" \
  --source   "YOUR_ORG/YOUR_REPO" \
  --open-pr
```

### GitHub issue form (no tooling)

Open <https://github.com/IBuySpy-Shared/basecoat/issues/new/choose> and
select **💡 Submit a Memory Contribution**. Works from any browser.
No PAT, no CLI, no secret required.

## Token Maintenance

| Task | When |
|---|---|
| Rotate PAT | Every 30 days (or before expiry) |
| Update org/repo secret | After rotation |
| Check enlistment | If sweep candidates stop appearing |

To rotate:

1. Create a new PAT with the same permissions
2. Update the secret: `gh secret set MEMORY_REPO_TOKEN --org YOUR_ORG --body "ghp_NEW_TOKEN"`
3. Delete the old PAT at <https://github.com/settings/tokens>

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Workflow fails: `MEMORY_REPO_TOKEN not set` | Secret not configured | Add org or repo secret (Step 2) |
| Workflow fails: `403` | PAT lacks permissions or expired | Recreate PAT (Step 1) |
| Repo not swept | Missing `basecoat-enabled` topic | Re-run `onboard-basecoat.sh` |
| PAT creation fails: "Resource owner not available" | Not an org member | Ask IBuySpy-Shared admin to add you |

## Getting Help

- Open an issue on <https://github.com/IBuySpy-Shared/basecoat/issues>
- Tag it `question` + `memory`
- Or use the **💡 Submit a Memory Contribution** issue form (no PAT needed)

## See Also

- `docs/memory/SETUP-INTERNAL.md` — guide for IBuySpy-Shared org members
- `docs/memory/CONTRIBUTING.md` — all five contribution paths explained
- `scripts/onboard-basecoat.sh` — enlistment script
