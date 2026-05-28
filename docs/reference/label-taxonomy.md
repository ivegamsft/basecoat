# Label Taxonomy Reference

This document defines all labels used in the BaseCoat repository for issue management, discovery, prioritization, and tracking.

---

## Label Categories

### 1. Asset Type Labels (Custom)

These labels identify the type of customization asset and enable discovery and filtering by asset type.

| Label | File Location | Purpose |
|---|---|---|
| `agent` | `agents/*.agent.md` | Copilot agent definition or agent-related work |
| `skill` | `skills/*/SKILL.md` | Reusable skill, template collection, or skill-related work |
| `instruction` | `instructions/*.instructions.md` | Custom instruction file or instruction-related work |
| `prompt` | `prompts/*.prompt.md` | Prompt template, prompt starter, or prompt-related work |

**When to use:** Apply the asset type label to all issues related to creating, updating, fixing, or reviewing that asset type.

**Examples:**

- Creating a new agent → label with `agent`
- Fixing a skill template → label with `skill`
- Updating documentation for an instruction → label with `documentation` + `instruction`
- Reviewing an existing prompt → label with `prompt`

---

### 2. Issue Type Labels

These labels classify the nature or category of the issue work.

| Label | Criteria | When to Use |
|---|---|---|
| `bug` | Unexpected behavior, error, regression, or defect | When reporting broken functionality |
| `enhancement` | New feature, improvement, or capability request | When requesting new functionality or improvements |
| `documentation` | Missing, unclear, or incorrect documentation | When documentation needs to be added, updated, or clarified |
| `question` | Question, clarification request, or support inquiry | When asking for help or clarification (not a bug or feature) |
| `chore` | Maintenance, refactoring, tech debt, or housekeeping | For non-functional improvements (deps, cleanup, tooling) |
| `security` | Vulnerability, security concern, or hardening work | When addressing security issues or hardening systems |

**Rules:**

- Every issue should have exactly one primary issue type label
- Combine with other labels as needed (e.g., `bug` + `security` for a security bug)

---

### 3. Priority Labels (SLA-Driven)

These labels indicate urgency and define service level agreements (SLAs) for response times.

| Label | SLA | Criteria | Example |
|---|---|---|---|
| `priority:high` | 1 hour | Service down, data loss risk, security breach, blocking multiple users | Production outage, critical vulnerability |
| `priority:medium` | 4 hours | Major feature broken, significant user impact, workaround not available | Important agent broken, significant UX issue |
| `priority:low` | 1 week | Cosmetic issue, nice-to-have enhancement, minor improvement | Typo in documentation, minor UI improvement |

**Escalation signals** (auto-elevate to `priority:high` or `priority:medium`):

- Title or body contains: `outage`, `data loss`, `security`, `CVE`, `incident`, `breach`
- Issue is from a repository admin or organization owner
- Multiple users report the same issue within 24 hours
- Issue is marked `blocked` and blocking multiple dependent issues

**When to use:**

- **During triage:** Assign priority based on severity and business impact
- **During sprint planning:** Use priority to determine sprint placement
- **For SLA tracking:** Monitor priority issues for response compliance

---

### 4. Sprint Assignment Labels

These labels indicate which sprint (if any) an issue is assigned to.

| Label | Meaning |
|---|---|
| `sprint-1` | Assigned to Sprint 1 |
| `sprint-2` | Assigned to Sprint 2 |
| `sprint-3` | Assigned to Sprint 3 |
| `sprint-4` | Assigned to Sprint 4 |
| `backlog` | Not yet assigned to a sprint |

**Workflow:**

- Backlog issues start with `backlog` label
- During sprint planning, move to appropriate sprint label: `sprint-1`, `sprint-2`, etc.
- Remove `backlog` when assigning to a sprint
- If moved between sprints, update the label accordingly

---

### 5. Status/Condition Labels

These labels indicate blocking conditions or special handling requirements.

| Label | Meaning | Action |
|---|---|---|
| `blocked` | Issue is blocked by another issue or external dependency | Add a comment explaining what's blocking; update when unblocked |
| `spec-required` | Issue needs a PRD, spec, or design doc before implementation can start | Do not start work until spec is linked and reviewed |
| `governance` | Issue relates to repository governance, standards, or process | Follows governance change approval process |
| `approved` | Issue has been approved for implementation by appropriate stakeholder | OK to start work |

**When to use:**

- **blocked:** When work cannot proceed due to a dependency
- **spec-required:** For complex features or infrastructure changes
- **governance:** For policy, process, or standard changes
- **approved:** After issue review and approval (typically pre-applied by tooling)

---

### 6. Approval & Assignment Labels

| Label | Meaning | Applied By |
|---|---|---|
| `approved` | Issue has been reviewed and approved for implementation | Repo owner or designated reviewer |
| `copilot-agent` | Issue is assigned to and being actively worked on by a Copilot agent | GitHub automation or agent assignment workflow |

**Workflow:**

1. Issue is triaged and labeled with type, priority, and asset type
2. Issue is reviewed and approved (add `approved` label)
3. Issue is assigned to an agent (add `copilot-agent` label)
4. Agent works on the issue and references it in commits/PRs
5. Upon completion, labels remain for historical tracking

---

### 7. Technology/Domain Labels (Optional)

