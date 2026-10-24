# Roadmap persistence decision prerequisite

Status: owner selected option A (original GitHub milestones) on 2026-10-09.
Issue #3694 remains a prerequisite to live persistence in #3616; the manual closure
of parent #3400 does not satisfy its children's technical acceptance. This
document does not approve a replacement design, enable writes, or demonstrate
the original milestone-assignment concurrency guarantee.

## Dependency-ordered delivery plan

| Wave | Issue | Required outcome |
| --- | --- | --- |
| 1 | #3694 | Decide a persistence contract with demonstrable concurrency protection. |
| 2 | #3616 | Deliver approved persistence, authenticated plan authority, resumable checkpoints and artifact publication. |
| 3 | #3617 | Deliver default-off runtime integration, bounded reconciliation and earliest-release ordering. |
| 4 | #3618 | Deliver exact release-set validation, verified release and advance. |

The grouping and preview foundation already exists. Do not recreate it or
interpret an umbrella parent as an execution prerequisite. Each subsequent
wave requires the preceding acceptance, not just a merged design document.

## Verified capability evidence

Read-only inspection on 2026-10-09 established:

- GitHub's [REST best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#use-conditional-requests)
  explicitly exclude conditional unsafe methods unless a specific endpoint
  documents support. GET ETags are not mutation preconditions.
- [Milestone update](https://docs.github.com/en/rest/issues/milestones#update-a-milestone)
  documents title, state, description and due date, with no expected version
  or conditional-write guarantee.
- Authenticated GraphQL introspection found no `UpdateMilestoneInput` type;
  `UpdateIssueInput` has `milestoneId` but no expected resource version.
  `clientMutationId` is correlation metadata, not compare-and-set.
- Authenticated schema introspection describes `CreateCommitOnBranchInput`'s
  `expectedHeadOid` as the expected Git commit OID at the branch head before
  committing. This is a candidate Git-backed primitive, not proof that
  milestone or issue writes are conditional.

No mutation probe, test milestone, assignment change, or permission change was
performed. The existing unconditional live-write rejection remains required.

## Alternatives and decision

| Option | Human-pin protection | Change to approved acceptance | Disposition |
| --- | --- | --- | --- |
| A: direct GitHub milestone/assignment writes | Unproven against external writers | None | Owner-selected scope; keep disabled until a supported conditional contract is demonstrated. |
| B: Git-backed canonical roadmap; no milestone/assignment writes | Cannot overwrite GitHub state because it never writes it | Replace live GitHub assignment with canonical ledger membership | Unselected alternative; not authorized. |
| C: exclusive-writer convention plus pre/post-write reads | Does not constrain repository admins or human UI edits | Weakens the pin invariant unless every writer is technically constrained | Reject as an equivalent solution without enforceable exclusion proof. |

Option B is not a drop-in fulfillment of #3400. It preserves the stronger
no-overwrite property by eliminating the problematic writes, at the cost of
losing automatic GitHub milestone assignment. No derived mirror is permitted:
an asynchronous assignment mirror would reintroduce the same race.

### Selected option and Projects APIs

Retain GitHub milestone persistence; do not substitute a canonical Git ledger,
weaken human-pin protection or treat the selection as proof of atomic writes.
GitHub Projects v2 exposes GraphQL APIs for membership and custom fields, but
the inspected update/delete and field-value inputs did not expose an expected
version or old-value precondition. Projects may present read-only planning
evidence; it is not a demonstrated compare-and-set workaround. No Project
mutation or permission expansion is authorized by this decision.

The mocked persistence/race suite in #3700 tests the required contract under a
strong atomic compare-and-commit assumption. It does not prove that separate
GitHub APIs implement that assumption. Live #3616 acceptance remains blocked;
Issues #3617 and #3618 must not consume a simulation as production authority.

## Candidate Git-backed contract

If explicitly approved, a repository-owned ledger defines release membership,
canonical pins, plan digest, bounded run identity and immutable receipts.
`docs/reference/roadmap.md` is rendered from that ledger in the same commit.
Publication uses a stable bot branch and a PR through existing admission gates,
never a direct-main write or force update.

Every proposed update binds the exact observed branch head. Reject a changed
head; re-read and revalidate rather than replaying a stale overwrite.
Normal Git expected-old ref updates or `expectedHeadOid` require contract and
failure-injection coverage before implementation chooses its transport.
A branch update is not an atomic main merge or an atomic GitHub inventory read.

GitHub milestones, assignments and pin labels remain observation-only exclusion
signals. Observe them before planning and again before execution; unknown,
changed or inaccessible state pauses the affected release. This detects
observed divergence but cannot promise atomicity against a concurrent GitHub
edit. Canonical pin edits must therefore occur through ledger commits for
transactional protection. If the owner requires instantaneous GitHub UI pin
semantics, option B is insufficient and option A remains blocked.

A recorded proposal or merged artifact is not plan approval. Authenticated
authority must bind repository, scope, digest, bounds and current policy.
One-time consumption and claimed execution ownership belong to a single
conditional state transition; a local SQLite receipt alone is not remote
authority. Missing proof keeps execution disabled. Existing release controls
remain authoritative; a ledger receipt cannot authorize arbitrary dispatch.

## Required revised acceptance and failure tests

Before option B implementation, amend the parent PRD/spec and #3616-#3618:

- Replace GitHub milestone upsert/assignment with canonical ledger membership,
  and replace milestone-number execution scope with exact canonical release ID.
- State the canonical-pin workflow and observed-only GitHub pin semantics.
  Do not imply preservation of instantaneous external-edit behavior.
- Define ownership, schema/version migration, bounded retention and redaction.
  Inventory content and actor evidence inherit repository access controls;
  no secrets or full private issue bodies belong in the ledger or logs.
- Demonstrate stale branch-head rejection, concurrent canonical pin edits,
  duplicate logical keys and deterministic artifact/ledger consistency.
- Simulate lost responses, replay and superseded approval; verify no duplicate
  approval consumption or execution, and bounded explicit recovery.
- Prove post-merge state revalidation, unauthorized actor rejection, default-off
  behavior, missing inventory failure and earliest blocked release pausing.
- Preserve #3618's exact merged-PR set, previous tag, planned version, verified
  release URL and no advance on partial release failure.

## Rollout and decision boundary

The owner selected option A. Merging this document records that choice but does
not prove conditional milestone mutation or enable runtime writes. Continue safe
read-only work until a supported contract is demonstrated; do not start dependent
live delivery. Any revised option B acceptance needs a new explicit decision.
After technical acceptance, split persistence, runtime ordering and release along
the existing dependency chain rather than a single large PR.

Shadow first, then opt in only after the revised contract's race/replay and
end-to-end requirements pass. Rollback disables new execution and retains
receipts; never delete human milestones or clear assignments. Previously
published releases keep their existing recovery procedure.

## Implementation status

Issue #3616 implements the [approved spec](../spec/roadmap-race-safe-persistence.spec.md); the
milestone adapter gate stays closed until the owner provisions it and records positive probe
evidence.
