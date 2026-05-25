---
name: container-build-assessment
description: "Assess Docker build readiness with composable scripts that analyze Dockerfile structure, inspect dependency footprint, estimate image size, and report security posture in structured JSON suitable for automation and remediation planning."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: DevOps
  tags: [container, docker, assessment]
  maturity: beta
  audience: [devops, backend, platform-engineers]
allowed-tools: [bash, powershell]
scripts:
  - name: analyze-dockerfile
    description: "Parse Dockerfile structure and detect common build issues."
    entrypoint: scripts/analyze-dockerfile.ps1
    inputs:
      - name: DockerfilePath
        type: string
  - name: scan-dependencies
    description: "Inspect dependency files and estimate dependency footprint."
    entrypoint: scripts/scan-dependencies.ps1
    inputs:
      - name: AppRoot
        type: string
  - name: estimate-build-size
    description: "Estimate final image size and optimization opportunities."
    entrypoint: scripts/estimate-build-size.ps1
    inputs:
      - name: analysis
        type: json
  - name: security-check
    description: "Check Dockerfile security posture and risk indicators."
    entrypoint: scripts/security-check.ps1
    inputs:
      - name: DockerfilePath
        type: string
---

# Container Build Assessment

This skill runs four scripts in order to produce a structured container build assessment.

## Usage

Run all steps:

```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -DockerfilePath ./Dockerfile `
  -AppRoot .
```

Run one step:

```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -Step analyze-dockerfile `
  -DockerfilePath ./Dockerfile
```

## Output

The orchestrator returns step-by-step JSON plus a final consolidated result.