These labels indicate the primary technology or domain focus of the issue. They're optional but recommended for cross-cutting concerns.

| Label | Scope | Examples |
|---|---|---|
| `azure` | Azure cloud services, SDK, or deployment | App Service, AKS, Functions, Bicep |
| `dotnet` | .NET framework or .NET Core | ASP.NET Core, C#, Entity Framework |
| `kubernetes` | Kubernetes, AKS, or container orchestration | Deployment configs, operators, helm |
| `python` | Python language or Python-based tools | Scripts, CLI tools, data processing |
| `terraform` | Terraform, IaC, or infrastructure as code | HCL, modules, providers |
| `github` | GitHub platform, API, or GitHub Actions | Workflows, webhooks, authentication |
| `mcp` | Model Context Protocol or MCP servers | Tools, integrations, custom servers |

**When to use:** Add technology labels when the issue is primarily focused on that technology (optional, use for better discoverability).

---

## Discovery Patterns

### Common Search Queries

Find all issues of a specific type:

```bash
is:issue label:agent              # Find all agent-related issues
is:issue label:skill              # Find all skill-related issues
is:issue label:bug                # Find all bug reports
is:issue label:enhancement        # Find all feature requests
```

Combine labels for compound queries:

```bash
is:issue label:sprint-3 label:agent           # Sprint 3 agent work
is:issue label:bug label:priority:high        # High-priority bugs
is:issue label:blocked is:open                # Open blocked issues
is:issue label:security label:priority:high   # High-priority security issues
```

Filter by sprint and type:

```bash
is:issue label:sprint-2 label:documentation   # Sprint 2 documentation work
is:issue label:sprint-3 label:chore           # Sprint 3 maintenance work
```

Find approval-pending or assigned work:

```bash
is:issue label:approved is:open               # Open approved issues (ready for implementation)
is:issue label:copilot-agent is:open          # Open issues assigned to Copilot agents
is:issue label:spec-required is:open          # Open issues waiting for spec
```

---

## Labeling Workflow

### For Issue Creators

When creating an issue:

1. **Choose asset type** (if applicable): `agent`, `skill`, `instruction`, or `prompt`
2. **Choose issue type**: `bug`, `enhancement`, `documentation`, `question`, `chore`, or `security`
3. **Estimate priority** (optional, will be set during triage): `priority:high`, `priority:medium`, `priority:low`
4. **Add technology labels** (optional): `azure`, `dotnet`, `kubernetes`, etc.

Example: Creating an issue about a bug in a skill → labels: `skill`, `bug`

### For Sprint Planners

During sprint planning:

1. **Review** untriaged issues (missing priority or sprint label)
2. **Assign priority** based on severity and business impact
3. **Assign sprint** using `sprint-1`, `sprint-2`, etc.
4. **Remove `backlog`** label when assigning to a sprint
5. **Mark blocked** issues with `blocked` label (and explain in a comment)

### For Issue Triagers

When triaging an issue:

1. **Apply issue type** label (`bug`, `enhancement`, etc.)
2. **Apply asset type** label if applicable (`agent`, `skill`, etc.)
3. **Set priority** label (`priority:high`, `priority:medium`, `priority:low`)
4. **Detect duplicates** and mark with duplicate label
5. **Add blocking status** if needed (`blocked`, `spec-required`)

### For Code Reviewers

When reviewing a PR:

1. **Link to the issue** in the PR description (`closes #123`)
2. **Verify labels** on the issue are accurate
3. **Update labels** if necessary (e.g., remove `spec-required` after spec is linked)
4. **Mark approved** if the issue is approved for implementation

---

## Label Maintenance

### Retiring Labels

When a label is no longer needed:

1. **Plan the retirement** in a governance issue (label it `governance`)
2. **Notify stakeholders** of the planned retirement and timeline
3. **Migrate** existing issues to new labels (if replacing) or remove the label (if retiring)
4. **Remove** the label from the repository after migration is complete

### Adding New Labels

When proposing a new label:

1. **Create an issue** explaining why the new label is needed
2. **Propose the label name and criteria** in the issue description
3. **Discuss and document** the label in this taxonomy reference
4. **Create the label** in the repository
5. **Communicate** the new label to the team via a comment on the issue or in sprint notes

---

## Integration with Tools

### GitHub Copilot Issue Triage Agent

The `issue-triage` agent uses these labels to classify and prioritize issues automatically. See [`agents/issue-triage.agent.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/issue-triage.agent.md) for details.

### Sprint Planning

Sprint labels (`sprint-1`, `sprint-2`, etc.) are used to track issues assigned to each sprint. Filter by sprint label to see all issues in a sprint:

```bash
is:issue label:sprint-3 is:open
```

### Release Tracking

Version labels (e.g., `v1.0.0`, `v2.0.0`) are used to track which version an issue targets. See [`docs/GOVERNANCE.md#versioning`](GOVERNANCE.md#versioning) for details.

---

## References

- **Governance Framework:** [`docs/GOVERNANCE.md`](GOVERNANCE.md)
- **Contributing Guide:** [`CONTRIBUTING.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/CONTRIBUTING.md)
- **Issue Templates:** [`.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE/)
- **Issue Triage Agent:** [`agents/issue-triage.agent.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/issue-triage.agent.md)
