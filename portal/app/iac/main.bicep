@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Deployment environment name.')
@allowed([
  'staging'
])
param environment string = 'staging'

@description('Deployment mode boundary for internal vs downstream deployments.')
@allowed([
  'internal'
  'downstream'
])
param deploymentMode string = 'internal'

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

var modeSuffix = deploymentMode == 'internal' ? '-int' : '-dwn'
var nameSuffix = environment == 'staging' ? '-staging${modeSuffix}' : modeSuffix
var prefix = 'portal'
var lawName = '${prefix}-law${nameSuffix}'
var appInsightsName = '${prefix}-appi${nameSuffix}'
var envName = '${prefix}-env${nameSuffix}'
var backendName = '${prefix}-backend${nameSuffix}'
var frontendName = '${prefix}-frontend${nameSuffix}'
var postgresServerName = toLower('${prefix}-pg${nameSuffix}-${substring(uniqueString(resourceGroup().id), 0, 6)}')
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrPullIdentityName = '${prefix}-acr-pull${nameSuffix}'
var ingressExternal = deploymentMode == 'internal'
var postgresPublicNetworkAccess = deploymentMode == 'internal' ? 'Enabled' : 'Disabled'

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

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    DisableIpMasking: false
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
    publicNetworkAccess: postgresPublicNetworkAccess
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
    appInsightsConnectionString: appInsights.properties.ConnectionString
    ingressExternal: ingressExternal
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
    appInsightsConnectionString: appInsights.properties.ConnectionString
    ingressExternal: ingressExternal
  }
}

output deploymentMode string = deploymentMode
output resourceGroupName string = resourceGroup().name
output backendUrl string = 'https://${backend.outputs.fqdn}'
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output databaseFqdn string = database.outputs.fqdn
output acrLoginServer string = registry.outputs.loginServer
output logAnalyticsWorkspaceId string = law.id
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output backendContainerAppId string = resourceId('Microsoft.App/containerApps', backendName)
output frontendContainerAppId string = resourceId('Microsoft.App/containerApps', frontendName)
output postgresServerResourceId string = resourceId('Microsoft.DBforPostgreSQL/flexibleServers', postgresServerName)
