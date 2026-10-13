# Label Taxonomy Reference

This document defines all labels used in the BaseCoat repository for issue management, discovery, prioritization, and tracking.

---

## Namespace Policy

BaseCoat uses a dual taxonomy:

| Namespace | Examples | Cleanup rule |
|---|---|---|
| Governance/shared | `bug`, `enhancement`, `security`, `priority:critical`, `needs-triage`, `agent`, `skill` | May be normalized across repos |
| Delivery/repo-specific | `sprint:35`, `sprint:2026-W41`, `wave:2`, `backlog`, repo-local tracking labels | Preserve unless the repo owner approves removal or rename (BaseCoat has approved retiring its `area/*` labels) |
| Migration-only | `P0-critical`, `priority/high`, `size/m`, `risk-high`, `docs`, `ci/cd`, `sprint-24` (full list in [Deprecated Labels](#deprecated-labels)) | Migrate to the canonical label, then delete |

Shared tooling should never remove a delivery label just because another repo does not use it.

---

## Canonical Scheme

The machine-readable source of truth is
[`.github/governance/label-taxonomy.json`](../../.github/governance/label-taxonomy.json).
This page explains it; when they disagree, the JSON registry wins and this page is fixed.

- **One separator.** Scoped dimensions use `<dimension>:<value>` (`size:M`, `priority:high`,
  `risk:low`, `sprint:2026-W41`, `wave:2`). The `/` and `-` separators (`size/m`,
  `priority/high`, `risk-low`, `sprint-24`) are deprecated.
- **One label per dimension.** An item carries at most one `type`, `priority`, `size`, `risk`,
  `sprint`, and `wave` label.
- **Unscoped labels** are a single lowercase kebab-case name (`needs-triage`, `build-break`).
  The GitHub community labels `good first issue` and `help wanted` keep their default names
  because GitHub surfaces them to new contributors.
- **Workflow-read labels are protected.** A label that a workflow, script, or ruleset still
  reads is never deleted; `wave/sprint` is retained for that reason until its readers change.

| Dimension | Canonical labels | Primary consumers |
|---|---|---|
| Type | `bug`, `enhancement`, `documentation`, `chore`, `security`, `question` | `approval-contract.cjs`, `issue-field-sync.yml`, issue triage |
| Priority | `priority:critical`, `priority:high`, `priority:medium`, `priority:low` | `approval-contract.cjs`, `issue-field-sync.yml`, release chain |
| Size | `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL`, `size:XXL` | `pr-size-labeler.yml`, `pr-auto-merge-executor.yml` (XXL approval boundary) |
| Risk | `risk:low`, `risk:medium`, `risk:high`, `risk:critical` | ship-it `dispatch-intent.ps1`, `post-merge-release-chain.yml`, portfolio KPIs |
| Resolution | `duplicate`, `invalid`, `wontfix` | `approval-contract.cjs` (blocking labels) |
| Sprint | `sprint:<YYYY>-W<ww>` (applied by `pr-size-labeler.yml`), legacy `sprint:<number>` | Release readiness checks |
| Wave | `wave:<number>` | Release readiness checks, `release-train.yml` |

---

## Delivery Taxonomy: Sprint, Wave, Feature

Use these terms consistently in planning, triage, and reporting:

| Term | Definition | Practical use |
|---|---|---|
| Sprint | Main delivery bucket: the timeboxed board/field that says when work lands | Use sprint projects (for example, Sprint 40, Sprint 41) and the Sprint field in backlog records for historical attribution |
| Wave | Sub-sequence inside a sprint: the order in which related work should happen | Use `wave:1` for prerequisites/foundations and `wave:2` for follow-on work that depends on Wave 1 |
| Feature | The actual work item or capability being delivered | Use to describe scope/content, independent from scheduling and dependency sequencing |

Rule of thumb: **feature = what**, **wave = dependency order**, **sprint = delivery window**.

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
- A security bug uses `security` alone (not `bug` + `security`); combine the type label with
  other dimensions as needed (e.g., `security` + `priority:high`)

---

### 3. Priority Labels (SLA-Driven)

These labels indicate urgency and define service level agreements (SLAs) for response times.

| Label | SLA | Criteria | Example |
|---|---|---|---|
| `priority:critical` | 1 hour | Service down, data loss, active security breach, CVE | Production outage, active exploit |
| `priority:high` | 4 hours | Major feature broken, significant user impact, no workaround | Important agent broken, significant UX issue |
| `priority:medium` | 1 business day | Minor feature issue, workaround exists, moderate user impact | Non-critical agent issue with workaround |
| `priority:low` | 1 week | Cosmetic issue, nice-to-have enhancement, minor improvement | Typo in documentation, minor UI improvement |

Canonical priorities should be used for new triage. Legacy labels (`P0-critical`, `P1-high`, `P2-medium`, `P3-low`, `priority/critical`, `priority/high`, `priority/medium`, `priority/low`) are migration-only and should be normalized to canonical labels by triage automation.

Size (`size:*`) and risk (`risk:*`) labels are machine-derived: `pr-size-labeler.yml` applies
the size label that the merge executor reads, and ship-it intent runs apply `risk:<band>`.
Do not apply them by hand.

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
| `sprint:<YYYY>-W<ww>` | Merged in the named ISO week; applied automatically by `pr-size-labeler.yml` |
| `sprint:<number>` | Assigned to the named sprint (for example, `sprint:35`) |
| `backlog` | Not yet assigned to a sprint |

**Workflow:**

- Backlog issues start with `backlog` label
- During sprint planning, move to the appropriate sprint label: `sprint:<number>` (for example, `sprint:35`)
- Remove `backlog` when assigning to a sprint
- If moved between sprints, update the label accordingly
- Cleanup automation must preserve sprint labels unless the repo owner explicitly declares them obsolete.
- Legacy `sprint-<number>` labels are tolerated by readers during migration, but new sprint assignment should use `sprint:<number>`; each `sprint-<number>` label is renamed to `sprint:<number>`.

---

### 5. Status/Condition Labels

These labels indicate blocking conditions or special handling requirements.

| Label | Meaning | Action |
|---|---|---|
| `blocked` | Issue is blocked by another issue or external dependency | Add a comment explaining what's blocking; update when unblocked |
| `needs-info` | Additional details are required before triage or implementation | Request missing details and keep open until clarified |
| `needs-verification` | A fix is proposed and needs confirmation from reporter/reviewer | Validate behavior in repro path before closing |
| `spec-required` | Issue needs a PRD, spec, or design doc before implementation can start | Do not start work until spec is linked and reviewed |
| `governance` | Issue relates to repository governance, standards, or process | Follows governance change approval process |
| `approved` | Issue has been approved for implementation by appropriate stakeholder | OK to start work |
| `delivery-hold` | PR delivery is intentionally paused even if all automated gates pass | Remove only when the hold owner is ready for the auto-merge executor or merge queue to proceed |

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
3. Issue is assigned to an agent (add `copilot-agent` label and use the cloud-agent issue API with `copilot-swe-agent[bot]`)
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
is:issue label:sprint:35 label:agent          # Sprint 35 agent work
is:issue label:bug label:priority:critical    # Critical bugs
is:issue label:blocked is:open                # Open blocked issues
is:issue label:security label:priority:high   # High-priority security issues
```

Filter by sprint and type:

```bash
is:issue label:sprint:35 label:documentation  # Sprint 35 documentation work
is:issue label:sprint:35 label:chore          # Sprint 35 maintenance work
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
3. **Estimate priority** (optional, will be set during triage): `priority:critical`, `priority:high`, `priority:medium`, `priority:low`
4. **Add technology labels** (optional): `azure`, `dotnet`, `kubernetes`, etc.

Example: Creating an issue about a bug in a skill → labels: `skill`, `bug`

### For Sprint Planners

During sprint planning:

1. **Review** untriaged issues (missing priority or sprint label)
2. **Assign priority** based on severity and business impact
3. **Assign sprint** using `sprint:<number>` labels
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

### Deprecated Labels

Each deprecated label maps to one canonical label. The registry lists every name.

| Deprecated | Canonical |
|---|---|
| `size/xs`, `size/s`, `size/m`, `size/l`, `size/xl` | `size:XS`, `size:S`, `size:M`, `size:L`, `size:XL` |
| `P0-critical`, `P1-high`, `P2-medium`, `P3-low`, `priority/<level>` | `priority:<level>` |
| `risk-low`, `risk-medium`, `risk-high`, `risk-critical` | `risk:<band>` |
| `docs`, `[documentation`, `area/docs` | `documentation` |
| `feature` / `feature-tracker` | `enhancement` / `tracking` |
| `duplicate-candidate` | `needs-triage` (apply `duplicate` only once confirmed) |
| `ci-cd`, `ci/cd`, `area/ci`, `ci-failure` | `ci` |
| `area/infra` | `infrastructure` |
| `good-first-issue` | `good first issue` |
| `dependency` / `agents` / `agent-governance` | `dependencies` / `agent` / `governance` |
| `sprint-<number>` | `sprint:<number>` |
| `[retrospective`, `process]`, `automated-report]`, `sprint:41]` (malformed) | the name without the bracket |
| `sprint-2026-07` | removed (no replacement) |

Readers that normalize historical items (for example `post-merge-release-chain.yml` and
`skills/issue-triage/scripts/triage-issues.ps1`) may keep matching deprecated names; writers
must apply only canonical labels.

### Migration Procedure

Migration must be reversible and logged; never delete a label before its references are updated.

1. Merge the code, workflow, and doc changes that stop writing the deprecated label.
2. Export every issue and pull request that carries it, using a filesystem-safe log name
   (replace `/` and spaces with `_`, for example `size_xs`):
   `gh issue list --label "<old>" --state all --limit 5000 --json number,title,labels > issues-<safe>.json`
   and `gh pr list --label "<old>" --state all --limit 5000 --json number,title,labels > prs-<safe>.json`.
3. If the canonical label does not exist yet, rename in place (`gh label edit "<old>" --name "<new>"`);
   rename keeps every association and is reversed by renaming back.
4. Otherwise add `<new>` to each logged item, remove `<old>`, then delete `<old>`. For every
   exclusive dimension (`type`, `priority`, `size`, `risk`, `sprint`, `wave`), skip adding
   `<new>` when the item already carries a different canonical label in that dimension, and
   record the skip in the log. Reverse by recreating `<old>` and replaying the log.

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
3. **Discuss and document** the label in this taxonomy reference and add it to
   `.github/governance/label-taxonomy.json`
4. **Create the label** in the repository
5. **Communicate** the new label to the team via a comment on the issue or in sprint notes

---

## Integration with Tools

### Label Taxonomy Audit

`pwsh scripts/label-taxonomy-audit.ps1` validates `.github/governance/label-taxonomy.json` and
fails when a workflow, script, or agentic prompt writes a deprecated label (run in CI through
`tests/label-taxonomy-tests.ps1`). With `-Repo <owner/name>` or an offline `-LabelsJsonPath`
export it also reports deprecated, unknown, and missing canonical labels with the proposed
`rename`, `migrate-delete`, or `remove` operation; `-FailOnDrift` exits non-zero on drift. It
never changes labels.

### GitHub Copilot Issue Triage Agent

The `issue-triage` agent uses these labels to classify and prioritize issues automatically. See [`agents/basecoat-10-core-issue-triage.agent.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-10-core-issue-triage.agent.md) for details.

### Sprint Planning

Sprint labels (`sprint:<number>`) are used to track issues assigned to each sprint. Filter by sprint label to see all issues in a sprint:

```bash
is:issue label:sprint:35 is:open
```

### Release Tracking

Version labels (e.g., `v1.0.0`, `v2.0.0`) are used to track which version an issue targets. See [`docs/reference/governance-contract.md#versioning`](governance-contract.md#versioning) for details.

---

## References

- **Governance Framework:** [`docs/reference/governance-contract.md`](governance-contract.md)
- **Contributing Guide:** [`CONTRIBUTING.md`](../../CONTRIBUTING.md)
- **Issue Templates:** [`.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE/)
- **Issue Triage Agent:** [`agents/basecoat-10-core-issue-triage.agent.md`](../../agents/basecoat-10-core-issue-triage.agent.md)
