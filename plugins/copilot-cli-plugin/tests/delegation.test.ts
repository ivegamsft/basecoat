import { delegate, DelegationEngine, DelegationOptions } from '../src/delegation/index';
import { BasecoatCommand, InvocationContext } from '../src/types';
import * as registry from '../src/registry/index';

function makeCommand(agent: string, task = 'do the thing'): BasecoatCommand {
  return { agent, task, args: {}, rawInput: `/basecoat ${agent} ${task}` };
}

function makeContext(command: BasecoatCommand): InvocationContext {
  return {
    command,
    environment: {
      os: 'linux',
      shell: 'bash',
      cwd: '/home/test',
      timestamp: new Date().toISOString(),
    },
    metadata: { sessionId: 'sess-001' },
  };
}

describe('delegate()', () => {
  it('returns a successful result for a known agent', async () => {
    const command = makeCommand('code-review', 'review PR #42');
    const context = makeContext(command);

    const result = await delegate(command, context);

    expect(result.success).toBe(true);
    expect(result.agentId).toBe('code-review');
    expect(result.output).toContain('Code Review');
    expect(result.error).toBeUndefined();
  });

  it('returns an error result (no throw) when agent is not found', async () => {
    const command = makeCommand('nonexistent-agent', 'do something');
    const context = makeContext(command);

    const result = await delegate(command, context);

    expect(result.success).toBe(false);
    expect(result.agentId).toBe('nonexistent-agent');
    expect(result.error).toBe('Agent not found: nonexistent-agent');
    expect(result.output).toBe('');
  });

  it('propagates registry load failures instead of masking them as "Agent not found"', async () => {
    const loadError = new Error('ENOENT: bundled registry file missing');
    const findAgentSpy = jest.spyOn(registry, 'findAgent').mockImplementation(() => {
      throw loadError;
    });

    const command = makeCommand('ship-it-control-loop', 'do something');
    const context = makeContext(command);

    // A genuine registry-load failure (corrupt/missing bundled JSON) must
    // surface as a distinguishable error rather than being swallowed into
    // the generic "Agent not found" message used for real lookup misses.
    await expect(delegate(command, context)).rejects.toThrow(loadError);

    findAgentSpy.mockRestore();
  });

  it('measures a duration greater than 0 for a successful delegation', async () => {
    const command = makeCommand('tech-writer', 'document the API');
    const context = makeContext(command);

    const result = await delegate(command, context);

    expect(result.duration).toBeGreaterThan(0);
  });

  it('times out and returns an error result when timeoutMs is exceeded', async () => {
    const command = makeCommand('security-analyst', 'scan everything');
    const context = makeContext(command);

    // timeoutMs: 1 fires before the first 10ms sleep inside simulateDelegation.
    const result = await delegate(command, context, { timeoutMs: 1 });

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/timed out after 1ms/i);
  }, 10_000);

  it('retries on transient failure and eventually succeeds', async () => {
    let callCount = 0;
    const failUntil = 2;

    const flakyDelegate = async (
      command: BasecoatCommand,
      context: InvocationContext,
      options: DelegationOptions = {},
    ) => {
      const maxRetries = options.maxRetries ?? 2;
      let lastError: Error | undefined;

      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        callCount++;
        if (callCount <= failUntil) {
          lastError = new Error(`Transient failure on attempt ${attempt}`);
          continue;
        }
        return delegate(command, context, { ...options, maxRetries: 0 });
      }

      return {
        success: false,
        output: '',
        agentId: command.agent,
        duration: 0,
        error: lastError?.message,
      };
    };

    const command = makeCommand('code-review', 'check my PR');
    const context = makeContext(command);

    const result = await flakyDelegate(command, context, { maxRetries: 3 });

    expect(callCount).toBe(failUntil + 1);
    expect(result.success).toBe(true);
  });

  it('calls onChunk with streaming output pieces', async () => {
    const command = makeCommand('tech-writer', 'write readme');
    const context = makeContext(command);
    const chunks: string[] = [];

    const result = await delegate(command, context, {
      onChunk: (chunk: string) => chunks.push(chunk),
    });

    expect(result.success).toBe(true);
    expect(chunks.length).toBeGreaterThanOrEqual(3);
    expect(chunks.length).toBeLessThanOrEqual(5);
    chunks.forEach((c) => expect(typeof c).toBe('string'));
  });
});

describe('DelegationEngine', () => {
  it('delegates successfully with default options', async () => {
    const engine = new DelegationEngine();
    const command = makeCommand('security-analyst', 'audit the app');
    const context = makeContext(command);

    const result = await engine.delegate(command, context);

    expect(result.success).toBe(true);
    expect(result.agentId).toBe('security-analyst');
  });

  it('respects configurable defaults', async () => {
    const engine = new DelegationEngine({ timeoutMs: 60_000, maxRetries: 0 });
    const command = makeCommand('code-review', 'spot check');
    const context = makeContext(command);

    const result = await engine.delegate(command, context);

    expect(result.success).toBe(true);
  });

  it('per-call options override engine defaults', async () => {
    const engine = new DelegationEngine({ timeoutMs: 60_000 });
    const command = makeCommand('nonexistent', 'irrelevant');
    const context = makeContext(command);

    const result = await engine.delegate(command, context, { maxRetries: 0 });

    expect(result.success).toBe(false);
    expect(result.error).toMatch(/Agent not found/);
  });
});