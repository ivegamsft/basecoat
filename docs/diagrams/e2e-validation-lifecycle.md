# E2E Validation Lifecycle and Gate Flow

Visual reference for end-to-end verification requirements, decision flow, and outcomes.

---

## 1. Validation Gate Funnel

```mermaid
graph TD
    A["Change Detected<br/>(code, UX, auth, integration)"] --> B{Lint Pass?}
    B -->|No| B1["Fix Linting Errors"]
    B1 --> B
    B -->|Yes| C{Build Success?}
    C -->|No| C1["Fix Build Errors"]
    C1 --> C
    C -->|Yes| D{Typecheck Pass?}
    D -->|No| D1["Fix Type Errors"]
    D1 --> D
    D -->|Yes| E{Requires E2E?<br/>Runtime/UX/Auth/Integration}
    
    E -->|No| F["Gate Passes<br/>Ready to Merge"]
    
    E -->|Yes| G{Env Preconditions Met?}
    G -->|No| G1["Setup Auth Mode<br/>Configure Services<br/>Verify Base URL"]
    G1 --> G
    
    G -->|Yes| H["Run E2E Suite<br/>Against Affected Flows"]
    
    H --> I{All Tests Pass?}
    I -->|No| I1["Debug & Fix"]
    I1 --> H
    I -->|Yes| F
    
    style A fill:#e1f5ff
    style F fill:#c8e6c9
    style I1 fill:#ffccbc
    style G1 fill:#fff9c4

---

## 2. E2E Pass/Fail Branching

```mermaid
graph TD
    A["E2E Test Results"] --> B{All Tests Pass?}
    
    B -->|Yes| C["Promotion Decision"]
    C --> C1{Confidence High?<br/>Coverage Strong?}
    C1 -->|Yes| D["Promote to Main<br/>Update GA Policy"]
    C1 -->|No| E["Promote with Warnings<br/>Schedule Follow-up"]
    
    B -->|No| F["Failure Triage"]
    F --> G{Failure Type?}
    
    G -->|Flaky Test<br/>Intermittent| H["Quarantine Test<br/>File Investigation"]
    H --> H1["Update Test Stability Docs<br/>Plan Hardening Sprint"]
    
    G -->|Code Defect<br/>Real Issue| I["Rollback Changes<br/>File Bug"]
    I --> I1["Root Cause Analysis<br/>Fix and Re-test"]
    
    G -->|Environment<br/>Infrastructure| J["Escalate to Ops<br/>Block Merge"]
    J --> J1["Fix Infrastructure<br/>Re-run E2E"]
    
    G -->|Test Data<br/>Scope Issue| K["Review Test Scope<br/>Adjust Coverage"]
    
    D --> L["Merge Ready"]
    E --> L
    H1 --> M["Add to Backlog<br/>Later Merge"]
    I1 --> L
    J1 --> L
    K --> L
    
    style A fill:#e1f5ff
    style L fill:#c8e6c9
    style I fill:#ffccbc
    style J fill:#f8bbd0

---

## 3. Test Scope Map

```mermaid
graph TD
    A["Change Type"] --> B{Decision Tree}
    
    B -->|Runtime/Behavior| C["Critical Path Tests"]
    C --> C1["Happy path user flows<br/>Authentication<br/>Data persistence<br/>Integration boundaries"]
    C1 --> C2["Required E2E Coverage"]
    C2 --> C3["Min Coverage: 80%<br/>All gates must pass"]
    
    B -->|UX/UI| D["Critical + Regression"]
    D --> D1["Layout & interactions<br/>Accessibility<br/>Browser compatibility<br/>Responsive design"]
    D1 --> D2["Required E2E Coverage"]
    D2 --> D3["Min Coverage: 85%<br/>All gates must pass"]
    
    B -->|Internal/Infra| E["Smoke + Targeted"]
    E --> E1["System health checks<br/>API contract validation<br/>CI/CD correctness"]
    E1 --> E2["Conditional E2E"]
    E2 --> E3["Gates waived if<br/>isolated to infra"]
    
    B -->|Documentation Only| F["No E2E Required"]
    F --> F1["Lint/Build/Typecheck<br/>Gate passes"]
    
    B -->|Bug Fix (Non-Critical)| G["Regression + Root Cause"]
    G --> G1["Verify the fix<br/>Prevent recurrence<br/>Browser matrix if UX"]
    G1 --> G2["Required E2E"]
    G2 --> G3["Min Coverage: 60%<br/>Specific to bug"]
    
    style C2 fill:#c8e6c9
    style D2 fill:#c8e6c9
    style E2 fill:#fff9c4
    style F fill:#e0e0e0
    style G2 fill:#c8e6c9
