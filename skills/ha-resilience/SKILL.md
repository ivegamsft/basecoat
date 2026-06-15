---
name: ha-resilience
title: High-Availability & Resilience Design Patterns
description: "Use when designing highly available systems with retries, circuit breakers, failover, chaos testing, and SRE guardrails for recovery objectives. USE FOR: design multi-region failover, add retry and jitter strategy, introduce circuit breaker for flaky dependency, plan chaos testing against SLOs, define health probes and recovery behavior. DO NOT USE FOR: single-host app setup, feature UI design, cost-only optimization reviews."
compatibility:
  - GHCP
---
# HA & Resilience Skill

Design and test fault-tolerant systems using retries, circuit breakers, multi-region failover, and chaos testing.

## Reference Files

| File | Contents |
|------|----------|
| [`references/patterns.md`](references/patterns.md) | Multi-region active-active (Terraform), circuit breaker (Go), retry + jitter (Python), bulkhead, error budget |
| [`references/testing.md`](references/testing.md) | Chaos test script, test scenarios, k6 load testing, SLO validation checklist |

## Core Patterns

| Pattern | Use Case | Key Rule |
|---------|---------|---------|
| Circuit Breaker | Prevent cascade failures | Opens after N failures; half-open after timeout |
| Retry + Jitter | Transient faults | Exponential backoff + random jitter; cap at max\_delay |
| Bulkhead | Dependency isolation | Separate thread pools per downstream dependency |
| Multi-region | Regional outages | Route53 health check + failover; read replica in secondary |
| Error Budget | Deployment safety | Block deploys when burn rate > 3× |

## SLO Quick Reference

| Target | Monthly Downtime Budget |
|--------|------------------------|
| 99.9% | 43.8 min |
| 99.95% | 21.9 min |
| 99.99% | 4.4 min |
