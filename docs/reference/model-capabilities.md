# Model Capability Framework

Generated from GitHub Docs model data retrieved through `gh api`, then enriched with BaseCoat routing guidance. Effective user and organization entitlements must still be verified by the authenticated Copilot runtime.

## Selection contract

1. Filter to GitHub-supported models and the target client.
2. Intersect with effective organization and user policy when runtime data is available.
3. Match task capability requirements before cost or latency.
4. Emit `reasoning_effort` only when the model is configurable and the authenticated runtime reports the exact effort value.
5. Prefer the lowest-cost model that passes task-specific evaluations.

`reasoning_depth` describes task complexity. It is not a provider parameter and must never be copied automatically into `reasoning_effort`.

## Models

| Model | Provider | Status | Copilot CLI | CLI auto-selection | Configurable reasoning | Task area |
|---|---|---|---:|---:|---:|---|
| `gpt-5-mini` | OpenAI | GA | True | True | False | General-purpose coding and writing |
| `kimi-k2.7-code` | Moonshot AI | GA | True | False | False | General-purpose coding and agent tasks |
| `raptor-mini` | Fine-tuned GPT-5 mini | GA | False | False | False | General-purpose coding and writing |
| `mai-code-1-flash-picker` | Microsoft | GA | True | True | False | General-purpose coding and writing |
| `gemini-3.6-flash` | Google | GA | True | False | False | Fast help with simple or repetitive tasks |
| `gemini-3.5-flash` | Google | GA | True | False | False | Fast help with simple or repetitive tasks |
| `gemini-3.1-pro-preview` | Google | Public preview | True | False | False | Deep reasoning and debugging |
| `claude-sonnet-5` | Anthropic | GA | True | False | True | General-purpose coding and agent tasks |
| `claude-sonnet-4.6` | Anthropic | GA | True | True | True | General-purpose coding and agent tasks |
| `claude-sonnet-4.5` | Anthropic | GA | True | False | False | General-purpose coding and agent tasks |
| `claude-opus-5` | Anthropic | GA | True | False | True | Deep reasoning and debugging |
| `claude-opus-4.8-fast` | Anthropic | GA | True | False | True | Deep reasoning and debugging |
| `claude-opus-4.8` | Anthropic | GA | True | False | True | Deep reasoning and debugging |
| `claude-opus-4.7` | Anthropic | GA | True | False | True | Deep reasoning and debugging |
| `claude-opus-4.6` | Anthropic | GA | True | False | True | Not classified by GitHub Docs |
| `claude-opus-4.5` | Anthropic | GA | True | False | False | Not classified by GitHub Docs |
| `claude-haiku-4.5` | Anthropic | GA | True | True | False | Fast help with simple or repetitive tasks |
| `claude-fable-5` | Anthropic | GA | True | False | True | Long-horizon, autonomous coding and knowledge-work |
| `gpt-5.6-terra` | OpenAI | GA | True | False | True | General-purpose coding and agent tasks |
| `gpt-5.6-sol` | OpenAI | GA | True | False | True | Deep reasoning and debugging |
| `gpt-5.6-luna` | OpenAI | GA | True | False | True | Fast help with simple or repetitive tasks |
| `gpt-5.5` | OpenAI | GA | True | False | True | Deep reasoning and debugging |
| `gpt-5.4-nano` | OpenAI | GA | False | False | False | Not classified by GitHub Docs |
| `gpt-5.4-mini` | OpenAI | GA | True | True | False | Agentic software development |
| `gpt-5.4` | OpenAI | GA | True | True | True | Deep reasoning and debugging |
| `gpt-5.3-codex` | OpenAI | GA | True | True | True | Agentic software development |
| `kimi-k3` | Moonshot AI | GA | True | False | True | Agentic coding and long-context work |
| `grok-4.5` | xAI | GA | True | False | False | General-purpose coding and agent tasks |

## Runtime availability

GitHub public REST does not currently expose the effective per-user Copilot model allowlist. The refresh script therefore records the public supported baseline from `github/docs`; callers must intersect it with the access-filtered Copilot runtime catalog when available. Do not substitute the GitHub Models inference catalog.
