# Contributing to Shared Memory

## Rules

1. **Generic only** — no project names, repo paths, internal URLs, or issue numbers
2. **Namespaced subjects** — use `domain:subject` (e.g., `ci:workflow-run-trigger`)
3. **Evidence required** — must have been validated in 5+ sessions
4. **Max 200 chars** — memories must be atomic; split anything longer
5. **No secrets** — ever

## PR Template

When opening a PR, fill out:

```markdown
**Subject:** `domain:subject`
**Category:** fact | preference | decision | convention
**Confidence:** 0.XX (validated in N sessions)
**Applies to:** all teams | {specific stack/platform}

### The Memory
{content — max 200 chars}

### Evidence
- N sessions over {time period}
- Does NOT apply to: {exceptions}

### Source
{session checkpoint link, issue, or doc — anonymized if needed}
```

## File format

Each memory is a markdown file at `memories/{domain}/{subject}.md`:

```markdown
---
subject: "domain:subject"
category: "convention"
confidence: 0.85
created: "YYYY-MM-DD"
applies_to: "all teams"
---

# Short title

## Pattern
{The reusable pattern — max 200 chars}

## Evidence
- Validated in N sessions
- Context: {when this applies}
- Does NOT apply to: {exceptions}
```

## What gets rejected

- Memories with project-specific references
- Memories already covered by existing entries (duplicates)
- Confidence below 0.75 (not enough validation)
- Memories scoped to a single team's codebase
