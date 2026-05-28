# Offline Agent Stack Guide

This guide ties together `docs/LOCAL_MODELS.md`, `docs/LOCAL_EMBEDDINGS.md`, and `docs/SQLITE_MEMORY.md` into one local-first pattern for running Base Coat agents without cloud dependencies.

Use this setup when you need:

- Offline development on a laptop or lab machine
- Privacy-sensitive work where code must stay local
- Air-gapped operation with no outbound network access
- A predictable promotion path from local development to cloud deployment

## Architecture

```text
                                   ┌──────────────────────────────┐
                                   │        Developer Shell       │
                                   │  editor / CLI / test runner  │
                                   └──────────────┬───────────────┘
                                                  │
                                                  v
                                   ┌──────────────────────────────┐
                                   │      Base Coat Runtime       │
                                   │ prompts + orchestration      │
                                   └───────┬─────────┬────────────┘
                                           │         │
                         stdio MCP         │         │ HTTP on localhost only
                                           │         │
                   ┌───────────────────────┘         └──────────────────────────┐
                   v                                                            v
      ┌──────────────────────────────┐                          ┌──────────────────────────────┐
      │ Local File Tools MCP Server  │                          │            Ollama            │
      │ repo-scoped read/write/search│                          │ generate + embed models      │
      └──────────────┬───────────────┘                          │ 127.0.0.1:11434 /v1         │
                     │                                          └──────────────┬───────────────┘
                     │                                                         │
                     v                                                         │
      ┌──────────────────────────────┐                                         │
      │ Working Tree + Local Files   │                                         │
      │ source, docs, tests, scripts │                                         │
      └──────────────────────────────┘                                         │
                                                                                │
                    stdio MCP                                                   │
                         │                                                      │
                         v                                                      v
      ┌──────────────────────────────┐                          ┌──────────────────────────────┐
      │   SQLite Memory MCP Server   │                          │ sqlite-vec Embeddings Store  │
      │ facts, decisions, preferences│<──── recall metadata ───>│ code/docs chunk vectors      │
      │ .basecoat\memory.db          │                          │ .basecoat\embeddings.db     │
      └──────────────────────────────┘                          └──────────────────────────────┘

      Everything stays on the workstation or approved removable media.
      No GitHub API, cloud model endpoint, hosted vector DB, or remote memory service is required.
```

## Prerequisites

Minimum software:

- Git 2.40+
- Python 3.11+ or Node.js 20+
- Ollama
- `sqlite-vec`
- Enough local disk for models, indexes, and the repository

Practical hardware guidance:

- 16GB RAM minimum for small local models
- 32GB RAM recommended for 14B-class reasoning models
- SSD storage recommended for model and SQLite performance

Recommended local components:

| Layer | Recommended local option | Notes |
|---|---|---|
| LLM | Ollama + `qwen3:8b`, `qwen3:14b`, `phi4`, or similar | See `docs/LOCAL_MODELS.md` |
| Embeddings | Ollama + `nomic-embed-text` | Good default for local retrieval |
| Vector store | `sqlite-vec` | Lightweight, file-based, offline-capable |
| Memory | SQLite | See `docs/SQLITE_MEMORY.md` |
| Tooling | Python or Node MCP servers over stdio | Prefer repo-scoped local tools |

## Step-by-Step Setup for an Air-Gapped Environment

A truly air-gapped machine cannot download installers, models, packages, or Git history directly. Stage everything on a connected machine first, then transfer the approved artifacts.

### 1. Stage artifacts on a connected machine

Clone and package the repository:

```powershell
git clone https://github.com/IBuySpy-Shared/basecoat.git
Set-Location .\basecoat
git bundle create .\basecoat.bundle --all
```

Preload the local models you want to carry offline:

```powershell
ollama pull qwen3:8b
ollama pull qwen3:14b
ollama pull nomic-embed-text
```

For fully offline transfer, copy the Ollama model store after the pulls complete:

- Windows: `%USERPROFILE%\.ollama\models`
- Linux/macOS: `~/.ollama/models`

Stage Python wheels if your local MCP servers use Python:

```powershell
python -m pip download --dest .\offline-wheels sqlite-vec mcp
```

Stage Node packages if your local MCP servers use Node:

```powershell
npm pack sqlite-vec
```

Also stage:

- Ollama installer
- Python and/or Node installers
- Any local MCP server code you plan to run
- A copy of your approved `.env` or config template with local-only values

### 2. Restore the stack on the offline machine

Install Git, Python or Node, and Ollama from the staged installers.

Restore the repository from the Git bundle:

