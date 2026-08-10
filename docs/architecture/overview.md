# Architecture Overview

BaseCoat is a **distributed Copilot customization library** — assets are authored centrally
and synced into consumer repositories, where GitHub Copilot picks them up automatically.

## System Context

```mermaid
C4Context
    title BaseCoat — System Context

    Person(dev, "Developer", "Uses GitHub Copilot in VS Code or GitHub.com")
    Person(contributor, "Contributor", "Adds patterns to BaseCoat")

    System(bc, "BaseCoat", "Enterprise Copilot customization library: agents, skills, instructions, prompts")
    System_Ext(copilot, "GitHub Copilot", "AI coding assistant")
    System_Ext(cr, "Consumer Repo", "Team's application repository")
    System_Ext(mem, "BaseCoat Memory", "example-org/basecoat-memory: curated patterns")

    Rel(dev, copilot, "Uses")
    Rel(copilot, cr, "Reads assets from")
    Rel(cr, bc, "Syncs from", "sync.ps1 / sync.sh")
    Rel(contributor, bc, "Submits PR / memory contribution")
    Rel(bc, mem, "Promotes learnings to")
    Rel(mem, bc, "Informs asset updates")
```

## Asset Taxonomy

BaseCoat assets are organized into four types, each with a specific role in shaping Copilot's behavior:

| Type | Count | Role | Location |
|---|---|---|---|
| **Agents** | 79 | End-to-end task executors with defined inputs, workflow, and output | `agents/*.agent.md` |
| **Skills** | 57 | Reusable domain capabilities invoked by agents | `skills/*/SKILL.md` |
| **Instructions** | 64 | Copilot behavior rules applied by file path pattern | `instructions/*.instructions.md` |
| **Prompts** | 3 | Structured templates for repeatable tasks | `prompts/*.prompt.md` |

```mermaid
flowchart TD
    BC["BaseCoat Assets"] --> A["Agents\n79 files\nagents/*.agent.md"]
    BC --> S["Skills\n57 directories\nskills/*/SKILL.md"]
    BC --> I["Instructions\n64 files\ninstructions/*.instructions.md"]
    BC --> P["Prompts\n3 files\nprompts/*.prompt.md"]

    A --> A1["Legacy Modernization"]
    A --> A2["Self-Healing CI"]
    A --> A3["Memory Promoter"]
    A --> A4["Issue Triage"]
    A --> A5["...75 more"]

    S --> S1["azure-linux-app-service"]
    S --> S2["cross-stack-modernization"]
    S --> S3["database-migration"]
    S --> S4["...54 more"]

    I --> I1["workflow-integrity"]
    I --> I2["governance"]
    I --> I3["python"]
    I --> I4["...61 more"]
```

## Consumer Sync Lifecycle

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant CR as Consumer Repo
    participant BC as BaseCoat (public mirror)
    participant CP as GitHub Copilot

    Dev->>CR: git clone / open repo
    CR->>BC: sync.ps1 / sync.sh (initial or update)
    BC-->>CR: .github/base-coat/ (raw synced assets — staging area)
    Note over CR: sync script distributes assets to Copilot-readable locations
    CR-->>CR: .github/agents/ (agent files)
    CR-->>CR: .github/instructions/ (instruction files)
    CR-->>CR: .github/prompts/ (prompt templates)
    CR-->>CR: .github/skills/ (skill manifests)
    CP-->>Dev: Copilot reads agents, instructions, prompts & skills

    loop Weekly drift check
        CR->>BC: check-basecoat-version-callable.yml
        BC-->>CR: latest version tag
        alt stale
            CR->>Dev: Opens upgrade issue
        end
    end
```

## Memory Contribution Flow

Patterns discovered in sessions can be promoted to long-term BaseCoat memory via the
memory-promoter agent:

```mermaid
flowchart LR
    S["Session\n(Copilot CLI)"] -->|memory-promoter agent| C["Contribution\nPayload"]
    C -->|submit-learning-callable.yml| MR["Memory Repo\nbasecoat-memory"]
    MR -->|quarterly review| BC["BaseCoat\nAsset Update"]
    D["detect-repeat-fixes.ps1"] -->|high-frequency patterns| C
```

## Key Design Decisions

- **[ADR-001 — Naming Convention](decisions/adr-001-naming-convention.md)**: Why `basecoat`
  (repo) and `base-coat` (artifact) coexist
- **Distributed sync model**: Assets live in consumer repos — no runtime dependency on BaseCoat
- **Quality gate**: CI blocks merges if avg asset score < 5.0/10 or any asset scores 0
- **Idempotent drift detection**: Version check workflow updates existing issues rather than
  opening duplicates

## Repository Structure

```text
basecoat/
├── agents/          # 79 agent definition files
├── skills/          # 57 skill directories
├── instructions/    # 64 instruction files
├── prompts/         # 3 prompt templates
├── scripts/         # Sync, audit, coherence, adoption scripts
├── tests/           # Validation and quality gate tests
├── docs/            # This documentation
├── mcp/             # MCP server exposing metrics to AI agents
└── .github/
    └── workflows/   # CI, release, deploy, drift detection
```
