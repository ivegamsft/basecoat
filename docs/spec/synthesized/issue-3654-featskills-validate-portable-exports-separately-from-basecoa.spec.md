---
issue: 3654
title: "feat(skills): validate portable exports separately from BaseCoat source frontmatter"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:high"]
---

# Spec: feat(skills): validate portable exports separately from BaseCoat source frontmatter

## Status and Decision

This is a documentation-only proposal. It defines a future opt-in export
contract; it does not implement an exporter, alter distribution, or authorize
conversion of source skills. BaseCoat source remains canonical and is not
rewritten to satisfy a native schema.

## Context

The source contract in
`instructions/basecoat-10-core-host-frontmatter.instructions.md` deliberately
uses list-valued host compatibility, list-valued source tool policy and rich
metadata. The portable Agent Skills schema instead defines string-valued
`name` and `description`, optional string `compatibility`, optional experimental
space-delimited `allowed-tools`, and optional string-to-string `metadata`.
`docs/reference/frontmatter-host-contract.md` distinguishes these contracts and
states that documented host behavior is not measured loader evidence.

The source issue clarifies that bootstrap copies source skills to
`.agents/skills` and sync copies `planned.source` to its destination. Neither
copy operation proves schema conversion. The 2026-10-07 inventory is a source
snapshot, not a complete reference-library or host-loader test.

## Scope

Specify a deterministic, non-mutating export of explicitly selected source
skills; path-safe companion handling; loss accounting and provenance; native
schema compatibility; fail-closed tool policy; and reference/host verification.
Existing install/sync behavior and all source files remain out of scope.

## Out of Scope

- Bulk conversion, source normalization, or replacing the BaseCoat source schema.
- Changing bootstrap, sync, package, discovery, routing, or runtime permissions.
- Claiming an experimental host field is enforced without positive and negative
  tests on the exact host and version.
- Choosing a new parser dependency, host platform, or compatibility mapping
  without implementation review and source-owner approval.

## Architecture Overview

1. **Select and snapshot.** Resolve one explicit skill directory from the
   repository revision named by the caller. Read `SKILL.md` and resources only
   beneath that root. Record the source commit and hashes before projection.
2. **Validate source profile.** Parse frontmatter as a single safe YAML mapping
   using the repository-supported safe parser. The parser must reject duplicate
   mapping keys at every depth before field interpretation; safe parsing alone
   does not guarantee this behavior. Before value construction, enforce a
   65,536-byte UTF-8 frontmatter cap, YAML depth 32 and 10,000 YAML nodes;
   reject anchors, aliases and merge keys. If the selected parser cannot
   enforce a bound before expansion/materialization, it is unavailable for this
   contract. Require string `name` and `description`, validate the portable
   limits for those values, and require `name` to equal the source directory.
   Run BaseCoat source-profile validation independently; source validity does
   not imply export validity.
3. **Project fields and preserve the body.** Produce a fresh frontmatter block
   in a new `SKILL.md`; never mutate or overwrite the source. Apply only
   explicit, versioned mappings defined below. Copy the exact original Markdown
   body bytes following the closing frontmatter delimiter, including its
   separator/newlines, without normalization or rewriting. Compute SHA-256
   digests over the source and emitted body byte ranges and require equality.
   Unsupported source-only keys remain in source and are listed as omitted,
   not coerced. Any future body transformation requires a separately versioned
   contract and explicit review; it is not part of this proposal.
