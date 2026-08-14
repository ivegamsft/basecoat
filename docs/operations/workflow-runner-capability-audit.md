# Workflow Runner Capability Audit

| Metric | Value |
|---|---|
| Workflows scanned | 84 |
| Jobs classified | 118 |
| Mismatches | 0 |
| Conditional routes | 0 |
| Unclassified jobs | 0 |
| Contracted jobs | 13 |
| Contract violations | 0 |

| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | Status |
|---|---|---|---|---|---|
| ab-experiment.yml | run-experiment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| adoption-metrics.yml | collect | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | guardrails | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | rollback-plan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | rollback-apply | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| aidl-incident-routing-verification.yml | incident-routing | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| aidl-memory-hygiene-sweep.yml | memory-hygiene | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| aidl-portfolio-rollup-kpi-publisher.yml | rollup | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| asset-health.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| audit-environment-drift.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| auto-approve-cloud-agent-workflows.yml | auto-approve-workflows | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| auto-enlist.yml | enlist | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| automation-stuck-state-watchdog.yml | watchdog | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| behavioral-eval.yml | evaluate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| branch-protection-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| check-basecoat-version-callable.yml | check-version | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ci.yml | lint-and-validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ci.yml | test | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| close-production-issues.yml | close-issues | public-api-dispatch, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| cross-repo-sync-validation.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-canary.yml | plan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-canary.yml | canary | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-graph-pages.yml | graph | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| dependency-relationship-routing.yml | route | public-internet, untrusted-fork-safe | github-hosted-linux | github-hosted-linux | aligned |
| dependency-update-advisor.yml | advise | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs-link-checker.yml | link-check | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs-production.yml | dispatch-production-docs | public-api-dispatch, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs.yml | verify-github-pages-environment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs.yml | deploy | deployment-credentials, oidc, public-internet, public-pages-deploy | github-hosted-linux | github-hosted-linux | aligned |
| downstream-reviewer-routing-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | bootstrap-prod-environment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | verify-prod-environment-protection | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | verify-staging-environment-protection | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | summary | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| environment-protection-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| extension-deploy.yml | build-push | deployment-credentials, public-internet, public-registry-publish | github-hosted-linux | github-hosted-linux | aligned |
| extension-deploy.yml | deploy | credential-auth, deployment-credentials, public-cloud-deploy, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| extension-intent-routing-eval.yml | extension-intent-routing-eval | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| fork-import.yml | import | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| governance-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| governance-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| harness-change-eval-gate.yml | harness-change-eval-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| harness-change-eval-gate.yml | run-harness-eval | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-approve.yml | route-pr-approve | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-approve.yml | approve | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-field-sync.yml | sync-fields | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-metadata-hygiene.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-to-spec-synthesis.yml | synthesize-spec | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| keep-fix-throttle-weekly-scorecard.yml | generate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| mcp-build.yml | build | public-build, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| mcp-deploy.yml | build-push | deployment-credentials, public-internet, public-registry-publish | github-hosted-linux | github-hosted-linux | aligned |
| mcp-deploy.yml | deploy | credential-auth, deployment-credentials, public-cloud-deploy, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-contribute.yml | contribute | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-contribution-issue.yml | process | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-sweep.yml | sweep | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| model-capability-refresh.yml | refresh | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| operation-context-resolver.yml | validate-and-report | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| package-basecoat.yml | validate | delegated-runner, public-internet | reusable-workflow | reusable-workflow | aligned |
| package-basecoat.yml | package | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| package-basecoat.yml | release | deployment-credentials, public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| portal-deploy.yml | deploy | credential-auth, deployment-credentials, oidc, public-cloud-deploy, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | frontend-tests | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | backend-tests | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | app-backend-build | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | app-dashboard-build | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| post-merge-release-chain.yml | chain | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| post-onboarding-drift-loop.yml | drift-loop | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-auto-merge-executor.yml | evaluate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-auto-merge-executor.yml | merge | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-flow-hygiene.yml | hygiene | public-internet, untrusted-fork-safe | github-hosted-linux | github-hosted-linux | aligned |
| pr-size-labeler.yml | label | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | main-branch-protection-readiness | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | release-label-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | markdown-lint | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | gitleaks-scan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | validate-agent-files | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | sync-dry-run | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| prd-spec-gate.yml | prd-spec-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| project-rules-drift-audit.yml | drift-audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| publish-to-production.yml | preflight-token-check | delegated-runner, deployment-credentials, public-internet | reusable-workflow | reusable-workflow | aligned |
| publish-to-production.yml | publish | deployment-credentials, public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| release-changelog-generation.yml | generate | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| release-train.yml | orchestrate-release-train | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| release.yml | production-token-preflight | delegated-runner, deployment-credentials, public-internet | reusable-workflow | reusable-workflow | aligned |
| release.yml | release | deployment-credentials, public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| repo-health-check.yml | health | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| reviewer-autoassign.yml | assign | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| runner-health-observability.yml | runner-health | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| secret-scan.yml | gitleaks | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-build-guard.yml | resolve-inputs | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-build-guard.yml | detect-and-recover | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-intent-dispatch.yml | resolve-intent | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-intent-dispatch.yml | dispatch-intent | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-release-gate.yml | evaluate-ship-it-gate | public-ci, public-internet | github-hosted-linux | github-hosted-linux | aligned |
| skill-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| skill-coverage-report.yml | coverage | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| smoke-test.yml | smoke-test | multi-os-matrix, public-internet, windows-runtime | github-hosted-matrix | github-hosted-matrix | aligned |
| sprint-closeout-branch-audit.yml | branch-audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| stale-management.yml | stale-sweep | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| submit-learning-callable.yml | submit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| sync-test.yml | sync-consumer-test | multi-os-matrix, public-internet, windows-runtime | github-hosted-matrix | github-hosted-matrix | aligned |
| terraform-deploy.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| terraform-deploy.yml | plan-dev | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| terraform-deploy.yml | plan-prod | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| token-inventory.yml | regenerate-inventory | public-internet, public-release-publish | github-hosted-linux | github-hosted-linux | aligned |
| token-preflight.yml | validate-token-configured | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| token-preflight.yml | verify-push-access | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| validate-basecoat.yml | validate-workflow-syntax | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| validate-basecoat.yml | validate-commit-messages | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| validate-basecoat.yml | validate-unix | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| validate-basecoat.yml | validate-windows | public-internet, windows-runtime | github-hosted-windows | github-hosted-windows | aligned |
| validate-operation-context.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| validate-repo-template-sample.yml | validate-sample-template | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| version-check.yml | version-consistency | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| workflow-runner-capability-audit.yml | runner-capability-audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
