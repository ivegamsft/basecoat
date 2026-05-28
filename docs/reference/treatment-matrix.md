# Treatment Matrix — Legacy Application Disposition

Use this matrix after running the App Inventory Agent. Match an application's complexity score
and strategic value to the recommended treatment path. Each path maps to a set of Base Coat
basecoat-10-core-agents and skills.

## Decision Framework

```text
                        Strategic Value
                   Low          Medium         High
                ┌────────────┬────────────┬────────────┐
           Low  │  Retire     │  Rehost    │  Replatform│
Complexity      ├────────────┼────────────┼────────────┤
  Score    Mid  │  Retire     │  Replatform│  Refactor  │
                ├────────────┼────────────┼────────────┤
           High │  Replace    │  Refactor  │  Rebuild   │
                └────────────┴────────────┴────────────┘
```

Strategic value is rated Low / Medium / High based on business criticality, active user base,
revenue contribution, and regulatory obligation.

## Treatment Paths

### Retire

Stop investing in the application and plan decommission.

**Criteria**

- Complexity score < 40 AND strategic value: Low
- No active users in the past 90 days
- Functionality already covered by another system

**Actions**

1. Communicate sunset timeline to stakeholders
2. Archive source code and database snapshots
3. Redirect dependent systems to replacement
4. Remove from load balancer and DNS
5. Decommission infrastructure

**Base Coat agents**: `basecoat-10-core-product-manager`, `basecoat-10-core-devops-engineer`

---

### Rehost (Lift and Shift)

Move the application to a new infrastructure platform with no code changes.

**Criteria**

- Complexity score 1–40 AND strategic value: Medium
- Application is stable with low change frequency
- Primary driver is infrastructure cost or EOL OS/hardware

**Actions**

1. Containerize the application binary (no source change)
2. Deploy to basecoat-40-azure-azure Container Apps or AKS
3. Migrate database to PaaS (basecoat-40-azure-azure SQL, Cosmos DB)
4. Update DNS and connection strings
5. Validate with smoke tests

**Base Coat agents**: `basecoat-30-ai-containerization-planner`, `basecoat-10-core-devops-engineer`
**Base Coat skills**: `azure-container-apps`, `devops`

---

### Replatform (Lift, Tinker, and Shift)

Make targeted platform changes while preserving application architecture.

**Criteria**

- Complexity score 1–40 AND strategic value: High
- Complexity score 21–60 AND strategic value: Medium
- Main goal is taking advantage of managed services (PaaS database, managed identity)

**Actions**

1. Replace self-managed dependencies with managed equivalents
2. Adopt managed identity — remove hardcoded credentials
3. Externalise basecoat-10-core-config via basecoat-40-azure-azure App Configuration / Key Vault
4. Update framework to a supported LTS version
5. Run existing test suite to validate parity

**Base Coat agents**: `basecoat-10-core-legacy-modernization`, `basecoat-50-security-config-auditor`, `basecoat-10-core-devops-engineer`
**Base Coat skills**: `identity-migration`, `environment-bootstrap`

---

### Refactor (Re-architect)

Redesign the internal structure without changing external behavior.

**Criteria**

- Complexity score 41–80 AND strategic value: Medium or High
- Application has high business value but significant technical debt
- Target state is microservices or modular basecoat-10-core-monolith

**Actions**

1. Run App Inventory to produce full dependency and complexity report
2. Apply strangler fig pattern to extract high-value modules
3. Introduce API gateway in front of legacy core
4. Extract services incrementally per sprint wave
5. Replace legacy service bus / messaging with basecoat-40-azure-azure Service Bus
6. Migrate authentication to ASP.NET Core Identity + Entra ID

**Base Coat agents**: `basecoat-10-core-legacy-modernization`, `basecoat-10-core-solution-architect`, `basecoat-10-core-backend-dev`
**Base Coat skills**: `service-bus-migration`, `identity-migration`, `basecoat-10-core-architecture`

---

### Rebuild

Rewrite the application from scratch using modern patterns, retaining business logic.

**Criteria**

- Complexity score 61–100 AND strategic value: High
- Codebase is unmaintainable or framework is no longer supportable
- Business logic is well-understood and can be respecified

**Actions**

1. Extract business rules via the App Inventory Agent
2. Author PRD and technical spec (`docs/prd-and-spec-guidance.md`)
3. Design new basecoat-10-core-architecture (C4 model, ADRs)
4. Build greenfield service with parity acceptance tests
5. Run old and new systems in parallel with traffic mirroring
6. Perform cutover and retire legacy system

**Base Coat agents**: `basecoat-10-core-solution-architect`, `basecoat-10-core-backend-dev`, `basecoat-10-core-frontend-dev`, `basecoat-10-core-product-manager`
**Base Coat skills**: `basecoat-10-core-architecture`, `basecoat-10-core-backend-dev`, `basecoat-10-core-frontend-dev`

---

### Replace

Adopt a commercial or open-source product instead of maintaining custom code.

**Criteria**

- Complexity score > 60 AND strategic value: Low or Medium
- COTS solution covers ≥ 80 % of required functionality
- Total cost of ownership favors commercial product

**Actions**

1. Document current feature set and integration points (App Inventory output)
2. Evaluate vendor options against requirement matrix
3. Plan data migration and integration adapters
4. Run parallel operation period
5. Decommission custom application

**Base Coat agents**: `basecoat-10-core-product-manager`, `basecoat-10-core-solution-architect`

---

## Scoring Sheet

Use this worksheet alongside `skills/app-inventory/complexity-scoring-template.md`.

| Application | Complexity Score | Strategic Value | Treatment |
|-------------|-----------------|-----------------|-----------|
| (name) | (1–100) | Low / Medium / High | Retire / Rehost / Replatform / Refactor / Rebuild / Replace |

## basecoat-20-lang-governance

- Complexity score and treatment path must be recorded in the ADR log for each application.
- Scores above 60 require basecoat-10-core-solution-architect sign-off before treatment selection is finalised.
- Treatment paths that result in Retire or Replace require basecoat-10-core-product-manager approval.
- Review the treatment matrix annually or after major portfolio changes.
