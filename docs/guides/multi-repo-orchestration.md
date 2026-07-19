# Multi-Repo Orchestration Guide

This guide explains the **hub-and-spoke** pattern for orchestrating CI/CD
across multiple GitHub repositories using `workflow_dispatch`. It covers
authentication, output sharing, throttling, and failure handling.

The companion Copilot instruction file is
[`instructions/basecoat-60-workflow-multi-repo-orchestration.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/basecoat-60-workflow-multi-repo-orchestration.instructions.md).

## When to Use This Pattern

Use hub-and-spoke orchestration when:

- A platform or infra team needs to roll out a change to N service repos
  simultaneously (fleet management).
- A migration factory needs to process repositories in sequence or parallel.
- A monorepo is being split into polyrepo and deployment needs to be
  coordinated across the new repos during transition.

## Hub-Only Dispatch Rule

The hub repo is the single source of orchestration truth.

- The hub calls `workflow_dispatch` on spoke repos.
- Spoke repos never call back to the hub -- they expose a `workflow_dispatch`
  trigger and respond to inputs only.
- This prevents dispatch cycles and makes the dependency graph acyclic and
  auditable.

```yaml
# hub repo: .github/workflows/orchestrate.yml
jobs:
  dispatch-spokes:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        spoke: [spoke-alpha, spoke-beta, spoke-gamma]
    steps:
      - name: Dispatch spoke workflow
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: '${{ matrix.spoke }}',
              workflow_id: 'deploy.yml',
              ref: 'main',
              inputs: { environment: 'production', sha: context.sha },
            });
```

## Spoke Ownership

Spoke repos own their infrastructure, build pipeline, and deployment logic.
The hub is an orchestrator, not a deployer.

- Spoke `deploy.yml` defines **how** the spoke deploys -- not the hub.
- The hub passes context (SHA, environment, version tag) as `inputs`.
- Spokes must validate and act on inputs defensively.

```yaml
# spoke repo: .github/workflows/deploy.yml
on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [staging, production]
      sha:
        required: true
        description: "Commit SHA to deploy"

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.sha }}
      - run: ./scripts/deploy.sh
```

## Cross-Repo Authentication

### Choosing PAT vs. OIDC

Use **OIDC** for cloud resource access inside spokes (Azure, AWS, GCP) -- no
long-lived credentials. Use a **fine-grained PAT or GitHub App** for the hub's
dispatch call itself.

| Scenario | Auth method |
| --- | --- |
| Hub dispatches to spokes in same org | Fine-grained PAT (`actions:write`) |
| Hub reads spoke run status | Fine-grained PAT (`actions:read`) |
| Cross-org dispatch | GitHub App with installation tokens |
| Spoke accesses cloud resources | OIDC (workload identity federation) |

### Scoping the Dispatch Credential

The hub's `HUB_DISPATCH_TOKEN` should be scoped as narrowly as possible:

- Repository access: spoke repos only (not the hub or unrelated repos).
- Permissions: **Actions -> Read and write** only -- not `Contents`, `Secrets`,
  or `Administration`.

Rotate PATs every 30 days. Set PAT expiration to 30 days or less. For
zero-rotation credentials, use a GitHub App
with an installation token generated per run.

### Secrets Layout

```text
Hub repo secrets:
  HUB_DISPATCH_TOKEN     <- dispatch credential (PAT or App token)

Spoke repo secrets:
  AZURE_CLIENT_ID        <- spoke's own OIDC client
  AZURE_SUBSCRIPTION_ID
  AZURE_TENANT_ID
  (no hub credentials)   <- hub tokens never live in spokes
```

## Passing Outputs Between Repos

### Artifacts

For build outputs, test reports, or deployment manifests that a downstream hub
step needs to consume:

```yaml
# spoke: upload artifact
- uses: actions/upload-artifact@v4
  with:
    name: build-results-${{ github.sha }}
    path: dist/
    retention-days: 1

