# Token Context Inventory

Generated as a standalone inventory (no edits to agent/skill/instruction files).

- Generated: 2026-05-19 16:38:17 -0400
- Estimation method: `approx_tokens = round(word_count × 1.35)` (same heuristic used in `scripts/validate-basecoat.ps1`).
- Scope: `agents/*.agent.md`, `skills/*/SKILL.md`, `instructions/*.instructions.md`.

## Summary

| Type | Count | Total Words | Total Approx Tokens | Avg Approx Tokens |
|---|---:|---:|---:|---:|
| Agent | 98 | 70862 | 95657 | 976 |
| Skill | 80 | 16846 | 22741 | 284 |
| Instruction | 79 | 44837 | 60532 | 766 |
| **All** | 257 | 132545 | 178930 | 696 |

## basecoat-10-core-agents

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| basecoat-50-security-container-basecoat-50-security-security | `agents/container-security.agent.md` | 1467 | 1980 |
| basecoat-30-ai-containerization-planner | `agents/containerization-planner.agent.md` | 1442 | 1947 |
| basecoat-10-core-agentops | `agents/agentops.agent.md` | 1438 | 1941 |
| basecoat-60-workflow-release-manager | `agents/release-manager.agent.md` | 1384 | 1868 |
| basecoat-10-core-project-onboarding | `agents/project-onboarding.agent.md` | 1346 | 1817 |
| basecoat-50-security-api-basecoat-50-security-security | `agents/api-security.agent.md` | 1344 | 1814 |
| basecoat-50-security-secrets-manager | `agents/secrets-manager.agent.md` | 1339 | 1808 |
| basecoat-50-security-policy-as-code-compliance | `agents/policy-as-code-compliance.agent.md` | 1334 | 1801 |
| basecoat-10-core-mcp-developer | `agents/mcp-developer.agent.md` | 1304 | 1760 |
| basecoat-10-core-performance-analyst | `agents/performance-analyst.agent.md` | 1303 | 1759 |
| basecoat-10-core-sre-engineer | `agents/sre-engineer.agent.md` | 1297 | 1751 |
| basecoat-10-core-ux-designer | `agents/ux-designer.agent.md` | 1283 | 1732 |
| basecoat-90-quality-penetration-test | `agents/penetration-test.agent.md` | 1252 | 1690 |
| basecoat-10-core-finops-advisor | `agents/finops-advisor.agent.md` | 1245 | 1681 |
| basecoat-30-ai-mlops | `agents/mlops.agent.md` | 1239 | 1673 |
| basecoat-80-data-dataops | `agents/dataops.agent.md` | 1215 | 1640 |
| basecoat-10-core-agent-designer | `agents/agent-designer.agent.md` | 1196 | 1615 |
| basecoat-10-core-prompt-coach | `agents/prompt-coach.agent.md` | 1191 | 1608 |
| basecoat-10-core-api-designer | `agents/api-designer.agent.md` | 1187 | 1602 |
| basecoat-10-core-sprint-planner | `agents/sprint-planner.agent.md` | 1183 | 1597 |
| basecoat-80-data-data-tier | `agents/data-tier.agent.md` | 1173 | 1584 |
| basecoat-50-security-github-security-posture | `agents/github-security-posture.agent.md` | 1155 | 1559 |
| basecoat-50-security-security-monitor | `agents/security-monitor.agent.md` | 1149 | 1551 |
| basecoat-10-core-solution-architect | `agents/solution-architect.agent.md` | 1138 | 1536 |
| basecoat-10-core-identity-architect | `agents/identity-architect.agent.md` | 1136 | 1534 |
| basecoat-50-security-security-analyst | `agents/security-analyst.agent.md` | 1134 | 1531 |
| basecoat-10-core-legacy-modernization | `agents/legacy-modernization.agent.md` | 1127 | 1521 |
| basecoat-60-workflow-ci-failure-escalation | `agents/ci-failure-escalation.agent.md` | 1120 | 1512 |
| basecoat-10-core-prompt-engineer | `agents/prompt-engineer.agent.md` | 1096 | 1480 |
| basecoat-10-core-orchestrator | `agents/orchestrator.agent.md` | 1067 | 1440 |
| basecoat-10-core-app-inventory | `agents/app-inventory.agent.md` | 1022 | 1380 |
| basecoat-10-core-middleware-dev | `agents/middleware-dev.agent.md` | 1009 | 1362 |
| basecoat-10-core-gitops-engineer | `agents/gitops-engineer.agent.md` | 997 | 1346 |
| basecoat-80-data-database-migration | `agents/database-migration.agent.md` | 996 | 1345 |
| basecoat-10-core-backend-dev | `agents/backend-dev.agent.md` | 984 | 1328 |
| basecoat-10-core-dependency-lifecycle | `agents/dependency-lifecycle.agent.md` | 984 | 1328 |
| basecoat-10-core-frontend-dev | `agents/frontend-dev.agent.md` | 969 | 1308 |
| basecoat-50-security-instruction-auditor | `agents/instruction-auditor.agent.md` | 918 | 1239 |
| basecoat-50-security-security-operations | `agents/security-operations.agent.md` | 895 | 1208 |
| basecoat-10-core-issue-triage | `agents/issue-triage.agent.md` | 864 | 1166 |
| basecoat-10-core-production-readiness | `agents/production-readiness.agent.md` | 859 | 1160 |
| basecoat-30-ai-guardrail | `agents/guardrail.agent.md` | 832 | 1123 |
| basecoat-60-workflow-infrastructure-deploy | `agents/infrastructure-deploy.agent.md` | 762 | 1029 |
| basecoat-50-security-config-auditor | `agents/config-auditor.agent.md` | 758 | 1023 |
| basecoat-10-core-product-manager | `agents/product-manager.agent.md` | 739 | 998 |
| basecoat-10-core-memory-promoter | `agents/memory-promoter.agent.md` | 734 | 991 |
| basecoat-60-workflow-self-healing-ci | `agents/self-healing-ci.agent.md` | 693 | 936 |
| basecoat-90-quality-guidance-reviewer | `agents/guidance-reviewer.agent.md` | 685 | 925 |
| basecoat-10-core-tech-writer | `agents/tech-writer.agent.md` | 676 | 913 |
| basecoat-90-quality-resilience-reviewer | `agents/resilience-reviewer.agent.md` | 667 | 900 |
| basecoat-80-data-data-architect | `agents/data-architect.agent.md` | 663 | 895 |
| basecoat-10-core-strategy-to-automation | `agents/strategy-to-automation.agent.md` | 661 | 892 |
| basecoat-10-core-dependency-update-advisor | `agents/dependency-update-advisor.agent.md` | 652 | 880 |
| basecoat-10-core-exploratory-charter | `agents/exploratory-charter.agent.md` | 582 | 786 |
| basecoat-10-core-escalation-router | `agents/escalation-router.agent.md` | 540 | 729 |
| basecoat-50-security-guidance-author | `agents/guidance-author.agent.md` | 526 | 710 |
| basecoat-90-quality-manual-test-strategy | `agents/manual-test-strategy.agent.md` | 524 | 707 |
| basecoat-10-core-dependency-blocker-monitor | `agents/dependency-blocker-monitor.agent.md` | 498 | 672 |
| basecoat-50-security-sprint-closeout-auditor | `agents/sprint-closeout-auditor.agent.md` | 415 | 560 |
| basecoat-20-lang-dotnet-modernization-advisor | `agents/dotnet-modernization-advisor.agent.md` | 390 | 526 |
| basecoat-90-quality-code-review | `agents/code-review.agent.md` | 389 | 525 |
| basecoat-10-core-contract-basecoat-10-core-testing | `agents/contract-testing.agent.md` | 368 | 497 |
| basecoat-10-core-station-bottleneck-analyzer | `agents/station-bottleneck-analyzer.agent.md` | 368 | 497 |
| basecoat-10-core-new-customization | `agents/new-customization.agent.md` | 367 | 495 |
| basecoat-10-core-merge-coordinator | `agents/merge-coordinator.agent.md` | 365 | 493 |
| basecoat-30-ai-domain-designer | `agents/domain-designer.agent.md` | 364 | 491 |
| basecoat-60-workflow-rollout-basecoat | `agents/rollout-basecoat.agent.md` | 361 | 487 |
| basecoat-10-core-observability-engineer | `agents/observability-engineer.agent.md` | 360 | 486 |
| basecoat-10-core-hardening-advisor | `agents/hardening-advisor.agent.md` | 356 | 481 |
| basecoat-80-data-data-integrity | `agents/data-integrity.agent.md` | 338 | 456 |
| basecoat-10-core-rca | `agents/rca.agent.md` | 338 | 456 |
| basecoat-10-core-branch-hygiene-sweeper | `agents/branch-hygiene-sweeper.agent.md` | 330 | 446 |
| basecoat-10-core-feedback-loop | `agents/feedback-loop.agent.md` | 324 | 437 |
| basecoat-90-quality-e2e-test-strategy | `agents/e2e-test-strategy.agent.md` | 323 | 436 |
| basecoat-60-workflow-release-impact-advisor | `agents/release-impact-advisor.agent.md` | 321 | 433 |
| basecoat-10-core-sprint-retrospective | `agents/sprint-retrospective.agent.md` | 310 | 418 |
| basecoat-60-workflow-retro-facilitator | `agents/retro-facilitator.agent.md` | 301 | 406 |
| basecoat-50-security-supply-chain-basecoat-50-security-security | `agents/supply-chain-security.agent.md` | 294 | 397 |
| basecoat-10-core-memory-curator | `agents/memory-curator.agent.md` | 293 | 396 |
| basecoat-10-core-ha-architect | `agents/ha-architect.agent.md` | 292 | 394 |
| basecoat-10-core-orphaned-pr-cleanup | `agents/orphaned-pr-cleanup.agent.md` | 290 | 392 |
| basecoat-60-workflow-release-freeze-enforcer | `agents/release-freeze-enforcer.agent.md` | 287 | 387 |
| basecoat-60-workflow-broken-build-troubleshooter | `agents/broken-build-troubleshooter.agent.md` | 286 | 386 |
| basecoat-10-core-chaos-engineer | `agents/chaos-engineer.agent.md` | 285 | 385 |
| basecoat-10-core-devops-engineer | `agents/devops-engineer.agent.md` | 284 | 383 |
| basecoat-10-core-definition-of-done | `agents/definition-of-done.agent.md` | 275 | 371 |
| basecoat-10-core-llmops | `agents/llmops.agent.md` | 274 | 370 |
| basecoat-60-workflow-data-pipeline | `agents/data-pipeline.agent.md` | 270 | 364 |
| basecoat-60-workflow-incident-responder | `agents/incident-responder.agent.md` | 269 | 363 |
| basecoat-40-azure-azure-landing-zone | `agents/azure-landing-zone.agent.md` | 258 | 348 |
| basecoat-60-workflow-release-readiness-chair | `agents/release-readiness-chair.agent.md` | 243 | 328 |
| basecoat-30-ai-daily-standup-facilitator | `agents/daily-standup-facilitator.agent.md` | 237 | 320 |
| basecoat-10-core-takt-time-tracker | `agents/takt-time-tracker.agent.md` | 203 | 274 |
| basecoat-10-core-replanning-engine | `agents/replanning-engine.agent.md` | 184 | 248 |
| basecoat-10-core-factory-state-curator | `agents/factory-state-curator.agent.md` | 175 | 236 |
| basecoat-10-core-s4-shadow-mode-validator | `agents/s4-shadow-mode-validator.agent.md` | 172 | 232 |
| basecoat-10-core-factory-conductor | `agents/factory-conductor.agent.md` | 170 | 230 |
| basecoat-10-core-bom-validator | `agents/bom-validator.agent.md` | 160 | 216 |

