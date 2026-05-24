@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short environment label appended to resource names.')
@allowed(['prod', 'staging', 'dev'])
param environment string = 'prod'

@description('Container image tag to deploy (for example latest or short SHA).')
param imageTag string = 'latest'

@description('GHCR image repository (org/repo).')
param imageRepo string = 'YOUR_ORG/basecoat-extension'

@description('GHCR username for authenticated pulls (github actor or org name).')
param registryUsername string = ''

@secure()
@description('GHCR token/PAT for authenticated pulls. If empty, anonymous pull is used.')
param registryPassword string = ''

@description('Container CPU cores.')
param cpuCores string = '0.25'

@description('Container memory in Gi.')
param memoryGi string = '0.5'

@description('Minimum replicas (0 = scale to zero).')
param minReplicas int = 0

@description('Maximum replicas.')
param maxReplicas int = 3

@description('Default request cap per user for extension API routes.')
param rateLimitMaxRequests int = 10

@description('Rate-limit window in milliseconds.')
param rateLimitWindowMs int = 60000

var prefix = 'bcext'
var envSuffix = environment == 'prod' ? '' : '-${environment}'
var lawName = '${prefix}-law${envSuffix}'
var appInsightsName = '${prefix}-ai${envSuffix}'
var envName = '${prefix}-env${envSuffix}'
var appName = '${prefix}-app${envSuffix}'
var image = 'ghcr.io/${imageRepo}:${imageTag}'

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: { enableLogAccessUsingOnlyResourcePermissions: true }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
  }
}

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
          name: 'extension'
          image: image
          resources: {
            cpu: json(cpuCores)
            memory: '${memoryGi}Gi'
          }
          env: [
            { name: 'NODE_ENV', value: 'production' }
            { name: 'PORT', value: '8080' }
            { name: 'OTEL_SERVICE_NAME', value: 'basecoat-extension' }
            { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
            { name: 'RATE_LIMIT_MAX_REQUESTS', value: string(rateLimitMaxRequests) }
            { name: 'RATE_LIMIT_WINDOW_MS', value: string(rateLimitWindowMs) }
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

@description('Fully-qualified domain name of the deployed extension service.')
output fqdn string = app.properties.configuration.ingress.fqdn

@description('Health check URL.')
output healthUrl string = 'https://${app.properties.configuration.ingress.fqdn}/health'

@description('Application Insights component name.')
output appInsightsComponent string = appInsights.name

