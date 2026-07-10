import chalk from 'chalk';
import * as path from 'path';
import { compileAgent, compileAgentDirectory } from '../compile';
import * as fs from 'fs-extra';

export async function compileCommand(argv: any): Promise<void> {
  const { input, output, validate, strict, quiet, verbose } = argv;

  if (!quiet) {
    console.log(chalk.cyan(`Compiling: ${input}`));
  }

  try {
    const fullInputPath = path.resolve(input);
    const stat = await fs.lstat(fullInputPath);

    let results: any[] = [];

    if (stat.isDirectory()) {
      // Compile all .agent.md files in directory
      results = await compileAgentDirectory(fullInputPath, { validate, strict });
    } else if (stat.isFile()) {
      // Compile single file
      const result = await compileAgent({
        input: fullInputPath,
        output,
        validate,
        strict
      });
      results = [result];
    } else {
      console.error(chalk.red('✗'), 'Input is neither file nor directory');
      process.exit(1);
    }

    // Display results
    let hasErrors = false;

    for (const result of results) {
      const fileName = path.basename(result.sourceFile);

      if (result.success) {
        console.log(chalk.green('  ✓'), `Compiled: ${fileName}`);
        if (verbose) {
          console.log(chalk.gray(`    Output: ${result.lockFile}`));
        }
      } else {
        console.error(chalk.red('  ✗'), `Failed: ${fileName}`);
        hasErrors = true;

        if (result.errors) {
          for (const error of result.errors) {
            console.error(chalk.red(`    ${error}`));
          }
        }
      }

      if (verbose && result.warnings) {
        for (const warning of result.warnings) {
          console.warn(chalk.yellow(`    ${warning}`));
        }
      }
    }

    if (hasErrors) {
      process.exit(1);
    }

    if (!quiet) {
      console.log(chalk.green(`\n✓ Compilation complete`));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(chalk.red('✗'), `Compilation failed: ${message}`);
    process.exit(1);
  }
}
