---
issue: 3655
title: "fix(validation): enforce Agent Skills required fields without conflating agent and skill schemas"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["bug", "priority:high"]
---

# Spec: fix(validation): enforce Agent Skills required fields without conflating agent and skill schemas

## Status and Decision

This is a documentation-only proposal for correcting validation boundaries.
It does not change validator code, add a parser, rewrite source files, approve
runtime work, or claim native host validation. Future implementation requires
separate source-issue approval and assignment.

## Context

At `scripts/validate-basecoat.ps1` lines 442-474, the current checks select both
`SKILL.md` and `*.agent.md`, search individual lines for optional fields, and
extract a name with a partial regex. This can miss missing/invalid names and
does not provide a full YAML type boundary. It also reports absent optional
portable fields as warnings. Source issue #3655 asks for safe parsing and
positive/negative tests without conflating skill and agent profiles.

## Scope

Define profile selection, safe frontmatter parsing, required skill fields and
types, complete name constraints, source directory identity, optional-field
handling, failure semantics and fixture coverage. Preserve BaseCoat-specific
source checks and separate native artifact validation from agent validation.

## Out of Scope

- Implementing the validator or adding/installing a YAML package.
- Changing agent or skill frontmatter, migrating the source catalog, or changing
  host behavior.
- Making portable optional fields mandatory.
- Proving export correctness or host enforcement; that evidence belongs to
  #3654's separate export and loader-test boundary.

## Schema and Profile Boundaries

Use one safe parser, if already supported, but select one explicit validator
profile per artifact. The caller must pass a trusted profile identifier and
repository-relative path; resolve the path beneath that profile's configured
root before reading. The root-to-profile mapping is trusted validator
configuration, not metadata from the file being validated. Do not infer a
profile from YAML fields, basename `SKILL.md`, or an untrusted path. Share
parsing primitives only; do not share a blended schema or run every profile
against every file.

Reject missing or unknown profile identifiers, conflicting profile/root
combinations, paths outside the selected root, symlink escapes and ambiguous
overlapping roots. Never guess another profile after a mismatch. Return an
explicit routing error with no schema pass when the caller omits profile
context or configured roots overlap.

| Profile | Applies to | Required fields and rules | Optional/present-field behavior |
| --- | --- | --- | --- |
| BaseCoat source skill | Canonical `skills/<directory>/SKILL.md`, selected only beneath the trusted source-skills root | Require one mapping with string `name` and `description`, plus the required canonical list-valued `compatibility` under existing BaseCoat source rules; enforce source-profile checks and exact parent-directory equality; run BaseCoat source extensions independently | Preserve source types and constraints for host-list compatibility and source tool-policy lists; native optionality does not weaken source requirements |
| Portable/native skill | Exported `<directory>/SKILL.md`, selected only beneath the explicitly configured export root | Require string `name` and `description`; enforce portable limits/name grammar and exact export-directory equality | `compatibility` optional string (1-500 chars); `license` optional string; `metadata` optional string-to-string mapping; `allowed-tools` optional space-delimited string. Validate a field's native type if present, but absence is valid |
| BaseCoat source agent | Canonical `agents/*.agent.md`, selected only beneath the trusted source-agents root | Require the BaseCoat source-agent contract, including required `name`, `description` and `visibility` | Apply BaseCoat agent-specific optional fields such as `tools` and `allowed_skills`; no skill fields or directory identity |
| Host-native agent | Explicitly staged host-agent artifact, selected only beneath the configured native-agent root and requested host profile | Require the selected host's contract; documented GitHub/CLI profiles require `description`, with `name` optional display metadata | Validate only fields supported by that host profile; do not impose BaseCoat source-agent requirements or skill fields |

An existing source validator may perform stricter BaseCoat authoring checks than
the portable schema. Those checks must be named and reported as source-profile
results, not silently treated as portable requirements. No one profile's
success implies another profile's success or host-loader acceptance.

## Required Skill Field Contract

### Frontmatter document

- Read the complete file and identify one opening and one closing frontmatter
  delimiter at the supported file positions. Parse only that frontmatter
  document, not fenced YAML or body examples.
- Require exactly one top-level YAML mapping. Reject malformed frontmatter,
  parser errors, non-mapping roots, duplicate required keys, and unsupported
  multiple-document input. Do not fall back to regex or accept a partial parse.
- Bound untrusted frontmatter before materializing the YAML object: maximum
  65,536 UTF-8 bytes, nesting depth 32 and 10,000 YAML nodes. Reject anchors
  and aliases (including alias expansion) and merge keys. Enforce byte, depth
  and node limits while streaming or through parser-native limits; a post-parse
  check is too late. If the selected safe parser cannot enforce these limits,
  treat it as unavailable.
- `name` and `description` must each be present exactly once and decode to YAML
  strings. Reject null, boolean, numeric, sequence, mapping, or other non-string
  scalar values. Quoted string values remain strings and are validated by their
  content.

### Name and directory identity

