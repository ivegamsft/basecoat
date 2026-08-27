# Dependency Blocker Monitor — Detail Reference

## Blocker Creation

Use a compact issue body that captures the dependency chain and the evidence of failure.

```bash
gh issue create \
  --title "Cell <cell-name> blocks <N> workcells" \
  --label "blocker" \
  --body "## Cell blocker

**Cell:** <cell-name>
**Status:** failed
**Blocked workcells:** <list>
**Evidence:** <deployment or health check summary>
**Next check:** <timestamp or condition>
"
```

## Recovery Handling

When health returns, close only the issue that corresponds to the recovered cell.

```bash
gh issue comment <number> --body "Cell health restored; blocker cleared."
gh issue close <number>
```
