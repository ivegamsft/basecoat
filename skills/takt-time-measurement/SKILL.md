---
name: takt-time-measurement
description: "Use when measuring takt time, exporting throughput metrics, or building a GitHub Actions workflow that captures timing data. USE FOR: workflow templates, takt calculations, and metric export guidance. DO NOT USE FOR: general project management or unrelated observability tasks."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
visibility: "internal"
---
# Takt Time Measurement Skill

Create workflow templates that measure takt time and publish the resulting metrics.

## Templates in This Skill

| Template | Purpose |
|---|---|
| `takt-time-workflow.yml` | GitHub Actions template that captures timing data and exports takt metrics |

## Core Rules

- Capture start and end timestamps consistently.
- Keep the measurement workflow lightweight and repeatable.
- Export metrics in a format that downstream dashboards can read.
- Use the same calculation path for every run.

## Agent Pairing

Use with DevOps or analytics agents that need to turn workflow timing into usable throughput signals.

- `station-bottleneck-analyzer` for queue length, throughput, and weekly bottleneck report issues.
