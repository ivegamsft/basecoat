---
name: performance-profiling
description: "Use when code is slow, latency regressed, or throughput dropped and you need measurements before fixing it. USE FOR: profile hot path in service, compare baseline vs optimized runtime, find CPU or memory bottleneck, investigate slow database or I/O path, verify performance regression fix. DO NOT USE FOR: guessing at optimizations without data, feature prioritization only."
compatibility: GHCP
---

# Performance Profiling

Use this skill when a user asks why code is slow, where latency comes from, or how to profile a hot path.

## Workflow

1. Reproduce the slowness with a measurable command, request, or test.
2. Separate startup cost, I/O cost, and steady-state runtime.
3. Use the platform's profiler or timing tools before changing code.
4. Identify the highest-cost path and validate it with data.
5. Implement the smallest fix that improves the measured bottleneck.
6. Re-run the same measurement and report the delta.

## Output

- Baseline measurement
- Likely bottleneck
- Change made
- Post-change measurement
- Remaining risks or follow-ups