## Skills

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| create-skill | `skills/create-skill/SKILL.md` | 295 | 398 |
| merge-conflict-mediator | `skills/merge-conflict-mediator/SKILL.md` | 291 | 393 |
| basecoat-10-core-documentation | `skills/documentation/SKILL.md` | 285 | 385 |
| dependency-blocker-monitoring | `skills/dependency-blocker-monitoring/SKILL.md` | 283 | 382 |
| basecoat-50-security-api-basecoat-50-security-security | `skills/api-security/SKILL.md` | 280 | 378 |
| sprint-management | `skills/sprint-management/SKILL.md` | 273 | 369 |
| ci-flake-quarantine | `skills/ci-flake-quarantine/SKILL.md` | 272 | 367 |
| ha-resilience | `skills/ha-resilience/SKILL.md` | 272 | 367 |
| azure-devops-rest | `skills/azure-devops-rest/SKILL.md` | 270 | 364 |
| twelve-factor | `skills/twelve-factor/SKILL.md` | 267 | 360 |
| basecoat-10-core-contract-basecoat-10-core-testing | `skills/contract-testing/SKILL.md` | 257 | 347 |
| service-bus-migration | `skills/service-bus-migration/SKILL.md` | 254 | 343 |
| penetration-basecoat-10-core-testing | `skills/penetration-testing/SKILL.md` | 244 | 329 |
| e2e-basecoat-10-core-testing | `skills/e2e-testing/SKILL.md` | 239 | 323 |
| basecoat | `skills/basecoat/SKILL.md` | 237 | 320 |
| public-safe-sanitization | `skills/public-safe-sanitization/SKILL.md` | 236 | 319 |
| tech-debt | `skills/tech-debt/SKILL.md` | 236 | 319 |
| gitops | `skills/gitops/SKILL.md` | 235 | 317 |
| electron-apps | `skills/electron-apps/SKILL.md` | 234 | 316 |
| identity-migration | `skills/identity-migration/SKILL.md` | 234 | 316 |
| basecoat-80-data-database-migration | `skills/database-migration/SKILL.md` | 232 | 313 |
| refactoring | `skills/refactoring/SKILL.md` | 232 | 313 |
| agent-design | `skills/agent-design/SKILL.md` | 229 | 309 |
| receiving-basecoat-90-quality-code-review | `skills/receiving-code-review/SKILL.md` | 229 | 309 |
| git-worktrees | `skills/git-worktrees/SKILL.md` | 226 | 305 |
| human-in-the-loop | `skills/human-in-the-loop/SKILL.md` | 225 | 304 |
| domain-driven-design | `skills/domain-driven-design/SKILL.md` | 220 | 297 |
| create-instruction | `skills/create-instruction/SKILL.md` | 219 | 296 |
| basecoat-50-security-github-security-posture | `skills/github-security-posture/SKILL.md` | 218 | 294 |
| azure-identity | `skills/azure-identity/SKILL.md` | 216 | 292 |
| cqrs-event-sourcing | `skills/cqrs-event-sourcing/SKILL.md` | 215 | 290 |
| dev-containers | `skills/dev-containers/SKILL.md` | 215 | 290 |
| sprint-closeout-audit | `skills/sprint-closeout-audit/SKILL.md` | 215 | 290 |
| lexicon | `skills/lexicon/SKILL.md` | 214 | 289 |
| dotnet-modernization | `skills/dotnet-modernization/SKILL.md` | 213 | 288 |
| azure-container-apps | `skills/azure-container-apps/SKILL.md` | 211 | 285 |
| azure-linux-app-service | `skills/azure-linux-app-service/SKILL.md` | 210 | 284 |
| copilot-usage-analytics | `skills/copilot-usage-analytics/SKILL.md` | 209 | 282 |
| environment-bootstrap | `skills/environment-bootstrap/SKILL.md` | 209 | 282 |
| cross-stack-modernization | `skills/cross-stack-modernization/SKILL.md` | 207 | 279 |
| basecoat-10-core-production-readiness | `skills/production-readiness/SKILL.md` | 207 | 279 |
| devops | `skills/devops/SKILL.md` | 206 | 278 |
| entity-framework-migration | `skills/entity-framework-migration/SKILL.md` | 206 | 278 |
| api-design | `skills/api-design/SKILL.md` | 205 | 277 |
| basecoat-40-azure-azure-landing-zone | `skills/azure-landing-zone/SKILL.md` | 204 | 275 |
| basecoat-50-security-supply-chain-basecoat-50-security-security | `skills/supply-chain-security/SKILL.md` | 204 | 275 |
| basecoat-10-core-observability | `skills/observability/SKILL.md` | 203 | 274 |
| backlog-burndown | `skills/backlog-burndown/SKILL.md` | 202 | 273 |
| container-migration | `skills/container-migration/SKILL.md` | 202 | 273 |
| escalation-routing | `skills/escalation-routing/SKILL.md` | 202 | 273 |
| basecoat-90-quality-code-review | `skills/code-review/SKILL.md` | 201 | 271 |
| azure-waf-review | `skills/azure-waf-review/SKILL.md` | 199 | 269 |
| basecoat-50-security-security | `skills/security/SKILL.md` | 199 | 269 |
| sprint-closeout | `skills/sprint-closeout/SKILL.md` | 191 | 258 |
| azure-networking | `skills/azure-networking/SKILL.md` | 190 | 256 |
| basecoat-50-security-security-operations | `skills/security-operations/SKILL.md` | 190 | 256 |
| basecoat-10-core-station-bottleneck-analyzer | `skills/station-bottleneck-analyzer/SKILL.md` | 189 | 255 |
| basecoat-10-core-ux | `skills/ux/SKILL.md` | 189 | 255 |
| handoff | `skills/handoff/SKILL.md` | 188 | 254 |
| performance-profiling | `skills/performance-profiling/SKILL.md` | 188 | 254 |
| basecoat-10-core-backend-dev | `skills/backend-dev/SKILL.md` | 187 | 252 |
| basecoat-80-data-data-tier | `skills/data-tier/SKILL.md` | 186 | 251 |
| docs-site | `skills/docs-site/SKILL.md` | 186 | 251 |
| basecoat-10-core-sprint-retrospective | `skills/sprint-retrospective/SKILL.md` | 183 | 247 |
| basecoat-90-quality-manual-test-strategy | `skills/manual-test-strategy/SKILL.md` | 182 | 246 |
| basecoat-10-core-architecture | `skills/architecture/SKILL.md` | 179 | 242 |
| azure-policy | `skills/azure-policy/SKILL.md` | 178 | 240 |
| takt-time-measurement | `skills/takt-time-measurement/SKILL.md` | 178 | 240 |
| basecoat-10-core-app-inventory | `skills/app-inventory/SKILL.md` | 172 | 232 |
| basecoat-10-core-frontend-dev | `skills/frontend-dev/SKILL.md` | 172 | 232 |
| factory-state-machine | `skills/factory-state-machine/SKILL.md` | 170 | 230 |
| mcp-basecoat-10-core-development | `skills/mcp-development/SKILL.md` | 170 | 230 |
| s4-deployment-checklist | `skills/s4-deployment-checklist/SKILL.md` | 169 | 228 |
| bom-schema | `skills/bom-schema/SKILL.md` | 165 | 223 |
| build-failure-triage | `skills/build-failure-triage/SKILL.md` | 156 | 211 |
| orphaned-pr-triage | `skills/orphaned-pr-triage/SKILL.md` | 150 | 202 |
| bom-validation | `skills/bom-validation/SKILL.md` | 146 | 197 |
| s4-rollback-basecoat-10-core-testing | `skills/s4-rollback-testing/SKILL.md` | 138 | 186 |
| decision-log-capture | `skills/decision-log-capture/SKILL.md` | 130 | 176 |
| standup-signal-extraction | `skills/standup-signal-extraction/SKILL.md` | 126 | 170 |

