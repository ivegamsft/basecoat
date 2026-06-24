# Agentic Workflows — Sprint 2 Scope Plan (#1981)

## Objective

Implement Sprint 1's wave decomposition to remediate agentic-workflow execution failures and unblock review/security agents across CI lanes.

## Implementation Waves

### Wave 1 — Immediate reliability unblockers (this sprint)

**Issues:** #1977, #1971, #1710, #1675

**Goal:** Remove hard execution failures in core review/security agent paths.

| Issue | Title | Status | Approach |
|-------|-------|--------|----------|
| #1977 | Code Review Agent is missing required data | OPEN | GitHub MCP server configuration to ensure PR diff/files are accessible to agentic workflows |
| #1971 | Code Review Agent is missing required tool | OPEN | Verify code-review skill tool registry and MCP bindings |
| #1710 | Security Analyst — PR Security Review failed | OPEN | Stabilize security-analyst workflow and tool dependencies |
| #1675 | Code Review Agent failed | OPEN | Fix core agent activation and error handling |

### Wave 2 — Advisor stabilization (follow-up)

**Issues:** #1941, #1794

**Goal:** Converge Release Impact Advisor to deterministic activation/agent handoffs.

### Wave 3 — Detection/no-op governance hardening (follow-up)

**Issues:** #1302, #1274

**Goal:** Eliminate false-positive runs and improve monitoring signal quality.

## Sprint 2 Acceptance Criteria

- [ ] Wave 1 issues are either closed or have documented evidence of fix + testing
- [ ] GitHub MCP server configuration is verified for PR data access
- [ ] Agents activate cleanly without missing-data or missing-tool errors
- [ ] Evidence links captured in Sprint 2 evidence artifact
- [ ] Carryover items documented with rationale

## Implementation Sequence

1. **Configuration audit** — Verify GitHub MCP server bindings and PR data access (fixes #1977)
2. **Tool registry review** — Confirm code-review skill tools are registered and accessible (fixes #1971)
3. **Agent error handling** — Test code-review and security-analyst workflows; fix hard failures (fixes #1675, #1710)
4. **Validation & testing** — Re-run failed workflows; capture pass evidence
5. **Sprint 2 implementation PR** — Merge all fixes with evidence

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| MCP server not deployed or misconfigured | Cannot retrieve PR data; agents fail | Coordinate with MCP server team; verify prod deployment |
| Tool registration missing or broken | Agents cannot invoke code review | Audit agent → skill → tool binding chain |
| Parallel agent failures have multiple root causes | Fix one issue; others still fail | Triage each failure independently; document root cause |

## Out of Scope for Sprint 2

- Broad agent refactoring unrelated to stabilization
- New agent features or capabilities
- Instrumentation or observability enhancements (handled in separate initiatives)

## Evidence & Artifacts

- **Implementation PR:** Will link to this sprint issue
- **Workflow runs:** Evidence of fixed agents running successfully
- **MCP audit report:** Configuration validation results
- **Sprint 2 evidence:** Detailed findings and remediation details (to be captured during implementation)

---

**Related Issues:**

- Parent: #1979 (Intent Contract)
- Successor: #1982 (Sprint 3 — Release/Verification)  
- Sprint 1 Plan: #1980 (Scope decomposition)

**Regroup Key:** `agentic-sprint-2`
