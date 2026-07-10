# Audit Findings Template

Use this template to document audit findings in a structured, consistent format.

## Audit Metadata

| Field | Value |
|---|---|
| Audit Date | *YYYY-MM-DD* |
| Organization | *org-name* |
| Auditor | *name/team* |
| Audit Period | *date range* |
| Next Audit Date | *YYYY-MM-DD* |

## Executive Summary

*Brief 2-3 sentence overview of audit scope and key findings.*

## Findings by Category

### 1. Organization Settings

#### Finding: [CATEGORY] [TITLE]

| Field | Value |
|---|---|
| **Finding ID** | ORG-001 |
| **Severity** | Critical / High / Medium / Low |
| **Category** | Runner Allocation / Secrets / Artifacts / Billing / Other |
| **Status** | Open / In Progress / Resolved |
| **Discovered Date** | *YYYY-MM-DD* |

**Description**

Clear, specific description of the finding. Include what was observed and why it matters.

**Evidence**

- Specific configuration values observed
- Screenshots or API responses
- Direct links to settings pages
- Quantitative metrics (e.g., "10 org secrets unencrypted")

**Recommendation**

Specific, actionable steps to remediate. Include:
- Exact configuration changes needed
- Why this change improves security/performance/cost
- Expected impact (savings, reliability improvement)
- Timeline (urgent, 1 week, 1 month, backlog)

**Effort Estimate**

- Implementation effort: *0.5 days / 1 day / 2-3 days / 1+ week*
- Ongoing maintenance: *minimal / 1 hour/week / daily*

**Expected ROI**

- Cost savings: *$X/month or N% reduction*
- Performance improvement: *N% faster builds / N minutes saved per deployment*
- Reliability improvement: *N% reduction in failures / N% uptime improvement*
- Security improvement: *description of risk mitigation*

---

### 2. Enterprise Settings

#### Finding: [CATEGORY] [TITLE]

| Field | Value |
|---|---|
| **Finding ID** | ENT-001 |
| **Severity** | Critical / High / Medium / Low |
| **Category** | SSO / Audit Logs / App Policies / Network / Other |
| **Status** | Open / In Progress / Resolved |
| **Discovered Date** | *YYYY-MM-DD* |

**Description**

[Same structure as org settings finding]

---

### 3. Dependency Health

#### Finding: [CATEGORY] [TITLE]

| Field | Value |
|---|---|
| **Finding ID** | DEP-001 |
| **Severity** | Critical / High / Medium / Low |
| **Category** | Outdated Packages / Missing Lock Files / Vulnerable Deps / Other |
| **Status** | Open / In Progress / Resolved |
| **Discovered Date** | *YYYY-MM-DD* |

**Description**

[Description of dependency issue]

**Outdated Packages**

| Package | Current | Latest | Age (days) | Severity |
|---|---|---|---|---|
| package-name | 1.0.0 | 2.1.0 | 180 | High |
| another-pkg | 3.0.0 | 3.1.2 | 45 | Low |

**Recommendation**

[Specific upgrade strategy and timeline]

---

### 4. Runner Profiles

#### Finding: [CATEGORY] [TITLE]

| Field | Value |
|---|---|
| **Finding ID** | RUN-001 |
| **Severity** | Critical / High / Medium / Low |
| **Category** | Overprovisioned / Underprovisioned / Capacity / Configuration / Other |
| **Status** | Open / In Progress / Resolved |
| **Discovered Date** | *YYYY-MM-DD* |

**Description**

[Description of runner configuration issue]

**Affected Runners**

| Runner Name | CPU | Memory | Status | Utilization | Last Active |
|---|---|---|---|---|---|
| runner-1 | 4 | 16GB | Online | 5% | 2 hours ago |
| runner-2 | 8 | 32GB | Offline | N/A | 7 days ago |

**Recommendation**

[Specific resizing, decommissioning, or configuration changes]

---

### 5. Installed Apps & SDKs

#### Finding: [CATEGORY] [TITLE]

| Field | Value |
|---|---|
| **Finding ID** | APP-001 |
| **Severity** | Critical / High / Medium / Low |
| **Category** | Unused App / Permission Creep / Missing Security App / Other |
| **Status** | Open / In Progress / Resolved |
| **Discovered Date** | *YYYY-MM-DD* |

**Description**

[Description of app/SDK issue]

**App Inventory**

| App Name | Permissions | Last Activity | Status | Action |
|---|---|---|---|---|
| unused-app | read:repo, write:admin | 6 months ago | Should deprovisioned | Remove |
| security-app | read:code, write:checks | Today | Active | Keep |

**Recommendation**

[Specific actions: update, remove, configure]

---

## Summary Statistics

| Metric | Value |
|---|---|
| **Total Findings** | N |
| **Critical** | N |
| **High** | N |
| **Medium** | N |
| **Low** | N |
| **Total Effort (days)** | N |
| **Estimated Annual Cost Savings** | $N |
| **Performance Improvement** | N% |
| **Reliability Improvement** | N% |

## Action Plan

| Finding ID | Title | Owner | Due Date | Status | Notes |
|---|---|---|---|---|---|
| ORG-001 | [Title] | @owner | *YYYY-MM-DD* | Not Started | [Any notes] |
| DEP-001 | [Title] | @owner | *YYYY-MM-DD* | In Progress | [Any notes] |

## Appendix: Methodology

**Audit Scope**
- Organization settings review
- Enterprise governance audit (if applicable)
- Dependency scanning and analysis
- Runner configuration and capacity analysis
- GitHub Apps and SDK inventory
- Workflow pattern analysis

**Data Sources**
- GitHub GraphQL API
- GitHub REST API
- Workflow file analysis
- Dependency file parsing
- Self-hosted runner inspection
- GitHub Apps API

**Limitations**
- [Any access limitations noted]
- [Any scope limitations]
- [Assumptions made during audit]

**Next Steps**
1. Present findings to engineering leadership
2. Prioritize recommendations by ROI and criticality
3. Assign owners to each recommendation
4. Schedule follow-up audit for [date]
5. Track metrics to measure improvement from recommendations

---

*Audit Report Generated: [date] by [auditor/tool]*
