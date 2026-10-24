#!/usr/bin/env bash
# submit-learning.sh — Active learning submission for non-PowerShell environments.
#
# Submits a structured learning candidate to basecoat-memory/sweep-candidates/
# via the GitHub REST API (no git clone, no PowerShell required).
#
# Requirements:
#   - bash (or zsh), curl, jq
#   - MEMORY_REPO_TOKEN env var: fine-grained PAT with Contents (R/W) +
#     Pull Requests (R/W) on {org}/basecoat-memory
#
# Usage:
#   export MEMORY_REPO_TOKEN=ghp_...
#   bash scripts/submit-learning.sh \
#     --subject  "ci:agent-pr-approval" \
#     --fact     "Copilot agent PRs need a maintainer empty-commit to trigger CI." \
#     --evidence "https://github.com/myorg/myrepo/pull/42" \
#     --domain   "ci" \
#     --source   "myorg/myrepo"
#
# Optional flags:
#   --team     "Platform Engineering"
#   --contact  "@alice"
#   --open-pr           Open a PR in basecoat-memory after pushing
#   --dry-run           Print candidate without writing
#   --memory-repo       Override target repo (requires --memory-repo or BASECOAT_SHARED_MEMORY_REPO)

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SUBJECT=""
FACT=""
EVIDENCE=""
DOMAIN=""
SOURCE=""
TEAM=""
CONTACT=""
OPEN_PR=false
DRY_RUN=false
MEMORY_REPO="${BASECOAT_SHARED_MEMORY_REPO:-}"

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subject)    SUBJECT="$2";    shift 2 ;;
    --fact)       FACT="$2";       shift 2 ;;
    --evidence)   EVIDENCE="$2";   shift 2 ;;
    --domain)     DOMAIN="$2";     shift 2 ;;
    --source)     SOURCE="$2";     shift 2 ;;
    --team)       TEAM="$2";       shift 2 ;;
    --contact)    CONTACT="$2";    shift 2 ;;
    --memory-repo) MEMORY_REPO="$2"; shift 2 ;;
    --open-pr)    OPEN_PR=true;    shift ;;
    --dry-run)    DRY_RUN=true;    shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Validate required args ─────────────────────────────────────────────────────
errors=()
[[ -z "$MEMORY_REPO" ]] && errors+=("--memory-repo or BASECOAT_SHARED_MEMORY_REPO is required")
[[ -z "$SUBJECT"  ]] && errors+=("--subject is required")
[[ -z "$FACT"     ]] && errors+=("--fact is required")
[[ -z "$EVIDENCE" ]] && errors+=("--evidence is required")
[[ -z "$DOMAIN"   ]] && errors+=("--domain is required")
[[ -z "$SOURCE"   ]] && errors+=("--source is required")

VALID_DOMAINS="ci git authoring process security portal testing governance memory infra"
if [[ -n "$DOMAIN" ]] && ! echo "$VALID_DOMAINS" | grep -qw "$DOMAIN"; then
  errors+=("--domain '$DOMAIN' is not valid. Choose: $VALID_DOMAINS")
fi

if [[ -n "$SUBJECT" ]] && ! echo "$SUBJECT" | grep -qE '^[a-z]+:[a-z][a-z0-9-]+$'; then
  errors+=("--subject must match domain:key format (e.g., ci:agent-pr-approval)")
fi

if [[ -n "$SUBJECT" && -n "$DOMAIN" ]]; then
  subject_domain="${SUBJECT%%:*}"
  if [[ "$subject_domain" != "$DOMAIN" ]]; then
    errors+=("Subject domain '$subject_domain' does not match --domain '$DOMAIN'")
  fi
fi

