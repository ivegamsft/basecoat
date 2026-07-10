import * as fs from 'fs-extra';
import * as path from 'path';

const AGENT_TEMPLATE = `---
name: {{ name }}
description: >
  {{ description }}
author: {{ author }}
version: 0.1.0
triggers:
  - issue.opened
  - pull_request.opened
instructions:
  - keep-it-simple
skills: []
mcp:
  - github-mcp-server
---

## Overview

This is a starter agent template. Replace this with your agent instructions.

## Behavior

- Responds to GitHub events
- Uses available MCP tools
- Follows BaseCoat patterns

## Example

Your agent implementation here.
`;

export async function initializeAgent(
  name: string,
  outputDir: string,
  options: {
    description?: string;
    author?: string;
  } = {}
): Promise<{ success: boolean; message: string; agentPath?: string }> {
  try {
    // Validate agent name
    if (!name || name.trim() === '') {
      return {
        success: false,
        message: 'Agent name is required'
      };
    }

    if (!/^[a-z0-9-]+$/.test(name)) {
      return {
        success: false,
        message: 'Agent name must contain only lowercase letters, numbers, and hyphens'
      };
    }

    // Create output directory
    const fullPath = path.resolve(outputDir);
    await fs.ensureDir(fullPath);

    // Check if agent already exists
    const agentPath = path.join(fullPath, `${name}.agent.md`);
    if (await fs.pathExists(agentPath)) {
      return {
        success: false,
        message: `Agent file already exists: ${agentPath}`
      };
    }

    // Render template
    let content = AGENT_TEMPLATE;
    content = content.replace('{{ name }}', name);
    content = content.replace('{{ description }}', options.description || 'A custom BaseCoat agent');
    content = content.replace('{{ author }}', options.author || 'Your Name');

    // Write agent file
    await fs.writeFile(agentPath, content, 'utf-8');

    // Create test directory structure
    const testDir = path.join(fullPath, `__tests__`);
    await fs.ensureDir(testDir);

    const testFile = path.join(testDir, `${name}.test.ts`);
    const testTemplate = `import { validateAgent } from '@basecoat/agent-sdk';
import * as fs from 'fs-extra';
import * as path from 'path';

describe('${name} agent', () => {
  it('should validate agent structure', async () => {
    const agentPath = path.join(__dirname, '..', '${name}.agent.md');
    const agent = await fs.readFile(agentPath, 'utf-8');
    const result = await validateAgent(agent);
    expect(result.valid).toBe(true);
  });
});
`;

    await fs.writeFile(testFile, testTemplate, 'utf-8');

    return {
      success: true,
      message: `Agent '${name}' scaffolded successfully at ${agentPath}`,
      agentPath
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      message: `Failed to initialize agent: ${message}`
    };
  }
}
