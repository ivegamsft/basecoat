import * as fs from 'fs-extra';
import * as path from 'path';
import { CompileOptions, CompileResult } from './types';
import { validateAgentFile } from './validate';

export async function compileAgent(options: CompileOptions): Promise<CompileResult> {
  try {
    const inputPath = path.resolve(options.input);
    const outputPath = options.output
      ? path.resolve(options.output)
      : inputPath.replace(/\.agent\.md$/, '.lock.yml');

    // Verify input file exists
    if (!(await fs.pathExists(inputPath))) {
      return {
        success: false,
        lockFile: outputPath,
        sourceFile: inputPath,
        errors: [`Input file not found: ${inputPath}`]
      };
    }

    // Validate agent if requested
    if (options.validate !== false) {
      const validation = await validateAgentFile(inputPath);
      if (!validation.valid) {
        const errors = validation.errors.map(e => `[${e.code}] ${e.message}`);
        return {
          success: false,
          lockFile: outputPath,
          sourceFile: inputPath,
          errors: errors
        };
      }
    }

    // For Phase 1, create a placeholder lock file
    // In Phase 2, this will integrate with `gh aw compile`
    const agentContent = await fs.readFile(inputPath, 'utf-8');
    const lockContent = generateLockFile(agentContent, inputPath);

    // Write lock file
    await fs.writeFile(outputPath, lockContent, 'utf-8');

    return {
      success: true,
      lockFile: outputPath,
      sourceFile: inputPath,
      warnings: options.strict ? [] : undefined
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      lockFile: options.output || '',
      sourceFile: options.input,
      errors: [`Compilation failed: ${message}`]
    };
  }
}

function generateLockFile(_content: string, sourceFile: string): string {
  const sourceFileName = path.basename(sourceFile);
  const timestamp = new Date().toISOString();

  return `# This is a compiled agent lock file
# Generated from: ${sourceFileName}
# Generated at: ${timestamp}
# DO NOT EDIT - this file is auto-generated

# Agent compilation placeholder for Phase 1
# In Phase 2, this will be compiled to full GitHub Actions workflow YAML

# Source agent marker
source_file: ${sourceFileName}
compiled: true
version: 0.1.0

# Note: Full gh-aw compilation support will be added in Phase 2
# For now, this lock file serves as a validation checkpoint
`;
}

export async function compileAgentDirectory(
  dirPath: string,
  options: Partial<CompileOptions> = {}
): Promise<CompileResult[]> {
  try {
    const fullPath = path.resolve(dirPath);
    const files = await fs.readdir(fullPath);
    const agentFiles = files.filter((f: string) => f.endsWith('.agent.md'));

    const results: CompileResult[] = [];
    for (const file of agentFiles) {
      const inputPath = path.join(fullPath, file);
      const result = await compileAgent({
        ...options,
        input: inputPath
      });
      results.push(result);
    }

    return results;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return [
      {
        success: false,
        lockFile: '',
        sourceFile: dirPath,
        errors: [`Failed to compile directory: ${message}`]
      }
    ];
  }
}
