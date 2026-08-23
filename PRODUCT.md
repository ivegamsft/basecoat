# BaseCoat

## Register

product

## Description

BaseCoat is the shared operating layer for governed GitHub Copilot work.

## Users

- Developers and maintainers working in GitHub repositories
- Platform, security, and release teams governing AI-assisted delivery
- Downstream repositories onboarding a reusable Copilot operating model

## Problem

Repositories adopt AI assistance with inconsistent prompts, undocumented
decisions, unclear ownership, and uneven quality or security controls. Teams
then spend turns rediscovering context and reviewing outputs that should have
been governed at the entry point.

## Product Purpose

BaseCoat provides composable agents, skills, instructions, and prompts that
route work through explicit intent, evidence, validation, and approval
boundaries. Success means a downstream repository can adopt a pinned,
discoverable operating model quickly and produce auditable delivery outcomes
without memorizing specialist asset names.

## Brand Personality / Tone

Precise, calm, direct, evidence-led, and operationally useful. BaseCoat should
reduce ambiguity and turns without hiding uncertainty or bypassing approval
boundaries.

## Anti-references

BaseCoat must never resemble:

- An opaque autonomous system that changes repositories without a clear scope
- A generic prompt collection with no routing or validation contract
- A replacement for human judgment in critical decisions
- A visual design layer that overwrites a repository's product identity

## Design Principles

1. **One clear entry point:** users can start with an intent prefix or discover
   the right asset without memorizing the catalog.
2. **Guardrails plus visibility:** instructions govern execution while issues,
   pull requests, and workflow runs make state auditable.
3. **Evidence before action:** inventory, plans, and preflight checks precede
   write-capable work.
4. **Preserve local ownership:** downstream repositories own their product,
   brand, and design decisions; BaseCoat supplies the operating contract.
5. **Fail closed:** ambiguity, missing evidence, and unmet approvals remain
   visible and block side effects.
6. **Composable distribution:** agents, skills, instructions, and prompts can
   be adopted, pinned, refreshed, and customized independently.

## Accessibility & Inclusion

All downstream design and documentation work must preserve accessible,
keyboard-operable, inclusive experiences. Prefer plain language, explicit
labels, sufficient contrast, semantic structure, and evidence for accessibility
requirements rather than aesthetic assumptions.

## Boundaries

BaseCoat is not a hosted SaaS product, runtime dependency, product-specific
design system, or substitute for a downstream repository's product definition.
It does not decide a downstream product's brand, users, pricing, or visual
identity without repository-owned evidence and approval.

## Stack

- [AI SDLC operating model](docs/reference/ai-sdlc-operating-model.md)
- [Downstream prompt catalog](docs/guides/downstream-prompt-catalog.md)
- [Intent prefixes](docs/guides/intent-prefixes.md)
- [Design debate format](docs/reference/design-debate-format.md)
- [Agents](agents/)
- [Skills](skills/)
- [Instructions](instructions/)
- [Prompts](prompts/)
