#!/usr/bin/env node
import { BasecoatPlugin } from './index';

export async function runCli(args: string[], plugin?: BasecoatPlugin): Promise<void> {
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    console.log(`
Basecoat CLI Plugin v${getVersion()}

Usage:
  basecoat <agent-id> <task> [--key value ...]
  basecoat --help
  basecoat --version

Examples:
  basecoat code-review "review this PR for security issues"
  basecoat security-analyst "scan src/ for vulnerabilities" --severity high
`);
    process.exit(0);
    return;
  }

  if (args[0] === '--version' || args[0] === '-v') {
    console.log(getVersion());
    process.exit(0);
    return;
  }

  // Reconstruct raw input as /basecoat <args...>
  const rawInput = `/basecoat ${args.join(' ')}`;
  const p = plugin ?? new BasecoatPlugin();

  try {
    const result = await p.invoke(rawInput);
    if (result.success) {
      console.log(result.output);
      process.exit(0);
    } else {
      console.error(`Error: ${result.error}`);
      process.exit(1);
    }
  } catch (err) {
    // In tests, process.exit is mocked to throw — re-throw those so they
    // propagate to the test harness rather than being swallowed as fatals.
    if (err instanceof Error && err.message.startsWith('process.exit(')) {
      throw err;
    }
    console.error(`Fatal: ${(err as Error).message}`);
    process.exit(1);
  }
}

function getVersion(): string {
  // eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
  return require('../package.json').version as string;
}

if (require.main === module) {
  runCli(process.argv.slice(2));
}
