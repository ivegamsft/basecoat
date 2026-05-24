# VS Code Agent Mode Tool Confirmation Policy

## Purpose

This policy defines when the VS Code agent mode must require explicit user confirmation before executing a tool call.

## Policy

- Treat every mutating or side-effecting tool as **confirm-required by default**.
- A confirmation step must occur immediately before execution for any tool call that can:
  - Create, update, or delete files outside the current workspace
  - Execute shell or terminal commands
  - Perform network writes to external systems (GitHub, cloud APIs, ticketing systems, databases)
  - Change deployment, infrastructure, identity, policy, or access configuration
  - Submit forms, send messages, or trigger workflow runs on behalf of a user
- Read-only tools may run without confirmation only when they have no side effects and no external mutation path.

## Risk Tiers

| Tier | Tool profile | Confirmation requirement |
|---|---|---|
| Tier 0 | Read-only lookup, local file read, metadata inspection | No confirmation required |
| Tier 1 | Workspace-local write (`create`, `edit`, `apply_patch`) | Single-step confirmation required |
| Tier 2 | Command execution, package install, git write, external API mutation | Explicit per-action confirmation required |
| Tier 3 | Production-impacting actions (deploy, infra mutation, identity/policy changes, destructive deletes) | Explicit confirmation plus restated impact and target required |

## Confirmation UX Requirements

- Show the target, action, and blast radius in plain language before execution.
- Do not bundle unrelated tool calls into one confirmation.
- If tool arguments materially change after confirmation, require confirmation again.
- On rejection, cancel the tool call and return control to the user without fallback execution.

## Audit and Traceability

- Log confirmation decision (`approved` or `rejected`), tool name, and timestamp in harness/debug traces.
- For Tier 2 and Tier 3, log the target resource identifier and requested operation class.

## Harness Validation Requirements

The VS Code harness test suite must include scenarios that verify:

- Tier 1 to Tier 3 tools are blocked until confirmation is granted
- Rejection prevents execution
- Confirmation is re-requested after argument changes
- Trace output includes confirmation events

## Related Standards

- [MCP Standards](../../../instructions/mcp.instructions.md)
- [Security Standards](../../../instructions/security.instructions.md)
- [Governance Instructions for AI Agents](../../../instructions/governance.instructions.md)
