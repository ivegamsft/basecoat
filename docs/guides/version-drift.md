# Consumer Update Automation

BaseCoat v4.2 provides a consumer-owned hybrid updater. A scheduled pull check is
authoritative; an optional `basecoat-release-published` `repository_dispatch`
only reduces notification latency.

## Prerequisites

The callable is a reusable workflow hosted in the BaseCoat repository. Before consumers can call it:

- **Actions sharing must be enabled.** In the BaseCoat repository, set
  *Settings → Actions → General → Access* to **Accessible from repositories in the organization**
  (or a broader scope). If sharing is `none`, downstream runs fail at startup with
  `error parsing called workflow ... workflow was not found`, even though the file exists.
- **Private/internal sources need a fetch token.** The default `GITHUB_TOKEN` cannot read releases
  across repositories. When BaseCoat is private or internal, pass a `fetch_token` secret with
  release read access (see the private-source example below). Without it the run **fails closed**
  with an explicit error rather than silently reporting no drift.

## Safety defaults

- `mode: notify`
- `approval: required`
- stable releases only
- patch and minor upgrades allowed
- major upgrades fail closed to explicit approval
- release tags are resolved to immutable commit SHAs
- pull-request delivery requires a dedicated fine-grained PAT or a runtime-generated GitHub App installation token

Automatic mode waits until consumer-required checks are observed and pass, then
calls GitHub auto-merge without `--admin`. Repository branch protection, review
rules, and merge queues remain authoritative.

## Install the workflow

Copy `.github/workflow-templates/check-basecoat-version.yml` to the consumer as
`.github/workflows/check-basecoat-version.yml`:

```yaml
name: Check BaseCoat Updates

on:
  schedule:
    - cron: "0 9 * * 1"
  workflow_dispatch:
  repository_dispatch:
    types: [basecoat-release-published]

permissions:
  actions: read
  contents: read
  issues: write
  pull-requests: write

jobs:
  update:
    uses: IBuySpy-Shared/basecoat/.github/workflows/check-basecoat-version-callable.yml@9ab8894828e3a887d97c3383e7f23ed892d9a088
    with:
      stage_path: .github/base-coat
      source_repo: IBuySpy-Shared/basecoat
      fetch_host: github.com
      update_actor: ${{ vars.BASECOAT_UPDATE_ACTOR }}
    secrets:
      update_token: ${{ secrets.BASECOAT_UPDATE_TOKEN }}
      fetch_token: ${{ secrets.BASECOAT_FETCH_TOKEN }}
```

The callable inherits this caller-defined permission set rather than requesting
additional scopes. This preserves the exact v4.1 caller contract while current
PR-mode callers explicitly grant the permissions their delivery policy needs.

The canonical BaseCoat repository must expose reusable Actions to organization
repositories under **Settings → Actions → General → Access**. Organization or
enterprise access is accepted. Because BaseCoat is internal, release
publication does not call the administrative access endpoint or require a
separate release-audit token; consumer workflow invocation remains the
authoritative compatibility check.

The callable requires
`.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1`, distributed by
the v4.2 sync lifecycle.

### Secrets

| Secret | Required | Description |
|---|---|---|
| `update_token` | Only for pull-request delivery | Dedicated fine-grained PAT or runtime GitHub App installation token used to push branches and open update PRs. Omit for notify mode. |
| `fetch_token` | Only for private/internal sources | Token with read access to the source repository's releases. Omit for public sources (the default `GITHUB_TOKEN` is used). |

### Private or internal source

When the source BaseCoat repository is private or internal, pass a `fetch_token` secret:

```yaml
jobs:
  update:
    uses: YOUR-ORG/basecoat/.github/workflows/check-basecoat-version-callable.yml@9ab8894828e3a887d97c3383e7f23ed892d9a088
    with:
      stage_path: .github/base-coat
      source_repo: YOUR-ORG/basecoat
    secrets:
      fetch_token: ${{ secrets.BASECOAT_REPO_TOKEN }}
    permissions:
      issues: write
      contents: read
```

### Pull-request delivery credentials

For `pull-request` mode, the recommended setup is repository secret
`BASECOAT_UPDATE_TOKEN` containing a dedicated fine-grained PAT that can push
branches and create pull requests. The reusable workflow forwards only this
named secret. It is used by checkout, Git push, and GitHub CLI so generated
events trigger normal consumer CI. Without it, PR mode fails closed; notify mode
continues with the scoped `GITHUB_TOKEN`.

Set repository variable `BASECOAT_UPDATE_ACTOR` to the PAT owner's login. Keep
it when disabling delivery so stale updater PRs remain safely reconcilable.
During actor rotation, temporarily list old and new logins comma-separated
until old PRs are retired.

Grant the PAT these repository permissions: **Actions: read**, **Checks: read**,
**Commit statuses: read**, **Contents: read and write**, **Issues: read and
write**, and **Pull requests: read and write**. The dedicated credential is the
updater's `GH_TOKEN` in pull-request mode, so these permissions cover drift
issue maintenance, required-check observation, branch push, and pull-request
delivery. Release resolution uses anonymous public lookup or the separately
authority-bound fetch credential.

