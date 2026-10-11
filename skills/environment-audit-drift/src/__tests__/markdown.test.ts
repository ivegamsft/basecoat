import { describe, it, expect } from 'vitest';
import fs from 'fs';
import path from 'path';
import { escapeMarkdown, toCriticalCommentMarkdown, toMarkdown } from '../markdown';
import { DriftReport } from '../types';

function report(finding: string, environment = 'prod'): DriftReport {
  return {
    total_drifts: 1,
    severity_summary: { critical: 1, high: 0, medium: 0, low: 0 },
    findings: [
      { id: 'f1', environment, category: 'config_drift', severity: 'critical', finding, remediation: 'fix' },
    ],
  } as unknown as DriftReport;
}

describe('escapeMarkdown', () => {
  it('escapes backslashes before pipes so a pipe cannot close the cell', () => {
    expect(escapeMarkdown('a\\|b')).toBe('a\\\\\\|b');
  });

  it('collapses CR/LF so a value cannot start a new row', () => {
    expect(escapeMarkdown('a\r\nb\nc\rd')).toBe('a b c d');
  });

  it('neutralizes links, images, and autolinks', () => {
    const out = escapeMarkdown('[x](https://evil.example) ![i](u) https://evil.example');
    expect(out).not.toMatch(/(^|[^\\])[[\]()]/);
    expect(out).not.toContain('https:');
  });

  it('encodes HTML-like input', () => {
    const out = escapeMarkdown('<img src=x onerror=alert(1)> & <b>');
    expect(out).not.toContain('<');
    expect(out).not.toContain('>');
    expect(out).toContain('&lt;img');
    expect(out).toContain('&amp;');
  });
});

describe('toMarkdown', () => {
  it('keeps hostile findings on a single valid table row', () => {
    const md = toMarkdown(report('x\\|y\n| injected | row |\n# Heading <script>[a](b)</script>', 'e|\nv'));
    const tableLines = md.split('\n').filter(l => l.startsWith('|'));
    expect(tableLines).toHaveLength(3);
    for (const line of tableLines.slice(2)) {
      const cells = line.split(/(?<!\\)\|/).slice(1, -1);
      expect(cells).toHaveLength(5);
    }
    expect(md).not.toContain('<script>');
    expect(md).not.toMatch(/\n# Heading/);
  });
});

describe('published workflow template', () => {
  const template = fs.readFileSync(
    path.join(__dirname, '..', '..', 'templates', 'audit-environment-drift.yml'),
    'utf-8'
  );

  it('routes summary and issue comment through CLI-rendered Markdown', () => {
    expect(template).toContain('--markdown-output drift-report.md');
    expect(template).toContain('--critical-comment-output drift-critical-comment.md');
    expect(template).toContain('cat drift-report.md');
    expect(template).toContain("readFileSync('drift-critical-comment.md'");
  });

  it('never interpolates raw finding fields into Markdown sinks', () => {
    expect(template).not.toMatch(/\\\(\.(finding|resource|remediation)/);
    expect(template).not.toMatch(/\$\{f\.(finding|remediation|environment)\}/);
  });

  it('only writes the status line and rendered file to the step summary', () => {
    const lines = template.split('\n').filter(l => l.includes('GITHUB_STEP_SUMMARY'));
    expect(lines.every(l => !/jq/.test(l))).toBe(true);
  });
});

describe('toCriticalCommentMarkdown', () => {
  it('escapes injected newlines, links, and HTML in critical findings', () => {
    const r = report('x\n# Fake [a](https://evil.example) <img src=x>');
    r.findings[0].remediation = 'do\n<script>';
    const md = toCriticalCommentMarkdown(r);
    expect(md).not.toContain('<img');
    expect(md).not.toContain('<script>');
    expect(md).not.toContain('](https');
    expect(md).not.toMatch(/\n# Fake/);
    expect(md.split('\n').filter(l => l.startsWith('- '))).toHaveLength(1);
  });
});