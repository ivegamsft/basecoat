# Local Embeddings Guide

This guide goes deeper on fully local semantic code search using Ollama embedding models and `sqlite-vec`. For Ollama installation and general local model setup, see `docs/LOCAL_MODELS.md`.

## Overview

Local embeddings let you search a codebase by meaning instead of exact keywords.

- **Semantic search over codebases using locally-generated embeddings**
- **No cloud API calls** — fully private and offline-capable
- **Built on `sqlite-vec`** for lightweight local vector similarity search in SQLite
- **Embedding models run via Ollama** on the same machine or inside a controlled local network

This pattern is useful when you want private retrieval over source code, documentation, or prompt context without running a hosted vector database or sending code to external APIs.

## Architecture

```text
Code Files → Chunking → Ollama Embed → sqlite-vec DB → Query Interface
```

At a high level:

1. Read source files from the repository
2. Split them into semantically meaningful chunks
3. Generate embeddings locally through Ollama
4. Store vectors in SQLite with `sqlite-vec`
5. Query by natural language or by example code

## Embedding Models

| Model | Dimensions | Size | Speed | Quality |
|---|---:|---:|---|---|
| `nomic-embed-text` | 768 | 274MB | Fast | Good general-purpose |
| `mxbai-embed-large` | 1024 | 670MB | Medium | Higher quality |
| `all-minilm` | 384 | 45MB | Very fast | Lightweight/mobile |
| `snowflake-arctic-embed` | 1024 | 670MB | Medium | Code-optimized |

### Choosing a model

- Start with **`nomic-embed-text`** for the best balance of size, speed, and quality
- Use **`mxbai-embed-large`** when retrieval quality matters more than disk and RAM usage
- Use **`all-minilm`** for constrained devices, experiments, or fast local iteration
- Try **`snowflake-arctic-embed`** when code-heavy repositories benefit from a more code-oriented embedding model

The vector dimensions in your schema must match the model you choose.

## Setup

```bash
# Install Ollama and pull embedding model
ollama pull nomic-embed-text

# Install sqlite-vec (Python)
pip install sqlite-vec

# Or via npm for Node.js
npm install sqlite-vec
```

If Ollama is not already installed, follow `docs/LOCAL_MODELS.md` first.

## Indexing Pipeline

A typical indexing flow looks like this:

1. **Chunking strategy**: Split code into semantic chunks such as functions, classes, or logical blocks
2. **Metadata extraction**: Capture file path, language, symbols, and line numbers
3. **Embedding generation**: Call the Ollama embeddings API for each chunk
4. **Storage**: Insert embeddings and metadata into `sqlite-vec` and companion tables

## SQLite Schema

```sql
CREATE VIRTUAL TABLE code_embeddings USING vec0(
    embedding float[768]  -- matches nomic-embed-text dimensions
);

CREATE TABLE code_chunks (
    id INTEGER PRIMARY KEY,
    file_path TEXT NOT NULL,
    chunk_text TEXT NOT NULL,
    start_line INTEGER,
    end_line INTEGER,
    language TEXT,
    symbols TEXT,  -- JSON array of defined symbols
    indexed_at TEXT NOT NULL
);
```

A common pattern is to keep vectors in the virtual table and store human-readable metadata in a normal table keyed by row ID.

## Generating Embeddings with Ollama

Ollama can generate embeddings for each chunk through its local API. The exact client varies by language, but the flow stays the same:

1. Read chunk text
2. Send it to the selected embedding model
3. Receive the embedding vector
4. Persist the vector alongside chunk metadata

For large repositories, batch work at the file level and commit inserts in transactions so indexing can resume cleanly after interruptions.

## Query Interface

```python
# Semantic search: find code similar to a natural language query
query_embedding = ollama.embed("nomic-embed-text", "authentication middleware")
results = db.execute("""
    SELECT c.file_path, c.chunk_text, c.start_line,
           distance
    FROM code_embeddings e
    JOIN code_chunks c ON c.id = e.rowid
    WHERE e.embedding MATCH ?
    ORDER BY distance
    LIMIT 10
""", [query_embedding])
```

This turns a natural language query into an embedding, then finds the closest code chunks by vector distance.

## Chunking Strategies

Choosing the right chunk size matters as much as the model.

- **Function-level**: each function or method is one chunk; usually the best default for code search
- **Block-level**: logical blocks of 20-50 lines with overlap; useful when functions are too large or loosely structured
- **File-level**: the whole file as one chunk; simplest to implement, but often too coarse for precise retrieval
- **AST-aware**: use tools such as tree-sitter to split at semantic boundaries; best when you want language-aware chunking

### Chunking guidance

- Prefer **function-level** chunking for most repositories
- Add small overlap when using fixed-size block chunking so surrounding context is not lost completely
- Preserve symbol names, comments, and signatures because they improve retrieval quality
- Keep chunks short enough to represent one idea, but large enough to contain useful implementation detail

## Incremental Updates

Local search stays practical when the index updates incrementally instead of rebuilding everything on every run.

Recommended approach:

- Track file modification times
- Re-index only changed files
- Delete embeddings for removed files
- Run a periodic full re-index for consistency

You can also store a content hash per chunk to avoid regenerating embeddings when formatting changes do not affect semantics.

## Use Cases

Examples of what local semantic code search can answer:

- **"Find code that handles authentication"** → semantic match across middleware, guards, or auth helpers
- **"Show me error handling patterns"** → concept search across try/catch blocks, wrappers, and logging helpers
- **"What's similar to this function?"** → code similarity search using an existing chunk as the query
- **Agent context enrichment** → retrieve relevant code chunks and inject them into prompts before generation

This works especially well when exact symbol names are unknown, inconsistent, or spread across multiple files.

## Performance Considerations

Expected performance depends on hardware, repository size, chunking strategy, and model choice.

- Initial indexing: **~100 files/minute** with `nomic-embed-text`
- Query latency: **<50ms** for **100K chunks**
- Database size: **~1GB per 50K chunks** for **768d embeddings**
- RAM usage: embedding model memory plus SQLite cache and any in-memory index structures

### Practical tuning tips

- Use smaller chunks only if retrieval quality improves enough to justify more rows
- Batch inserts and reuse a single database connection during indexing
- Keep metadata lean so the SQLite file stays portable
- Consider separate indexes per repository or language when a single database becomes too large

## Limitations

Local embeddings are powerful, but they are not a full program analysis system.

- Embedding quality varies by language and tends to be strongest for Python, JavaScript, and TypeScript
- Semantic drift means embeddings capture similarity, not exact runtime behavior
- Chunk boundaries lose surrounding context unless you deliberately preserve overlap or parent references
- Cross-file relationships are weak; use embeddings alongside call graphs, symbol indexes, or AST tooling for deeper understanding

## Recommended Implementation Pattern

A practical local semantic search stack looks like this:

1. Use Ollama to host the embedding model locally
2. Parse and chunk source files by semantic boundaries
3. Store vectors in `sqlite-vec` and metadata in SQLite tables
4. Query with natural language and rerank or filter using metadata
5. Inject the best matches into agent prompts, code review workflows, or developer search tools

This keeps the full pipeline private, portable, and simple enough to run on a laptop.
