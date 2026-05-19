@description('Azure region for the registry.')
param location string = resourceGroup().location

@description('Container registry name (must be globally unique, alphanumeric only).')
param registryName string

@description('SKU for the container registry.')
@allowed([
  'Basic'
  'Standard'
])
param sku string = 'Basic'

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

output loginServer string = acr.properties.loginServer
output registryId string = acr.id
output registryName string = acr.name
