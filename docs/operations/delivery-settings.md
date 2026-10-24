# Delivery Automation Settings

This guide covers approved-spec handoff and roadmap persistence settings.
Publishing BaseCoat does not require enabling either feature. Keep assignment
handoff read-only and roadmap milestone writes disabled until their live
prerequisites are verified. Examples below are instructions, not authorization
to change repository settings or create infrastructure.

## Settings inventory

| Setting | Location and type | Default / allowed value | Purpose |
| --- | --- | --- | --- |
| `BASECOAT_SPEC_HANDOFF_MODE` | Repository Actions variable, string | Unset means `read-only`; supported modes are `read-only`, `canary`, `general` | Controls assignment writes from approved-spec handoff. |
| `BASECOAT_SPEC_HANDOFF_CANARY` | Repository Actions variable, JSON text | Unset means no configured canary | Binds one exact source/directive/spec identity for the first assignment. |
| `ROADMAP_APP_SLUG` | Roadmap process environment, string | No default; actual GitHub App slug without `[bot]` | Checks that ledger commit authors are the intended app. |
| `ROADMAP_APP_ID` | Roadmap process environment, decimal string | No default; GitHub App ID, not installation ID or client ID | Checks that the branch update ruleset allows only that app. |
| `roadmap_persistence_enabled` | Top-level JSON boolean in `scripts/backlog-autopilot/autopilot.config.json` | Missing or `false` disables milestone writes; only JSON `true` passes this flag check | One of several mandatory milestone-write gates. |
| Sandbox repositories | `scripts/roadmap/probe-allowlist.json`, `repositories` array | Empty array | Restricts live contract probes to owner-approved sandboxes. |
| Probe evidence | `docs/reference/roadmap-contract-probe.json`, JSON file | Missing means gate closed | Supplies recent live API evidence, not mocked results. |
| `GH_AW_GITHUB_TOKEN` | Repository or selected-repository organization Actions secret | Optional; workflows using this override otherwise use `github.token` | Scoped temporary credential exception; not a prerequisite for publishing or roadmap app provenance. |

Repository Actions variables are under **Settings > Secrets and variables >
Actions > Variables**. Secrets belong on the **Secrets** tab. App IDs and slugs
are not credentials; tokens and private keys must never be put in variables,
JSON configuration, or committed examples.

The roadmap transport, publisher, probe and adapter are separate implementation
units. Confirm that the referenced scripts are present in the installed release
before using them; a merged spec or ledger core alone does not install them.
Repository variables named `ROADMAP_APP_SLUG` and `ROADMAP_APP_ID` do not
automatically become process environment variables. A future workflow must
explicitly map them into `env`, or an operator must set them for that process.

## Approved-spec handoff

### Read-only baseline

An administrator can explicitly retain the safe baseline:

```powershell
gh variable set BASECOAT_SPEC_HANDOFF_MODE --repo OWNER/REPO --body read-only
```

Read-only disables assignment writes, not status reporting: the handoff
workflow can still reconcile a source issue and update its bot-owned status
comment. Invalid modes, missing/invalid canary JSON and unresolved source
evidence fail closed. Do not use `general` to bypass a blocked canary.

### Build the canary from resolved evidence

1. Enable the Copilot coding agent for the repository and verify that it is
   assignable. A variable cannot enable the platform feature.
2. Install `approved-spec-handoff.yml`, `agent-assignment-worker.yml` and their
   shared scripts. Ensure hold/deferred labels referenced by those workflows
   are available; hold labels must not be removed merely to pass a gate.
3. Merge the reviewed spec PR. Before the directive, set the source issue's
   single `- Spec:` URL to the merged spec's commit-pinned blob URL. The spec
   and PRD must be `reviewed` or `implementation-ready`, and delivery intent
   must be `implementation`; resolve dependencies and holds first.
4. A qualified human posts exact `/approve-spec <spec-pr> <final-head-sha>`
   on the source issue after the spec merges. The head SHA is the spec PR's
   final head, not its merge commit. Subsequent source edits can invalidate it.
