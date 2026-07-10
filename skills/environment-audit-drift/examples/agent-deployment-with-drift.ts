/**
 * Example: Using audit-drift in an agent before resolving operation context
 *
 * This shows a reference pattern for agents to check drift status before
 * executing operations that depend on environment-map.yml being correct.
 */

import { resolveOperationContext } from '@basecoat/operation-context-resolver';
import { auditEnvironmentDrift, driftIsCritical } from '@basecoat/environment-audit-drift';
import * as fs from 'fs';

export async function executeDeploymentWithDriftCheck() {
  const repoRoot = process.cwd();

  // 1. Audit drift first
  console.log('Checking environment configuration drift...');

  const driftReport = await auditEnvironmentDrift({
    config_path: '.github/environment-map.yml',
    azure_subscription_id: process.env.AZURE_SUBSCRIPTION_ID!,
    github_token: process.env.GITHUB_TOKEN!,
    release_manifest_path: '.release/manifest.json',
    app_config_key_check: true,
    repo_root: repoRoot,
  });

  // Save report for audit trail
  fs.writeFileSync('drift-report.json', JSON.stringify(driftReport, null, 2));

  // 2. Check severity
  if (driftIsCritical(driftReport)) {
    console.error('Critical environment drift detected. Cannot proceed.');
    console.error('Findings:');

    for (const finding of driftReport.findings.filter(f => f.severity === 'critical')) {
      console.error(`  - [${finding.environment}] ${finding.finding}`);
      console.error(`    ${finding.remediation}`);
    }

    process.exit(1);
  }

  // 3. Warn on high severity (but proceed)
  if (driftReport.severity_summary.high > 0) {
    console.warn(
      `${driftReport.severity_summary.high} high-severity drift findings. Proceeding with caution.`
    );

    for (const finding of driftReport.findings.filter(f => f.severity === 'high')) {
      console.warn(`  - [${finding.environment}] ${finding.finding}`);
    }
  }

  // 4. Now resolve operation context (drift is clean or manageable)
  console.log('\nResolving operation context...');

  const operationContext = await resolveOperationContext({
    github_ref: process.env.GITHUB_REF || 'refs/heads/main',
    pr_labels: process.env.PR_LABELS?.split(',').map(l => l.trim()) || [],
    user_intent: process.env.IS_INCIDENT === 'true' ? process.env.INCIDENT_DESC : 'deployment validation',
    repo_root: repoRoot,
  });

  const driftStatus = driftReport.severity_summary.critical === 0 ? 'clean' : 'critical';

  console.log('\nDeployment context resolved');
  console.log(`   Environment: ${operationContext.target_environment}`);
  console.log(`   Mode: ${operationContext.mode}`);
  console.log(`   Approvals Required: ${operationContext.human_approval_required ? 'Yes' : 'No'}`);
  console.log(`   Drift Status: ${driftStatus}`);

  return {
    context: operationContext,
    driftStatus,
    driftReport,
  };
}

// Usage in an agent
export async function deployApplicationWithValidation() {
  try {
    const { context, driftStatus } = await executeDeploymentWithDriftCheck();

    // Gate 1: Check environment
    if (!['staging', 'prod'].includes(context.target_environment)) {
      throw new Error(`Unsupported environment: ${context.target_environment}`);
    }

    // Gate 2: Check approvals
    if (context.human_approval_required) {
      console.log('Approval required but approver not set. Waiting for manual approval...');
      return;
    }

    // Gate 3: Check drift
    if (driftStatus === 'critical') {
      throw new Error('Cannot proceed: environment configuration has critical drift');
    }

    // Now safe to proceed with deployment
    console.log('\nAll checks passed. Proceeding with deployment...');

    // Your deployment logic here
    console.log(`Deploying to ${context.target_environment}...`);
  } catch (error) {
    console.error('Deployment blocked:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

// Usage: Run in CI/CD
// npx ts-node examples/agent-deployment-with-drift.ts
if (require.main === module) {
  deployApplicationWithValidation();
}