4. **Resolve resources.** Enforce all limits before opening/copying unbounded
   content: inspect no more than 256 tree files, read no file larger than
   8,388,608 bytes (8 MiB), emit no more than 67,108,864 payload bytes (64 MiB),
   scan no more than 256 Markdown files or 32 link-depth levels, and process no
   more than 4,096 Markdown destinations across one skill. These inclusive
   limits apply per skill. Exceeding any cap fails that skill before
   publication; never truncate, skip, or downgrade a required reference.

   Use a pinned Markdown parser to collect destinations
   from supported inline/reference links and images in the `SKILL.md` body and
   each included Markdown companion (`.md` or `.markdown`). Ignore code spans,
   fenced/indented code and HTML comments. Recursively scan each discovered or
   allowlisted Markdown companion; maintain a visited set of normalized
   root-relative paths so cycles terminate deterministically. Resolve a link
   relative to the Markdown file containing it, then require its normalized
   target to remain beneath the skill root. Merge discovered references with
   the explicit resource allowlist in the target profile. Non-Markdown
   companions are included only by that allowlist and are not interpreted for
   embedded dependencies. Do not infer paths from arbitrary prose, scripts,
   or dynamic code. Raw HTML nodes with URL-bearing attributes (`src`, `srcset`,
   `href`, `poster`, `data` or `xlink:href`) are unsupported and block export,
   whether the value is local or external; requiring resource links to use
   parsed Markdown prevents a successful but incomplete package. Preserve
   each included companion resource's
   skill-root-relative path.

   Treat absolute Markdown destinations with ASCII-case-insensitive `https`,
   `http`, or `mailto` schemes as external links: preserve them verbatim in the
   unchanged body, do not fetch them, and exclude them from the package
   inventory. These three schemes are the external-scheme allowlist; reject
   other schemes unless a separately versioned target profile explicitly
   permits them. For local destinations, reject protocol-relative/rooted paths,
   query strings, malformed escapes, encoded separators, and traversal after
   percent-decoding exactly once and path normalization. A `#fragment` on the
   current document adds no resource; on a local file link, retain it as an
   anchor on that resolved file without changing the file path. Every
   discovered local destination must be present and included; unresolved
   references block export. Reject conflicting output paths and every source
   symlink, whether absolute, relative, internal or escaping. Do not preserve
   a symlink or dereference it into a regular output file; links create source
   coupling and ambiguous snapshots. The portable output contains only regular
   files and directories.
5. **Validate and publish.** A request for one or more skills is an
   all-or-nothing batch. Build the complete generation in a unique staging
   directory on the same filesystem as `<export-root>/generations/`; include
   every payload and one manifest. Run the pinned reference validator and
   structural checks for all selected skills. On any invalid, blocked, or
   failed member, publish none and leave the existing current pointer and
   generations untouched. On success, atomically rename the complete staging
   directory to the immutable `generations/<generation-id>` path, then write
   a temporary pointer file beside `<export-root>/current.json` and atomically
   create or replace that pointer with the generation id and SHA-256 of the
   exact serialized manifest bytes. Serialize pointer promotion under an
   exclusive publisher lock; if it cannot be acquired, fail without changing
   the current pointer.
   Readers use only the generation named by the pointer. A crash before pointer
   replacement leaves the old generation current and may leave an unreferenced
   immutable generation; it never exposes mixed payload and manifest state.
   Never replace or delete prior generations as part of publication. If the
   filesystem cannot provide same-volume atomic directory rename and pointer
   replacement, fail without publishing. Clean only exporter-owned staging
   paths.

No source or canonical export path is overwritten. A caller may select a
bounded set of skills, but each entry is independently reported and no failed
entry is represented as a successful portable artifact.

## Portable Field and Mapping Contract

| Field | Output contract | Projection and failure behavior |
| --- | --- | --- |
| `name` | Required string, 1-64 characters; lowercase ASCII letters/digits and single internal hyphens; equals directory name | Preserve the validated source value; missing, non-string, invalid, or mismatched values block the entry |
| `description` | Required non-empty string, 1-1024 characters | Preserve the validated source string; missing, non-string, empty, or over-limit values block the entry |
| `compatibility` | Optional string, 1-500 characters when present; environment requirements only | Omit by default. Emit only from an explicit target-profile mapping that provides a truthful requirement statement. Never join or reinterpret BaseCoat's host list |
| `license` | Optional string naming a license or a bundled license file | Preserve only an existing source string when explicitly allowed by the target profile. A file reference must resolve to an included regular companion under the same root/path rules; do not infer or coerce a license |
| `allowed-tools` | Optional experimental string, tokens separated by spaces | Emit only from a versioned mapping to exact native tool identifiers when the exact host proves both listed-tool success and unlisted-tool denial under an authoritative policy. Otherwise omit; if a required restriction cannot be proven, fail closed. No list-to-string conversion |
| `metadata` | Optional mapping of string keys to string values | Emit only named, allowlisted string fields. Omit nested or other non-string values; never stringify them. Do not expose private source metadata |
| Other BaseCoat fields | Not native portable fields unless explicitly supported by a pinned schema | Preserve in canonical source. Record field names and safe omission reasons in provenance; block if an omitted field carries required behavior or security policy |

