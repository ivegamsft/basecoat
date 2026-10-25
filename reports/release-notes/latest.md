# Latest Release Notes

## 4.7.0 - 2026-10-24

### Added

- `scripts/label-taxonomy-audit.ps1` validates the label registry, fails on deprecated label writes, and
  with `-Repo` reports live label drift with a proposed operation per deprecated label (#3740, part 3).
- `scripts/preview-portable-skill-export.ps1` previews the portable Agent Skills
  projection of named source skills without writing files: it validates the
  source and portable profiles independently, projects only `name` and
  `description`, proves body bytes are unchanged and reports omitted source
  fields with reasons (#3654, part 1).
- Roadmap persistence (#3616): a fail-closed bot-branch authority ledger with fenced leases and one-time
  approval consumption (#3869, #3870), its GitHub transport and dry-run CLI (#3871), an approval-gated
  roadmap artifact publisher (#3872), a sandbox-only stale-write contract probe (#3873), an app-authored
  ledger root bootstrap (#3891) and a gated milestone create/assign adapter that stays closed until
  `roadmap_persistence_enabled` is set and positive probe evidence is recorded (#3874, #3896).
- Approved-spec handoff: a read-only resolver for `/approve-spec` directives (#3846), a trusted write gate,
  status record and worker adapter (#3848), and the handoff workflow wired through the shared worker
  without enabling live writes (#3849, #3851).
- Stage 1 shadow (write-free) delivery evaluators: the protected-main eligibility barrier (#3861), ordered
  delivery admission and holds (#3862), dependent stack validation and handoff observation (#3863), and
  coding-agent completion readiness reconciliation (#3864).
- An author-time `PR intake metadata` check names every invalid Intake Contract Design field on PR open,
  edit or push instead of only at merge eligibility (#3801).
- Work-unit completion and authorization contracts for the `spec:`, `prepare:`, `build:`, `review:`,
  `deliver:` and `ship:` intents (#3834-#3839), plus specs for roadmap persistence (#3860) and stale-run
  recovery backpressure (#3832).

### Changed

- Repin the gh-aw `issue-triage`, `code-review-agent` and `release-impact-advisor` agents from `gpt-5-mini`,
  which no longer resolves for the `agentic-workflows` integrator, to `claude-sonnet-5` (#3946).
- Every tag publisher (`release.yml`, `package-basecoat.yml`) enforces the release label policy over the exact
  previous-tag..tag range through `scripts/release-label-gate.sh`, failing closed before publishing (#3895);
  `skip-release-label-gate` and `dependencies` exemptions count as covered (#3829).
- The PR auto-merge executor withholds merge eligibility while any unresolved, non-outdated review thread
  exists, under every policy pack including `solo-dev` (#3795).
- Ship-it allows explicitly owner-delegated approval posted through the verified owner's account, keeping
  all runtime authorization checks (#3824).
- Docs: the README Quick Start drops the unsupported manual-copy install and adds a "Choose your intent"
  onboarding table (#3806); an operator guide documents approved-spec handoff and roadmap persistence
  settings (#3880); docs are provider-neutral by default (#3935); and the 2026-10-24 CI/CD and
  spec-to-production audits are recorded (#3925, #3928).

### Fixed

- Record the canonical label taxonomy in `.github/governance/label-taxonomy.json`: one `:` separator per
  dimension, one label per dimension, and a deprecated-to-canonical map for the duplicate `size/*`, `risk-*`,
  `priority/*`, docs, CI, and malformed labels, with a reversible, logged migration procedure in
  `docs/reference/label-taxonomy.md` (#3740, part 1).
- Ship-it intent runs now apply and create canonical `risk:<band>` labels instead of deprecated `risk-<band>`
  labels, and issue triage applies GitHub's `good first issue` label instead of `good-first-issue` (#3740, part 2).
- `sync.ps1` and `sync.sh` honor the documented `.basecoat.yml` `agents:` allow-list: only listed agents are projected to
  `.github/agents/`, `agents: []` disables agent projection while keeping agents staged under `.github/base-coat/agents/`,
  and previously projected agents that leave the list are pruned through `guidance-lock/v1` (#3747).
- `rollback.ps1` replays `sync.ps1` for the tag under the guidance-lock lease, so projections and `guidance-lock/v1` match a fresh sync;
  failures restore the prior install and pin, except `GUIDANCE_LOCK_BUSY` (lease reclaimed as stale), which keeps the backup instead (#3776).
- Key `pr-flow-hygiene` and `ship-it-intent-dispatch` concurrency per issue/PR so runs for one item no longer cancel
  or displace runs for another; a workflow guardrail now rejects `github.ref`-only groups under PR-target/issue triggers (#3803).
- Key `ship-it-build-guard` concurrency per source `workflow_run` so a later completion can no longer displace a pending
  failure run before its retry/escalation; the guardrail now also covers `workflow_run` triggers, with `adoption-metrics`
  and `post-onboarding-drift-loop` explicitly exempted as intentionally serialized aggregates (#3808).
- `scripts/bootstrap-basecoat.ps1` now counts the committable files a real run adds, updates or removes (including a
  custom `TargetDir`), so its optional pull request opens when the overlay changed and is skipped otherwise; it stages
  and commits only those files, and `-DryRun` clones into a temp directory so it can list top-level items (#3812).
- `scripts/bootstrap-basecoat.ps1 -DryRun` now runs sync in a temporary clone of the consumer repo and lists the
  files it would add, update or remove, so its counts match a real run; the unused legacy copy helpers are removed (#3818).
- `sync.ps1` and `sync.sh` acquire (or verify an inherited) guidance-lock lease before the first repository write and
  renew it before each write phase, so a concurrent sync cannot interleave staged-payload writes and a sync whose lease
  was taken over stops with `GUIDANCE_LOCK_BUSY` before writing more (#3804). Renewal fails closed within 60s of the
  600s stale-reclaim threshold, and a heartbeat keeps the lease fresh while the consumer cleanup script runs. That script
  runs as its own process tree (a job object on Windows, a process group elsewhere). Sync stops and awaits the whole
  tree, including child processes, if the lease is lost and before writing on, and leaves unrelated processes running (#3822).
- `sync.sh` installs `configure-downstream-workflows.ps1` like `sync.ps1`, and the parity test now requires both
  scripts to install the same runtime validators (#3813).
- `sync.ps1` and `sync.sh` stage `policy-packs.json` and `human-approval-boundaries.json` into
  `.github/base-coat/governance/`, so `configure-downstream-workflows.ps1` no longer warns that the source governance
  files are missing (#3758, item 2).
- `scripts/bootstrap-basecoat.ps1` keeps upstream case-only renames on `core.ignorecase=true` repositories: it pairs them
  from its file snapshots, and its pull request commit is built in a temporary index that removes the old casing before
  adding the new one, still leaving unrelated staged work alone (#3821).
- `sync.ps1` omits `tools` when an agent declares an empty `allowed-tools`, instead of installing CLI agents
  with `tools: []` and no tools (#3913).
- `scripts/validate-basecoat.ps1` resolves a relative `-ConsumerRoot` before changing directory, so it scans
  the consumer's workflows rather than the BaseCoat root (#3898).
- `invoke-basecoat-consumer-update.ps1 -CaptureWorkflowSelection` exits nonzero when capture fails instead of
  silently skipping the workflow refresh (#3810).
- `basecoat-secret-scan.yml` no longer reports green when gitleaks did not run, and falls back to the built-in
  rules when consumers have no `.gitleaks.toml` (#3809).
- The executor listens for the downstream-installed workflow names (#3796), and every PR-creating workflow
  dispatches `pr-size-labeler.yml` after bot PR writes so automation PRs become eligible (#3878).
- Solo-dev recovery no longer defers forever on phantom queued executor runs with zero jobs (#3850).
- The PR conflict router trusts only bot-authored routing markers and resolves concurrent routing (#3805);
  dependency routing concurrency is keyed per issue/PR (#3797).
- Comments that merely mention `/approve` no longer start failing `issue-approve.yml` runs (#3828).
- Issue-to-spec synthesis: indented code is treated as literal (#3798), copied lists are separated from
  paragraphs (#3833), expected changed lines sum per-file counts (#3858), the classification rationale keeps
  its field label (#3867), and implementation PRs that touch a spec file are ignored by spec handoff (#3902).
- Failed Windows validation stages keep pipeline output and error details in the log and per-attempt failure
  artifacts (#3903).

### Security

- `intake-contract-check.yml` passes `workflow_call` template paths through `env:` instead of interpolating
  them into Bash, and PRD gate exemptions are configurable (#3893).
- Ship-it cross-repository targets require an explicit allowlist rather than only the actor's permission in
  the host repository (#3894).
- Bump transitive `handlebars` to 4.7.10 (#3892) and remove the vulnerable transitive `sprintf-js`
  (GHSA-hp3w-g68c-fv3c) from five Jest roots (#3831).
