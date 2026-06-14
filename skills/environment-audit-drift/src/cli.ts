import fs from 'fs';
import path from 'path';
import { auditEnvironmentDrift } from './drift';
import { DriftAuditInput, DriftReport } from './types';

interface CliOptions {
  config: string;
  subscription?: string;
  githubToken?: string;
  output: string;
  strict: boolean;
  skipDeploymentCheck: boolean;
  skipTagCheck: boolean;
  outputFormat: 'json' | 'markdown' | 'junit';
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    config: '.github/environment-map.yml',
    output: 'drift-report.json',
    strict: false,
    skipDeploymentCheck: false,
    skipTagCheck: false,
    outputFormat: 'json',
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    switch (arg) {
      case '--config':
        if (!next) throw new Error('Missing value for --config');
        options.config = next;
        i += 1;
        break;
      case '--subscription':
        if (!next) throw new Error('Missing value for --subscription');
        options.subscription = next;
        i += 1;
        break;
      case '--github-token':
        if (!next) throw new Error('Missing value for --github-token');
        options.githubToken = next;
        i += 1;
        break;
      case '--output':
        if (!next) throw new Error('Missing value for --output');
        options.output = next;
        i += 1;
        break;
      case '--strict':
        options.strict = true;
        break;
      case '--skip-deployment-check':
        options.skipDeploymentCheck = true;
        break;
      case '--skip-tag-check':
        options.skipTagCheck = true;
        break;
      case '--output-format':
        if (!next) throw new Error('Missing value for --output-format');
        if (!['json', 'markdown', 'junit'].includes(next)) {
          throw new Error("Invalid --output-format. Expected: json, markdown, junit");
        }
        options.outputFormat = next as CliOptions['outputFormat'];
        i += 1;
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function toMarkdown(report: DriftReport): string {
  const rows = report.findings.map(finding =>
    `| ${finding.severity} | ${finding.category} | ${finding.environment} | ${finding.finding.replace(/\|/g, '\\|')} |`
  );

  return [
    '# Environment Drift Report',
    '',
    `- Total drifts: ${report.total_drifts}`,
    `- Critical: ${report.severity_summary.critical}`,
    `- High: ${report.severity_summary.high}`,
    `- Medium: ${report.severity_summary.medium}`,
    `- Low: ${report.severity_summary.low}`,
    '',
    '| Severity | Category | Environment | Finding |',
    '|---|---|---|---|',
    ...rows,
    '',
  ].join('\n');
}

function toJunit(report: DriftReport): string {
  const testCases = report.findings.map(
    finding =>
      `    <testcase classname="${finding.category}" name="${finding.id}"><failure message="${finding.finding.replace(/"/g, '&quot;')}">${finding.remediation.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</failure></testcase>`
  );

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    `<testsuite name="environment-audit-drift" tests="${report.findings.length}" failures="${report.findings.length}">`,
    ...testCases,
    '</testsuite>',
    '',
  ].join('\n');
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const input: DriftAuditInput = {
    config_path: options.config,
    azure_subscription_id: options.subscription || process.env.AZURE_SUBSCRIPTION_ID || '',
    github_token: options.githubToken || process.env.GITHUB_TOKEN || '',
    release_manifest_path: options.skipDeploymentCheck ? undefined : '.release/manifest.json',
    app_config_key_check: !options.skipTagCheck,
    strict_mode: options.strict,
    repo_root: process.cwd(),
  };

  const report = await auditEnvironmentDrift(input);

  const outputDir = path.dirname(options.output);
  if (outputDir && outputDir !== '.') {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  if (options.outputFormat === 'markdown') {
    fs.writeFileSync(options.output, toMarkdown(report), 'utf-8');
  } else if (options.outputFormat === 'junit') {
    fs.writeFileSync(options.output, toJunit(report), 'utf-8');
  } else {
    fs.writeFileSync(options.output, JSON.stringify(report, null, 2), 'utf-8');
  }

  console.log(`Drift report written to ${options.output}`);
  if (options.strict && report.total_drifts > 0) {
    process.exit(1);
  }
}

void main().catch(error => {
  console.error(`[ERROR] ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
