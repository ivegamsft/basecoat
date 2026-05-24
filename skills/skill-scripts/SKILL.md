---
name: skill-scripts
description: "Use when augmenting a skill with executable scripts that can be chained together. Enables skills to run assessment scripts, process outputs, and feed results to subsequent steps instead of completing as single monolithic prompts. Declare script steps in skill frontmatter with input/output contracts."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  domain: framework
  maturity: beta
  audience: [all]
allowed-tools: [bash, powershell, git]
---

# Skill Scripts — Composable Execution Steps

Skills can declare executable scripts that run in sequence, passing outputs from one step to the next. This enables:

- **Assessments** → structured data (schema analysis, diagnostics, metrics)
- **Planning** → takes assessment output, produces recommendations
- **Validation** → takes plan output, verifies correctness
- **Execution** → takes validation output, applies changes

Instead of one prompt handling all steps, each runs as a script with clear contracts.

## Frontmatter Schema

Add a `scripts` section to your skill's YAML frontmatter:

```yaml
---
name: database-migration
description: "Assess, plan, validate, and execute database migrations..."
scripts:
  - name: assess-schema
    description: "Analyze source database schema and constraints"
    entrypoint: scripts/assess-schema.ps1
    inputs: []
    outputs:
      - format: json
        schema: |
          {
            "tables": [...],
            "constraints": [...],
            "estimatedSize": "..."
          }
  
  - name: generate-plan
    description: "Create migration plan from assessment"
    entrypoint: scripts/generate-migration-plan.ps1
    inputs:
      - name: assessment
        format: json
        description: "Output from assess-schema step"
    outputs:
      - format: json
        schema: |
          {
            "steps": [...],
            "estimatedDuration": "...",
            "risks": [...]
          }
  
  - name: validate
    description: "Validate plan correctness"
    entrypoint: scripts/validate-migration.ps1
    inputs:
      - name: plan
        format: json
        description: "Output from generate-plan step"
    outputs:
      - format: json
        schema: |
          {
            "valid": true,
            "warnings": [],
            "approved": true
          }
---
```

## Execution Flow

```
User runs: /skill database-migration --source-db prod --target-db postgres

Orchestrator:
  1. assess-schema.ps1 --source-db prod
     → outputs: assessment.json
  
  2. generate-migration-plan.ps1 --assessment assessment.json
     → outputs: plan.json
  
  3. validate-migration.ps1 --plan plan.json
     → outputs: validation.json
  
  4. Return combined results to user
```

## Implementation: Orchestrator Script

Create `scripts/orchestrate-skill-scripts.ps1`:

```powershell
param(
    [string]$SkillPath,           # Path to SKILL.md
    [string]$WorkingDir,          # Temp directory for outputs
    [hashtable]$InitialInputs     # {"--source-db" = "prod", ...}
)

# 1. Parse SKILL.md frontmatter → extract scripts[] array
$yaml = Read-SkillFrontmatter -Path $SkillPath
$scriptSteps = $yaml.scripts

# 2. For each step, run entrypoint script
$previousOutput = $null
foreach ($step in $scriptSteps) {
    Write-Host "Running step: $($step.name)..."
    
    $scriptPath = Join-Path (Split-Path $SkillPath) $step.entrypoint
    
    # Build command with previous output
    $cmd = @($scriptPath)
    if ($step.inputs) {
        foreach ($input in $step.inputs) {
            if ($input.name -eq "assessment" -and $previousOutput) {
                $cmd += "--$($input.name)"
                $cmd += $previousOutput
            }
        }
    }
    $cmd += $InitialInputs.GetEnumerator() | ForEach-Object { @("--$($_.Key)", $_.Value) } | % { $_ }
    
    # Execute and capture output
    $output = & $cmd | ConvertFrom-Json
    $previousOutput = $output | ConvertTo-Json -Compress
    
    # Validate against output schema
    Validate-OutputSchema -Output $output -Schema $step.outputs[0].schema
    
    # Save intermediate result
    $step.name + ".json" | Out-File (Join-Path $WorkingDir $_)
}

# 3. Return final combined result
return @{
    steps = @(1..($scriptSteps.Count) | % { Get-Content (Join-Path $WorkingDir "$($scriptSteps[$_-1].name).json") | ConvertFrom-Json })
    finalOutput = $previousOutput | ConvertFrom-Json
}
```

