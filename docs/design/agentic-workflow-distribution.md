<!-- markdownlint-disable MD009 MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->

## Agentic Workflow Distribution & Consumer Agent SDK Strategy

### Executive Summary

This design document addresses issue #1305: evaluating distribution strategy for compiled agentic workflows (.lock.yml files) and architecture for consumer agent deployments. The document proposes a three-phase approach:

1. **Phase 1 (Immediate)**: Distribute pre-compiled .lock.yml workflows as reference implementations with metadata
2. **Phase 2 (Short-term)**: Develop a Consumer Agent SDK pattern for enterprise teams to build custom agents
3. **Phase 3 (Medium-term)**: Build self-service templates and runtime for distributed agent deployment

---

## Current State Assessment

### BaseCoat Agentic Workflows (6 compiled workflows)

| Workflow | Trigger | Runtime | Status |
|----------|---------|---------|--------|
| code-review-agent | PR opened/synchronized | 20 min | Stable |
| issue-triage | Issue opened | Variable | Stable |
| release-impact-advisor | PR opened | Variable | Stable |
| security-analyst | Scheduled/manual | Variable | Stable |
| self-healing-ci | Workflow run failed | Variable | Stable |
| retro-facilitator | Weekly schedule | Variable | Stable |

**Distribution Status**: All 6 workflows are compiled to `.lock.yml` and committed to `.github/workflows/`. Source `.md` files are also committed. Only `.lock.yml` files are truly distributable runtime artifacts.

### MCP Server Availability Model (Current)

**In-Repo MCP Servers** (committed to `mcp/`):
- `basecoat-extension`: GitHub API wrapper with custom agents
- `basecoat-metrics`: Adoption metrics and monitoring

**Public/Third-party MCP Servers** (external dependencies):
- `github-mcp-server`: GitHub API (ghcr.io/github/github-mcp-server:v1.0.4)
- `gh-aw-mcpg`: Agent graph and tool introspection

**Status**: GitHub is actively shipping public MCP servers; BaseCoat can reference them once available via npm/registry.

---

## Design Decisions

### Decision 1: Distribution Strategy

**Recommendation: Hybrid Model (Lock.yml + Source + SDK)**

#### Option 1a: Distribute Pre-Compiled .lock.yml Only ❌
- **Pros**: Immutable runtime artifacts, no compilation overhead
- **Cons**: Consumers cannot customize; tightly couples to gh-aw version; no source transparency

#### Option 1b: Distribute Source .md Only ❌
- **Pros**: Full transparency; consumers can adapt; no version fragmentation
- **Cons**: Compilation burden on consumers; missing gh-aw extension knowledge; security verification harder

#### Option 1c: Hybrid (Both .md + .lock.yml + SDK) ✅ **RECOMMENDED**
- **Approach**:
  - Release compiled `.lock.yml` files as reference implementations (immutable)
  - Include source `.md` files for transparency and as customization templates
  - Provide Consumer Agent SDK with scaffolding and validation tooling
  - Publish as GitHub releases and/or npm package
- **Benefits**:
  - Consumers can "copy & paste" .lock.yml for immediate value
  - Source files allow education and adaptation
  - SDK reduces time-to-value for custom agents
  - Clear separation: reference vs. customizable

---

### Decision 2: Consumer Agent SDK Pattern

**Recommendation: "BaseCoat SDK" npm package + documentation**

#### SDK Goals

1. **Scaffolding**: Template generator for custom agentic workflows
2. **Validation**: Frontmatter schema, security rules, best practices linter
3. **Compilation**: Thin wrapper around `gh aw compile` with BaseCoat conventions
4. **MCP Integration**: Discovery and binding of BaseCoat MCP servers
5. **Testing**: Behavioral eval harness for consumer agents (reference BaseCoat patterns)

#### SDK Structure