BaseCoat's current `allowed-tools` list is source metadata; the source contract
does not establish that an empty list means deny-all or that a non-empty list
defines an enforceable allow-list. Do not infer either semantic. Preserve and
report it without projecting it unless a separately versioned, authoritative
source/target policy defines the exact meaning and mapping. If a mapping emits
the native `allowed-tools` field as a restriction, exact-host evidence must
show that an included tool succeeds and a tool excluded by that policy is
denied. If the host ignores the field, the profile is unsupported. If the
versioned policy explicitly marks a restriction required and that positive or
negative enforcement evidence is unavailable or fails, fail closed before
publication. A host-provided tool ceiling still applies. If policy intent
cannot be determined, mark it unresolved and block that requested
policy-dependent export rather than silently relaxing or inventing a
restriction.

The source repository remains unchanged. The emitted `SKILL.md` contains
projected frontmatter, so its complete bytes are not expected to match the
source file. Its Markdown body, defined as all original bytes following the
closing frontmatter delimiter, is copied byte-for-byte; source and emitted body
SHA-256 digests must match. Do not normalize line endings, trim whitespace, or
rewrite body links. A future body transformation requires a separately
versioned contract.

## Data Model and Storage Changes

The proposal introduces no repository data or runtime storage. A future
exporter emits an immutable generation separate from source, for example
`<export-root>/generations/<generation-id>/skills/<skill-name>/...` plus
`basecoat-export-manifest.json` in that generation. A small
`<export-root>/current.json` pointer names the active complete generation and
contains the detached manifest SHA-256. Staging and final generation paths
must be on the same filesystem.

The generation manifest records a path/digest inventory of all selected
portable-skill payload files. It excludes itself because embedding its digest
would be self-referential. If manifest integrity is required, emit a detached
checksum or signature outside the manifest; never claim an in-manifest
self-digest.

For each exported skill, the manifest records:

- Source repository identity, immutable commit, source directory and
  `SKILL.md` digest.
- Source and emitted `SKILL.md` body digests, which must be identical for a
  successful projection; full-file digests may differ because frontmatter is
  projected.
- Exported skill name, destination directory, exporter build and source-
  contract version.
- The source/output SHA-256 for each payload file. One generation-level
  `package_tree_digest` is computed from the canonical ordered inventory below;
  the manifest is excluded from that inventory and its own digest is carried
  by the detached generation pointer.
- Pinned portable schema revision, reference-validator version, target profile
  and host/version under test.
- An ordered mapping of source-relative path, output-relative path, content
  digest and inclusion/exclusion reason for every considered companion; a
  rejected symlink records only its safe relative path and failure reason.
- Field-level projection decisions, including license handling and any
  bundled license path, allowlisted metadata keys, compatibility mapping,
  native tool tokens, and omitted field names/reasons.
- Reference validation and host test identifiers/results, or an explicit
  `not-run`/`blocked` status with reason.

Do not place arbitrary source frontmatter, secret values, credentials, or
private resource content in the manifest. Digests and safe field names are
provenance, not a substitute for authorization.

### Digest and reproducibility contract

Each payload-file digest is SHA-256 over its exact emitted bytes. The
generation-level `package_tree_digest` is SHA-256 over this UTF-8 byte stream:

1. The literal header `basecoat-tree-v1\n`.
2. One record per regular payload file across all selected skills, using paths
   relative to the generation root (for example,
   `skills/example/SKILL.md`), sorted by normalized output-path UTF-8 bytes in
   ascending byte order. Each record is
   `<path>\0<byte-length-decimal>\0<lowercase-file-sha256>\n`.

