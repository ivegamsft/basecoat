# BaseCoat Config (.basecoat.yml)

Place a .basecoat.yml file at the root of your consumer repo to control how
BaseCoat assets are synced and how the enterprise memory sweep collects learnings
from your repo.

The file combines two concerns in one place:

- **Sync configuration** --- which upstream source to pull from, which assets to
  include, and which paths to skip.
- **Memory sweep configuration** --- which issue/PR labels mark learnings, how far
  back to look, and team metadata for candidate review.

Both sections are optional. Omit any key to accept the default.

## Sync configuration

### source

| | |
|---|---|
| **Type** | string (URL) |
| **Required** | No |
| **Default** | `https://github.com/YOUR-ORG/basecoat.git` |

The upstream BaseCoat repository URL to clone assets from. The shipped default is
a placeholder (`YOUR-ORG`) and must be overridden before a sync will work — point
it at your BaseCoat repository or a private fork. This matches the `BASECOAT_REPO`
default used by `sync.sh` and `sync.ps1`.

```yaml
source: https://github.com/YOUR-ORG/basecoat.git
```

### ref

| | |
|---|---|
| **Type** | string |
| **Required** | No |
| **Default** | `main` |
| **Valid values** | Any git branch name or release tag (e.g. `v4.0.0`) |

The branch or tag to sync from. Pin to a release tag for production stability;
leave as `main` to always pull the latest.

```yaml
ref: v4.0.0
```

### agents

| | |
|---|---|
| **Type** | list of strings |
| **Required** | No |
| **Default** | All agents (omit key = sync everything) |
| **Valid values** | Agent names without the `.agent.md` suffix |

Explicit allow-list of agents to include. When present, only the listed agents
are copied to `.github/agents/`. When absent, all available agents are synced.

```yaml
agents:
  - solution-architect
  - code-review
  - security-review
```

### skills

| | |
|---|---|
| **Type** | list of strings |
| **Required** | No |
| **Default** | All skills (omit key = sync everything) |
| **Valid values** | Skill directory names (each skill lives at `skills/<name>/`) |

Explicit allow-list of skills to include. When present, only the listed skill
directories are copied. When absent, all available skills are synced.

```yaml
skills:
  - azure-diagnostics
  - database-migration
```

### instructions

| | |
|---|---|
| **Type** | list of strings |
| **Required** | No |
| **Default** | All instruction files (omit key = sync everything) |
| **Valid values** | Instruction file names without the `.instructions.md` suffix |

Explicit allow-list of instruction files to include. When present, only the
listed files are copied to `.github/instructions/`. When absent, all instruction
files are synced.

```yaml
instructions:
  - governance
  - token-economics
```

### scoped_instructions

| | |
|---|---|
| **Type** | list of strings |
| **Required** | No |
| **Default** | None |

Instructions that apply to specific file patterns. Populated by the integrate
prompt based on the detected tech stack. Leave empty or omit if you have no
pattern-specific instructions.

```yaml
scoped_instructions: []
```

### sync.exclude

| | |
|---|---|
| **Type** | list of strings (path prefixes or globs) |
| **Required** | No |
| **Default** | Nothing excluded |

Paths to skip during sync. Useful for omitting archived assets or directories
that your team does not need.

```yaml
sync:
  exclude:
    - archive/
    - agents/deprecated-agent.agent.md
```

## Memory sweep configuration

The enterprise memory sweep (`scripts/sweep-enterprise-memory.ps1`) runs weekly
against all repos in your GitHub org that carry the `basecoat-enabled` topic.
For each repo it reads `.basecoat.yml` to fine-tune sweep behaviour.

### learning_labels

| | |
|---|---|
| **Type** | list of strings |
| **Required** | No |
| **Default** | `[learning, retrospective, decision]` |

Issues and pull requests with **any** of these labels are treated as learning
candidates by the sweep. Add labels that your team uses for ADRs, postmortems,
or other retrospective artefacts.

```yaml
learning_labels:
  - learning
  - retrospective
  - decision
  - adr
  - postmortem
```

### days_back

| | |
|---|---|
| **Type** | integer |
| **Required** | No |
| **Default** | `30` |

How many calendar days back the sweep looks for signals. Increase this if your
team runs quarterly retrospectives; the sweep will not re-process items it has
already seen.

```yaml
days_back: 30
```

### team

| | |
|---|---|
| **Type** | string |
| **Required** | No |
| **Default** | `""` |

Human-readable team name. Included in candidate files to give memory stewards
context during triage.

```yaml
team: "Platform Engineering"
```

### contact

| | |
|---|---|
| **Type** | string |
| **Required** | No |
| **Default** | `""` |

GitHub username or team handle for the primary contact. Stewards can mention this
handle when a candidate needs clarification.

```yaml
contact: "@platform-eng"
```

