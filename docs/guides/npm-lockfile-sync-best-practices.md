# npm Lockfile Sync Best Practices

Use these rules in npm-based repos to avoid CI drift:

1. Update `package-lock.json` whenever `package.json` changes.
2. Commit `package.json` and `package-lock.json` together.
3. Use `npm ci` in CI so drift fails fast instead of masking mismatch.
4. Avoid mixing installs across branches or worktrees.
5. Treat lockfile changes as part of the same review as dependency changes.

## Corporate proxy SHA-512 workflow

The required npm registry is
`https://packagefeedproxy.microsoft.io/npm/`. Do not generate BaseCoat lockfiles
through `registry.npmjs.org` or fetch the internal `dist.tarball` URL returned by
the proxy metadata.

The proxy currently publishes `dist.shasum` without `dist.integrity` for some
packages. After any dependency update:

```powershell
npm install --prefix path/to/workspace --package-lock-only --registry=https://packagefeedproxy.microsoft.io/npm/
node scripts/npm-lock-integrity.mjs --dry-run path/to/package-lock.json
node scripts/npm-lock-integrity.mjs --apply path/to/package-lock.json
node scripts/npm-lock-integrity.mjs --check path/to/package-lock.json
```

The helper constructs every tarball request under the corporate proxy, follows
only trusted Microsoft storage redirects, verifies any existing SHA-1 value
against the delivered bytes, and writes the computed SHA-512 integrity. It also
removes internal feed URLs and removes all `resolved` fields from packages that
are publishable (`private` is not `true`). Run without paths to process every
tracked npm lockfile.

Use `--verify` when a full network-backed revalidation is required. This
refetches every dependency through the proxy and compares the delivered bytes
with the committed SHA-512 value.

CI runs the offline `--check` mode and rejects:

- missing or non-SHA-512 package integrity
- corporate proxy or internal Azure Artifacts `resolved` URLs
- any `resolved` field in a publishable package lockfile

## Replacement condition

Retire the SHA-512 generation portion of the helper when the corporate proxy
consistently exposes upstream `dist.integrity` and a fresh proxy-only
`npm install --package-lock-only` produces SHA-512 entries for all affected
workspaces. Prove that condition in CI before removal. Keep the offline lockfile
policy validation so weak integrity and feed-specific URLs cannot regress.

## Why this matters

Lockfile drift is a common source of broken builds. The safest workflow is to keep the
dependency graph and its lockfile in the same change, then validate with `npm ci` before
merge.
