import { validateAgent } from '../src/validate';

describe('validateAgent', () => {
  it('should validate correct agent', async () => {
    const agent = `---
name: test-agent
description: A test agent for validation
author: Test Author
version: 0.1.0
triggers:
  - pull_request
instructions:
  - keep-it-simple
skills: []
mcp:
  - github-mcp-server
---

## Overview

This is a test agent.

## Behavior

Test behavior here.
`;

    const result = await validateAgent(agent);
    expect(result.valid).toBe(true);
    expect(result.errors.length).toBe(0);
  });

  it('should reject agent without name', async () => {
    const agent = `---
description: A test agent
---

## Overview

Test.
`;

    const result = await validateAgent(agent);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e: any) => e.code === 'MISSING_NAME')).toBe(true);
  });

  it('should reject agent with invalid name format', async () => {
    const agent = `---
name: InvalidName
description: A test agent
---

## Overview

Test.
`;

    const result = await validateAgent(agent);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e: any) => e.code === 'INVALID_NAME_FORMAT')).toBe(true);
  });

  it('should reject agent without description', async () => {
    const agent = `---
name: test-agent
---

## Overview

Test.
`;

    const result = await validateAgent(agent);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e: any) => e.code === 'MISSING_DESCRIPTION')).toBe(true);
  });

  it('should warn on short description', async () => {
    const agent = `---
name: test-agent
description: Short
---

## Overview

Test.
`;

    const result = await validateAgent(agent);
    expect(result.warnings.some((w: any) => w.code === 'SHORT_DESCRIPTION')).toBe(true);
  });

  it('should warn on empty body', async () => {
    const agent = `---
name: test-agent
description: A valid test agent
---
`;

    const result = await validateAgent(agent);
    expect(result.warnings.some((w: any) => w.code === 'EMPTY_BODY')).toBe(true);
  });

  it('should reject malformed frontmatter', async () => {
    const agent = `---
name: test-agent
description: A test agent

## Overview

Test.
`;

    const result = await validateAgent(agent);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e: any) => e.code === 'PARSE_ERROR')).toBe(true);
  });
});
