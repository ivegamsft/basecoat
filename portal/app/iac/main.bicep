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
param backendImageTag string = ''

@description('Frontend container image tag (repo:tag, without registry prefix).')
param frontendImageTag string = ''

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

// Azure Container Registry
module registry './modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    location: location
    registryName: acrName
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

// Use mcr.microsoft.com hello-world placeholder if no image tag provided (ACR-only provisioning)
var backendImage = empty(backendImageTag) ? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' : '${registry.outputs.loginServer}/${backendImageTag}'
var frontendImage = empty(frontendImageTag) ? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' : '${registry.outputs.loginServer}/${frontendImageTag}'

module frontend './modules/frontend-container-app.bicep' = {
  name: 'frontend-container-app'
  params: {
    location: location
    appName: frontendName
    environmentId: env.id
    image: frontendImage
    acrLoginServer: registry.outputs.loginServer
  }
}

module backend './modules/backend-container-app.bicep' = {
  name: 'backend-container-app'
  params: {
    location: location
    appName: backendName
    environmentId: env.id
    image: backendImage
    acrLoginServer: registry.outputs.loginServer
    dbHost: database.outputs.fqdn
    dbPort: 5432
    dbName: postgresDatabaseName
    dbUser: postgresAdminLogin
    dbPassword: postgresAdminPassword
    corsOrigins: 'https://${frontend.outputs.fqdn}'
  }
}

// AcrPull role assignment for backend managed identity
// Role definition ID for AcrPull: 7f951dda-4ed3-4680-a7ca-43fe172d538d
resource backendAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, backendName, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: backend.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// AcrPull role assignment for frontend managed identity
resource frontendAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, frontendName, '7f951dda-4ed3-4680-a7ca-43fe172d538d')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: frontend.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

output backendUrl string = 'https://${backend.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output databaseFqdn string = database.outputs.fqdn
output acrLoginServer string = registry.outputs.loginServer
