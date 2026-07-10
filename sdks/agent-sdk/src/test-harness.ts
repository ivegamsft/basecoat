import * as fs from 'fs-extra';
import * as path from 'path';
import { TestResult, TestCaseResult, TestCase } from './types';

export async function runTestHarness(testDir: string): Promise<TestResult> {
  const startTime = Date.now();
  const results: TestCaseResult[] = [];
  let passed = 0;
  let failed = 0;
  let skipped = 0;

  try {
    const fullPath = path.resolve(testDir);

    // Check if directory exists
    if (!(await fs.pathExists(fullPath))) {
      return {
        passed: 0,
        failed: 1,
        skipped: 0,
        duration: Date.now() - startTime,
        results: [
          {
            name: 'Directory Check',
            passed: false,
            error: `Test directory not found: ${fullPath}`,
            duration: 0
          }
        ]
      };
    }

    // Find test files
    const files = await fs.readdir(fullPath);
    const testFiles = files.filter((f: string) => f.endsWith('.test.ts') || f.endsWith('.test.json'));

    if (testFiles.length === 0) {
      skipped = 1;
      results.push({
        name: 'No test files found',
        passed: true,
        duration: 0
      });
    }

    // Load and run JSON-based test cases
    for (const file of testFiles.filter((f: string) => f.endsWith('.test.json'))) {
      const testCaseStartTime = Date.now();
      const filePath = path.join(fullPath, file);

      try {
        const content = await fs.readFile(filePath, 'utf-8');
        const testCases: TestCase[] = JSON.parse(content);

        for (const testCase of testCases) {
          const testStartTime = Date.now();
          try {
            // For Phase 1, we just validate the test case structure
            validateTestCase(testCase);

            results.push({
              name: testCase.name,
              passed: true,
              duration: Date.now() - testStartTime
            });
            passed++;
          } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            results.push({
              name: testCase.name,
              passed: false,
              error: message,
              duration: Date.now() - testStartTime
            });
            failed++;
          }
        }
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        results.push({
          name: `Test file: ${file}`,
          passed: false,
          error: `Failed to load test cases: ${message}`,
          duration: Date.now() - testCaseStartTime
        });
        failed++;
      }
    }

    return {
      passed,
      failed,
      skipped,
      duration: Date.now() - startTime,
      results
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      passed: 0,
      failed: 1,
      skipped: 0,
      duration: Date.now() - startTime,
      results: [
        {
          name: 'Test Harness Error',
          passed: false,
          error: message,
          duration: 0
        }
      ]
    };
  }
}

function validateTestCase(testCase: unknown): void {
  if (!testCase || typeof testCase !== 'object') {
    throw new Error('Test case must be an object');
  }

  const tc = testCase as Record<string, unknown>;

  if (!tc.name || typeof tc.name !== 'string') {
    throw new Error('Test case must have a name field');
  }

  if (!tc.description || typeof tc.description !== 'string') {
    throw new Error('Test case must have a description field');
  }

  if (!tc.inputs || typeof tc.inputs !== 'object') {
    throw new Error('Test case must have inputs object');
  }

  if (!tc.expectedOutputs || typeof tc.expectedOutputs !== 'object') {
    throw new Error('Test case must have expectedOutputs object');
  }
}

export function createTestTemplate(agentName: string): TestCase[] {
  return [
    {
      name: `${agentName} - Basic Trigger`,
      description: `Test that ${agentName} responds to basic trigger event`,
      inputs: {
        event: 'issue.opened',
        title: 'Test issue',
        body: 'This is a test'
      },
      expectedOutputs: {
        triggered: true,
        action: 'analyze'
      }
    },
    {
      name: `${agentName} - Edge Case`,
      description: `Test that ${agentName} handles edge cases gracefully`,
      inputs: {
        event: 'issue.opened',
        title: '',
        body: ''
      },
      expectedOutputs: {
        triggered: true,
        action: 'skip'
      }
    }
  ];
}
