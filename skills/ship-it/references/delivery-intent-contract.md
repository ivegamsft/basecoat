# Delivery Intent Contract

## Alias and Dispatch Rules

`ship-it: <goal>` and `spec-2-prod: <goal>` are aliases for the existing
canonical `ship-it` and `spec-2-prod` intents, not new delivery engines.
Normalize the token case-insensitively and trim outer whitespace; preserve the
raw directive and goal for audit. Workflow inputs accept exact canonical enum
values only. Legacy slash commands retain their existing title fallback.

Require a nonempty colon goal. Reject token lookalikes, dual/conflicting
directives, and quoted, fenced, bulleted, embedded, or agent-authored commands.
Read-only, log-only, and deferred modifiers suppress side effects; contradictory
immediate/stop modifiers block. Never add aliases such as `ship-to-prod:`.

Validate the authorized source issue, approved scope, non-placeholder spec,
current actor permission, and required plan confirmation. Approval and delivery
consent are distinct; a delivery command must not assign a cloud agent or add an
approval label. Record canonical intent, original actor, and evidence URL/time
in the existing dispatch summary and handoff. Do not fabricate a maintainer
comment to translate chat syntax.

## Feature-Origin Handoff

Preserve the source issue markers and scope:

```text
<!-- basecoat-feature-origin:v1 -->
BaseCoat Source scope: <approved feature scope>
```

Link the feature PR to that issue and include
`<!-- basecoat-feature-handoff:v1 source-issue:#<number> -->` in the PR body.
Markers establish provenance, not consent. Keep the PR draft until a separate
qualified delivery directive is validated. The merge evaluator independently
requires the open approved issue, non-placeholder Spec URL, exact qualified
`/approve`, and explicit qualified delivery evidence. A missing or conflicting
directive, changed scope, or invalid evidence blocks promotion. Never infer
delivery from `feature:`, an approved design, green checks, or
`pr-lifecycle=full`; never synthesize approval or delivery comments.

## Existing Delivery Gates

Routing is not a gate waiver. Preserve current-head required checks and human
review under risk/size policy, serialized merges, production environment
approval, rollback evidence, and post-release verification. XXL changes above
2000 lines still require qualified human PR review. A missing gate or
unattended human-evidence requirement remains blocked; it must not be bypassed
by aliases or prior issue approval.
