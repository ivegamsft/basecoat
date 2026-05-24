# Weekly Report Template

Use this template when filing the weekly bottleneck report issue.

```markdown
## Weekly Bottleneck Report — <week ending YYYY-MM-DD>

### Inputs
- Source takt-time JSON: <path or artifact>
- Analysis window: <week ending>

### Station Summary
| Station | Queue Length | Throughput | Bottleneck Score | Notes |
|---|---:|---:|---:|---|

### Highest-Risk Stations
1. <station> — <reason>
2. <station> — <reason>

### Recommended Actions
- [ ] <action>
- [ ] <action>

### Follow-up
- [ ] Review again next week
```

## Filing Checklist

1. Create or update the issue with the week-ending date in the title.
2. Include the station summary table and top bottlenecks.
3. Add concrete follow-up actions for the slowest stations.
4. Link back to the takt-time JSON source used for the analysis.
