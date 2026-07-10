# {{bundle_id}} Diagram Template

## Usage

Use this template to describe the workflow path, control points, and handoff
boundaries for a single SDLC content bundle.

## Context

- SDLC phase: {{sdlc_phase}}
- Audience: {{audience}}
- Maturity: {{maturity}}
- Domain overlay: {{domain_overlay}}
- Constraints: {{constraints}}

## Workflow Summary

{{workflow_summary}}

## Workflow Diagram

```mermaid
flowchart TD
    A[{{step_1}}] --> B[{{step_2}}]
    B --> C[{{step_3}}]
    C --> D[{{step_4}}]
    D --> E[{{step_5}}]
```

## Decision Points

- {{decision_point_1}}
- {{decision_point_2}}

## Handoff Notes

- Entry signal: {{entry_signal}}
- Exit signal: {{exit_signal}}
- Owner handoff: {{handoff_summary}}

## Source References

{{source_refs}}
