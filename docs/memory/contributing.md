# Contributing Learnings to Basecoat Memory

This guide explains how repos that use basecoat guidance can contribute
learnings back for the steward team to review and promote into shared memory.

## First-Time Setup

> **IBuySpy-Shared org members (internal):** See `docs/memory/setup-internal.md`.
> After a one-time admin secret, onboarding a repo takes a single command.
>
> **External orgs:** See `docs/memory/setup-external.md`.
> You need a fine-grained PAT stored as a secret, then one onboarding command.

Once set up, the paths below all work with zero additional configuration
for internal org members.

## Choosing a Path

| Path | Internal setup | External setup | Good for |
|---|---|---|---|
| **Label an issue or PR** | Enlist repo once | Enlist repo once | Ongoing passive collection |
| **Starter workflow** | None — appears in Actions UI automatically | Copy one file | CI-triggered, GUI form |
| **Submit via GitHub issue** | GitHub account only | GitHub account only | One-off, no CLI |
| **Reusable workflow call** | None — org secret inherited | Copy one file + secret | Any OS, any language |
| **`submit-learning.sh`** | Org secret auto-injected in CI | PAT env var | Linux/macOS/WSL |
| **`submit-learning.ps1`** | Org secret auto-injected in CI | PAT env var | Windows/pwsh |

## How It Works

```text
Consumer repo (basecoat-enabled)
  │
  ├─ labels issue/PR: "learning"           ← passive, weekly pickup
  ├─ opens basecoat issue (memory-contribution template) ← zero-setup
  ├─ calls submit-learning-callable.yml    ← CI-native, any OS
  ├─ runs submit-learning.sh               ← bash/curl/jq
  ├─ runs submit-learning.ps1              ← PowerShell
  │
  ▼
basecoat-memory/sweep-candidates/          ← PR opened for steward review
  │
  ▼
Memory steward reviews → promotes to memories/{domain}/{subject}.md
  │
  ▼
Weekly sync distributes to all basecoat-enabled repos (hot-index.md)
```

## Path 1 — Label-Based Sweep (passive, zero setup after enlistment)

Add the `basecoat-enabled` GitHub topic to your repo:

```sh
gh api repos/{org}/{repo}/topics --method PUT --field names[]=basecoat-enabled
```

Then label any merged PR or closed issue with `learning`, `retrospective`,
or `decision`. The weekly sweep picks it up automatically every Monday.

Create the labels once:

```sh
gh label create learning      --color 0075ca --description "Candidate for basecoat memory"
gh label create retrospective --color e4e669 --description "Sprint retrospective finding"
gh label create decision      --color d93f0b --description "Architecture or process decision"
```

## Path 2 — GitHub Issue (zero local setup)

Open an issue on the basecoat repo using the **Memory Contribution** template.
No CLI, no PAT, no PowerShell required — just a GitHub account.

1. Go to: <https://github.com/ivegamsft/basecoat/issues/new/choose>
2. Select **💡 Submit a Memory Contribution**
3. Fill in the structured form
4. Submit — the bot validates and queues the candidate automatically

The scope-check boxes in the form are enforced before submission.

## Path 3 — Reusable Workflow (CI-native, any OS)

No local tools needed. Add one workflow file to your repo and the submission
runs in GitHub Actions.

**Prerequisites:**

- Store `MEMORY_REPO_TOKEN` as a repo secret (fine-grained PAT with
  Contents R/W + Pull Requests R/W on `{org}/basecoat-memory`)

**Workflow to add** (copy to `.github/workflows/submit-learning.yml`):

```yaml
name: Submit learning to basecoat
on:
  workflow_dispatch:
    inputs:
      subject:  { required: true,  type: string }
      fact:     { required: true,  type: string }
      evidence: { required: true,  type: string }
      domain:   { required: true,  type: string }
      source:   { required: false, type: string, default: "" }

jobs:
  submit:
    uses: IBuySpy-Shared/basecoat/.github/workflows/submit-learning-callable.yml@main
    with:
      subject:  ${{ inputs.subject }}
      fact:     ${{ inputs.fact }}
      evidence: ${{ inputs.evidence }}
      domain:   ${{ inputs.domain }}
      source:   ${{ inputs.source || github.repository }}
    secrets:
      memory_repo_token: ${{ secrets.MEMORY_REPO_TOKEN }}
```

