# Shared guidance ownership lock

`guidance-lock/v1` is the cross-product ownership contract for files physically
materialized by BaseCoat, Sheen, and Adhesion.

## Canonical location

The single lock is `.github/base-coat/guidance-lock.json` in the consumer
repository. Sheen and Adhesion must read and update that file even when their
own product payload is installed elsewhere. The reference JSON Schema is
installed at `.github/base-coat/schemas/guidance-lock-v1.schema.json`, and the
portable PowerShell reader/writer is installed at
`.github/base-coat/scripts/guidance-lock.ps1`.

The lock covers files below these physical shared destinations:

- `.github/skills/`
- `.github/agents/`
- `.github/agents/references/`
- `.github/instructions/`
- `.github/prompts/`
- `.agents/skills/`

`.github/agents/references/` is listed explicitly as a shared destination and
is also structurally contained by `.github/agents/`.

## Contract

Each entry records:

- `path`: normalized repository-relative path using `/`
- `owner`: stable lowercase product identifier (`basecoat`, `sheen`, or
  `adhesion`)
- `guidanceUnit`: optional source unit or source-relative asset path
- `sourceVersion`: optional product or unit version
- `sha256`: lowercase SHA-256 of the installed bytes

Entries are sorted by `path`. Paths must be files, must be under an allowed
shared destination, and must not be rooted, contain `.` or `..` segments, or
escape the repository through normalization. Duplicate paths and malformed
locks fail closed with `GUIDANCE_LOCK_INVALID`.
Paths use the portable `[A-Za-z0-9._/+@()-]` vocabulary. Optional metadata uses
`[A-Za-z0-9._/+:-]` (maximum 512 characters), so PowerShell and
dependency-free Bash readers produce the same deterministic representation.

## Required synchronization behavior

Before changing any shared destination, a product must preflight the complete
write and removal plan:

1. A different owner already claiming a path blocks with
   `GUIDANCE_PATH_COLLISION`; no planned shared file is changed.
2. An existing unclaimed path also blocks as owner `unmanaged`.
3. A same-owner update is allowed only when the installed SHA-256 equals the
   lock's expected hash. A mismatch blocks with
   `GUIDANCE_CONTENT_MODIFIED`, including expected and actual hashes.
4. A product may remove a stale path only when the lock names that product as
   owner and the installed hash still matches. Foreign stale entries and files
   are preserved.
5. A cross-platform exclusive lease at
   `.github/base-coat/guidance-lock.lease/` serializes the read, preflight,
   shared-file mutation, and lock publication transaction. Contenders wait up
   to 30 seconds, then fail with `GUIDANCE_LOCK_BUSY`. The lease contains a
   unique ownership token and acquisition epoch. A lease older than 10 minutes
   is reclaimed by atomically renaming it before deletion; release removes a
   lease only when the token still matches its owner.
6. The lock is written by same-directory temporary file plus atomic replace
   after all planned file operations succeed. If a file operation fails first,
   the old lock remains and the next run fails closed on any partial content
   change.

Products must retain foreign entries unchanged and must never maintain a
second ownership tracker.

## BaseCoat migration

When the JSON lock does not exist, BaseCoat imports
`.github/base-coat/.overlay-managed-files` as `owner: basecoat`. Existing file
bytes become the migration baseline hash because the legacy tracker did not
record hashes. BaseCoat also retains the post-#3422 fallback that reconstructs
legacy paths from the previously installed asset manifest when neither state
file exists.

After a successful sync, BaseCoat atomically writes `guidance-lock.json` and
removes `.overlay-managed-files`. If both files exist, the JSON lock is
authoritative and the legacy tracker is removed only after successful lock
publication. This prevents two unsynchronized ownership sources.

## PowerShell reference

```powershell
. .github/base-coat/scripts/guidance-lock.ps1
$lock = Read-GuidanceLock -RepoRoot (git rev-parse --show-toplevel)

$entry = New-GuidanceLockEntry `
    -RepoRoot (git rev-parse --show-toplevel) `
    -Path '.github/agents/example.agent.md' `
    -Owner 'adhesion' `
    -GuidanceUnit 'dist/agents/example.agent.md' `
    -SourceVersion '0.7.0' `
    -Sha256 '<64 lowercase hex characters>'

Write-GuidanceLock -RepoRoot (git rev-parse --show-toplevel) `
    -Entries (@($lock.entries) + $entry)
```

Callers remain responsible for the preflight rules above; the reusable
functions provide strict normalization, validation, hashing, reading, and
atomic writing.
