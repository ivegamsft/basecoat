---
description: Prevent common GitHub Actions workflow security vulnerabilities including script injection, credential embedding, and unpinned actions.
applyTo: .github/workflows/**
---

# Workflow Integrity Rules

These rules guard against vulnerabilities in GitHub Actions workflow files.

## No base64-encoded scripts

Never embed base64-encoded scripts in workflow YAML. Encoded payloads bypass code review and static analysis.

**Bad:**

```yaml
- run: echo "IyEvYmluL2Jhc2g..." | base64 -d | bash
```

**Good:** Store scripts in `scripts/` and reference them directly.

```yaml
- run: bash scripts/my-script.sh
```

## No inline credentials

Never hardcode secrets, tokens, or credentials in workflow YAML — even as defaults or examples.

**Bad:**

```yaml
env:
  API_KEY: "sk-abc123"
```

**Good:** Always reference GitHub Secrets.

```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}
```

## Pin third-party actions to full commit SHA

Third-party actions (not `actions/*`) must be pinned to a full SHA, not a mutable tag.

**Bad:**

```yaml
uses: some-org/some-action@v2
```

**Good:**

```yaml
uses: some-org/some-action@a1b2c3d4e5f6...  # v2.1.0
```

## No `pull_request_target` with untrusted code

Do not check out PR code and run it in a `pull_request_target` context without explicit trust checks. This allows arbitrary code execution from forks.

## Minimal permissions

Always declare the minimum required `permissions` at the job level. Default to `contents: read`. Add only what the job needs (e.g., `issues: write`, `pull-requests: write`).

```yaml
permissions:
  contents: read
  issues: write
```

## No `${{ github.event.*.body }}` in run steps

User-controlled inputs like issue body, PR title, and commit messages must never be interpolated directly into `run:` steps. Use environment variables instead.

**Bad:**

```yaml
- run: echo "${{ github.event.issue.body }}"
```

**Good:**

```yaml
- env:
    ISSUE_BODY: ${{ github.event.issue.body }}
  run: echo "$ISSUE_BODY"
```
