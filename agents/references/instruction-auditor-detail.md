# Instruction Auditor Agent — Detail Reference

Full mapping tables and output examples for `agents/basecoat-50-security-instruction-auditor.agent.md`.

## Tech Stack Signal Detection

Scan the repo for the following indicator files and map them to tech stacks:

| Indicator file(s) | Detected stack |
|---|---|
| `package.json`, `.nvmrc` | Node.js |
| `pom.xml`, `build.gradle` | Java / Spring Boot or J2EE |
| `Gemfile` | Ruby on Rails |
| `requirements.txt`, `manage.py`, `pyproject.toml` | Python (data science or Django) |
| `*.csproj`, `*.sln` | .NET |
| `Dockerfile`, `docker-compose.yml` | Containers |
| `*.tf`, `*.tfvars` | Terraform |
| `*.bicep` | Azure Bicep |
| `.github/workflows/*.yml` | CI/CD (check for Azure deploy actions) |
| `ejb-jar.xml`, `persistence.xml`, `*.war` | J2EE / Jakarta EE |

For Python repos, inspect dependencies to distinguish stacks:

- If `django` appears in `requirements.txt` or `pyproject.toml` → Django
- Otherwise → Python (data science / general)

For Node.js repos, inspect dependencies and application scripts:

- If `express` appears in `package.json` → Node.js / Express
- If frontend framework dependencies or build scripts appear → Node.js / frontend
- Otherwise → Node.js (general)

For Java repos, inspect for J2EE markers:

- If `ejb-jar.xml`, `persistence.xml`, or `*.war` are present → J2EE / Jakarta EE
- If `pom.xml` or `build.gradle` reference Spring → Java / Spring Boot

## Mapping Signals to Canonical Instruction Files

| Detected stack | Expected instruction file |
|---|---|
| Node.js / Express | No stack-specific canonical instruction; use `basecoat-10-core-backend.instructions.md` |
| Node.js / frontend | No stack-specific canonical instruction; use `basecoat-10-core-development.instructions.md` |
| Node.js (general) | No stack-specific canonical instruction; use `basecoat-10-core-development.instructions.md` |
| Java / Spring Boot | `basecoat-20-lang-java-spring-boot.instructions.md` |
| J2EE / Jakarta EE | `basecoat-10-core-j2ee-jakarta-ee.instructions.md` |
| Ruby on Rails | `basecoat-20-lang-ruby-on-rails.instructions.md` |
| Python + Django | `basecoat-20-lang-django.instructions.md` |
| Python (general) | `basecoat-20-lang-python.instructions.md` |
| .NET | No general canonical instruction; select an applicable `basecoat-20-lang-dotnet-*.instructions.md` asset |
| Containers | No container-specific canonical instruction; use `basecoat-10-core-development.instructions.md` |
| Terraform | `basecoat-10-core-terraform.instructions.md` |
| Azure Bicep | `basecoat-10-core-bicep.instructions.md` |
| CI/CD (Azure deploy) | No Azure DevOps-specific canonical instruction; use `basecoat-60-workflow-workflow-integrity.instructions.md` |

Assign a status to each mapping:

- `[PRESENT]` — the expected file exists in the overlay
- `[MISSING]` — the expected file is absent from the overlay
- `[PARTIAL]` — a related file exists but does not exactly match the canonical name

## Coverage Report Examples

**Markdown example:**

```markdown
## Instruction Coverage Report

| Tech Stack | Expected File | Status |
|---|---|---|
| Node.js / Express | `basecoat-10-core-backend.instructions.md` | [PRESENT] |
| Java / Spring Boot | `basecoat-20-lang-java-spring-boot.instructions.md` | [MISSING] |
| Azure Bicep | `basecoat-10-core-bicep.instructions.md` | [PARTIAL] |

**Summary:** 1 of 3 stacks covered. 1 missing, 1 partial.
```

**JSON example:**

```json
{
  "summary": { "total": 3, "covered": 1, "missing": 1, "partial": 1 },
  "stacks": [
    { "stack": "Node.js / Express", "expected": "basecoat-10-core-backend.instructions.md", "status": "present" },
    { "stack": "Java / Spring Boot", "expected": "basecoat-20-lang-java-spring-boot.instructions.md", "status": "missing" },
    { "stack": "Azure Bicep", "expected": "basecoat-10-core-bicep.instructions.md", "status": "partial" }
  ]
}
```

## Recommending Synchronization for Missing Files

For each Missing entry, list the files that a full overlay synchronization will add.
Resolve the consumer's configured sync entrypoint first. If no custom entrypoint is
configured, use the repository-root `sync.ps1` on Windows or `sync.sh` on Unix-like
systems; do not advertise unsupported selective-sync parameters.

```powershell
pwsh ./sync.ps1
```

Group the missing files and the one supported synchronization command together at the
end of the report for easy copy-paste.

## Full Markdown Output Example

```markdown
## Instruction Coverage Report — acme-corp/widget-api

Overlay path: `.github/base-coat/instructions`
Scanned: 2025-07-01

| Tech Stack | Expected File | Status |
|---|---|---|
| Node.js / Express | `basecoat-10-core-backend.instructions.md` | [PRESENT] |
| Java / Spring Boot | `basecoat-20-lang-java-spring-boot.instructions.md` | [MISSING] |
| Azure Bicep | `basecoat-10-core-bicep.instructions.md` | [MISSING] |
| CI/CD (Azure deploy) | `basecoat-60-workflow-workflow-integrity.instructions.md` | [PARTIAL] |

**Summary:** 1 of 4 stacks covered — 2 missing, 1 partial.

### Recommended Synchronization

The following files will be added by a full overlay synchronization:

- `instructions/basecoat-20-lang-java-spring-boot.instructions.md`
- `instructions/basecoat-10-core-bicep.instructions.md`

Run the configured sync entrypoint, or from the repository root:

pwsh ./sync.ps1
```
