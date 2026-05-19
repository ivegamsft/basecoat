# Token Context Inventory

Generated as a standalone inventory (no edits to agent/skill/instruction files).

- Generated: 2026-05-19 00:52:28 -0400
- Estimation method: `approx_tokens = round(word_count × 1.35)` (same heuristic used in `scripts/validate-basecoat.ps1`).
- Scope: `agents/*.agent.md`, `skills/*/SKILL.md`, `instructions/*.instructions.md`.

## Summary

| Type | Count | Total Words | Total Approx Tokens | Avg Approx Tokens |
|---|---:|---:|---:|---:|
| Agent | 98 | 101941 | 137617 | 1404 |
| Skill | 78 | 16391 | 22127 | 284 |
| Instruction | 76 | 43209 | 58334 | 768 |
| **All** | 252 | 161541 | 218078 | 865 |

## Agents

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| production-readiness | `agents/production-readiness.agent.md` | 2195 | 2963 |
| resilience-reviewer | `agents/resilience-reviewer.agent.md` | 2107 | 2844 |
| self-healing-ci | `agents/self-healing-ci.agent.md` | 1979 | 2672 |
| release-impact-advisor | `agents/release-impact-advisor.agent.md` | 1945 | 2626 |
| definition-of-done | `agents/definition-of-done.agent.md` | 1900 | 2565 |
| incident-responder | `agents/incident-responder.agent.md` | 1858 | 2508 |
| domain-designer | `agents/domain-designer.agent.md` | 1793 | 2421 |
| e2e-test-strategy | `agents/e2e-test-strategy.agent.md` | 1776 | 2398 |
| ha-architect | `agents/ha-architect.agent.md` | 1770 | 2390 |
| contract-testing | `agents/contract-testing.agent.md` | 1760 | 2376 |
| devops-engineer | `agents/devops-engineer.agent.md` | 1739 | 2348 |
| feedback-loop | `agents/feedback-loop.agent.md` | 1696 | 2290 |
| llmops | `agents/llmops.agent.md` | 1605 | 2167 |
| data-pipeline | `agents/data-pipeline.agent.md` | 1600 | 2160 |
| hardening-advisor | `agents/hardening-advisor.agent.md` | 1597 | 2156 |
| chaos-engineer | `agents/chaos-engineer.agent.md` | 1574 | 2125 |
| retro-facilitator | `agents/retro-facilitator.agent.md` | 1555 | 2099 |
| merge-coordinator | `agents/merge-coordinator.agent.md` | 1553 | 2097 |
| memory-curator | `agents/memory-curator.agent.md` | 1540 | 2079 |
| data-integrity | `agents/data-integrity.agent.md` | 1512 | 2041 |
| azure-landing-zone | `agents/azure-landing-zone.agent.md` | 1495 | 2018 |
| supply-chain-security | `agents/supply-chain-security.agent.md` | 1491 | 2013 |
| observability-engineer | `agents/observability-engineer.agent.md` | 1472 | 1987 |
| container-security | `agents/container-security.agent.md` | 1467 | 1980 |
| containerization-planner | `agents/containerization-planner.agent.md` | 1442 | 1947 |
| agentops | `agents/agentops.agent.md` | 1438 | 1941 |
| release-manager | `agents/release-manager.agent.md` | 1384 | 1868 |
| project-onboarding | `agents/project-onboarding.agent.md` | 1346 | 1817 |
| api-security | `agents/api-security.agent.md` | 1344 | 1814 |
| secrets-manager | `agents/secrets-manager.agent.md` | 1339 | 1808 |
| policy-as-code-compliance | `agents/policy-as-code-compliance.agent.md` | 1334 | 1801 |
| mcp-developer | `agents/mcp-developer.agent.md` | 1304 | 1760 |
| performance-analyst | `agents/performance-analyst.agent.md` | 1303 | 1759 |
| sre-engineer | `agents/sre-engineer.agent.md` | 1297 | 1751 |
| ux-designer | `agents/ux-designer.agent.md` | 1283 | 1732 |
| penetration-test | `agents/penetration-test.agent.md` | 1252 | 1690 |
| finops-advisor | `agents/finops-advisor.agent.md` | 1245 | 1681 |
| mlops | `agents/mlops.agent.md` | 1239 | 1673 |
| dataops | `agents/dataops.agent.md` | 1215 | 1640 |
| agent-designer | `agents/agent-designer.agent.md` | 1196 | 1615 |
| prompt-coach | `agents/prompt-coach.agent.md` | 1191 | 1608 |
| api-designer | `agents/api-designer.agent.md` | 1187 | 1602 |
| sprint-planner | `agents/sprint-planner.agent.md` | 1183 | 1597 |
| data-tier | `agents/data-tier.agent.md` | 1173 | 1584 |
| github-security-posture | `agents/github-security-posture.agent.md` | 1155 | 1559 |
| security-monitor | `agents/security-monitor.agent.md` | 1149 | 1551 |
| solution-architect | `agents/solution-architect.agent.md` | 1138 | 1536 |
| identity-architect | `agents/identity-architect.agent.md` | 1136 | 1534 |
| security-analyst | `agents/security-analyst.agent.md` | 1134 | 1531 |
| legacy-modernization | `agents/legacy-modernization.agent.md` | 1127 | 1521 |
| ci-failure-escalation | `agents/ci-failure-escalation.agent.md` | 1120 | 1512 |
| prompt-engineer | `agents/prompt-engineer.agent.md` | 1096 | 1480 |
| orchestrator | `agents/orchestrator.agent.md` | 1067 | 1440 |
| app-inventory | `agents/app-inventory.agent.md` | 1022 | 1380 |
| middleware-dev | `agents/middleware-dev.agent.md` | 1009 | 1362 |
| gitops-engineer | `agents/gitops-engineer.agent.md` | 997 | 1346 |
| database-migration | `agents/database-migration.agent.md` | 996 | 1345 |
| backend-dev | `agents/backend-dev.agent.md` | 984 | 1328 |
| dependency-lifecycle | `agents/dependency-lifecycle.agent.md` | 984 | 1328 |
| frontend-dev | `agents/frontend-dev.agent.md` | 969 | 1308 |
| instruction-auditor | `agents/instruction-auditor.agent.md` | 918 | 1239 |
| security-operations | `agents/security-operations.agent.md` | 895 | 1208 |
| issue-triage | `agents/issue-triage.agent.md` | 864 | 1166 |
| guardrail | `agents/guardrail.agent.md` | 832 | 1123 |
| infrastructure-deploy | `agents/infrastructure-deploy.agent.md` | 762 | 1029 |
| config-auditor | `agents/config-auditor.agent.md` | 758 | 1023 |
| product-manager | `agents/product-manager.agent.md` | 739 | 998 |
| memory-promoter | `agents/memory-promoter.agent.md` | 734 | 991 |
| guidance-reviewer | `agents/guidance-reviewer.agent.md` | 685 | 925 |
| tech-writer | `agents/tech-writer.agent.md` | 676 | 913 |
| data-architect | `agents/data-architect.agent.md` | 663 | 895 |
| strategy-to-automation | `agents/strategy-to-automation.agent.md` | 661 | 892 |
| dependency-update-advisor | `agents/dependency-update-advisor.agent.md` | 652 | 880 |
| exploratory-charter | `agents/exploratory-charter.agent.md` | 582 | 786 |
| escalation-router | `agents/escalation-router.agent.md` | 540 | 729 |
| guidance-author | `agents/guidance-author.agent.md` | 526 | 710 |
| manual-test-strategy | `agents/manual-test-strategy.agent.md` | 524 | 707 |
| dependency-blocker-monitor | `agents/dependency-blocker-monitor.agent.md` | 498 | 672 |
| sprint-closeout-auditor | `agents/sprint-closeout-auditor.agent.md` | 415 | 560 |
| dotnet-modernization-advisor | `agents/dotnet-modernization-advisor.agent.md` | 390 | 526 |
| code-review | `agents/code-review.agent.md` | 389 | 525 |
| station-bottleneck-analyzer | `agents/station-bottleneck-analyzer.agent.md` | 368 | 497 |
| new-customization | `agents/new-customization.agent.md` | 367 | 495 |
| rollout-basecoat | `agents/rollout-basecoat.agent.md` | 361 | 487 |
| rca | `agents/rca.agent.md` | 338 | 456 |
| branch-hygiene-sweeper | `agents/branch-hygiene-sweeper.agent.md` | 330 | 446 |
| sprint-retrospective | `agents/sprint-retrospective.agent.md` | 310 | 418 |
| orphaned-pr-cleanup | `agents/orphaned-pr-cleanup.agent.md` | 290 | 392 |
| release-freeze-enforcer | `agents/release-freeze-enforcer.agent.md` | 287 | 387 |
| broken-build-troubleshooter | `agents/broken-build-troubleshooter.agent.md` | 286 | 386 |
| release-readiness-chair | `agents/release-readiness-chair.agent.md` | 243 | 328 |
| daily-standup-facilitator | `agents/daily-standup-facilitator.agent.md` | 237 | 320 |
| takt-time-tracker | `agents/takt-time-tracker.agent.md` | 203 | 274 |
| replanning-engine | `agents/replanning-engine.agent.md` | 184 | 248 |
| factory-state-curator | `agents/factory-state-curator.agent.md` | 175 | 236 |
| s4-shadow-mode-validator | `agents/s4-shadow-mode-validator.agent.md` | 172 | 232 |
| factory-conductor | `agents/factory-conductor.agent.md` | 170 | 230 |
| bom-validator | `agents/bom-validator.agent.md` | 160 | 216 |

