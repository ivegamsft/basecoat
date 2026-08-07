// Example parameter file for infra/mcp/main.bicep
// Copy this file, fill in YOUR_ORG, and pass it to az deployment group create:
//
//   az deployment group create \
//     -g <rg> -f infra/mcp/main.bicep -p infra/mcp/main.bicepparam

using './main.bicep'

// ⚠️  Replace YOUR_ORG with your GitHub organization name before deploying.
param imageRepo = 'YOUR_ORG/basecoat-metrics-mcp'
param metricsBaseUrl = 'https://YOUR_ORG.github.io/basecoat/metrics'

// Optional overrides — defaults are fine for most deployments.
// param imageTag      = 'latest'
// param environment   = 'prod'
// param cpuCores      = '0.25'
// param memoryGi      = '0.5'
// param maxReplicas   = 3
// ⚠️  minReplicas defaults to 1. Setting it to 0 enables scale-to-zero but risks
//     Azure archiving the environment after extended idle periods, requiring full
//     environment recreation. Only use 0 for disposable dev environments.
// param minReplicas   = 1