Then trigger it:

```sh
gh workflow run submit-learning.yml \
  -f subject="ci:agent-pr-approval" \
  -f fact="Copilot agent PRs need a maintainer empty-commit to trigger CI." \
  -f evidence="https://github.com/myorg/myrepo/pull/42" \
  -f domain="ci"
```

## Path 4 — Bash Script (Linux / macOS)

**Prerequisites:** `bash`, `curl`, `jq`, and `MEMORY_REPO_TOKEN` env var.

```sh
export MEMORY_REPO_TOKEN=ghp_...

curl -fsSL https://raw.githubusercontent.com/ivegamsft/basecoat/main/scripts/submit-learning.sh \
  -o submit-learning.sh

bash submit-learning.sh \
  --subject  "ci:agent-pr-approval" \
  --fact     "Copilot agent PRs need a maintainer empty-commit to trigger CI." \
  --evidence "https://github.com/myorg/myrepo/pull/42" \
  --domain   "ci" \
  --source   "myorg/myrepo" \
  --open-pr
```

## Path 5 — PowerShell Script (Windows / cross-platform pwsh)

**Prerequisites:** PowerShell (`pwsh`), `gh` CLI, and `MEMORY_REPO_TOKEN` env var.

```powershell
$env:MEMORY_REPO_TOKEN = "ghp_..."

pwsh scripts/submit-learning.ps1 `
  -Subject  "ci:agent-pr-approval" `
  -Fact     "Copilot agent PRs need a maintainer empty-commit to trigger CI." `
  -Evidence "https://github.com/myorg/myrepo/pull/42" `
  -Domain   "ci" `
  -Source   "myorg/myrepo" `
  -OpenPR
```

## Getting MEMORY_REPO_TOKEN

All active push paths (Paths 3–5) require a fine-grained PAT:

1. Go to <https://github.com/settings/personal-access-tokens/new>
2. Set **Resource owner** to your org
3. Set **Repository access** → Only select repositories → `{org}/basecoat-memory`
4. Under **Permissions**, grant:
   - **Contents**: Read and Write
   - **Pull requests**: Read and Write
5. Generate and store as `MEMORY_REPO_TOKEN` in your repo secrets

## Configuring the Sweep

Place a `.basecoat.yml` at your repo root to customize sweep behavior.
Copy `.basecoat.yml.example` from the basecoat repo as a starting point:

```sh
curl -fsSL https://raw.githubusercontent.com/ivegamsft/basecoat/main/.basecoat.yml.example \
  -o .basecoat.yml
```

Key settings:

| Key | Default | Purpose |
|---|---|---|
| `learning_labels` | `[learning, retrospective, decision]` | Labels that trigger sweep |
| `days_back` | `30` | How far back the sweep looks |
| `team` | *(empty)* | Team name included in candidate metadata |
| `contact` | *(empty)* | GitHub handle for follow-up |
| `domain` | *(empty)* | Hint for which memory domain to target |

## What Makes a Good Learning

The steward team evaluates candidates against a four-point scope policy:

| Criterion | Question |
|---|---|
| **Generic** | Free of product names, internal system names, org-specific tooling? |
| **Broadly applicable** | Would another team using Basecoat find this useful? |
| **Durable** | Has it held true across ≥ 3 sprints or ≥ 2 similar incidents? |
| **Actionable** | Would another team change their behavior based on this? |

All four must be **yes** for a candidate to be promoted to shared memory.

## Feedback Loop

Once a candidate is promoted to `basecoat-memory`, it flows back to all
`basecoat-enabled` repos via the weekly hot-index sync. Your team benefits
directly from other teams' learnings.

## References

- `scripts/submit-learning.sh` — bash active push (curl/jq, no PowerShell)
- `scripts/submit-learning.ps1` — PowerShell active push
- `.github/workflows/submit-learning-callable.yml` — reusable/callable workflow
- `.github/ISSUE_TEMPLATE/memory-contribution.yml` — zero-setup issue form
- `.basecoat.yml.example` — sweep configuration template
- `docs/memory/process.md` — full memory lifecycle overview