## Skills

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| create-skill | `skills/create-skill/SKILL.md` | 295 | 398 |
| merge-conflict-mediator | `skills/merge-conflict-mediator/SKILL.md` | 291 | 393 |
| documentation | `skills/documentation/SKILL.md` | 285 | 385 |
| dependency-blocker-monitoring | `skills/dependency-blocker-monitoring/SKILL.md` | 283 | 382 |
| api-security | `skills/api-security/SKILL.md` | 280 | 378 |
| sprint-management | `skills/sprint-management/SKILL.md` | 273 | 369 |
| ci-flake-quarantine | `skills/ci-flake-quarantine/SKILL.md` | 272 | 367 |
| ha-resilience | `skills/ha-resilience/SKILL.md` | 272 | 367 |
| azure-devops-rest | `skills/azure-devops-rest/SKILL.md` | 270 | 364 |
| twelve-factor | `skills/twelve-factor/SKILL.md` | 267 | 360 |
| contract-testing | `skills/contract-testing/SKILL.md` | 257 | 347 |
| service-bus-migration | `skills/service-bus-migration/SKILL.md` | 254 | 343 |
| penetration-testing | `skills/penetration-testing/SKILL.md` | 244 | 329 |
| e2e-testing | `skills/e2e-testing/SKILL.md` | 239 | 323 |
| basecoat | `skills/basecoat/SKILL.md` | 237 | 320 |
| public-safe-sanitization | `skills/public-safe-sanitization/SKILL.md` | 236 | 319 |
| tech-debt | `skills/tech-debt/SKILL.md` | 236 | 319 |
| gitops | `skills/gitops/SKILL.md` | 235 | 317 |
| electron-apps | `skills/electron-apps/SKILL.md` | 234 | 316 |
| identity-migration | `skills/identity-migration/SKILL.md` | 234 | 316 |
| database-migration | `skills/database-migration/SKILL.md` | 232 | 313 |
| refactoring | `skills/refactoring/SKILL.md` | 232 | 313 |
| agent-design | `skills/agent-design/SKILL.md` | 229 | 309 |
| human-in-the-loop | `skills/human-in-the-loop/SKILL.md` | 225 | 304 |
| domain-driven-design | `skills/domain-driven-design/SKILL.md` | 220 | 297 |
| create-instruction | `skills/create-instruction/SKILL.md` | 219 | 296 |
| github-security-posture | `skills/github-security-posture/SKILL.md` | 218 | 294 |
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
| production-readiness | `skills/production-readiness/SKILL.md` | 207 | 279 |
| devops | `skills/devops/SKILL.md` | 206 | 278 |
| entity-framework-migration | `skills/entity-framework-migration/SKILL.md` | 206 | 278 |
| api-design | `skills/api-design/SKILL.md` | 205 | 277 |
| azure-landing-zone | `skills/azure-landing-zone/SKILL.md` | 204 | 275 |
| supply-chain-security | `skills/supply-chain-security/SKILL.md` | 204 | 275 |
| observability | `skills/observability/SKILL.md` | 203 | 274 |
| backlog-burndown | `skills/backlog-burndown/SKILL.md` | 202 | 273 |
| container-migration | `skills/container-migration/SKILL.md` | 202 | 273 |
| escalation-routing | `skills/escalation-routing/SKILL.md` | 202 | 273 |
| code-review | `skills/code-review/SKILL.md` | 201 | 271 |
| azure-waf-review | `skills/azure-waf-review/SKILL.md` | 199 | 269 |
| security | `skills/security/SKILL.md` | 199 | 269 |
| sprint-closeout | `skills/sprint-closeout/SKILL.md` | 191 | 258 |
| azure-networking | `skills/azure-networking/SKILL.md` | 190 | 256 |
| security-operations | `skills/security-operations/SKILL.md` | 190 | 256 |
| station-bottleneck-analyzer | `skills/station-bottleneck-analyzer/SKILL.md` | 189 | 255 |
| ux | `skills/ux/SKILL.md` | 189 | 255 |
| handoff | `skills/handoff/SKILL.md` | 188 | 254 |
| performance-profiling | `skills/performance-profiling/SKILL.md` | 188 | 254 |
| backend-dev | `skills/backend-dev/SKILL.md` | 187 | 252 |
| data-tier | `skills/data-tier/SKILL.md` | 186 | 251 |
| docs-site | `skills/docs-site/SKILL.md` | 186 | 251 |
| sprint-retrospective | `skills/sprint-retrospective/SKILL.md` | 183 | 247 |
| manual-test-strategy | `skills/manual-test-strategy/SKILL.md` | 182 | 246 |
| architecture | `skills/architecture/SKILL.md` | 179 | 242 |
| azure-policy | `skills/azure-policy/SKILL.md` | 178 | 240 |
| takt-time-measurement | `skills/takt-time-measurement/SKILL.md` | 178 | 240 |
| app-inventory | `skills/app-inventory/SKILL.md` | 172 | 232 |
| frontend-dev | `skills/frontend-dev/SKILL.md` | 172 | 232 |
| factory-state-machine | `skills/factory-state-machine/SKILL.md` | 170 | 230 |
| mcp-development | `skills/mcp-development/SKILL.md` | 170 | 230 |
| s4-deployment-checklist | `skills/s4-deployment-checklist/SKILL.md` | 169 | 228 |
| bom-schema | `skills/bom-schema/SKILL.md` | 165 | 223 |
| build-failure-triage | `skills/build-failure-triage/SKILL.md` | 156 | 211 |
| orphaned-pr-triage | `skills/orphaned-pr-triage/SKILL.md` | 150 | 202 |
| bom-validation | `skills/bom-validation/SKILL.md` | 146 | 197 |
| s4-rollback-testing | `skills/s4-rollback-testing/SKILL.md` | 138 | 186 |
| decision-log-capture | `skills/decision-log-capture/SKILL.md` | 130 | 176 |
| standup-signal-extraction | `skills/standup-signal-extraction/SKILL.md` | 126 | 170 |

