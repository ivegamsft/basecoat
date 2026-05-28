---
description: "Use when debugging requires runtime context such as crash dumps, logs, memory state, or production telemetry. Covers how to feed runtime data into AI-assisted debugging workflows."
applyTo: "src/**,lib/**,app/**,packages/**,tests/**"
---

# Runtime-Aware Debugging

Use this instruction when a bug cannot be diagnosed from static code analysis alone and runtime data (logs, dumps, traces, profiler output) is available or needed.

## Runtime Context Gathering

Before engaging AI for a bug that involves runtime behavior, collect:

1. **Stack trace** at the point of failure (crash, exception, assertion).
2. **Relevant log window** — the 20-50 lines before and after the failure event, not the entire log.
3. **Reproduction steps** — the minimal sequence of actions or inputs that trigger the issue.
4. **Environment** — OS version, runtime version, build configuration (debug/release), relevant feature flags.
5. **State snapshot** — values of key variables, object states, or memory regions at the failure point.

If any of these are unavailable, state what is missing and what it would tell you.

## Structured Context Injection

When providing runtime data to AI:

- **Summarize stack traces**: include the top 5-10 frames with function names, file locations, and any visible arguments. Remove noise frames (runtime boilerplate, framework internals) unless they are the suspect.
- **Annotate log lines**: mark which line corresponds to the failure, which are normal, and which are suspicious.
- **Provide state diffs**: if you know what the state should be vs what it is, state both.
- **Bound the time window**: "This crash happens 30 seconds after startup, always during the first network request."

## Production vs Local Debugging

| Use production telemetry when: | Use local reproduction when: |
|---|---|
| Bug only occurs at scale or under real load | Bug is consistently reproducible locally |
| Memory pressure or concurrency timing is a factor | Single-threaded or deterministic behavior |
| You need aggregate patterns across many instances | You need step-by-step execution control |
| The environment cannot be replicated locally | Full debugger access is needed |

When bridging: extract the minimal reproduction conditions from production data, then attempt local reproduction before making fixes.

## Memory State Reasoning

For bugs involving memory corruption, leaks, or object lifecycle:

- Provide the allocation site and the access/crash site if known.
- State the object's expected lifecycle (created at X, expected to live until Y, but accessed at Z).
- Include heap profiler or valgrind output when available — summarize the finding, do not paste raw output.
- Identify ownership: who is responsible for freeing this memory? Is it clear?

## Temporal Debugging

For race conditions, timing-dependent bugs, and non-deterministic failures:

- Describe the expected ordering of events vs the observed ordering.
- Provide thread IDs or task identifiers for concurrent operations.
- Note whether the bug is frequency-dependent (happens 1 in 100 runs vs every time).
- If a trace tool captured event ordering (ETW, DTrace, strace), summarize the relevant event sequence.

## Guardrails

- Do not guess at runtime behavior from static code alone when runtime data is available. Ask for it.
- Do not propose a fix for a runtime bug without explaining which runtime evidence supports the diagnosis.
- If the root cause is uncertain, propose a diagnostic step (add logging, enable a sanitizer, capture a dump) before proposing a fix.
- State confidence level: "High confidence based on stack trace + logs" vs "Hypothesis — needs verification with X."
