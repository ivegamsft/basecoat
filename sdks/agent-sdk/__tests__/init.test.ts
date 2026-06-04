import * as fs from 'fs-extra';
import * as path from 'path';
import { initializeAgent } from '../src/init';

describe('initializeAgent', () => {
  const testDir = path.join(__dirname, 'fixtures', 'init');

  beforeAll(async () => {
    await fs.ensureDir(testDir);
  });

  afterAll(async () => {
    await fs.remove(testDir);
  });

  it('should scaffold new agent', async () => {
    const result = await initializeAgent('test-agent', testDir, {
      description: 'A test agent',
      author: 'Test Author'
    });

    expect(result.success).toBe(true);
    expect(result.agentPath).toBeDefined();

    const agentFile = path.join(testDir, 'test-agent.agent.md');
    expect(await fs.pathExists(agentFile)).toBe(true);

    const content = await fs.readFile(agentFile, 'utf-8');
    expect(content).toContain('name: test-agent');
    expect(content).toContain('A test agent');
    expect(content).toContain('Test Author');
  });

  it('should reject invalid agent name', async () => {
    const result = await initializeAgent('Invalid_Name', testDir);

    expect(result.success).toBe(false);
    expect(result.message).toContain('lowercase');
  });

  it('should reject empty agent name', async () => {
    const result = await initializeAgent('', testDir);

    expect(result.success).toBe(false);
    expect(result.message).toContain('required');
  });

  it('should reject duplicate agent', async () => {
    const agentName = 'duplicate-test';
    await initializeAgent(agentName, testDir);

    const result = await initializeAgent(agentName, testDir);

    expect(result.success).toBe(false);
    expect(result.message).toContain('already exists');
  });

  it('should create test directory structure', async () => {
    const agentName = 'test-structure';
    await initializeAgent(agentName, testDir);

    const testDirPath = path.join(testDir, '__tests__');
    expect(await fs.pathExists(testDirPath)).toBe(true);

    const testFile = path.join(testDirPath, `${agentName}.test.ts`);
    expect(await fs.pathExists(testFile)).toBe(true);
  });

  it('should use kebab-case names', async () => {
    const result = await initializeAgent('valid-kebab-case', testDir, {
      description: 'Test kebab case'
    });

    expect(result.success).toBe(true);
  });
});
