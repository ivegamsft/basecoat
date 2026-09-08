---
description: "Use when authoring, summarizing, quoting, or vendoring third-party content in docs, agents, skills, prompts, evals, or generated artifacts."
applyTo: "**/*.{md,yaml,yml,json,txt,cs,fs,ts,tsx,js,jsx,py,go,java,kt,rb,php,rs}"
---

# Licensing and Attribution Posture

Apply this instruction before reproducing or adapting third-party text,
examples, snippets, standards material, or vendor guidance.

## Source Classes

Classify every nontrivial external source before copying its content:

| Class | Allowed usage |
|---|---|
| `basecoat-owned` | Reuse under the repository license |
| `public-reference` | Cite names, URLs, section IDs, and short factual identifiers; paraphrase by default |
| `open-source-compatible` | Copy only when its license permits reuse; record attribution and notice status |
| `vendor-guidance` | Paraphrase in BaseCoat-owned language unless copying is expressly permitted |
| `restricted-standard` | Cite-only: use public identifiers, source names, safe section references, and original summaries |
| `unknown` | Do not copy until the source is classified |

## Required Handling

- Paraphrase first for `public-reference` and `vendor-guidance` sources.
- A direct quotation must be short, necessary, and attributed with a source URL
  or unambiguous source name.
- Never reproduce ISO, IEC, ETSI, paywalled, or otherwise license-controlled
  standards text. Treat it as `restricted-standard` and cite-only.
- When copying third-party text, examples, snippets, or vendored assets under
  permitted terms, include attribution and update `THIRD-PARTY-NOTICES` or an
  equivalent notice file in the same change.
- Generated PRD/spec artifacts must retain source links, but quoted source
  content remains evidence and does not become BaseCoat-owned reusable text.

## Reviewer Decision Record

For risky-path changes that use third-party content, record:

```text
source: <url-or-name>
source_class: <basecoat-owned|public-reference|open-source-compatible|vendor-guidance|restricted-standard|unknown>
usage: <cite-only|paraphrase|short-quote|vendored-copy>
notice_required: <yes|no>
notice_status: <present|missing|not-applicable>
decision: <allow|revise|block>
```

Treat copied restricted text, a missing source class, missing attribution, or a
required-but-missing notice as blocking findings. Default `restricted-standard`
with `short-quote` or `vendored-copy` to `block`; default `unknown` to `revise`
or `block` until classification is documented.

This policy is not legal advice and does not replace maintainer license review.

Refs #3115.
