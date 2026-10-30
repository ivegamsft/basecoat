import { DelegationResult, InvocationContext, PluginConfig } from './types';
import { parseCommand } from './parser/index';
import { buildContext } from './context/index';
import { findAgent } from './registry/index';
import { delegate } from './delegation/index';

const DEFAULT_CONFIG: PluginConfig = {
  registryUrl: 'https://raw.githubusercontent.com/ivegamsft/basecoat/main/registry.json',
  cacheTtlMs: 300_000,
  timeoutMs: 30_000,
  maxConcurrency: 4,
};

export class BasecoatPlugin {
  private readonly config: PluginConfig;

  constructor(config?: Partial<PluginConfig>) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Resolves the routed agent for `rawInput` and returns the invocation
   * context that would be handed to delegation, with the agent's
   * registry-derived vocabulary (description/USE FOR guidance sourced from
   * its agents/*.agent.md frontmatter) surfaced under
   * `metadata.agentVocabulary`. Returns `null` when the agent cannot be
   * resolved. Exposed so callers (and tests) can verify that repo-specific
   * vocabulary is actually surfaced into context at routing time, instead of
   * being re-derived from scratch each session (see issue #2891).
   */
  resolveContext(rawInput: string): InvocationContext | null {
    const command = parseCommand(rawInput);
    const context = buildContext(command);

    const agent = findAgent(command.agent);
    if (!agent) {
      return null;
    }

    context.metadata['agentVocabulary'] = {
      id: agent.id,
      name: agent.name,
      description: agent.description,
      keywords: agent.keywords,
    };

    return context;
  }

  async invoke(rawInput: string): Promise<DelegationResult> {
    try {
      let command;
      try {
        command = parseCommand(rawInput);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        return { success: false, error: msg, agentId: '', output: '', duration: 0 };
      }

      const agent = findAgent(command.agent);
      if (!agent) {
        return {
          success: false,
          error: `Agent not found: ${command.agent}`,
          agentId: command.agent,
          output: '',
          duration: 0,
        };
      }

      // Surface the agent's registry-derived vocabulary into the session
      // context so downstream reasoning doesn't have to re-derive
      // repo-specific terms (e.g. "wave") from scratch each invocation.
      const context = buildContext(command, {
        agentVocabulary: {
          id: agent.id,
          name: agent.name,
          description: agent.description,
          keywords: agent.keywords,
        },
      });

      return await delegate(command, context, { timeoutMs: this.config.timeoutMs });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { success: false, error: msg, agentId: '', output: '', duration: 0 };
    }
  }

  getVersion(): string {
    return '0.1.0';
  }
}

export type { BasecoatCommand, AgentEntry, AgentRegistry, InvocationContext, DelegationResult, PluginConfig } from './types';