# hub: poll spoke run, then download artifact
- name: Wait for spoke and download artifact
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
    script: |
      // Poll spoke run until completed (see full example in instructions file)
      const runId = await waitForSpokeRun('spoke-alpha', context.sha);
      core.setOutput('spoke_run_id', runId);

- uses: actions/download-artifact@v4
  with:
    name: build-results-${{ inputs.sha }}
    github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
    repository: ${{ github.repository_owner }}/spoke-alpha
    run-id: ${{ steps.wait.outputs.spoke_run_id }}
```

### Lightweight Values

For small values (version numbers, deployment URLs), use the GitHub Deployments
API or a GitHub environment variable -- avoid full artifacts for small payloads.

## Rate Limiting and Throttling

### Sequential vs. Matrix

| Approach | Use when | Trade-off |
| --- | --- | --- |
| Sequential jobs | Spokes share a downstream resource | Slower but safe |
| Matrix dispatch | Spokes are independent | Faster; watch `max-parallel` |

GitHub enforces approximately **1,000 `workflow_dispatch` events per hour** per
token. For large fleets:

- Cap matrix concurrency with `max-parallel: 5` (or lower for large fleets).
- Add a `sleep 2` step between dispatch calls to pace API requests.
- For fleets > 100 spokes, use sequential batches with a pause between batches.

```yaml
strategy:
  max-parallel: 5
  fail-fast: false
  matrix:
    spoke: [alpha, beta, gamma, delta, epsilon]
steps:
  - run: sleep 2
  - name: Dispatch
    uses: actions/github-script@v7
    # ...
```

## Error Handling

### Hub-Level Aggregation

Set `fail-fast: false` on the matrix so all spokes run even if one fails. Use
a `gate` job with `if: always()` to aggregate and surface failures.

```yaml
jobs:
  dispatch-spokes:
    continue-on-error: true
    strategy:
      fail-fast: false
      matrix:
        spoke: [alpha, beta, gamma]

  gate:
    needs: dispatch-spokes
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Fail if any spoke failed
        run: |
          if [[ "${{ needs.dispatch-spokes.result }}" != "success" ]]; then
            echo "One or more spokes failed. Check the dispatch-spokes job matrix."
            exit 1
          fi
```

### Rollback Strategy

When a partial fleet deployment fails, the hub must roll back spokes that
already succeeded:

1. Record dispatched spoke names and run IDs as job outputs or artifact.
2. Dispatch a rollback call to each succeeded spoke using `inputs.rollback: 'true'`.
3. Spokes implement idempotent rollback steps triggered by that input.

```yaml
# spoke deploy workflow -- rollback-capable
on:
  workflow_dispatch:
    inputs:
      rollback:
        default: "false"
        type: string

steps:
  - run: |
      if [[ "${{ inputs.rollback }}" == "true" ]]; then
        ./scripts/rollback.sh
      else
        ./scripts/deploy.sh
      fi
```

## Common Mistakes

| Anti-pattern | Why it's wrong | Correct approach |
| --- | --- | --- |
| Spoke calls `gh workflow run` on the hub | Creates dispatch cycles | Spoke signals status via API only |
| Hub embeds spoke deploy logic | Violates spoke ownership | Hub passes inputs only; spoke decides how |
| Hub token stored as spoke secret | Hub credential leaks | Each repo provisions its own secrets |
| `fail-fast: true` on matrix | Hides which spokes passed or failed | Use `fail-fast: false` + gate job |
| No rollback path | Partial deployment leaves fleet inconsistent | Implement rollback input in all spokes |

## References

- [GitHub Actions: `workflow_dispatch`](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch)
- [GitHub Actions: Reusable workflows vs. dispatch](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Fine-grained personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
- [GitHub Apps for cross-repo auth](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps)
- Related instruction: [`instructions/basecoat-60-workflow-ci-firewall.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/basecoat-60-workflow-ci-firewall.instructions.md)
- Related instruction: [`instructions/basecoat-50-security-secrets-management.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/basecoat-50-security-secrets-management.instructions.md)