```powershell
git clone .\basecoat.bundle basecoat
Set-Location .\basecoat
git checkout main
```

Restore Ollama models by copying the staged model directory into the offline machine's Ollama data path before starting `ollama serve`.

Install Python dependencies from staged wheels:

```powershell
python -m pip install --no-index --find-links .\offline-wheels sqlite-vec mcp
```

If you use Node-based MCP servers, install from staged tarballs or from a prebuilt `node_modules` image created on the connected machine.

### 3. Start local-only services

Start Ollama:

```powershell
ollama serve
```

Create a working directory for local state:

```powershell
New-Item -ItemType Directory -Force .\.basecoat | Out-Null
```

Create the SQLite memory database and embeddings database inside the repo or an approved local path:

```text
.basecoat\memory.db
.basecoat\embeddings.db
```

### 4. Initialize local memory and embeddings

Suggested sequence:

1. Create the SQLite memory schema from `docs/SQLITE_MEMORY.md`
2. Create the `sqlite-vec` schema from `docs/LOCAL_EMBEDDINGS.md`
3. Chunk the repository into code and documentation units
4. Generate embeddings locally through Ollama
5. Store vectors and metadata in `.basecoat\embeddings.db`
6. Configure the runtime to read and write durable memory in `.basecoat\memory.db`

### 5. Run the agent fully offline

At runtime, the agent should use only:

- Local files in the working tree
- Local SQLite databases
- Local MCP servers over stdio
- Ollama on `127.0.0.1`

If any tool or config references a public hostname, managed API, or SaaS MCP server, the stack is no longer offline-only.

## Component Integration

### Local LLM

Point the agent runtime or inference bridge at Ollama's local endpoint:

- Base URL: `http://127.0.0.1:11434/v1`
- Placeholder API key: `ollama`

Use a small model for routine loops and a larger local model for harder reasoning. See `docs/LOCAL_MODELS.md` for sizing guidance.

### Local Embeddings

Use the same Ollama instance for embeddings and store results in `sqlite-vec`.

Recommended flow:

1. Read repo files
2. Chunk by function, block, or document section
3. Embed each chunk with `nomic-embed-text`
4. Store vectors in `.basecoat\embeddings.db`
5. Retrieve top matches before prompt assembly

For schema patterns and chunking advice, see `docs/LOCAL_EMBEDDINGS.md`.

### Persistent Memory

Use SQLite as the durable memory layer so decisions and conventions survive session restarts.

Recommended storage split:

- `.basecoat\memory.db` for durable memory records
- `.basecoat\embeddings.db` for vector search over repo content

This keeps structured memory and semantic retrieval separate while still letting the runtime combine them during prompt assembly.

### File Tools

Keep tool use local and repo-scoped.

Recommended local file-tool capabilities:

- Read files
- Write or patch files in the working tree
- Search paths and content
- Run local tests and linters
- Inspect Git state locally

Avoid tools that require external APIs when you are validating the offline path.

## MCP Server Configuration for Local-Only Operation

Use stdio MCP servers for local tools and `127.0.0.1` for Ollama.

Example `mcp.json`:

```json
{
  "servers": {
    "local-inference": {
      "command": "node",
      "args": ["tools\\mcp\\openai-compatible-server.js"],
      "env": {
        "OPENAI_BASE_URL": "http://127.0.0.1:11434/v1",
        "OPENAI_API_KEY": "ollama",
        "OPENAI_MODEL_FAST": "qwen3:8b",
        "OPENAI_MODEL_REASONING": "qwen3:14b",
        "OPENAI_MODEL_EMBEDDINGS": "nomic-embed-text"
      }
    },
    "local-memory": {
      "command": "python",
      "args": ["tools\\mcp\\memory_server.py"],
      "env": {
        "MEMORY_DB_PATH": ".basecoat\\memory.db"
      }
    },
    "local-embeddings": {
      "command": "python",
      "args": ["tools\\mcp\\embeddings_server.py"],
      "env": {
        "EMBEDDINGS_DB_PATH": ".basecoat\\embeddings.db",
        "OLLAMA_BASE_URL": "http://127.0.0.1:11434"
      }
    },
    "local-files": {
      "command": "node",
      "args": ["tools\\mcp\\filesystem_server.js"],
      "env": {
        "ALLOWED_ROOT": "F:\\path\\to\\basecoat"
      }
    }
  },
  "hooks": {
    "SessionStart": [
      { "tool": "local-memory.memory_recall", "priority": 10 }
    ],
    "SessionEnd": [
      { "tool": "local-memory.memory_store", "priority": 10 }
    ]
  }
}
```

