# Rollout BaseCoat — Delivery Lifecycle

Detailed steps for running a BaseCoat upgrade inside an isolated worktree and
completing the full commit → push → PR → cleanup lifecycle. An upgrade that stops
at "here is what changed" and leaves the sync uncommitted in the consumer's
working tree is an **incomplete run**.

Commands are given for both Bash (Linux/macOS) and PowerShell (Windows). The
delivery block is **fail-fast**: if any step fails, stop and keep the
worktree/branch for recovery — do **not** run cleanup, or you may destroy the only
local copy of an unpushed commit.

## 1. Resolve the default branch and create a uniquely-named worktree

The consumer's default branch is not always `main` — resolve it. Give the branch a
unique suffix so re-running the rollout for a moving ref (e.g. `main`) never
collides with a still-open PR branch.

Bash:

```bash
git fetch origin
DEFAULT_BRANCH=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
BRANCH="chore/basecoat-upgrade-<ref>-$(date +%Y%m%d%H%M%S)"
git worktree list                      # inspect existing worktrees first
git worktree add ../<repo>-wt-basecoat -b "$BRANCH" "origin/$DEFAULT_BRANCH"
cd ../<repo>-wt-basecoat
```

PowerShell:

```powershell
git fetch origin
$DefaultBranch = ((git remote show origin | Select-String 'HEAD branch:') -replace '.*HEAD branch:\s*','').Trim()
$Branch = "chore/basecoat-upgrade-<ref>-$(Get-Date -Format 'yyyyMMddHHmmss')"
git worktree list                      # inspect existing worktrees first
git worktree add ..\<repo>-wt-basecoat -b $Branch "origin/$DefaultBranch"
Set-Location ..\<repo>-wt-basecoat
```

If an upgrade tracking issue exists, prefer `chore/<issue>-basecoat-upgrade-<ref>`.
Alternatively, detect and resume an existing open rollout PR instead of creating a
new branch.

## 2. Sync inside the worktree

### Discover the sync entrypoint

Do **not** assume a root `sync.ps1`/`sync.sh`. Real consumers vendor the script
elsewhere (e.g. `scripts/basecoat/sync-basecoat.ps1`). Resolve the entrypoint in
this order and fail with a clear message if none is found:

1. **Configured path** — `sync.script` in the consumer's root `.basecoat.yml`
   (relative to repo root). Use it directly if the file exists.
2. **Canonical root** — root `sync.ps1` (Windows) or `sync.sh` (Linux/macOS).
3. **Common locations** — first match of `scripts/**/sync*basecoat*.ps1`,
   `scripts/**/sync*basecoat*.sh`, `.github/base-coat/sync.ps1`,
   `.github/base-coat/sync.sh`.
4. **Fail** — if nothing matches, stop and report every path checked so the user
   can add `sync.script` to `.basecoat.yml`.

Bash:

```bash
# Resolve the sync entrypoint: configured path > root > common locations.
shopt -s globstar nullglob            # ** recurses; unmatched globs vanish
# Read sync.script from .basecoat.yml, stripping inline comments and quotes.
CONFIGURED=$(sed -n 's/^[[:space:]]\{1,\}script:[[:space:]]*//p' .basecoat.yml 2>/dev/null | head -n1)
CONFIGURED=${CONFIGURED%%#*}
CONFIGURED=$(printf '%s' "$CONFIGURED" | sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
candidates=("$CONFIGURED" sync.sh sync.ps1 \
  scripts/**/sync*basecoat*.sh scripts/**/sync*basecoat*.ps1 \
  .github/base-coat/sync.sh .github/base-coat/sync.ps1)
SYNC_SCRIPT=""
for cand in "${candidates[@]}"; do
  [ -n "$cand" ] && [ -f "$cand" ] && { SYNC_SCRIPT="$cand"; break; }
done
if [ -z "$SYNC_SCRIPT" ]; then
  echo "No BaseCoat sync entrypoint found. Checked: sync.script='${CONFIGURED:-<unset>}', ./sync.sh, ./sync.ps1, scripts/**/sync*basecoat*.{sh,ps1}, .github/base-coat/sync.{sh,ps1}. Set sync.script in .basecoat.yml." >&2
  exit 1
fi
echo "Using sync entrypoint: $SYNC_SCRIPT"
```

