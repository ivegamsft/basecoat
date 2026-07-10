# Layer Boundary Matrix Template

Use this template to formalize isolation boundaries and ownership for each layer.

## Layer Inventory

| Layer | Owned Paths | Build/Test Workflow | Deploy Workflow | Version Lane | Owner | Depends On | Triggered By |
|---|---|---|---|---|---|---|---|
| Mobile | `mobile/**` | `mobile-tests.yml` | `mobile-deploy.yml` | `mobile-v*` | `<team>` | Shared UI kit | Mobile + shared-only |
| Database | `db/**`, `migrations/**` | `db-validate.yml` | `db-deploy.yml` | `db-v*` | `<team>` | None | Database-only + approved schema interface changes |
| Portal | `portal/**` | `portal-tests.yml` | `portal-deploy.yml` | `portal-v*` | `<team>` | API contracts | Portal + explicit contract changes |
| Extension | `mcp/basecoat-extension/**`, `infra/extension/**` | `extension-ci.yml` | `extension-deploy.yml` | `extension-v*` | `<team>` | Shared auth package | Extension + shared-auth changes |
| MCP | `mcp/basecoat-metrics/**`, `infra/mcp/**` | `mcp-build.yml` | `mcp-deploy.yml` | `mcp-v*` | `<team>` | Shared runtime libs | MCP + shared-runtime changes |
| Infra (AWS) | `infra/aws/**` | `terraform-validate.yml` | `terraform-deploy.yml` | `infra-v*` | `<team>` | None | Infra-only |

## Shared/Core Contracts

| Shared Area | Paths | Consumers | Change Policy | Validation Requirement |
|---|---|---|---|---|
| Shared API contracts | `<path>` | Portal, Mobile | Semver + compatibility gate | Contract tests on consumers |
| Shared auth/session package | `<path>` | Extension, MCP | Backward compatible by default | Auth integration smoke checks |
| Workflow templates | `.github/workflows/**` | All lanes | Must not broaden triggers without approval | Trigger matrix policy check |

## Coupling Exceptions

Document exceptions where one layer intentionally triggers another lane.

| Source Layer | Target Layer | Why Coupled | Trigger Condition | Approval Required |
|---|---|---|---|---|
| `<source>` | `<target>` | `<reason>` | `<condition>` | `<owner/role>` |
