# Runner Routing Strategy

> **Rule:** Match every job's `runs-on` to the workload's resource, network, and cost profile. Never default all jobs to `ubuntu-latest` when self-hosted capacity exists.

## Decision Matrix

| Workload characteristic | Recommended runner |
|---|---|
| Needs private Azure/cloud access (Packer, Key Vault) | Self-hosted (managed identity or private network) |
| Public-control-plane Azure deployment using OIDC | GitHub-hosted is acceptable |
| Heavy compute (image builds, large compiles) | Self-hosted (dedicated capacity) |
| Quick CI gate (<30 s typical) | GitHub-hosted (fast cold-start) |
| Requires CodeQL or GitHub-native tooling | GitHub-hosted |
| Security-sensitive (secret access, regulated data) | Self-hosted (controlled environment) |
| PR validation (needs fast feedback) | GitHub-hosted or hybrid |
| Untrusted code from external forks | GitHub-hosted only |

## Routing Patterns

### Pattern 1: Direct routing to a runner group

Use when the job always requires self-hosted resources (private deployment,
image build, or Key Vault access).

```yaml
jobs:
  deploy:
    name: Deploy to Azure
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]
```

### Pattern 2: Configurable routing via repository variable

Use when teams need to toggle between runner types without changing workflow code. Set `USE_SELF_HOSTED` to `'true'` in repository or environment variables to route to self-hosted runners.

```yaml
jobs:
  build:
    name: Build
    runs-on: >-
      ${{
        vars.USE_SELF_HOSTED == 'true'
          && fromJson('{"group":"shared-build-agents","labels":["self-hosted","linux","x64"]}')
          || 'ubuntu-latest'
      }}
```

### Pattern 3: Fast-fail timeout for self-hosted

Use when self-hosted is preferred but the workflow must not block indefinitely if the pool is scaled to zero.

```yaml
jobs:
  build:
    name: Build
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]
    timeout-minutes: 10  # fail fast if no runner picks up the job
```

### Pattern 4: Hybrid pipeline — route each job by workload type

Use for pipelines that include both lightweight CI gates and heavyweight deployment jobs.

```yaml
jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest          # fast, cheap, no network requirements

  test:
    name: Test
    runs-on: ubuntu-latest          # stateless, no private network needed
    needs: [lint]

  build-image:
    name: Build Container Image
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]   # dedicated CPU / cache
    needs: [test]

  deploy:
    name: Deploy to Azure
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]   # managed identity required
    needs: [build-image]
    if: github.ref == 'refs/heads/main'
```

## Rationale

| Criterion | GitHub-hosted | Self-hosted |
|---|---|---|
| Cold-start latency | ~10–30 s | Varies (0 s if warm, minutes if scaled to zero) |
| Managed identity / private network | ❌ No | ✅ Yes |
| Runner minutes cost | Counts against plan quota | Infrastructure cost only |
| Maintenance burden | ❌ None | ✅ Team-managed |
| Isolation from other workloads | ✅ Ephemeral VM per job | Depends on runner pool config |
| GitHub-native tooling (CodeQL, etc.) | ✅ Pre-installed | May require manual setup |

## Anti-Patterns

### All jobs on `ubuntu-latest` when self-hosted runners exist

```yaml
# ❌ BAD — ignores self-hosted capacity; incurs GitHub-hosted minutes
jobs:
  deploy:
    runs-on: ubuntu-latest   # cannot reach Azure Key Vault; will fail
```

### Self-hosted runners for trivial jobs

```yaml
# ❌ BAD — wastes dedicated capacity on a 5-second echo step
jobs:
  greet:
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]
    steps:
      - run: echo "Hello"
```

### No timeout on self-hosted jobs

```yaml
# ❌ BAD — job waits indefinitely when pool is scaled to zero
jobs:
  build:
    runs-on:
      group: shared-build-agents
      labels: [self-hosted, linux, x64]
    # missing timeout-minutes
```

### Mixing sensitive and untrusted workloads on the same runner group

```yaml
# ❌ BAD — external fork PR runs on the same runner that handles secrets
on:
  pull_request_target:   # runs in privileged context
jobs:
  ci:
    runs-on:
      group: shared-build-agents   # has access to org secrets
      labels: [self-hosted]
```

External contributor PRs must run on GitHub-hosted runners or an isolated, unprivileged runner group with no secret access.

## Quick Reference

| Job type | Recommended `runs-on` |
|---|---|
| Lint / unit test / PR gate | `ubuntu-latest` |
| CodeQL / dependency scan | `ubuntu-latest` |
| Container image build (heavy) | `group: shared-build-agents` + `[self-hosted, linux, x64]` |
| Private-cloud deployment | `group: shared-build-agents` + `[self-hosted, linux, x64]` |
| Public-control-plane OIDC deployment | `ubuntu-latest` is acceptable |
| Packer / VM image build | `group: shared-build-agents` + `[self-hosted, linux, x64]` |
| Key Vault / secrets retrieval | `group: shared-build-agents` + `[self-hosted, linux, x64]` |
| External fork / untrusted PR | `ubuntu-latest` only |

## Related Guardrails

- [CI/CD Concurrency Settings](ci-concurrency.md) — prevent duplicate runs and stuck queues
- [OIDC Federation](oidc-federation.md) — prefer OIDC over long-lived secrets on self-hosted runners
- [Secrets in Workflows](secrets-in-workflows.md) — handle secrets safely regardless of runner type
