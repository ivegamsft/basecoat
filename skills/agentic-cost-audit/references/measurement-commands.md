# Measurement Commands

Read-only commands backing each finding. Every command below only reads. If a
command is unavailable in the target environment, report the check as
**unknown** rather than estimating.

Set the scope once:

```bash
REPO="OWNER/REPO"
SINCE="$(date -u -d '30 days ago' +%Y-%m-%d)"
```

## 1. Inventory agent definitions

```bash
grep -l '^engine:' .github/workflows/*.md 2>/dev/null
grep -l 'gh-aw-metadata' .github/workflows/*.lock.yml 2>/dev/null
```

Per file, extract the model, triggers, path filters, and concurrency:

```bash
grep -E '^(model|engine):|^on:|paths-ignore:|paths:|cancel-in-progress:' "$f"
```

Prompt size (check 8) — words times 1.7 approximates tokens:

```bash
wc -w "$f"
```

## 2. Run rates and duration

```bash
gh run list --repo "$REPO" --workflow "$WORKFLOW" --created ">=$SINCE" \
  --limit 200 --json databaseId,createdAt,conclusion,event
```

Runs per day is the row count divided by the window length in days. Keep the
raw count in the report so the arithmetic is checkable.

## 3. Runs per pull request (check 4)

```bash
gh run list --repo "$REPO" --workflow "$WORKFLOW" --created ">=$SINCE" \
  --limit 200 --json event,headBranch
```

Group by `headBranch` and divide total runs by distinct branches. A value near
1.0 means one review per pull request; higher values indicate `synchronize`
re-reviews.

## 4. Docs-only pull request ratio (checks 2 and 3)

```bash
gh pr list --repo "$REPO" --state merged --limit 100 \
  --json number,files --jq \
  '[.[] | {n: .number, docsOnly: ([.files[].path] | all(test("^docs/|\\.md$")))}]'
```

Classify against the repository's real conventions. In repositories where
markdown is executable configuration — agent, skill, prompt, and workflow
definitions — a bare `**/*.md` filter is wrong. Restrict "docs" to genuine
documentation paths and say which paths you counted.

## 5. Required status checks (check 10 interlock)

```bash
gh api "repos/$REPO/branches/main/protection/required_status_checks" \
  --jq '.contexts[]'
gh api "repos/$REPO/rulesets" --jq '.[] | {id, name}'
```

Cross-reference every gating candidate against this list **before** proposing
`paths-ignore`. Also inspect rulesets for a `copilot_code_review` rule, which
indicates the check 6 redundant-layer signal.

## 6. Overlapping charters (check 5)

Compare the `description` and body of each discovered agent and group by the
concern claimed. Two agents that both claim to review correctness of the same
diff are paying twice for one answer.

## Estimating reduction

Estimated monthly reduction for a change is:

```text
runs_avoided_per_month x tier_weight(model)
```

Report it as a **relative** figure against current total agent spend. Do not
quote currency amounts: per-token pricing is not readable from the repository
and would be a fabricated measurement.
