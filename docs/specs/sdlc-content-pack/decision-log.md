# SDLC Content Pack Generator - Decision Log

## Overview

This document captures key design decisions, tradeoffs, and non-goals for the
SDLC Content Pack Generator skill. It explains the rationale behind architectural
choices and defines what the skill does not address.

## Design Decisions

### Decision 1: Markdown-First Architecture

**Decision**: Use markdown as the system of record for all generated artifacts.

**Rationale**:

- Markdown is version-control-friendly and easily reviewable in pull requests
- No binary dependencies required for the initial release
- Content can be easily adapted, edited, and extended by downstream teams
- Enables asynchronous review and approval workflows
- Supports both human editing and downstream automation

**Tradeoff**:

- No direct export to PowerPoint, video formats, or binary assets in this release
- Teams must use secondary tools (e.g., Excalidraw for diagrams, video editing software)
  to convert markdown to final deliverables

**Alternative Considered**:

- Direct binary rendering: Would simplify end-user experience but add complexity,
  dependencies, and maintenance burden to the orchestration layer

### Decision 2: Template-Driven Generation

**Decision**: Use template substitution with simple parameter injection rather than
AI-driven content generation.

**Rationale**:

- Ensures consistency and predictability across bundles
- Keeps orchestration logic simple and auditable
- Reduces non-deterministic behavior and cost variance
- Makes it easier for teams to customize and extend templates

**Tradeoff**:

- Templates require careful design and regular updates
- Customization requires template editing rather than prompt engineering
- Each domain overlay may need its own template variations

**Alternative Considered**:

- LLM-driven generation: Would provide flexibility but add cost, latency, and
  non-determinism. Better revisited once this baseline is proven.

### Decision 3: Strict Consistency Model

**Decision**: Enforce one canonical step list across all four artifacts (diagram,
click-through, video script, deck).

**Rationale**:

- Eliminates drift between artifacts that confuses downstream teams
- Makes bundle quality easier to validate and score
- Simplifies human review by providing a clear reference list
- Enables predictable tracing from source to each artifact

**Tradeoff**:

- Limits the flexibility to tell different stories for different audiences
- Requires explicit audience framing within each artifact rather than audience-specific
  story variations
- More rigid change process if source workflow changes mid-bundle

**Alternative Considered**:

- Audience-specific artifacts: Would allow tailored narratives but would complicate
  consistency checks and human review. Better revisited as an extension after
  baseline stability is proven.

### Decision 4: Four Artifact Types as Standard

**Decision**: Define the bundle as always containing exactly four artifacts:
diagram, click-through, video script, and deck.

**Rationale**:

- Covers the most common downstream use cases (architecture review, onboarding,
  demo, decision making)
- Simplifies the contract and reduces conditional logic
- Makes quality gates and rubrics easier to define

**Tradeoff**:

- Not every use case needs all four artifacts
- May require teams to filter or repackage bundles for specific consumption

**Alternative Considered**:

- À la carte artifact selection: Would provide flexibility but complicate
  consistency enforcement and downstream tooling

### Decision 5: Simple Export Package Structure

**Decision**: Export each bundle as a flat folder containing all artifacts plus
manifest and quality report.

**Rationale**:

- Flat structure is easy to inspect and version
- Compatible with standard version control workflows
- Simplifies downstream automation and integration
- No database or complex metadata required

**Tradeoff**:

- Doesn't scale well if bundles become very large or nested
- Requires discipline to avoid artifact naming collisions across domains
- May require post-processing for custom organizational structures

### Decision 6: PowerShell for Initial Orchestration

**Decision**: Use PowerShell for the bundle generation orchestrator.

**Rationale**:

- Matches the primary scripting environment for basecoat infrastructure
- Simple, readable orchestration without heavy dependencies
- Easy to extend and debug for downstream teams
- Compatible with GitHub Actions and Windows environments

**Tradeoff**:

