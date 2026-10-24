## GitHub Actions Secrets Configuration

Integrate Azure credentials and environment-specific secrets into GitHub Actions workflows.

### Workflow Example

```yaml
name: Deploy Infrastructure

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v3

      - name: Azure Login
        uses: azure/login@v2
        with:
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy with Bicep
        run: |
          az deployment group create \
            --resource-group ${{ secrets.AZURE_RESOURCE_GROUP }} \
            --template-file main.bicep \
            --parameters environment=prod

      - name: Retrieve Secrets from Key Vault
        run: |
          SECRET=$(az keyvault secret show \
            --vault-name ${{ secrets.KEYVAULT_NAME }} \
            --name database-password \
            --query value -o tsv)
          echo "::add-mask::$SECRET"
          echo "DB_PASSWORD=$SECRET" >> $GITHUB_ENV
```

### Setting GitHub Secrets

```bash
# Store Azure credentials in GitHub repository secrets
gh secret set AZURE_TENANT_ID --body "your-tenant-id" --repo ivegamsft/basecoat
gh secret set AZURE_CLIENT_ID --body "your-client-id" --repo ivegamsft/basecoat
gh secret set AZURE_SUBSCRIPTION_ID --body "your-subscription-id" --repo ivegamsft/basecoat
gh secret set AZURE_RESOURCE_GROUP --body "your-resource-group" --repo ivegamsft/basecoat
gh secret set KEYVAULT_NAME --body "your-keyvault-name" --repo ivegamsft/basecoat
```
