# Analysis Workflow

1. Parse the takt-time JSON export for the reporting week.
2. Group records by station and compute the active window for each station.
3. Queue length = items entered but not yet exited within the window.
4. Throughput = completed items / elapsed hours in the window.
5. Bottleneck score = `queue length / max(throughput, 0.1)`.
6. Flag stations with rising queue length, falling throughput, or both.

## Reporting Rules

- Call out the top 3 stations by bottleneck score.
- Include any stations with zero throughput and non-zero queue length.
- Prefer trends over a single spike when describing the weekly issue.
