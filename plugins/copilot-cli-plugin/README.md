# basecoat

> GitHub Copilot CLI plugin — routes natural-language commands to the right [Basecoat](https://github.com/ivegamsft/basecoat) agent.

## Installation

```bash
npm install -g @basecoat/cli
# or use without installing:
npx basecoat <command>
```

## Usage

```bash
# Route a command to the best-matching agent
basecoat "review this pull request for security issues"

# List available agents
basecoat --list-agents

# Show help
basecoat --help

# Show version
basecoat --version
```

## How It Works

1. **Parse** — Natural language input is parsed to extract intent and context
2. **Lookup** — The agent registry (73 agents) is searched for the best match
3. **Delegate** — The matched agent receives the command and returns a result

## Agent Registry

The plugin ships with a registry of 73 Basecoat agents covering:

- Code review, security analysis, architecture design
- DevOps, CI/CD, infrastructure
- Frontend, backend, data tier development
- Documentation, testing, release management

See [agents/](https://github.com/ivegamsft/basecoat/tree/main/agents) for the full list.

## Configuration

| Environment Variable | Description | Default |
|---|---|---|
| `BASECOAT_REGISTRY_PATH` | Path to custom agent registry JSON | Built-in registry |
| `BASECOAT_TIMEOUT_MS` | Delegation timeout in milliseconds | `30000` |

## API

```typescript
import { BasecoatPlugin } from 'basecoat';

const plugin = new BasecoatPlugin();
const result = await plugin.invoke('analyze performance of this query');

if (result.success) {
  console.log('Agent:', result.agentName);
  console.log('Response:', result.response);
} else {
  console.error('Error:', result.error);
}
```

## License

MIT — see [LICENSE](../../LICENSE)
