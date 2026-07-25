# Burndown Metrics Formulas

- **Ideal daily burn** = `baseline scope / sprint working days`
- **Actual daily burn** = `(baseline scope - remaining scope) / elapsed working days`
- **Burn variance** = `actual daily burn - ideal daily burn`
- **Spillover risk index** = `remaining scope / max(actual daily burn, 0.1) - days left`
- **Blocker pressure** = `blocked items / remaining scope`
- **Removed/deferred scope** (e.g., closed-unmerged PRs) is tracked on its own
  line and subtracted from *both* baseline and remaining scope. It is excluded
  from the actual-burn numerator (`baseline scope - remaining scope`) so
  de-scoping never inflates delivered burn.

## Interpretation Guide

- Burn variance < 0 and blocker pressure > 0.2 usually indicates rising spillover risk.
- Positive burn variance with steady scope suggests healthy execution.
- Rising baseline scope mid-sprint should be explicitly called out as scope injection.
