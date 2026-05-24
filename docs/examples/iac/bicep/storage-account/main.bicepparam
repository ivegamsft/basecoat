using './main.bicep'

param storageAccountName = 'stbasecoatdev001'

param tags = {
  environment: 'dev'
  owner: 'platform'
}
