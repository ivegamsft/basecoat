# Workflow Runner Routing Baseline

This repository uses explicit capability-based routing for workflow jobs so runner
selection is deterministic rather than ad hoc.

## Routing classes

Canonical runner classes live in:

- `.github/workflow-runner-capability-classes.json`
- `.github/workflow-runner-routing-contracts.json` (enforceable job-level contracts for deploy paths)

| Runner class | Default runs-on | Use for |
|---|---|---|
| `github-hosted-linux` | `ubuntu-latest` | lint, tests, docs, and public-endpoint deploy/release jobs, including OIDC |
| `github-hosted-windows` | `windows-latest` | Windows-specific validation |
| `github-hosted-macos` | `macos-latest` | macOS-specific validation |
| `self-hosted-linux` | self-hosted group + labels | jobs requiring private network access or runner-managed identity |
| `configurable-deploy` | `${{ vars.RUNNER_DEPLOY \|\| 'ubuntu-latest' }}` | deploy-path migration with a safe fallback |
| `configurable-release` | `${{ vars.RUNNER_RELEASE \|\| vars.RUNNER_DEPLOY \|\| 'ubuntu-latest' }}` | release/publish lane isolation with a deploy-lane fallback |
| `github-hosted-matrix` | `${{ matrix.os }}` | multi-OS validation where a single job fans out across OS images |
| `reusable-workflow` | `uses: ./.github/workflows/<reusable>.yml` | delegated runner choice managed by a reusable workflow |

## Capability audit

Every workflow job is classified by required capability via:

```powershell
pwsh scripts/audit-workflow-runner-capabilities.ps1 -OutputFormat markdown -OutputPath docs/operations/workflow-runner-capability-audit.md
```

To enforce contracts in CI (fail on violations):

```powershell
pwsh scripts/audit-workflow-runner-capabilities.ps1 -OutputFormat markdown -FailOnContractViolation
```

The audit report includes:

1. Classification of every workflow job.
2. Recommended runner class versus actual runner assignment.
3. Logged mismatches and conditional routes.
4. Runner contract violations, including required/forbidden capabilities,
   timeout bounds, and routing markers.

Authentication and network requirements are modeled separately:

- `oidc` requires both an effective `id-token: write` permission and an
  applicable action configuration. For Azure Login, the step must provide
  `client-id`, `tenant-id`, and `subscription-id`; a `with.creds` login is
  classified separately as `credential-auth`.
- Root permission inheritance is read only from the root-level `permissions`
  block. Job-level permissions apply only to that job.
- Repository tokens and deployment credentials do not imply private network
  access.
- Runner assignment is not capability evidence. `private-network` comes from an
  explicit YAML comment marker (`# runner-capability: private-network`) or a
  routing contract requirement. Marker-like command or string content is not
  workload evidence.
- `runner-managed-identity` comes from a routing contract requirement or runner
  identity flows such as `az login --identity`, `Connect-AzAccount -Identity`,
  or Azure Login `auth-type: IDENTITY`. Only executable command text counts:
  quoted examples, heredoc/here-string bodies, PowerShell block comments,
  full-line comments, and unquoted inline comments are excluded from identity
  evidence.

In the capability class catalog, `self-hosted-linux` declares these alternatives
through `required_capabilities_any`; a workload needs either private networking
or runner-managed identity, not both. The audit loads this catalog directly and
selects the highest-priority matching class, so catalog changes cannot silently
diverge from recommendation logic. The catalog also owns the canonical
capability vocabulary used to reject misspelled class and contract values.

This separation prevents public OIDC deployments from being misrouted while
retaining a self-hosted recommendation for genuine private runner requirements.

The scheduled automation lives at:

- `.github/workflows/workflow-runner-capability-audit.yml`

## Deployment workflows

Deploy workflows that require private networking or runner-managed identity can
route through org pools with safe fallback:

```yaml
runs-on: ${{ vars.RUNNER_DEPLOY || 'ubuntu-latest' }}
```

This pattern remains compatible with protected self-hosted rollouts.

Jobs that only use public service endpoints and require a predictable Linux
toolchain stay pinned to `ubuntu-latest`. The routing contract covers:

