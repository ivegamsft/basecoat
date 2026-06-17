---
name: container-build-assessment
description: "Assess Docker build readiness with composable scripts that analyze Dockerfile structure, inspect dependency footprint, estimate image size, and report security posture in structured JSON suitable for automation and remediation planning."
compatibility: [github-copilot-cli]
scripts:
  - name: analyze-dockerfile
    description: "Parse Dockerfile structure and detect common build issues."
    entrypoint: scripts/analyze-dockerfile.ps1
    inputs:
      - name: DockerfilePath
compatibility:
  - GHCP
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