```text
@basecoat/agent-sdk
├── bin/
│   ├── init           # Create new agent/workflow project
│   ├── validate       # Lint agent .md files against schema
│   ├── compile        # Compile .md → .lock.yml with BaseCoat rules
│   └── test-harness   # Run behavioral eval against sample inputs
├── templates/
│   ├── agent.md       # Agent template (example: code review, triage)
│   ├── workflow.md    # Agentic workflow template
│   ├── instruction.md # Instruction template
│   └── skill.md       # Skill template
├── config/
│   ├── frontmatter-schema.json
│   ├── mcp-registry.json      # Reference MCP servers
│   └── basecoat-rules.json    # Linting rules
├── lib/
│   ├── validator.ts   # Frontmatter + content validation
│   ├── compiler.ts    # gh-aw wrapper + BaseCoat rules
│   ├── test-runner.ts # Behavioral eval runner
│   └── mcp-discovery.ts  # MCP server binding
└── docs/
    ├── QUICK_START.md
    ├── ARCHITECTURE.md
    ├── MCP_INTEGRATION.md
    └── TESTING_GUIDE.md
```

#### MCP Server Discovery

**Consumer SDK MCP Registry** (in config/mcp-registry.json):

```json
{
  "servers": [
    {
      "name": "github-mcp-server",
      "publisher": "GitHub",
      "version": "1.0.4",
      "channel": "docker",
      "image": "ghcr.io/github/github-mcp-server:v1.0.4",
      "tools": ["search_code", "get_issue", "create_pr", "..."],
      "requires": ["GITHUB_TOKEN"]
    },
    {
      "name": "basecoat-extension",
      "publisher": "BaseCoat",
      "version": "1.0.0",
      "channel": "npm",
      "package": "@basecoat/extension-mcp",
      "tools": ["get_agent_by_id", "get_skill", "find_instruction"],
      "requires": []
    }
  ]
}
```

Consumers can extend or override this registry to add custom MCP servers.

---

### Decision 3: Distribution Channels

**Recommendation: Multi-channel release**

| Channel | Content | Audience | Update Cadence |
|---------|---------|----------|-----------------|
| GitHub Releases | `.lock.yml` + `.md` + SDK npm package | All consumers | Quarterly (aligned with BaseCoat releases) |
| npm (`@basecoat/workflows`) | Pre-compiled workflows as JSON | Node.js / CI environments | Quarterly |
| npm (`@basecoat/agent-sdk`) | CLI tool + SDK library + templates | Agent developers | Quarterly |
| GitHub Pages docs | Interactive workflow browser + SDK guide | All consumers | Continuous (mirrors main) |

---

### Decision 4: Consumer Agent Runtime Architecture

**Recommendation: GitHub Actions native (no new runtime required)**

#### Design Principles

1. **No new runtime**: Leverage existing GitHub Actions + gh-aw runtime
2. **Enterprise-friendly**: Works with air-gapped repos, no external dependencies
3. **Incremental adoption**: Works standalone or as part of larger agentic system
4. **Clear evolution path**: Foundation for future distributed agent platform

#### Consumer Agent Deployment Pattern

```text
Consumer Enterprise Repo
├── .github/
│   ├── workflows/
│   │   ├── custom-triage.md               # Consumer's custom agent
│   │   ├── custom-triage.lock.yml         # Compiled version
│   │   └── basecoat-security-analyst.lock.yml  # Reference agent (imported)
│   └── scripts/
│       └── setup-agents.sh                # SDK init script
├── .basecoat/
│   ├── mcp-registry.json                  # Consumer's MCP overrides
│   └── agent-config.json                  # Agent customization
├── .copilot/
│   ├── instructions/                      # Org-level instructions
│   ├── skills/                            # Org-level skills
│   └── prompts/                           # Org-level prompts
└── README.md
```

**Setup Flow**:

```bash
# 1. Initialize consumer repo with SDK
npx @basecoat/agent-sdk init --repo-type enterprise

# 2. Import reference workflow (optional, reference only)
gh aw import github://IBuySpy-Shared/basecoat/code-review-agent

# 3. Create custom workflow
gh aw new custom-triage

# 4. Validate against BaseCoat schema
npx @basecoat/agent-sdk validate

# 5. Compile and test
gh aw compile && npx @basecoat/agent-sdk test-harness

# 6. Commit and deploy
git add . && git commit -m "feat: add custom triage agent"
git push origin main
```

---

### Decision 5: Integration with Related Initiatives

#### Impact on Issue #1304: Memory Workflows Distribution

**Status**: Defer detailed memory workflow templatization until Phase 2

