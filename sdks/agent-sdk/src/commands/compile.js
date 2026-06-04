"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.compileCommand = compileCommand;
const chalk_1 = __importDefault(require("chalk"));
const path = __importStar(require("path"));
const compile_1 = require("../../src/compile");
const fs = __importStar(require("fs-extra"));
async function compileCommand(argv) {
    const { input, output, validate, strict, quiet, verbose } = argv;
    if (!quiet) {
        console.log(chalk_1.default.cyan(`Compiling: ${input}`));
    }
    try {
        const fullInputPath = path.resolve(input);
        const stat = await fs.lstat(fullInputPath);
        let results = [];
        if (stat.isDirectory()) {
            // Compile all .agent.md files in directory
            results = await (0, compile_1.compileAgentDirectory)(fullInputPath, { validate, strict });
        }
        else if (stat.isFile()) {
            // Compile single file
            const result = await (0, compile_1.compileAgent)({
                input: fullInputPath,
                output,
                validate,
                strict
            });
            results = [result];
        }
        else {
            console.error(chalk_1.default.red('✗'), 'Input is neither file nor directory');
            process.exit(1);
        }
        // Display results
        let hasErrors = false;
        for (const result of results) {
            const fileName = path.basename(result.sourceFile);
            if (result.success) {
                console.log(chalk_1.default.green('  ✓'), `Compiled: ${fileName}`);
                if (verbose) {
                    console.log(chalk_1.default.gray(`    Output: ${result.lockFile}`));
                }
            }
            else {
                console.error(chalk_1.default.red('  ✗'), `Failed: ${fileName}`);
                hasErrors = true;
                if (result.errors) {
                    for (const error of result.errors) {
                        console.error(chalk_1.default.red(`    ${error}`));
                    }
                }
            }
            if (verbose && result.warnings) {
                for (const warning of result.warnings) {
                    console.warn(chalk_1.default.yellow(`    ${warning}`));
                }
            }
        }
        if (hasErrors) {
            process.exit(1);
        }
        if (!quiet) {
            console.log(chalk_1.default.green(`\n✓ Compilation complete`));
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(chalk_1.default.red('✗'), `Compilation failed: ${message}`);
        process.exit(1);
    }
}
//# sourceMappingURL=compile.js.map