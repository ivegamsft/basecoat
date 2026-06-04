import * as fs from 'fs-extra';
import * as path from 'path';
import { compileAgent } from '../src/compile';
import { initializeAgent } from '../src/init';

describe('compileAgent', () => {
  const testDir = path.join(__dirname, 'fixtures', 'compile');

  beforeAll(async () => {
    await fs.ensureDir(testDir);
  });

  afterAll(async () => {
    await fs.remove(testDir);
  });

  it('should compile agent file successfully', async () => {
    // Create test agent
    const agentName = 'test-compile-agent';
    await initializeAgent(agentName, testDir, {
      description: 'A test agent for compilation',
      author: 'Test'
    });

    const agentPath = path.join(testDir, `${agentName}.agent.md`);
    const lockPath = path.join(testDir, `${agentName}.lock.yml`);

    // Compile
    const result = await compileAgent({
      input: agentPath,
      output: lockPath,
      validate: true
    });

    expect(result.success).toBe(true);
    expect(result.lockFile).toBe(lockPath);
    expect(result.sourceFile).toBe(agentPath);
    expect(await fs.pathExists(lockPath)).toBe(true);
  });

  it('should reject non-existent input file', async () => {
    const result = await compileAgent({
      input: path.join(testDir, 'non-existent.agent.md'),
      validate: false
    });

    expect(result.success).toBe(false);
    expect(result.errors).toBeDefined();
  });

  it('should use default output path', async () => {
    const agentName = 'test-default-output';
    await initializeAgent(agentName, testDir, {
      description: 'A test agent for output path testing',
      author: 'Test'
    });

    const agentPath = path.join(testDir, `${agentName}.agent.md`);

    const result = await compileAgent({
      input: agentPath,
      validate: false
    });

    expect(result.success).toBe(true);
    const expectedPath = agentPath.replace(/\.agent\.md$/, '.lock.yml');
    expect(result.lockFile).toBe(expectedPath);
  });
});