### domain

| | |
|---|---|
| **Type** | string |
| **Required** | No |
| **Default** | `""` |
| **Valid values** | `ci`, `git`, `authoring`, `process`, `security`, `portal`, `testing`, `governance`, `memory`, `infra` |

Primary domain hint. Helps route candidates to the correct memory subdirectory
during steward review.

```yaml
domain: infra
```

### auto_pr

| | |
|---|---|
| **Type** | boolean |
| **Required** | No |
| **Default** | `false` |

When `true`, the sweep script calls `submit-learning.ps1` and automatically
opens a pull request for each candidate. When `false` (the default), candidates
are written to `sweep-candidates/` on the next weekly run and wait for manual
steward review.

```yaml
auto_pr: false
```

## Memory sweep process

### What triggers a sweep

The workflow `.github/workflows/adoption-metrics.yml` triggers the sweep on a
weekly schedule and on `workflow_dispatch`. The sweep script is
`scripts/sweep-enterprise-memory.ps1`.

### Discovery phase

1. The script queries the GitHub API for all repositories in the configured org
   that carry the `basecoat-enabled` GitHub topic.
2. For each discovered repo it fetches `.basecoat.yml` via the GitHub Contents
   API (base64-decoded). Repos without the file use default values for every key.

### Signal extraction

For each repo the sweep collects three signal types:

- **Labelled issues** --- issues carrying any label in `learning_labels` closed
  within `days_back` days.
- **Labelled pull requests** --- PRs carrying any label in `learning_labels` merged
  within `days_back` days.
- **CHANGELOG entries** --- recent entries from `CHANGELOG.md` or `CHANGELOG`.

### Output

Extracted signals are written as Markdown candidate files to the `OutputDir`
(default: `sweep-candidates/`). Each file is named `YYYY-MM-DD.md` and contains
the signal content plus team metadata (`team`, `contact`, `domain`) from
`.basecoat.yml`.

When `auto_pr: true`, the script immediately opens a pull request proposing the
candidates for inclusion. Otherwise candidates wait for the weekly steward triage
cycle described in [Memory Triage](../memory/triage.md).

### How .basecoat.yml influences the sweep

| Key | Effect |
|---|---|
| `learning_labels` | Filters which issues/PRs are extracted |
| `days_back` | Sets the lookback window for signal extraction |
| `team` / `contact` / `domain` | Embedded in every candidate file for steward context |
| `auto_pr` | Controls whether candidates are auto-submitted or queued |

## Complete examples

### Quickstart --- minimal config, sync everything from main

Suitable for individuals and small teams trying BaseCoat for the first time. No
include lists means all agents, skills, and instructions are synced.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: main
```

### Pinned production --- locked to a release tag with explicit asset lists

Suitable for teams that need stability. Pin to a release tag so the next upstream
release does not change agent behaviour unexpectedly.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: v4.0.0   # pinned --- update deliberately after reviewing the changelog

agents:
  - solution-architect
  - code-review
  - sprint-planner
  - security-review

skills:
  - azure-diagnostics
  - database-migration

instructions:
  - governance
  - token-economics

sync:
  exclude:
    - archive/   # skip historical/deprecated assets

# Memory sweep
learning_labels:
  - learning
  - retrospective
  - decision
days_back: 30
team: "Platform Engineering"
contact: "@platform-eng"
domain: infra
```

### Enterprise fork --- private fork, exclude archive

Suitable for enterprises that maintain a private fork with organisation-specific
agents and instructions. Point `source` at the fork; consumers get the
organisation's curated asset set.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: main   # or a tag from the private fork

sync:
  exclude:
    - archive/              # skip archived assets
    - agents/experimental/  # not ready for consumers

# Memory sweep --- quarterly retrospective cadence
learning_labels:
  - learning
  - adr
  - postmortem
days_back: 90   # quarterly retrospective cadence
team: "YOUR-ORG Platform"
contact: "@your-org/platform-team"
domain: governance
auto_pr: false
```

### Selective sync --- only security and governance assets

Suitable for teams that want a minimal footprint. Only the listed agents,
skills, and instructions are synced; everything else is excluded.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: v4.0.0

agents:
  - security-review
  - code-review

skills:
  - harden

instructions:
  - governance
  - security-baseline

sync:
  exclude:
    - archive/

# Memory sweep --- security domain focus
learning_labels:
  - security
  - decision
days_back: 60
team: "AppSec"
contact: "@appsec-team"
domain: security
```

## See also

- [Consumer Sync Guide](consumer-sync.md) --- sync commands and automation setup
- [Make It Your Own](customization.md) --- customization levels from zero-config to full fork
- [Memory Triage](../memory/triage.md) --- how stewards review sweep candidates
- [Memory Enlistment](../memory/enlistment.md) --- opt a repo into the memory sweep
