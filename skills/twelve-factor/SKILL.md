---
name: twelve-factor
compatibility: [github-copilot-cli]
description: "Use when auditing or redesigning an app for cloud-native 12-Factor practices. USE FOR: move config from code to environment, check stateless process design, separate build release and run stages, verify logs go to stdout, assess dev and prod parity. DO NOT USE FOR: pixel-level UI design, vendor-specific service pricing comparisons."
---
# 12-Factor App Methodology

The 12-Factor App methodology for building modern, scalable, cloud-native applications.

## Quick Navigation

| Reference | Contents |
|---|---|
| [references/factors-1-6.md](references/factors-1-6.md) | Factors 1–6: codebase, dependencies, config, backing services, build/release/run, processes |
| [references/factors-7-12.md](references/factors-7-12.md) | Factors 7–12: port binding, concurrency, disposability, dev/prod parity, logs, admin tasks |

## The 12 Factors at a Glance

| # | Factor | Rule |
|---|---|---|
| 1 | Codebase | One repo → many deploys |
| 2 | Dependencies | Explicit declare + isolate |
| 3 | Config | Store in environment, not code |
| 4 | Backing services | Treat as attached resources |
| 5 | Build/Release/Run | Strictly separated stages |
| 6 | Processes | Stateless, share-nothing |
| 7 | Port binding | Self-contained HTTP service |
| 8 | Concurrency | Scale via process model |
| 9 | Disposability | Fast start, graceful shutdown |
| 10 | Dev/Prod parity | Keep environments identical |
| 11 | Logs | Treat logs as event streams (stdout) |
| 12 | Admin tasks | Run in same environment as app |
