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
param acrName string = toLower('portalacr${environment}${deploymentMode}${substring(uniqueString(subscription().subscriptionId, environment, deploymentMode), 0, 4)}')

@description('Backend container image tag (repo:tag, without registry prefix).')
param backendImageTag string = ''

@description('Frontend container image tag (repo:tag, without registry prefix).')
param frontendImageTag string = ''

@description('Downstream backend image reference (fully qualified).')
param downstreamBackendImage string = ''

@description('Downstream frontend image reference (fully qualified).')
param downstreamFrontendImage string = ''

@description('Downstream CORS origins for backend container app.')
param downstreamCorsOrigins string = '*'

@description('PostgreSQL administrator login.')
param postgresAdminLogin string = 'portaladmin'

@secure()
@description('PostgreSQL administrator password. If omitted, Bicep generates one for this deployment.')
param postgresAdminPassword string = 'Pg!${substring(replace(newGuid(), '-', ''), 0, 20)}Aa1'

@description('PostgreSQL database name.')
param postgresDatabaseName string = 'portaldb'

var envSuffix = environment == 'staging' ? 'stg' : toLower(environment)
var modeSuffix = deploymentMode == 'internal' ? 'int' : 'dwn'
var stableSuffix = substring(uniqueString(subscription().subscriptionId, environment, deploymentMode), 0, 6)
var prefix = 'portal'
var lawName = '${prefix}-law-${envSuffix}-${modeSuffix}'
var appInsightsName = '${prefix}-appi-${envSuffix}-${modeSuffix}'
var envName = '${prefix}-env-${envSuffix}-${modeSuffix}'
var backendName = '${prefix}-backend-${envSuffix}-${modeSuffix}'
var frontendName = '${prefix}-frontend-${envSuffix}-${modeSuffix}'
var postgresServerName = toLower('${prefix}-pg-${envSuffix}-${modeSuffix}-${stableSuffix}')
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrPullIdentityName = '${prefix}-acr-pull-${envSuffix}-${modeSuffix}'
var backendImage = deploymentMode == 'internal'
  ? (empty(backendImageTag) ? fail('backendImageTag is required when deploymentMode=internal') : '${registry!.outputs.loginServer}/${backendImageTag}')
  : (empty(downstreamBackendImage) ? fail('downstreamBackendImage is required when deploymentMode=downstream') : downstreamBackendImage)
var frontendImage = deploymentMode == 'internal'
  ? (empty(frontendImageTag) ? fail('frontendImageTag is required when deploymentMode=internal') : '${registry!.outputs.loginServer}/${frontendImageTag}')
  : (empty(downstreamFrontendImage) ? fail('downstreamFrontendImage is required when deploymentMode=downstream') : downstreamFrontendImage)

resource acrPullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (deploymentMode == 'internal') {
  name: acrPullIdentityName
  location: location
}

module registry './modules/container-registry.bicep' = if (deploymentMode == 'internal') {
  name: 'container-registry'
  params: {
    location: location
    registryName: acrName
  }
}

resource acrRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (deploymentMode == 'internal') {
  name: acrName
}

resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deploymentMode == 'internal') {
  name: guid(resourceGroup().id, acrPullIdentityName, acrPullRoleId)
  scope: acrRegistry
  dependsOn: [registry]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: acrPullIdentity!.properties.principalId
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
    IngestionMode: 'LogAnalytics'
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
    publicNetworkAccess: 'Enabled'
  }
}

module frontend './modules/frontend-container-app.bicep' = {
  name: 'frontend-container-app'
  dependsOn: deploymentMode == 'internal' ? [acrPullRole] : []
  params: {
    location: location
    appName: frontendName
    environmentId: env.id
    image: frontendImage
    acrLoginServer: deploymentMode == 'internal' ? registry!.outputs.loginServer : ''
    acrPullIdentityId: deploymentMode == 'internal' ? acrPullIdentity!.id : ''
    ingressExternal: deploymentMode == 'internal'
    deploymentMode: deploymentMode
    appInsightsConnectionString: appInsights.properties.ConnectionString
  }
}

module backend './modules/backend-container-app.bicep' = {
  name: 'backend-container-app'
  dependsOn: deploymentMode == 'internal' ? [acrPullRole] : []
  params: {
    location: location
    appName: backendName
    environmentId: env.id
    image: backendImage
    acrLoginServer: deploymentMode == 'internal' ? registry!.outputs.loginServer : ''
    acrPullIdentityId: deploymentMode == 'internal' ? acrPullIdentity!.id : ''
    ingressExternal: deploymentMode == 'internal'
    deploymentMode: deploymentMode
    appInsightsConnectionString: appInsights.properties.ConnectionString
    dbHost: database.outputs.fqdn
    dbPort: 5432
    dbName: postgresDatabaseName
    dbUser: postgresAdminLogin
    dbPassword: postgresAdminPassword
    corsOrigins: deploymentMode == 'internal' ? 'https://${frontend.outputs.fqdn}' : downstreamCorsOrigins
  }
}

output deploymentMode string = deploymentMode
output resourceGroupName string = resourceGroup().name
output backendUrl string = deploymentMode == 'internal' ? 'https://${backend.outputs.fqdn}' : ''
output frontendUrl string = 'https://${frontend.outputs.fqdn}'
output databaseFqdn string = database.outputs.fqdn
output acrLoginServer string = deploymentMode == 'internal' ? registry!.outputs.loginServer : ''
output logAnalyticsWorkspaceId string = law.id
output appInsightsName string = appInsights.name
output appInsightsResourceId string = appInsights.id
output backendContainerAppId string = backend.outputs.resourceId
output frontendContainerAppId string = frontend.outputs.resourceId
output postgresServerResourceId string = database.outputs.resourceId
output targetResourceGroupName string = resourceGroup().name
output targetResourceGroupId string = resourceGroup().id
output acrResourceId string = deploymentMode == 'internal' ? registry!.outputs.registryId : ''