Output paths use `/`, must be Unicode NFC, and may not contain NUL, `.`/`..`
segments, or case-colliding names; reject non-NFC source paths rather than
silently renaming them. Empty directories and the manifest are excluded.
`package_tree_digest` is the generation payload digest, not an unspecified
per-directory hash. Payload bytes, file digests and tree digest are
deterministic for the same source revision, exporter, schema and target
profile. The manifest may vary only in its explicit evidence fields
`generated_at_utc`, `run_id`, and host/validator test identifiers, outcomes and
log references; all other manifest fields must be deterministic. A detached
manifest checksum is computed after serialization and stored only in the
generation pointer.

## API and Interface Contracts

The future command/API must require an explicit source revision, skill
directory, destination, and target profile. A target profile identifies the
portable schema revision, reference validator, pinned Markdown parser and
supported resource syntax, optional compatibility text, license passthrough
policy, native allowed-tool mapping, and any authoritative versioned required
permission semantics. Defaults must not silently select all source skills or
a host. Tool semantics for the existing BaseCoat list are unresolved until
such a policy is specified; no allow/deny meaning is assumed by this contract.

Results are reported per skill, but publication is per request. A member may be
`valid-staged`, `blocked`, `invalid` or `failed` during evaluation. Return
`published` for every requested skill only after the whole generation and
pointer replacement succeed. If any member is not valid-staged, publish none,
report the specific member results, and leave the previous current generation
unchanged. Return non-zero unless the whole request is published.

## Security and Privacy Considerations

- Treat source YAML and Markdown as untrusted data. Use safe parsing; reject
  duplicate mapping keys at every depth and do not evaluate YAML tags,
  expressions, scripts, or embedded instructions.
- Enforce the frontmatter byte/depth/node caps and reject YAML anchors, aliases
  and merge keys before expansion. Enforce source-file, file-count, total
  payload, Markdown traversal and destination-count limits; cap breaches fail
  closed with no publication.
- Resolve paths before reads/writes. Reject absolute, traversal, all symlink,
  duplicate-output and case-collision paths; do not follow links, including
  links that currently point inside the source root.
- Require explicit field and companion allowlists. Do not leak `internal`,
  private, credentials, or unreviewed metadata into public native exports.
- A projected tool allow-list is not authorization. The adapter must check the
  actual host tool set and enforce required restrictions before invocation.
  If an authoritative versioned policy declares a restriction required,
  unknown mappings or unverifiable enforcement block publication/use; never
  fall back to unrestricted tools. BaseCoat `allowed-tools` list contents alone
  do not establish a restriction or deny-all mode.
- Do not execute companion scripts during export or validation. Host execution
  testing uses disposable, least-privilege fixtures with no production secrets.

## Reliability and Failure Modes

| Condition | Required result |
| --- | --- |
| Missing/malformed frontmatter, wrong scalar type, invalid required value, or directory mismatch | Mark entry invalid; report field/path; publish no generation |
| Unknown source/schema version or incomplete field mapping | Block; require explicit compatibility decision; no downgrade |
| Referenced companion or bundled license absent, excluded, ambiguous, or outside the root | Block; identify the reference and safe remediation |
| Resource reference is dynamic, malformed, uses an unsupported destination form, or cannot be resolved by the pinned Markdown parser | Block; require an explicit profile allowlist or a supported static relative destination |
| Raw HTML contains a URL-bearing resource attribute | Block; require supported Markdown resource syntax |
| Frontmatter, file size/count, total payload, link depth or destination-count cap is exceeded | Fail closed; discard exporter-owned staging and leave current generation unchanged |
| Parser, duplicate-key check, validator, host, or provenance step unavailable/fails | Report failed or blocked with stage and version; never claim success |
| An authoritative policy requires a restriction that cannot be exactly mapped or verified | Fail closed; do not emit/install an unrestricted substitute |
| Output write or pointer replacement interrupted | Current pointer continues to reference the prior complete generation; discard only exporter-owned staging, retain any unreferenced immutable generation for safe later cleanup |
| Host loader passes schema but ignores policy or companion references | Mark that host/profile unsupported; schema pass is not enforcement evidence |

Errors must identify the skill, field or resource, failed stage, and next
action without exposing secret content. No broad catch or silent omission of
required semantics is allowed.

## Schema Compatibility

