# Repository Story Chronicle

Chronicle-generated execution updates are appended below.

Use `scripts/chronicle-to-story-export.ps1` to append or update cycle sections,
emit issue-ready learnings, and produce optional memory-promotion suggestions.

<!-- CHRONICLE:START 2026-07-24-to-2026-09-01-backlog-recovery -->
## Chronicle Update — 2026-07-24-to-2026-09-01-backlog-recovery

- **Generated**: 2026-09-01 01:51:34 -04:00
- **Mode**: update

### Session Sources

- Copilot session 576bde66-67a2-4705-995e-ff5b2285a7f9
- Repository history after docs/operations/repo-story.md update 04143b9 on 2026-07-23

### Timeline

| Time | Event | Reference |
|---|---|---|
| 2026-07-24 to 2026-08-09 | The repository released v4.0.0, hardened downstream rollout and release-gate controls, added oldest-first backlog burndown routing, and updated publishing, infrastructure, MCP, deployment, and model-routing behavior. | v4.0.0, #2696, #2700, #2708, #2717, #2741, #2752, #2758, #2767, #2770, #2773, #2778, #2780 |
| 2026-08-10 | The post-story period opened with corporate-proxy lock integrity, an enforceable solo-developer governance profile, and immutable GitHub Actions pin enforcement. | 0a761667, 551a744f, daf83646 |
| 2026-08-13 to 2026-08-18 | Governance, downstream updates, runner capability modeling, onboarding, and current-head automated-review behavior were hardened. | #2810, #2815, #2742, #2740, #2796, #2819, #2869 |
| 2026-08-16 and 2026-08-31 | BaseCoat releases 4.2.0 and 4.2.1 were prepared and production publication was unblocked. | v4.2.0, v4.2.1, #2835, 7a46529d |
| 2026-08-22 to 2026-08-30 | The repository upgraded gh-aw and Node-compatible action pins, repaired learning and cleanup paths, completed five agent token-budget waves, and strengthened ship-it fail-closed behavior. | #2884, #2886, #2904, #2903, #2928, #2930, #2931, #2932, #2950, 90a2d277 |
| 2026-08-31 | The repository inventory established a dated baseline of 130 agents, 134 skills, 91 instructions, 6 prompts, 90 workflows, and 416 documentation pages. | #2986, docs/reference/repository-inventory.md |
| 2026-08-31 to 2026-09-01 | The oldest-first backlog wave completed the #2704 accuracy audit branch, implemented #2775 YAGNI analysis, advanced compatibility-alias validation, and opened the #2776 backlog-revalidation lane. | #2989, #2991, #2981, #2776 |
| 2026-09-01 | PR #2984 merged the action-required root fix. A fresh Copilot review on #2981 head 93910bf3 created zero pull_request_review action-required runs. | #2984, b87de505, #2981 |
| Session snapshot | The session recorded 445 model calls: 252 gpt-5.6-terra, 112 gpt-5.4-mini, and 81 mai-code-1.1-flash. Usage totaled 41,287,904 input tokens, 239,020 output tokens, 38,851,416 cache-read tokens, 882 tool calls, and five delegated task executions. | session_usage and tool_executions for session 576bde66-67a2-4705-995e-ff5b2285a7f9 |
| Repository snapshot | Since the prior story update, 98 commits landed on main. At documentation time, 84 issues remained open; #2984 and #2986 were merged while #2981, #2989, and #2991 remained active. | origin/main 04143b9..b87de505 and GitHub issue/PR state |

### Learnings

- [learning:ship-control-plane-fixes-before-resuming-fleet-throughput] **Ship control-plane fixes before resuming fleet throughput** — The action-required correction existed on #2984 but remained behind the queue it was intended to repair. Continuing to rebase and open later PRs caused the old main-branch workflow to keep generating blocked runs.
  - Follow-up action: When a merge-control defect is confirmed, pause later auto-merges and make the control-plane repair the only merge candidate until its behavior is verified on main.