Local-only rules:

- Use `stdio` for MCP servers whenever possible
- Use only `127.0.0.1` or `::1` for HTTP endpoints
- Remove or disable GitHub, Azure, Slack, cloud storage, and web-search MCP servers
- Keep secrets and environment-specific values out of source control
- Restrict file tools to the repo root or an approved workspace path

## Network Isolation Verification

Do not assume the stack is offline because the models are local. Verify it.

### Configuration checks

Search your config for non-local endpoints:

```powershell
Get-ChildItem -Recurse -File . |
  Select-String -Pattern 'https://|http://' |
  Where-Object { $_.Line -notmatch '127\.0\.0\.1|localhost|::1' }
```

Review the final `mcp.json`, `.env`, and runtime config to confirm every endpoint is local-only.

### Runtime checks

Run the agent with the network adapter disabled, or with outbound traffic blocked by policy, and confirm the local workflow still succeeds.

Inspect active connections for the relevant local processes:

```powershell
$ollamaPid = (Get-Process ollama).Id
Get-NetTCPConnection -OwningProcess $ollamaPid |
  Where-Object { $_.RemoteAddress -notin @('127.0.0.1', '::1') }
```

Expected result: no outbound remote addresses.

Recommended verification checklist:

1. Disable Wi-Fi and unplug Ethernet, or enforce an outbound deny rule
2. Start Ollama and local MCP servers
3. Run a prompt that reads files, recalls memory, and performs semantic retrieval
4. Confirm the prompt still succeeds
5. Confirm no non-local established connections appear for the participating processes

## Limitations Compared to Cloud

| Area | Local-only stack | Cloud stack |
|---|---|---|
| Context window | Often 4K-32K on practical local models | Often much larger |
| Latency | Can be slower on CPU or small GPUs | Usually faster at high quality |
| Tool use | Some local models have weak or missing tool-use behavior | Usually stronger and more reliable |
| Reasoning depth | Good for routine work, weaker on long-horizon tasks | Better for hard planning and governance-heavy tasks |
| Operations | Simple local files and SQLite | Easier to scale across teams and services |

Practical tradeoffs:

- Smaller local models may need tighter prompts and more explicit tool wrappers
- Quantized models save RAM but can reduce quality
- Local semantic search works well, but retrieval quality still depends on chunking and the embedding model
- Air-gapped environments require manual artifact staging and update workflows

## Migration Path: Local Development to Cloud Promotion

Design the offline stack so the interfaces stay stable when you promote it.

Recommended path:

1. Develop prompts, chunking, schemas, and tool contracts locally
2. Keep storage interfaces stable even if the backing store later changes from SQLite to a managed service
3. Keep the MCP tool names stable while swapping the backend from localhost to approved cloud services
4. Promote the largest pain points first, usually model inference or shared retrieval
5. Keep offline mode as a fallback for privacy-sensitive or travel scenarios

A practical promotion sequence is:

- Start with Ollama + SQLite + local file tools
- Move inference to a managed endpoint when you need larger context or stronger reasoning
- Move retrieval or memory to a shared service only when collaboration or scale requires it
- Re-enable external MCP servers one at a time with governance review

## Docker-Based Option for Reproducible Environments

Docker works well when you want a repeatable local stack, but an air-gapped environment still needs the images and model data staged in advance.

Example `docker-compose.yml`:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    ports:
      - "127.0.0.1:11434:11434"
    volumes:
      - ollama-models:/root/.ollama

  agent-runtime:
    build: .
    depends_on:
      - ollama
    working_dir: /workspace
    environment:
      OPENAI_BASE_URL: http://ollama:11434/v1
      OPENAI_API_KEY: ollama
      MEMORY_DB_PATH: /workspace/.basecoat/memory.db
      EMBEDDINGS_DB_PATH: /workspace/.basecoat/embeddings.db
    volumes:
      - .:/workspace
    command: ["node", "tools/mcp/openai-compatible-server.js"]

volumes:
  ollama-models:
```

Offline Docker guidance:

1. Build or pull images on a connected machine
2. Save them with `docker save`
3. Transfer them through approved media
4. Load them on the offline machine with `docker load`
5. Pre-seed the Ollama volume with approved models before running the stack

If your environment disallows Docker networking entirely, keep the same architecture and run the processes directly on the host.

## Recommended Reading

- `docs/LOCAL_MODELS.md`
- `docs/LOCAL_EMBEDDINGS.md`
- `docs/SQLITE_MEMORY.md`
- `docs/HOOKS.md`
- `docs/CONFIG_PATTERN.md`
