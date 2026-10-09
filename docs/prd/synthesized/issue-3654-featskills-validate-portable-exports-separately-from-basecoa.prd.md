---
issue: 3654
title: "feat(skills): validate portable exports separately from BaseCoat source frontmatter"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["enhancement", "priority:high"]
---

# PRD: feat(skills): validate portable exports separately from BaseCoat source frontmatter

## Problem Statement

BaseCoat skill source is intentionally richer than portable Agent Skills
frontmatter. The current source catalog uses list-valued host compatibility and
tool policy plus non-string metadata; installation and sync copy source files
without demonstrating a native-format projection. Treating a source file as a
portable export can therefore produce invalid fields or imply tool restrictions
that a host does not enforce.

The existing inventory reviewed on 2026-10-07 covered 143 source skills: all
had valid required names, directory matches, and description lengths, while
142 used list-valued compatibility, 142 used list-valued `allowed-tools`, and
all 143 used non-string metadata values. This is an inventory, not a reference
validator run or a host-loader test.

## Goals

- Define an opt-in, deterministic portable export boundary that never rewrites
  canonical BaseCoat source assets.
- Specify native field types and explicit, reviewable mappings for compatible
  source values; leave canonical source bytes unchanged and preserve provenance.
- Make companion-resource copying, provenance, schema compatibility, security
  and failure behavior testable.
- Require pinned reference validation and measured native-loader tests before
  any host-support or enforcement claim.

## Non-Goals

- Convert, normalize, or rename every source skill, or change existing bootstrap,
  install, package, or sync behavior.
- Change runtime tools, skill invocation, permissions, or host discovery.
- Stringify arbitrary YAML objects, lists, or policy values to make them appear
  portable.
- Treat documentation publication, a supported-host name, schema validation,
  or a successful export as proof of host enforcement or implementation approval.
- Expand this proposal into the separate source-validator correction in #3655.

## User Personas and Use Cases

Asset maintainers need to export a specifically selected skill for a declared
native target while retaining the governed source as the reviewable authority.
Host integrators need to know which resource files were emitted, which source
revision produced them, which fields were transformed or omitted, and whether
required tool policy was actually enforced.

## User Experience Summary

A future caller explicitly selects a source skill and target profile. The
exporter stages a separate portable skill directory and provenance manifest,
validates it, then either reports a complete artifact or a specific blocked
reason. It must not silently fall back to copying the source or return a
success-shaped partial package.

## Functional Requirements

1. Resolve the source skill root and `SKILL.md`; do not modify any source file.
   Emit the portable artifact at a separate destination with validated string
   `name` and `description`. Cap frontmatter at 65,536 UTF-8 bytes, YAML depth
   at 32 and node count at 10,000; reject anchors, aliases, merge keys and
   duplicate mapping keys before value construction. The emitted frontmatter
   is projected; only the Markdown body bytes after the closing delimiter must
   be byte-identical to the source body.
2. Emit optional native `compatibility` only as a truthful environment-requirement
   string of 1-500 characters. BaseCoat's host list is not that string and must
   not be joined, renamed, or inferred as one. Omit it unless an explicit
   target-profile mapping supplies the statement.
3. Emit optional native `allowed-tools` only as the explicitly mapped,
   space-delimited experimental string of native tool identifiers. Never use
   `compatibility` as a host selector or a tool list as an authorization grant.
4. Emit optional `license` only when the source value is already a string and
   the target profile explicitly permits it. Preserve the value; if it
   references a bundled file, that file must be included through the companion
   rules below. Do not infer a license from repository files or coerce a
   non-string source value.
5. Emit optional `metadata` only as an explicitly allowlisted map of string
   keys to string values. Do not stringify nested values. Preserve unsupported
   BaseCoat fields in source; record safe field names and omission reasons in
   provenance without copying private values.
6. Preserve each included companion file's path relative to the skill root.
   Include referenced resources under a documented include policy; exclude
   authoring-only files such as eval fixtures unless explicitly needed. Bound
   each file at 8 MiB, the complete payload at 64 MiB, the inspected tree at
   256 files, Markdown traversal at depth 32 and parsed destinations at 4,096.
   A limit breach, license-referenced, referenced-but-excluded, missing, or
   unsafe resource blocks export. Reject every source symlink, including links
   whose target currently resolves inside the skill root; never preserve a
   link into source. Raw HTML resource attributes are unsupported and block
   export rather than being silently omitted.
7. Preserve the original Markdown body of `SKILL.md` byte-for-byte after
   projecting frontmatter. Record source and emitted body digests and require
   equality; any future body transformation needs a separately versioned,
   explicitly tested contract.
