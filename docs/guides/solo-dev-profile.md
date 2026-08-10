# Solo-Developer Governance Profile

Use the `solo-dev` profile for a repository with one accountable maintainer and
an available independent reviewer. It still requires pull requests, required
checks, protected `main`, and an auditable merge path. It simplifies operations;
it does not weaken branch protection or authorize administrator bypass.

## Choose the right profile

| Signal | `solo-dev` | `team-dev` | `regulated-team` |
|---|---|---|---|
| Active maintainers | One accountable maintainer plus a designated independent reviewer | Two or more regular contributors | Any team with mandated separation of duties |
| Routine independent review | Required by the portable ruleset | Required for medium and higher risk | Required for every risk tier |
| Merge queue | Deferred | Deferred | Required |
| Production, policy exceptions, incidents | Independent human approval remains required | Independent human approval required | Stricter approval and evidence requirements |
| Best fit | Single-owner service with reliable CI and an available reviewer | Shared ownership and normal team delivery | Regulated, security-sensitive, or audited delivery |

Choose `team-dev` as soon as another person regularly owns, reviews, or operates
the repository. Choose `regulated-team` when policy, customer commitments, or
compliance controls require separation of duties. Repository size is not the
deciding factor; ownership and risk are.

## Non-negotiable solo-dev controls

`minimal` branch policy means the minimum protected posture, not an unprotected
branch:

- every change to `main` uses a pull request
- direct pushes, force pushes, and branch deletion are blocked
- required status checks run against the current head and must succeed
- review conversations must be resolved
- administrators are subject to the rules and the bypass list is empty
- the auto-merge workflow uses GitHub auto-merge, never `--admin`
- GitHub requires one independent approval after the last push
- the executor's `BaseCoat merge eligibility` status is required as a
  fail-closed policy and check aggregator

The six canonical validation checks come from
`.github/governance/policy-packs.json`:

1. `lint-and-validate`
2. `test`
3. `validate-commit-messages`
4. `validate-unix`
5. `validate-windows`
6. `release-label-gate`

The ruleset must also require `BaseCoat merge eligibility`. The trusted
executor publishes that commit status directly against the pull request head
SHA. Pin the required context to GitHub Actions integration ID `15368` for
provenance, but do not treat that shared app identity as the human boundary:
another repository workflow can run under the same integration. The globally
required independent review is the portable enforceable boundary. Pending
validation or policy violations keep the status red and prevent both manual and
automatic merge.

If a consumer uses different check names, update its local policy pack and
ruleset together. Do not delete checks from only one surface.

## Self-merge policy

For the portable `solo-dev` setup, every risk tier requires one approving
review. The repository owner may author and merge the PR after another
qualified collaborator approves the latest push and all required checks and
repository rules pass. This is the permitted **self-merge** path.

Self-merge does not mean self-approval. GitHub's pull-request rule, not a
repo-local status producer, enforces the human boundary. The executor ignores
the PR author's review, validates reviewer repository permission, and counts
only write, maintain, or admin approvals. If no independent approver is
available, the change remains blocked.

Conditional zero-review merging requires an executor-specific GitHub App or an
organization-required workflow outside PR-author control. The shipped
repo-local executor does not claim that identity boundary, so its portable
ruleset requires one review globally.

Production release paths are explicit policy, not inferred from the broad
`high` tier. The shipped policy pack includes every BaseCoat workflow that can
target the `production` environment in `production_release_paths`.

Before enabling solo-dev self-merge in a consumer repository, inventory
every local workflow that can deploy to production, including workflows with
dynamic `environment` expressions, and add every path to
`production_release_paths`. This is a mandatory precondition: do not activate
the solo-dev ruleset until the consumer check names and production workflow
inventory are complete.

Risk tier is the highest path tier matched by the changed files. See
[Governance Policy Packs](../reference/governance-policy-packs.md) and
[Risk-Tier Autonomy Policy](../reference/risk-tier-policy.md).

## Configure the profile

### 1. Commit the onboarding contract

Create `.github/basecoat-onboarding-profile.json`:

```json
{
  "contract_version": "1.0.0",
  "profile": "solo-dev",
  "branch_policy": "minimal",
  "workflow_pack": "solo",
  "template_pack": "solo",
  "telemetry_mode": "local",
  "secrets_mode": "local",
  "hook_pack": "none",
  "preserve_local_customizations": true,
  "allow_profile_downgrade": false
}
```

Validate the selection through the existing bootstrap entrypoint:

```powershell
pwsh scripts/bootstrap.ps1 `
  -OnboardingContractPath .github\basecoat-onboarding-profile.json `
  -Silent
```

### 2. Install the existing merge executor

Use the downstream workflow installer rather than writing another auto-merge
implementation:

```powershell
pwsh scripts/configure-downstream-workflows.ps1 `
  -Workflow pr-auto-merge-executor.yml `
  -KeepUnknownBc
```

This installs:

- `.github/workflows/basecoat-pr-auto-merge-executor.yml`
- `.github/governance/policy-packs.json`
- `.github/governance/human-approval-boundaries.json`

The exact `-Workflow` selector installs only the executor and its governance
contracts. Targeted mode preserves every non-selected workflow; `-KeepUnknownBc`
adds an explicit safeguard for older installer versions. On reinstall, targeted
mode also preserves existing consumer governance files so local check names and
production paths are not overwritten. Review upstream governance changes and
merge them into the consumer policy deliberately.

