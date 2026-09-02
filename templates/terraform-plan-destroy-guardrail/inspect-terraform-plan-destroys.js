#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

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
  process.env.TERRAFORM_DESTROY_POLICY_FILE || 'terraform-plan-destroy-guardrail-policy.json';
const DEFAULT_PLAN_JSON = process.env.TERRAFORM_PLAN_JSON || 'tfplan.json';

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
    policyFile: process.env.TERRAFORM_DESTROY_POLICY_FILE || DEFAULT_POLICY_FILE,
    planJson: process.env.TERRAFORM_PLAN_JSON || DEFAULT_PLAN_JSON,
    overrideApproved: parseBooleanFlag(process.env.TERRAFORM_DESTROY_ACK_APPROVED),
    baseRef: process.env.TERRAFORM_DESTROY_BASE_REF || '',
    commentFile: process.env.TERRAFORM_DESTROY_COMMENT_FILE || '',
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--policy-file') {
      parsed.policyFile = argv[index + 1];
      index += 1;
      continue;
    }
    if (arg === '--plan-json') {
      parsed.planJson = argv[index + 1];
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
    if (arg === '--comment-file') {
      parsed.commentFile = argv[index + 1];
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

function escapeRegex(value) {
  return value.replace(/[|\\{}()[\]^$+?.]/g, '\\$&');
}

function globToRegExp(glob) {
  if (typeof glob !== 'string' || glob.trim().length === 0) {
    throw new Error('protectedResourceTypeGlobs entries must be non-empty strings');
  }

  const source = glob
    .split('*')
    .map((part) => escapeRegex(part))
    .join('.*');
  return new RegExp(`^${source}$`);
}

function normalizeGlobs(policy, contextLabel) {
  const globs = policy && policy.protectedResourceTypeGlobs;
  if (!Array.isArray(globs) || globs.length === 0) {
    throw new Error(`${contextLabel}.protectedResourceTypeGlobs must contain at least one glob`);
  }

  return globs.map((glob, index) => {
    if (typeof glob !== 'string' || glob.trim().length === 0) {
      throw new Error(`${contextLabel}.protectedResourceTypeGlobs[${index}] must be a non-empty string`);
    }
    return glob.trim();
  });
}

function matchProtectedType(resourceType, globs) {
  return globs.some((glob) => globToRegExp(glob).test(resourceType));
}

function extractDestroys(plan) {
  const changes = plan && plan.resource_changes;
  if (!Array.isArray(changes)) {
    throw new Error('plan.resource_changes must be an array');
  }

  const destroys = [];
  for (const change of changes) {
    const actions = change && change.change && change.change.actions;
    if (!Array.isArray(actions) || !actions.includes('delete')) {
      continue;
    }

    const address = typeof change.address === 'string' ? change.address : '';
    const type = typeof change.type === 'string' ? change.type : '';
    if (!address || !type) {
      throw new Error('resource_changes entries with deletes must include address and type');
    }

    destroys.push({
      address,
      type,
      actions: actions.slice(),
      mode: actions.includes('create') ? 'replace' : 'delete',
    });
  }

  return destroys;
}

function detectProtectedListDrift({ policy, baselinePolicy }) {
  const current = new Set(normalizeGlobs(policy, 'policy'));
  const baseline = normalizeGlobs(baselinePolicy, 'baselinePolicy');
  const removed = baseline.filter((glob) => !current.has(glob));
  return removed.map(
    (glob) => `Protected resource glob '${glob}' was removed from the proposed policy`
  );
}

function evaluatePlanDestroys({ plan, policy, baselinePolicy, overrideApproved }) {
  const effectivePolicy = baselinePolicy || policy;
  const globs = normalizeGlobs(effectivePolicy, baselinePolicy ? 'baselinePolicy' : 'policy');
  const destroys = extractDestroys(plan);
  const protectedDestroys = destroys.filter((item) => matchProtectedType(item.type, globs));
  const warnings = [];
  const violations = [];

  if (protectedDestroys.length > 0 && !overrideApproved) {
    violations.push(
      `Protected Terraform destroys require acknowledgement: ${protectedDestroys
        .map((item) => item.address)
        .join(', ')}`
    );
  } else if (protectedDestroys.length > 0 && overrideApproved) {
    warnings.push(
      `Protected Terraform destroys present but override approved: ${protectedDestroys
        .map((item) => item.address)
        .join(', ')}`
    );
  }

  return {
    ok: violations.length === 0,
    destroys,
    protectedDestroys,
    warnings,
    violations,
  };
}

function renderComment({ destroys, protectedDestroys, overrideApproved }) {
  if (destroys.length === 0) {
    return '';
  }

  const lines = [
    '## Terraform plan destroys',
    '',
    '| Address | Type | Actions | Protected |',
    '|---|---|---|---|',
  ];

  for (const item of destroys) {
    const protectedFlag = protectedDestroys.some((entry) => entry.address === item.address)
      ? 'yes'
      : 'no';
    lines.push(
      `| \`${item.address}\` | \`${item.type}\` | ${item.actions.join(',')} | ${protectedFlag} |`
    );
  }

  lines.push('');
  if (protectedDestroys.length > 0) {
    lines.push(
      overrideApproved
        ? 'Protected destroys were acknowledged with the override label.'
        : 'Protected destroys require the acknowledgement label before apply.'
    );
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

function loadJsonFromGitRef({ absolutePath, gitRef }) {
  const relativePath = path.relative(REPO_ROOT, absolutePath).replace(/\\/g, '/');
  const stdout = execFileSync('git', ['show', `${gitRef}:${relativePath}`], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    cwd: REPO_ROOT,
  });
  return JSON.parse(stdout);
}

function printHelp(logger) {
  logger.log(`Inspect terraform show -json output for deletes and replaces.

Usage:
  node inspect-terraform-plan-destroys.js --plan-json tfplan.json --policy-file terraform-plan-destroy-guardrail-policy.json
`);
}

function runInspect(argv = process.argv.slice(2), logger = console) {
  try {
    const args = parseArgs(argv);
    if (args.help) {
      printHelp(logger);
      return 0;
    }

    const policyPath = path.resolve(REPO_ROOT, args.policyFile);
    if (!fs.existsSync(policyPath)) {
      throw new Error(
        `Policy file '${args.policyFile}' is missing. The guardrail fails closed until a base-branch policy exists.`
      );
    }

    const policy = JSON.parse(fs.readFileSync(policyPath, 'utf8'));
    const requiredLabel = (policy.override && policy.override.label) || 'terraform-destroy-ack';
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
            `${message}. Apply '${requiredLabel}' label (or set TERRAFORM_DESTROY_ACK_APPROVED=true) for explicit approval.`
          );
        }
        logger.warn(`::warning::${message}; override approved — using proposed branch policy`);
      }
    }

    const planPath = path.resolve(REPO_ROOT, args.planJson);
    if (!fs.existsSync(planPath)) {
      throw new Error(
        `Plan JSON '${args.planJson}' is missing. Produce it with 'terraform show -json tfplan > tfplan.json' before this check.`
      );
    }

    const plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
    const results = evaluatePlanDestroys({
      plan,
      policy,
      baselinePolicy,
      overrideApproved: args.overrideApproved,
    });

    if (args.baseRef && baselinePolicyLoadedFromBaseRef) {
      const driftMessages = detectProtectedListDrift({ policy, baselinePolicy });
      for (const message of driftMessages) {
        const formatted = `Protected-list drift detected against '${args.baseRef}': ${message}`;
        if (args.overrideApproved) {
          results.warnings.push(`${formatted}; override approved`);
        } else {
          results.violations.push(formatted);
        }
      }
      results.ok = results.violations.length === 0;
    }

    const comment = renderComment({
      destroys: results.destroys,
      protectedDestroys: results.protectedDestroys,
      overrideApproved: args.overrideApproved,
    });

    if (comment) {
      logger.log(comment.trimEnd());
      if (args.commentFile) {
        const commentPath = path.resolve(REPO_ROOT, args.commentFile);
        fs.writeFileSync(commentPath, comment, 'utf8');
      }
    } else {
      logger.log('No Terraform deletes or replaces in plan.');
    }

    for (const warning of results.warnings) {
      logger.warn(`::warning::${warning}`);
    }

    if (!results.ok) {
      for (const violation of results.violations) {
        logger.error(`::error::${violation}`);
      }
      logger.error(
        `::error::Terraform plan destroy guardrail failed. Apply '${requiredLabel}' label (or set TERRAFORM_DESTROY_ACK_APPROVED=true) for explicit approval.`
      );
      return 1;
    }

    logger.log('Terraform plan destroy guardrail passed.');
    return 0;
  } catch (error) {
    logger.error(`::error::Terraform plan destroy guardrail failed: ${error.message}`);
    return 1;
  }
}

if (require.main === module) {
  process.exit(runInspect());
}

module.exports = {
  detectProtectedListDrift,
  evaluatePlanDestroys,
  extractDestroys,
  globToRegExp,
  matchProtectedType,
  parseArgs,
  parseBooleanFlag,
  renderComment,
  runInspect,
};
