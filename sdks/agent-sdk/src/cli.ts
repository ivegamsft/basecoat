#!/usr/bin/env node

import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import chalk from 'chalk';
import { initCommand } from './commands/init';
import { validateCommand } from './commands/validate';
import { compileCommand } from './commands/compile';
import { testCommand } from './commands/test';

yargs(hideBin(process.argv))
  .command(
    'init <name> [directory]',
    'Scaffold a new agent',
    (yargs) =>
      yargs
        .positional('name', {
          describe: 'Agent name (kebab-case)',
          type: 'string'
        })
        .positional('directory', {
          describe: 'Output directory (default: current)',
          type: 'string',
          default: '.'
        })
        .option('description', {
          describe: 'Agent description',
          type: 'string',
          alias: 'd'
        })
        .option('author', {
          describe: 'Agent author',
          type: 'string',
          alias: 'a'
        }),
    (argv) => initCommand(argv as any)
  )
  .command(
    'validate [path]',
    'Validate agent structure against schema',
    (yargs) =>
      yargs
        .positional('path', {
          describe: 'Agent file or directory to validate',
          type: 'string',
          default: '.'
        })
        .option('strict', {
          describe: 'Fail on warnings',
          type: 'boolean',
          alias: 's'
        }),
    (argv) => validateCommand(argv as any)
  )
  .command(
    'compile <input> [output]',
    'Compile agent from source to lock file',
    (yargs) =>
      yargs
        .positional('input', {
          describe: 'Input agent file (.agent.md)',
          type: 'string'
        })
        .positional('output', {
          describe: 'Output lock file (.lock.yml)',
          type: 'string'
        })
        .option('validate', {
          describe: 'Validate before compiling',
          type: 'boolean',
          default: true
        })
        .option('strict', {
          describe: 'Fail on warnings',
          type: 'boolean'
        }),
    (argv) => compileCommand(argv as any)
  )
  .command(
    'test [directory]',
    'Run test harness for agents',
    (yargs) =>
      yargs.positional('directory', {
        describe: 'Test directory',
        type: 'string',
        default: './__tests__'
      }),
    (argv) => testCommand(argv as any)
  )
  .option('verbose', {
    describe: 'Verbose output',
    type: 'boolean',
    alias: 'v',
    global: true
  })
  .option('quiet', {
    describe: 'Quiet output',
    type: 'boolean',
    alias: 'q',
    global: true
  })
  .help()
  .alias('help', 'h')
  .version('0.1.0')
  .alias('version', 'v')
  .demandCommand()
  .strict()
  .fail((msg, err) => {
    if (msg) {
      console.error(chalk.red('Error:'), msg);
    } else if (err) {
      console.error(chalk.red('Error:'), err.message);
    }
    process.exit(1);
  })
  .parse();
