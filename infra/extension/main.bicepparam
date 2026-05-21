// Example parameter file for infra/extension/main.bicep
// Copy this file, fill in YOUR_ORG, and pass it to az deployment group create:
//
//   az deployment group create \
//     -g <rg> -f infra/extension/main.bicep -p infra/extension/main.bicepparam

using './main.bicep'

// Replace YOUR_ORG with your GitHub organization name before deploying.
param imageRepo = 'YOUR_ORG/basecoat-extension'

// Optional overrides.
// param imageTag             = 'latest'
// param environment          = 'prod'
// param cpuCores             = '0.25'
// param memoryGi             = '0.5'
// param minReplicas          = 0
// param maxReplicas          = 3
// param rateLimitMaxRequests = 10
// param rateLimitWindowMs    = 60000

