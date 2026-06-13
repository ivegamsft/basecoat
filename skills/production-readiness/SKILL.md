---
name: production-readiness
title: Production Readiness Review & Release Management
description: "Use when deciding whether a service is safe to launch, scale, or recover in production. USE FOR: run production readiness review, check rollback and canary plan, assess disaster recovery readiness, review incident response runbooks, evaluate release go-live checklist. DO NOT USE FOR: day-to-day bug fixing, early product ideation without deployment scope."
compatibility: GHCP
---

# Production Readiness Skill

Evaluate launch safety through PRR gate checklists, DR planning, and incident response runbooks.

## Reference Files

| File | Contents |
|------|----------|
| [`references/prr-checklist.md`](references/prr-checklist.md) | PRR gate criteria (YAML), deployment/security/performance/observability gates, Python gate logic |
| [`references/runbook-template.md`](references/runbook-template.md) | High-error-rate runbook, immediate actions, diagnosis steps, escalation path |

## PRR Gate Quick Reference

| Gate | Required Items |
|------|---------------|
| Deployment | Automation tested, rollback documented, canary plan, health checks passing |
| Security | SAST/DAST complete, no hardcoded creds, access controls verified |
| Performance | Load test at 2×peak, query perf validated, auto-scaling configured |
| Observability | Centralized logs, dashboards, alerting, distributed tracing enabled |
| Incident | On-call rotation, runbooks, escalation procedures, post-mortem process |