Both skill profiles require a YAML string `name` equal to the parent skill
directory basename; a missing or non-string name fails and cannot bypass the
identity check. In both BaseCoat source and portable profiles, require a
1-64-character name matching `^[a-z0-9]+(?:-[a-z0-9]+)*$`: lowercase ASCII
letters and digits separated only by single internal hyphens. Reject uppercase,
whitespace, underscores, Unicode lookalikes, leading/trailing hyphens,
repeated hyphens and values over 64 in either skill profile. This corrects the
source validator's partial extraction of invalid names; do not weaken the
source contract to preserve that parsing defect. Existing source files are not
rewritten by this proposal; any failing source path must be reported for
separately reviewed remediation. Agent profiles are not skills and have no
skill-directory identity rule.

### Description and optional fields

Both skill profiles require a YAML string `description`. The BaseCoat source
profile's existing check is 1-1024 characters, and the portable profile
independently requires the same 1-1024-character bound. Equal limits do not
merge the source and native schemas. The portable schema does not require `compatibility`, `metadata` or
`allowed-tools`; their omission is valid. The source profile still requires its
canonical BaseCoat list-valued `compatibility` field under the existing source
rules; native optionality does not weaken or redefine it. In the portable
profile, when present, `compatibility` must be a 1-500-character string,
`license` a string, `metadata` a mapping whose keys and values are strings,
and `allowed-tools` a string containing the space-delimited tool identifiers
accepted by the pinned native validator. Do not reinterpret source lists or
nested BaseCoat policy as native values.

Optional native fields are not mandatory source fields. Existing BaseCoat
source-profile requirements remain separate and must not be weakened as a
side-effect of making portable optional fields optional.

## Parser and Type-Safety Contract

Use a safe YAML parser supported by the repository's existing validation
runtime. Do not deserialize with object construction, execute custom tags,
evaluate content, or inspect field types by textual substring. Record and test
the parser/runtime version and YAML dialect so implicit scalar resolution is
deterministic. Reject duplicate keys rather than accepting a parser-dependent
first- or last-value result.

The current validator code shown in the source issue uses line regexes and does
not establish that a safe YAML parser is already available. Parser choice and
availability are an implementation prerequisite, not a decision made here.
If no supported safe parser with the required duplicate-key/type behavior
exists, report the dependency/design blocker and stop; do not add an unapproved
dependency or fallback parser.

## Failure and Diagnostic Contract

Return validation failure for malformed syntax, missing delimiters, invalid
root shape, duplicate keys, missing required fields, wrong YAML types,
out-of-range values, invalid names and source directory mismatch. Report
repository-relative file path, selected profile, field and concise reason.
Do not echo untrusted YAML values when doing so could expose private content.

Parser absence, parser/runtime mismatch, an unsupported profile, or inability
to establish the correct file context is an explicit validation error, never a
warning-only pass or skip. Aggregate independent field errors when parsing is
unambiguous; after parse failure, do not invent field-level conclusions from
regex text.

## Testing Strategy

Fixtures must be isolated by profile and assert both result and diagnostic.

### Positive fixtures

- Minimal portable skill with only string `name` and `description`.
- Minimal portable skill at `<name>/SKILL.md` passes; a syntactically valid
  name that differs from the exported directory fails.
- Frontmatter at the 65,536-byte, depth-32 and 10,000-node limits passes; one
  byte over, depth 33, 10,001 nodes, any anchor/alias, or a merge key fails
  before schema validation.
- Valid shortest and 64-character names and 1-character and 1024-character
  descriptions in both skill profiles; source fixtures also verify that valid
  canonical assets pass without weakening the source checks.
- Optional portable fields omitted; valid compatibility/license strings,
  string-to-string metadata, and allowed-tools string when present.
- Valid BaseCoat source skill with its allowed source-specific list/object
  fields, required source-list `compatibility`, current source
  name/description checks and directory match preserved.
- Valid agent profile using agent-only fields and no skill-specific directory.
- Valid BaseCoat source agent with `name`, `description` and `visibility`, and
  valid host-native agent with only required `description`; each passes only
  when selected with its matching trusted root/profile.
- YAML body containing fenced examples that must not be parsed as frontmatter.

### Negative fixtures

- Missing, duplicate, null, empty, numeric, boolean, sequence or mapping
  `name`/`description`; malformed YAML, missing delimiters, non-mapping root,
  duplicate keys, multiple documents, frontmatter over 65,536 bytes, nesting
  deeper than 32, more than 10,000 nodes, anchors, aliases and merge keys.
- Missing or wrong-type BaseCoat source `compatibility` fails the source
  profile; its requiredness and list type do not transfer to the portable
  profile.
- Invalid source and portable name characters/case, leading/trailing/
  consecutive hyphens and over-length names; source/exported name-directory
  mismatches in their respective skill profiles.
- Description lengths 0 and 1025 in both skill profiles; non-string optional
  native fields, non-string metadata keys/values and invalid metadata root type.
- Agent fixture with no skill-only fields must pass its agent profile; invalid
  skill fixture must not be hidden by the agent path; BaseCoat source-only
  shapes must not be mistaken for native portable types.
- Missing/unknown profile, wrong profile for configured root, path traversal,
  overlapping roots, symlink escape and an attempt to select profile from
  frontmatter all fail as routing errors before schema evaluation.