## Instructions

| Name | Location | Words | Approx Tokens |
|---|---|---:|---:|
| entra-oidc-user-auth | `instructions/entra-oidc-user-auth.instructions.md` | 1604 | 2165 |
| multi-repo-orchestration | `instructions/multi-repo-orchestration.instructions.md` | 1316 | 1777 |
| ruby-on-rails | `instructions/ruby-on-rails.instructions.md` | 1233 | 1665 |
| memory-index | `instructions/memory-index.instructions.md` | 1195 | 1613 |
| ux | `instructions/ux.instructions.md` | 1090 | 1472 |
| django | `instructions/django.instructions.md` | 1052 | 1420 |
| intent-routing | `instructions/intent-routing.instructions.md` | 1026 | 1385 |
| hrm-execution | `instructions/hrm-execution.instructions.md` | 1010 | 1364 |
| architecture | `instructions/architecture.instructions.md` | 1004 | 1355 |
| mcp | `instructions/mcp.instructions.md` | 973 | 1314 |
| java-spring-boot | `instructions/java-spring-boot.instructions.md` | 970 | 1310 |
| agents | `instructions/agents.instructions.md` | 940 | 1269 |
| error-kb | `instructions/error-kb.instructions.md` | 929 | 1254 |
| python | `instructions/python.instructions.md` | 919 | 1241 |
| npm-workspaces | `instructions/npm-workspaces.instructions.md` | 885 | 1195 |
| development | `instructions/development.instructions.md` | 860 | 1161 |
| agent-routing | `instructions/agent-routing.instructions.md` | 849 | 1146 |
| azure-service-connector | `instructions/azure-service-connector.instructions.md` | 833 | 1125 |
| trm-reflexion | `instructions/trm-reflexion.instructions.md` | 811 | 1095 |
| agent-behavior | `instructions/agent-behavior.instructions.md` | 791 | 1068 |
| drift-monitor | `instructions/drift-monitor.instructions.md` | 733 | 990 |
| j2ee-jakarta-ee | `instructions/j2ee-jakarta-ee.instructions.md` | 708 | 956 |
| ai-verification | `instructions/ai-verification.instructions.md` | 676 | 913 |
| rest-client-resilience | `instructions/rest-client-resilience.instructions.md` | 666 | 899 |
| governance | `instructions/governance.instructions.md` | 653 | 882 |
| azure-app-configuration | `instructions/azure-app-configuration.instructions.md` | 621 | 838 |
| tailwind-v4 | `instructions/tailwind-v4.instructions.md` | 602 | 813 |
| tool-minimization | `instructions/tool-minimization.instructions.md` | 598 | 807 |
| model-routing | `instructions/model-routing.instructions.md` | 592 | 799 |
| electron | `instructions/electron.instructions.md` | 577 | 779 |
| testing | `instructions/testing.instructions.md` | 577 | 779 |
| runtime-debugging | `instructions/runtime-debugging.instructions.md` | 571 | 771 |
| fabric-notebooks | `instructions/fabric-notebooks.instructions.md` | 550 | 742 |
| security | `instructions/security.instructions.md` | 531 | 717 |
| cpp | `instructions/cpp.instructions.md` | 515 | 695 |
| session-hygiene | `instructions/session-hygiene.instructions.md` | 507 | 684 |
| bootstrap-structure | `instructions/bootstrap-structure.instructions.md` | 490 | 662 |
| config | `instructions/config.instructions.md` | 486 | 656 |
| bootstrap-github-secrets | `instructions/bootstrap-github-secrets.instructions.md` | 479 | 647 |
| process | `instructions/process.instructions.md` | 474 | 640 |
| ci-firewall | `instructions/ci-firewall.instructions.md` | 464 | 626 |
| observability | `instructions/observability.instructions.md` | 458 | 618 |
| secrets-management | `instructions/secrets-management.instructions.md` | 451 | 609 |
| quality | `instructions/quality.instructions.md` | 450 | 608 |
| rbac-authentication | `instructions/rbac-authentication.instructions.md` | 443 | 598 |
| plan-first | `instructions/plan-first.instructions.md` | 438 | 591 |
| token-economics | `instructions/token-economics.instructions.md` | 419 | 566 |
| monolith | `instructions/monolith.instructions.md` | 418 | 564 |
| data-science | `instructions/data-science.instructions.md` | 416 | 562 |
| enterprise-configuration | `instructions/enterprise-configuration.instructions.md` | 416 | 562 |
| documentation | `instructions/documentation.instructions.md` | 398 | 537 |
| bootstrap-autodetect | `instructions/bootstrap-autodetect.instructions.md` | 392 | 529 |
| security-monitoring | `instructions/security-monitoring.instructions.md` | 369 | 498 |
| mutation-testing | `instructions/mutation-testing.instructions.md` | 336 | 454 |
| nextjs-react19 | `instructions/nextjs-react19.instructions.md` | 306 | 413 |
| data-workload-testing | `instructions/data-workload-testing.instructions.md` | 284 | 383 |
| frontend | `instructions/frontend.instructions.md` | 281 | 379 |
| verification | `instructions/verification.instructions.md` | 280 | 378 |
| reliability | `instructions/reliability.instructions.md` | 278 | 375 |
| terraform-init | `instructions/terraform-init.instructions.md` | 277 | 374 |
| public-guidance | `instructions/public-guidance.instructions.md` | 275 | 371 |
| azure | `instructions/azure.instructions.md` | 270 | 364 |
| workflow-integrity | `instructions/workflow-integrity.instructions.md` | 268 | 362 |
| bicep | `instructions/bicep.instructions.md` | 255 | 344 |
| terraform | `instructions/terraform.instructions.md` | 255 | 344 |
| escalation-criteria | `instructions/escalation-criteria.instructions.md` | 248 | 335 |
| dotnet-upgrade-planning | `instructions/dotnet-upgrade-planning.instructions.md` | 247 | 333 |
| factory-orchestration | `instructions/factory-orchestration.instructions.md` | 245 | 331 |
| output-style | `instructions/output-style.instructions.md` | 243 | 328 |
| workflow-file-integrity | `instructions/workflow-file-integrity.instructions.md` | 241 | 325 |
| dotnet-test-strategy | `instructions/dotnet-test-strategy.instructions.md` | 223 | 301 |
| dotnet-dependency-analysis | `instructions/dotnet-dependency-analysis.instructions.md` | 222 | 300 |
| copilot-github-token-bootstrap | `instructions/copilot-github-token-bootstrap.instructions.md` | 214 | 289 |
| naming | `instructions/naming.instructions.md` | 196 | 265 |
| backend | `instructions/backend.instructions.md` | 180 | 243 |
| s4-safety-gates | `instructions/s4-safety-gates.instructions.md` | 157 | 212 |
