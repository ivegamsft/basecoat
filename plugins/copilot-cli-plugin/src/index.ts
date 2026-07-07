import { DelegationResult, PluginConfig } from './types';
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

  async invoke(rawInput: string): Promise<DelegationResult> {
    try {
      let command;
      try {
        command = parseCommand(rawInput);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        return { success: false, error: msg, agentId: '', output: '', duration: 0 };
      }

      const context = buildContext(command);

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