## Example: Create a Database Migration Skill

### 1. Create folder
```
skills/database-migration/
  ├── SKILL.md
  ├── scripts/
  │   ├── assess-schema.ps1
  │   ├── generate-migration-plan.ps1
  │   └── validate-migration.ps1
  └── examples/
      └── migration-plan.json
```

### 2. Write SKILL.md with scripts metadata
```yaml
---
name: database-migration
description: "Migrate on-premises MSSQL/MySQL to PostgreSQL. Assesses schema, generates plan, validates, then executes."
scripts:
  - name: assess-schema
    entrypoint: scripts/assess-schema.ps1
    inputs: []
    outputs:
      - format: json
  - name: generate-plan
    entrypoint: scripts/generate-migration-plan.ps1
    inputs:
      - name: assessment
        format: json
---

## Workflow

1. **Assess** — analyze source schema, constraints, size, complexity
2. **Plan** — create step-by-step migration strategy
3. **Validate** — test plan for conflicts, risks, downtimes
4. **Execute** — (optional) apply changes if approved
```

### 3. Write assess-schema.ps1
```powershell
param([string]$SourceDb)

$schema = @{
    tables = @("orders", "customers", "payments")
    constraints = @("PK", "FK", "CHECK")
    estimatedSize = "2.3 GB"
}

$schema | ConvertTo-Json
```

### 4. Write generate-migration-plan.ps1
```powershell
param([string]$Assessment)

$assess = $Assessment | ConvertFrom-Json

$plan = @{
    steps = @(
        "Create target PostgreSQL database"
        "Migrate schemas: $($assess.tables -join ', ')"
        "Migrate data (~$($assess.estimatedSize))"
        "Validate constraints"
        "Run tests"
    )
    estimatedDuration = "4 hours"
    risks = @("Downtime during final cutover")
}

$plan | ConvertTo-Json
```

## Usage

```bash
# List available skill scripts
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/database-migration/SKILL.md `
  -List

# Run all steps
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/database-migration/SKILL.md `
  -SourceDb prod `
  -TargetDb postgres-prod

# Run single step
./scripts/orchestrate-skill-scripts.ps1 `
  -SkillPath skills/database-migration/SKILL.md `
  -Step assess-schema `
  -SourceDb prod
```

## Benefits

| Benefit | Example |
|---------|---------|
| **Composability** | Reuse assess-schema.ps1 across multiple skills |
| **Debuggability** | Run one step at a time, inspect intermediate outputs |
| **Scalability** | Add more steps without rewriting entire skill |
| **Testability** | Unit test each script independently |
| **Observability** | Each step produces timestamped outputs for audit trail |
| **Parallelization** | Independent steps could run in parallel (future) |

## Validation

When a skill declares scripts:

1. Validate YAML frontmatter `scripts` syntax
2. Verify all `entrypoint` files exist and are executable
3. Check `inputs` names match previous step `outputs`
4. Validate `outputs.schema` is valid JSON Schema
5. Run smoke test: execute first step with mock inputs

Add to `scripts/validate-basecoat.ps1`:
```powershell
if ($skill.scripts) {
    foreach ($step in $skill.scripts) {
        if (-not (Test-Path $step.entrypoint)) {
            throw "Script not found: $($step.entrypoint)"
        }
    }
}
```

## Next Steps

1. Implement `orchestrate-skill-scripts.ps1` orchestrator
2. Add `scripts` schema to YAML frontmatter validation
3. Update skill template to include optional `scripts` section
4. Create 2-3 example skills using scripts (database migration, container building, testing)
5. Document in CONTRIBUTING.md
