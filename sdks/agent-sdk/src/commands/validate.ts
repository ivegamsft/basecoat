import chalk from 'chalk';
import * as fs from 'fs-extra';
import * as path from 'path';
import { validateAgentFile } from '../validate';

export async function validateCommand(argv: any): Promise<void> {
  const { path: inputPath, strict, quiet, verbose } = argv;

  if (!quiet) {
    console.log(chalk.cyan(`Validating: ${inputPath}`));
  }

  try {
    const fullPath = path.resolve(inputPath);
    const stat = await fs.lstat(fullPath);

    let results: any[] = [];

    if (stat.isDirectory()) {
      // Validate all .agent.md files in directory
      const files = await fs.readdir(fullPath);
      const agentFiles = files.filter(f => f.endsWith('.agent.md'));

      if (agentFiles.length === 0) {
        console.warn(chalk.yellow('⚠'), 'No .agent.md files found in directory');
        return;
      }

      for (const file of agentFiles) {
        const filePath = path.join(fullPath, file);
        const result = await validateAgentFile(filePath);
        results.push({ file, result });
      }
    } else if (stat.isFile()) {
      // Validate single file
      const result = await validateAgentFile(fullPath);
      results.push({ file: inputPath, result });
    } else {
      console.error(chalk.red('✗'), 'Path is neither file nor directory');
      process.exit(1);
    }

    // Display results
    let hasErrors = false;
    let hasWarnings = false;

    for (const { file, result } of results) {
      if (!quiet || result.errors.length > 0) {
        console.log(chalk.gray(`\n${file}`));
      }

      if (result.valid) {
        console.log(chalk.green('  ✓ Valid'));
      } else {
        console.log(chalk.red('  ✗ Invalid'));
        hasErrors = true;
      }

      // Display errors
      for (const error of result.errors) {
        console.error(
          chalk.red(`    [${error.code}] ${error.message}`),
          error.line ? `(line ${error.line})` : ''
        );
      }

      // Display warnings
      if (verbose || strict) {
        for (const warning of result.warnings) {
          if (strict) {
            console.warn(chalk.red(`    [${warning.code}] ${warning.message}`));
            hasWarnings = true;
          } else {
            console.warn(chalk.yellow(`    [${warning.code}] ${warning.message}`));
          }
        }
      }
    }

    if (hasErrors || (hasWarnings && strict)) {
      process.exit(1);
    }

    if (!quiet && !hasErrors) {
      console.log(chalk.green('\n✓ All agents valid'));
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(chalk.red('✗'), `Validation failed: ${message}`);
    process.exit(1);
  }
}
