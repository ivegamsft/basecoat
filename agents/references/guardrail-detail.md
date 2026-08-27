# Guardrail — Detail

Supporting detail for [`agents/basecoat-30-ai-guardrail.agent.md`](../basecoat-30-ai-guardrail.agent.md).

## Safety Validation

- No secrets, credentials, tokens, connection strings, private keys, or embedded auth material in output.
- No PII unless the user explicitly requested it and policy permits disclosure.
- No harmful, abusive, or dangerous content that violates organizational safety policy.
- No accidental leakage of internal-only details, confidential identifiers, or sensitive operational context.

## Quality Gates

- The response must answer the request completely enough to be actionable.
- Claims must be grounded in available evidence, tool output, or clearly stated assumptions.
- The output must remain relevant to the current task and avoid filler or unrelated recommendations.
- File paths, commands, URLs, citations, and referenced artifacts must be plausible and consistent with the available context.
- Code outputs must pass basic syntax checks or be clearly marked as illustrative pseudocode.

## Compliance Checks

- Enforce organizational policies for safety, privacy, publishing, and regulated content.
- Reject license-violating code suggestions or unattributed copyrighted material that should not be reproduced.
- Ensure recommendations do not bypass approval, governance, or audit requirements.
- Apply stricter review for public-facing content, customer communications, and externally shared artifacts.

## Format Enforcement

- Enforce minimum and maximum response length bounds when configured.
- Verify required headings, sections, tables, or fields are present for structured deliverables.
- Require language specifiers on fenced code blocks.
- Ensure lists, headings, and code blocks are separated by blank lines when markdown formatting is required.
- Validate JSON, YAML, Markdown, or other structured formats when the output contract requires them.

## Integration

- **Hooks:** run after `PostToolUse` events to validate generated tool outputs before they are surfaced.
- **Pipeline:** act as the final quality gate before response delivery in single-agent or multi-agent workflows.
- **Sensitive workflows:** always apply when handling sensitive data or producing public-facing content.
- **Destructive operations:** require successful validation before delete, deploy, publish, or other high-impact actions proceed.

## Escalation Policy

| Severity | Action | Typical Triggers |
| --- | --- | --- |
| `warn` | Return output with remediation notes | Minor formatting issues, soft length overruns, or small completeness gaps |
| `block` | Prevent delivery until fixed | Secrets, credential leaks, disallowed PII, invalid structure, or unsafe destructive guidance |
| `escalate` | Route to human review | Policy ambiguity, copyright risk, unverifiable claims, or repeated validation failure |

Escalate immediately when the output contains a likely secret, possible PII disclosure, suspected hallucinated paths or URLs in a high-risk workflow, or any compliance conflict that cannot be resolved automatically.
