import * as fs from 'fs-extra';
import * as path from 'path';
import { runTestHarness, createTestTemplate } from '../src/test-harness';

describe('runTestHarness', () => {
  const testFixturesDir = path.join(__dirname, 'fixtures', 'test-harness');

  beforeAll(async () => {
    await fs.ensureDir(testFixturesDir);
  });

  afterAll(async () => {
    await fs.remove(testFixturesDir);
  });

  it('should return results for valid test cases', async () => {
    const testDir = path.join(testFixturesDir, 'valid');
    await fs.ensureDir(testDir);

    const testCases = createTestTemplate('test-agent');
    const testFile = path.join(testDir, 'test.test.json');
    await fs.writeFile(testFile, JSON.stringify(testCases), 'utf-8');

    const result = await runTestHarness(testDir);

    expect(result.passed).toBeGreaterThan(0);
    expect(result.results.length).toBeGreaterThan(0);
    expect(result.duration).toBeGreaterThan(0);
  });

  it('should handle non-existent directory', async () => {
    const result = await runTestHarness(path.join(testFixturesDir, 'non-existent'));

    expect(result.failed).toBe(1);
    expect(result.results[0].passed).toBe(false);
  });

  it('should skip when no test files found', async () => {
    const testDir = path.join(testFixturesDir, 'no-tests');
    await fs.ensureDir(testDir);

    const result = await runTestHarness(testDir);

    expect(result.skipped).toBe(1);
    expect(result.failed).toBe(0);
  });

  it('should report errors for invalid test cases', async () => {
    const testDir = path.join(testFixturesDir, 'invalid');
    await fs.ensureDir(testDir);

    const testFile = path.join(testDir, 'invalid.test.json');
    await fs.writeFile(testFile, JSON.stringify([{ name: 'incomplete' }]), 'utf-8');

    const result = await runTestHarness(testDir);

    expect(result.failed).toBeGreaterThan(0);
  });
});

describe('createTestTemplate', () => {
  it('should generate test template', () => {
    const template = createTestTemplate('my-agent');

    expect(template.length).toBe(2);
    expect(template[0].name).toContain('my-agent');
    expect(template[0].inputs).toBeDefined();
    expect(template[0].expectedOutputs).toBeDefined();
  });
});