5. Reconcile in read-only mode and inspect the bot-owned handoff status
   comment, including its `basecoat-spec-handoff-state:v1` JSON payload.
   Require a resolved identity and `handoff-pending` or `assigned` state.

Use that trusted resolved record to create a local `canary.json` with exactly
these fields; do not invent IDs or copy values from a different source:

| Canary field | JSON type | Resolved-record source |
| --- | --- | --- |
| `issue` | Positive integer | `issueNumber`, the source issue number |
| `directiveId` | Positive integer | `directiveId`, the source issue comment ID, not its GraphQL node ID |
| `specPr` | Positive integer | `evidence.specPr`, the merged spec PR number |
| `approvedHead` | 40-character Git SHA string | `evidence.approvedHead`, final spec PR head |
| `mergeCommit` | 40-character Git SHA string | `evidence.mergeCommit`, spec PR merge commit |
| `specBlob` | 40-character Git blob SHA string | `evidence.specBlob`, spec content identity |
| `prdBlob` | 40-character Git blob SHA string | `evidence.prdBlob`, PRD content identity |

`specBlob` and `prdBlob` are blob IDs, not commit SHAs. The workflow resolves
them and checks current default-branch content; editing a spec or PRD can make
the tuple stale. The status comment is evidence to inspect, not an approval
substitute.

### Canary activation and promotion

Only after the administrator approves the canary operation:

```powershell
Get-Content -Raw .\canary.json | gh variable set BASECOAT_SPEC_HANDOFF_CANARY --repo OWNER/REPO
if ($LASTEXITCODE -ne 0) { throw 'Canary configuration failed; do not activate handoff.' }
gh variable set BASECOAT_SPEC_HANDOFF_MODE --repo OWNER/REPO --body canary
gh workflow run approved-spec-handoff.yml --repo OWNER/REPO --ref main -f issue_number=SOURCE_ISSUE
```

Replace `SOURCE_ISSUE` with the integer used in the tuple. In downstream
repositories, use the installed workflow filename and actual default branch.
Setting variables does not itself dispatch a run. Verify both the handoff
record and the assignment worker's persisted read-back show the same directive,
spec identity and actual agent assignee. Approval labels or a successful
dispatch alone are insufficient.

Promotion to `general` requires a separate protected administrator decision
and successful persisted canary assignee verification. Retain the verified
canary tuple. Roll back new assignment attempts by restoring `read-only`;
this does not unassign issues or undo work already started.

## Roadmap identity, authentication and branches

These settings are not additional handoff variables. The roadmap Python
scripts call `gh api` and use that process's GitHub authentication. They do
not mint an installation token from an app ID.

An administrator must select/install the roadmap GitHub App and arrange an
installation-token credential for the approved repository. Verify the actual
app slug and numeric App ID in the app's settings. A human PAT with matching
environment labels cannot satisfy app-authored, verified commit provenance.
For a local process, after approved credentials are supplied securely:

```powershell
$env:ROADMAP_APP_SLUG = "YOUR-ROADMAP-APP-SLUG"
$env:ROADMAP_APP_ID = "YOUR-NUMERIC-APP-ID"
```

`gh` supports `GH_TOKEN` for the credential; never paste its value into the
guide or a committed file. Ledger/artifact operation needs repository content
and PR access, plus readable comments, collaborator permissions and effective
branch rulesets. Milestone writes additionally need issues write access;
keep that capability separate while the write gate is closed.

Before initializing bot branches, approve and provision their protection:

- `bot/roadmap-state`: active restrictions on updates, deletion and
  non-fast-forward updates; update authority limited to the selected App
  (`actor_type: Integration`, its App ID, `bypass_mode: always` for the update
  restriction). Do not introduce human update exceptions or permit deletion
  and force-pushes.
- Ledger history must be entirely app-authored and verified, and effective
  rulesets must not have been created or changed after its root commit.
  A branch simply copied from normal human-authored `main` history will not
  satisfy that provenance check. Agree the initialization procedure first.
- `bot/roadmap-artifact`: approved app-controlled branch for
  `docs/reference/roadmap.md`; publishing opens/updates a normal PR to `main`,
  never bypasses main checks. Provision its protection in advance. An approved
  artifact `--apply` run creates a missing branch from `main` before committing;
  a dry run reports `create_branch: true` without creating it.

