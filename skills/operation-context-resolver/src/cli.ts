import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { OperationContextResolver } from './resolver.js';
import { ResolverInput } from './types.js';
import { validateEnvironmentMap } from './validator.js';

interface CliLogger {
  log: (message?: unknown) => void;
  warn: (message?: unknown) => void;
  error: (message?: unknown) => void;
}

interface CliRuntime {
  cwd: string;
  env: NodeJS.ProcessEnv;
  logger: CliLogger;
}

interface ResolveCliOptions {
  repoRoot: string;
  output: string;
  githubRef?: string;
  githubEventName?: string;
  userIntent?: string;
  workflowEnvironment?: string;
  deploymentRecordSha?: string;
  prLabels: string[];
}

const DEFAULT_OUTPUT_FILE = 'operation-context.json';

function usage(logger: CliLogger): number {
  logger.error('Usage: operation-context-resolver <validate|resolve> [options]');
  logger.error('  validate [--repo-root <path>]');
  logger.error('  resolve [--repo-root <path>] [--output <path>] [--github-ref <ref>]');
  logger.error('          [--github-event-name <name>] [--user-intent <text>]');
  logger.error('          [--workflow-environment <environment>] [--deployment-record-sha <sha>]');
  logger.error('          [--pr-label <label>]...');
  return 1;
}

function readRequiredValue(argv: string[], index: number, flag: string): string {
  const value = argv[index + 1];
  if (!value) {
    throw new Error(`Missing value for ${flag}`);
  }

  return value;
}

function parseValidateArgs(args: string[], runtime: CliRuntime): { repoRoot: string } {
  let repoRoot = runtime.cwd;

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    switch (arg) {
      case '--repo-root':
        repoRoot = readRequiredValue(args, index, arg);
        index += 1;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return { repoRoot };
}

function parseResolveArgs(args: string[], runtime: CliRuntime): ResolveCliOptions {
  const options: ResolveCliOptions = {
    repoRoot: runtime.cwd,
    output: DEFAULT_OUTPUT_FILE,
    githubRef: runtime.env.GITHUB_REF,
    githubEventName: runtime.env.GITHUB_EVENT_NAME,
    userIntent: undefined,
    workflowEnvironment: undefined,
    deploymentRecordSha: undefined,
    prLabels: [],
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];

    switch (arg) {
      case '--repo-root':
        options.repoRoot = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--output':
        options.output = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--github-ref':
        options.githubRef = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--github-event-name':
        options.githubEventName = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--user-intent':
        options.userIntent = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--workflow-environment':
        options.workflowEnvironment = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--deployment-record-sha':
        options.deploymentRecordSha = readRequiredValue(args, index, arg);
        index += 1;
        break;
      case '--pr-label':
        options.prLabels.push(readRequiredValue(args, index, arg));
        index += 1;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function readGithubEventPayload(env: NodeJS.ProcessEnv): string | undefined {
  if (env.GITHUB_EVENT_PATH) {
    return fs.readFileSync(env.GITHUB_EVENT_PATH, 'utf-8');
  }

  return env.GITHUB_EVENT;
}

async function runValidate(args: string[], runtime: CliRuntime): Promise<number> {
  const { repoRoot } = parseValidateArgs(args, runtime);
  const result = await validateEnvironmentMap(repoRoot);

  if (result.valid) {
    runtime.logger.log('[OK] environment-map.yml is valid');
    runtime.logger.log(
      `[OK] Found ${result.environments_found.length} environments: ${result.environments_found.join(', ')}`
    );
    runtime.logger.log(`[OK] Found ${result.rules_count} rules`);
  } else {
    runtime.logger.error('[ERROR] environment-map.yml validation failed');
  }

  for (const warning of result.warnings) {
    runtime.logger.warn(`[WARN] ${warning}`);
  }

  for (const error of result.errors) {
    runtime.logger.error(`[ERROR] ${error}`);
  }

  return result.valid ? 0 : 1;
}

async function runResolve(args: string[], runtime: CliRuntime): Promise<number> {
  const options = parseResolveArgs(args, runtime);
  const resolver = await OperationContextResolver.fromRepoRoot(options.repoRoot);

  const input: ResolverInput = {
    repo_root: options.repoRoot,
    github_ref: options.githubRef,
    github_event_name: options.githubEventName,
    github_event_payload: readGithubEventPayload(runtime.env),
    user_intent: options.userIntent,
    pr_labels: options.prLabels.length > 0 ? options.prLabels : undefined,
    workflow_dispatch_input: options.workflowEnvironment
      ? { environment: options.workflowEnvironment }
      : undefined,
    deployment_record_sha: options.deploymentRecordSha,
  };

  const context = await resolver.resolve(input);
  const outputPath = path.isAbsolute(options.output)
    ? options.output
    : path.join(runtime.cwd, options.output);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(context, null, 2)}\n`, 'utf-8');

  runtime.logger.log(`Operation context written to ${outputPath}`);
  runtime.logger.log(`Resolved ${context.target_environment} in ${context.mode} mode`);

  return 0;
}

export async function main(
  args: string[] = process.argv.slice(2),
  runtimeOverrides: Partial<CliRuntime> = {}
): Promise<number> {
  const runtime: CliRuntime = {
    cwd: runtimeOverrides.cwd ?? process.cwd(),
    env: runtimeOverrides.env ?? process.env,
    logger: runtimeOverrides.logger ?? console,
  };

  try {
    const [command, ...commandArgs] = args;

    if (!command) {
      return usage(runtime.logger);
    }

    if (command === 'validate') {
      return await runValidate(commandArgs, runtime);
    }

    if (command === 'resolve') {
      return await runResolve(commandArgs, runtime);
    }

    return usage(runtime.logger);
  } catch (error) {
    runtime.logger.error(`[ERROR] ${error instanceof Error ? error.message : String(error)}`);
    return 1;
  }
}

const isMainModule =
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (isMainModule) {
  void main().then(code => {
    process.exit(code);
  });
}