if [[ ${#FACT} -gt 300 ]]; then
  errors+=("--fact is ${#FACT} chars; must be ≤ 300")
fi

if [[ -n "$EVIDENCE" ]] && ! echo "$EVIDENCE" | grep -qE '^https?://'; then
  errors+=("--evidence must be a URL starting with http:// or https://")
fi

PROJECT_SPECIFIC="TypeORM|Jest|Winston|Supertest|NextAuth|Prisma|Sequelize|Express|Postgres|MySQL|MongoDB"
if echo "$FACT" | grep -qE "$PROJECT_SPECIFIC"; then
  matched=$(echo "$FACT" | grep -oE "$PROJECT_SPECIFIC" | head -1)
  errors+=("Fact contains '$matched' — possible project-specific technology. Generalize or remove.")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "❌ Validation failed:" >&2
  for e in "${errors[@]}"; do echo "  • $e" >&2; done
  exit 1
fi

echo "✅ Validation passed"

# ── Build candidate content ───────────────────────────────────────────────────
DATE=$(date -u +%Y-%m-%d)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
KEY_PART="${SUBJECT#*:}"
FILE_NAME="submitted-${DATE}-${KEY_PART}.md"

TEAM_LINE=""
CONTACT_LINE=""
[[ -n "$TEAM"    ]] && TEAM_LINE=$'\n'"team: \"${TEAM}\""
[[ -n "$CONTACT" ]] && CONTACT_LINE=$'\n'"contact: \"${CONTACT}\""

CONTENT="---
subject: \"${SUBJECT}\"
domain: \"${DOMAIN}\"
source: \"${SOURCE}\"
submitted: \"${TIMESTAMP}\"
type: \"active-submission\"${TEAM_LINE}${CONTACT_LINE}
---

## Fact

${FACT}

## Evidence

${EVIDENCE}

## Does NOT apply to

<!-- Fill in before promoting: specific conditions where this pattern breaks down -->

## Scope check

- [ ] Applies broadly to this type of repo (not just one internal project)
- [ ] Free of product names, internal system names, org-specific tooling
- [ ] Has held true across ≥ 3 sprints or ≥ 2 similar incidents
- [ ] Another team would change their behavior based on this
"

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "── Dry run — candidate file ──────────────────────────────────────────────────"
  echo "$CONTENT"
  echo "─────────────────────────────────────────────────────────────────────────────"
  echo ""
  echo "Would write to: ${MEMORY_REPO}/sweep-candidates/${FILE_NAME}"
  exit 0
fi

# ── Check token ───────────────────────────────────────────────────────────────
if [[ -z "${MEMORY_REPO_TOKEN:-}" ]]; then
  echo "❌ MEMORY_REPO_TOKEN is not set." >&2
  echo "   Set a fine-grained PAT with Contents (R/W) and Pull Requests (R/W) on ${MEMORY_REPO}." >&2
  exit 1
fi

API_BASE="https://api.github.com"
AUTH_HEADER="Authorization: Bearer ${MEMORY_REPO_TOKEN}"

# ── Get default branch SHA ────────────────────────────────────────────────────
echo "📥 Resolving ${MEMORY_REPO} default branch..."
REPO_INFO=$(curl -fsS \
  -H "$AUTH_HEADER" \
  -H "Accept: application/vnd.github+json" \
  "${API_BASE}/repos/${MEMORY_REPO}")

DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.default_branch')
BASE_SHA=$(curl -fsS \
  -H "$AUTH_HEADER" \
  -H "Accept: application/vnd.github+json" \
  "${API_BASE}/repos/${MEMORY_REPO}/git/ref/heads/${DEFAULT_BRANCH}" \
  | jq -r '.object.sha')

echo "  Branch: ${DEFAULT_BRANCH} @ ${BASE_SHA}"

# ── Create branch ─────────────────────────────────────────────────────────────
BRANCH="memory-submit/${DATE}-${KEY_PART}"
echo "🌿 Creating branch ${BRANCH}..."
curl -fsS \
  -X POST \
  -H "$AUTH_HEADER" \
  -H "Accept: application/vnd.github+json" \
  "${API_BASE}/repos/${MEMORY_REPO}/git/refs" \
  -d "{\"ref\":\"refs/heads/${BRANCH}\",\"sha\":\"${BASE_SHA}\"}" \
  > /dev/null

# ── Push file ─────────────────────────────────────────────────────────────────
FILE_PATH="sweep-candidates/${FILE_NAME}"
ENCODED=$(echo -n "$CONTENT" | base64 | tr -d '\n')

echo "📝 Writing ${FILE_PATH}..."
curl -fsS \
  -X PUT \
  -H "$AUTH_HEADER" \
  -H "Accept: application/vnd.github+json" \
  "${API_BASE}/repos/${MEMORY_REPO}/contents/${FILE_PATH}" \
  -d "{
    \"message\": \"chore(memory): active submission — ${SUBJECT} from ${SOURCE}\n\nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>\",
    \"content\": \"${ENCODED}\",
    \"branch\": \"${BRANCH}\"
  }" > /dev/null

echo "📤 Pushed to ${MEMORY_REPO}:${BRANCH}"

# ── Open PR (optional) ────────────────────────────────────────────────────────
if [[ "$OPEN_PR" == "true" ]]; then
  TEAM_ROW=""
  CONTACT_ROW=""
  [[ -n "$TEAM"    ]] && TEAM_ROW=$'\n'"| **Team** | ${TEAM} |"
  [[ -n "$CONTACT" ]] && CONTACT_ROW=$'\n'"| **Contact** | ${CONTACT} |"

  PR_BODY="## Active Memory Submission

Submitted by **${SOURCE}** via \`submit-learning.sh\`.

| | |
|---|---|
| **Subject** | \`${SUBJECT}\` |
| **Domain** | \`${DOMAIN}\` |
| **Source** | \`${SOURCE}\` |
| **Submitted** | ${TIMESTAMP} |${TEAM_ROW}${CONTACT_ROW}

## Steward Review Checklist

- [ ] Generalize the fact if needed (remove org/project references)
- [ ] Complete the 'Does NOT apply to' section
- [ ] Confirm all four scope-check boxes are met
- [ ] Move to \`memories/${DOMAIN}/\` as a structured memory file
- [ ] Delete the candidate entry from \`sweep-candidates/\`"

  PR_RESPONSE=$(curl -fsS \
    -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}/repos/${MEMORY_REPO}/pulls" \
    -d "$(jq -n \
      --arg title "memory(submit): ${SUBJECT} from ${SOURCE}" \
      --arg head "${BRANCH}" \
      --arg base "${DEFAULT_BRANCH}" \
      --arg body "${PR_BODY}" \
      '{title:$title,head:$head,base:$base,body:$body}')")

  PR_URL=$(echo "$PR_RESPONSE" | jq -r '.html_url')
  echo "🔗 PR opened: ${PR_URL}"
else
  echo "ℹ️  Branch pushed. The weekly sweep will include this candidate."
  echo "   To open a PR immediately, re-run with --open-pr."
fi

echo ""
echo "✅ Learning submitted: ${SUBJECT}"
