---
issue: 3655
title: "fix(validation): enforce Agent Skills required fields without conflating agent and skill schemas"
status: proposal
author: ibuyspy
created: 2026-10-07
labels: ["bug", "priority:high"]
---

# PRD: fix(validation): enforce Agent Skills required fields without conflating agent and skill schemas

## Problem Statement

`scripts/validate-basecoat.ps1` applies a partial Agent Skills line-regex check
to both `SKILL.md` and `.agent.md`. It can miss missing, malformed or
consecutive-hyphen skill names, does not reliably parse YAML types or complete
values, checks the skill-directory match only when a name was extracted, and
warns when optional native fields are absent. Agent profiles are not portable
Agent Skills documents, so applying skill rules to them creates false errors
and warnings.

## Goals

- Define an explicit safe-YAML parsing and validation contract for BaseCoat
  source skills, exported native skills, BaseCoat source agents and host-native
  agent profiles.
- Enforce required skill field presence, scalar types, bounds, full name syntax
  and source-directory identity without extracting partial values by regex.
- Preserve existing BaseCoat-specific source-profile checks without presenting
  them as portable requirements.
- Define separate BaseCoat source-agent and host-native-agent required fields;
  source agents require `name`, `description` and `visibility`, while the
  documented GitHub/CLI native profile requires `description` and makes
  `name` optional.
- Specify positive and negative fixtures, parser failure behavior and clear
  diagnostics before implementation is separately authorized.

## Non-Goals

- Implement or change the validator, parser dependency, fixtures, or source
  assets in this documentation-only proposal.
- Require portable optional fields such as `compatibility`, `metadata` or
  `allowed-tools` merely because they are absent.
- Apply Agent Skills schemas to `.agent.md` profiles or turn source validation
  into proof of export validity or host enforcement.
- Perform portable export or host-loader integration defined separately by
  #3654.

## User Personas and Use Cases

Skill authors need malformed or incomplete skill frontmatter to fail with a
specific path and field diagnostic; valid minimal portable skill fixtures must
not be rejected for omitting optional fields. Agent authors need agent profiles
evaluated by their own source/native contract rather than skill requirements.
Maintainers need validation results that distinguish BaseCoat source checks
from native artifact checks.

## User Experience Summary

A future validator identifies the artifact profile from its explicit file
context, safely parses the complete frontmatter mapping, and reports each
profile's required fields and type/boundary violations. Parse failure,
ambiguity or unsupported YAML fails validation; no regex fallback or warning-
only success is permitted for required skill defects.

## Functional Requirements

1. Require the caller to select a trusted validator profile and repository-
   relative path beneath that profile's configured root. Do not infer profile
   from frontmatter or filename. Missing, unknown, conflicting or untrusted
   profile/root context is a routing failure; never retry another schema.
2. Use a safe YAML parser for the complete frontmatter mapping. Do not execute
   YAML tags, parse with line-regex extraction, or validate fenced examples as
   if they were file frontmatter. Before object materialization, enforce a
   65,536-byte UTF-8 frontmatter cap, nesting depth no greater than 32 and no
   more than 10,000 YAML nodes; reject anchors, aliases and merge keys.
   Unsupported parser limits fail closed.
3. In both BaseCoat source-skill and explicit portable-skill profiles, require
   exactly one top-level `name` and `description`, both YAML strings, and apply
   the shared required-skill identity rules below. Keep source-only extensions
   and portable-only optional fields in their separate schemas.
4. For both source `skills/<directory>/SKILL.md` and exported
   `<directory>/SKILL.md`, require the parsed name to match that skill
   directory exactly. Missing or non-string names must not bypass the check.
   BaseCoat source agents and host-native agents are separate profiles; agent
   profiles have no skill-directory identity rule.
5. In both skill profiles, require string `name` and `description`, exact
   name/directory identity and the 1-64-character skill grammar
   `^[a-z0-9]+(?:-[a-z0-9]+)*$` (lowercase ASCII letters and digits separated
   by single internal hyphens). This closes the source validator's partial-
   extraction bug for edge/repeated hyphens without rewriting source assets;
   report any existing failing source path for separate remediation. Apply
   the existing BaseCoat 1-1024-character description check to source files
   and independently require the same bound for native skills. Reject missing,
   null, non-string and empty required values. Agent fields follow their
   respective independent schemas.
6. Keep BaseCoat source-skill extensions, portable exported-skill schema,
   BaseCoat source-agent schema and host-native agent schema separate. Preserve
   the source skill's required canonical list-valued `compatibility` under
   existing BaseCoat rules; its requiredness does not transfer to the native
   profile, where portable `compatibility` is an optional string. Other
   optional portable fields remain optional; when a profile validates a field
   that is present, enforce its type there rather than treating omission as an
   error.
