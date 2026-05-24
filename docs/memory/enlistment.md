# Repo Enlistment — Enterprise Memory Sweep

How to opt a repository into the BaseCoat enterprise memory sweep so that
learnings from that repo are automatically harvested and promoted to the
shared org memory (`{org}/basecoat-memory`).

---

## How Enlistment Works

The sweep uses **GitHub Topics** as the primary enlistment signal. Any repo with
the `basecoat-enabled` topic is discovered automatically via the GitHub Search API.
No central registry to maintain, no pull requests to basecoat itself.

```
repo adds topic: basecoat-enabled
         ↓
sweep-enterprise-memory.yml discovers it
         ↓
signals extracted (PRs, issues, CHANGELOG)
         ↓
PR opened to {org}/basecoat-memory with candidates
         ↓
memory-curator reviews → merged → available to all teams
```

---

## Step 1 — Add the Topic

In your repo's GitHub UI:

1. Go to **Settings → Topics** (or the repo homepage → gear icon next to "About")
2. Add: `basecoat-enabled`
3. Save

Or via CLI:

```bash
gh api repos/{org}/{repo}/topics --method PUT --field names[]="basecoat-enabled"
```

That's the minimum required for the sweep to discover the repo.

---

## Step 2 — Add `.basecoat.yml` (Optional)

Drop a `.basecoat.yml` at your repo root to fine-tune what gets swept:

```yaml
# .basecoat.yml
memory:
  # Which signal types to extract (all enabled by default)
  sweep:
    pull_requests: true      # merged PRs with 'learning' or 'retrospective' label
    issues: true             # closed issues labelled 'learning', 'bug', 'decision'
    changelog: true          # CHANGELOG.md / CHANGELOG entries since last sweep
    commit_patterns: false   # grep commits for store_memory() calls (expensive)

  # Domains this repo's learnings belong to (used for namespace in basecoat-memory/)
  domains:
    - ci         # GitHub Actions, workflow patterns
    - testing    # Test strategies and conventions
    - arch       # Architectural decisions

  # Labels that mark an issue/PR as a learning candidate
  learning_labels:
    - learning
    - retrospective
    - decision
    - bug        # resolved bugs that generate reusable error-kb entries

  # Paths to exclude from CHANGELOG scanning
  exclude_paths:
    - vendor/
    - node_modules/
    - .github/

  # How many days back to look (overrides workflow default of 30)
  # days_back: 30
```

If `.basecoat.yml` is absent the sweep uses defaults (all signals, 30 days back,
no domain filter).

---

## What Gets Swept

| Signal | Source | Condition |
|---|---|---|
| Merged PR titles + bodies | `/pulls?state=closed` | Labelled `learning` or `retrospective` |
| Resolved issue titles + bodies | `/issues?state=closed` | Labelled `learning`, `decision`, or `bug` |
| CHANGELOG entries | `CHANGELOG.md` root | Entries since last sweep date |
| `store_memory` calls | Recent commits | Only if `commit_patterns: true` |

The sweep does **not** extract source code, credentials, or content from files
outside the explicitly listed signal sources.

---

## Labels Convention

To maximize sweep signal quality, apply these labels in your repo:

| Label | Color | Use on |
|---|---|---|
| `learning` | `#d4c5f9` | PRs/issues that contain a reusable lesson |
| `decision` | `#c5def5` | Architectural or process decisions with rationale |
| `retrospective` | `#e4e669` | Post-incident or sprint retrospective outcomes |

The `bug` label is standard GitHub. Mark resolved bugs as `learning` too when the
fix is non-obvious and reusable.

---

## Required Secret

The sweep workflow writes to `{org}/basecoat-memory` using a PAT stored as
`MEMORY_REPO_TOKEN` in the basecoat repo secrets.

Create a fine-grained PAT with:
- **Resource owner:** your org
- **Repository access:** `{org}/basecoat-memory` only
- **Permissions:** Contents (R/W), Pull requests (R/W)
- **Expiration:** 30 days or less

```bash
gh secret set MEMORY_REPO_TOKEN --repo IBuySpy-Shared/basecoat
```

---

## Sweep Schedule

The sweep runs:

- **Weekly** — every Monday at 06:00 UTC (automatic)
- **On demand** — `workflow_dispatch` from the BaseCoat repo Actions tab

After each sweep a PR is opened against `{org}/basecoat-memory` with candidate
files under `sweep-candidates/YYYY-MM-DD.md` in that repo. The memory-curator
agent reviews each candidate and a memory steward approves the merge.

> **Note:** No sweep data is written back to this (basecoat) repository.
> All candidates land in `{org}/basecoat-memory` only.

---

## Verifying Enlistment

Check that your repo is visible to the sweep:

```bash
gh api "search/repositories?q=topic:basecoat-enabled+org:{YOUR_ORG}" \
  --jq '.items[].full_name'
```

Your repo should appear in the list within minutes of adding the topic.

---

## Opting Out

Remove the `basecoat-enabled` topic at any time. The sweep stops discovering
the repo on the next run. No other changes are needed.

---

## Related

- `docs/memory/shared-memory.md` — shared memory architecture and contribution flow
- `scripts/sweep-enterprise-memory.ps1` — the sweep script
- `scripts/sync-shared-memory.ps1` — pull shared memory to your local session
- `.github/workflows/memory-sweep.yml` — the scheduled sweep workflow
- `agents/memory-curator.agent.md` — curation and review process
