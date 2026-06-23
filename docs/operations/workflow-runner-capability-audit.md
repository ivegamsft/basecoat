# Workflow Runner Capability Audit

| Metric | Value |
|---|---|
| Workflows scanned | 69 |
| Jobs classified | 100 |
| Mismatches | 7 |
| Conditional routes | 6 |
| Unclassified jobs | 0 |
| Contracted jobs | 6 |
| Contract violations | 0 |

| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | Status |
|---|---|---|---|---|---|
| ab-experiment.yml | run-experiment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| adoption-metrics.yml | collect | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | guardrails | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | rollback-plan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| agent-merge.yml | rollback-apply | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| asset-health.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| audit-environment-drift.yml | audit | managed-identity, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| auto-approve-cloud-agent-workflows.yml | auto-approve-workflows | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| auto-enlist.yml | enlist | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| behavioral-eval.yml | evaluate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| branch-protection-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| check-basecoat-version-callable.yml | check-version | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ci.yml | lint-and-validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ci.yml | test | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| close-production-issues.yml | close-issues | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| cross-repo-sync-validation.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-canary.yml | plan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-canary.yml | canary | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-graph-pages.yml | graph | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| dependency-relationship-routing.yml | route | public-internet, untrusted-fork-safe | github-hosted-linux | github-hosted-linux | aligned |
| dependency-update-advisor.yml | advise | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs-link-checker.yml | link-check | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs-production.yml | dispatch-production-docs | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| docs.yml | validate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs.yml | verify-github-pages-environment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| docs.yml | deploy | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| downstream-reviewer-routing-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | bootstrap-prod-environment | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | verify-prod-environment-protection | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | verify-staging-environment-protection | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| enforce-protection.yml | summary | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| environment-protection-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| extension-deploy.yml | build-push | deployment-credentials, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| extension-deploy.yml | deploy | deployment-credentials, managed-identity, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| extension-intent-routing-eval.yml | extension-intent-routing-eval | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| fork-import.yml | import | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| governance-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| governance-enforce.yml | enforce | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| harness-change-eval-gate.yml | harness-change-eval-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| harness-change-eval-gate.yml | run-harness-eval | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-approve.yml | approve | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| issue-metadata-hygiene.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| mcp-build.yml | build | managed-identity, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| mcp-deploy.yml | build-push | deployment-credentials, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| mcp-deploy.yml | deploy | deployment-credentials, managed-identity, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| memory-audit.yml | audit | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-contribute.yml | contribute | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-contribution-issue.yml | process | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| memory-sweep.yml | sweep | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| operation-context-resolver.yml | validate-and-report | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| package-basecoat.yml | validate | delegated-runner, private-network, public-internet | reusable-workflow | reusable-workflow | aligned |
| package-basecoat.yml | package | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| package-basecoat.yml | release | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| portal-deploy.yml | deploy | deployment-credentials, managed-identity, private-network, public-internet | self-hosted-linux | configurable-deploy | conditional |
| portal-tests.yml | frontend-tests | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | backend-tests | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | app-backend-build | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| portal-tests.yml | app-dashboard-build | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| post-onboarding-drift-loop.yml | drift-loop | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-flow-hygiene.yml | hygiene | public-internet, untrusted-fork-safe | github-hosted-linux | github-hosted-linux | aligned |
| pr-size-labeler.yml | label | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | main-branch-protection-readiness | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | release-label-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | markdown-lint | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | gitleaks-scan | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | validate-agent-files | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| pr-validation.yml | sync-dry-run | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| prd-spec-gate.yml | prd-spec-gate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| publish-to-production.yml | preflight-token-check | delegated-runner, deployment-credentials, private-network, public-internet | reusable-workflow | reusable-workflow | aligned |
| publish-to-production.yml | publish | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| release-changelog-generation.yml | generate | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| release.yml | production-token-preflight | delegated-runner, deployment-credentials, private-network, public-internet | reusable-workflow | reusable-workflow | aligned |
| release.yml | release | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | mismatch |
| repo-health-check.yml | health | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| reviewer-autoassign.yml | assign | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| secret-scan.yml | gitleaks | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-intent-dispatch.yml | resolve-intent | public-internet | github-hosted-linux | github-hosted-linux | aligned |
| ship-it-intent-dispatch.yml | dispatch-intent | public-internet | github-hosted-linux | github-hosted-linux | aligned |
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
| token-inventory.yml | regenerate-inventory | public-internet | github-hosted-linux | github-hosted-linux | aligned |
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

## Mismatch Details

| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | runs-on |
|---|---|---|---|---|---|
| audit-environment-drift.yml | audit | managed-identity, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| close-production-issues.yml | close-issues | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| docs-production.yml | dispatch-production-docs | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| docs.yml | deploy | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| package-basecoat.yml | release | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| publish-to-production.yml | publish | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
| release.yml | release | deployment-credentials, private-network, public-internet | self-hosted-linux | github-hosted-linux | ubuntu-latest |
