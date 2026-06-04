import chalk from 'chalk';
import { runTestHarness } from '../test-harness';

export async function testCommand(argv: any): Promise<void> {
  const { directory, quiet, verbose } = argv;

  if (!quiet) {
    console.log(chalk.cyan(`Running tests in: ${directory}`));
  }

  try {
    const result = await runTestHarness(directory);

    if (!quiet || result.failed > 0) {
      console.log(chalk.gray(`\nTest Results:`));
      console.log(
        `  ${chalk.green(`${result.passed} passed`)}, ${chalk.red(`${result.failed} failed`)}, ${chalk.gray(`${result.skipped} skipped`)}`
      );
      console.log(chalk.gray(`  Duration: ${result.duration}ms`));
    }

    if (verbose) {
      console.log(chalk.gray(`\nDetailed Results:`));
      for (const testResult of result.results) {
        const icon = testResult.passed ? chalk.green('✓') : chalk.red('✗');
        console.log(`  ${icon} ${testResult.name}`);
        if (testResult.error && verbose) {
          console.log(chalk.red(`    Error: ${testResult.error}`));
        }
        if (verbose) {
          console.log(chalk.gray(`    Duration: ${testResult.duration}ms`));
        }
      }
    }

    if (result.failed > 0) {
      process.exit(1);
    }

    if (!quiet) {
      console.log(chalk.green('\n✓ All tests passed'));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(chalk.red('✗'), `Test execution failed: ${message}`);
    process.exit(1);
  }
}
