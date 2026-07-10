# Guardrail: No Hardcoded Secrets in Workflow Files

> **Rule:** Never place secrets, tokens, passwords, connection strings, or credentials as literal values in any GitHub Actions workflow `env` block, `with` parameter, or `run` script. Always reference them through the `secrets` context.

---

## Why This Matters

Workflow files are committed to source control and visible to anyone with read access to the repository. A hardcoded secret in a workflow file is a leaked secret — it persists in Git history even after removal and can be harvested by automated scanners.

---

## Bad Examples

```yaml
# ❌ BAD — password as a literal value in env
env:
  DB_PASSWORD: "my-password-123"
  API_KEY: "sk-abc123def456"
```

```yaml
# ❌ BAD — secret passed inline to an action input
- uses: azure/login@v2
  with:
    client-secret: "s3cret-value-here"
```

```yaml
# ❌ BAD — connection string embedded in a run step
- run: |
    az sql db connect --connection-string "Server=myserver;Password=hunter2"
```

---

## Good Examples

```yaml
# ✅ GOOD — reference secrets context
env:
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
  API_KEY: ${{ secrets.API_KEY }}
```

```yaml
# ✅ GOOD — secrets passed through action inputs
- uses: azure/login@v2
  with:
    client-secret: ${{ secrets.AZURE_CLIENT_SECRET }}
```

```yaml
# ✅ GOOD — secret referenced in a run step
- run: |
    az sql db connect --connection-string "${{ secrets.SQL_CONNECTION_STRING }}"
```

---

## How to Audit Existing Workflows

1. **Search for literal strings in env blocks:**

   ```bash
   grep -rn 'env:' .github/workflows/ -A 10 | grep -vE '\$\{\{.*secrets\.' | grep -E ':\s*".+"'
   ```

2. **Look for `with:` parameters that don't use secrets context:**

   ```bash
   grep -rn 'with:' .github/workflows/ -A 10 | grep -vE '\$\{\{.*secrets\.' | grep -iE '(password|secret|token|key|credential|connection).*:\s*".+"'
   ```

3. **Review `run:` blocks for inline credentials:**

   ```bash
   grep -rn 'run:' .github/workflows/ -A 5 | grep -iE '(password|secret|token|api.key)='
   ```

4. **Use GitHub's secret scanning:** Enable [secret scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning) on the repository for automatic detection.

---

## Remediation

If a hardcoded secret is found in a workflow file:

1. **Rotate the credential immediately** — assume it is compromised.
2. Add the value as a [GitHub encrypted secret](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions).
3. Update the workflow to reference `${{ secrets.SECRET_NAME }}`.
4. Rewrite Git history to remove the secret from prior commits if feasible, or contact your security team.

---

## References

- [Using secrets in GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions)
- [Encrypted secrets](https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)
- [Secret scanning](https://docs.github.com/en/code-security/secret-scanning/about-secret-scanning)
- Governance policy: [governance.instructions.md](/instructions/basecoat-20-lang-governance.instructions.md) § 2 — No Secrets
- Security standards: [security.instructions.md](/instructions/basecoat-50-security-security.instructions.md)
