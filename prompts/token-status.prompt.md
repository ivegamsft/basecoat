---
description: "Use when checking live session token/event efficiency and deciding whether to compact or pivot."
model: gpt-5.4-mini
tools: ["changes", "terminal"]
---

# Token Status

Use this prompt to run a deterministic cost check before expensive context drift compounds.

## Prompt

Compute and report current session cost posture in this format:

```text
Token Status
- Tokens sent: <n>
- Event count: <n>
- Input/output ratio: <n>x
- Elapsed time: <duration>
- Estimated budget remaining: <n>
```

Then apply this decision policy:

1. If ratio is >= 300x, emit a warning and recommend immediate compaction.
2. If events are >= 400 or tokens are >= 50M, trigger `/compact` now.
3. If post-compact ratio remains >= 300x, recommend `/new` with canonical references only.
4. If events are >= 500, mark session as critical-cost state.
