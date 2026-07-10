# Release Notes Validation Report

Generated: 2026-05-31 19:58:46-04:00
Repository: https://ibuyspy@github.com/ivegamsft/basecoat

## v3.30.0 (v3.29.0..v3.30.0)

- PRs in window: 1
- Waves: N/A
- Sprints: N/A
- Binding status: Needs confirmation

### Highlights
- refactor: standardize BaseCoat-prefixed naming for agents and instructions (PR #1297)

### Fixes and improvements
- None identified

## v3.29.0 (v3.28.2..v3.29.0)

- PRs in window: 4
- Waves: N/A
- Sprints: N/A
- Binding status: Needs confirmation

### Highlights
- feat(skills): add audit skill siblings for code review

Add six new audit skills for reviewing generated or implemented output:
- backend-audit: Review backend code, testing, performance, security
- api-audit: Review API design, contracts, error handling
- devops-audit: Review CI/CD pipelines and deployment configs
- infrastructure-audit: Review IaC (Bicep/Terraform) and networking
- mcp-audit: Review MCP server implementations and schemas
- agentops-audit: Review agent definitions and routing

Each skill includes focused review criteria, concrete checklists, and validation-oriented output.

Closes #1279, #1281, #1282, #1283, #1284, #1285 (PR #1296)

### Fixes and improvements
- feat(skills): add audit skill siblings for code review

Add six new audit skills for reviewing generated or implemented output:
- backend-audit: Review backend code, testing, performance, security
- api-audit: Review API design, contracts, error handling
- devops-audit: Review CI/CD pipelines and deployment configs
- infrastructure-audit: Review IaC (Bicep/Terraform) and networking
- mcp-audit: Review MCP server implementations and schemas
- agentops-audit: Review agent definitions and routing

Each skill includes focused review criteria, concrete checklists, and validation-oriented output.

Closes #1279, #1281, #1282, #1283, #1284, #1285 (PR #1296)
- fix: sanitize exported custom-agent frontmatter in sync/bootstrap (PR #1294)
- fix(workflows): harden deploy auth and infra bootstrap (PR #1275)

## v3.28.2 (v3.28.1..v3.28.2)

- PRs in window: 41
- Waves: N/A
- Sprints: N/A
- Binding status: Needs confirmation

### Highlights
- feat(guardrails): deployment RCA guardrails and deploy/rca intent prefixes (PR #1261)
- feat(intent): add fleet shortcut routing (PR #1256)
- feat: automate sprint closeout branch audit (#1157) (PR #1249)
- feat: composable skill scripts and triage workflow hardening (PR #1214)
- feat(skills): composable script execution framework - hardening fix (PR #1203)

### Fixes and improvements
- fix: update stale dates in sprint artifacts (#1209) (PR #1272)
- fix: Pin GitHub Actions to full 40-char commit SHAs (PR #1270)
- fix(workflow): make token inventory PR step policy-resilient (PR #1267)
- fix(intent-routing): replace missing skill refs in Prefix-to-Skill Routing table (PR #1263)
- fix(intent): enforce feature:/bug: prefix contract (PR #1262)
