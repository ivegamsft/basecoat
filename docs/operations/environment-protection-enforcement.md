# Environment Protection Enforcement Runbook

This runbook defines how maintainers enforce and audit environment protection gates, with production approvals as a hard requirement.

## Scope

Apply this runbook when:

- A workflow introduces or changes deployment jobs
- A production deployment path is added or modified
- Sprint closeout includes deployment governance verification

## Enforcement controls

| Control | Enforcement method | Frequency |
|---|---|---|
| Environment policy exists in docs | Governance audit + enforcement workflow | Per PR + weekly |
| Production manual approvals configured | GitHub environment API check (`production`, fallback `prod`) | Per PR + weekly |
| Production branch/tag restrictions configured | GitHub environment API check (`production`, fallback `prod`) | Per PR + weekly |
| GitHub Pages branch restrictions configured | GitHub environment API check (`github-pages`) | Per docs workflow PR + weekly |
| Deployment workflows declare environments | Workflow YAML static checks | Per PR + weekly |
| Audit trail availability | Environment deployment history review | Per release and incident |

## Operational procedure

1. Ensure `.github/workflows/environment-protection-enforce.yml` is green for the target PR.
2. Confirm `production` environment (or legacy `prod`) has required reviewers configured.
3. Confirm the resolved production environment uses selected branch/tag policies that include `main` and SemVer release tags (`v*`).
4. Confirm deployment workflows use `environment:` for deployment jobs.
5. Confirm production-targeting jobs resolve to `production` (or legacy `prod`) and consume secrets/vars from protected scope.
6. If `docs.yml` changed, confirm the `github-pages` environment still resolves to protected branches or a selected-branch list that includes `main`.
7. Capture any exception with issue reference before merge.

## GitHub Pages environment requirement

`docs.yml` deploys through the `github-pages` environment. If docs deploys are blocked,
set **Settings → Environments → github-pages → Deployment branches** to either:

1. **Protected branches only**, with `main` protected, or
2. **Selected branches** including `main`.

Without one of those configurations, Deploy Docs runs from `main` will remain blocked by environment protection.

## Production release tag requirement

`publish-to-production.yml` runs from immutable `v*.*.*` release tags. The `production`
environment must therefore use **Selected branches and tags**, not protected branches
only, with:

1. Branch policy `main`
2. Tag policy `v*`

Manual production approvals remain mandatory. The tag policy only permits the
tag-triggered workflow to enter the protected environment and wait for approval.

## Exception handling

Exceptions are time-boxed and issue-tracked:

- Open or link an issue with risk, owner, expiry date, and rollback plan.
- Add the issue reference to the PR body.
- Restore baseline controls before the exception expiry.

No permanent bypasses for production manual approval controls are allowed.

## Audit evidence checklist

For each release window or incident review, retain:

- Enforcement workflow run URL
- Environment protection screenshot or API output for `production` (or `prod`)
- Production deployment run URL with approval event
- Linked issue for any approved exception

## Related references

- `docs/reference/environment-protection.md`
- `.github/workflows/environment-protection-enforce.yml`
- `.github/workflows/governance-audit.yml`
