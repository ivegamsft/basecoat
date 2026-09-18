# Dependency Graph

- Generated: 2026-09-14T14:39:41Z
- Source workflow: .github/workflows/dependency-graph-pages.yml

```mermaid
graph LR

    %% Agents (blue)
    agent_agent_designer[[agent-designer]]:::agent
    agent_agentic_sdlc_autonomy[[agentic-sdlc-autonomy]]:::agent
    agent_agentops[[agentops]]:::agent
    agent_api_designer[[api-designer]]:::agent
    agent_api_security[[api-security]]:::agent
    agent_app_inventory[[app-inventory]]:::agent
    agent_azure_landing_zone[[azure-landing-zone]]:::agent
    agent_backend_dev[[backend-dev]]:::agent
    agent_backlog_autopilot[[backlog-autopilot]]:::agent
    agent_backlog_rebalancer[[backlog-rebalancer]]:::agent
    agent_bom_validator[[bom-validator]]:::agent
    agent_branch_hygiene_sweeper[[branch-hygiene-sweeper]]:::agent
    agent_broken_build_troubleshooter[[broken-build-troubleshooter]]:::agent
    agent_build_master[[build-master]]:::agent
    agent_change_isolation_architect[[change-isolation-architect]]:::agent
    agent_chaos_engineer[[chaos-engineer]]:::agent
    agent_ci_audit[[ci-audit]]:::agent
    agent_ci_failure_escalation[[ci-failure-escalation]]:::agent
    agent_ci_guardrail_accelerator[[ci-guardrail-accelerator]]:::agent
    agent_code_review[[code-review]]:::agent
    agent_config_auditor[[config-auditor]]:::agent
    agent_Container_Security[[Container Security]]:::agent
    agent_containerization_planner[[containerization-planner]]:::agent
    agent_contract_testing[[contract-testing]]:::agent
    agent_copilot_review_triage[[copilot-review-triage]]:::agent
    agent_daily_standup_facilitator[[daily-standup-facilitator]]:::agent
    agent_Data_Integrity[[Data Integrity]]:::agent
    agent_data_architect[[data-architect]]:::agent
    agent_data_pipeline[[data-pipeline]]:::agent
    agent_data_tier[[data-tier]]:::agent
    agent_database_migration[[database-migration]]:::agent
    agent_dataops[[dataops]]:::agent
    agent_definition_of_done[[definition-of-done]]:::agent
    agent_delivery_autopilot[[delivery-autopilot]]:::agent
    agent_delivery_gap_mapper[[delivery-gap-mapper]]:::agent
    agent_dependabot_prioritizer[[dependabot-prioritizer]]:::agent
    agent_dependency_blocker_monitor[[dependency-blocker-monitor]]:::agent
    agent_dependency_lifecycle[[dependency-lifecycle]]:::agent
    agent_dependency_update_advisor[[dependency-update-advisor]]:::agent
    agent_devops_engineer[[devops-engineer]]:::agent
    agent_domain_designer[[domain-designer]]:::agent
    agent_dotnet_modernization_advisor[[dotnet-modernization-advisor]]:::agent
    agent_e2e_test_strategy[[e2e-test-strategy]]:::agent
    agent_escalation_router[[escalation-router]]:::agent
    agent_exploratory_charter[[exploratory-charter]]:::agent
    agent_factory_conductor[[factory-conductor]]:::agent
    agent_factory_state_curator[[factory-state-curator]]:::agent
    agent_failure_pattern_process[[failure-pattern-process]]:::agent
    agent_feedback_loop[[feedback-loop]]:::agent
    agent_finops_advisor[[finops-advisor]]:::agent
    agent_flow_admission_controller[[flow-admission-controller]]:::agent
    agent_flow_auditor[[flow-auditor]]:::agent
    agent_flow_governance_conductor[[flow-governance-conductor]]:::agent
    agent_flow_optimizer[[flow-optimizer]]:::agent
    agent_flow_suggester[[flow-suggester]]:::agent
    agent_flow_tracker[[flow-tracker]]:::agent
    agent_frontend_dev[[frontend-dev]]:::agent
    agent_github_security_posture[[github-security-posture]]:::agent
    agent_gitops_engineer[[gitops-engineer]]:::agent
    agent_governance_auditor[[governance-auditor]]:::agent
    agent_governance_author[[governance-author]]:::agent
    agent_guardrail[[guardrail]]:::agent
    agent_guidance_author[[guidance-author]]:::agent
    agent_guidance_reviewer[[guidance-reviewer]]:::agent
    agent_ha_architect[[ha-architect]]:::agent
    agent_Hardening_Advisor[[Hardening Advisor]]:::agent
    agent_identity_architect[[identity-architect]]:::agent
    agent_incident_responder[[incident-responder]]:::agent
    agent_incident_to_backlog_router[[incident-to-backlog-router]]:::agent
    agent_infrastructure_deploy[[infrastructure-deploy]]:::agent
    agent_instruction_auditor[[instruction-auditor]]:::agent
    agent_issue_triage[[issue-triage]]:::agent
    agent_legacy_modernization[[legacy-modernization]]:::agent
    agent_llmops[[llmops]]:::agent
    agent_local_dev_data_pack_orchestrator[[local-dev-data-pack-orchestrator]]:::agent
    agent_manual_test_strategy[[manual-test-strategy]]:::agent
    agent_mcp_developer[[mcp-developer]]:::agent
    agent_memory_curator[[memory-curator]]:::agent
    agent_memory_promoter[[memory-promoter]]:::agent
    agent_merge_coordinator[[merge-coordinator]]:::agent
    agent_middleware_dev[[middleware-dev]]:::agent
    agent_mlops[[mlops]]:::agent
    agent_new_customization[[new-customization]]:::agent
    agent_Observability_Engineer[[Observability Engineer]]:::agent
    agent_orchestrator[[orchestrator]]:::agent
    agent_orchestrator_compat[[orchestrator-compat]]:::agent
    agent_orphaned_pr_cleanup[[orphaned-pr-cleanup]]:::agent
    agent_parallel_session_coordinator[[parallel-session-coordinator]]:::agent
    agent_penetration_test[[penetration-test]]:::agent
    agent_performance_analyst[[performance-analyst]]:::agent
    agent_policy_as_code_compliance[[policy-as-code-compliance]]:::agent
    agent_product_manager[[product-manager]]:::agent
    agent_production_readiness[[production-readiness]]:::agent
    agent_program_bootstrap[[program-bootstrap]]:::agent
    agent_project_onboarding[[project-onboarding]]:::agent
    agent_project_rules_drift_auditor[[project-rules-drift-auditor]]:::agent
    agent_prompt_coach[[prompt-coach]]:::agent
    agent_prompt_engineer[[prompt-engineer]]:::agent
    agent_queue_rebalancer[[queue-rebalancer]]:::agent
    agent_rca[[rca]]:::agent
    agent_release_freeze_enforcer[[release-freeze-enforcer]]:::agent
    agent_release_impact_advisor[[release-impact-advisor]]:::agent
    agent_release_manager[[release-manager]]:::agent
    agent_release_readiness_chair[[release-readiness-chair]]:::agent
    agent_replanning_engine[[replanning-engine]]:::agent
    agent_Resilience_Reviewer[[Resilience Reviewer]]:::agent
    agent_retro_facilitator[[retro-facilitator]]:::agent
    agent_rollout_basecoat[[rollout-basecoat]]:::agent
    agent_run_history_cleanup[[run-history-cleanup]]:::agent
    agent_s4_shadow_mode_validator[[s4-shadow-mode-validator]]:::agent
    agent_Secrets_Manager[[Secrets Manager]]:::agent
    agent_Security_Monitor[[Security Monitor]]:::agent
    agent_security_analyst[[security-analyst]]:::agent
    agent_security_operations[[security-operations]]:::agent
    agent_self_healing_ci[[self-healing-ci]]:::agent
    agent_ship_it_control_loop[[ship-it-control-loop]]:::agent
    agent_ship_it_orchestrator[[ship-it-orchestrator]]:::agent
    agent_solution_architect[[solution-architect]]:::agent
    agent_sprint_closeout_auditor[[sprint-closeout-auditor]]:::agent
    agent_sprint_planner[[sprint-planner]]:::agent
    agent_sprint_project_mapper[[sprint-project-mapper]]:::agent
    agent_sprint_retrospective[[sprint-retrospective]]:::agent
    agent_sre_engineer[[sre-engineer]]:::agent
    agent_station_bottleneck_analyzer[[station-bottleneck-analyzer]]:::agent
    agent_strategy_to_automation[[strategy-to-automation]]:::agent
    agent_supply_chain_security[[supply-chain-security]]:::agent
    agent_takt_time_tracker[[takt-time-tracker]]:::agent
    agent_task_scope_validator[[task-scope-validator]]:::agent
    agent_tech_writer[[tech-writer]]:::agent
    agent_ux_designer[[ux-designer]]:::agent
    agent_workflow_gate_diagnostician[[workflow-gate-diagnostician]]:::agent

    %% Skills (green)
    skill_agent_design((agent-design)):::skill
    skill_agentic_cost_audit((agentic-cost-audit)):::skill
    skill_agentic_sdlc_autonomy((agentic-sdlc-autonomy)):::skill
    skill_agentops_audit((agentops-audit)):::skill
    skill_api_audit((api-audit)):::skill
    skill_api_design((api-design)):::skill
    skill_api_security((api-security)):::skill
    skill_app_inventory((app-inventory)):::skill
    skill_architecture((architecture)):::skill
    skill_azure_container_apps((azure-container-apps)):::skill
    skill_azure_devops_rest((azure-devops-rest)):::skill
    skill_azure_identity((azure-identity)):::skill
    skill_azure_identity_audit((azure-identity-audit)):::skill
    skill_azure_landing_zone((azure-landing-zone)):::skill
    skill_azure_linux_app_service((azure-linux-app-service)):::skill
    skill_azure_networking((azure-networking)):::skill
    skill_azure_policy((azure-policy)):::skill
    skill_azure_policy_audit((azure-policy-audit)):::skill
    skill_azure_waf_review((azure-waf-review)):::skill
    skill_backend_audit((backend-audit)):::skill
    skill_backend_dev((backend-dev)):::skill
    skill_backlog_burndown((backlog-burndown)):::skill
    skill_backlog_rebalance_engine((backlog-rebalance-engine)):::skill
    skill_backlog_revalidation((backlog-revalidation)):::skill
    skill_basecoat((basecoat)):::skill
    skill_basecoat_help((basecoat-help)):::skill
    skill_bom_schema((bom-schema)):::skill
    skill_bom_validation((bom-validation)):::skill
    skill_build_failure_triage((build-failure-triage)):::skill
    skill_build_master_control_plane((build-master-control-plane)):::skill
    skill_change_isolation((change-isolation)):::skill
    skill_ci_audit((ci-audit)):::skill
    skill_ci_cd_diagnostics((ci-cd-diagnostics)):::skill
    skill_ci_flake_quarantine((ci-flake-quarantine)):::skill
    skill_code_review((code-review)):::skill
    skill_config_secrets_audit((config-secrets-audit)):::skill
    skill_container_build_assessment((container-build-assessment)):::skill
    skill_container_migration((container-migration)):::skill
    skill_contract_testing((contract-testing)):::skill
    skill_copilot_review_triage((copilot-review-triage)):::skill
    skill_copilot_usage_analytics((copilot-usage-analytics)):::skill
    skill_cqrs_event_sourcing((cqrs-event-sourcing)):::skill
    skill_create_instruction((create-instruction)):::skill
    skill_create_skill((create-skill)):::skill
    skill_cross_stack_modernization((cross-stack-modernization)):::skill
    skill_data_tier((data-tier)):::skill
    skill_data_tier_audit((data-tier-audit)):::skill
    skill_database_migration((database-migration)):::skill
    skill_decision_log_capture((decision-log-capture)):::skill
    skill_delivery_autopilot((delivery-autopilot)):::skill
    skill_dependency_blocker_monitoring((dependency-blocker-monitoring)):::skill
    skill_dev_containers((dev-containers)):::skill
    skill_devops((devops)):::skill
    skill_devops_audit((devops-audit)):::skill
    skill_docs_site((docs-site)):::skill
    skill_documentation((documentation)):::skill
    skill_domain_driven_design((domain-driven-design)):::skill
    skill_dotnet_modernization((dotnet-modernization)):::skill
    skill_e2e_testing((e2e-testing)):::skill
    skill_electron_apps((electron-apps)):::skill
    skill_entity_framework_migration((entity-framework-migration)):::skill
    skill_environment_audit_drift((environment-audit-drift)):::skill
    skill_environment_bootstrap((environment-bootstrap)):::skill
    skill_escalation_routing((escalation-routing)):::skill
    skill_factory_state_machine((factory-state-machine)):::skill
    skill_failure_pattern_process((failure-pattern-process)):::skill
    skill_flow_admission_control((flow-admission-control)):::skill
    skill_flow_audit((flow-audit)):::skill
    skill_flow_optimize((flow-optimize)):::skill
    skill_flow_suggest((flow-suggest)):::skill
    skill_flow_track((flow-track)):::skill
    skill_frontend_audit((frontend-audit)):::skill
    skill_frontend_dev((frontend-dev)):::skill
    skill_git_worktrees((git-worktrees)):::skill
    skill_github_security_posture((github-security-posture)):::skill
    skill_gitops((gitops)):::skill
    skill_governance((governance)):::skill
    skill_governance_audit((governance-audit)):::skill
    skill_ha_resilience((ha-resilience)):::skill
    skill_handoff((handoff)):::skill
    skill_human_in_the_loop((human-in-the-loop)):::skill
    skill_hybrid_branching_audit((hybrid-branching-audit)):::skill
    skill_hybrid_branching_rollout_planner((hybrid-branching-rollout-planner)):::skill
    skill_identity_migration((identity-migration)):::skill
    skill_infrastructure_audit((infrastructure-audit)):::skill
    skill_issue_triage((issue-triage)):::skill
    skill_landing_zone_audit((landing-zone-audit)):::skill
    skill_lane_closeout((lane-closeout)):::skill
    skill_lexicon((lexicon)):::skill
    skill_local_dev_data_pack((local-dev-data-pack)):::skill
    skill_manual_test_strategy((manual-test-strategy)):::skill
    skill_mcp_audit((mcp-audit)):::skill
    skill_mcp_development((mcp-development)):::skill
    skill_memory_promoter((memory-promoter)):::skill
    skill_merge_conflict_mediator((merge-conflict-mediator)):::skill
    skill_observability((observability)):::skill
    skill_onboarding_telemetry((onboarding-telemetry)):::skill
    skill_operation_context_resolver((operation-context-resolver)):::skill
    skill_orphaned_pr_triage((orphaned-pr-triage)):::skill
    skill_penetration_testing((penetration-testing)):::skill
    skill_performance_profiling((performance-profiling)):::skill
    skill_production_readiness((production-readiness)):::skill
    skill_project_rules_drift_audit((project-rules-drift-audit)):::skill
    skill_public_safe_sanitization((public-safe-sanitization)):::skill
    skill_queue_rebalancer((queue-rebalancer)):::skill
    skill_rai_privacy_review((rai-privacy-review)):::skill
    skill_rca((rca)):::skill
    skill_receiving_code_review((receiving-code-review)):::skill
    skill_refactoring((refactoring)):::skill
    skill_release_audit((release-audit)):::skill
    skill_release_notes((release-notes)):::skill
    skill_repo_cleanup((repo-cleanup)):::skill
    skill_repo_learning((repo-learning)):::skill
    skill_rollout_basecoat((rollout-basecoat)):::skill
    skill_s4_deployment_checklist((s4-deployment-checklist)):::skill
    skill_s4_rollback_testing((s4-rollback-testing)):::skill
    skill_sdlc_content_pack((sdlc-content-pack)):::skill
    skill_security((security)):::skill
    skill_security_operations((security-operations)):::skill
    skill_service_bus_migration((service-bus-migration)):::skill
    skill_session_analysis((session-analysis)):::skill
    skill_session_optimization((session-optimization)):::skill
    skill_ship_it((ship-it)):::skill
    skill_ship_it_control_loop((ship-it-control-loop)):::skill
    skill_skill_scripts((skill-scripts)):::skill
    skill_sprint_closeout((sprint-closeout)):::skill
    skill_sprint_closeout_audit((sprint-closeout-audit)):::skill
    skill_sprint_management((sprint-management)):::skill
    skill_sprint_planner((sprint-planner)):::skill
    skill_sprint_project_mapper((sprint-project-mapper)):::skill
    skill_sprint_retrospective((sprint-retrospective)):::skill
    skill_standards_mapping((standards-mapping)):::skill
    skill_standup_signal_extraction((standup-signal-extraction)):::skill
    skill_station_bottleneck_analyzer((station-bottleneck-analyzer)):::skill
    skill_supply_chain_security((supply-chain-security)):::skill
    skill_takt_time_measurement((takt-time-measurement)):::skill
    skill_task_decomposition((task-decomposition)):::skill
    skill_task_provenance((task-provenance)):::skill
    skill_tech_debt((tech-debt)):::skill
    skill_twelve_factor((twelve-factor)):::skill
    skill_ux((ux)):::skill
    skill_workflow_parallelization((workflow-parallelization)):::skill
    skill_yagni_analysis((yagni-analysis)):::skill

    %% Edges
    agent_flow_auditor -.-> skill_flow_audit
    agent_flow_auditor -.-> skill_flow_track
    agent_governance_auditor -.-> skill_governance
    agent_governance_auditor -.-> skill_governance_audit
    agent_agentic_sdlc_autonomy -.-> skill_agentic_sdlc_autonomy
    agent_agentic_sdlc_autonomy -.-> skill_ci_audit
    agent_agentic_sdlc_autonomy -.-> skill_flow_audit
    agent_agentic_sdlc_autonomy -.-> skill_flow_admission_control
    agent_agentic_sdlc_autonomy -.-> skill_human_in_the_loop
    agent_governance_author -.-> skill_governance
    agent_governance_author -.-> skill_governance_audit
    agent_ship_it_control_loop -.-> skill_ship_it
    agent_ship_it_control_loop -.-> skill_ship_it_control_loop
    agent_agent_designer -.-> skill_agent_design
    agent_agent_designer -.-> skill_agentops_audit
    agent_project_rules_drift_auditor -.-> skill_project_rules_drift_audit
    agent_project_rules_drift_auditor -.-> skill_governance_audit
    agent_github_security_posture -.-> skill_security
    agent_build_master -.-> skill_build_master_control_plane
    agent_build_master -.-> skill_build_failure_triage
    agent_build_master -.-> skill_escalation_routing
    agent_build_master -.-> skill_dependency_blocker_monitoring
    agent_delivery_autopilot -.-> skill_delivery_autopilot
    agent_ship_it_orchestrator -.-> skill_ship_it
    agent_ship_it_orchestrator -.-> skill_lane_closeout
    agent_flow_governance_conductor -.-> skill_flow_audit
    agent_flow_governance_conductor -.-> skill_flow_suggest
    agent_flow_governance_conductor -.-> skill_flow_optimize
    agent_flow_governance_conductor -.-> skill_flow_track
    agent_flow_governance_conductor -.-> skill_flow_admission_control
    agent_flow_governance_conductor -.-> skill_ci_audit
    agent_flow_governance_conductor -.-> skill_governance_audit
    agent_flow_governance_conductor -.-> skill_agentic_sdlc_autonomy
    agent_orphaned_pr_cleanup -.-> skill_orphaned_pr_triage
    agent_orphaned_pr_cleanup -.-> skill_backlog_revalidation
    agent_guidance_reviewer -.-> skill_agent_design
    agent_guidance_reviewer -.-> skill_agentops_audit
    agent_flow_admission_controller -.-> skill_flow_admission_control
    agent_flow_admission_controller -.-> skill_flow_optimize
    agent_instruction_auditor -.-> skill_agent_design
    agent_local_dev_data_pack_orchestrator -.-> skill_local_dev_data_pack
    agent_incident_to_backlog_router -.-> skill_decision_log_capture
    agent_incident_to_backlog_router -.-> skill_flow_admission_control
    agent_incident_to_backlog_router -.-> skill_observability
    agent_incident_to_backlog_router -.-> skill_security_operations
    agent_incident_to_backlog_router -.-> skill_operation_context_resolver
    agent_delivery_gap_mapper -.-> skill_issue_triage
    agent_delivery_gap_mapper -.-> skill_sprint_project_mapper
    agent_delivery_gap_mapper -.-> skill_flow_audit
    agent_copilot_review_triage -.-> skill_copilot_review_triage
    agent_copilot_review_triage -.-> skill_code_review
    agent_flow_optimizer -.-> skill_flow_optimize
    agent_flow_optimizer -.-> skill_flow_suggest
    agent_flow_optimizer -.-> skill_flow_audit
    agent_issue_triage -.-> skill_issue_triage
    agent_issue_triage -.-> skill_backlog_revalidation
    agent_backlog_autopilot -.-> skill_backlog_burndown
    agent_backlog_autopilot -.-> skill_ship_it_control_loop
    agent_backlog_autopilot -.-> skill_delivery_autopilot
    agent_backlog_autopilot -.-> skill_issue_triage
    agent_backlog_autopilot -.-> skill_workflow_parallelization
    agent_flow_suggester -.-> skill_flow_suggest
    agent_flow_suggester -.-> skill_flow_audit
    agent_flow_tracker -.-> skill_flow_track
    agent_flow_tracker -.-> skill_flow_audit

    classDef agent fill:#4a90d9,color:#fff,stroke:#2c5f8a
    classDef skill fill:#5cb85c,color:#fff,stroke:#3a7a3a
    classDef instr fill:#f0ad4e,color:#fff,stroke:#b07a1e
```

