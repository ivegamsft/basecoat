# GitHub Issue Filing — Shared Pattern

Every agent that files gap/debt issues follows this same template. Agents
reference this file instead of repeating the full `gh issue create` command
inline, so each agent's own file only needs to state its title prefix, base
labels, category list, and trigger table.

## Command Template

```bash
TITLE=$(cat <<'TITLE_TEXT'
<title-prefix> <short description>
TITLE_TEXT
)
gh issue create \
  --title "$TITLE" \
  --label "<base-labels>" \
  --body-file - <<'ISSUE_BODY'
## <Domain> Gap Finding

**Category:** <one of the domain's category options, or the caller's own
metadata block — see note below>
**File:** <path/to/file-or-system>
**Line(s):** <line range or n/a>
<any additional domain-specific fields — see the calling agent's own list>

### Description
<what was found and why it is a risk>
<any additional domain-specific sections — see the calling agent's own list>

### Recommended Fix
<concise recommendation>

### Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

### Discovered During
<feature or task that surfaced this — see the timestamp note below if a
computed date/time is needed>
ISSUE_BODY
```

Use `--body-file -` with a **single-quoted** heredoc delimiter
(`<<'ISSUE_BODY'`), not a double-quoted `--body "..."` argument. A
double-quoted shell argument is subject to command substitution and
variable expansion — if any substituted content (a file path, a
`$(date ...)` timestamp field, or literal backticks in a code sample)
contains `$()` or backticks, the shell executes it before `gh` ever sees
the body. A single-quoted heredoc passes the rendered content through
literally with no shell interpretation.

The free-form `<short description>` inserted into `--title` is exposed to
the same risk if passed inline in a double-quoted `--title "..."`
argument — a description naming a command-injection finding routinely
contains backticks or `$()`. Build the title the same way: through a
single-quoted heredoc captured into a variable (`TITLE=$(cat <<'TITLE_TEXT'
...)`), then reference it as `--title "$TITLE"`. Referencing an
already-set shell variable inside double quotes does not re-parse its
contents for command substitution, so this is safe even though `--title`
itself must stay double-quoted (variables don't expand inside single
quotes).

**Timestamp/computed-value note:** because the body heredoc is
single-quoted, `$(...)` and other shell expansions inside it are **not**
evaluated — text like `$(date -u +%Y-%m-%dT%H:%MZ)` would be filed
literally, not replaced with the actual time. If a field needs a computed
value (most commonly `### Discovered During`'s timestamp), compute it in
a separate command *before* building the heredoc (e.g. `NOW=$(date -u
+%Y-%m-%dT%H:%MZ)`) and paste the literal resulting value into the field
text — do not write the `$(...)` expression itself inside the quoted
heredoc.

## Usage

1. File the issue immediately when a gap is discovered — do not defer to a
   later pass or summary.
2. Substitute `<title-prefix>` and `<base-labels>` with the values the calling
   agent documents in its own `## GitHub Issue Filing` section.
3. Pick `<Category>` from that agent's category list, and add any
   finding-specific labels from that agent's trigger table. **The
   `Category`/`File`/`Line(s)` metadata block is the default shape for
   file-and-line-scoped findings, not a mandatory format.** If the calling
   agent's domain isn't file/line-scoped (e.g. an org-level identity,
   architecture, or security-posture setting), the agent's own section must
   define its own replacement metadata fields (as
   `basecoat-50-security-github-security-posture.agent.md` does with
   `Rating`/`Check`/`Target`/`Scope`) and state explicitly that they replace
   `Category`/`File`/`Line(s)` — never invent placeholder file paths or line
   numbers to satisfy the default shape.
4. **Additional fields and sections are additive, never optional.** If the
   calling agent's own section lists extra metadata fields (e.g.
   `Severity`, `OWASP Category`, `Agent`/`Version`/`Environment`) or extra
   body sections (e.g. `### Proof of Concept`, `### Positive Path`/
   `### Negative Path`, `### Remediation` with a command block), include
   every one of them in the filed issue. The calling agent's list is the
   complete, authoritative field/section set for its domain — this shared
   skeleton is a minimum common shape, not a ceiling.
5. Reference the issue number inline in the agent's final output whenever a
   known gap is intentionally deferred rather than fixed immediately.
