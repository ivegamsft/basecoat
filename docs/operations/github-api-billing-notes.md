# GitHub Copilot Premium Billing API Tracking

## Overview

GitHub Copilot offers per-model cost breakdown in the web-based billing dashboard, but **this data is not available via any GitHub REST or GraphQL API**. This document tracks the current limitation and notes when GitHub releases API support.

## Current Status

**Last Updated:** 2026-05-08

| Data | API Available | Where |
|------|---------------|-------|
| Seat costs ($19/user/mo) | ✅ Yes | `GET /enterprises/{ent}/settings/billing/usage` |
| Seat assignments + activity | ✅ Yes | `GET /orgs/{org}/copilot/billing/seats` |
| Usage metrics (completions, suggestions) | ✅ Available | New `/metrics/reports/` endpoints (old `/copilot/metrics` sunset Apr 2 2026) |
| **Per-model request counts** | ❌ No API | Web UI only |
| **Per-model costs (e.g., Claude Opus: $72.72)** | ❌ No API | Web UI only |
| Premium request totals | ❌ No API | Web UI only |

## What Data IS Available

### Seat Billing Data (REST API)

```bash
curl -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/enterprises/{enterprise_slug}/settings/billing/usage"

# Response includes:
# - "copilot_business_seats"
# - "copilot_business_seats_used"
# - "copilot_business_seat_management_setting"
# - "copilot_seat_allocation_setting"
```

### Seat Assignments (REST API)

```bash
curl -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/orgs/{org}/copilot/billing/seats"

# Response includes:
# - user login
# - last_activity_at
# - created_at
# - pending_cancellation_date
```

### Usage Metrics (REST API) — Now Available

> ⚠️ **API Migration:** The old `GET /orgs/{org}/copilot/metrics` endpoint was
> deprecated 2026-01-29 and **sunset 2026-04-02**. It returns 404. Use the new
> `/metrics/reports/` endpoints below.

```bash
# 28-day rolling report (latest available)
curl -H "Authorization: token $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/{org}/copilot/metrics/reports/organization-28-day/latest"

# Response: { "download_links": ["<azure-blob-url>"], "report_start_day": "...", "report_end_day": "..." }
# Download the NDJSON file from the link — each line is an independent JSON object.
# Fields include: daily_active_users, daily_active_cli_users,
# daily_active_copilot_cloud_agent_users, weekly_active_users, etc.

# 1-day report (requires ?day=YYYY-MM-DD query param)
curl -H "Authorization: token $GH_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/orgs/{org}/copilot/metrics/reports/organization-1-day?day=2026-05-07"

# Requires: admin:org or read:org scope (no manage_billing:copilot needed)
# Requires: enterprise admin to have enabled Copilot usage metrics policy (#282 — now resolved)
```

## What Data IS NOT Available (Web UI Only)

The billing dashboard shows per-model cost breakdown:

- "Claude Opus 4.6: $72.72"
- "GPT-5.4 mini: $10.36"
- "Other: $2.14"

But no API endpoint provides this data. To work around this, users must:

1. **Manual screenshots:** Monthly screenshot of the billing dashboard.
2. **Browser console inspection:** Extract data from network requests (fragile, not API).
3. **Feature request:** Monitor GitHub's changelog and community feedback.

## Impact on BaseCoat

### What This Blocks

- ✅ Seat cost automation (cost alerts, budgets) — **POSSIBLE** via seat billing API
- ✅ Usage adoption tracking — **POSSIBLE** via metrics API (when enabled)
- ✅ Per-model cost attribution — **NOT POSSIBLE** (no API)
- ✅ Model routing cost optimization automation — **BLOCKED** (need per-model data)
- ✅ Skill #280 (usage analytics) — **PARTIAL** (can do usage, not per-model costs)

## Tracking GitHub Releases

Monitor the following for API announcements:

- [GitHub Changelog](https://github.blog/changelog/)
- [GitHub API Releases](https://docs.github.com/en/rest/reference/releases)
- [GitHub Community Discussions](https://github.com/orgs/github-community/discussions)
- [GitHub Feature Request Issues](https://github.com/github/feedback/discussions)

### Known Issues to Monitor

- GitHub Issue #XXX (if filed by Microsoft) requesting per-model billing API
- GitHub API docs for new endpoints under `/copilot/billing/`

## Workarounds

### Option 1: Manual Monthly Export

1. Navigate to: Enterprise → Settings → Billing → Copilot → Billing summary
2. Screenshot the per-model cost breakdown
3. Document in spreadsheet or issue for tracking

### Option 2: RPA / Browser Automation

For integration with internal systems, use browser automation (Playwright, Selenium) to:

1. Log in to GitHub Enterprise
2. Navigate to billing page
3. Extract cost data from rendered HTML or network requests

**Risk:** Fragile; GitHub UI changes break automation.

### Option 3: Community Feature Request

File or upvote a GitHub feature request:

- [GitHub Feedback](https://github.com/github/feedback/discussions)
- [GitHub Community](https://github.com/orgs/github-community/discussions)

### Option 4: Use Metrics API Only

Until per-model billing API exists, model cost attribution can be inferred from:

1. **Usage metrics** (completions/suggestions per language, editor)
2. **Fixed cost assumptions** (e.g., Claude costs ~$X per 1K completions)
3. **Model routing logs** (if Copilot logs model selection)

This is imperfect but enables relative cost tracking.

## Migration Path

When GitHub releases per-model billing API:

1. Update docs to link new endpoint
2. Update `#280` (usage analytics skill) to include per-model costs
3. Implement automated cost alerts and reporting
4. Close this tracking issue

## Related Issues

- **#282**: Enable Copilot usage metrics policy at enterprise level
- **#280**: Usage analytics skill (blocked until per-model data available)
- **#283**: This issue

## Timeline

| Date | Event |
|------|-------|
| 2026-04-30 | GitHub API per-model billing data limitation identified. Issue filed. |
| 2026-05-03 | Tracking document created. Workarounds documented. |
| TBD | GitHub announces per-model billing API (monitor changelog) |
| TBD | Update #280 with per-model cost support |
| TBD | Close this tracking issue |

## Links

- [GitHub Copilot Billing REST API docs](https://docs.github.com/en/rest/copilot)
- [GitHub Copilot Usage Metrics API](https://docs.github.com/en/rest/copilot/copilot-metrics)
- [GitHub API Changelog](https://github.blog/changelog/)
