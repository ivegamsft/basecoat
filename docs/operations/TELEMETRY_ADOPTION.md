# Telemetry and Adoption Tracking

## Overview

How to measure Base Coat effectiveness, usage patterns, and continuous improvement signals across consuming projects. This guide helps dogfooding teams understand where basecoat is helping, what's working, and where improvements are needed through systematic measurement and feedback loops.

For the currently shippable implementation baseline, see [Telemetry Adoption — Phase 1](./TELEMETRY_ADOPTION_PHASE1.md).
Use canonical terms from
[Dashboard Metrics Schema and Glossary](../reference/metrics-schema-glossary.md#canonical-vocabulary-and-usage-rules)
for adoption telemetry and dashboard participation language.

## What to Measure

### Usage Signals

Understanding how basecoat is being used reveals adoption patterns and engagement levels:

- Which agents/instructions/skills are being referenced in Copilot sessions
- Frequency of agent invocations per project
- Session duration and completion rates
- Which instructions are loaded (via `applyTo` patterns)
- Number of unique contributors using basecoat-enabled features
- Time-of-day and day-of-week usage patterns

Track these signals by project to identify which teams are adopting fastest and which may need additional training or documentation.

### Effectiveness Metrics

Measure the concrete impact basecoat has on development workflows:

- Code review turnaround time (before/after basecoat)
- PR merge cycle time
- Test coverage changes
- Bug escape rate
- Developer satisfaction surveys (quarterly)
- Time-to-first-commit for new contributors (onboarding speed)
- Time spent on code reviews per PR
- Defect density (bugs per 1000 lines of code)

### Quality Signals

Monitor the quality and accuracy of basecoat outputs:

- Agent output acceptance rate (was the suggestion used?)
- Instruction override frequency (did devs disable/skip instructions?)
- Feedback loop signals from feedback-loop agent
- Error rates in CI after basecoat adoption
- Linting violations prevented by agent guidance
- Security vulnerability detection rate improvements

## Collection Methods

### GitHub Copilot Metrics API

Organization-level insights into Copilot usage and effectiveness:

- Endpoint: `GET /orgs/{org}/copilot/metrics/reports/organization-28-day/latest`
- Returns NDJSON download link: daily/weekly active users, CLI users, agent users
- Acceptance rates, suggestions, completions are in the per-day NDJSON data

> ⚠️ Old endpoint `GET /orgs/{org}/copilot/usage` was sunset 2026-04-02.

**How to correlate with basecoat:**

Track GitHub Copilot API metrics from 30 days before basecoat deployment through ongoing. Use deployment date as a clear inflection point to measure delta.

**Requirements:**

- GitHub Organization Admin access
- GitHub CLI installed
- Personal access token with `read:org` scope

**Example query:**

```bash
gh api /orgs/{org}/copilot/metrics/reports/organization-28-day/latest \
  --header "X-GitHub-Api-Version: 2022-11-28"
```

### Repository Signals (Passive)

Measure adoption without active instrumentation by analyzing git history and CI data:

- **Git log analysis:** commit frequency, author count, PR velocity
  - Script: analyze commits touching basecoat configs or agent files
  - Metric: commits per week that reference agents or skills

- **CI metrics:** build times, failure rates, job duration
  - Extract from GitHub Actions workflow runs
  - Compare pre/post basecoat deployment

- **Issue resolution time:** days from open to close
  - Use GitHub Issues API to filter by label (e.g., `basecoat-related`)

- **Code churn:** lines added/removed in agent-related areas
  - Reduced churn in guarded areas suggests agents prevent mistakes

### Copilot Chat Analytics

Extract usage patterns from Copilot Chat interactions:

- Session logs (if organization enables extended data logging)
- Agent mention frequency in chat conversations
- Skill invocation patterns and timing
- Most-used instruction types
- Failed agent invocations (error rates)

Enable via Organization settings > Copilot > Extended Data Logging.

### Custom Telemetry (Active)

Implement lightweight feedback collection within repositories:

- **Feedback hooks in `.github/hooks/`:**

```text
.github/
└── hooks/
    ├── feedback-post-review.sh
    ├── telemetry-session.json
    └── README.md
```

- **Post-session survey prompts:**
  - Lightweight: "Was this agent helpful?" (yes/no/skip)
  - Optional deeper feedback via GitHub Discussions

- **Opt-in telemetry via environment variables:**
  - `BASECOAT_TELEMETRY=true` to enable session logging
  - `BASECOAT_FEEDBACK_CHANNEL=#basecoat-feedback` for Slack integration

- **SQLite-based local session logging:**
  - Reference: `../memory/SQLITE_MEMORY.md` for session database schema
  - Aggregate logs weekly via GitHub Action
  - Upload to shared analysis repository

## Dashboards and Reporting

### GitHub Actions Metrics

Automate metric collection and reporting:

- Workflow run analytics from basecoat-enabled jobs
- Step timing for agent execution and feedback
- Success/failure trends over time
- Cost analysis (compute time × GitHub Actions pricing)

Example workflow for metrics collection:

```yaml
name: Weekly Metrics Collection

on:
  schedule:
    - cron: '0 9 * * MON'
  workflow_dispatch:

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Collect GitHub Copilot metrics
        env:
          GH_TOKEN: ${{ secrets.METRICS_TOKEN }}
        run: |
          gh api /orgs/${{ github.repository_owner }}/copilot/metrics/reports/organization-28-day/latest \
            --header "X-GitHub-Api-Version: 2022-11-28" > copilot-metrics-response.json
          # Download NDJSON from the returned link
          DOWNLOAD_URL=$(cat copilot-metrics-response.json | python3 -c "import sys,json; print(json.load(sys.stdin)['download_links'][0])")
          curl -s "$DOWNLOAD_URL" > copilot-metrics.json

      - name: Analyze repository signals
        run: |
          git log --since="7 days ago" --oneline > commits.txt
          gh workflow list --all > workflows.json
          gh api repos/${{ github.repository }}/actions/runs \
            --paginate --jq '.workflow_runs[] | select(.created_at > now - 7days)' > runs.json

      - name: Generate report
        run: |
          echo "# Weekly Adoption Report" > WEEKLY_REPORT.md
          echo "Generated: $(date)" >> WEEKLY_REPORT.md
          echo "" >> WEEKLY_REPORT.md
          echo "## Metrics Summary" >> WEEKLY_REPORT.md
          echo "- Copilot Sessions: $(jq '.total_sessions' copilot-metrics.json)" >> WEEKLY_REPORT.md
          echo "- Commits (7d): $(wc -l < commits.txt)" >> WEEKLY_REPORT.md

      - name: Post to Slack
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: |
          curl -X POST $SLACK_WEBHOOK \
            -H 'Content-Type: application/json' \
            -d @- << EOF
          {
            "text": "📊 Weekly BaseCoat Metrics",
            "attachments": [{
              "color": "good",
              "text": "$(cat WEEKLY_REPORT.md)"
            }]
          }
          EOF

      - name: Upload metrics
        uses: actions/upload-artifact@v3
        with:
          name: weekly-metrics
          path: |
            copilot-metrics.json
            WEEKLY_REPORT.md
          retention-days: 90
```

### Power BI / Excel Integration

Create dashboards for executive visibility and trend analysis:

- Export metrics to CSV format for ingestion
- Template dashboard for adoption tracking across projects
- Monthly adoption report template with variance analysis
- Trend charts: usage growth, quality improvements, time savings

**Sample CSV export format:**

```csv
date,project,metric,value,target
2024-01-08,project-a,copilot-sessions,42,30
2024-01-08,project-a,pr-merge-time-hours,18.5,20
2024-01-08,project-b,copilot-sessions,31,30
2024-01-08,project-b,pr-merge-time-hours,22.1,20
```

### Automated Reports

Eliminate manual reporting overhead with automated tooling:

- GitHub Actions scheduled job to generate adoption summary (weekly/monthly)
- Post results to Teams/Slack channel with trend indicators
- Compare metrics across dogfooding projects side-by-side
- Alert on anomalies (sudden drops in usage, quality regressions)

## Improvement Loop

### Signal → Action Flow

Turn metrics into continuous improvements:

1. **Collect metrics weekly** via GitHub Actions and API integrations
2. **Identify underperforming agents** (low usage, high override frequency, low acceptance)
3. **Investigate root causes:**
   - Is the instruction unclear?
   - Is the agent context too narrow/broad?
   - Are we targeting the wrong use case?
   - Is the skill missing dependencies?
4. **File improvement issues** in the basecoat repository with telemetry evidence
5. **Implement fixes** in next sprint (refine instructions, improve context, add feedback)
6. **Measure delta** to validate fix effectiveness

### A/B Testing Approach

Test instruction and agent improvements with measurable outcomes:

- Use branch-based instruction variants
- Split consuming projects into control (main branch) and treatment (experiment branch)
- Measure key metrics between teams using different instruction versions
- Promote winning variants to main branch after 2-week test period

**Example experiment setup:**

```yaml
# .github/workflows/experiment-tracking.yml
name: A/B Experiment Tracking

on:
  workflow_dispatch:
    inputs:
      experiment:
        description: 'Experiment name (e.g., improved-pr-review-v2)'
        required: true
        type: string

jobs:
  track-variant:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Record experiment variant
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VARIANT=$(git rev-parse --abbrev-ref HEAD)
          echo "experiment=${{ inputs.experiment }}" > experiment.env
          echo "variant=$VARIANT" >> experiment.env
          echo "start_date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> experiment.env
```

### Feedback Collection

Build systematic feedback collection into the improvement workflow:

- **In-repo feedback mechanism:**
  - GitHub Discussions thread per agent/instruction set
  - Issues with `feedback:` label for structured bug reports
  - Quick reaction emoji voting on usefulness

- **Monthly retrospective** on basecoat effectiveness
  - 30-minute sync with all dogfooding teams
  - Review metrics, discuss blockers, share learnings
  - Document decisions in team wiki

- **Cross-project sync** to share learnings and prevent silos
  - Rotate facilitator across projects
  - Capture best practices and anti-patterns
  - Contribute winning instructions back to basecoat

## Privacy and Compliance

Maintain trust and regulatory compliance:

- **What data is collected (aggregated, not individual):**
  - No personal identifiers in telemetry
  - Aggregate counts by project, not by user
  - Session logs contain only agent/skill names and timestamps
  - Code snippets are not logged

- **Opt-in/opt-out mechanisms:**
  - Default: opt-out (telemetry disabled unless `BASECOAT_TELEMETRY=true`)
  - Easy disable: set `BASECOAT_TELEMETRY=false`
  - Users can exclude specific projects from telemetry

- **Data retention policies:**
  - Raw session logs: 30 days (then delete)
  - Aggregated metrics: 12 months
  - Experiment data: until analysis complete (max 90 days)

- **No PII in telemetry:**
  - Scrub email addresses, user names, branch names
  - Generic project identifiers (project-a, project-b) instead of real names

## Getting Started

### Quick Setup for Dogfooding Projects

Get metrics flowing in 30 minutes:

1. **Enable GitHub Copilot metrics API access:**
   - Organization owner enables in Settings > Copilot
   - Ensure consuming projects have GitHub Advanced Security

2. **Add telemetry GitHub Action:**
   - Copy example workflow from this guide
   - Customize for your organization and projects
   - Set schedule: weekly collection at 9 AM Monday

3. **Set up monthly review cadence:**
   - Calendar invite: "BaseCoat Adoption Review" 1st Friday of month
   - Participants: basecoat maintainers + consuming project leads
   - Duration: 30 minutes

4. **Create feedback channel:**
   - Slack: `#basecoat-feedback`
   - Or GitHub Discussions in basecoat repository
   - Share link in consuming project onboarding docs

### Baseline Metrics

Before deploying basecoat, establish baseline measurements for comparison:

**Week 1 metrics to capture:**

- Copilot usage: total sessions, languages, acceptance rates
- PR velocity: average days from open to merge
- Code review time: average review duration
- Test coverage: overall percentage
- CI success rate: percentage of successful builds
- Onboarding time: average days from first commit for new contributors

**Document baseline in:**

```markdown
# BaseCoat Adoption Baseline
## Project: [project-name]
## Baseline Date: [YYYY-MM-DD]
## Metrics:
- Copilot Sessions/Week: X
- PR Merge Time: Y hours
- Code Review Time: Z hours
- Test Coverage: A%
- CI Success: B%
- Onboarding Days: C

## Target Improvements (by deployment+30 days):
- PR Merge Time: reduce by 15%
- Code Review Time: reduce by 10%
- Onboarding Days: reduce by 20%
```

## Example: Telemetry GitHub Action

Complete workflow for collecting and reporting metrics across consuming projects:

```yaml
name: BaseCoat Metrics Collection

on:
  schedule:
    - cron: '0 9 * * MON'
  workflow_dispatch:

concurrency:
  group: metrics-collection
  cancel-in-progress: false

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    outputs:
      summary: ${{ steps.report.outputs.summary }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Collect Copilot usage
        env:
          GH_TOKEN: ${{ secrets.METRICS_TOKEN }}
        run: |
          python3 << 'EOF'
          import subprocess
          import json
          from datetime import datetime, timedelta

          # Get Copilot metrics for last 7 days
          result = subprocess.run([
              'gh', 'api',
              gh api "/orgs/${{ github.repository_owner }}/copilot/metrics/reports/organization-28-day/latest" \
              '--header', 'X-GitHub-Api-Version: 2022-11-28'
          ], capture_output=True, text=True)

          metrics = json.loads(result.stdout)
          with open('copilot-usage.json', 'w') as f:
              json.dump(metrics, f, indent=2)
          EOF

      - name: Analyze repository velocity
        run: |
          python3 << 'EOF'
          import subprocess
          import json
          from datetime import datetime, timedelta

          # Get commits from last 7 days
          week_ago = (datetime.now() - timedelta(days=7)).isoformat()
          commits = subprocess.run([
              'git', 'log',
              f'--since={week_ago}',
              '--pretty=format:%H|%an|%ad|%s',
              '--date=short'
          ], capture_output=True, text=True).stdout.strip().split('\n')

          # Get PR metrics
          prs = subprocess.run([
              'gh', 'pr', 'list',
              '--state', 'all',
              '--limit', '50',
              '--json', 'number,title,createdAt,mergedAt,reviews'
          ], capture_output=True, text=True).stdout

          metrics = {
              'commit_count': len([c for c in commits if c]),
              'pr_data': json.loads(prs)
          }

          with open('repo-velocity.json', 'w') as f:
              json.dump(metrics, f, indent=2)
          EOF

      - name: Generate adoption report
        id: report
        run: |
          python3 << 'EOF'
          import json
          from datetime import datetime

          # Load collected metrics
          with open('copilot-usage.json') as f:
              copilot = json.load(f)
          with open('repo-velocity.json') as f:
              velocity = json.load(f)

          # Generate report
          report = f"""
          # BaseCoat Adoption Report
          **Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}

          ## Copilot Metrics (7-day)
          - **Total Sessions:** {copilot.get('total_sessions', 'N/A')}
          - **Acceptance Rate:** {copilot.get('acceptance_rate', 'N/A')}%
          - **Languages:** {', '.join(copilot.get('languages', [])[:5])}

          ## Repository Velocity
          - **Commits:** {velocity['commit_count']}
          - **PRs Merged:** {len([p for p in velocity['pr_data'] if p.get('mergedAt')])}
          - **Avg Review Time:** {velocity.get('avg_review_time', 'calculating...')}h

          ## Status
          ✅ Metrics collected successfully
          """

          with open('REPORT.md', 'w') as f:
              f.write(report)

          # Set output for next job
          with open('report.txt', 'w') as f:
              f.write(report)
          EOF
          echo "summary=$(cat report.txt | head -5)" >> $GITHUB_OUTPUT

      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: metrics-${{ github.run_id }}
          path: |
            copilot-usage.json
            repo-velocity.json
            REPORT.md
          retention-days: 90

      - name: Post to Slack
        if: always()
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: |
          curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d @- << 'EOF'
          {
            "text": "📊 BaseCoat Weekly Metrics",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "${{ steps.report.outputs.summary }}\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Full Report>"
                }
              }
            ]
          }
          EOF

  notify-teams:
    runs-on: ubuntu-latest
    needs: collect-metrics
    if: always()
    steps:
      - name: Download metrics
        uses: actions/download-artifact@v3
        with:
          name: metrics-${{ github.run_id }}

      - name: Post to Teams
        env:
          TEAMS_WEBHOOK: ${{ secrets.TEAMS_WEBHOOK }}
        run: |
          curl -X POST "$TEAMS_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d @- << 'EOF'
          {
            "@type": "MessageCard",
            "@context": "https://schema.org/extensions",
            "summary": "BaseCoat Metrics Report",
            "themeColor": "0078D4",
            "sections": [
              {
                "activityTitle": "📊 Weekly BaseCoat Adoption Metrics",
                "text": "Metrics collected and ready for review"
              }
            ],
            "potentialAction": [
              {
                "@type": "OpenUri",
                "name": "View Report",
                "targets": [
                  {
                    "os": "default",
                    "uri": "${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                  }
                ]
              }
            ]
          }
          EOF
```

## Reference Links

- [GitHub Copilot Metrics API](https://docs.github.com/en/rest/copilot/copilot-metrics)
- [GitHub Actions Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [SQLite Memory Implementation](../memory/SQLITE_MEMORY.md)
- [BaseCoat Architecture](https://github.com/IBuySpy-Shared/basecoat/blob/main/README.md)
- [Feedback Loop Agent Guide](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/feedback-loop.agent.md)
