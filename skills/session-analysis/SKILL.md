---
name: session-analysis
compatibility: [github-copilot-cli]
description: "Use when analyzing Copilot CLI session behavior and efficiency from session telemetry. USE FOR: rank top tools by frequency, summarize assistant message volume and token usage, detect model changes within a session, compute average turns and turn distribution, produce optimization actions paired with session-optimization and copilot-usage-analytics. DO NOT USE FOR: feature implementation, infrastructure deployment, non-session product analytics."

category: workflow
visibility: public
metadata:
  category: workflow
  maturity: stable
  audience:
    - developer
    - maintainer
allowed-tools: []
model_policy:
  fallback: true
  preferred_families:
    - gpt-5.4-mini
    - claude-haiku
  upshift:
    allowed: true
    owner: runtime
    max_tier: reasoning
    triggers:
      - complexity
      - repeated_failures
  cost_tracking:
    budget_tier: low
    chargeback_tag: session-analysis
---

# Session Analysis Skill

Analyze a Copilot CLI session to answer operational questions about tool usage, tokens, model routing, and turn cadence, then pair findings with optimization guidance.

## Shortcut Phrases

- analyze this session
- top tools in this session
- did model change mid-session
- assistant token usage summary
- average turns per session

## Inputs

- Session identifier or transcript source
- Time window or turn range (optional)
- Focus area (tooling, tokens, routing, efficiency)

## Analysis Workflow

1. Identify the session scope and pull event/turn data.
2. Aggregate tool invocations and rank top-used tools.
3. Summarize assistant messages, including counts and token totals (or bounded estimates when exact usage is unavailable).
4. Detect model transitions by turn and flag mid-session model changes.
5. Compute turn metrics (total turns, user turns, assistant turns, average turns).
6. Produce optimization actions by pairing with companion skills.

## Paired Skills

| Companion skill | Purpose |
|---|---|
| `session-optimization` | Convert findings into concrete hygiene actions (`/compact`, `/new`, model downshift, file-reference discipline). |
| `copilot-usage-analytics` | Convert token and routing findings into cost estimates, dispatch ranking, and ROI framing. |

## Output

- Top tools table (count and share)
- Assistant message and token summary
- Model timeline with mid-session change points
- Turn metrics (including average turns)
- Prioritized optimization actions mapped to paired skills