## Orphaned nodes (214 total — no incoming or outgoing edges)

- agent:agentops
- agent:api-designer
- agent:api-security
- agent:app-inventory
- agent:azure-landing-zone
- agent:backend-dev
- agent:backlog-rebalancer
- agent:bom-validator
- agent:branch-hygiene-sweeper
- agent:broken-build-troubleshooter
- agent:change-isolation-architect
- agent:chaos-engineer
- agent:ci-audit
- agent:ci-failure-escalation
- agent:ci-guardrail-accelerator
- agent:code-review
- agent:config-auditor
- agent:Container Security
- agent:containerization-planner
- agent:contract-testing
- agent:daily-standup-facilitator
- agent:Data Integrity
- agent:data-architect
- agent:data-pipeline
- agent:data-tier
- agent:database-migration
- agent:dataops
- agent:definition-of-done
- agent:dependabot-prioritizer
- agent:dependency-blocker-monitor
- agent:dependency-lifecycle
- agent:dependency-update-advisor
- agent:devops-engineer
- agent:domain-designer
- agent:dotnet-modernization-advisor
- agent:e2e-test-strategy
- agent:escalation-router
- agent:exploratory-charter
- agent:factory-conductor
- agent:factory-state-curator
- agent:failure-pattern-process
- agent:feedback-loop
- agent:finops-advisor
- agent:frontend-dev
- agent:gitops-engineer
- agent:guardrail
- agent:guidance-author
- agent:ha-architect
- agent:Hardening Advisor
- agent:identity-architect
- agent:incident-responder
- agent:infrastructure-deploy
- agent:legacy-modernization
- agent:llmops
- agent:manual-test-strategy
- agent:mcp-developer
- agent:memory-curator
- agent:memory-promoter
- agent:merge-coordinator
- agent:middleware-dev
- agent:mlops
- agent:new-customization
- agent:Observability Engineer
- agent:orchestrator
- agent:orchestrator-compat
- agent:parallel-session-coordinator
- agent:penetration-test
- agent:performance-analyst
- agent:policy-as-code-compliance
- agent:product-manager
- agent:production-readiness
- agent:program-bootstrap
- agent:project-onboarding
- agent:prompt-coach
- agent:prompt-engineer
- agent:queue-rebalancer
- agent:rca
- agent:release-freeze-enforcer
- agent:release-impact-advisor
- agent:release-manager
- agent:release-readiness-chair
- agent:replanning-engine
- agent:Resilience Reviewer
- agent:retro-facilitator
- agent:rollout-basecoat
- agent:run-history-cleanup
- agent:s4-shadow-mode-validator
- agent:Secrets Manager
- agent:Security Monitor
- agent:security-analyst
- agent:security-operations
- agent:self-healing-ci
- agent:solution-architect
- agent:sprint-closeout-auditor
- agent:sprint-planner
- agent:sprint-project-mapper
- agent:sprint-retrospective
- agent:sre-engineer
- agent:station-bottleneck-analyzer
- agent:strategy-to-automation
- agent:supply-chain-security
- agent:takt-time-tracker
- agent:task-scope-validator
- agent:tech-writer
- agent:ux-designer
- agent:workflow-gate-diagnostician
- skill:agentic-cost-audit
- skill:api-audit
- skill:api-design
- skill:api-security
- skill:app-inventory
- skill:architecture
- skill:azure-container-apps
- skill:azure-devops-rest
- skill:azure-identity
- skill:azure-identity-audit
- skill:azure-landing-zone
- skill:azure-linux-app-service
- skill:azure-networking
- skill:azure-policy
- skill:azure-policy-audit
- skill:azure-waf-review
- skill:backend-audit
- skill:backend-dev
- skill:backlog-rebalance-engine
- skill:basecoat
- skill:basecoat-help
- skill:bom-schema
- skill:bom-validation
- skill:change-isolation
- skill:ci-cd-diagnostics
- skill:ci-flake-quarantine
- skill:config-secrets-audit
- skill:container-build-assessment
- skill:container-migration
- skill:contract-testing
- skill:copilot-usage-analytics
- skill:cqrs-event-sourcing
- skill:create-instruction
- skill:create-skill
- skill:cross-stack-modernization
- skill:data-tier
- skill:data-tier-audit
- skill:database-migration
- skill:dev-containers
- skill:devops
- skill:devops-audit
- skill:docs-site
- skill:documentation
- skill:domain-driven-design
- skill:dotnet-modernization
- skill:e2e-testing
- skill:electron-apps
- skill:entity-framework-migration
- skill:environment-audit-drift
- skill:environment-bootstrap
- skill:factory-state-machine
- skill:failure-pattern-process
- skill:frontend-audit
- skill:frontend-dev
- skill:git-worktrees
- skill:github-security-posture
- skill:gitops
- skill:ha-resilience
- skill:handoff
- skill:hybrid-branching-audit
- skill:hybrid-branching-rollout-planner
- skill:identity-migration
- skill:infrastructure-audit
- skill:landing-zone-audit
- skill:lexicon
- skill:manual-test-strategy
- skill:mcp-audit
- skill:mcp-development
- skill:memory-promoter
- skill:merge-conflict-mediator
- skill:onboarding-telemetry
- skill:penetration-testing
- skill:performance-profiling
- skill:production-readiness
- skill:public-safe-sanitization
- skill:queue-rebalancer
- skill:rai-privacy-review
- skill:rca
- skill:receiving-code-review
- skill:refactoring
- skill:release-audit
- skill:release-notes
- skill:repo-cleanup
- skill:repo-learning
- skill:rollout-basecoat
- skill:s4-deployment-checklist
- skill:s4-rollback-testing
- skill:sdlc-content-pack
- skill:service-bus-migration
- skill:session-analysis
- skill:session-optimization
- skill:skill-scripts
- skill:sprint-closeout
- skill:sprint-closeout-audit
- skill:sprint-management
- skill:sprint-planner
- skill:sprint-retrospective
- skill:standards-mapping
- skill:standup-signal-extraction
- skill:station-bottleneck-analyzer
- skill:supply-chain-security
- skill:takt-time-measurement
- skill:task-decomposition
- skill:task-provenance
- skill:tech-debt
- skill:twelve-factor
- skill:ux
- skill:yagni-analysis

Graph: 131 agents, 143 skills, 65 edges, 214 orphans