7. Report parse and validation failures with artifact path, selected profile,
   field and actionable reason. A missing parser or parse error fails closed;
   do not silently skip validation.
8. Add positive/negative fixtures covering required names/description, YAML
   types, source/native bounds, hyphen grammar, directory identity, all four
   profiles, optional-field omission and malformed YAML.

## Requirements Traceability

| PRD requirements | Spec section | Verification evidence |
| --- | --- | --- |
| 1, 6 | Schema and Profile Boundaries | Trusted-root and wrong-profile routing fixtures |
| 2, 7 | Parser and Type-Safety Contract; Failure and Diagnostic Contract | Parser-unavailable, malformed-YAML, duplicate-key, resource-limit and field-diagnostic fixtures |
| 3-5 | Required Skill Field Contract | Source/native skill boundary, compatibility, name, type and length fixtures |
| 8 | Testing Strategy | Profile-isolated positive/negative fixtures across supported runtimes |
| Success metrics | Testing Strategy; Failure and Diagnostic Contract | Fixture result/diagnostic assertions and portable optional-field omission checks |

## Non-Functional Requirements

- Deterministic results across supported validation environments.
- Bounded YAML size/depth/node count and rejected aliases prevent untrusted
  frontmatter from causing unbounded parser resource use in CI.
- No execution or unsafe deserialization of frontmatter.
- Preserve current legitimate BaseCoat source acceptance except for explicitly
  documented defects; do not convert warnings for optional native fields into
  required checks.
- Diagnostics distinguish parser failure, source-profile violation and native
  schema violation.

## Success Metrics

- Every required field/type/name/directory negative fixture fails for the
  expected reason; every valid boundary positive fixture passes.
- Minimal native skill documents without optional fields pass native schema
  checks when their `name` matches the exported skill directory.
- BaseCoat source-agent, host-native-agent, source-skill and exported-skill
  fixtures route only to their respective profiles. Both source and exported
  skill directory mismatches fail under their respective profiles.
- All four profiles produce distinct results; none is reported as host-loader
  evidence.

## Constraints and Assumptions

The host-aware contract in
`docs/reference/frontmatter-host-contract.md` and
`instructions/basecoat-10-core-host-frontmatter.instructions.md` distinguishes
BaseCoat skill source, portable `SKILL.md`, BaseCoat source agents and
host-native agents. Require the shared strict skill-name grammar and directory
identity in both skill profiles; this corrects the documented partial-regex
defect but does not rewrite any source assets. Keep BaseCoat's required host-
list compatibility separate from portable optional string compatibility.
Apply and test the source's existing 1-1024 description bound and the same
numeric bound independently in the native skill profile. BaseCoat and native
agent contracts remain independent. The validator's current line-based code does not establish
an existing safe YAML parser. Parser availability and duplicate-key behavior
must be verified before implementation. If none is already available,
dependency selection requires separate review; do not install a package or
add an unsafe/regex fallback under this proposal.

## Risks and Open Questions

- YAML parser libraries may coerce plain scalars into booleans, numbers, nulls,
  or collections; all such non-string required values must fail consistently.
- Duplicate keys and parser-specific YAML versions can create inconsistent
  interpretations. The selected parser must reject duplicate keys and unsafe
  tags consistently across CI platforms; parser availability remains unresolved.
- The existing source profile includes BaseCoat-only fields. Which current
  source-specific validation rules should remain in the source schema beyond
  the required name/description checks?
- Native export validation and actual host loading are separate deliverables;
  #3654's pinned host availability remains unresolved.

## Dependencies

- Current BaseCoat source and host contract documentation.
- A safe YAML parser already supported in the chosen validator runtime, or a
  separately approved dependency decision if none is available.
- #3654 for portable export projection and reference/host-loader validation;
  this proposal does not duplicate or implement that boundary.

## Rollout and Adoption Plan

This PR only publishes a proposal. Future implementation must be separately
approved and assigned. First introduce profile-specific fixtures and validator
diagnostics, then run the existing validation suite on Windows and Unix before
changing CI behavior. Preserve source-profile rules and report schema results
by profile. Roll back validator wiring independently if false positives or
cross-profile regressions occur; do not rewrite source frontmatter as a
workaround.

## References

- Refs #3655
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3655>
- Source/host contract: [`frontmatter-host-contract.md`](../../reference/frontmatter-host-contract.md)
- Validator: `scripts/validate-basecoat.ps1`
- PRD/spec guidance: [`prd-and-spec-guidance.md`](../../guides/prd-and-spec-guidance.md)
- Agent Skills specification: <https://agentskills.io/specification>