- [learning:pre-job-action-required-failures-are-trigger-boundary-defects] **Pre-job action_required failures are trigger-boundary defects** — The Copilot reviewer app had no repository permission, so privileged workflows subscribed to pull_request_review submitted were blocked before any job could execute. Job-level conditions and self-approval logic could not repair that boundary.
  - Follow-up action: Remove untrusted privileged event subscriptions and relay reevaluation through trusted default-branch workflow_run, schedule, issue-comment, or workflow-dispatch signals.
- [learning:review-reconciliation-needs-a-trusted-evidence-watermark] **Review reconciliation needs a trusted evidence watermark** — One-time polling missed late automated and human reviews, while unconditional scheduled fan-out would create 96 runs per blocked PR per day. Comparing newest review time with the latest BaseCoat eligibility status gives bounded, idempotent reconciliation.
  - Follow-up action: Use an evidence watermark and dispatch only when review evidence is newer than the latest eligibility evaluation.
- [learning:do-not-conflate-workflow-run-approval-with-merge-reevaluation] **Do not conflate workflow-run approval with merge reevaluation** — cloud_agent.auto_approve_workflow_runs controls approval of requested Actions runs; it must not disable merge-eligibility reevaluation for regulated profiles that still require later human approvals.
  - Follow-up action: Keep merge reconciliation under a dedicated main.reconcile_merge_eligibility policy and validate all policy profiles.
- [learning:sequence-policy-evaluation-after-mutable-evidence-settles] **Sequence policy evaluation after mutable evidence settles** — Eligibility runs repeatedly failed because they started before the current-head review, exact-head acknowledgement, or long-running required checks completed. The same code passed when evaluation was dispatched after all evidence existed.
  - Follow-up action: Treat review, acknowledgement, and required-check completion as explicit prerequisites for final eligibility dispatch.
- [learning:resolve-review-threads-only-against-verified-code] **Resolve review threads only against verified code** — The merge queue was blocked by unresolved substantive comments rather than broken builds. Each thread required either a tested correction or an explicit governance disposition; mass resolution would have hidden real defects.
  - Follow-up action: Inspect, fix, validate, and only then resolve each review thread.
- [learning:serialize-merges-when-main-branch-automation-is-stateful] **Serialize merges when main-branch automation is stateful** — Merging #2986 advanced main and made every later branch stale. Pausing later auto-merges, rebasing one branch, validating it, and waiting for its actual merge prevented further cross-branch churn.
  - Follow-up action: Keep one active auto-merge candidate during fleet recovery and rebase the next lane only after the prior merge reaches main.
- [learning:session-cost-must-be-evaluated-against-shipped-outcomes] **Session cost must be evaluated against shipped outcomes** — The session used 41.29M input tokens and 882 tool calls. The cost produced durable fixes and documentation, but repeated review-push-review cycles dominated the run and show why phase compaction and control-plane-first sequencing matter.
  - Follow-up action: Record long backlog sessions in the efficiency scorecard and compact at triage, implementation, and merge-waiting boundaries.

### References

- <https://github.com/ivegamsft/basecoat/issues/2993>
- <https://github.com/ivegamsft/basecoat/issues/2704>
- <https://github.com/ivegamsft/basecoat/issues/2775>
- <https://github.com/ivegamsft/basecoat/issues/2776>
- <https://github.com/ivegamsft/basecoat/issues/2983>
- <https://github.com/ivegamsft/basecoat/pull/2981>
- <https://github.com/ivegamsft/basecoat/pull/2984>
- <https://github.com/ivegamsft/basecoat/pull/2986>
- <https://github.com/ivegamsft/basecoat/pull/2989>
- <https://github.com/ivegamsft/basecoat/pull/2991>
- git range 04143b9..b87de505
- docs/reference/repository-inventory.md
<!-- CHRONICLE:END 2026-07-24-to-2026-09-01-backlog-recovery -->
