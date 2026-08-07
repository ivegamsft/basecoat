// ── BaseCoat Metrics MCP Server — Azure Container Apps ───────────────────────
//
// Provisions:
//   - Log Analytics Workspace (Container Apps telemetry)
//   - Container Apps Environment
//   - Container App (pulling from GHCR)
//
// Deploy:
//   az group create -n <rg> -l eastus
//   az deployment group create -g <rg> -f infra/mcp/main.bicep \
//     --parameters imageTag=latest \
//       imageRepo=YOUR_ORG/basecoat-metrics-mcp \
//       metricsBaseUrl=https://YOUR_ORG.github.io/basecoat/metrics

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short environment label appended to resource names.')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

@description('Container image tag to deploy (e.g. latest or a SHA digest).')
param imageTag string = 'latest'

@description('GHCR image repository (org/repo). Replace YOUR_ORG with your GitHub org before deploying.')
param imageRepo string = 'YOUR_ORG/basecoat-metrics-mcp'

@description('GitHub Pages metrics endpoint. Replace YOUR_ORG with your GitHub org before deploying.')
param metricsBaseUrl string = 'https://YOUR_ORG.github.io/basecoat/metrics'

@description('GHCR username for authenticated pulls (github actor or org name).')
param registryUsername string = ''

@secure()
@description('GHCR token/PAT for authenticated pulls. If empty, anonymous pull is used (package must be public).')
param registryPassword string = ''

@description('Container CPU cores.')
param cpuCores string = '0.25'

@description('Container memory in Gi.')
param memoryGi string = '0.5'

@description('Minimum replicas (1 keeps environment active; set to 0 only for cost-saving dev environments that can tolerate archive/cold-start).')
param minReplicas int = 1

@description('Maximum replicas.')
param maxReplicas int = 3

// ── Variables ─────────────────────────────────────────────────────────────────

var prefix    = 'bcmcp'
var envSuffix = environment == 'prod' ? '' : '-${environment}'
var lawName   = '${prefix}-law${envSuffix}'
var envName   = '${prefix}-env${envSuffix}'
var appName   = '${prefix}-app${envSuffix}'
var image     = 'ghcr.io/${imageRepo}:${imageTag}'

// ── Log Analytics Workspace ───────────────────────────────────────────────────

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

// ── Container Apps Environment ────────────────────────────────────────────────

resource env 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: law.properties.customerId
        sharedKey: law.listKeys().primarySharedKey
      }
    }
  }
}

// ── Container App ─────────────────────────────────────────────────────────────

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
      }
      // Registry auth: if credentials are provided, use authenticated GHCR pulls.
      // Otherwise the package must be public for anonymous pulls.
      secrets: registryPassword != '' ? [
        { name: 'ghcr-password', value: registryPassword }
      ] : []
      registries: registryPassword != '' ? [
        {
          server: 'ghcr.io'
          username: registryUsername
          passwordSecretRef: 'ghcr-password'
        }
      ] : []
    }
    template: {
      containers: [
        {
          name: 'mcp'
          image: image
          resources: {
            cpu: json(cpuCores)
            memory: '${memoryGi}Gi'
          }
          env: [
            { name: 'MCP_TRANSPORT',    value: 'http' }
            { name: 'NODE_ENV',         value: 'production' }
            { name: 'PORT',             value: '8080' }
            { name: 'METRICS_BASE_URL', value: metricsBaseUrl }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/health', port: 8080 }
              initialDelaySeconds: 15
              periodSeconds: 30
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: { path: '/health', port: 8080 }
              initialDelaySeconds: 5
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: { metadata: { concurrentRequests: '10' } }
          }
        ]
      }
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Fully-qualified domain name of the deployed MCP server.')
output fqdn string = app.properties.configuration.ingress.fqdn

@description('Health check URL.')
output healthUrl string = 'https://${app.properties.configuration.ingress.fqdn}/health'

@description('MCP endpoint URL for .vscode/mcp.json.')
output mcpUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
