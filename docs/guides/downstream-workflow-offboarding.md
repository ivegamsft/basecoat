# Downstream Workflow Offboarding Checklist

Use this checklist when reducing BaseCoat automation after onboarding or
retiring a specific factory capability. It prevents a factory cleanup from
removing repository-owned operational workflows.

## Ownership boundary

`.github/base-coat/workflows/workflow-ownership-manifest.json` is the
distributed ownership marker. Its explicit `factory-owned` entries may be
retired with the guarded command. Every workflow not explicitly marked in that
manifest is `repo-owned`, including custom CI, deployment, dependency
submission, CodeQL, container, and release workflows.

Do not remove an unmarked workflow because it has a BaseCoat-like filename.
The installer preserves unmarked workflows, and the retirement command refuses
to remove them.

## Pre-retirement checks

- [ ] Create a branch and inventory `.github/workflows`; identify the
      repository owner and replacement plan for every unmarked workflow.
- [ ] Search workflow, script, documentation, and branch-protection references
      before removing a factory workflow.

  ```powershell
  rg -n "workflow-name\.yml|workflow display name" .github scripts docs
  ```

- [ ] Confirm the protected default branch has active protection or a ruleset
      and that its required checks remain available.

  ```powershell
  gh api "repos/OWNER/REPO/branches/main/protection"
  gh api "repos/OWNER/REPO/rulesets?includes_parents=true"
  ```

- [ ] Confirm dependency security remains enabled and review outstanding alerts.

  ```powershell
  gh api --paginate "repos/OWNER/REPO/dependabot/alerts?state=open"
  gh api --paginate "repos/OWNER/REPO/code-scanning/alerts?state=open"
  gh api "repos/OWNER/REPO/dependency-graph/sbom" > dependency-sbom.json
  ```

- [ ] Verify repository-owned CI, restore/build/test, deployment or release,
      container, dependency-submission, and security scanning workflows still
      cover the repository's active technology stack.
- [ ] Record the current required-check names and a branch-protection/ruleset
      snapshot in the change record before merging the retirement.

## Safe retirement

1. Sync BaseCoat first so the installed manifest and guard match the selected
   release.
2. Preview only an explicitly marked factory workflow:

   ```powershell
   pwsh .github/base-coat/scripts/retire-downstream-workflows.ps1 `
     -Workflow basecoat-secret-scan.yml -DryRun
   ```

3. Review the preview, remove `-DryRun`, and retire only the approved
   factory-owned files.
4. Never use a glob, a bulk `Remove-Item`, or a generic "retire factory
   workflows" change to remove `.github/workflows` files.

The command fails before deleting when a requested file is repo-owned or
unmarked:

```text
Refusing to remove repository-owned workflow '<file>'.
```

## Post-retirement verification

- [ ] Run the repository's restore, build, test, and workflow lint commands.
- [ ] Open a pull request and confirm all required checks appear and complete.
- [ ] Re-query branch protection/rulesets and compare the required-check set
      with the snapshot.
- [ ] Re-run dependency and code-scanning alert queries; confirm the
      dependency graph remains available.
- [ ] Exercise any remaining release or deployment path before declaring
      offboarding complete.
