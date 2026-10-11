import { DriftReport } from './types';

/**
 * Encode an untrusted value so it renders as inert literal text inside a
 * Markdown table cell or list item: no links, HTML, emphasis, or row breaks.
 */
export function escapeMarkdown(value: unknown): string {
  return String(value ?? '')
    .replace(/\r\n|\r|\n|\u2028|\u2029/g, ' ')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/[\\`*_{}[\]()#+\-.!|~:@=]/g, '\\$&');
}

export function toMarkdown(report: DriftReport): string {
  const rows = report.findings.map(
    finding =>
      `| ${escapeMarkdown(finding.severity)} | ${escapeMarkdown(finding.category)} | ${escapeMarkdown(finding.environment)} | ${escapeMarkdown(finding.finding)} | ${escapeMarkdown(finding.resource ?? 'N/A')} |`
  );

  return [
    '# Environment Drift Report',
    '',
    `- Total drifts: ${escapeMarkdown(report.total_drifts)}`,
    `- Critical: ${escapeMarkdown(report.severity_summary.critical)}`,
    `- High: ${escapeMarkdown(report.severity_summary.high)}`,
    `- Medium: ${escapeMarkdown(report.severity_summary.medium)}`,
    `- Low: ${escapeMarkdown(report.severity_summary.low)}`,
    '',
    '| Severity | Category | Environment | Finding | Resource |',
    '|---|---|---|---|---|',
    ...rows,
    '',
  ].join('\n');
}

export function toCriticalCommentMarkdown(report: DriftReport): string {
  const items = report.findings
    .filter(finding => finding.severity === 'critical')
    .map(
      finding =>
        `- **${escapeMarkdown(finding.environment)}**: ${escapeMarkdown(finding.finding)}\n  Remediation: ${escapeMarkdown(finding.remediation)}`
    );

  return [
    '## Critical Environment Drift Detected',
    '',
    ...items,
    '',
    '**Action Required**: Review and resolve critical drifts before proceeding with deployments.',
    '',
    'See drift report artifact for full details.',
    '',
  ].join('\n');
}