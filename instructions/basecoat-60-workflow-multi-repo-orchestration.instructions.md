---
description: "Multi-repo orchestration guidance for hub-and-spoke CI/CD patterns using workflow_dispatch."
applyTo: ".github/workflows/*.yml"
---

# Multi-Repo Orchestration (Hub-and-Spoke)

Use this instruction when writing GitHub Actions workflows that orchestrate
CI/CD across multiple repositories using `workflow_dispatch`. This pattern
appears in enterprise fleet management, migration factories, and
monorepo-to-polyrepo splits.

## Hub-Only Dispatch Rule

Only hub repos initiate cross-repo workflows. Spoke repos are consumers -- they
are called, never call out.

- The hub owns the orchestration logic and dispatch sequence.
- Spokes expose a `workflow_dispatch` trigger with defined `inputs`; they never
  call `gh workflow run` on other repos.
- If a spoke needs to signal completion, it updates a status check or posts to
  an API -- it does **not** dispatch back to the hub.

```yaml
# hub repo: .github/workflows/orchestrate.yml
on:
  push:
    branches: [main]
  workflow_dispatch:

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
              inputs: {
                environment: 'production',
                sha: context.sha,
              },
            });
```

## Spoke Ownership

Spokes own their infrastructure, build, and deploy logic. The hub only
orchestrates -- it never modifies spoke code, secrets, or IaC.

- Each spoke's `deploy.yml` (or equivalent) is the single source of truth for
  how that repo deploys.
- The hub passes context (SHA, environment, version) as `inputs`; it does not
  embed deployment logic.
- Spokes must validate inputs at the top of their workflow using `if:` guards
  or explicit checks.

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
      - name: Deploy
        run: ./scripts/deploy.sh
```

## Cross-Repo Authentication

### PAT vs. OIDC

| Scenario | Recommended auth | Notes |
| --- | --- | --- |
| Hub dispatches to spokes in same org | Fine-grained PAT or GitHub App | Scope to `actions:write` on target repos |
| Hub reads spoke workflow run status | Fine-grained PAT with `actions:read` | Polling `GET /repos/{owner}/{repo}/actions/runs` |
| Cross-org dispatch | GitHub App with installation tokens | PATs cross org boundaries poorly |
| Cloud resource access in spokes | OIDC (preferred) | No long-lived secrets; use `actions/oidc-token` |

Use OIDC for cloud resource access inside spokes; use a GitHub App or
fine-grained PAT for the hub-to-spoke dispatch call itself.

### Secrets Management

- Store the dispatch credential as a repository or organization secret on the
  hub: `HUB_DISPATCH_TOKEN`.
- Never copy hub secrets into spokes -- spokes provision their own credentials.
- Rotate PATs every 30 days; set PAT expiration to 30 days or less.
- Prefer GitHub Apps for zero-rotation tokens.
- Audit token scope: the dispatch token needs only `actions:write` on spoke
  repos, not `repo` (full) scope.

```yaml
# Minimal fine-grained PAT scope for dispatch
# Settings -> Developer settings -> Fine-grained tokens
# Repository access: select spoke repos only
# Permissions: Actions -> Read and write
```

## Output Passing Between Repos

### Via Workflow Outputs (same-run coordination)

Workflow outputs work within a single repo's job graph. For cross-repo output,
use artifacts or environment variables written to a shared store.

### Via Artifacts

```yaml
# spoke repo: upload results
- name: Upload build output
  uses: actions/upload-artifact@v4
  with:
    name: build-results-${{ github.sha }}
    path: dist/
    retention-days: 1

# hub repo: poll and download spoke artifact
- name: Wait for spoke run
  id: wait
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
    script: |
      const maxAttempts = 20;
      for (let i = 0; i < maxAttempts; i++) {
        const runs = await github.rest.actions.listWorkflowRuns({
          owner: context.repo.owner,
          repo: 'spoke-alpha',
          workflow_id: 'deploy.yml',
          head_sha: '${{ inputs.sha }}',
        });
        const run = runs.data.workflow_runs[0];
        if (run?.conclusion === 'success') {
          core.setOutput('run_id', run.id);
          return;
        }
        if (run?.conclusion === 'failure') {
          core.setFailed('Spoke workflow failed');
          return;
        }
        await new Promise(r => setTimeout(r, 30000));
      }
      core.setFailed('Timed out waiting for spoke');

- name: Download spoke artifact
  uses: actions/download-artifact@v4
  with:
    name: build-results-${{ inputs.sha }}
    github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
    repository: ${{ github.repository_owner }}/spoke-alpha
    run-id: ${{ steps.wait.outputs.run_id }}