8. Write a separate export manifest mapping every portable-skill payload path
   (excluding the manifest itself) to its source path and content digest.
   Record repository, source revision, source path and digest, exporter
   version, source-contract version, pinned native schema and reference-
   validator versions, target profile, tool mapping, included and omitted
   companion inventory, license mapping, body digests, and validation results.
   The payload digest is SHA-256 over the versioned, canonical path/size/file-
   digest inventory defined in the spec. The manifest cannot contain its own
   digest; if manifest integrity is required, place its detached checksum in
   the generation pointer. Do not put BaseCoat-only metadata into the portable
   skill directory solely for provenance.
9. Treat required tool restrictions as security policy only when an
   authoritative, versioned source or target policy explicitly declares them
   required. BaseCoat's current `allowed-tools` list is source metadata whose
   semantics are not established as a restriction; neither an empty nor
   non-empty list means deny-all/allow-list by inference. Preserve and report
   it without conversion unless a separately versioned mapping defines its
   meaning. Once a required restriction is established, an unmappable or
   unverified policy must fail closed before publication.

## Non-Functional Requirements

- Deterministic portable payload bytes and tree digest for identical source,
  exporter, schema and target profile. Only `generated_at_utc`, `run_id`, and
  named host/validator evidence fields may vary in the provenance manifest.
- Atomic all-or-nothing publication per requested batch using an immutable
  generation plus a same-filesystem atomic pointer replacement. Preserve the
  prior generation and pointer on any failure.
- Path containment: reject absolute paths, traversal, and every source symlink;
  never preserve or dereference a link into the portable output.
- Bounded parsing/traversal: enforce the frontmatter, depth, node, file-count,
  per-file, total-payload and resource-reference caps before publication.
- Reproducible provenance with no credentials, private source text, or secrets.
- Unknown source-contract or native-schema versions fail with an actionable
  diagnostic; no implicit downgrade or lossy conversion.

## Success Metrics

- 100% of exports leave canonical source bytes unchanged and contain a
  complete path/digest mapping for every portable-skill payload file,
  explicitly excluding the separate manifest; the versioned tree digest is
  reproducible and the manifest checksum is detached. Projected frontmatter
  may differ, but the emitted Markdown body must retain its source digest.
- 100% of successful projections preserve the original `SKILL.md` body bytes
  and match its recorded digest; duplicate YAML keys never reach projection.
- 100% of malformed, unsupported, or security-sensitive required mappings
  block publication; no partial artifact is reported as successful.
- Requests exceeding any parser, traversal or payload cap publish no
  generation and do not move the current pointer.
- Every supported target profile has a pinned validator result and a recorded
  native-loader test matrix; otherwise that target remains unverified.
- No compatibility list, nested metadata value, or unverified tool restriction
  is silently converted or described as enforced.

## Constraints and Assumptions

The source contract and portable Agent Skills schema are separate profiles.
The portable field baseline is documented in
`docs/reference/frontmatter-host-contract.md`; its checked upstream reference
is not a measured result for all installed hosts. The implementation must pin an
immutable schema/reference and toolchain version. No currently available,
pinned native-loader environment is established by this proposal. Existing
bootstrap and sync copying behavior remains unchanged until a separately
authorized design adopts an export boundary.

## Risks and Open Questions

- Host loaders may ignore experimental `allowed-tools` or expose no explicit
  deny-all mode. Required restrictions then make that target unsupported.
- Source companion references may rely on files outside a skill directory;
  such dependencies must be surfaced and resolved, never copied implicitly.
- Large or highly linked skills can exceed the proposed parser/traversal caps;
  report the exact exceeded limit and leave the prior export generation active.
- A filesystem without same-volume atomic publication or a contended publisher
  lock cannot safely promote a generation; block the export rather than
  falling back to partial writes.
- No pinned host-loader environment or credentials have been established. Which
  host/version can run controlled discovery, activation and permission tests?
- Is a safe, existing YAML parser available to the chosen exporter runtime? If
  not, parser/dependency selection requires separate implementation review.
- Which source metadata keys are safe and useful to allowlist for each target?

## Dependencies

- #3655's separate frontmatter schema-validation proposal.
- A pinned Agent Skills schema/reference validator and explicit target profiles.
- Controlled host/version test environments with a real loader and observable
  available tools; simulation alone is insufficient.

## Rollout and Adoption Plan

This PR only publishes a proposal. Future implementation must be separately
approved and assigned. Start with an opt-in, explicitly selected skill and
target; keep current source distribution untouched. Promote a host profile only
after native loader evidence passes. Roll back by disabling that export profile
and removing its generated artifacts; canonical sources remain unchanged.

## References

- Refs #3654
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3654>
- Source/host contract: [`frontmatter-host-contract.md`](../../reference/frontmatter-host-contract.md)
- PRD/spec guidance: [`prd-and-spec-guidance.md`](../../guides/prd-and-spec-guidance.md)
- Agent Skills specification: <https://agentskills.io/specification>
