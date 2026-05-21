# VS Code Tools UI and Chat Debug View Runbook

## Purpose

Use this runbook to troubleshoot agent harness behavior in VS Code using:

- The tool picker (Tools UI) in chat
- Chat Debug View prompt and tool-call traces

This workflow helps confirm tool exposure, inspect call payloads, and identify failure points quickly.

## Preconditions

- VS Code is updated to a build that includes Copilot chat tool picker and Chat Debug View.
- The workspace is opened at the repository root.
- Required MCP/tool configuration files are present and valid.
- Any required local tool servers are started.

## Open Chat Debug View

1. Open VS Code chat and run the target prompt once.
2. Open Command Palette.
3. Run `Chat: Open Chat Debug View`.
4. Select the latest chat turn for the run you want to inspect.

In Debug View, confirm:

- Final assembled prompt/context
- Tool list exposed for that turn
- Tool-call request and response events
- Any errors returned by tool execution
- Confirmation events for side-effecting tool calls (`approved` or `rejected`)

Policy reference:

- [VS Code Agent Mode Tool Confirmation Policy](../reference/guardrails/tool-confirmation-policy.md)

## Validate Tools Exposed in Tools UI

1. Open a new chat turn.
2. Open the tool picker in chat.
3. Confirm expected tools are listed and enabled for this turn.
4. Compare tool names to expected harness/tool config.

If a tool is missing:

- Confirm the tool server is configured and reachable.
- Confirm the tool is enabled for the current workspace/profile.
- Reload the window and re-open chat.
- Re-run the prompt and re-check tool picker plus Debug View.

## Inspect Prompt and Tool-Call Traces

For a failing or unexpected run, inspect this order in Chat Debug View:

1. **Prompt assembly**
   - Verify expected instructions/context are present.
   - Check for truncation or missing system context.
2. **Tool selection**
   - Verify the model selected the expected tool.
   - If no tool selected, check whether tools were exposed in picker.
3. **Tool-call payload**
   - Validate argument names, types, required fields, and value format.
4. **Tool response**
   - Confirm success/error status and returned schema.
5. **Post-tool reasoning**
   - Check if the model consumed returned fields correctly.

## Troubleshooting Checklist

### Symptom: expected tool is not shown in Tools UI

- Verify workspace-level MCP/tool config path and syntax.
- Confirm the tool server process is running.
- Confirm no auth/session requirement is blocking tool registration.
- Reload VS Code window and retry.
- Use Chat Debug View to confirm tool exposure list for the turn.

### Symptom: malformed tool call

Indicators:

- Missing required argument
- Wrong type (string vs number/object)
- Invalid enum/value format

Actions:

- Inspect tool schema and compare with call payload in Debug View.
- Update prompt instructions to force explicit argument shape.
- Re-run and verify payload now matches tool schema.

### Symptom: tool call succeeds but answer is wrong

- Inspect tool response payload in Debug View.
- Confirm expected fields exist and are non-empty.
- Check whether the model ignored or misread key fields.
- Tighten prompt instructions to reference required response fields.

### Symptom: side-effecting tool ran without confirmation

- Confirm the tool category in the policy tiers and expected confirmation behavior.
- Verify the turn includes a confirmation event before tool execution.
- If no confirmation event exists, treat as policy violation and escalate.

## End-to-End Debug Example

Scenario: The model should call `search_opportunities` but does not.

1. Run prompt: `Find open opportunities for account Contoso over $1M`.
2. Open tool picker and confirm `search_opportunities` is available.
3. Open Chat Debug View and inspect the same turn.
4. If tool not exposed in turn:
   - Fix tool configuration or server startup.
   - Reload window and rerun.
5. If tool exposed but not called:
   - Adjust prompt to explicitly require tool usage and required filters.
6. If called with bad payload:
   - Correct argument names/value formats based on schema.
7. Re-run and verify in Debug View:
   - Tool call event exists
   - Payload is valid
   - Response is successful
   - Final answer references returned results

## Escalation Criteria

Escalate to platform/tooling owners when:

- Tools do not appear after configuration and reload checks.
- Debug trace consistently shows registration failures.
- Calls fail with platform auth/transport errors outside prompt control.
- Reproducible malformed payload persists after prompt/schema alignment.

Capture and share:

- Repro prompt
- Tool picker state
- Debug View snippets for tool exposure, payload, and error
- VS Code version and extension version
