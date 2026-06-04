<!-- markdownlint-disable MD031 MD032 MD036 MD040 MD041 -->

## CI/CD Workflow Templatization Design

### Executive Summary

This document assesses feasibility and priority for templatizing BaseCoat's CI/CD workflows within the Consumer Agent SDK model. **Recommendation: Phased approach with 3 workflow categories** based on reusability, consumer demand, and coupling to BaseCoat infrastructure.

**Key Decision**: Integration with Consumer Agent SDK (Phase 1 of #1305) will provide **validation & testing templates** for consumer CI/CD. Templatization of BaseCoat's existing CI/CD workflows is lower priority (Phase 3).

---

## Workflow Classification & Feasibility Assessment

### Group A: Reusable Validation Templates (HIGH PRIORITY - Phase 1 SDK)

**Suitable for Templatization as Consumer SDK Templates**

| Workflow | Effort | Consumer Value | Recommendation |
|----------|--------|-----------------|---|
| **validate-agents.yml** (new) | 1 week | HIGH | Create as SDK template |
| **test-agents.yml** (new) | 1 week | HIGH | Create as SDK template |
| **agent-pr-validation.yml** (new) | 3 days | MEDIUM | Create as SDK template |

**Details**:
- **validate-agents.yml**: Generic validation for consumer agent markdown files (frontmatter, naming conventions, security rules)
- **test-agents.yml**: Behavioral eval harness runner for agents before deployment
- **agent-pr-validation.yml**: PR gate checks (agent schema validation, MCP server binding validation)

**Customization Points**:
- Script paths (relative to consumer repo)
- Validation rule overrides
- Timeout/concurrency settings
- Notification channels (Slack, email, etc.)

**Integration**:
- SDK `init` command scaffolds these templates
- Consumer can customize via `.basecoat/ci-config.yml`
- Validation rules inherit from `.basecoat/validation-schema.json`

---

### Group B: Potentially Reusable (MEDIUM PRIORITY - Phase 2)

**Could be Templatized with Moderate Customization**

| Workflow | Current Coupling | Effort | Recommendation |
|----------|------------------|--------|---|
| **pr-validation.yml** | BaseCoat labels (wave/sprint) | 2 weeks | Template in Phase 2 after consumer SDK stabilizes |
| **commit-message-validation.yml** | Org-specific secret scanning | 1 week | Basic template in Phase 1, org-specific overrides in Phase 2 |

**Details**:
- **pr-validation.yml**: Release label gates, markdown lint, structural checks
  - **Consumers need**: Release labels? Commit signing? Workflow approval gates?
  - **Path forward**: Create a generic PR gate template with optional label validation
  - **Risk**: Release label naming varies by org (wave/sprint vs. milestone/release)

- **commit-message-validation.yml**: Secret scanning, PII detection
  - **Consumers need**: All enterprises care about secrets
  - **Path forward**: Extract `scripts/scan-commit-messages.sh` to SDK, make reusable
  - **Risk**: Secret patterns vary by org

**Customization**:
- Label naming patterns
- Secret detection rules
- Fail vs. warn thresholds

---

### Group C: BaseCoat-Specific (LOW PRIORITY - Phase 3 or Internal Only)

**Not Suitable for Consumer Templatization**

| Workflow | Why Not Templatized | Alternative |
|----------|---|---|
| **ci.yml** (hardcoded portal/mcp/plugins) | Tightly coupled to BaseCoat project structure | Consumers build their own; provide example in docs |
| **behavioral-eval.yml** | Reference implementation; consumers fork if needed | Include example in SDK docs |
| **harness-change-eval-gate.yml** | BaseCoat eval harness specific | Reference implementation; consumers adapt |
| **token-inventory.yml** | Internal security audit only | Internal-only; not for consumers |

---

## Consumer Agent SDK CI/CD Integration Model

**File Structure** (new in Phase 1):

```
@basecoat/agent-sdk/
├── templates/
│   ├── ci-workflows/
│   │   ├── validate-agents.yml       # Validate agent markdown
│   │   ├── test-agents.yml           # Run behavioral tests
│   │   └── agent-pr-validation.yml   # PR gate checks
│   ├── config/
│   │   ├── default-validation.json   # Default validation rules
│   │   └── mcp-binding-rules.json    # MCP server binding validation
│   └── scripts/
│       ├── validate-agents.sh        # Agent validation script
│       ├── run-tests.sh              # Test harness runner
│       └── check-mcp-bindings.sh     # MCP binding validator
├── docs/
│   └── CI_CD_INTEGRATION.md          # Setup guide
```

**Consumer Workflow** (simplified):

```bash
# 1. Initialize consumer repo
npx @basecoat/agent-sdk init --repo-type enterprise

# 2. Templates automatically copied to .github/workflows/
#    - validate-agents.yml
#    - test-agents.yml
#    - agent-pr-validation.yml

# 3. Consumer customizes via config files
cat > .basecoat/ci-config.yml << 'EOF'
validation:
  rules: 'strict'  # or 'relaxed'
  fail_on_warnings: true
  
mcp:
  check_binding: true
  
pr_gate:
  require_test_pass: true
  require_review: false
EOF

# 4. PR workflow automatically runs validation
git push origin feature-branch
# → PR validation runs, blocks merge if validation fails

# 5. Manual test before merge
npm run test:agents
```

---

## Template Customization Architecture

**Customization Points** (via config files):

1. **Validation Rules** (`.basecoat/validation-schema.json`):
   - Frontmatter requirements
   - Naming conventions
   - Security scanning patterns
   - Optional fields per workflow type

2. **MCP Binding** (`.basecoat/mcp-registry.json`):
   - Required vs. optional servers
   - Version constraints
   - Binding validation rules

3. **Test Configuration** (`.basecoat/test-config.json`):
   - Test case directories
   - Timeout values
   - Pass/fail thresholds

4. **CI/CD Settings** (`.basecoat/ci-config.yml`):
   - Concurrency group naming
   - Notification channels
   - Approval gates (optional)

**Example Override**:

```json
{
  "rules": {
    "frontmatter.required": ["name", "description"],
    "naming": "workflow-name-kebab-case",
    "security": {
      "block_on_secret_pattern": true,
      "patterns": ["AWS_KEY", "GITHUB_TOKEN"]
    }
  }
}
```

---

## Integration with Downstream Workflow Installer

**Workflow Installer** (future component, Phase 2):

```
Consumer Repo
├── .github/workflows/
│   ├── validate-agents.yml              # Generated from SDK template
│   ├── test-agents.yml                  # Generated from SDK template
│   └── agent-pr-validation.yml          # Generated from SDK template
└── .basecoat/
    ├── ci-config.yml                    # Consumer overrides
    ├── validation-schema.json           # Validation rules
    └── mcp-registry.json                # MCP server registry
```

**Installer Flow**:

1. **SDK init command**:
   - Copies templates to `.github/workflows/`
   - Creates `.basecoat/ci-config.yml` with defaults
   - Copies schema files to `.basecoat/`

2. **Consumer customization**:
   - Edit `.basecoat/ci-config.yml` to override defaults
   - Edit `.basecoat/validation-schema.json` to adjust rules
   - Commit changes

3. **CI/CD execution**:
   - Workflows load config from `.basecoat/`
   - Apply consumer overrides to validation rules
   - Run validation and tests

4. **Version management**:
   - SDK version pinned in `.github/workflows/validate-agents.yml`
   - Consumer can upgrade via SDK version bump
   - Breaking changes documented in release notes

---

## Documentation & Configuration Impact

**New Documentation Required**:

1. **Docs/ci-cd-integration.md** (consumer-facing):
   - How to initialize CI/CD templates
   - Customization examples
   - Troubleshooting common validation failures

2. **Docs/validation-rules.md**:
   - Default validation rules
   - How to override per rule
   - Custom rule patterns

3. **Docs/mcp-binding-validation.md**:
   - MCP server binding validation
   - Required vs. optional servers
   - Troubleshooting binding failures

4. **SDK README** (update):
   - Add "CI/CD Integration" section
   - Link to quick-start guide

**Configuration Files**:

1. **`.basecoat/ci-config.yml`** (new):
   - Consumer CI/CD settings
   - Validation level (strict/relaxed)
   - Notification channels

2. **`.basecoat/validation-schema.json`** (new):
   - Validation rules override
   - Inherited from SDK defaults

3. **`.basecoat/mcp-registry.json`** (existing from #1305):
   - MCP server bindings
   - Version constraints

---

## Implementation Roadmap

**Phase 1 (SDK MVP - 2 weeks)**:
- Create `validate-agents.yml` template
- Create `test-agents.yml` template
- Add SDK documentation
- No customization; fixed templates

**Phase 1.5 (Customization - 1 week)**:
- Create `.basecoat/ci-config.yml` pattern
- Add schema override support
- Update documentation with examples

**Phase 2 (Advanced - 3 weeks)**:
- Templatize `pr-validation.yml` (label gates, commit validation)
- Add approval gate customization
- Behavioral eval integration
- CLI commands for testing workflows locally

**Phase 3 (BaseCoat CI/CD Refactor - TBD)**:
- Templatize BaseCoat's own workflows
- Eat own dogfood by using SDK templates internally
- Gather consumer feedback; iterate

---

## Open Questions & Risks

**Q1**: Should consumers inherit BaseCoat's validation rules or start with minimal defaults?
- **Risk**: Over-validation may frustrate teams
- **Mitigation**: Two modes ("strict" = BaseCoat rules; "relaxed" = minimal)

**Q2**: How do we handle org-specific secret patterns?
- **Risk**: Generic secret scanning misses custom patterns
- **Mitigation**: SDK provides pattern registry; consumers can extend

**Q3**: Should CI/CD templates auto-update when SDK version changes?
- **Risk**: Breaking changes in workflow syntax
- **Mitigation**: Semantic versioning; consumers pin SDK version

**Q4**: What's the failure mode if validation/test workflows become outdated?
- **Risk**: Consumer agents slip through with invalid schemas
- **Mitigation**: SDK validation command runs locally; CI/CD as safety net

---

## Success Criteria

1. **Consumer SDK adoption**: At least 2 enterprise teams use validate-agents.yml template within 4 weeks of Phase 1 release
2. **Time-to-CI/CD setup**: Consumer can run SDK init + customize + deploy CI/CD in <30 minutes
3. **Documentation**: Minimal support requests about CI/CD setup (target: <5 questions/month)
4. **No blocking issues**: All Phase 1 workflows pass in 3 different consumer repos

---

## References

- **#1305 Design**: Agentic Workflow Distribution & Consumer Agent SDK
  - Section "Decision 5: Integration with Related Initiatives"
  - Section "Impact on CI/CD Templatization (#1303)"
- **Current Workflows**: `.github/workflows/(validate-basecoat|pr-validation|ci).yml`
- **Related Issue**: #1304 (Memory Workflows Distribution — defer to Phase 3)

<!-- markdownlint-enable MD031 MD032 MD036 MD040 MD041 -->