Treat the BaseCoat source-contract version, Agent Skills schema revision,
reference-validator version, exporter version and native host/version as
independent compatibility coordinates. Pin all applicable versions in the
target profile and manifest. Validate against an immutable schema/reference
revision rather than a floating latest version. Maintain explicit supported
source-to-portable pairs; reject unknown versions and run fixture comparisons
before changing a pair. Optional portable fields may be absent. Native optional
fields, when emitted, must have their specified native types.

The current evidence is the frontmatter contract checked 2026-10-07 and its
linked upstream specification; no immutable validator release or measured
host-loader version is selected by this proposal.

## Testing Strategy

### Static and reference validation

- Positive fixtures for minimal required fields; optional native fields absent;
  valid compatibility string; string-to-string metadata; mapped tool tokens;
  optional string license identifiers; valid bundled license paths; and nested
  companion resources.
- Pinned Markdown-parser fixtures discover inline and reference-style relative
  links/images in `SKILL.md` and transitive Markdown companions; terminate
  cycles through a visited set; ignore code spans, code blocks and HTML
  comments; and merge the explicit allowlist without guessing from prose or
  dynamic script content.
- Boundary fixtures accept each stated inclusive parser/traversal/payload cap
  and reject one-over cases for frontmatter bytes, YAML depth/nodes, inspected
  file count, per-file bytes, aggregate emitted bytes, Markdown traversal depth
  and parsed destinations. Rejections publish no generation and preserve the
  previous pointer.
- Digest fixtures use a fixed multi-skill payload with Unicode NFC paths and
  assert exact canonical inventory bytes and SHA-256 independent of filesystem
  enumeration order. Non-NFC paths, case collisions and unsafe path segments
  fail before publication.
- Publication fault-injection fixtures fail validation, staging writes,
  generation rename and pointer promotion. A failed batch never moves the
  current pointer or changes prior generations; interruption after immutable
  generation rename leaves the old pointer resolving to a complete generation.
  Concurrent promotion is serialized by the publisher lock.
- Frontmatter containing duplicate keys at top level and inside nested
  mappings, including duplicate `allowed-tools`, is rejected before projection.
- Source and emitted `SKILL.md` bodies are byte-for-byte identical with matching
  body digests for empty, LF and CRLF body fixtures; frontmatter projection
  never normalizes, truncates or rewrites the body.
- Negative fixtures for absent, null, non-string, empty or over-limit required
  values; invalid names and directory mismatch; non-string optional values;
  invalid or unsafe license paths; nested metadata; unknown tool tokens;
  unsupported source/schema versions; missing direct or transitive resource
  references; cyclic Markdown links; preserved HTTPS/HTTP/mailto links that
  are excluded from the resource inventory; path traversal; unsupported
  schemes, query, encoded-separator and malformed-escape destinations;
  raw HTML with each URL-bearing attribute; relative internal, absolute
  internal, and escaping symlinks; and output collision. Verify empty/non-empty
  BaseCoat `allowed-tools` values do not acquire inferred allow/deny semantics
  absent an explicit policy.
- Snapshot source tree hashes before/after to prove export never mutates it.
  Assert that no source symlink is preserved or dereferenced into output.
- Assert failed cases produce no published artifact and no unrestricted
  fallback. Validate successful artifacts with the pinned `skills-ref validate
  <skill-directory>` and record the exact `skills-ref` release/commit.
- Require positive and negative exact-host permission evidence for any emitted
  enforcing `allowed-tools` mapping: a permitted listed tool succeeds and a
  tool excluded by the same authoritative policy is denied. If the host ignores
  the field or denial is not observable, the target profile remains unsupported.

### Pinned host/native-loader matrix

Run the following for every target profile claimed as supported. The supported
hosts/versions and test environment are **not yet established**; a unit-test
mock or schema validator does not fill these rows.