```

### Via Environment Variables and API

For lightweight data (version numbers, deployment URLs), write to a GitHub
environment variable or use the Deployments API rather than full artifacts.

## Rate Limiting and Throttle Guidance

### Sequential vs. Matrix Dispatch

| Approach | When to use | Risk |
| --- | --- | --- |
| Sequential | > 5 spokes; spokes share a downstream dependency | Slower; safer for shared resources |
| Matrix (`strategy.matrix`) | Independent spokes; parallel is safe | May hit `workflow_dispatch` API limits |

GitHub enforces a limit of **~1,000 `workflow_dispatch` events per hour** per
authenticated token. For large fleets:

- Batch matrix dispatches to <= 20 spokes per run.
- Add `max-parallel` to the matrix to cap concurrent dispatch calls.
- Space sequential dispatches >= 2 seconds apart using a `sleep` step.

```yaml
jobs:
  dispatch-spokes:
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 5        # cap concurrent API calls
      matrix:
        spoke: [alpha, beta, gamma, delta, epsilon]
    steps:
      - name: Throttle between dispatches
        run: sleep 2

      - name: Dispatch
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
          script: |
            await github.rest.actions.createWorkflowDispatch({
              owner: context.repo.owner,
              repo: '${{ matrix.spoke }}',
              workflow_id: 'deploy.yml',
              ref: 'main',
            });
```

## Error Handling

### When a Spoke Fails

The hub must decide: stop all remaining spokes, or continue and aggregate
failures at the end.

- Use `continue-on-error: true` with a final aggregation step to collect all
  spoke results before failing the hub run.
- Do **not** silently swallow spoke failures -- always surface them in the hub
  run summary.

```yaml
jobs:
  dispatch-spokes:
    runs-on: ubuntu-latest
    continue-on-error: true           # collect all results before failing
    strategy:
      fail-fast: false                # run all matrix legs even if one fails
      matrix:
        spoke: [alpha, beta, gamma]
    outputs:
      result-${{ matrix.spoke }}: ${{ steps.dispatch.outputs.result }}
    steps:
      - name: Dispatch and wait
        id: dispatch
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.HUB_DISPATCH_TOKEN }}
          script: |
            // ... dispatch logic ...
            core.setOutput('result', conclusion);

  gate:
    needs: dispatch-spokes
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Assert all spokes passed
        run: |
          echo "alpha:  ${{ needs.dispatch-spokes.outputs.result-alpha }}"
          echo "beta:   ${{ needs.dispatch-spokes.outputs.result-beta }}"
          echo "gamma:  ${{ needs.dispatch-spokes.outputs.result-gamma }}"
          if [[ "${{ needs.dispatch-spokes.result }}" != "success" ]]; then
            echo "One or more spokes failed. See above for details."
            exit 1
          fi
```

### Rollback Patterns

When a hub dispatch run fails mid-fleet, rollback must be coordinated:

- Dispatch a `rollback` input to spokes that already succeeded.
- Record which spokes were dispatched and their run IDs in a job output or
  artifact for audit.
- Spokes must implement their own idempotent rollback step triggered by
  `inputs.rollback == 'true'`.

```yaml
# spoke repo: rollback-capable deploy workflow
on:
  workflow_dispatch:
    inputs:
      rollback:
        required: false
        default: "false"
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy or rollback
        run: |
          if [[ "${{ inputs.rollback }}" == "true" ]]; then
            ./scripts/rollback.sh
          else
            ./scripts/deploy.sh
          fi
```

## Anti-Patterns

```yaml
# WRONG -- spoke dispatches back to hub (creates cycles)
# spoke repo: .github/workflows/notify-hub.yml
- run: gh workflow run hub-notify.yml --repo org/hub-repo

# WRONG -- hub embeds spoke deploy logic (violates spoke ownership)
- name: Deploy spoke-alpha
  run: |
    ssh spoke-alpha-server "docker pull && docker-compose up -d"

# WRONG -- dispatch token stored in spoke (hub credential leak)
# spoke repo secrets: HUB_DISPATCH_TOKEN  <- never do this

# WRONG -- matrix with fail-fast: true stops partial fleet on first error
strategy:
  fail-fast: true   # loses visibility into which spokes passed/failed
```

## Review Lens

- Does the hub workflow avoid embedding spoke-specific deploy logic?
- Are spoke workflows triggered only via `workflow_dispatch`, never calling
  back to the hub?
- Is the dispatch credential scoped to `actions:write` only -- not full `repo`?
- Does the hub use `fail-fast: false` and aggregate spoke results before
  failing?
- Is there a rollback path for already-deployed spokes when later spokes fail?
- Are matrix dispatches capped with `max-parallel` to avoid rate limit bursts?
