# Roadmap grouping and checkpoint preview

This is the safe, read-only portion of [#3616](https://github.com/IBuySpy-Shared/basecoat/issues/3616),
continuing the [foundation](roadmap-planner-foundation.md). #3616 and umbrella
[#3400](https://github.com/IBuySpy-Shared/basecoat/issues/3400) remain open.
The approved PRD/spec, not this adapter, define eventual live delivery.

## Boundary and usage

```powershell
python scripts\roadmap\preview.py --evidence mapper-advisor.json --snapshot snapshot.json --run-id preview-1 --checkpoint roadmap-preview.sqlite
python scripts\roadmap\preview.py --evidence mapper-advisor.json --repo owner/repo --run-id preview-1 --checkpoint roadmap-preview.sqlite
python tests\roadmap-preview-tests.py
```

The live source delegates to the foundation's paginated `gh api --method GET`
inventory. This adapter never invokes a model, creates a milestone, assigns an
item, opens a bot PR, dispatches execution, or publishes a release/tag.
`--apply` always fails before reading evidence or opening the local store.
There is no enable setting or asserted capability that bypasses that gate.

Output is JSON containing the validated plan, digest, storage-step **preview**,
generated Markdown, blockers and immutable checkpoint. Markdown is the proposed
content for `docs/reference/roadmap.md`; it is not written there automatically.
No run ID or timestamp appears in Markdown. Assignments are proposals, not live
membership; lifecycle is `proposed`, and verified tag is `none`.

## Normalized interchange contract

The adapter consumes supplied reports from the existing
[`sprint-project-mapper`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-10-core-sprint-project-mapper.agent.md)
and [`release-impact-advisor`](https://github.com/IBuySpy-Shared/basecoat/blob/main/agents/basecoat-60-workflow-release-impact-advisor.agent.md).
It does not fabricate reports, infer themes from arbitrary body text, perform
split/merge debate, or independently certify model-reported historical metrics.
`source` identifies the required input contract, **not authenticated provenance**.
Only previously obtained reports should be converted to this interchange.
Missing or incomplete reports stop; there is no placeholder grouping fallback.

Top-level JSON fields:

| Field | Meaning |
| --- | --- |
| `schema` | Integer `1`. |
| `repository`, `scope`, `current_version` | Foundation repository and stable version; all, label, issue-set, or theme selector. |
| `snapshot_digest` | `preview.snapshot_digest(snapshot)`: SHA-256 canonical JSON with inventory/list ordering normalized. Must match current observations. |
| `max_releases`, `concurrency`, `pace`, `stop_conditions` | Optional foundation bounds; no policy override. |
| `mapper` | Fields below; `source: sprint-project-mapper`. |
| `advisor` | `source: release-impact-advisor`, exact `current_version`, and `recommendations`. |

Mapper fields:

- `themes`: `{theme, issues}` entries from mapper classification. A theme selector
  requires one nonempty exact normalized theme; theme membership must be open
  issues in the same repository. Other selectors use foundation semantics.
- `links`: `{pr, issues}` entries from normalized mapper linkage. IDs must exist
  in the same snapshot. Only a single selected issue admits a PR; missing,
  ambiguous or out-of-scope links remain residual. Snapshot link annotations are
  not implicitly trusted or combined with report links.
- `groups`: `{id, issues, merged_prs, loc, activity_days, explicit_binding, debate}`
  entries. IDs and member lists are unique and disjoint. `debate` requires
  nonempty `split` and `merge` arguments, `decision` (`retain`, `split`, `merge`,
  `needs-human-decision`) and numeric `confidence` in `[0,1]`.
  A merge additionally requires numeric `similarity` strictly greater than `0.65`.
- `residuals`: `{number, reason}` for selected issues excluded from groups.
  Every selected issue must be accounted for exactly once.

Mapper significance follows its existing detail contract: at least five issues
**or** three merged PRs, **and** at least 200 LOC, **and** seven days activity
**or** explicit binding. Confidence below `0.70` or `needs-human-decision` cannot
produce a release. Failing significance is visible residue, not an invented
release or automatic nearest-group merge.

Each significant group requires exactly one advisor recommendation
`{group, release, risks, rollout, rollback}`; the final three fields are nonempty
supplied report text. Sub-threshold groups must not receive recommendations.
The baseline must match the supplied advisor baseline and not lag live tags.
Foundation validation rejects duplicate/old/malformed releases, ownership/pin
conflicts and malformed API inventory. It still owns milestone identity and
storage-step computation.

The digest includes the original normalized selector and normalized evidence
digest, so changing classification, debate, bounds or scope requires a new plan.
Reordering records/members does not change the digest or Markdown. Historical
counts remain supplied evidence, not a substitute for approval or live CAS.

## Durable read-only checkpoint protocol

The explicitly selected SQLite path stores one immutable row per
`(repository, run_id)` using `BEGIN IMMEDIATE`, a primary key and full synchronous
commit. The row contains the exact result, Markdown, scope/bounds through the
plan, blockers, `phase: preview-only`, `approval: null` and `completed_writes: []`.
This transaction is only local durability; it is not GitHub conditional storage.

Identical replay returns the same payload, including after loss of the CLI
response following commit. Different scope, digest, observations, evidence or
preview steps on the same run ID fail closed. Refresh observations and obtain
new reports under a new run ID after an inventory change. A locked, corrupted
or malformed store stops; no silent reset or fabricated partial progress.
Keep the store private, like its repository inventory. No credentials are stored.

## Actual GitHub API capability evidence

Read-only inspection on 2026-10-07 used authenticated `GET` calls against
`IBuySpy-Shared/basecoat`: milestone inventory returned records with numeric
`number` and `open|closed` states; `GET .../issues/3616` returned issue `3616`,
`open`, `milestone: null`, and label names. The foundation's live shadow proof
validated 13 milestones, 47 open issue/PR records and 79 tags through three
paginated GET endpoints (one page each at that observation).
No mutation, conditional PATCH experiment, test milestone or assignment was
performed or authorized.

The published GitHub OpenAPI contract at revision
[`670d6845f9d3de5fd53b9d8a52a8106bc7e98ecf`](https://github.com/github/rest-api-description/blob/670d6845f9d3de5fd53b9d8a52a8106bc7e98ecf/descriptions/api.github.com/api.github.com.json)
was inspected for these operations:

| Operation | Documented body | Conditional-write guarantee |
| --- | --- | --- |
| `POST /repos/{owner}/{repo}/milestones` | title, state, description, due_on | No expected version/marker uniqueness precondition. |
| `PATCH /repos/{owner}/{repo}/milestones/{milestone_number}` | title, state, description, due_on | No expected version or `If-Match` parameter; documented response is 200. |
| `PATCH /repos/{owner}/{repo}/issues/{issue_number}` | Includes milestone, labels, title/body/state and other issue fields | No expected milestone/version or `If-Match` parameter; no documented 412 stale-update rejection. |

These contracts do **not** demonstrate mutation CAS. A GET ETag/cache validator,
repository workflow serialization, pre-write re-read, or post-write read cannot
protect against an external human pin between observation and PATCH. Lack of a
documented guarantee is not proof of every server implementation detail, but
it is sufficient to keep this capability **unproven** and the gate closed.
Never repair a detected post-write race by overwriting the human change.

## Remaining blocked delivery within #3616

- Live milestone upsert/assignment, partial remote-step replay and canonical
  artifact bot PR need demonstrated stale-update rejection or equivalent
  protection including item labels, source/target milestone pins, external
  ownership changes and duplicate marker creation.
- Exact authenticated approval needs current repository authority, repository,
  run, digest, scope/bounds validation and atomic one-time consumption.
  The foundation's pure checker is not authentication or consumption.
  Neither a bot label nor schedule/merge event grants authority; this adapter
  accepts and consumes no approval.
- Live model/report acquisition and historical metric/link provenance still
  require orchestration. This deliverable validates supplied normalized reports.
  Routing/triggers/execution belong to #3617; release delivery belongs to #3618.

Do not close #3616 or #3400, enqueue execution, or describe this increment as
complete live persistence. Future artifact publication must use a stable bot PR
and the existing merge gates, never direct-main writes.
