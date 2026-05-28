# RAG Patterns for Agent Context Enrichment

Retrieval-augmented generation (RAG) is the pattern of retrieving relevant context before generating a response. For Base Coat agents, it improves accuracy, grounds outputs in real repository data, and helps agents work across codebases that are larger than a single model context window.

This reduces hallucination by giving the model factual source material instead of forcing it to rely only on prior training or partial prompt context.

Related documents:

- `docs/LOCAL_EMBEDDINGS.md` covers chunking, embeddings, and vector storage
- `docs/SQLITE_MEMORY.md` covers persistent storage and recall patterns for durable memory

## Overview

A practical RAG system for agent context enrichment has four stages:

1. **Indexing**: chunk, embed, and store source material
2. **Retrieval**: query, rank, and filter the indexed data
3. **Augmentation**: inject the best retrieved context into the prompt
4. **Generation**: have the LLM produce a grounded response

In this stack, indexing is covered in `docs/LOCAL_EMBEDDINGS.md`. This document focuses on the workflow patterns that use that index effectively.

## RAG Pipeline Stages

### 1. Indexing

Indexing prepares content for later recall.

Typical responsibilities:

- Split code or docs into meaningful chunks
- Generate embeddings for each chunk
- Store vectors and metadata together
- Preserve file path, symbol, line range, language, and timestamp metadata

For implementation details, see `docs/LOCAL_EMBEDDINGS.md`.

### 2. Retrieval

Retrieval turns a user task into a search operation over indexed content.

Typical responsibilities:

- Convert the incoming task into one or more search queries
- Rank matching chunks by relevance
- Filter out low-value, stale, or out-of-scope results
- Return a bounded set of chunks for prompt assembly

### 3. Augmentation

Augmentation decides how retrieved evidence enters the prompt.

Typical responsibilities:

- Select the highest-value chunks that fit the token budget
- Add source metadata so the model can reason about provenance
- Order chunks by usefulness instead of raw storage order
- Remove duplicates and overlapping passages

### 4. Generation

Generation is the final grounded model call.

Typical responsibilities:

- Answer using retrieved evidence first
- Cite or reference retrieved sources when helpful
- Avoid unsupported claims when retrieval is weak
- Calibrate confidence based on retrieval quality

## Retrieval Strategies

### Semantic search

Semantic search embeds the query and finds the nearest vectors.

Use it when the user knows the concept but not the exact symbol or wording. This is usually the best default for concept matching across source code, documentation, and prior decisions.

### Keyword or BM25 search

Keyword retrieval uses traditional text matching.

Use it when exact terms matter, such as:

- Error messages
- Stack trace fragments
- Exact API names
- Config keys
- Migration flags

Keyword search is often a better first pass when precision matters more than conceptual similarity.

### Hybrid retrieval

Hybrid retrieval combines semantic and keyword search, then merges rankings with reciprocal rank fusion.

This is usually the most reliable production pattern because it handles both fuzzy concept matching and exact text matches in the same pipeline.

### Metadata filtering

Metadata filtering narrows the candidate set before vector search.

Common filters include:

- File type
- Language
- Directory or subsystem
- Symbol kind
- Recency or last-modified time
- Branch, owner, or repository scope

Pre-filtering reduces noise, improves latency, and makes semantic search more precise.

### Multi-query retrieval

Multi-query retrieval rewrites the question several ways, retrieves for each variant, then deduplicates the results.

This helps when a request is ambiguous or could be expressed with different terminology. A bug report, for example, may benefit from searches over the error string, subsystem name, and desired behavior.

## Context Window Management

RAG quality depends on fitting the right evidence into a limited prompt budget.

### Budget allocation

Reserve tokens explicitly for both retrieved context and final generation. If retrieval consumes the entire prompt budget, the model has no room left to reason or answer clearly.

### Prioritization

Put the most relevant chunks first and truncate from the end. Front-loading the strongest evidence gives the model the best chance to use the highest-signal material.

### Deduplication

Do not inject overlapping chunks or near-identical passages. Repeated context wastes tokens and can overweight one source artificially.

### Freshness

Prefer recently modified or recently validated content when multiple chunks are similarly relevant. This matters most for active repositories, evolving APIs, and configuration guidance.

## Augmentation Patterns

### Stuff

The stuff pattern inserts all retrieved chunks directly into the prompt.

It is simple and effective for small result sets, but it is limited by context window size and can degrade quickly when too many chunks are included.

### Map-reduce

The map-reduce pattern processes each chunk independently, summarizes or extracts useful facts, then merges the summaries into a final answer.

Use it when the source set is too large to stuff directly or when you need broad coverage across many files or documents.

### Refine

The refine pattern starts with an initial answer and iteratively improves it as each chunk is processed.

Use it when evidence arrives in a sequence and later chunks may expand, correct, or sharpen the draft.

### Re-rank

The re-rank pattern retrieves broadly, then applies a stronger reranker such as a cross-encoder before prompt injection.

Use it when first-pass retrieval is noisy and prompt space is expensive. Re-ranking helps keep only the best evidence.

## Agent-Specific RAG Patterns

### Code completion

Retrieve similar functions, adjacent API usage examples, and matching patterns from the same language or subsystem.

This helps completions match local conventions instead of generic training examples.

### Bug fixing

Retrieve prior fixes for similar errors, known failure signatures, and error knowledge base entries.

This works especially well when combined with persistent storage patterns from `docs/SQLITE_MEMORY.md`.

### Documentation answering

Retrieve relevant documentation before answering user questions.

This keeps explanations aligned with repository-specific behavior instead of broad, potentially inaccurate defaults.

### Code review

Retrieve coding standards, guardrails, and past review comments on similar patterns.

This helps agents apply project-specific review criteria consistently.

## Quality Signals

### Relevance threshold

Set a minimum relevance score and do not inject low-relevance chunks. Irrelevant context is often worse than no context.

### Source attribution

Track which retrieved chunks influenced the answer. Provenance improves trust, debugging, and later evaluation.

### Confidence calibration

Use retrieval quality as an input to answer confidence. High retrieval scores and consistent evidence support stronger claims. Weak or conflicting retrieval should produce a more cautious response.

### Feedback loop

Track which retrievals led to good or bad outcomes. Over time, this supports better chunking, better ranking, and better threshold tuning.

## Anti-Patterns

### Retrieving too much context

Too much context dilutes signal, wastes tokens, and can confuse the model about what matters.

### No relevance threshold

If every match is injected, low-value noise crowds out the useful evidence.

### Ignoring chunk boundaries

Splitting in the middle of a function, class, or logical unit makes retrieval less interpretable and less useful during augmentation.

### Not updating the index

If the codebase changes but the index does not, the agent will retrieve stale guidance and produce outdated answers.

### Using RAG unnecessarily

If the answer is already present in the system prompt, current task context, or a deterministic lookup, RAG adds overhead without improving quality.

## Recommended Base Coat Pattern

For most Base Coat agent workflows, a practical default is:

1. Build and maintain a local index as described in `docs/LOCAL_EMBEDDINGS.md`
2. Apply metadata filters before semantic search when scope is known
3. Use hybrid retrieval for the first pass when exact terms may matter
4. Enforce a relevance threshold and deduplicate overlapping chunks
5. Inject only the highest-signal evidence that fits the prompt budget
6. Track source attribution and feedback so retrieval quality can improve over time

This gives agents a grounded context-enrichment workflow that stays local, efficient, and adaptable to completion, review, bug-fixing, and documentation tasks.
