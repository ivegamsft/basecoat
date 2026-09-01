# Make It Your Own

BaseCoat is designed to be adopted as-is, then shaped to fit your team.
This guide explains the three levels of customization — from zero-config adoption
to a fully maintained private fork — and when each makes sense.

---

## The customization spectrum

```json
[Sync & go] ──────── [Configure] ──────── [Fork & extend] ──────── [Full fork]
     │                     │                      │                      │
  5 minutes             30 minutes             1–2 hours             Ongoing
  Zero config          .basecoat.yml          Private agents         Full control
  Best for:            Best for:              Best for:              Best for:
  Trying it out        Teams with             Enterprises with       Platform teams
                       preferences            proprietary patterns   maintaining
                                                                     a shared fork
```text

---

## Level 1 — Sync and go

The fastest path. Run the sync script and start using BaseCoat immediately.
No configuration file required.

```bash
# macOS / Linux
export BASECOAT_REPO='https://github.com/YOUR-ORG/basecoat.git'
curl -fsSL https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.sh | bash
```text

```powershell
# Windows PowerShell
$env:BASECOAT_REPO = 'https://github.com/YOUR-ORG/basecoat.git'
irm https://raw.githubusercontent.com/YOUR-ORG/basecoat/main/sync.ps1 | iex
```text

What you get: all agents, skills, instructions, and prompts overlaid into `.github/`.

**Best for:** individuals, small teams, and anyone evaluating BaseCoat.

---

## Level 2 — Configure with `.basecoat.yml`

Add a `.basecoat.yml` file to your repo root to control which assets are synced
and how. The sync script reads it automatically on the next run.

```yaml
# .basecoat.yml
source: https://github.com/YOUR-ORG/basecoat.git
ref: v4.2.1   # pin to a release tag for stability

# Only sync agents relevant to your stack
agents:
  - solution-architect
  - code-review
  - sprint-planner
  - security-review

# Only sync skills relevant to your work
skills:
  - azure-diagnostics
  - database-migration

# Always include governance instructions
instructions:
  - governance
  - token-economics

sync:
  exclude:
    - archive/   # skip archived assets
```text

### What configuration lets you do

| Capability | How |
|---|---|
| Pin to a specific version | Set `ref: vX.Y.Z` |
| Include only relevant agents | List them under `agents:` |
| Exclude noisy or irrelevant skills | Omit from `skills:` or add to `exclude:` |
| Skip the `archive/` directory | Add `archive/` to `sync.exclude` |
| Point at your org's fork | Set `source:` to your fork URL |

**Best for:** teams that want to stay in sync with upstream but don't need everything.

---

## Level 3 — Add private agents (without forking)

You can add agents, skills, or instructions that live only in your repo — they
co-exist with synced BaseCoat assets without any conflict.

Place private assets **outside** the sync target paths:

```text
your-repo/
├── .github/
│   ├── agents/               ← synced from BaseCoat (do not edit)
│   ├── skills/               ← synced from BaseCoat (do not edit)
│   └── copilot-instructions.md  ← synced from BaseCoat (do not edit)
├── copilot/
│   ├── agents/               ← your private agents (not touched by sync)
│   │   └── deploy-to-prod.agent.md
│   └── skills/
│       └── our-stack/SKILL.md
```text

Or, add your private agents as **custom instructions** that extend the synced globals:

```markdown
<!-- .github/my-team.instructions.md — not synced; committed by you -->
applyTo: "src/**/*.py"
---
Always use our internal `app.logger` module, not the stdlib `logging` module.
```text

**Best for:** teams with proprietary domain knowledge or internal tooling that
shouldn't be contributed upstream.

---

## Level 4 — Fork and extend

Fork BaseCoat into your GitHub org and maintain your own version. Your fork gets
upstream updates on your schedule; you add organization-specific assets that are
available to all your consumer repos.

### Fork setup

```bash
# Fork via GitHub CLI
gh repo fork SOURCE-ORG/basecoat --org YOUR-ORG --clone

# Or: mirror to your org
git clone https://github.com/SOURCE-ORG/basecoat.git
cd basecoat
git remote rename origin upstream
git remote add origin https://github.com/YOUR-ORG/basecoat.git
git push -u origin main
```text

### Point your consumers at the fork

```yaml
# .basecoat.yml in each consumer repo
source: https://github.com/YOUR-ORG/basecoat.git
```text

### Stay in sync with upstream

Add an upstream sync workflow to your fork:

```yaml
# .github/workflows/upstream-sync.yml
name: Sync from upstream
on:
  schedule:
    - cron: '0 6 * * 1'  # weekly Monday 6am
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Fetch upstream
        run: |
          git remote add upstream https://github.com/SOURCE-ORG/basecoat.git
          git fetch upstream
          git merge upstream/main --no-edit || echo "Conflicts need manual resolution"
      - name: Open PR if changes
        run: gh pr create --fill --base main || true
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```text

**Best for:** enterprises managing multiple teams, platform teams, and orgs
that need to add proprietary agents centrally.

---

## Override strategy: your version always wins

When you add a file with the same name as a BaseCoat asset in your fork,
your version takes precedence after the next sync. Downstream consumers get
your version, not the upstream original.

```text
SOURCE-ORG/basecoat
  └── agents/basecoat-90-quality-code-review.agent.md   ← upstream original

YOUR-ORG/basecoat (fork)
  └── agents/basecoat-90-quality-code-review.agent.md   ← your override wins
```text

Use this to:

- Add org-specific patterns to an existing agent
- Replace a BaseCoat instruction with your team's version
- Add a skill that wraps your internal platform

---

## Contributing back

If something you built would help everyone using BaseCoat, contribute it upstream.
See the [contribution guide](contributing.md) for the process.

The [memory triage guide](../memory/triage.md) helps you decide whether a learning
belongs in the shared repo or stays in your fork.

---

## Verification

After any customization, verify BaseCoat is correctly wired:

```bash
# Run the full test suite
pwsh tests/run-tests.ps1

# Check asset structure
pwsh scripts/validate-basecoat.ps1

# Verify instruction coverage
pwsh scripts/check-coherence.ps1 -Strict
```text

If tests pass, Copilot can see all your agents, skills, and instructions.
