import * as fs from 'fs-extra';
import Ajv from 'ajv';
import { ValidationResult, ValidationError, ValidationWarning } from './types';

const SCHEMA = {
  type: 'object',
  properties: {
    name: { type: 'string', minLength: 1, pattern: '^[a-z0-9-]+$' },
    description: { type: 'string', minLength: 1 },
    author: { type: 'string' },
    version: { type: 'string' },
    triggers: { type: 'array', items: { type: 'string' } },
    instructions: { type: 'array', items: { type: 'string' } },
    skills: { type: 'array', items: { type: 'string' } },
    mcp: { type: 'array', items: { type: 'string' } }
  },
  required: ['name', 'description'],
  additionalProperties: false
};

function parseFrontmatter(content: string): { frontmatter: string; body: string } {
  const lines = content.split('\n');
  if (!lines[0]?.startsWith('---')) {
    throw new Error('No YAML frontmatter found');
  }

  let endIndex = -1;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i]?.startsWith('---')) {
      endIndex = i;
      break;
    }
  }

  if (endIndex === -1) {
    throw new Error('Malformed frontmatter: missing closing ---');
  }

  const frontmatter = lines.slice(1, endIndex).join('\n');
  const body = lines.slice(endIndex + 1).join('\n');

  return { frontmatter, body };
}

function parseFrontmatterYAML(yaml: string): Record<string, unknown> {
  const obj: Record<string, unknown> = {};
  const lines = yaml.split('\n');

  let pendingKey: string | null = null;
  let pendingMode: 'scalar' | 'array' | null = null;
  let scalarParts: string[] = [];
  let arrayItems: string[] = [];

  const flushPending = (): void => {
    if (!pendingKey) {
      return;
    }

    if (pendingMode === 'array') {
      obj[pendingKey] = arrayItems;
    } else if (pendingMode === 'scalar') {
      obj[pendingKey] = scalarParts.join(' ').trim();
    }

    pendingKey = null;
    pendingMode = null;
    scalarParts = [];
    arrayItems = [];
  };

  const parsePrimitive = (value: string): unknown => {
    if (value === 'true') {
      return true;
    }

    if (value === 'false') {
      return false;
    }

    if (!isNaN(Number(value))) {
      return Number(value);
    }

    return value;
  };

  for (const line of lines) {
    if (!line.trim() || line.trimStart().startsWith('#')) {
      continue;
    }

    const topLevelMatch = line.match(/^(\w+):\s*(.*?)(?:\s*#.*)?$/);
    if (topLevelMatch && !line.startsWith(' ')) {
      flushPending();

      const [, key, rawValue] = topLevelMatch;
      const value = rawValue.trim();

      if (!value) {
        pendingKey = key;
        pendingMode = null;
        continue;
      }

      if (value === '>' || value === '|') {
        pendingKey = key;
        pendingMode = 'scalar';
        continue;
      }

      if (value.startsWith('[') && value.endsWith(']')) {
        obj[key] = value
          .slice(1, -1)
          .split(',')
          .map(v => v.trim());
        continue;
      }

      obj[key] = parsePrimitive(value);
      continue;
    }

    if (!pendingKey) {
      continue;
    }

    const listMatch = line.match(/^\s*-\s+(.*)$/);
    if (listMatch) {
      if (pendingMode === null) {
        pendingMode = 'array';
      }

      if (pendingMode === 'array') {
        arrayItems.push(listMatch[1].trim());
      }

      continue;
    }

    if (pendingMode === null || pendingMode === 'scalar') {
      pendingMode = 'scalar';
      scalarParts.push(line.trim());
    }
  }

  flushPending();

  return obj;
}

export async function validateAgent(content: string): Promise<ValidationResult> {
  const errors: ValidationError[] = [];
  const warnings: ValidationWarning[] = [];

  try {
    // Parse frontmatter
    const { frontmatter } = parseFrontmatter(content);
    const data = parseFrontmatterYAML(frontmatter);

    // Validate against schema
    const ajv = new Ajv();
    const validate = ajv.compile(SCHEMA);
    const valid = validate(data);

    if (!valid) {
      validate.errors?.forEach(err => {
        errors.push({
          code: 'SCHEMA_VALIDATION_ERROR',
          message: `${err.schemaPath}: ${err.message}`,
          field: String(err.instancePath || ''),
          line: 1
        });
      });
    }

    // Additional validation checks
    if (!data.name || typeof data.name !== 'string') {
      errors.push({
        code: 'MISSING_NAME',
        message: 'Agent must have a name field',
        field: 'name'
      });
    }

    if (data.name && !/^[a-z0-9-]+$/.test(String(data.name))) {
      errors.push({
        code: 'INVALID_NAME_FORMAT',
        message: 'Agent name must contain only lowercase letters, numbers, and hyphens',
        field: 'name'
      });
    }

    if (!data.description || typeof data.description !== 'string') {
      errors.push({
        code: 'MISSING_DESCRIPTION',
        message: 'Agent must have a description field',
        field: 'description'
      });
    }

    if (data.description && (String(data.description).length < 10)) {
      warnings.push({
        code: 'SHORT_DESCRIPTION',
        message: 'Description should be at least 10 characters',
        field: 'description'
      });
    }

    // Check for content after frontmatter
    const { body } = parseFrontmatter(content);
    if (!body.trim()) {
      warnings.push({
        code: 'EMPTY_BODY',
        message: 'Agent body is empty. Please add implementation instructions.',
        field: 'body'
      });
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    errors.push({
      code: 'PARSE_ERROR',
      message: `Failed to parse agent: ${message}`,
      field: 'root'
    });

    return {
      valid: false,
      errors,
      warnings
    };
  }
}

export async function validateAgentFile(filePath: string): Promise<ValidationResult> {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    return validateAgent(content);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      valid: false,
      errors: [
        {
          code: 'FILE_READ_ERROR',
          message: `Failed to read file: ${message}`,
          field: 'file'
        }
      ],
      warnings: []
    };
  }
}