## Instructions

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| basecoat-50-security-entra-oidc-user-auth | `instructions/entra-oidc-user-auth.instructions.md` | 1604 | 2165 |
| basecoat-60-workflow-multi-repo-orchestration | `instructions/multi-repo-orchestration.instructions.md` | 1324 | 1787 |
| basecoat-20-lang-ruby-on-rails | `instructions/ruby-on-rails.instructions.md` | 1233 | 1665 |
| basecoat-10-core-memory-index | `instructions/memory-index.instructions.md` | 1195 | 1613 |
| basecoat-10-core-ux | `instructions/ux.instructions.md` | 1090 | 1472 |
| basecoat-20-lang-django | `instructions/django.instructions.md` | 1052 | 1420 |
| basecoat-10-core-intent-routing | `instructions/intent-routing.instructions.md` | 1026 | 1385 |
| basecoat-10-core-hrm-execution | `instructions/hrm-execution.instructions.md` | 1010 | 1364 |
| basecoat-10-core-architecture | `instructions/architecture.instructions.md` | 1004 | 1355 |
| basecoat-10-core-mcp | `instructions/mcp.instructions.md` | 973 | 1314 |
| basecoat-20-lang-java-spring-boot | `instructions/java-spring-boot.instructions.md` | 970 | 1310 |
| basecoat-10-core-agents | `instructions/agents.instructions.md` | 940 | 1269 |
| basecoat-10-core-error-kb | `instructions/error-kb.instructions.md` | 929 | 1254 |
| basecoat-20-lang-python | `instructions/python.instructions.md` | 919 | 1241 |
| basecoat-10-core-npm-workspaces | `instructions/npm-workspaces.instructions.md` | 885 | 1195 |
| basecoat-10-core-development | `instructions/development.instructions.md` | 860 | 1161 |
| basecoat-10-core-agent-routing | `instructions/agent-routing.instructions.md` | 849 | 1146 |
| basecoat-40-azure-azure-service-connector | `instructions/azure-service-connector.instructions.md` | 833 | 1125 |
| basecoat-10-core-trm-reflexion | `instructions/trm-reflexion.instructions.md` | 811 | 1095 |
| basecoat-10-core-agent-behavior | `instructions/agent-behavior.instructions.md` | 791 | 1068 |
| basecoat-10-core-drift-monitor | `instructions/drift-monitor.instructions.md` | 733 | 990 |
| basecoat-10-core-j2ee-jakarta-ee | `instructions/j2ee-jakarta-ee.instructions.md` | 708 | 956 |
| basecoat-30-ai-ai-basecoat-10-core-verification | `instructions/ai-verification.instructions.md` | 676 | 913 |
| basecoat-10-core-rest-client-resilience | `instructions/rest-client-resilience.instructions.md` | 666 | 899 |
| basecoat-20-lang-governance | `instructions/governance.instructions.md` | 653 | 882 |
| basecoat-10-core-plan-first | `instructions/plan-first.instructions.md` | 631 | 852 |
| basecoat-40-azure-azure-app-configuration | `instructions/azure-app-configuration.instructions.md` | 621 | 838 |
| basecoat-30-ai-tailwind-v4 | `instructions/tailwind-v4.instructions.md` | 602 | 813 |
| basecoat-10-core-tool-minimization | `instructions/tool-minimization.instructions.md` | 598 | 807 |
| basecoat-10-core-model-routing | `instructions/model-routing.instructions.md` | 592 | 799 |
| basecoat-10-core-electron | `instructions/electron.instructions.md` | 577 | 779 |
| basecoat-10-core-testing | `instructions/testing.instructions.md` | 577 | 779 |
| basecoat-10-core-runtime-debugging | `instructions/runtime-debugging.instructions.md` | 571 | 771 |
| basecoat-10-core-fabric-notebooks | `instructions/fabric-notebooks.instructions.md` | 550 | 742 |
| basecoat-50-security-security | `instructions/security.instructions.md` | 531 | 717 |
| basecoat-10-core-cpp | `instructions/cpp.instructions.md` | 515 | 695 |
| basecoat-10-core-session-hygiene | `instructions/session-hygiene.instructions.md` | 507 | 684 |
| basecoat-10-core-bootstrap-structure | `instructions/bootstrap-structure.instructions.md` | 490 | 662 |
| basecoat-10-core-tdd-enforcement | `instructions/tdd-enforcement.instructions.md` | 490 | 662 |
| basecoat-10-core-config | `instructions/config.instructions.md` | 486 | 656 |
| basecoat-50-security-bootstrap-github-secrets | `instructions/bootstrap-github-secrets.instructions.md` | 479 | 647 |
| basecoat-10-core-subagent-review | `instructions/subagent-review.instructions.md` | 479 | 647 |
| basecoat-10-core-process | `instructions/process.instructions.md` | 474 | 640 |
| basecoat-60-workflow-ci-firewall | `instructions/ci-firewall.instructions.md` | 464 | 626 |
| basecoat-60-workflow-high-stakes-workflow | `instructions/high-stakes-workflow.instructions.md` | 458 | 618 |
| basecoat-10-core-observability | `instructions/observability.instructions.md` | 458 | 618 |
| basecoat-50-security-secrets-management | `instructions/secrets-management.instructions.md` | 451 | 609 |
| basecoat-90-quality-quality | `instructions/quality.instructions.md` | 450 | 608 |
| basecoat-50-security-rbac-authentication | `instructions/rbac-authentication.instructions.md` | 443 | 598 |
| basecoat-50-security-token-economics | `instructions/token-economics.instructions.md` | 419 | 566 |
| basecoat-10-core-monolith | `instructions/monolith.instructions.md` | 418 | 564 |
| basecoat-80-data-data-science | `instructions/data-science.instructions.md` | 416 | 562 |
| basecoat-10-core-enterprise-configuration | `instructions/enterprise-configuration.instructions.md` | 416 | 562 |
| basecoat-10-core-documentation | `instructions/documentation.instructions.md` | 398 | 537 |
| basecoat-10-core-bootstrap-autodetect | `instructions/bootstrap-autodetect.instructions.md` | 392 | 529 |
| basecoat-50-security-security-monitoring | `instructions/security-monitoring.instructions.md` | 369 | 498 |
| basecoat-10-core-mutation-basecoat-10-core-testing | `instructions/mutation-testing.instructions.md` | 336 | 454 |
| basecoat-10-core-nextjs-react19 | `instructions/nextjs-react19.instructions.md` | 306 | 413 |
| basecoat-10-core-data-workload-basecoat-10-core-testing | `instructions/data-workload-testing.instructions.md` | 284 | 383 |
| basecoat-10-core-frontend | `instructions/frontend.instructions.md` | 281 | 379 |
| basecoat-10-core-verification | `instructions/verification.instructions.md` | 280 | 378 |
| basecoat-10-core-reliability | `instructions/reliability.instructions.md` | 278 | 375 |
| basecoat-10-core-terraform-init | `instructions/terraform-init.instructions.md` | 277 | 374 |
| basecoat-10-core-public-guidance | `instructions/public-guidance.instructions.md` | 275 | 371 |
| basecoat-40-azure-azure | `instructions/azure.instructions.md` | 270 | 364 |
| basecoat-60-workflow-workflow-integrity | `instructions/workflow-integrity.instructions.md` | 268 | 362 |
| basecoat-10-core-bicep | `instructions/bicep.instructions.md` | 255 | 344 |
| basecoat-10-core-terraform | `instructions/terraform.instructions.md` | 255 | 344 |
| basecoat-10-core-escalation-criteria | `instructions/escalation-criteria.instructions.md` | 248 | 335 |
| basecoat-20-lang-dotnet-upgrade-planning | `instructions/dotnet-upgrade-planning.instructions.md` | 247 | 333 |
| basecoat-60-workflow-factory-orchestration | `instructions/factory-orchestration.instructions.md` | 245 | 331 |
| basecoat-10-core-output-style | `instructions/output-style.instructions.md` | 243 | 328 |
| basecoat-60-workflow-workflow-file-integrity | `instructions/workflow-file-integrity.instructions.md` | 241 | 325 |
| basecoat-20-lang-dotnet-test-strategy | `instructions/dotnet-test-strategy.instructions.md` | 223 | 301 |
| basecoat-20-lang-dotnet-dependency-analysis | `instructions/dotnet-dependency-analysis.instructions.md` | 222 | 300 |
| basecoat-50-security-copilot-github-token-bootstrap | `instructions/copilot-github-token-bootstrap.instructions.md` | 214 | 289 |
| basecoat-10-core-naming | `instructions/naming.instructions.md` | 196 | 265 |
| basecoat-10-core-backend | `instructions/backend.instructions.md` | 180 | 243 |
| basecoat-10-core-s4-safety-gates | `instructions/s4-safety-gates.instructions.md` | 157 | 212 |