Do not store a GitHub App installation token in `BASECOAT_UPDATE_TOKEN`.
Installation tokens are short-lived. Generate the token at workflow runtime and
pass the generation step's output directly to the callable workflow's
`update_token` input. Also set `update_actor` to the GitHub App bot login (for
example, `basecoat-updater[bot]`) so existing generated PRs can be verified.
For installation tokens, configure exactly one `[bot]` actor; verification
confirms that the token can access the consumer repository because GitHub's
`/user` endpoint does not expose an installation-token user.

Private canonical sources use read-only `BASECOAT_FETCH_TOKEN` with callable
input `fetch_host` bound to its exact HTTPS authority. A private mirror on a
different host uses separate `BASECOAT_MIRROR_FETCH_TOKEN` and
`mirror_fetch_host`. The updater and both sync entrypoints never reuse
`BASECOAT_UPDATE_TOKEN`, `GITHUB_TOKEN`, or `GH_TOKEN` for source
authentication. Public GitHub sources resolve anonymously when `fetch_token`
is omitted. Private or internal sources fail clearly if anonymous resolution
is unavailable and no authority-matched `fetch_token` is supplied.

Callers already using the callable at `@main` remain compatible with the legacy
`alert_threshold` and `source_repo` inputs. The callable retains a safe
notification fallback when the distributed v4.2 updater script is not yet
installed; it does not attempt pull-request delivery in that fallback. Because
the v4.1 caller cannot forward a source credential, an internal/private source
that rejects anonymous lookup produces one stable consumer setup issue with
disposition `unknown`. Updating the caller to forward `fetch_token` restores
target resolution.

## Configure policy

```yaml
source: https://github.com/IBuySpy-Shared/basecoat.git
ref: v4.1.0

updates:
  channel: stable
  cadence: weekly
  mode: pull-request
  approval: required
  allowed_bumps: [patch, minor]
  source: IBuySpy-Shared/basecoat
  ref: latest
  validation: pwsh tests/run-tests.ps1
```

`updates.ref` selects the update target. `latest` resolves the latest stable
release. The top-level `ref` remains the installed sync pin and is updated by the
sync payload.

## Corporate mirrors and known-bad releases

```yaml
source: https://github.com/IBuySpy-Shared/basecoat.git
mirror: https://github.corp.example/platform/basecoat.git

known_bad_releases:
  v3.30.4: v3.30.5
```

Release notes come from the canonical `source`. Tag/SHA resolution and sync
fetches use `mirror`. A known-bad tag is remapped before any worktree or branch is
created.

For a private mirror, add `mirror_fetch_host: github.corp.example` to the
reusable workflow `with:` block and forward only `mirror_fetch_token:
${{ secrets.BASECOAT_MIRROR_FETCH_TOKEN }}`. Scope it read-only to the mirror;
keep the canonical source credential separately bound through `fetch_host` and
`fetch_token`.

## Lifecycle

1. Read the installed full SemVer, including patch.
2. Resolve the selected release tag and immutable commit SHA.
3. Create or update one issue containing the stable
   `basecoat-consumer-update` marker.
4. In pull-request mode, create a unique branch and isolated worktree.
5. Verify canonical and mirror tags resolve to the same commit, then run the
   consumer sync entrypoint at that immutable SHA.
6. Verify installed version and `.source-provenance.json`, then persist the new
   top-level `.basecoat.yml` release pin.
7. Commit and rebase, then run `git diff --check` and optional
   `updates.validation` on the exact post-rebase content.
8. Push and open an upgrade PR with provenance, changed assets,
   validation, release notes, and rollback instructions.
9. Remove the worktree only after successful delivery. Failed delivery preserves
   it for recovery.
10. Close the drift issue after the installed version reaches the target.

## Idempotency and fleet status

The issue body contains a stable machine-readable marker, so new patch releases
update the same issue rather than creating version-specific duplicates. Upgrade
PRs also carry a stable marker and are reused for the same target.
The marker records `drift_started_at`; reopening a closed issue starts a new drift
cycle instead of inheriting the original issue age.

Each run uploads `basecoat-update-status.json` with:

- current and target versions
- immutable target SHA
- drift age
- issue and PR URLs
- mode, approval, bump, and disposition

The adoption scanner exposes the same fields by reading the stable issue marker.

## Approval behavior

| Mode | Approval | Result |
|---|---|---|
| `notify` | either | Stable issue only |
| `pull-request` | `required` | Upgrade PR waits for normal review |
| `pull-request` | `automatic` | GitHub auto-merge waits for repository policy |
| any | major | Explicit approval; automatic is downgraded |
| any | disallowed bump | Issue disposition is `blocked-by-policy` |

## Audit commands

```bash
gh run list --workflow check-basecoat-version.yml --limit 10
gh issue list --state all --search "basecoat-consumer-update in:body"
gh pr list --state all --search "basecoat-consumer-update-pr in:body"
```