- Non-Windows environments require `pwsh` (PowerShell Core) to be available
- PowerShell expertise required for customization

**Alternative Considered**:

- Python or JavaScript: Would provide better cross-platform support but would
  add complexity and break pattern consistency with existing basecoat scripting

### Decision 7: Manual Review as Part of Release Path

**Decision**: Require human review and approval before bundles are considered
production-ready.

**Rationale**:

- Ensures terminology accuracy and workflow correctness
- Captures domain expertise that automated checks cannot validate
- Provides a gate for compliance, legal, or governance checks
- Supports adoption confidence in downstream teams

**Tradeoff**:

- Adds latency to the bundle generation workflow
- Requires skilled reviewers with domain knowledge
- Cannot be fully automated in first release

**Alternative Considered**:

- Fully automated generation: Faster time-to-value but higher risk of
  inaccuracy and incomplete governance

## Non-Goals

### What This Skill Does NOT Do

1. **Automated Media Rendering**
   - No direct conversion to PowerPoint, video files, or image exports
   - Expected to be a future enhancement after baseline stabilizes

2. **Live Dashboards or Interactive Experiences**
   - No web UI for bundle preview or real-time generation
   - Not a replacement for documentation sites or wikis

3. **Audience-Specific Story Variations**
   - Each audience sees the same workflow steps and narrative spine
   - Framing and emphasis differ, but the story does not
   - Future extension after baseline proves value

4. **Multi-Language Support**
   - Initial release is English-only
   - Localization framework can be added once metadata structure is stable

5. **Integration with External Systems**
   - No direct export to Jira, Azure DevOps, or other platforms
   - Can be added as post-processing steps

6. **Workflow Inference from Unstructured Data**
   - Requires explicit, well-structured input from bundle owner
   - Does not attempt to reverse-engineer workflows from scattered documentation

7. **Historical Versioning of Bundles**
   - Bundles are point-in-time artifacts
   - Change history managed through source control, not built-in versioning

## Extensibility Model

### Domain Overlays

Domain overlays extend the baseline without changing the core contract. Each
overlay is designed to be additive:

- **Security overlay**: Adds security terminology, threat model cues, and review
  checklist items without changing the workflow steps
- **Compliance overlay**: Adds audit trail expectations, control names, and
  governance gates
- **Platform overlay**: Adds platform-specific terminology (e.g., Kubernetes,
  Azure, AWS) and resource references
- **Data overlay**: Adds data classification labels, retention policies, and
  handling instructions

Each overlay is:

- Optional and independent
- Implemented as metadata, not template forking
- Composable with other overlays
- Non-breaking to the baseline contract

## Future Extensions

These areas are explicitly deferred for future sprints:

1. **Binary rendering pipeline**: Convert markdown to PowerPoint, PDF, and video
2. **AI-driven personalization**: Use models to adapt narratives for specific
   audiences or domains
3. **Bundle composition**: Combine multiple bundles into larger artifact sets
4. **Integration connectors**: Export to Jira, Azure DevOps, and other platforms
5. **Interactive preview**: Web UI for reviewing and editing bundles before
   publishing
6. **Multilingual templates**: Support for non-English content generation

## Acceptance of Tradeoffs

The team accepts these tradeoffs in favor of:

1. **Simplicity**: Easier for downstream teams to understand, customize, and extend
2. **Auditability**: Clear, version-controlled assets that can be reviewed and approved
3. **Cost control**: No dependency on external services or expensive AI inference
4. **Reliability**: Deterministic generation that produces the same output for the
   same input
5. **Time-to-value**: Faster initial release to gather pilot feedback

If future use cases require different tradeoffs, this skill can evolve, and new
specialized skills can be created for specific domains or media formats.

## Review and Sign-Off

- **Approved by**: Architecture review (PR #1956)
- **Date**: Sprint 35 closeout
- **Review scope**: Design decisions, extension model, and non-goals
- **Next review**: Post-pilot feedback from downstream teams (Sprint 39)
