@description('Azure region for the database server.')
param location string = resourceGroup().location

@description('PostgreSQL flexible server name.')
param serverName string

@description('Database name.')
param databaseName string = 'portaldb'

@description('Administrator login name.')
param administratorLogin string = 'portaladmin'

@secure()
@description('Administrator password.')
param administratorLoginPassword string

@description('PostgreSQL version.')
param version string = '16'

@description('Flexible server SKU name.')
param skuName string = 'Standard_B1ms'

@description('Storage size in GB.')
param storageSizeGB int = 32

@description('Backup retention in days.')
param backupRetentionDays int = 7

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: server
  name: 'allow-azure-services'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: server
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

output fqdn string = server.properties.fullyQualifiedDomainName
output serverName string = server.name
output databaseName string = database.name
output adminLogin string = administratorLogin
