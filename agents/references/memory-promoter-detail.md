# Memory Promoter — Anti-Patterns and Examples Detail

Supporting detail for [`agents/basecoat-10-core-memory-promoter.agent.md`](../basecoat-10-core-memory-promoter.agent.md).

## Anti-Patterns to Exclude

- **Ephemeral instructions** — "skip lint for now", "use this value for this PR", "temporarily disable X"
- **Single-session fixes** — a workaround applied once and not observed again
- **"For now" qualifiers** — any fact qualified with "for now", "in this case", "this session", or "temporarily"
- **Personal data** — names, emails, locations, or any GDPR Article 9 category
- **Secrets and credentials** — API keys, tokens, passwords, connection strings
- **Repo-specific facts** — facts that are only true for one named repository and would not generalize

## Examples

**Good candidate** — appears repeatedly, actionable, generalizes across sessions:

```json
{
  "subject": "PowerShell escaping",
  "fact": "PowerShell strips backticks from arguments passed via -c; use single-quoted strings or a script block instead of escaping with backtick.",
  "citations": "session-state/2025-05-sprint.md, session-state/2025-06-sprint.md",
  "reason": "This pattern caused incorrect command output in at least three sessions. Future code generation involving PowerShell -c invocations will produce correct results by avoiding backtick escaping. Affects any contributor running shell commands from PowerShell.",
  "score": "High",
  "frequency": 3
}
```

**Bad candidate** — ephemeral, task-specific, must be excluded:

```json
{
  "subject": "linting",
  "fact": "Skip lint for now because the governance file has pre-existing violations.",
  "citations": "session-state/2025-06-12.md",
  "reason": "Captured as a temporary workaround for a single session.",
  "score": "Low",
  "frequency": 1
}
```

The second candidate must be excluded: it contains an ephemeral qualifier ("for now"), applies to a
single session, and has frequency 1 below the minimum threshold.
