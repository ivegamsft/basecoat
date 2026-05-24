---
on:
  pull_request:
    types: [opened, synchronize]
  workflow_dispatch:
    inputs:
      pr_number:
        description: "PR number to analyze (for workflow_dispatch)"
        required: false
permissions:
  contents: read
  issues: read
  pull-requests: read
safe-outputs:
  add-comment:
    hide-older-comments: true
  noop:
    report-as-issue: false
engine: copilot
timeout-minutes: 20
run-name: "Security Analysis — PR #${{ github.event.pull_request.number }}"
---

# Security Analyst — PR Security Review

You are performing a focused security review of a pull request diff. Your goal
is to identify security vulnerabilities, insecure patterns, and risk before
the code reaches production.

## Context

- **PR number**: `${{ github.event.pull_request.number }}`
- **PR title**: `${{ github.event.pull_request.title }}`
- **Repository**: `${{ github.repository }}`
- **Base branch**: `${{ github.event.pull_request.base.sha }}`

Fetch the PR diff and changed files:

```bash
gh pr view ${{ github.event.pull_request.number }} --repo ${{ github.repository }} \
  --json number,title,body,additions,deletions,changedFiles

gh pr diff ${{ github.event.pull_request.number }} --repo ${{ github.repository }}
```

## What to Do

Only post a comment if you find security issues. If the diff is clean, post nothing.

### Step 1 — Scope the Changed Surface

Identify which of the following are touched by this PR:
- Authentication or authorization logic
- Input handling, parsing, or validation
- Data access or query construction
- Secrets, credentials, tokens, or certificates
- Network or API endpoints
- Dependencies (package.json, requirements.txt, go.mod, *.csproj)
- CI/CD configuration (.github/workflows/, Dockerfiles, IaC)
- Cryptographic operations

### Step 2 — OWASP Top 10 Spot Check (diff-scoped)

For each changed area, check the most relevant OWASP categories:

| Category | What to Look For |
|---|---|
| **A01 Broken Access Control** | Missing auth checks, hardcoded user IDs, IDOR patterns |
| **A02 Cryptographic Failures** | Weak algorithms (MD5, SHA1, DES), plaintext sensitive data |
| **A03 Injection** | Unsanitized input in SQL, shell commands, LDAP, XML |
| **A05 Security Misconfiguration** | Debug flags in production, overly permissive CORS, verbose errors |
| **A06 Vulnerable Components** | New or updated dependency with known CVE |
| **A07 Auth Failures** | Weak session handling, missing token expiry, improper logout |
| **A09 Logging Failures** | PII or secrets logged, missing audit events for privileged operations |

### Step 3 — Secret Scan

Scan the diff for patterns that suggest hardcoded secrets:
- API keys, tokens, passwords in string literals
- Base64-encoded values that decode to credentials
- Private key headers (`-----BEGIN`)
- Connection strings with embedded credentials

If any are found, classify as **Critical** and flag immediately.

### Step 4 — Dependency Risk (if dependencies changed)

```bash
# Check for known vulnerabilities in changed dependencies
gh pr diff ${{ github.event.pull_request.number }} -- '**/package.json' '**/requirements.txt' \
  '**/go.mod' '**/*.csproj' 2>/dev/null | head -200
```

Note any new dependency that:
- Has not been updated in 12+ months
- Has a known CVE in the added version range
- Adds significant transitive dependencies

### Step 5 — Post Security Review Comment

Only post if Step 2–4 found issues. Use this structure:

```markdown
## Security Review

> Automated security analysis of the PR diff. Review findings and resolve
> before merging.

### Findings

| Severity | Category | File | Line | Issue |
|---|---|---|---|---|
| 🔴 Critical | [category] | [file] | [line] | [brief description] |
| 🟠 High | [category] | [file] | [line] | [brief description] |
| 🟡 Medium | [category] | [file] | [line] | [brief description] |

### Details

**[Finding 1 title]**
- **Location**: `file:line`
- **Issue**: What the problem is and why it is a risk
- **Recommendation**: Specific fix or mitigation

---

### Summary

- **Critical**: N | **High**: N | **Medium**: N | **Low**: N
- **Action required before merge**: [Yes / No]
```

Keep findings precise and actionable. Do not report style issues or non-security
concerns. If no security issues are found, do not post a comment.
