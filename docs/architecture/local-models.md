# Local Models Guide

This guide extends `docs/MODEL_OPTIMIZATION.md` with practical local small language model (SLM) equivalents for teams that want to run Base Coat agents against Ollama instead of cloud-hosted APIs.

## Overview

Local SLMs make Base Coat usable in environments where cloud access is expensive, constrained, or impossible:

- **Offline development** when you are on a plane, in a lab, or behind unstable connectivity
- **Privacy-sensitive work** where source code should stay on the workstation or inside a controlled network
- **Cost-free iteration** for repeated prompts, agent tuning, and experimentation
- **Air-gapped environments** where external model endpoints are not allowed

Use **local models** when you are prototyping, working with privacy-sensitive code, conserving cloud quota, or operating fully offline. Use **cloud models** when you need the largest context windows, strongest instruction following, or the most reliable reasoning on complex governance-heavy tasks.

## Ollama Setup

Install Ollama on the machine that will host inference:

### macOS

- Download the app from [ollama.com/download](https://ollama.com/download)
- Or install with Homebrew:

```bash
brew install ollama
```

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Windows

- Download the Windows installer from [ollama.com/download](https://ollama.com/download)
- Or install via `winget` if your environment supports it:

```powershell
winget install Ollama.Ollama
```

After installation, pull the models you want to use:

```bash
ollama pull <model>
```

Examples:

```bash
ollama pull qwen3:8b
ollama pull qwen3:14b
ollama pull deepseek-r1:32b
ollama pull phi4
ollama pull gemma3:4b
```

Expose the OpenAI-compatible API locally:

```bash
ollama serve
```

By default, Ollama listens on `http://127.0.0.1:11434` and exposes an OpenAI-compatible endpoint at `http://127.0.0.1:11434/v1`.

## Model Tier Mapping

Approximate local equivalents for the cloud tiers in `docs/MODEL_OPTIMIZATION.md`:

| Base Coat Tier | Cloud Model | Local Equivalent | Parameters | RAM Required |
|---|---|---|---|---|
| Premium | claude-opus-4.6 | Qwen3-Coder-30B, DeepSeek-R1-32B | 30-32B | 32GB+ |
| Reasoning | claude-sonnet-4.6 | Qwen3-14B, Llama 3.3 70B (quantized) | 14-70B | 16-48GB |
| Code | gpt-5.3-codex | Qwen3-Coder-30B, CodeLlama 34B | 30-34B | 32GB+ |
| Fast | haiku/mini | Qwen3-8B, Phi-4, Gemma-3-4B | 4-8B | 8-16GB |

These mappings are directional, not exact replacements. Local models can be excellent for drafting, refactoring, search, and routine agent steps, but they are still below the best cloud models on long-horizon reasoning and strict policy adherence.

## Hardware Sizing

Assume quantized local models unless you have a workstation GPU with substantial VRAM.

- **Minimum:** 16GB RAM -> 8B models for fast-tier tasks only
- **Recommended:** 32GB RAM -> 14-30B models for most reasoning and code tasks
- **Optimal:** 64GB+ RAM or a GPU with 24GB VRAM -> 30B+ models with less aggressive quantization or unquantized variants

Rule of thumb:

- 4B-8B models are best for classification, summarization, formatting, and lightweight automation
- 14B models are the practical floor for serious local reasoning
- 30B+ models are where local coding and review quality becomes much more usable for Base Coat workflows

## Local Embeddings

For fully local semantic search, pair Ollama embeddings with `sqlite-vec`.

Recommended embedding models:

- `nomic-embed-text` — 768 dimensions, ~2GB
- `mxbai-embed-large` — 1024 dimensions, ~4GB

Pull an embedding model with:

```bash
ollama pull nomic-embed-text
```

A typical local stack is:

1. Ollama for generation and embeddings
2. `sqlite-vec` for vector storage and retrieval
3. A lightweight retrieval layer that injects the top matches into the agent prompt

This is often enough for private, offline code search and documentation retrieval without a hosted vector database.

## Limitations

Local SLM deployments are capable, but they do have tradeoffs:

- **Smaller context windows** on some models: often 4K-32K instead of 200K-class cloud models
- **Reduced instruction following** on complex governance or multi-rule compliance tasks
- **No native tool use** on some models; use wrappers or function-calling fine-tunes where needed
- **Quantization tradeoffs**: lower memory use and faster inference can reduce quality

When an agent must follow many layered constraints, produce high-stakes architectural reasoning, or operate over very large context windows, keep the cloud tier as the default.

## MCP Integration

Base Coat does not ship a local inference server, but any MCP-compatible bridge that speaks OpenAI-compatible APIs can be pointed at Ollama.

Use Ollama's local endpoint:

- Base URL: `http://127.0.0.1:11434/v1`
- API key: any placeholder string such as `ollama`

Example `mcp.json` snippet for a local inference tool:

```json
{
  "servers": {
    "local-inference": {
      "command": "node",
      "args": ["path\\to\\openai-compatible-mcp-server.js"],
      "env": {
        "OPENAI_BASE_URL": "http://127.0.0.1:11434/v1",
        "OPENAI_API_KEY": "ollama",
        "OPENAI_MODEL_FAST": "qwen3:8b",
        "OPENAI_MODEL_REASONING": "qwen3:14b",
        "OPENAI_MODEL_CODE": "qwen3-coder:30b",
        "OPENAI_MODEL_PREMIUM": "deepseek-r1:32b"
      }
    }
  }
}
```

If your tooling supports only a single model setting, start with a reasoning-tier model locally and override per task when latency or memory becomes a problem.

## Recommended Local Workflow

1. Keep the cloud defaults from `docs/MODEL_OPTIMIZATION.md` for high-stakes work
2. Add a local override for fast, code, or privacy-sensitive runs
3. Route embeddings to `nomic-embed-text` plus `sqlite-vec`
4. Fall back to cloud models when the task needs deep reasoning, long context, or strong governance compliance

In practice, many teams get the best results with a hybrid model policy: local first for drafts and private iteration, cloud for final review and critical decisions.
