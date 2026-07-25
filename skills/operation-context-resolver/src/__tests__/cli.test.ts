import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { main } from '../cli.js';

function createRepoRoot(): string {
  return createRepoRootWithContent(`
environments:
  preview:
    github_environment: preview
    production: false
    azure_subscription: sub-preview
    resource_group: rg-preview
    allowed_branch_patterns:
      - feature/*
    allowed_actions:
      branch_deploy: [read_logs]
      read_only: [read_logs]
    blocked_actions:
      branch_deploy: [deploy]
      read_only: [deploy]
  dev:
    github_environment: dev
    production: false
    azure_subscription: sub-dev
    resource_group: rg-dev
    allowed_branch_patterns:
      - dev
    allowed_actions:
      read_only: [read_logs]
    blocked_actions:
      read_only: [deploy]
`.trim());
}

function createRepoRootWithContent(content: string): string {
  const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'operation-context-cli-'));
  fs.mkdirSync(path.join(repoRoot, '.github'), { recursive: true });
  fs.writeFileSync(
    path.join(repoRoot, '.github', 'environment-map.yml'),
    content,
    'utf-8'
  );

  return repoRoot;
}

function createLogger() {
  const messages = {
    log: [] as string[],
    warn: [] as string[],
    error: [] as string[],
  };

  return {
    messages,
    logger: {
      log: (message?: unknown) => messages.log.push(String(message)),
      warn: (message?: unknown) => messages.warn.push(String(message)),
      error: (message?: unknown) => messages.error.push(String(message)),
    },
  };
}

describe('operation-context-resolver CLI', () => {
  it('should print usage when no command is provided', async () => {
    const { logger, messages } = createLogger();

    const code = await main([], { logger, env: {}, cwd: process.cwd() });

    expect(code).toBe(1);
    expect(messages.error[0]).toContain('Usage: operation-context-resolver');
  });

  it('should validate a repo environment map', async () => {
    const repoRoot = createRepoRoot();
    const { logger, messages } = createLogger();

    const code = await main(['validate', '--repo-root', repoRoot], {
      logger,
      env: {},
      cwd: repoRoot,
    });

    expect(code).toBe(0);
    expect(messages.log).toContain('[OK] environment-map.yml is valid');
  });

  it('should print warnings for a minimally valid environment map', async () => {
    const repoRoot = createRepoRootWithContent(`
environments:
  dev:
    github_environment: dev
    production: false
    azure_subscription: sub-dev
    resource_group: rg-dev
`.trim());
    const { logger, messages } = createLogger();

    const code = await main(['validate', '--repo-root', repoRoot], {
      logger,
      env: {},
      cwd: repoRoot,
    });

    expect(code).toBe(0);
    expect(messages.warn).toContain('[WARN] dev: no allowed_branch_patterns defined');
    expect(messages.warn).toContain('[WARN] dev: no allowed_actions defined');
    expect(messages.warn).toContain('[WARN] dev: no blocked_actions defined');
  });

  it('should return validation errors when the environment map is missing', async () => {
    const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'operation-context-cli-missing-'));
    const { logger, messages } = createLogger();

    const code = await main(['validate', '--repo-root', repoRoot], {
      logger,
      env: {},
      cwd: repoRoot,
    });

    expect(code).toBe(1);
    expect(messages.error).toContain('[ERROR] environment-map.yml validation failed');
    expect(messages.error.at(-1)).toContain('environment-map.yml not found');
  });

  it('should resolve and write operation-context.json', async () => {
    const repoRoot = createRepoRoot();
    const outputPath = path.join(repoRoot, 'artifacts', 'operation-context.json');
    const { logger, messages } = createLogger();

    const code = await main(
      ['resolve', '--repo-root', repoRoot, '--output', outputPath, '--github-ref', 'refs/heads/feature/test'],
      {
        logger,
        env: {},
        cwd: repoRoot,
      }
    );

    expect(code).toBe(0);
    expect(messages.log[0]).toContain('Operation context written');

    const context = JSON.parse(fs.readFileSync(outputPath, 'utf-8')) as { target_environment: string; mode: string };
    expect(context.target_environment).toBe('preview');
    expect(context.mode).toBe('branch_deploy');
  });

  it('should resolve using event payload, labels, and deployment options', async () => {
    const repoRoot = createRepoRoot();
    const outputPath = path.join(repoRoot, 'operation-context.json');
    const eventPath = path.join(repoRoot, 'event.json');
    fs.writeFileSync(
      eventPath,
      JSON.stringify({
        pull_request: {
          head: { ref: 'feature/from-event' },
          labels: [{ name: 'type:test' }],
        },
      }),
      'utf-8'
    );
    const { logger } = createLogger();

    const code = await main(
      [
        'resolve',
        '--repo-root',
        repoRoot,
        '--output',
        outputPath,
        '--user-intent',
        'check deployment context',
        '--deployment-record-sha',
        'abc123',
        '--pr-label',
        'type:test',
      ],
      {
        logger,
        env: {
          GITHUB_EVENT_PATH: eventPath,
          GITHUB_EVENT_NAME: 'pull_request',
        },
        cwd: repoRoot,
      }
    );

    expect(code).toBe(0);

    const context = JSON.parse(fs.readFileSync(outputPath, 'utf-8')) as { target_environment: string; mode: string };
    expect(context.target_environment).toBe('preview');
    expect(context.mode).toBe('read_only');
  });

  it('should return an error code for invalid resolve options', async () => {
    const repoRoot = createRepoRoot();
    const { logger, messages } = createLogger();

    const code = await main(
      ['resolve', '--repo-root', repoRoot, '--workflow-environment', 'qa'],
      {
        logger,
        env: {},
        cwd: repoRoot,
      }
    );

    expect(code).toBe(1);
    expect(messages.error.at(-1)).toContain("Invalid workflow_dispatch_input.environment 'qa'");
  });

  it('should return an error code for unknown commands and arguments', async () => {
    const repoRoot = createRepoRoot();
    const { logger, messages } = createLogger();

    const unknownCommandCode = await main(['unknown-command'], {
      logger,
      env: {},
      cwd: repoRoot,
    });
    const unknownArgumentCode = await main(['validate', '--bad-flag'], {
      logger,
      env: {},
      cwd: repoRoot,
    });

    expect(unknownCommandCode).toBe(1);
    expect(unknownArgumentCode).toBe(1);
    expect(messages.error).toContain('Usage: operation-context-resolver <validate|resolve> [options]');
    expect(messages.error.at(-1)).toContain('Unknown argument: --bad-flag');
  });

  it('should return an error code for missing resolve argument values', async () => {
    const repoRoot = createRepoRoot();
    const { logger, messages } = createLogger();

    const code = await main(['resolve', '--github-event-name'], {
      logger,
      env: {},
      cwd: repoRoot,
    });

    expect(code).toBe(1);
    expect(messages.error.at(-1)).toContain('Missing value for --github-event-name');
  });
});
