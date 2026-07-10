"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initCommand = initCommand;
const chalk_1 = __importDefault(require("chalk"));
const init_1 = require("../../src/init");
async function initCommand(argv) {
    const { name, directory, description, author, quiet } = argv;
    if (!quiet) {
        console.log(chalk_1.default.cyan(`Creating agent: ${name}`));
    }
    const result = await (0, init_1.initializeAgent)(name, directory, { description, author });
    if (result.success) {
        console.log(chalk_1.default.green('✓'), result.message);
        if (!quiet && result.agentPath) {
            console.log(chalk_1.default.gray(`  Location: ${result.agentPath}`));
        }
    }
    else {
        console.error(chalk_1.default.red('✗'), result.message);
        process.exit(1);
    }
}
//# sourceMappingURL=init.js.map