**Reasoning**:
- Memory workflows (`memory-audit.yml`, `memory-contribute.yml`, etc.) are **internal operational workflows**, not consumer-facing agent workflows
- They depend on BaseCoat-specific infrastructure (basecoat-memory repo, adoption metrics, org structure)
- Templatization effort is higher; value to consumers is lower
- **Recommendation**: Mark as "Internal-only, not distributable" for Phase 1; revisit in Phase 3 if consumer demand emerges

**Decision**: Consumer agent SDK will NOT include memory workflow templates in Phase 1. Can be added later if needed.

#### Impact on Issue #1303: CI/CD Templatization

**Status**: Integrate CI/CD workflow validation into Consumer Agent SDK

**Reasoning**:
- CI/CD workflows (`validate-basecoat.yml`, `pr-validation.yml`, `ci.yml`) are NOT agentic workflows; they're infrastructure
- However, Consumer Agent SDK needs to validate that `.lock.yml` workflows follow BaseCoat CI/CD conventions
- Reusable patterns: validation script abstraction, PR validation checks, test harness integration

**Decision**: 
- Consumer Agent SDK will provide **CI/CD integration templates** (e.g., validate-agents.yml, test-agents.yml) in Phase 1
- Templatization of BaseCoat's CI/CD workflows is a separate Phase 3 initiative (lower priority)

---

### Decision 6: Security & Trust Model

**Recommendation: Multi-layer trust architecture**

#### Layer 1: Source Code Review
- All workflows published in GitHub releases are code-reviewed by BaseCoat maintainers
- Signed commits (GitHub verified badge)
- Threat detection gates (agent-side secret detection)

#### Layer 2: MCP Server Provenance
- All MCP servers reference official container images (sha256 pinned)
- No unsigned or third-party MCP servers in default registry
- Consumers can extend registry at their own risk

#### Layer 3: Behavioral Sandboxing
- Agentic workflows run in GitHub Actions with minimal permissions
- Read-only agent job with write-only safe-outputs
- All outputs audited for secrets/policy violations

#### Layer 4: Consumer-side Verification
- SDK includes `verify-workflow` command (checksum, GPG signature validation)
- Behavioral eval harness allows dry-run testing before deployment

---

## Implementation Roadmap

### Phase 1: Foundation (2-3 weeks)

**Deliverables**:
1. Package existing 6 workflows as npm release
   - `@basecoat/workflows@1.0.0` (pre-compiled .lock.yml + .md)
   - GitHub release with checksums and GPG signatures
2. Create `@basecoat/agent-sdk` package (MVP)
   - `init` command (scaffold new agent)
   - `validate` command (frontmatter + content linting)
   - Templates for custom agents
3. Documentation
   - Quick-start guide for consumer agents
   - MCP server discovery guide
   - Customization patterns (real examples)
4. Integration points
   - Document how to import BaseCoat workflows
   - Show how to extend MCP registry

**Success Criteria**:
- Consumer can run `npx @basecoat/agent-sdk init` and have working custom agent in <10 min
- BaseCoat workflows can be imported and customized without modification
- All 6 reference workflows tested and documented

### Phase 2: Developer Experience (3-4 weeks)

**Deliverables**:
1. Enhance `@basecoat/agent-sdk`
   - `compile` command (gh-aw wrapper with BaseCoat rules)
   - `test-harness` command (behavioral eval runner)
   - `verify-workflow` command (signature/checksum validation)
2. MCP Integration
   - Auto-discovery of installed MCP servers
   - MCP registry management CLI
   - Binding validation (required tools present)
3. Behavioral Eval for Consumer Agents
   - Reuse BaseCoat eval harness patterns
   - Sample test cases per workflow type
   - CI/CD integration template (GitHub Actions)

**Success Criteria**:
- Consumer can test custom agent with `npx @basecoat/agent-sdk test-harness` before deployment
- MCP server misconfigurations caught early
- Developer documentation complete with tutorials

### Phase 3: Distributed Platform (4-6 weeks)

**Deliverables**:
1. Consumer Agent Registry (optional marketplace)
   - Hub for sharing consumer-built agents (opt-in)
   - Versioning and backward compatibility tracking
2. Self-healing Workflows for Consumer Agents
   - Monitoring of deployed agents
   - Automated rollback on failures
   - Health dashboards
