import { BasecoatPlugin } from '../src/index';

describe('BasecoatPlugin', () => {
  it('instantiates with default config', () => {
    const plugin = new BasecoatPlugin();
    expect(plugin).toBeDefined();
  });

  it('returns version string', () => {
    const plugin = new BasecoatPlugin();
    expect(plugin.getVersion()).toBe('0.1.0');
  });
});

describe('BasecoatPlugin.invoke() e2e', () => {
  let plugin: BasecoatPlugin;

  beforeEach(() => {
    plugin = new BasecoatPlugin();
  });

  it('delegates a valid command successfully', async () => {
    const result = await plugin.invoke('/basecoat code-review review this PR');
    expect(result.success).toBe(true);
    expect(result.agentId).toBe('code-review');
  });

  it('surfaces the registry-derived agent vocabulary through the actual delegation output, not just resolveContext()', async () => {
    const result = await plugin.invoke('/basecoat code-review review this PR');
    expect(result.success).toBe(true);
    expect(result.output).toMatch(/Vocabulary: Code review and quality gate specialist\. USE FOR:/);
  });

  it('delegates to a real registry-only agent that is not one of the three stub agents (e.g. ship-it-control-loop from #2891)', async () => {
    const result = await plugin.invoke('/basecoat ship-it-control-loop run the next wave');
    expect(result.success).toBe(true);
    expect(result.agentId).toBe('ship-it-control-loop');
    expect(result.output).toMatch(/Vocabulary: Persistent fleet delivery loop coordinator/);
  });

  it('returns failure for unknown agent', async () => {
    const result = await plugin.invoke('/basecoat nonexistent-xyz do task');
    expect(result.success).toBe(false);
    expect(result.error).toMatch(/not found/i);
  });

  it('returns failure for input without /basecoat prefix', async () => {
    const result = await plugin.invoke('bad input no slash');
    expect(result.success).toBe(false);
  });

  it('returns failure for empty input', async () => {
    const result = await plugin.invoke('');
    expect(result.success).toBe(false);
  });
});

describe('BasecoatPlugin.resolveContext()', () => {
  let plugin: BasecoatPlugin;

  beforeEach(() => {
    plugin = new BasecoatPlugin();
  });

  it('surfaces the routed agent vocabulary (id/name/description/keywords) into context metadata', () => {
    const context = plugin.resolveContext('/basecoat code-review review this PR');

    expect(context).not.toBeNull();
    expect(context?.metadata['agentVocabulary']).toMatchObject({
      id: 'code-review',
      name: 'code-review',
      keywords: ['code', 'review'],
    });
    const vocabulary = context?.metadata['agentVocabulary'] as { description: string };
    // Guards against regressing to the registry's "No description" placeholder
    // (the exact bug reported in #2891) and confirms the real USE FOR
    // vocabulary from the agent's frontmatter is what gets surfaced.
    expect(vocabulary.description).not.toBe('No description');
    expect(vocabulary.description).toMatch(/^Code review and quality gate specialist\. USE FOR:/);
  });

  it('returns null when the agent cannot be resolved', () => {
    const context = plugin.resolveContext('/basecoat nonexistent-xyz do task');
    expect(context).toBeNull();
  });
});
