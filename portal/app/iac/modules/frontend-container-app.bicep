@description('Azure region for the app.')
param location string = resourceGroup().location

@description('Container App name.')
param appName string

@description('Managed environment resource ID.')
param environmentId string

@description('Container image reference.')
param image string

@description('Target port exposed by the container.')
param targetPort int = 80

@description('ACR login server for managed identity pull.')
param acrLoginServer string

@description('User-assigned managed identity resource ID for ACR pull.')
param acrPullIdentityId string

@description('Minimum replica count.')
param minReplicas int = 0

@description('Maximum replica count.')
param maxReplicas int = 2

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
          name: 'frontend'
          image: image
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
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
                concurrentRequests: '20'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
