# Remediation Backlog (Issue #1747)

**Created**: June 24, 2026  
**Owner**: Platform Security  
**Status**: Active

---

## Prioritized Tasks

### P0 (Critical) — Start Sprint 38

#### BACKLOG-1747-001: Branch Protection Enforcement

- **Title**: Apply branch protection rules to all unprotected feature branches
- **Description**: Expand GitHub Rulesets to cover `feat/*`, `fix/*`, `chore/*`, `ci/*`, `copilot/*`, `automation/*` branches
- **Acceptance Criteria**:
  - All 10+ unprotected branches now protected
  - Ruleset verification workflow passes
  - PR flow hygiene check confirms protection

- **Owner**: Platform Security
- **Effort**: Medium (2–3 days)
- **Due Date**: Jun 28, 2026
- **Related Issues**: #1747
- **Dependencies**: None

#### BACKLOG-1747-002: Document Secrets Rotation Policy

- **Title**: Create and publish secrets rotation policy + procedures
- **Description**: Document quarterly/semi-annual rotation schedule, service-specific procedures (Azure, GitHub PAT, OAuth), audit trail, and incident response
- **Deliverables**:
  - `SECRETS_ROTATION_POLICY.md` (detailed procedures)
  - `token-inventory.yml` (automated inventory workflow)
  - Audit log template (`SECRETS_AUDIT_LOG.json`)

- **Acceptance Criteria**:
  - Policy document approved by Platform Security
  - Token inventory workflow runs successfully
  - First quarterly rotation completed using new procedures

- **Owner**: Platform Security
- **Effort**: Large (3–4 days)
- **Due Date**: Jun 28, 2026
- **Related Issues**: #1747
- **Dependencies**: None

---

### P1 (High) — Start Sprint 39

#### BACKLOG-1747-003: Implement Secret Scanning Enforcement

- **Title**: Upgrade secret scanning from warn-only to blocking enforcement
- **Description**: Configure gitleaks to block merge if secrets detected, unless explicitly exempted
- **Acceptance Criteria**:
  - Secret scanning workflow blocks merge on detection
  - Exemption process documented and tested
  - Pre-commit hook and CI enforcement aligned

- **Owner**: Workflow Security
- **Effort**: Medium (2–3 days)
- **Due Date**: Jul 5, 2026
- **Related Issues**: #1747
- **Dependencies**: None

#### BACKLOG-1747-004: Workflow Permission Audit and Enforcement

- **Title**: Audit all workflows and enforce explicit permission declarations
- **Description**: Ensure all ~50+ workflows explicitly declare `permissions:` block; lint workflow syntax as part of CI
- **Acceptance Criteria**:
  - All workflows audited and documented
  - Linting rule enforced in CI (`lint-workflows.yml`)
  - Remediation PRs merged for any non-compliant workflows

- **Owner**: Workflow Security
- **Effort**: Large (3–4 days)
- **Due Date**: Jul 5, 2026
- **Related Issues**: #1747
- **Dependencies**: None

---

### P2 (Medium) — Sprint 40

#### BACKLOG-1747-005: Dependency Alert Routing and SLA

- **Title**: Define SLA and ownership for GitHub Dependabot and security alerts
- **Description**: Route dependency alerts to portfolio operations queue with SLA targets (critical: 24h, high: 72h, medium: 14d)
- **Acceptance Criteria**:
  - Alert routing configured in GitHub
  - SLA targets documented in ticket
  - Quarterly review process established

- **Owner**: Platform Security
- **Effort**: Small (1–2 days)
- **Due Date**: Jul 12, 2026
- **Related Issues**: #1747
- **Dependencies**: None

---

### P3 (Low) — Sprint 40+

#### BACKLOG-1747-006: Expand Code Scanning Coverage

- **Title**: Evaluate and implement GitHub Advanced Security code scanning
- **Description**: Assess CodeQL, semgrep, and other SAST tools for portfolio operations baseline; implement if approved
- **Acceptance Criteria**:
  - Tool evaluation report completed
  - Approval from Portfolio Operations steering committee
  - Scanning workflow deployed (if approved)

- **Owner**: Platform Security
- **Effort**: Medium (2–3 days)
- **Due Date**: Jul 19, 2026
- **Related Issues**: #1747
- **Dependencies**: Portfolio steering committee approval

---

## Cross-Sprint Dependencies

```txt
Sprint 38:
  ├── BACKLOG-1747-001 (Branch Protection) [P0] — BLOCKS PRODUCTION MERGE
  ├── BACKLOG-1747-002 (Secrets Rotation) [P0] — DOCUMENTATION
  │
Sprint 39:
  ├── BACKLOG-1747-003 (Secret Scanning) [P1] — DEPENDS ON: 1747-002 approved
  ├── BACKLOG-1747-004 (Workflow Audit) [P1]
  │
Sprint 40:
  ├── BACKLOG-1747-005 (Dependency SLA) [P2]
  ├── BACKLOG-1747-006 (Code Scanning) [P3] — DEPENDS ON: Steering approval
```

---

## Execution Timeline

### Sprint 38 (Current)

- [ ] BACKLOG-1747-001: Branch Protection Enforcement (due Jun 28)
- [ ] BACKLOG-1747-002: Secrets Rotation Policy (due Jun 28)

### Sprint 39

- [ ] BACKLOG-1747-003: Secret Scanning Enforcement (due Jul 5)
- [ ] BACKLOG-1747-004: Workflow Permission Audit (due Jul 5)

### Sprint 40+

- [ ] BACKLOG-1747-005: Dependency Alert SLA (due Jul 12)
- [ ] BACKLOG-1747-006: Expand Code Scanning (due Jul 19)

---

## Tracking and Reporting

**Status Updates**: Weekly to portfolio operations queue
**Review Cadence**: Sprint Planning (every 2 weeks)
**Escalation Path**: Security Steering Committee (if blocking production deployment)

---

**Backlog Version**: 1.0  
**Created By**: Security Audit (Issue #1747)  
**Distribution**: Platform Security, Portfolio Operations, Sprint Planning
