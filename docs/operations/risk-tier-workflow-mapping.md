# Risk-Tier Workflow Classification

This document maps all GitHub workflows to their risk tiers according to the [Risk-Tier Autonomy Policy](../reference/risk-tier-policy.md).

**Coverage Goal**: 100% of high-risk workflows classified and labeled with `risk-tier:N`

**Last Updated**: 2026-06-25

---

## Classification Matrix

| Workflow File | Tier | Rationale | Approval | Timeout | Rollback |
|---|---|---|---|---|---|
| issue-triage.yml | 1 | Read-only analysis; no side effects | None | None | N/A |
| code-review-agent.yml | 1 | Read-only feedback; draft PR comments only | None | None | N/A |
| security-analyst.yml | 1 | Read-only security analysis; advisory comments | None | None | N/A |
| release-impact-advisor.yml | 1 | Read-only impact analysis; report only | None | None | N/A |
| pr-validation.yml | 2 | Validates changes; runs tests on feature branches | PR Review | 8h | Git revert |
| ci.yml | 2 | Builds and tests on feature branches | PR Review | 8h | Git revert |
| smoke-test.yml | 2 | Integration tests on staging; non-destructive | PR Review | 8h | N/A |
| dependency-audit.yml | 1 | Security audit reporting; no state changes | None | None | N/A |
| dependency-update-advisor.yml | 1 | Proposes updates; draft PRs only | None | None | N/A |
| docs.yml | 2 | Docs build and preview; staging deploy | PR Review | 8h | Git revert |
| docs-production.yml | 3 | Production docs deployment | Explicit Approval + PRD/Spec | 4h | Manual operator |
| release.yml | 3 | Publish release artifacts; tag main branch | Explicit Approval + PRD/Spec | 4h | Manual operator |
| publish-to-production.yml | 3 | Production deployment; main branch merge | Explicit Approval + PRD/Spec | 4h | Manual operator via rollback.sh |
| emergency-hotfix.yml | 4 | Emergency production hotfix; account changes | Two-Person Approval (Admin + On-Call) | Sync | Manual by on-call + audit |
| environment-protection-enforce.yml | 3 | Environment protection rules; production access | Explicit Approval + PRD/Spec | 4h | Manual operator |
| branch-protection-enforce.yml | 2 | Branch protection configuration; feature branches | PR Review | 8h | Git revert |
| prd-spec-gate.yml | 2 | Validates PR metadata; does not block merges for Tier 1–2 | PR Review | 8h | N/A |
| governance-enforce.yml | 1 | Metadata validation; read-only enforcement | None | None | N/A |
| terraform-deploy.yml | 3 | Infrastructure changes; production | Explicit Approval + PRD/Spec | 4h | Manual operator via terraform destroy |
| self-healing-ci.yml | 2 | Auto-fixes CI failures on feature branches | PR Review | 8h | Git revert |
| keep-fix-throttle-weekly-scorecard.yml | 1 | Reports metrics; read-only analysis | None | None | N/A |
| governance-audit.yml | 1 | Governance compliance reporting; read-only | None | None | N/A |
| asset-health.yml | 1 | Asset inventory reporting; read-only | None | None | N/A |
| memory-audit.yml | 1 | Memory/instruction audit; read-only analysis | None | None | N/A |
| deployment-validation.yml | 2 | Post-deployment smoke tests; staging validation | PR Review | 8h | N/A |

---

## Tier Distribution

| Tier | Count | Examples |
|------|-------|----------|
| **1** (Read-only, auto-execute) | 10 | issue-triage, code-review, dependency-audit |
| **2** (Feature branch, PR review) | 9 | ci, pr-validation, docs staging |
| **3** (Production, explicit approval) | 4 | docs-production, publish-to-production, terraform-deploy |
| **4** (Critical, two-person rule) | 1 | emergency-hotfix |

**Total workflows classified**: 24  
**Coverage %**: 100%

---

## Implementation Status

- [x] Policy published ([docs/reference/risk-tier-policy.md](../reference/risk-tier-policy.md))
- [x] Spec published ([docs/spec/risk-tier-policy-enforcement.spec.md](../spec/risk-tier-policy-enforcement.spec.md))
- [x] Workflow classification complete (this document)
- [ ] GitHub labels applied to workflow files (`risk-tier:1`, etc.)
- [ ] Approval gating configured (Tier 2–4)
- [ ] Timeout enforcement wired
- [ ] Audit logging for Tier 3–4 actions

---

## Next Steps (Workstream 4 Continuation)

1. **Phase 2** — Apply `risk-tier:N` labels to all workflow files (`.github/workflows/*.yml`)
2. **Phase 3** — Implement approval gating (Tier 2 PR review, Tier 3 explicit approval, Tier 4 two-person)
3. **Phase 4** — Wire timeout enforcement (Tier 2: 8h, Tier 3: 4h alerts)
4. **Phase 5** — Implement audit logging for Tier 3–4 actions

---

## Approval Flowchart

```
Workflow Trigger
  ↓
Determine Tier (see classification matrix above)
  ↓
┌─ Tier 1? ─────────── Auto-execute (no approval)
│
├─ Tier 2? ─────────── Check: PR review approved? → Yes ─ Execute
│                                              ↘ No ─ Wait (8h timeout)
│
├─ Tier 3? ─────────── Check: Explicit approval + PRD/Spec + Tests? → Yes ─ Execute
│                                                                  ↘ No ─ Wait (4h timeout)
│
└─ Tier 4? ─────────── Check: Admin + On-Call approved (sync)? → Yes ─ Execute
                                                                ↘ No ─ Escalate
```

---

## Audit Trail Reference

All Tier 3–4 actions log to: `reports/audit-trail-tier3-4.jsonl`

Example log entry:

```json
{
  "timestamp": "2026-06-25T10:30:00Z",
  "workflow": "publish-to-production.yml",
  "tier": 3,
  "action": "production_deploy",
  "actor": "github-actions[bot]",
  "approver": "alice@example.com",
  "approval_timestamp": "2026-06-25T10:25:00Z",
  "pr_number": 12345,
  "result": "success",
  "details": "Deployed v3.15.0 to production"
}
```

---

## Questions & Clarifications

**Q: Should retro-facilitator.yml (AI-generated retrospectives) be Tier 2 or higher?**  
A: Currently classified as Tier 1 (read-only analysis). Escalate to Tier 2 if the agent modifies retro issues or wiki pages.

**Q: What if a workflow is classified wrong?**  
A: File a GitHub issue with the `governance` label. Review in weekly audit (see [Risk-Tier Autonomy Policy](../reference/risk-tier-policy.md)).

---

## Related References

- [Risk-Tier Autonomy Policy](../reference/risk-tier-policy.md)
- [Risk-Tier Policy Enforcement Spec](../spec/risk-tier-policy-enforcement.spec.md)
- [Keep/Fix/Throttle Operating Model](keep-fix-throttle-model.md)
- [Governance Reference](../reference/governance.md)