The executor evaluates an existing PR and enables GitHub-native auto-merge with
`gh pr merge --auto --squash --delete-branch`. It does not discover BaseCoat
updates or create upgrade PRs. Keep consumer update detection and PR creation in
the consumer updater lifecycle; do not duplicate that implementation here.

### 3. Set repository options

In GitHub:

1. **Settings > General > Pull Requests**
   - enable **Allow auto-merge**
   - enable **Allow squash merging**
   - enable **Automatically delete head branches**
2. **Settings > Actions > General > Workflow permissions**
   - keep **Read repository contents and packages permissions**
   - do not grant repository-wide write access; the executor declares only its
     required `checks: read`, `contents: write`, `pull-requests: write`,
     `issues: write`, and `statuses: write` permissions
3. **Settings > Rules > Rulesets**
   - create an active branch ruleset targeting the default branch
   - require one approval and approval after the last push
   - require conversation resolution
   - require all six validation checks plus `BaseCoat merge eligibility`
   - require branches to be up to date
   - block deletion and non-fast-forward pushes
   - leave the bypass list empty
4. **Settings > Secrets and variables > Actions > Variables**
   - set `BASECOAT_POLICY_PACK` to `solo-dev`

Set the variable explicitly even though workflows can fall back to the policy
file's `default_profile`. Explicit selection prevents onboarding and workflow
defaults from being confused during migrations.

## Programmatic GitHub setup

The caller needs repository administration permission. Replace
`OWNER/REPOSITORY` before running these commands.

```powershell
$repository = "OWNER/REPOSITORY"

gh api --method PATCH "repos/$repository" `
  -F allow_auto_merge=true `
  -F allow_squash_merge=true `
  -F delete_branch_on_merge=true

gh variable set BASECOAT_POLICY_PACK `
  --repo $repository `
  --body "solo-dev"
```

Create `solo-dev-main-ruleset.json`:

```json
{
  "name": "BaseCoat solo-dev main",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "deletion"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "allowed_merge_methods": ["squash"],
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_approving_review_count": 1,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "do_not_enforce_on_create": false,
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          {"context": "lint-and-validate", "integration_id": 15368},
          {"context": "test", "integration_id": 15368},
          {"context": "validate-commit-messages", "integration_id": 15368},
          {"context": "validate-unix", "integration_id": 15368},
          {"context": "validate-windows", "integration_id": 15368},
          {"context": "release-label-gate", "integration_id": 15368},
          {"context": "BaseCoat merge eligibility", "integration_id": 15368}
        ]
      }
    }
  ]
}
```

Apply it:

```powershell
gh api --method POST "repos/$repository/rulesets" `
  --input solo-dev-main-ruleset.json
```

For an existing ruleset, use `PUT repos/$repository/rulesets/$rulesetId` with
the same payload rather than creating a duplicate.

## Verify before enabling routine auto-merge

Run each required workflow at least once so GitHub knows its check context, then
inspect the live configuration:

```powershell
gh variable get BASECOAT_POLICY_PACK --repo $repository
gh api "repos/$repository" `
  --jq '{allow_auto_merge,allow_squash_merge,delete_branch_on_merge}'
gh api "repos/$repository/rulesets" `
  --jq '.[] | select(.name == "BaseCoat solo-dev main") | {id,enforcement,bypass_actors}'
gh workflow list --repo $repository
```

Open a non-draft test PR and confirm:

1. the executor comment reports `solo-dev`, the expected risk tier, and one
   required independent approval
2. auto-merge remains pending while any required check is missing or failing
3. every test PR remains blocked without an independent approval after the last
   push
4. no run or command uses an administrator bypass

## Rollback

Use normal Git history for content rollback:

1. disable the auto-merge executor workflow
2. disable repository auto-merge if automated landing must stop immediately
3. revert the merged PR in a new protected PR
4. restore the previous ruleset payload if protection configuration changed
5. rerun required checks and record the rollback PR or incident

Do not force-push `main`, delete audit history, or use `gh pr merge --admin`.
A failed critical or production change follows the risk-tier rollback and
incident process rather than a solo-dev exception.

## Transition to a stronger profile

### Move to `team-dev`

Transition when a second maintainer becomes active, ownership is shared, or
routine independent review is expected:

1. change the onboarding contract to `profile: "team-dev"` and
   `migration_from: "solo-dev"`
2. set `BASECOAT_POLICY_PACK=team-dev`
3. update the ruleset to require the policy-pack approval baseline
4. rerun bootstrap and downstream workflow installation
5. verify required checks and reviewer routing before merging new work

### Move to `regulated-team`

Transition when compliance, security, or customer controls require stricter
evidence or separation of duties:

1. migrate from the current profile to `regulated-team`
2. require the regulated approval counts and `prd-spec-gate`
3. enable the required merge queue and organization-managed secrets/telemetry
4. remove any local exceptions and verify the empty bypass posture

When `migration_from` records the currently applied profile, bootstrap compares
profile strength and blocks a weaker target unless explicitly approved with
`allow_profile_downgrade: true`. Omitting `migration_from` prevents bootstrap
from identifying the transition, so migration contracts must always include it.
See the
[Onboarding Profile Contract](../reference/onboarding-profile-contract.v1.md)
for migration semantics.

## Related contracts

- [Onboarding Profile Contract](../reference/onboarding-profile-contract.v1.md)
- [Governance Policy Packs](../reference/governance-policy-packs.md)
- [Main Branch Protection Policy](../reference/branch-protection.md)
- [Risk-Tier Autonomy Policy](../reference/risk-tier-policy.md)
- [Workflow Installation](workflows-getting-started.md)
- `.github/base-coat/workflows/pr-auto-merge-executor.yml`