After the ledger protection is provisioned, `python .\scripts\roadmap\ledger.py
bootstrap --repo OWNER/REPO` previews the parentless, app-authored ledger root.
Use `--apply` only with the approved App credentials and owner authorization.
Bootstrap refuses an existing ledger branch and re-verifies provenance after
creation. The ledger branch must exist before publishing or persistence.
Creating the artifact branch requires the publisher's re-verified consumed
approval and `--apply`; merging this implementation does not authorize it.

Unproven protection/history produces `ledger-provenance-unproven`.
An uninitialized ledger produces `ledger-branch-missing`; a missing artifact
branch is previewed for approval-gated creation, not a prerequisite failure.
Do not weaken protection to clear these errors. Branch/ruleset provisioning
is an owner/admin decision, not a consequence of merging the implementation.

Without `--apply`, ledger/artifact commands do not commit changes, but may
read authenticated GitHub evidence and enforce prerequisites. A live ledger
approval consumes an exact qualified human issue comment:
`roadmap: approve <run_id> <plan_sha256>`. Scheduled runs, labels and feature
flags cannot grant that authority.

## Sandbox probe and milestone configuration

The owner must name and authorize a disposable sandbox repository before a
probe. Add only that repository to the `repositories` array in
`scripts/roadmap/probe-allowlist.json` through a normal PR. Do not include
`IBuySpy-Shared/basecoat` or a production repository. Supply sandbox-only
credentials, never the production token.

After the approved allowlist and probe script are installed:

```powershell
python .\scripts\roadmap\contract_probe.py --repo OWNER/SANDBOX --confirm-sandbox OWNER/SANDBOX
```

The probe performs real writes: it creates test issues/milestones, attempts
stale writes, then cleans up only resources bearing its run marker. Capture
its JSON result and review it before committing evidence to
`docs/reference/roadmap-contract-probe.json` through a PR. Negative or
inconclusive results are valid evidence that writes must remain disabled.
Do not manufacture positive results or substitute unit-test output.

Evidence must have `schema: 1`, a timezone-aware `recorded_at` no more than
30 days old and not in the future, and `cases` with positive live results:

| Planned operation | Mandatory positive cases |
| --- | --- |
| Assignment | `2a`, `2b`, `3a`, `3b` |
| Milestone creation | `4` |
| Marker/pin edit | `1` |

Preserve the probe's `repository`, API-surface and status evidence for review.
GitHub's currently observed lack of conditional milestone/assignment updates
is a reason to keep the gate closed, not to bypass it.

The flag is absent from the initial config, which means disabled. To make
that default explicit, merge this top-level member into
`scripts/backlog-autopilot/autopilot.config.json`, preserving existing keys:

```json
{
  "roadmap_persistence_enabled": false
}
```

It is not an Actions variable or environment override. Change it to JSON
`true` only through an approved configuration PR after live evidence proves
the required operations safe. Strings such as `"true"` do not pass the gate.
An exact consumed plan approval, current holder/epoch and fresh positive
probe evidence are also required; the flag alone never authorizes a write.
Rollback restores `false` and stops new runs, retaining ledger receipts
without deleting milestones or clearing assignments.

## Automation credential fallback

`GH_AW_GITHUB_TOKEN` is optional and distinct from the roadmap App identity.
Use the [secret setup and rotation policy](github-secrets.md#gh_aw_github_token)
for the scoped temporary PAT exception and platform PR-creation permissions.
Events caused by built-in `GITHUB_TOKEN` normally do not trigger subsequent
PR workflows; explicit `workflow_dispatch` is an exception. Check the installed
bot PR producer for a labeler dispatch fallback rather than assuming that
creating a PR also ran labeling and every PR gate. Adding a token is not a
substitute for verifying checks or granting source approval.

## Related contracts

- [Spec-to-production pipeline](../guides/spec-to-production.md).
- [Roadmap race-safe persistence spec](../spec/roadmap-race-safe-persistence.spec.md).
- [GitHub secrets](github-secrets.md).
