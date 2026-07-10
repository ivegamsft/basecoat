import chalk from 'chalk';
import { initializeAgent } from '../init';

export async function initCommand(argv: any): Promise<void> {
  const { name, directory, description, author, quiet } = argv;

  if (!quiet) {
    console.log(chalk.cyan(`Creating agent: ${name}`));
  }

  const result = await initializeAgent(name, directory, { description, author });

  if (result.success) {
    console.log(chalk.green('✓'), result.message);
    if (!quiet && result.agentPath) {
      console.log(chalk.gray(`  Location: ${result.agentPath}`));
    }
  } else {
    console.error(chalk.red('✗'), result.message);
    process.exit(1);
  }
}
