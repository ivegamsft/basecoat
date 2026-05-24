@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Deployment environment name.')
@allowed([
  'staging'
])
param environment string = 'staging'

@description('Azure Container Registry name (globally unique, alphanumeric).')
param acrName string = toLower('portalacr${substring(uniqueString(resourceGroup().id), 0, 6)}')

@description('Backend container image tag (repo:tag, without registry prefix).')
param backendImageTag string

@description('Frontend container image tag (repo:tag, without registry prefix).')
param frontendImageTag string

@description('PostgreSQL administrator login.')
param postgresAdminLogin string = 'portaladmin'

@secure()
@description('PostgreSQL administrator password. If omitted, Bicep generates one for this deployment.')
param postgresAdminPassword string = 'Pg!${substring(replace(newGuid(), '-', ''), 0, 20)}Aa1'

@description('PostgreSQL database name.')
param postgresDatabaseName string = 'portaldb'

var nameSuffix = environment == 'staging' ? '-staging' : ''
var prefix = 'portal'
var lawName = '${prefix}-law${nameSuffix}'
var envName = '${prefix}-env${nameSuffix}'
var backendName = '${prefix}-backend${nameSuffix}'
var frontendName = '${prefix}-frontend${nameSuffix}'
var postgresServerName = toLower('${prefix}-pg${nameSuffix}-${substring(uniqueString(resourceGroup().id), 0, 6)}')
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrPullIdentityName = '${prefix}-acr-pull${nameSuffix}'

// User-assigned managed identity for ACR pull — created BEFORE container apps
// so the AcrPull role assignment is in place when ACA pulls images.
resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: acrPullIdentityName
  location: location
}

// Azure Container Registry
module registry './modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    registryName: acrName
  }
}

// AcrPull role on the registry for the shared identity
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, acrPullIdentityName, acrPullRoleId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: acrPullIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
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

module database './modules/postgresql-flexible-server.bicep' = {
  name: 'postgresql-flexible-server'
  params: {
    location: location
    serverName: postgresServerName
    databaseName: postgresDatabaseName
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
  }
}

module frontend './modules/frontend-container-app.bicep' = {
  name: 'frontend-container-app'
  dependsOn: [acrPullRole]
  params: {
    location: location
    appName: frontendName
    environmentId: env.id
    image: '${registry.outputs.loginServer}/${frontendImageTag}'
    acrLoginServer: registry.outputs.loginServer
    acrPullIdentityId: acrPullIdentity.id
  }
}

module backend './modules/backend-container-app.bicep' = {
  name: 'backend-container-app'
  dependsOn: [acrPullRole]
  params: {
    location: location
    appName: backendName
    environmentId: env.id
    image: '${registry.outputs.loginServer}/${backendImageTag}'
    acrLoginServer: registry.outputs.loginServer
    acrPullIdentityId: acrPullIdentity.id
    dbHost: database.outputs.fqdn
    dbPort: 5432
    dbName: postgresDatabaseName
    dbUser: postgresAdminLogin
    dbPassword: postgresAdminPassword
    corsOrigins: 'https://${frontend.outputs.fqdn}'
  }
}

output backendUrl string = 'https://${backend.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output databaseFqdn string = database.outputs.fqdn
output acrLoginServer string = registry.outputs.loginServer
