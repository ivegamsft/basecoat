#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const METRIC_KEYS = ['statements', 'branches', 'functions', 'lines'];

function getRepoRoot() {
  try {
    return execFileSync('git', ['rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  } catch {
    return process.cwd();
  }
}

const REPO_ROOT = getRepoRoot();
const DEFAULT_POLICY_FILE =
  process.env.COVERAGE_RATCHET_POLICY_FILE || 'coverage-threshold-ratchet-policy.json';

function parseBooleanFlag(value) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value !== 'string') {
    return false;
  }

  const normalized = value.trim().toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes' || normalized === 'on';
}

function parseArgs(argv) {
  const parsed = {
    policyFile: process.env.COVERAGE_RATCHET_POLICY_FILE || DEFAULT_POLICY_FILE,
    overrideApproved: parseBooleanFlag(process.env.COVERAGE_RATCHET_OVERRIDE_APPROVED),
    baseRef: process.env.COVERAGE_RATCHET_BASE_REF || '',
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--policy-file') {
      parsed.policyFile = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === '--override-approved') {
      parsed.overrideApproved = parseBooleanFlag(argv[index + 1]);
      index += 1;
      continue;
    }
    if (arg === '--base-ref') {
      parsed.baseRef = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === '-h' || arg === '--help') {
      parsed.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return parsed;
}

function getTargetKey(target, contextLabel) {
  const key = target && (target.name || target.thresholdsFile);
  if (typeof key !== 'string' || key.trim().length === 0) {
    throw new Error(`${contextLabel} must include a non-empty name or thresholdsFile`);
  }
  return key.trim();
}

function buildBaselineMap(policy, contextLabel) {
  if (!Array.isArray(policy.targets) || policy.targets.length === 0) {
    throw new Error(`${contextLabel}.targets must contain at least one target`);
  }

  const baselineMap = new Map();

  for (let index = 0; index < policy.targets.length; index += 1) {
    const target = policy.targets[index];
    const targetLabel = `${contextLabel}.targets[${index}]`;
    const key = getTargetKey(target, targetLabel);

    if (baselineMap.has(key)) {
      throw new Error(`${contextLabel}.targets contains duplicate target key '${key}'`);
    }

    if (typeof target.thresholdsFile !== 'string' || target.thresholdsFile.trim().length === 0) {
      throw new Error(`${targetLabel}.thresholdsFile must be a non-empty string`);
    }

    const baselineMetrics = target.baseline && target.baseline.metrics;
    ensureMetricMap(baselineMetrics, `${key}.baseline.metrics`);

    baselineMap.set(key, {
      thresholdsFile: target.thresholdsFile,
      metrics: baselineMetrics,
    });
  }

  return baselineMap;
}

function detectBaselineDrift({ policy, baselinePolicy }) {
  const currentBaselineMap = buildBaselineMap(policy, 'policy');
  const baseBranchBaselineMap = buildBaselineMap(baselinePolicy, 'baselinePolicy');
  const driftMessages = [];

  for (const [key, baseTarget] of baseBranchBaselineMap.entries()) {
    const currentTarget = currentBaselineMap.get(key);
    if (!currentTarget) {
      driftMessages.push(`Target '${key}' is missing from the proposed policy`);
      continue;
    }

    if (currentTarget.thresholdsFile !== baseTarget.thresholdsFile) {
      driftMessages.push(
        `Target '${key}' thresholdsFile changed from '${baseTarget.thresholdsFile}' to '${currentTarget.thresholdsFile}'`
      );
    }

    for (const metricKey of METRIC_KEYS) {
      if (currentTarget.metrics[metricKey] !== baseTarget.metrics[metricKey]) {
        driftMessages.push(
          `Target '${key}' baseline ${metricKey} changed from ${baseTarget.metrics[metricKey]} to ${currentTarget.metrics[metricKey]}`
        );
      }
    }
  }

  for (const key of currentBaselineMap.keys()) {
    if (!baseBranchBaselineMap.has(key)) {
      driftMessages.push(`Target '${key}' was added to the proposed policy baseline`);
    }
  }

  return driftMessages;
}

function toRepoRelativePath(absolutePath) {
  const repoRelativePath = path.relative(REPO_ROOT, absolutePath);
  if (repoRelativePath.startsWith('..') || path.isAbsolute(repoRelativePath)) {
    throw new Error(`Path '${absolutePath}' is outside repository root`);
  }
  return repoRelativePath.split(path.sep).join('/');
}

function loadJsonFromGitRef({ absolutePath, gitRef }) {
  const repoRelativePath = toRepoRelativePath(absolutePath);
  const objectSpec = `${gitRef}:${repoRelativePath}`;

  let rawJson;
  try {
    rawJson = execFileSync('git', ['show', objectSpec], {
      cwd: REPO_ROOT,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    const stderr = typeof error.stderr === 'string' ? error.stderr.trim() : '';
    const details = stderr || error.message;
    throw new Error(`Unable to read '${repoRelativePath}' at '${gitRef}': ${details}`);
  }

  try {
    return JSON.parse(rawJson);
  } catch (error) {
    throw new Error(`Invalid JSON for '${repoRelativePath}' at '${gitRef}': ${error.message}`);
  }
}

function ensureMetricMap(metricMap, contextLabel) {
  if (!metricMap || typeof metricMap !== 'object' || Array.isArray(metricMap)) {
    throw new Error(`${contextLabel} must be an object`);
  }

  for (const metricKey of METRIC_KEYS) {
    const value = metricMap[metricKey];
    if (typeof value !== 'number' || Number.isNaN(value)) {
      throw new Error(`${contextLabel}.${metricKey} must be a number`);
    }
    if (value < 0 || value > 100) {
      throw new Error(`${contextLabel}.${metricKey} must be between 0 and 100`);
    }
  }
}

function evaluateRatchetPolicy({ policy, baselinePolicy = policy, overrideApproved, thresholdLoader }) {
  const violations = [];
  const warnings = [];
  const targetSummaries = [];
  const baselineMap = buildBaselineMap(baselinePolicy, 'baselinePolicy');

  const maxIncreasePerRatchet = policy.maxIncreasePerRatchet;
  if (typeof maxIncreasePerRatchet !== 'number' || maxIncreasePerRatchet < 0) {
    throw new Error('policy.maxIncreasePerRatchet must be a non-negative number');
  }

  if (!Array.isArray(policy.targets) || policy.targets.length === 0) {
    throw new Error('policy.targets must contain at least one target');
  }

  for (const target of policy.targets) {
    const targetName = getTargetKey(target, 'policy target');
    const baselineTarget = baselineMap.get(targetName);
    const baselineMetrics = baselineTarget
      ? baselineTarget.metrics
      : target.baseline && target.baseline.metrics;
    ensureMetricMap(baselineMetrics, `${targetName}.baseline.metrics`);

    const proposedThresholds = thresholdLoader(target);
    ensureMetricMap(proposedThresholds, `${targetName}.thresholds`);

    const metricSummaries = [];
    const requiresOverrideMetrics = [];

    for (const metricKey of METRIC_KEYS) {
      const baselineValue = baselineMetrics[metricKey];
      const proposedValue = proposedThresholds[metricKey];
      const increase = Number((proposedValue - baselineValue).toFixed(2));

      metricSummaries.push({
        metric: metricKey,
        baseline: baselineValue,
        proposed: proposedValue,
        increase,
      });

      if (increase > maxIncreasePerRatchet) {
        requiresOverrideMetrics.push({
          metric: metricKey,
          baseline: baselineValue,
          proposed: proposedValue,
          increase,
        });
      }
    }

    if (requiresOverrideMetrics.length > 0) {
      const message = `${targetName} exceeds +${maxIncreasePerRatchet} points for: ${requiresOverrideMetrics
        .map((item) => `${item.metric} (+${item.increase})`)
        .join(', ')}`;

      if (!overrideApproved) {
        violations.push(message);
      } else {
        warnings.push(`${message}; override approved`);
      }
    }

    targetSummaries.push({
      targetName,
      metrics: metricSummaries,
      requiresOverride: requiresOverrideMetrics.length > 0,
    });
  }

  return {
    ok: violations.length === 0,
    violations,
    warnings,
    targetSummaries,
  };
}

function runPolicyCheck({ argv = process.argv.slice(2), logger = console } = {}) {
  try {
    const args = parseArgs(argv);
    if (args.help) {
      logger.log(
        'Usage: node check-coverage-threshold-ratchet.js [--policy-file <path>] [--base-ref <git-ref>] [--override-approved <true|false>]'
      );
      return 0;
    }

    const policyPath = path.resolve(REPO_ROOT, args.policyFile);
    const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
    const requiredLabel = policy.override && policy.override.label;
    let baselinePolicy = policy;
    let baselinePolicyLoadedFromBaseRef = false;

    if (args.baseRef) {
      try {
        baselinePolicy = loadJsonFromGitRef({ absolutePath: policyPath, gitRef: args.baseRef });
        baselinePolicyLoadedFromBaseRef = true;
      } catch (error) {
        const message = `Base branch policy could not be loaded from '${args.baseRef}': ${error.message}`;
        if (!args.overrideApproved) {
          throw new Error(
            `${message}. Apply '${requiredLabel}' label (or set COVERAGE_RATCHET_OVERRIDE_APPROVED=true) for explicit approval.`
          );
        }
        logger.warn(`::warning::${message}; override approved — using proposed branch policy baseline`);
      }
    }

    if (args.baseRef && baselinePolicyLoadedFromBaseRef) {
      logger.log(`Coverage ratchet baseline policy source: ${args.baseRef}`);
    }

    const results = evaluateRatchetPolicy({
      policy,
      baselinePolicy,
      overrideApproved: args.overrideApproved,
      thresholdLoader: (target) => {
        if (!target.thresholdsFile) {
          throw new Error(`Missing thresholdsFile for target '${target.name || 'unnamed'}'`);
        }
        const thresholdsPath = path.resolve(REPO_ROOT, target.thresholdsFile);
        return JSON.parse(fs.readFileSync(thresholdsPath, 'utf8'));
      },
    });

    const baselineDriftMessages =
      args.baseRef && baselinePolicyLoadedFromBaseRef
        ? detectBaselineDrift({
            policy,
            baselinePolicy,
          })
        : [];

    if (baselineDriftMessages.length > 0) {
      for (const message of baselineDriftMessages) {
        const formatted = `Baseline policy drift detected against '${args.baseRef}': ${message}`;
        if (args.overrideApproved) {
          results.warnings.push(`${formatted}; override approved`);
        } else {
          results.violations.push(formatted);
        }
      }
      results.ok = results.violations.length === 0;
    }

    logger.log(
      `Coverage threshold ratchet policy: cadence='${policy.ratchetCadence}', max increase per ratchet=${policy.maxIncreasePerRatchet}`
    );
    for (const summary of results.targetSummaries) {
      logger.log(`Target: ${summary.targetName}`);
      for (const metric of summary.metrics) {
        logger.log(
          `  - ${metric.metric}: baseline=${metric.baseline}, proposed=${metric.proposed}, delta=${metric.increase >= 0 ? '+' : ''}${metric.increase}`
        );
      }
    }

    for (const warning of results.warnings) {
      logger.warn(`::warning::${warning}`);
    }

    if (!results.ok) {
      for (const violation of results.violations) {
        logger.error(`::error::${violation}`);
      }
      logger.error(
        `::error::Coverage threshold ratchet check failed. Apply '${requiredLabel}' label (or set COVERAGE_RATCHET_OVERRIDE_APPROVED=true) for explicit approval.`
      );
      return 1;
    }

    logger.log('Coverage threshold ratchet check passed.');
    return 0;
  } catch (error) {
    logger.error(`::error::Coverage threshold ratchet check failed: ${error.message}`);
    return 1;
  }
}

if (require.main === module) {
  process.exit(runPolicyCheck());
}

module.exports = {
  buildBaselineMap,
  detectBaselineDrift,
  METRIC_KEYS,
  evaluateRatchetPolicy,
  loadJsonFromGitRef,
  parseArgs,
  parseBooleanFlag,
  runPolicyCheck,
};
