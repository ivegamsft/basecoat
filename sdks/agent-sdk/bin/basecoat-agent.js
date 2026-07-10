#!/usr/bin/env node
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const yargs_1 = __importDefault(require("yargs"));
const helpers_1 = require("yargs/helpers");
const chalk_1 = __importDefault(require("chalk"));
const init_1 = require("./commands/init");
const validate_1 = require("./commands/validate");
const compile_1 = require("./commands/compile");
const test_1 = require("./commands/test");
const argv = (0, yargs_1.default)((0, helpers_1.hideBin)(process.argv))
    .command('init <name> [directory]', 'Scaffold a new agent', (yargs) => yargs
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
}), (argv) => (0, init_1.initCommand)(argv))
    .command('validate [path]', 'Validate agent structure against schema', (yargs) => yargs
    .positional('path', {
    describe: 'Agent file or directory to validate',
    type: 'string',
    default: '.'
})
    .option('strict', {
    describe: 'Fail on warnings',
    type: 'boolean',
    alias: 's'
}), (argv) => (0, validate_1.validateCommand)(argv))
    .command('compile <input> [output]', 'Compile agent from source to lock file', (yargs) => yargs
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
}), (argv) => (0, compile_1.compileCommand)(argv))
    .command('test [directory]', 'Run test harness for agents', (yargs) => yargs.positional('directory', {
    describe: 'Test directory',
    type: 'string',
    default: './__tests__'
}), (argv) => (0, test_1.testCommand)(argv))
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
    .strict();
argv.catch((err) => {
    console.error(chalk_1.default.red('Error:'), err.message);
    process.exit(1);
});
//# sourceMappingURL=basecoat-agent.js.map