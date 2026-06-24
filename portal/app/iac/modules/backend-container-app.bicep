@description('Azure region for the app.')
param location string = resourceGroup().location

@description('Container App name.')
param appName string

@description('Managed environment resource ID.')
param environmentId string

@description('Container image reference.')
param image string

@description('Target port exposed by the container.')
param targetPort int = 3000

@description('ACR login server for managed identity pull.')
param acrLoginServer string

@description('User-assigned managed identity resource ID for ACR pull.')
param acrPullIdentityId string

@description('Minimum replica count.')
param minReplicas int = 0

@description('Maximum replica count.')
param maxReplicas int = 2

@description('Database host name.')
param dbHost string

@description('Database port.')
param dbPort int = 5432

@description('Database name.')
param dbName string

@description('Database user.')
param dbUser string

@secure()
@description('Database password.')
param dbPassword string

@description('Allowed CORS origins.')
param corsOrigins string = '*'

@description('API prefix exposed by the backend.')
param apiPrefix string = '/api/v1'

@description('Application Insights connection string.')
param appInsightsConnectionString string = ''

@description('Whether ingress is externally exposed.')
param ingressExternal bool = true

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${acrPullIdentityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: ingressExternal
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
      }
      secrets: [
        {
          name: 'db-password'
          value: dbPassword
        }
      ]
      registries: [
        {
          server: acrLoginServer
          identity: acrPullIdentityId
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'PORT'
              value: string(targetPort)
            }
            {
              name: 'APP_NAME'
              value: 'basecoat-portal-api'
            }
            {
              name: 'API_PREFIX'
              value: apiPrefix
            }
            {
              name: 'CORS_ORIGINS'
              value: corsOrigins
            }
            {
              name: 'DB_HOST'
              value: dbHost
            }
            {
              name: 'DB_PORT'
              value: string(dbPort)
            }
            {
              name: 'DB_NAME'
              value: dbName
            }
            {
              name: 'DB_USER'
              value: dbUser
            }
            {
              name: 'DB_PASSWORD'
              secretRef: 'db-password'
            }
            {
              name: 'DB_SSL'
              value: 'true'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
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
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