| Layer | Pin and evidence | Required positive cases | Required negative cases |
| --- | --- | --- | --- |
| Portable reference | Immutable Agent Skills schema revision and exact `skills-ref` version | Valid artifact accepted; relative resource inventory resolves | Invalid field type, name/directory mismatch, or unsafe/missing resource rejected |
| Native discovery and activation | Actual host product/build, extension/runtime version, OS and configuration | Skill discovered from intended export location, selected by realistic request, body loaded | Unlisted/unexported skill and near-miss request do not activate it |
| Companion loading | Same exact host build and exported tree digest | Referenced nested resource is available at its unchanged relative path | Missing/escaping resource is not silently resolved from source or outside root |
| Tool-policy enforcement | Same host build, observed available tool set and exact projected file digest | For an emitted enforcing mapping, a listed tool succeeds when policy permits | For that same mapping, a tool excluded by the authoritative policy is denied. Missing evidence, ignored field or failed denial test makes the profile unsupported; an empty source list is not inferred to deny tools |

Record exact host and validator versions, environment, exported payload file
digests, and any detached manifest checksum/signature, available tools,
request/expected result, observed result, logs and failure behavior. A host
profile with no accessible pinned loader remains
`unverified` and cannot be described as supported or enforcing restrictions.

## Rollout, Migration, and Rollback Plan

Documentation publication changes no runtime behavior. After separate source
approval and assignment, implement an opt-in export command and test fixtures
first. Pilot one explicitly selected skill and one pinned host in a disposable
environment. Keep bootstrap/sync distribution unchanged until a separately
reviewed adoption specifies destination ownership and migration. Expand profiles
only after the entire matrix passes. On regression, disable the affected
profile, stop publishing its artifacts, and remove only generated output;
canonical sources and existing installs remain untouched.

## Observability and Operational Readiness

Future runs should report source revision, target/profile and tool versions,
per-skill terminal state, output/manifest digests, test evidence references,
and sanitized error categories. Distinguish `not-run`, `unverified`, `blocked`
and `failed`; no metric may infer enforcement from export or schema success.
Do not log credential values or private frontmatter.

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Native loader silently ignores experimental tool policy | Require exact-host positive/negative tests; fail closed on unavailable evidence |
| Lossy coercion makes source behavior appear portable | Strict allowlisted mappings, omission accounting, immutable source and rejection of required unmappable fields |
| Companion resources are omitted or escape the package | Root-confined resolution, preserved relative paths, complete hashed inventory and reference tests |
| Export contains private source metadata or scripts | Explicit allowlists, safe manifest fields, no script execution and disposable tests |
| Schema/host drift invalidates old claims | Pin versions and artifacts; rerun compatibility matrix before profile promotion |
| Source-copy distribution is mistaken for a portable export | Keep distribution unchanged and label source/export artifacts separately |

## Open Questions

- Which safe YAML parser is already available in the exporter/validation
  runtime? It must reject duplicate mapping keys at every depth and unsafe tags;
  if none is available, parser/dependency selection remains blocked.
- Which target host/version has a pinned, accessible native loader suitable for
  controlled tests? If none is available, implementation acceptance for that
  target remains blocked.
- Which metadata keys are explicitly safe to export, and who owns each mapping?
- Should any distribution consumer adopt generated exports? That requires a
  separate source issue, approval and migration plan.
- What immutable upstream schema revision and `skills-ref` version will be
  pinned when implementation is authorized?

## Acceptance Criteria

- [x] Source assets remain canonical; this proposal does not convert or alter
  any runtime or distribution files.
- [x] Required and optional native field types, explicit mappings, omissions,
  provenance and schema-version boundaries are specified.
- [x] Companion resource handling and path-containment rules are testable.
- [x] Explicitly required tool restrictions fail closed; source list contents
  alone do not imply deny-all or authorization semantics.
- [x] Reference and exact-host positive/negative test matrices are defined, with
  unavailable host evidence explicitly unresolved.
- [ ] Implementation and native-loader tests are not authorized by this
  proposal and require separate source approval and assignment.

## References

- PRD: `docs/prd/synthesized/issue-3654-featskills-validate-portable-exports-separately-from-basecoa.prd.md`
- Refs #3654
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3654>
- Source/host contract: [`frontmatter-host-contract.md`](../../reference/frontmatter-host-contract.md)
- BaseCoat authoring contract: `instructions/basecoat-10-core-host-frontmatter.instructions.md`
- PRD/spec guidance: [`prd-and-spec-guidance.md`](../../guides/prd-and-spec-guidance.md)
- Agent Skills specification: <https://agentskills.io/specification>
