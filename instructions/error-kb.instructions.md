---
description: "Use when building, extending, or consulting an error knowledge base so agents can classify failures, reuse proven fixes, and capture new patterns safely."
applyTo: "error-kb/**/*,**/*error*.{md,json,yml,yaml,ps1,sh,py,ts,js}"
---

# Error Knowledge Base Standards

Use this instruction when an agent is designing error handling workflows, maintaining operational troubleshooting guidance, or deciding how to respond to tool and command failures.

## Expectations

- Classify every meaningful failure before deciding whether to retry, auto-fix, escalate, or ask for user action.
- Store reusable error signatures as durable patterns, not as one-off anecdotes.
- Map each known signature to concrete resolution steps that are safe, minimal, and testable.
- Treat the knowledge base as a living system: add new evidence, validate fixes, and prune stale guidance.
- Never store secrets, tokens, credentials, private keys, or other sensitive values in error entries, examples, logs, or pattern notes.

## Error Classification

Categorize errors into one of these classes before responding:

- **Transient** — short-lived failures where retry with limits, backoff, or a precondition check is appropriate.
- **Known-fix** — failures with an established resolution that can be applied directly or suggested with high confidence.
- **Novel** — failures that do not match a trusted pattern and require investigation, evidence gathering, and future pattern extraction.
- **Environmental** — failures caused by missing access, configuration, credentials, network state, quotas, or other conditions that require user or environment changes.

For each stored error, capture:

- a stable signature, preferably a regex pattern that matches the relevant error text
- the error category
- the affected command, file type, tool, or workflow when known
- the recommended resolution steps
- validation notes showing how success is confirmed
- timestamps or counters needed for freshness and success-rate tracking

Example entry shape:

```json
{
  "id": "npm-eacces-cache",
  "category": "environmental",
  "signature": "EACCES: permission denied.*npm",
  "scope": {
    "tool": "npm",
    "command": "npm install"
  },
  "resolution": [
    "Check directory ownership and permissions.",
    "Use the approved local cache or package manager configuration for the repo.",
    "Re-run validation after the environment fix."
  ],
  "successRate": 0.82,
  "lastMatchedAt": "2025-01-12T00:00:00Z"
}
```

## Knowledge Base Structure

Use a structure like this so signatures, pattern notes, and workflow-specific guidance stay organized:

```text
error-kb/
  errors.json          # Error signatures + resolutions
  patterns/            # Categorized error patterns
    build-errors.md
    test-failures.md
    deploy-errors.md
```

Guidance for each artifact:

- `error-kb/errors.json` is the machine-readable source of truth for signatures, categories, resolutions, freshness metadata, and success-rate tracking.
- `error-kb/patterns/build-errors.md` documents recurring compile, package, and dependency failures.
- `error-kb/patterns/test-failures.md` documents assertion failures, flaky tests, fixture issues, and environment-sensitive test problems.
- `error-kb/patterns/deploy-errors.md` documents release, provisioning, authentication, quota, and rollout failures.

Keep categorized pattern files focused on interpretation and operator guidance, while the JSON file remains optimized for matching and automation.

## PreToolUse Integration

Before running a tool or command:

1. Check the error knowledge base for patterns relevant to the current file, command, tool, or workflow.
2. If a known issue is likely, inject a warning before execution.
3. Prefer warnings that include both the likely failure and the first safe mitigation step.

Use warnings in this form when applicable:

> This command commonly fails with X. If it does, try Y.

Pre-execution behavior should follow these rules:

- Surface likely failures for the current path or command, not generic warnings for unrelated tools.
- Use known-fix entries to prepare the recovery path before execution.
- Use transient entries to set retry expectations, limits, and backoff behavior.
- Track whether the suggested fix succeeds so low-value or stale entries can be pruned later.

## PostToolUse Integration

After any failure:

1. Normalize the error text enough to compare it against stored signatures.
2. Check whether the failure matches a known pattern.
3. If a match is found, apply the mapped fix automatically when it is safe and reversible, or suggest the fix explicitly when user action or confirmation is needed.
4. Re-validate after the fix so the entry records a confirmed success, not just an attempted remediation.
5. If no match is found, log the failure for future pattern extraction.

Post-failure handling should follow these rules:

- Do not auto-apply fixes that could destroy data, expose secrets, or make broad unrelated changes.
- Record unmatched failures with enough context to cluster future occurrences, but redact secrets and credentials.
- When multiple patterns match, prefer the most specific signature and the least risky resolution path.
- Update match counters, success counters, and last-seen timestamps after each handled failure.

## Lifecycle and Hygiene

Maintain the error knowledge base as an operational feedback loop:

- Add entries when novel failures recur or when a newly investigated issue produces a reusable fix.
- Mark fixes as validated only after the resolution has been applied successfully and the original failure condition is cleared.
- Prune stale entries after **N** days without a match, using the repository's defined retention threshold.
- Remove or downgrade entries whose fix success rate falls below an acceptable threshold or whose guidance is no longer correct.
- Review broad regex signatures regularly so they do not overmatch unrelated failures.
- Keep human-readable pattern files aligned with the machine-readable source of truth.

## Review Lens

- Does this failure fit the right class: transient, known-fix, novel, or environmental?
- Is the stored signature specific enough to avoid false positives but durable enough to match real repeats?
- Are the mapped resolution steps safe, minimal, and verifiable?
- Is the warning or remediation tied to the current command or file context?
- Is success-rate tracking good enough to identify stale or misleading entries?
- Have all logs and examples been scrubbed of secrets and credentials?
