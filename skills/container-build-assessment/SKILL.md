---
name: container-build-assessment
description: "Assess application for containerization readiness. Analyzes Dockerfile, dependencies, build size, layer efficiency, and security posture. Produces structured assessment JSON suitable for planning optimization."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "DevOps"
  tags: ["container", "docker", "assessment", "optimization"]
  maturity: beta
  audience: [devops, backend, platform-engineers]
allowed-tools: [bash, powershell]
scripts:
  - name: analyze-dockerfile
    description: "Parse Dockerfile, extract layers, analyze commands, detect issues"
    entrypoint: scripts/analyze-dockerfile.ps1
    inputs:
      - name: dockerfile_path
        type: string
    outputs:
      - format: json
        schema: |
          {
            "layers": [
              {
                "order": 1,
                "command": "FROM node:18",
                "size": null,
                "issues": []
              }
            ],
            "totalLayers": 0,
            "baseImage": "node:18",
            "issues": ["multi-stage build not used", "no .dockerignore"]
          }
  
  - name: scan-dependencies
    description: "Scan for outdated/vulnerable dependencies, lock files, size"
    entrypoint: scripts/scan-dependencies.ps1
    inputs:
      - name: app_root
        type: string
    outputs:
      - format: json
        schema: |
          {
            "packageManager": "npm",
            "totalDependencies": 250,
            "outdated": 12,
            "vulnerable": 3,
            "lockFileExists": true,
            "estimatedNodeModulesSize": "450 MB"
          }
  
  - name: estimate-build-size
    description: "Estimate final image size based on Dockerfile and dependencies"
    entrypoint: scripts/estimate-build-size.ps1
    inputs:
      - name: analysis
        type: json
        description: "Combined output from previous steps"
    outputs:
      - format: json
        schema: |
          {
            "baseImageSize": "940 MB",
            "dependenciesSize": "450 MB",
            "applicationCodeSize": "2 MB",
            "estimatedFinalSize": "1.39 GB",
            "optimizationOpportunities": [
              "Use node:18-alpine instead of full image (saves ~800 MB)"
            ]
          }
  
  - name: security-check
    description: "Check for security issues: secrets, non-root user, latest tags"
    entrypoint: scripts/security-check.ps1
    inputs:
      - name: dockerfile_path
        type: string
    outputs:
      - format: json
        schema: |
          {
            "runsAsRoot": true,
            "containsSecrets": false,
            "usesLatestTags": true,
            "hasHealthCheck": false,
            "issues": [
              {
                "severity": "high",
                "issue": "Container runs as root user",
                "fix": "Add: USER nonroot"
              }
            ]
          }
---

# Container Build Assessment

Analyze application for containerization readiness. This skill breaks down assessment into
discrete steps: analyze Dockerfile structure, scan dependencies, estimate image size, and
check security posture. Each step produces structured output suitable for building an
optimization plan.

## Workflow

1. **Analyze Dockerfile** — Parse structure, identify layer count, base image, issues
2. **Scan Dependencies** — Detect package manager, count dependencies, check for vulnerabilities
3. **Estimate Build Size** — Calculate final image size, identify optimization opportunities
4. **Security Check** — Verify non-root user, check for secrets, validate tags

Each step saves its output as JSON, and final results are combined for comprehensive assessment.

## Usage

### Run All Steps
```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -dockerfile_path ./Dockerfile `
  -app_root .
```

### Run Single Step
```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -Step analyze-dockerfile `
  -dockerfile_path ./Dockerfile
```

### Get JSON Output
```powershell
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/container-build-assessment/SKILL.md `
  -dockerfile_path ./Dockerfile `
  -Raw | ConvertFrom-Json
```

## Benefits

- **Composable**: Reuse individual assessment scripts (e.g., security-check) in multiple skills
- **Debuggable**: Run one step at a time, inspect intermediate JSON outputs
- **Testable**: Unit test each script independently before orchestration
- **CI/CD Friendly**: Parse JSON results in pipelines, create automated alerts
- **Observable**: Each step produces timestamped output for audit trails

## Example Output

```json
{
  "skill": "container-build-assessment",
  "totalSteps": 4,
  "completedSteps": 4,
  "results": [
    {
      "name": "analyze-dockerfile",
      "status": "success",
      "output": {
        "layers": [...],
        "issues": ["multi-stage build not used"]
      }
    },
    {
      "name": "scan-dependencies",
      "status": "success",
      "output": {
        "totalDependencies": 250,
        "vulnerable": 3
      }
    },
    ...
  ],
  "finalOutput": {
    "baseImageSize": "940 MB",
    "estimatedFinalSize": "1.39 GB",
    "optimizationOpportunities": [...]
  }
}
```

## Next Steps

After assessment, use results to:
1. Generate Dockerfile optimization recommendations
2. Create GitHub issue with security fixes
3. Build multi-stage build strategy
4. Plan image size reduction roadmap