PowerShell:

```powershell
# Resolve the sync entrypoint: configured path > root > common locations.
$Configured = (Select-String -Path .basecoat.yml -Pattern '^\s+script:\s*(.+?)\s*(?:#.*)?$' -ErrorAction SilentlyContinue |
  Select-Object -First 1).Matches.Groups[1].Value
if ($Configured) {
  $Configured = $Configured.Trim()
  if ($Configured -match '^"(.*)"$' -or $Configured -match "^'(.*)'$") { $Configured = $Matches[1] }
}
$Candidates = @($Configured, 'sync.ps1', 'sync.sh') +
  (Get-ChildItem -Recurse -File -Path scripts -Include 'sync*basecoat*.ps1','sync*basecoat*.sh' -ErrorAction SilentlyContinue).FullName +
  '.github/base-coat/sync.ps1', '.github/base-coat/sync.sh'
$SyncScript = $Candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if (-not $SyncScript) {
  $cfg = if ($Configured) { "sync.script='$Configured'" } else { 'sync.script=<unset>' }
  throw "No BaseCoat sync entrypoint found. Checked: $cfg, .\sync.ps1, .\sync.sh, scripts\**\sync*basecoat*.{ps1,sh}, .github/base-coat/sync.{ps1,sh}. Set sync.script in .basecoat.yml."
}
Write-Host "Using sync entrypoint: $SyncScript"
```

### Run the resolved entrypoint

`sync.ps1`/`sync.sh` resolve the source and ref with precedence
`BASECOAT_REPO`/`BASECOAT_REF` env vars > the consumer's root `.basecoat.yml`
(`source`/`ref`) > built-in defaults (`YOUR-ORG` placeholder / `main`). A pin in
`.basecoat.yml` is therefore honored automatically. Set the env vars only to
override a run (for example, to force a specific upgrade target); each run logs the
resolved values and their origin (`env`, `.basecoat.yml`, `default`, or `redirect`):

Windows (PowerShell):

```powershell
# Optional override — omit to use the consumer's .basecoat.yml pin.
$env:BASECOAT_REPO = '<source override>'
$env:BASECOAT_REF  = '<ref override>'  # e.g. vX.Y.Z
if ($SyncScript -like '*.ps1') { pwsh $SyncScript } else { bash $SyncScript }
```

Linux or macOS (Bash):

```bash
# Optional override — omit to use the consumer's .basecoat.yml pin.
# Dispatch .ps1 through pwsh; PowerShell scripts are not executable on Linux/macOS.
case "$SYNC_SCRIPT" in
  *.ps1) BASECOAT_REPO='<source override>' BASECOAT_REF='<ref override>' pwsh "$SYNC_SCRIPT" ;;
  *)     BASECOAT_REPO='<source override>' BASECOAT_REF='<ref override>' bash "$SYNC_SCRIPT" ;;
esac
```

Then verify `.github/base-coat/version.json` matches the pinned ref (sync enforces
provenance for semver tags) and compare with the latest upstream release:
`gh release list --repo SOURCE-ORG/basecoat --limit 1`.

## 3. Commit, then rebase, push, and open a PR (fail-fast)

