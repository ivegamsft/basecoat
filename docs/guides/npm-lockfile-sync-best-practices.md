# npm Lockfile Sync Best Practices

Use these rules in npm-based repos to avoid CI drift:

1. Update `package-lock.json` whenever `package.json` changes.
2. Commit `package.json` and `package-lock.json` together.
3. Use `npm ci` in CI so drift fails fast instead of masking mismatch.
4. Avoid mixing installs across branches or worktrees.
5. Treat lockfile changes as part of the same review as dependency changes.

## Why this matters

Lockfile drift is a common source of broken builds. The safest workflow is to keep the
dependency graph and its lockfile in the same change, then validate with `npm ci` before
merge.
