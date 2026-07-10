# .NET Modernization Decision Tree

Use this guide to pick the right modernization path for a .NET codebase.

## Start

Is the current runtime out of support or blocked by security/compliance requirements?

- **Yes** -> prioritize accelerated migration planning.
- **No** -> continue with standard modernization assessment.

## Architecture and coupling

Are critical services tightly coupled to Windows-only APIs, legacy IIS modules, or unsupported libraries?

- **Yes** -> choose incremental/strangler migration and isolate risky boundaries first.
- **No** -> evaluate in-place upgrade path by solution.

## Dependency posture

Do required packages have modern .NET compatible versions?

- **Mostly yes** -> plan staged framework upgrade by project groups.
- **No for key dependencies** -> choose replace-or-replatform track before broad upgrade.

## Data layer

Is the application dependent on legacy EF patterns or EF6-specific behavior?

- **Yes** -> include `entity-framework-migration` skill and schedule data-layer refactor wave.
- **No** -> proceed with standard app/service migration waves.

## Testing confidence

Is there sufficient automated coverage for critical paths?

- **Yes** -> proceed with phased execution and strict CI gates.
- **No** -> add baseline test hardening before migration of high-risk components.

## Recommended outputs

- Chosen migration strategy and rationale
- Ordered wave plan with gates and rollback criteria
- Dependency remediation backlog
- Test matrix and acceptance criteria