3. Memory Workflow Templates (if demand emerges)
   - Parameterized versions of memory-audit, memory-contribute
   - Consumer org learning repo integration
4. Cross-enterprise Agent Coordination
   - Multi-org agent composition
   - Shared skill libraries

---

## Decisions Affecting Downstream Work

### Impact on PR/Issue Triage Workflow

- **Consumer SDK templates** will include triage workflow example
- Reference implementation (issue-triage.lock.yml) will serve as golden standard
- Consumers can customize without recompiling BaseCoat

### Impact on Memory Workflows (#1304)

- **Defer** memory workflow templatization to Phase 3
- Mark as "Internal-only" for Phase 1
- Memory workflows will NOT be included in consumer SDK initial release

### Impact on CI/CD Templatization (#1303)

- **Integrate** validate/test patterns into consumer SDK
- Provide templates for consumer CI/CD workflows that validate custom agents
- Do NOT templatize BaseCoat's CI/CD workflows in Phase 1

---

## Open Questions & Risks

### Question 1: MCP Server Versioning

**Issue**: How do consumers handle MCP server updates?

**Risk**: Mismatched versions between BaseCoat releases and MCP servers can break agents

**Mitigation**:
- SDK validates MCP server versions during compile
- Release notes document MCP server compatibility matrix
- Consumers can pin MCP versions in their registry override

### Question 2: Behavioral Eval Coverage

**Issue**: Will consumer agents need the same behavioral eval harness as BaseCoat?

**Risk**: Consumer agents untested; quality degrades in production

**Mitigation**:
- SDK includes sample test cases (triage, code review patterns)
- Behavioral eval harness is open-source and reusable
- Documentation with best practices for testing strategies

### Question 3: Enterprise Air-Gap Scenarios

**Issue**: Some enterprises cannot pull images from ghcr.io

**Risk**: Agents cannot run; MCP servers blocked

**Mitigation**:
- Provide Dockerfile for local registry mirror
- Document private registry setup patterns
- SDK supports custom MCP registry (on-premises mirror)

### Question 4: Consumer Skill/Instruction Adoption

**Issue**: Should consumers inherit BaseCoat instructions and skills?

**Risk**: Version drift; unclear customization scope

**Decision**: Phase 1 focuses on workflows only. Skill/instruction inheritance in Phase 2.

### Question 5: Compliance & Audit Trail

**Issue**: Enterprises may need audit logs of which agents ran and what they accessed

**Risk**: GitHub Actions logs may not meet compliance requirements

**Mitigation**:
- Document GitHub Actions security model
- Provide example CloudWatch/Datadog forwarding templates
- SDK includes audit trail generation script

---

## Success Criteria (Measurable)

1. **Adoption**: At least 3 enterprise teams successfully deploy custom agents using SDK within 6 months (Phase 1 + 2)
2. **Developer Experience**: Average time from "init" to "deployed custom agent" < 15 minutes
3. **Quality**: 0 major security issues in distributed workflows; all BaseCoat workflows pass third-party security audit
4. **Documentation**: >80% code coverage in SDK with inline examples; >3 end-to-end tutorials
5. **Community**: >50 GitHub stars on consumer SDK repo; >10 issues/PRs from external teams

---

## Appendix: Related Files & References

### BaseCoat Workflow Files
- `.github/workflows/code-review-agent.md` (source)
- `.github/workflows/code-review-agent.lock.yml` (compiled)
- [Agentic Workflows Documentation](../agents/agentic-workflows.md)

### MCP References
- `mcp/basecoat-extension/` (in-repo MCP server)
- `mcp/basecoat-metrics/` (metrics MCP server)
- [MCP Developer Agent](../agents/basecoat-10-core-mcp-developer.agent.md)

### Related Issues
- [#1304: Memory Workflows Distribution](https://github.com/ivegamsft/basecoat/issues/1304)
- [#1303: CI/CD Templatization](https://github.com/ivegamsft/basecoat/issues/1303)

---

**Document Status**: Draft Design  
**Last Updated**: 2024  
**Approver**: Architecture Review (pending)

<!-- markdownlint-enable MD009 MD012 MD022 MD031 MD032 MD036 MD040 MD041 -->
