"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.testCommand = testCommand;
const chalk_1 = __importDefault(require("chalk"));
const test_harness_1 = require("../../src/test-harness");
async function testCommand(argv) {
    const { directory, quiet, verbose } = argv;
    if (!quiet) {
        console.log(chalk_1.default.cyan(`Running tests in: ${directory}`));
    }
    try {
        const result = await (0, test_harness_1.runTestHarness)(directory);
        if (!quiet || result.failed > 0) {
            console.log(chalk_1.default.gray(`\nTest Results:`));
            console.log(`  ${chalk_1.default.green(`${result.passed} passed`)}, ${chalk_1.default.red(`${result.failed} failed`)}, ${chalk_1.default.gray(`${result.skipped} skipped`)}`);
            console.log(chalk_1.default.gray(`  Duration: ${result.duration}ms`));
        }
        if (verbose) {
            console.log(chalk_1.default.gray(`\nDetailed Results:`));
            for (const testResult of result.results) {
                const icon = testResult.passed ? chalk_1.default.green('✓') : chalk_1.default.red('✗');
                console.log(`  ${icon} ${testResult.name}`);
                if (testResult.error && verbose) {
                    console.log(chalk_1.default.red(`    Error: ${testResult.error}`));
                }
                if (verbose) {
                    console.log(chalk_1.default.gray(`    Duration: ${testResult.duration}ms`));
                }
            }
        }
        if (result.failed > 0) {
            process.exit(1);
        }
        if (!quiet) {
            console.log(chalk_1.default.green('\n✓ All tests passed'));
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(chalk_1.default.red('✗'), `Test execution failed: ${message}`);
        process.exit(1);
    }
}
//# sourceMappingURL=test.js.map