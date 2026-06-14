/**
 * Example: Using resolver in an agent (TypeScript)
 * 
 * This example shows how a troubleshooting agent would use the
 * operation context resolver to determine where to read logs and
 * what permissions it has.
 */

import { resolveOperationContext, OperationContext } from '../src/resolver';

async function troubleshootAgent(userRequest: string): Promise<void> {
  console.log(`User request: "${userRequest}"`);

  // Resolve operation context
  const context = await resolveOperationContext({
    github_event_payload: process.env.GITHUB_EVENT,
    github_ref: process.env.GITHUB_REF,
    user_intent: userRequest,
    pr_labels: process.env.PR_LABELS ? JSON.parse(process.env.PR_LABELS) : [],
  });

  console.log(`\nResolved context:`);
  console.log(`  Target environment: ${context.target_environment}`);
  console.log(`  Mode: ${context.mode}`);
  console.log(`  Risk level: ${context.risk_level}`);
  console.log(`  Human approval required: ${context.human_approval_required}`);
  console.log(`  Incident mode: ${context.incident_mode}`);

  // Step 1: Check if we're allowed to read logs
  if (!context.isActionAllowed('read_logs')) {
    throw new Error(
      `Cannot read logs: action 'read_logs' not allowed in ${context.mode} mode`
    );
  }

  console.log(`\n✓ Permission check passed: read_logs allowed`);

  // Step 2: Gather data from the correct environment
  console.log(`\nGathering diagnostic data from ${context.target_environment}...`);

  const diagnostics = {
    environment: context.target_environment,
    logs: await mockReadLogs(context.target_environment),
    deployments: await mockReadDeployments(context.target_environment),
    infra_status: await mockCheckInfrastructure(context.target_environment),
  };

  console.log(`  Logs retrieved: ${diagnostics.logs.length} entries`);
  console.log(`  Deployments: ${diagnostics.deployments.length} found`);
  console.log(`  Infrastructure: ${diagnostics.infra_status}`);

  // Step 3: Analyze and recommend action
  const recommendation = analyzeAndRecommend(diagnostics, context);

  console.log(`\nAnalysis:`);
  console.log(`  Likely cause: ${recommendation.cause}`);
  console.log(`  Recommendation: ${recommendation.action}`);

  // Step 4: If production incident, check before executing action
  if (context.incident_mode && recommendation.is_mutation) {
    console.log(`\n⚠️  Production incident detected`);
    console.log(`  Human approval required before: ${recommendation.action}`);
    console.log(`  Status: BLOCKED (waiting for human approval)`);
    return;
  }

  // Step 5: Execute recommended action if allowed
  if (context.isActionAllowed(recommendation.action)) {
    console.log(`\n✓ Executing recommended action: ${recommendation.action}`);
    await mockExecuteAction(recommendation.action, context.target_environment);
  } else {
    console.log(
      `\n✗ Cannot execute action: ${recommendation.action} is blocked`
    );
  }
}

// Mock helper functions
async function mockReadLogs(env: string): Promise<string[]> {
  return [
    `[${env}] INFO: Starting application`,
    `[${env}] DEBUG: Connecting to database`,
    `[${env}] ERROR: Connection timeout`,
  ];
}

async function mockReadDeployments(env: string): Promise<object[]> {
  return [
    { version: '1.2.3', deployed_at: '2 hours ago', status: 'healthy' },
    { version: '1.2.2', deployed_at: '1 day ago', status: 'rollback-available' },
  ];
}

async function mockCheckInfrastructure(env: string): Promise<string> {
  return 'Database: healthy, Cache: degraded, Load Balancer: healthy';
}

function analyzeAndRecommend(
  diagnostics: any,
  context: OperationContext
): { cause: string; action: string; is_mutation: boolean } {
  const { logs, infra_status } = diagnostics;

  if (logs.some(log => log.includes('Connection timeout'))) {
    return {
      cause: 'Database connection timeout detected in logs',
      action: 'migrate_db',
      is_mutation: true,
    };
  }

  if (infra_status.includes('Cache: degraded')) {
    return {
      cause: 'Cache layer is degraded',
      action: 'restart_cache',
      is_mutation: true,
    };
  }

  return {
    cause: 'No critical issues detected',
    action: 'none',
    is_mutation: false,
  };
}

async function mockExecuteAction(action: string, env: string): Promise<void> {
  console.log(`  Executing ${action} in ${env}...`);
  console.log(`  ✓ Action completed successfully`);
}

// Run example
(async () => {
  try {
    // Example 1: Feature branch troubleshooting
    console.log('=== EXAMPLE 1: Feature branch troubleshooting ===\n');
    process.env.GITHUB_REF = 'refs/heads/feature/login-timeout';
    process.env.GITHUB_EVENT = JSON.stringify({
      pull_request: { head: { ref: 'feature/login-timeout' } },
    });
    await troubleshootAgent('Troubleshoot login timeout issue');

    // Example 2: Production incident
    console.log('\n\n=== EXAMPLE 2: Production incident ===\n');
    process.env.GITHUB_REF = 'refs/heads/main';
    await troubleshootAgent('Site is down in production, customers cannot access');
  } catch (error) {
    console.error('Error:', error instanceof Error ? error.message : error);
  }
})();
