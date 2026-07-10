export interface AgentFrontmatter {
  name: string;
  description: string;
  author?: string;
  version?: string;
  triggers?: string[];
  instructions?: string[];
  skills?: string[];
  mcp?: string[];
}

export interface AgentSchema {
  name: string;
  description: string;
  author: string;
  version: string;
  triggers: string[];
  instructions: string[];
  skills: string[];
  mcp: string[];
  validated: boolean;
  validationErrors?: string[];
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationWarning[];
}

export interface ValidationError {
  code: string;
  message: string;
  field: string;
  line?: number;
}

export interface ValidationWarning {
  code: string;
  message: string;
  field: string;
  line?: number;
}

export interface CompileOptions {
  input: string;
  output?: string;
  validate?: boolean;
  strict?: boolean;
}

export interface CompileResult {
  success: boolean;
  lockFile: string;
  sourceFile: string;
  errors?: string[];
  warnings?: string[];
}

export interface TestCase {
  name: string;
  description: string;
  inputs: Record<string, unknown>;
  expectedOutputs: Record<string, unknown>;
}

export interface TestResult {
  passed: number;
  failed: number;
  skipped: number;
  duration: number;
  results: TestCaseResult[];
}

export interface TestCaseResult {
  name: string;
  passed: boolean;
  error?: string;
  duration: number;
}