- `mcp-build.yml` (`build`) for Docker smoke tests and Bicep compilation.
- `extension-deploy.yml` and `mcp-deploy.yml` (`build-push`) for Docker and GHCR.
- `extension-deploy.yml` and `mcp-deploy.yml` (`deploy`) for bash-based Azure
  control-plane deployment using credential login.
- `portal-deploy.yml` (`deploy`) for Azure OIDC or secret-based login over
  public control-plane endpoints.
- `docs.yml` (`deploy`) for GitHub Pages OIDC deployment.
- `package-basecoat.yml`, `release.yml`, and `publish-to-production.yml` for
  GitHub release and repository publication APIs.
- `audit-environment-drift.yml` (`audit`) for public API drift inspection.

Contracts are keyed by workflow and job. They require the expected public
capabilities and forbid `private-network` and `runner-managed-identity`, so a new
job does not inherit an exception and a contracted job cannot silently acquire a
private runner requirement.

The public-hosted contract set is asserted explicitly by workflow guardrails.
Removing a contract, weakening its forbidden capabilities, or changing the v2
shape fails validation instead of silently reducing coverage.

For deploy workflows that require Docker or other Linux-only capabilities on
PR events (where `vars.RUNNER_DEPLOY` may resolve to a Windows runner), add
a PR guard:

```yaml
runs-on: ${{ github.event_name == 'pull_request' && 'ubuntu-latest' || vars.RUNNER_DEPLOY || 'ubuntu-latest' }}
```

This ensures PR-triggered runs use ubuntu-latest (GitHub-hosted Linux) while
push-to-main and workflow_dispatch flows route through `vars.RUNNER_DEPLOY`.
The fork exclusion is handled separately by a job-level `if:` condition.

Note: The `resolve-deploy-runner` resolver/preflight job pattern that previously
enforced `RUNNER_DEPLOY` as a hard requirement has been removed. For an approved
private route, use the soft-fallback expression above rather than failing when
`RUNNER_DEPLOY` is unset.

The policy still supports a configurable release lane when private access is
actually required:

```yaml
runs-on: ${{ vars.RUNNER_RELEASE || vars.RUNNER_DEPLOY || 'ubuntu-latest' }}
```

Use this expression only when a release needs private network access or
runner-managed identity. Current BaseCoat release/publication jobs use public
GitHub APIs and remain pinned to `ubuntu-latest`.

## Runner-health observability

The repository now includes a dedicated workflow to report queue wait, offline
capacity, and wrong-runner failure patterns for release/deploy lanes:

- `.github/workflows/runner-health-observability.yml`
- `scripts/report-runner-health.ps1`

This workflow emits markdown and JSON artifacts plus a step summary so lane
routing debt can be spotted quickly without inspecting each run manually.

If a future workflow uses `RUNNER_DEPLOY`, the audit classifies it as a
conditional private route. Public-endpoint workflows should not adopt that
expression merely because they deploy.

## Intentionally GitHub-hosted workflows

The following remain on GitHub-hosted runners by design:

- `validate-basecoat.yml`, `ci.yml`, and `pr-validation.yml` for fast, deterministic PR feedback.
- `docs.yml` for standard public tooling (MkDocs + GitHub Pages) with no private network requirement.
- Matrix jobs pinned to platform images (for example, `windows-latest` in `validate-basecoat.yml` and OS matrix jobs in `smoke-test.yml` and `sync-test.yml`) to preserve cross-platform coverage.

## Recent audit gaps

Recent workflow audits found repeated cases where runner choice was still being
handled ad hoc in MCP, deploy, and release lanes. Keep the routing contract
explicit so future changes do not regress back to hard-coded assumptions:

- Use `vars.RUNNER_DEPLOY` and `vars.RUNNER_RELEASE` only when private network
  access or runner-managed identity is an actual requirement.
- Pin public-endpoint deployment and publication jobs to `ubuntu-latest`, and
  record them in the routing contract with required and forbidden capabilities.
- CI-only workflows that require Docker (e.g., image build/smoke tests) should
  pin to `ubuntu-latest` unconditionally — do not route CI-only workflows
  through `vars.RUNNER_DEPLOY`.
- Keep PR validation and public OIDC deployments on GitHub-hosted runners unless
  private network access or runner-managed identity is required.
