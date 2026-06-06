# Setting Up Basecoat Memory Contributions — Internal (IBuySpy-Shared)

For repos inside the **IBuySpy-Shared** GitHub org, an admin only needs to
configure the org-level secret **once**. After that, every org repo can
contribute learnings with zero per-repo setup.

## How Internal Setup Works

```text
Admin (one time)
  └─ Sets MEMORY_REPO_TOKEN as an org-level Actions secret
        └─ All IBuySpy-Shared repos inherit it automatically

Any internal repo
  └─ Run: bash <(curl -fsSL .../onboard-basecoat.sh) --repo org/repo
        └─ Adds basecoat-enabled topic
        └─ Creates learning / retrospective / decision labels
        └─ Done — contributing immediately
```

## Step 1 — Admin: Set the Org-Level Secret (once, ever)

1. Create a fine-grained PAT:
   - Go to <https://github.com/settings/personal-access-tokens/new>
   - Resource owner: **IBuySpy-Shared**
   - Repository access: **Only select repositories** → `IBuySpy-Shared/basecoat-memory`
   - Permissions: **Contents** (R/W), **Pull requests** (R/W), **Metadata** (R)
   - Set PAT expiry to **30 days or less** (calendar reminder to rotate)

2. Store it as an **org-level secret**:
   - Go to <https://github.com/organizations/IBuySpy-Shared/settings/secrets/actions>
   - Click **New organization secret**
   - Name: `MEMORY_REPO_TOKEN`
   - Access: **All repositories** (or select the repos you want to enlist)
   - Save

That's it. Every org repo now has `MEMORY_REPO_TOKEN` available in Actions
**without any per-repo configuration**.

## Step 2 — Enlist a Repo (one command)

```sh
bash <(curl -fsSL \
  https://raw.githubusercontent.com/IBuySpy-Shared/basecoat/main/scripts/onboard-basecoat.sh) \
  --repo IBuySpy-Shared/my-repo
```

This adds the `basecoat-enabled` topic and creates the three learning labels.
The repo is now enlisted for the weekly passive sweep **and** can use all
active push paths immediately.

### What the onboard script does

| Action | Command used |
|---|---|
| Add `basecoat-enabled` topic | `gh api repos/{repo}/topics --method PUT` |
| Create `learning` label | `gh label create` |
| Create `retrospective` label | `gh label create` |
| Create `decision` label | `gh label create` |

## Step 3 — Verify

Run the sweep against just your repo to confirm it's discoverable:

```sh
gh workflow run memory-sweep.yml \
  --repo IBuySpy-Shared/basecoat \
  -f org=IBuySpy-Shared \
  -f days_back=7
```

Or check that your repo appears in the search:

```sh
gh api "search/repositories?q=topic:basecoat-enabled+org:IBuySpy-Shared" \
  --jq '.items[].full_name'
```

## Contributing After Setup

Once enlisted, internal teams can submit via any path — **no additional secrets needed**:

### Passive (automatic)

Label any merged PR or closed issue `learning`, `retrospective`, or `decision`.
Picked up every Monday.

### Reusable workflow (recommended for CI pipelines)

Because `MEMORY_REPO_TOKEN` is already an org secret, no `secrets:` block is
needed when calling from another org repo:

```yaml
jobs:
  submit:
    uses: IBuySpy-Shared/basecoat/.github/workflows/submit-learning-callable.yml@main
    with:
      subject:  "ci:my-finding"
      fact:     "One-sentence generic pattern."
      evidence: "https://github.com/IBuySpy-Shared/my-repo/pull/42"
      domain:   "ci"
      source:   ${{ github.repository }}
    secrets:
      memory_repo_token: ${{ secrets.MEMORY_REPO_TOKEN }}
```

### Starter workflow (no copy-paste)

The **Submit Learning** starter workflow appears in the
**Actions → New workflow** UI for all `IBuySpy-Shared` repos automatically.
Click it, fill in the form, run — done.

### Bash script

```sh
export MEMORY_REPO_TOKEN=${{ secrets.MEMORY_REPO_TOKEN }}  # already in CI env

bash <(curl -fsSL \
  https://raw.githubusercontent.com/IBuySpy-Shared/basecoat/main/scripts/submit-learning.sh) \
  --subject  "ci:my-finding" \
  --fact     "One-sentence generic pattern." \
  --evidence "https://github.com/IBuySpy-Shared/my-repo/pull/42" \
  --domain   "ci" \
  --source   "$GITHUB_REPOSITORY" \
  --open-pr
```

### GitHub issue form (no tooling at all)

Open <https://github.com/IBuySpy-Shared/basecoat/issues/new/choose> and select
**💡 Submit a Memory Contribution**. Works from any browser.

## Token Rotation

The org-level PAT should be rotated every 30 days.

1. Create a new fine-grained PAT with the same permissions
2. Update the org secret at:
   <https://github.com/organizations/IBuySpy-Shared/settings/secrets/actions>
3. All repos pick it up immediately — no per-repo changes

## Auto-Enlistment (Admins)

To enlist many repos at once, trigger the auto-enlist workflow:

```sh
gh workflow run auto-enlist.yml \
  --repo IBuySpy-Shared/basecoat \
  -f repos="IBuySpy-Shared/repo1,IBuySpy-Shared/repo2,IBuySpy-Shared/repo3"
```

## See Also

- `docs/memory/setup-external.md` — guide for teams outside IBuySpy-Shared
- `docs/memory/contributing.md` — all five contribution paths explained
- `scripts/onboard-basecoat.sh` — enlistment script
- `.github/workflows/auto-enlist.yml` — bulk enlistment for admins
