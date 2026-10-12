# Latest Release Notes

## 4.6.5 - 2026-10-11

### Fixed

- Validate skill frontmatter with a fail-closed YAML subset reader and separate
  source/portable skill profiles: `name` and `description` must be strings
  within limits, `name` must match the skill directory, and agent files no
  longer receive skill-only optional-field warnings (#3655).
- Escape environment-audit-drift Markdown output and render workflow comments
  through the escaping renderer (#3764).
- Export agent detail references outside `.github/agents` so the Copilot CLI
  no longer parses them as agents; sync preserves consumer-edited files (#3766).
- Report PR metadata drift during merge evaluation as pending and cap
  re-evaluation retries (#3780).
- Skip conflicted issues in the spec synthesis picker instead of retrying in a
  loop (#3781).
- Scope issue-approve concurrency per issue (#3779).
- Retire the destructive skill frontmatter `-Fix` mode (#3656).
