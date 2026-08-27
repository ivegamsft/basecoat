# GitHub Security Posture — Remediation & Issue Filing

## Remediation Commands

### Enable secret scanning and push protection

```bash
gh api --method PATCH /repos/{owner}/{repo} \
  --field security_and_analysis[secret_scanning][status]=enabled \
  --field security_and_analysis[secret_scanning_push_protection][status]=enabled
```

### Enable Dependabot security updates

Navigate to `https://github.com/{owner}/{repo}/settings/security_analysis` and enable **Dependabot security updates**, or use the org-level code security configuration.

### Create a branch protection rule

```bash
gh api --method PUT /repos/{owner}/{repo}/branches/{branch}/protection \
  -F required_status_checks[strict]=true \
  -f 'required_status_checks[contexts][]=<required-check-name>' \
  -F enforce_admins=true \
  -F required_pull_request_reviews[required_approving_review_count]=1 \
  -F restrictions=null
```

Replace `<required-check-name>` with a real CI check context for the repository — an empty `contexts` array does not enforce any status check.

### Require signed commits

```bash
gh api --method POST /repos/{owner}/{repo}/branches/{branch}/protection/required_signatures
```

### Add a CODEOWNERS file

This must target the audited `{owner}/{repo}` explicitly — do not run it against whatever repository happens to be checked out locally, since that can silently modify the wrong repository. Clone (or verify the current checkout's remote matches `{owner}/{repo}`) and land the file through a branch + PR, or create it directly via the Contents API if `.github/` may not exist locally:

```bash
# Preferred: branch + PR against the audited repo
gh repo clone "{owner}/{repo}" audit-codeowners-tmp -- --depth=1
cd audit-codeowners-tmp
git checkout -b add-codeowners
mkdir -p .github
cat > .github/CODEOWNERS << 'EOF'
# Default owners for all files
* @your-team
EOF
git add .github/CODEOWNERS && git commit -m "chore: add CODEOWNERS"
git push -u origin add-codeowners
gh pr create --repo "{owner}/{repo}" --title "chore: add CODEOWNERS" --body "Adds default code owners per security posture audit."

# Alternative: create the file directly via the API (no local checkout required)
gh api --method PUT "repos/{owner}/{repo}/contents/.github/CODEOWNERS" \
  --field message="chore: add CODEOWNERS" \
  --field content="$(base64 -w0 <<< '* @your-team')"
```

### Apply org code security configuration

Navigate to `https://github.com/organizations/{org}/settings/security_products` and apply the **GitHub recommended** configuration to all repositories.

## GitHub Issue Filing

File a GitHub Issue immediately when any check fails. Do not defer. Use the shared command template that ships alongside the `github-security-posture` agent at `agents/references/issue-filing-pattern.md` (installed to `references/issue-filing-pattern.md` next to that agent) with:

- **Title prefix:** `[Security Posture]`
- **Base labels:** `security,posture-audit`
- **This domain's `Rating`/`Check`/`Target`/`Scope` fields replace the shared template's `Category`/`File`/`Line(s)` metadata block** — this domain audits org/repo-level settings, not specific files or lines.
- **Rating:** always `Fail` — only failing checks are filed.
- **Check:** `<check name>`
- **Target:** `<org or owner/repo>`
- **Scope:** `<Org-level | Repo-level>`
- **This domain replaces the shared template's `### Description` / `### Recommended Fix` / `### Acceptance Criteria` / `### Discovered During` sections with its own structure** (do not use both):
  - `### Finding` — what was found: which setting is missing or misconfigured.
  - `### Risk` — why this matters: what an attacker or incident could exploit.
  - `### Remediation` — concise fix using `gh` CLI commands or a link to the settings page, followed by a fenced ` ```bash ` block with the exact remediation command.
  - `### Acceptance Criteria` — `- [ ] Setting is enabled and confirmed via API` and `- [ ] Re-run posture audit shows Pass for this check`.
  - `### Discovered During` — `GitHub Security Posture audit — <UTC timestamp>`. Because the shared template's body is filed through a single-quoted heredoc, `$(date ...)` is **not** evaluated inside it — compute the timestamp first (`date -u +%Y-%m-%dT%H:%MZ`) and paste the literal resulting value into this field, not the `$(...)` expression.

| Finding | Severity | Labels |
|---|---|---|
| Secret scanning disabled | High | `security,posture-audit` |
| Push protection disabled | High | `security,posture-audit` |
| No branch protection on default branch | High | `security,posture-audit` |
| Open critical Dependabot alert | Critical | `security,posture-audit,dependencies` |
| Open high Dependabot alert | High | `security,posture-audit,dependencies` |
| Code scanning not configured | Medium | `security,posture-audit` |
| Signed commits not required | Medium | `security,posture-audit` |
| CODEOWNERS file missing | Low | `security,posture-audit` |
| No org code security configuration | Medium | `security,posture-audit` |
| No org rulesets defined | Medium | `security,posture-audit` |
