import { validateEnvironmentMap } from './validator';

function usage(): never {
  console.error('Usage: operation-context-resolver validate [--repo-root <path>]');
  process.exit(1);
}

function getRepoRoot(argv: string[]): string {
  const index = argv.indexOf('--repo-root');
  if (index === -1) {
    return process.cwd();
  }
  const value = argv[index + 1];
  if (!value) {
    throw new Error('Missing value for --repo-root');
  }
  return value;
}

async function runValidate(args: string[]): Promise<void> {
  const repoRoot = getRepoRoot(args);
  const result = await validateEnvironmentMap(repoRoot);

  if (result.valid) {
    console.log('[OK] environment-map.yml is valid');
    console.log(`[OK] Found ${result.environments_found.length} environments: ${result.environments_found.join(', ')}`);
    console.log(`[OK] Found ${result.rules_count} rules`);
  } else {
    console.error('[ERROR] environment-map.yml validation failed');
  }

  for (const warning of result.warnings) {
    console.warn(`[WARN] ${warning}`);
  }

  for (const error of result.errors) {
    console.error(`[ERROR] ${error}`);
  }

  process.exit(result.valid ? 0 : 1);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command) {
    usage();
  }

  if (command === 'validate') {
    await runValidate(args.slice(1));
    return;
  }

  usage();
}

void main().catch(error => {
  console.error(`[ERROR] ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
