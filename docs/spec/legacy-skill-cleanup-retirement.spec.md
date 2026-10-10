# Spec: Retire destructive skill frontmatter cleanup

Status: proposal for #3656, implementation disabled. No script or source asset
is modified by this PR. This contract chooses deprecation, not a replacement
exporter or schema-aware mutation engine.

## Design and Alternatives

| Option | Consequence | Decision |
| --- | --- | --- |
| Patch field/indent regex | Still cannot safely parse arbitrary YAML or select host profile | Reject |
| Add schema-aware in-place conversion | Duplicates #3654/#3655 and increases migration blast radius | Defer to those contracts |
| Retire mutation, keep explicit guard | Prevents deletion without claiming validation/export capability | Preferred proposal |

The later implementation keeps `scripts/fix-skill-frontmatter.ps1` as a small
compatibility entry point. Parse the existing `-Fix` switch, reject it with an
explicit deprecation error and nonzero exit, and do not enumerate/read/write
skills first. No external command, repository discovery or YAML parsing is
needed to refuse an unsafe operation. Unknown parameters remain errors.

Without `-Fix`, emit a deprecation notice and accurate references, perform no
traversal or mutation, and return normally. This means only "notice delivered",
not "schema valid", "portable" or "nothing to fix". Remove mutation progress
messages and counts rather than returning a fabricated zero-fixed summary.

## Invariants and Boundaries

Every invocation preserves the bytes and paths of all source files and
companions, including malformed files that cannot be validated. It preserves
`compatibility`, nested `metadata`, `allowed-tools`, `allowed_skills`, multiline
descriptions, policy extensions and bodies by not opening them for mutation.
Optional portable fields are not unsupported source fields.

No automatic source normalization, backup overwrite, temp output, host
conversion or invocation of another mutating helper is allowed. Do not accept
paths from source content. The guard must behave the same outside a Git checkout
and cannot rely on current directory or inferred profile to decide safety.

The source validator remains `scripts/validate-basecoat.ps1`, with known profile
gaps tracked by #3655. Export/reference validation belongs to #3654; do not name
an unimplemented command as a working remedy. Consumers needing conversion
remain blocked until the separate explicit projection boundary is implemented.

## Implementation Plan

After source-specific approval, replace the legacy body with the guard, update
only directly related references and add subprocess invocation coverage to an
existing wired suite or a new suite wired into `tests/run-tests.ps1`.
Check repository and distributed installer references before changing filenames;
keep the entry point initially to avoid an unexplained missing-command failure.

If any distributed copy or binding is found, update its actual source and tests
in the same cohesive correction. Regenerate the manifest only when a tracked
distributed asset changes. Do not assume this root helper is distributed merely
because other scripts are.

## Test Matrix and Traceability

Run the actual script in a separate process so exit status and safe refusal are
verified, not mocked by string matching. Use explicit fixture paths/workspaces;
never run the old `-Fix` against the real catalog to reproduce its deletion.

| Fixture | Requirement / oracle |
| --- | --- |
| No flags in repository and outside Git | R3: notice explains source versus portable profiles, names #3654/#3655 and known source-validator gaps, no validation claim, zero file effects |
| `-Fix` in repository and outside Git | R2: nonzero before traversal, stable diagnostic, zero file effects |
| Compatibility list and nested policy metadata | R1: exact original bytes retained |
| Portable strings, empty optional tools and custom extensions | R1/R4: retained, no source/portable conversion inferred |
| CRLF/LF, UTF-8, multiline scalars and code fences | R1: hash/byte equality for the complete file |
| Malformed YAML or inaccessible skills directory | R1/R2: refusal does not need to parse/read catalog |
| Companion assets and unrelated files | R1: file inventory and hashes unchanged |
| Unknown parameters | R2: nonzero, no mutation or silent default |
| Wrapped caller sees guard failure | R2/R5: failure propagated, not suppressed as successful cleanup or a completed migration |

Assertions include output text, subprocess exit status, full file inventory and
SHA-256 byte hashes before/after. A preserved valid fixture alone does not prove
malformed/unreadable cases or a portable schema. Existing frontmatter/source
checks run separately to detect unrelated changes, never as a mutation oracle.
R5 verifies only the guard's observable refusal and honest future-work guidance.
It cannot prove a named export operation, profile conversion, exact migration
diff or provenance; those fixtures remain owned by #3654/#3655.

## Failure, Security and Observability

Record a deprecation category, requested mode and actual failure code. Avoid
logging skill bodies, credentials or guessed enforcement state. No network or
elevated permission is required. A direct error is preferable to an ignored
warning on a destructive request; automated callers must handle it explicitly.

The former regex silently discarded nested content. The guard removes this
failure mode rather than attempting recovery after deletion. Original artifacts
and Git history remain recovery evidence; never bulk restore unrelated user
edits or re-enable cleanup as an automatic fallback.

## Rollout and Rollback

Default is no mutation in every mode, not a gated unsafe legacy mode.
Communicate the intentional `-Fix` failure in consumer migration notes. Verify
the published helper revision and its subprocess result before claiming rollout.
Do not imply installation/source copies are portable or host-enforced.

If guard invocation itself regresses, halt dependent callers and repair the
entry point without restoring deletion. Any proposal to remove the compatibility
entry point later needs an inventory of callers and a separate migration notice.

## References

- [PRD R1-R5](../prd/legacy-skill-cleanup-retirement.prd.md).
- [Source/native contract](../reference/frontmatter-host-contract.md).
- Validator proposal: #3655; portable export proposal: #3654.
- No implementation, assignment or source acceptance closure is granted here.
