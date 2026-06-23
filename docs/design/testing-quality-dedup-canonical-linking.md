# Testing and Quality Dedup and Canonical Linking Rules

## Context

Issue: #1735  
Parent feature: #1737 (Wave 2)

Multiple finding sources produce overlapping remediation records. Without
deterministic dedupe, teams create parallel issues for the same root problem.

## Design Goals

1. Define deterministic dedupe keys across security and quality signals.
2. Enforce a single canonical issue per unique remediation target.
3. Preserve source traceability using required cross-links.
4. Resolve canonical conflicts without manual arbitration loops.

## Dedupe Key Algorithm

Canonical dedupe key:

`<finding_source>|<rule_or_advisory>|<package_or_component>|<affected_surface>|<owner_scope>`

Where:

- `finding_source`: `codeql`, `dependabot`, `secret-scan`, `quality-review`
- `rule_or_advisory`: CVE/GHSA/rule id/check id
- `package_or_component`: package name or subsystem id
- `affected_surface`: repo + path (or workflow/file target)
- `owner_scope`: owning team or service boundary

## Canonical Selection Rules

Given matching dedupe keys, select canonical in this order:

1. Highest severity.
2. Earliest created record.
3. Record with existing remediation PR link.
4. Lowest numeric issue id (stable tie-breaker).

Non-selected records must be marked `duplicate` and linked to canonical.

## Cross-Link Contract

Every canonical issue must include:

1. Source alert links (all contributing sources).
2. Remediation PR links.
3. Verification evidence links.
4. Backlinks from duplicate issues to canonical issue.

Every duplicate issue must include:

- `duplicate_of: <canonical_issue_id>`
- source-specific context not present in canonical issue

## Conflict Handling

When two canonical candidates are created concurrently:

1. Recompute selection rules with latest metadata.
2. Keep winner as canonical.
3. Convert loser to duplicate and preserve unique source evidence.
4. Emit an audit event with old/new canonical ids.

If conflicting severity values exist, canonical severity is max severity;
lower-severity signals are retained as annotations.

## Enforcement Points

1. **Intake time:** pre-create dedupe check before opening issue.
2. **Triage update:** re-run dedupe check when severity or owner changes.
3. **Pre-resolve gate:** block resolve if unresolved duplicates remain.

## Acceptance Criteria Mapping

- [x] Deterministic dedupe algorithm documented.
- [x] Canonical vs. duplicate handling defined.
- [x] Linkage requirements included in workflow contract.
