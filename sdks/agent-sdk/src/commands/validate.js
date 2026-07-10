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
exports.validateCommand = validateCommand;
const chalk_1 = __importDefault(require("chalk"));
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const validate_1 = require("../../src/validate");
async function validateCommand(argv) {
    const { path: inputPath, strict, quiet, verbose } = argv;
    if (!quiet) {
        console.log(chalk_1.default.cyan(`Validating: ${inputPath}`));
    }
    try {
        const fullPath = path.resolve(inputPath);
        const stat = await fs.lstat(fullPath);
        let results = [];
        if (stat.isDirectory()) {
            // Validate all .agent.md files in directory
            const files = await fs.readdir(fullPath);
            const agentFiles = files.filter(f => f.endsWith('.agent.md'));
            if (agentFiles.length === 0) {
                console.warn(chalk_1.default.yellow('⚠'), 'No .agent.md files found in directory');
                return;
            }
            for (const file of agentFiles) {
                const filePath = path.join(fullPath, file);
                const result = await (0, validate_1.validateAgentFile)(filePath);
                results.push({ file, result });
            }
        }
        else if (stat.isFile()) {
            // Validate single file
            const result = await (0, validate_1.validateAgentFile)(fullPath);
            results.push({ file: inputPath, result });
        }
        else {
            console.error(chalk_1.default.red('✗'), 'Path is neither file nor directory');
            process.exit(1);
        }
        // Display results
        let hasErrors = false;
        let hasWarnings = false;
        for (const { file, result } of results) {
            if (!quiet || result.errors.length > 0) {
                console.log(chalk_1.default.gray(`\n${file}`));
            }
            if (result.valid) {
                console.log(chalk_1.default.green('  ✓ Valid'));
            }
            else {
                console.log(chalk_1.default.red('  ✗ Invalid'));
                hasErrors = true;
            }
            // Display errors
            for (const error of result.errors) {
                console.error(chalk_1.default.red(`    [${error.code}] ${error.message}`), error.line ? `(line ${error.line})` : '');
            }
            // Display warnings
            if (verbose || strict) {
                for (const warning of result.warnings) {
                    if (strict) {
                        console.warn(chalk_1.default.red(`    [${warning.code}] ${warning.message}`));
                        hasWarnings = true;
                    }
                    else {
                        console.warn(chalk_1.default.yellow(`    [${warning.code}] ${warning.message}`));
                    }
                }
            }
        }
        if (hasErrors || (hasWarnings && strict)) {
            process.exit(1);
        }
        if (!quiet && !hasErrors) {
            console.log(chalk_1.default.green('\n✓ All agents valid'));
        }
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(chalk_1.default.red('✗'), `Validation failed: ${message}`);
        process.exit(1);
    }
}
//# sourceMappingURL=validate.js.map