If `git status --porcelain` is empty, the repo is already at the target build —
skip to [Cleanup for the no-change path](#5-cleanup-for-the-no-change-path) and
report "already up to date."

Otherwise **commit first** (rebasing a dirty tree fails with "cannot rebase: you
have unstaged changes"), then run the rest as a fail-fast chain. Do not proceed to
cleanup if any step fails.

Bash (`&&` stops the chain on the first failure):

```bash
git add -A \
  && git commit -m "chore(basecoat): upgrade to <version>" \
       -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" \
  && git fetch origin \
  && git rebase "origin/$DEFAULT_BRANCH" \
  && git push -u origin "$BRANCH" \
  && gh pr create --title "chore(basecoat): upgrade to <version>" \
       --body "Automated BaseCoat upgrade via rollout-basecoat. Previous <old-version>; new <version>; source <source> @ <ref>; changed paths <N>."
```

PowerShell (native commands do not stop on nonzero exit — check `$LASTEXITCODE`
after each and abort, preserving the worktree/branch for recovery):

```powershell
function Invoke-Step { param([scriptblock]$Cmd, [string]$Name)
  & $Cmd
  if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE); worktree/branch kept for recovery" }
}
Invoke-Step { git add -A } 'git add'
Invoke-Step { git commit -m "chore(basecoat): upgrade to <version>" -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" } 'git commit'
Invoke-Step { git fetch origin } 'git fetch'
Invoke-Step { git rebase "origin/$DefaultBranch" } 'git rebase'
Invoke-Step { git push -u origin $Branch } 'git push'
Invoke-Step { gh pr create --title "chore(basecoat): upgrade to <version>" --body "Automated BaseCoat upgrade via rollout-basecoat. Previous <old-version>; new <version>; source <source> @ <ref>; changed paths <N>." } 'gh pr create'
```

Let required checks run; do **not** self-merge high-risk upgrades. Use serialized
merges when combining with other release work.

## 4. Cleanup for the change path

Only after the delivery block above succeeded and the PR is open. Remove the
worktree but **keep the branch** — it backs the open PR and is deleted on merge
(`gh pr merge --delete-branch`).

Bash:

```bash
cd -                                   # back to the primary worktree
git worktree list                      # confirm branch-to-path mapping
git worktree remove ../<repo>-wt-basecoat
git worktree prune
```

PowerShell:

```powershell
Set-Location -                         # back to the primary worktree
git worktree list                      # confirm branch-to-path mapping
git worktree remove ..\<repo>-wt-basecoat
git worktree prune
```

## 5. Cleanup for the no-change path

The sync produced no changes, so there is no PR. Remove the worktree **and** delete
the unused branch created in step 1.

Bash:

```bash
cd -
git worktree list
git worktree remove ../<repo>-wt-basecoat
git worktree prune
git branch -D "$BRANCH"
```

PowerShell:

```powershell
Set-Location -
git worktree list
git worktree remove ..\<repo>-wt-basecoat
git worktree prune
git branch -D $Branch
```

## Safety rules

- Never remove a worktree by an assumed path — confirm the mapping with
  `git worktree list` first, and prune only after confirmed removal.
- Do not run cleanup after a failed delivery step; retain the worktree/branch so an
  unpushed commit can be recovered.
- The upgrade runs in a separate worktree, so the primary working tree is untouched
  by design. After cleanup, confirm `git worktree list` no longer shows the removed
  worktree rather than asserting anything about the primary tree's status — the user
  may have unrelated work in progress there.

## Fallback sync commands

If skill routing fails (`Skill not found: rollout-basecoat`), do not run sync in the
primary tree. First create and enter the worktree (step 1), then run the commands
below **inside that worktree** as the replacement for step 2, and finally continue
with steps 3–5. Resolve the entrypoint as in [Discover the sync
entrypoint](#discover-the-sync-entrypoint) — the commands below assume the canonical
root script; substitute the discovered path if the consumer vendors it elsewhere.
`BASECOAT_REPO` / `BASECOAT_REF` point at the upstream BaseCoat source and ref.

```powershell
# PowerShell — run from inside the worktree (step 1), replacing step 2
$env:BASECOAT_REPO = 'https://github.com/SOURCE-ORG/basecoat.git'
$env:BASECOAT_REF  = 'main'  # or vX.Y.Z
pwsh .\sync.ps1
```

```bash
# Bash — run from inside the worktree (step 1), replacing step 2
BASECOAT_REPO=https://github.com/SOURCE-ORG/basecoat.git \
BASECOAT_REF=main ./sync.sh
```