- Parser unavailable or unsupported profile must fail explicitly with no
  partial or warning-only success.

Run fixture tests on each supported OS/runtime to detect YAML scalar
coercion differences. Preserve representative current assets as regression
fixtures without rewriting them in this proposal.

## Implementation Plan

1. Inventory the validation runtime and establish an already-supported safe
   parser's version, YAML dialect, duplicate-key behavior and type mapping.
   If unavailable, stop for a separately approved dependency decision.
2. Add profile-specific parse/validation entry points and precise diagnostics.
   Replace the `SKILL.md` line-regex path with parsed source/native skill
   validators; route source and native agent files through separate profile
   validators using trusted root configuration.
3. Add profile-isolated positive/negative fixtures and regression tests for
   current source-specific validation.
4. Run targeted validator fixtures, `pwsh scripts/validate-basecoat.ps1`,
   `pwsh tests/run-tests.ps1`, and Windows/Unix CI checks. Validate portable
   exports separately under #3654.

No step is authorized by merging this proposal.

## Rollout, Migration, and Rollback Plan

Stage new checks in tests and validation tooling before making them blocking.
Compare current source results and diagnostics; treat new source failures as
regressions unless they match the explicitly documented invalid cases. Keep
portable validation scoped to explicit exports. Promote CI enforcement only
after profile fixtures pass on supported platforms. Revert profile wiring if
false positives occur; do not auto-edit assets or lower source checks to
silence a profile mismatch.

## Risks and Mitigations

| Risk | Mitigation | Mitigation owner | Validation |
| --- | --- | --- | --- |
| Parser scalar coercion differs by runtime, duplicate keys are accepted, or hostile YAML exhausts resources | Pin the already-supported parser/runtime; reject duplicates, anchors and aliases; enforce byte/depth caps during parse | Future validator implementer, named only after separate approval | Run scalar, duplicate, 65,536-byte/32-depth boundary and alias-expansion fixtures on each supported OS/runtime |
| Source and native files route through the wrong profile | Require trusted profile/root input and fail on missing or conflicting context | Future validator implementer, named only after separate approval | Run profile/root mismatch, path traversal, overlap and wrong-profile fixtures |
| Source compatibility or existing source name/description checks are weakened | Preserve the required source host-list field and record source-corpus regressions separately | Source-catalog maintainer, designated before implementation | Run full source-catalog validation and compare profile-specific results before changing blocking CI |
| Agent files are accidentally rejected by skill rules | Keep agent profiles separate and route only from trusted configuration | Future validator implementer, named only after separate approval | Run BaseCoat-source-agent and host-native-agent fixtures, including mismatched-profile failures |
| Portable optional fields become de facto required | Keep portable optional-field checks presence-based | Future validator implementer, named only after separate approval | Run minimal portable skills with all optional fields omitted and invalid-present-field cases |
| No supported safe parser is available | Stop for dependency review; no regex or unsafe fallback | Validation-runtime maintainer, designated before dependency review | Verify current runtime support and duplicate-key behavior before implementation proceeds |
| Schema pass is represented as loader proof | Separate validation results from actual host evidence | Host-integration owner, named in a separately approved integration issue | Run #3654's pinned host matrix; until host/version exists, report `unverified` |

## Observability and Operational Readiness

Future validator output should identify the profile and parser/runtime version,
report pass/fail counts and sanitized path/field diagnostics, and distinguish
source, portable and agent outcomes. It must not label parser skip as success
or emit sensitive field values. CI must retain the exact fixture command and
platform for reproducibility.

## Open Questions

- Which safe YAML parser is already available in the validation runtime, and
  does it expose duplicate-key rejection and stable YAML scalar types?
- Which current source-only validation rules are contractually required and
  need profile-specific regression fixtures?
- Which immutable Agent Skills schema and validator version will govern native
  optional-field checks?
- Which host/version can run #3654's real native-loader matrix? Availability is
  not established by this proposal.

## Acceptance Criteria

- [x] Required portable skill fields, YAML types, name grammar, lengths and
  source directory matching are explicit.
- [x] Agent, BaseCoat source-skill and native exported-skill schemas are
  separate; optional native fields remain optional.
- [x] Safe parsing, duplicate-key handling, explicit failure and parser
  availability constraints are documented.
- [x] Positive and negative fixture classes cover field, type, profile and
  parser-boundary behavior.
- [ ] Implementation, parser selection and runtime test results remain pending
  separate source approval and assignment.

## References

- PRD: `docs/prd/synthesized/issue-3655-fixvalidation-enforce-agent-skills-required-fields-without-c.prd.md`
- Refs #3655
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3655>
- Source/host contract: [`frontmatter-host-contract.md`](../../reference/frontmatter-host-contract.md)
- BaseCoat authoring contract: `instructions/basecoat-10-core-host-frontmatter.instructions.md`
- Validator: `scripts/validate-basecoat.ps1`
- PRD/spec guidance: [`prd-and-spec-guidance.md`](../../guides/prd-and-spec-guidance.md)
- Agent Skills specification: <https://agentskills.io/specification>
