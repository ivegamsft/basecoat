# OIDC Federation Setup for CI/CD

OpenID Connect (OIDC) federation allows GitHub Actions to authenticate to Azure without storing service principal credentials as secrets.

## Prerequisites

Before setting up OIDC federation, ensure you have:

- Azure subscription with Owner or Contributor access
- GitHub repository with Actions enabled
- Azure CLI installed locally
- Permissions to create Entra ID applications and federated credentials

## Step 1: Create an Entra ID Application

```bash
# Create the Entra ID app registration
az ad app create --display-name "github-actions-ci"

# Get the application ID
APP_ID=$(az ad app list --query "[?displayName=='github-actions-ci'].appId" -o tsv)
echo "Application ID: $APP_ID"

# Create a service principal for the app
az ad sp create --id $APP_ID
```

## Step 2: Configure Federated Credentials

```bash
# Set variables
TENANT_ID=$(az account show --query tenantId -o tsv)
REPO_OWNER="IBuySpy-Shared"
REPO_NAME="basecoat"
GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com"
# If enterprise custom issuer policy is enabled, use:
# GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com/<enterprise-slug>"
GITHUB_ENTITY="repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/main"

# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main",
    "issuer": "'$GITHUB_OIDC_ISSUER'",
    "subject": "'$GITHUB_ENTITY'",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Step 3: Assign Azure RBAC Roles

```bash
# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Assign Contributor role to service principal
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $(az ad sp show --id $APP_ID --query id -o tsv) \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

## GitHub Actions OIDC Token Exchange

Configure your workflow to use OIDC for authentication:

```yaml
name: Deploy with OIDC

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          
      - name: Deploy Infrastructure
        run: |
          az group create --name myResourceGroup --location eastus
```

## Multiple Environments

For multi-environment deployments, create additional federated credentials:

```bash
# For staging environment
GITHUB_ENTITY_STAGING="repo:${REPO_OWNER}/${REPO_NAME}:ref:refs/heads/staging"

az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-staging",
    "issuer": "'$GITHUB_OIDC_ISSUER'",
    "subject": "'$GITHUB_ENTITY_STAGING'",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For pull requests
GITHUB_ENTITY_PR="repo:${REPO_OWNER}/${REPO_NAME}:pull_request"

az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pr",
    "issuer": "'$GITHUB_OIDC_ISSUER'",
    "subject": "'$GITHUB_ENTITY_PR'",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Troubleshooting OIDC

**Issue**: "AADSTS700016: Application with identifier was not found in the directory"

**Solution**: Verify the application ID matches the service principal and federated credentials are configured for the correct repository/branch.

**Issue**: "JWT returned in the request is not valid"

**Solution**: Ensure GitHub token expiration hasn't passed; tokens are valid for 5 minutes. Verify audience matches exactly: `api://AzureADTokenExchange`

**Issue**: "AADSTS700211: No matching federated identity record found for presented assertion issuer"

**Solution**: Ensure federated credential issuer exactly matches the token issuer. If enterprise custom issuer policy is enabled, use `https://token.actions.githubusercontent.com/<enterprise-slug>` instead of the default issuer.

## References

- [Microsoft: Use GitHub Actions with Azure Login](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [GitHub Docs: About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
