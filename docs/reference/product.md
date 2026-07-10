# Base Coat — Product Identity

## What is Base Coat?

Base Coat is a full-SDLC Copilot customization framework built on four primitives: agents, skills, instructions, and prompts. It provides specialized assets that cover the entire software development lifecycle — from architecture and coding to testing, security, DevOps, and project management.

## Who is it for?

- **Engineering teams** using GitHub Copilot who want consistent, high-quality AI assistance across all disciplines
- **Platform/DevOps teams** who want to standardize AI agent behavior across their organization
- **Individual developers** who want specialized agents instead of generic AI chat

## Core Principles

1. **Full SDLC coverage** — Not just code generation. Architecture, testing, security, DevOps, docs, and PM too.
2. **One entry point** — `/basecoat` routes to any of 50 agents. No need to memorize agent names.
3. **Opinionated but extensible** — Ships with battle-tested defaults. Every agent, skill, and instruction can be customized.
4. **Framework, not a product** — Base Coat is infrastructure for your agents, not a hosted service.
5. **Governance built in** — Instructions enforce security, quality, and naming standards automatically.

## How it differs from single-domain tools

Tools like Impeccable focus on one discipline (UI/design) with deep expertise. Base Coat covers 6 disciplines with 50 agents:

- 🔨 **Development** (4 agents) — backend, frontend, middleware, data
- 🏗️ **Architecture** (3 agents) — system design, API design, UX
- 🔍 **Quality** (7 agents) — code review, security, performance, testing
- 🚀 **DevOps** (3 agents) — CI/CD, releases, enterprise rollout
- 📋 **Process** (5 agents) — sprint planning, PM, triage, retros
- 🧰 **Meta** (6 agents) — agent design, prompts, MCP, docs

## Architecture

```text
/basecoat (router)
├── agents/        50 agent definitions (.agent.md)
├── skills/        33 skill packages with templates
├── instructions/  34 instruction files (.instructions.md)
├── prompts/       3 reusable prompt files
└── basecoat-metadata.json  (machine-readable registry)
```
