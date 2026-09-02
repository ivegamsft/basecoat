const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const {
  detectBaselineDrift,
  evaluateRatchetPolicy,
  parseBooleanFlag,
} = require('../templates/coverage-threshold-ratchet/check-coverage-threshold-ratchet.js');

function buildPolicy(overrides = {}) {
  return {
    maxIncreasePerRatchet: 2,
    ratchetCadence: 'once per sprint',
    override: { label: 'coverage-ratchet-override' },
    targets: [
      {
        name: 'frontend-vitest',
        thresholdsFile: 'config/coverage-thresholds.json',
        baseline: {
          metrics: {
            statements: 50,
            branches: 40,
            functions: 45,
            lines: 50,
          },
        },
      },
    ],
    ...overrides,
  };
}

describe('check-coverage-threshold-ratchet', () => {
  test('passes when thresholds are within allowed per-ratchet delta', () => {
    const result = evaluateRatchetPolicy({
      policy: buildPolicy(),
      overrideApproved: false,
      thresholdLoader: () => ({
        statements: 52,
        branches: 40,
        functions: 46,
        lines: 51,
      }),
    });

    assert.equal(result.ok, true);
    assert.deepEqual(result.violations, []);
    assert.deepEqual(result.warnings, []);
  });

  test('fails when threshold increase exceeds policy and override is not approved', () => {
    const result = evaluateRatchetPolicy({
      policy: buildPolicy(),
      overrideApproved: false,
      thresholdLoader: () => ({
        statements: 55,
        branches: 44,
        functions: 48,
        lines: 53,
      }),
    });

    assert.equal(result.ok, false);
    assert.equal(result.violations.length, 1);
    assert.match(result.violations[0], /statements \(\+5\)/);
  });

  test('passes with warning when override is approved', () => {
    const result = evaluateRatchetPolicy({
      policy: buildPolicy(),
      overrideApproved: true,
      thresholdLoader: () => ({
        statements: 54,
        branches: 43,
        functions: 49,
        lines: 53,
      }),
    });

    assert.equal(result.ok, true);
    assert.deepEqual(result.violations, []);
    assert.equal(result.warnings.length, 1);
    assert.match(result.warnings[0], /override approved/);
  });

  test('evaluates deltas against base branch baseline to block bypass attempts', () => {
    const basePolicy = buildPolicy();
    const manipulatedPolicy = buildPolicy({
      targets: [
        {
          name: 'frontend-vitest',
          thresholdsFile: 'config/coverage-thresholds.json',
          baseline: {
            metrics: {
              statements: 70,
              branches: 70,
              functions: 70,
              lines: 70,
            },
          },
        },
      ],
    });

    const result = evaluateRatchetPolicy({
      policy: manipulatedPolicy,
      baselinePolicy: basePolicy,
      overrideApproved: false,
      thresholdLoader: () => ({
        statements: 70,
        branches: 70,
        functions: 70,
        lines: 70,
      }),
    });

    assert.equal(result.ok, false);
    assert.match(result.violations[0], /statements \(\+20\)/);
  });

  test('detects baseline drift against base branch policy', () => {
    const drift = detectBaselineDrift({
      policy: buildPolicy({
        targets: [
          {
            name: 'frontend-vitest',
            thresholdsFile: 'config/coverage-thresholds.json',
            baseline: {
              metrics: {
                statements: 52,
                branches: 40,
                functions: 45,
                lines: 50,
              },
            },
          },
        ],
      }),
      baselinePolicy: buildPolicy(),
    });

    assert.ok(
      drift.includes("Target 'frontend-vitest' baseline statements changed from 50 to 52")
    );
  });

  test('throws when threshold payload is invalid', () => {
    assert.throws(
      () =>
        evaluateRatchetPolicy({
          policy: buildPolicy(),
          overrideApproved: false,
          thresholdLoader: () => ({
            statements: 52,
            branches: 42,
            functions: 46,
          }),
        }),
      /frontend-vitest\.thresholds\.lines must be a number/
    );
  });

  test('parses boolean override flag values', () => {
    assert.equal(parseBooleanFlag('true'), true);
    assert.equal(parseBooleanFlag('1'), true);
    assert.equal(parseBooleanFlag('yes'), true);
    assert.equal(parseBooleanFlag('false'), false);
    assert.equal(parseBooleanFlag(undefined), false);
  });

  test('template files exist for sync', () => {
    const root = path.resolve(__dirname, '..');
    const required = [
      'templates/coverage-threshold-ratchet/check-coverage-threshold-ratchet.js',
      'templates/coverage-threshold-ratchet/coverage-threshold-ratchet-policy.example.json',
      'templates/coverage-threshold-ratchet/coverage-threshold-ratchet.yml',
      'templates/coverage-threshold-ratchet/README.md',
      'docs/guides/coverage-threshold-ratchet.md',
    ];
    for (const rel of required) {
      assert.equal(require('node:fs').existsSync(path.join(root, rel)), true, rel);
    }
  });
});
