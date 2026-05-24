# Infrastructure

This directory contains all Infrastructure as Code (IaC) for the BaseCoat platform.

## Azure (Bicep)

- `mcp/` — MCP server IaC (Azure Container Apps), deployed via `.github/workflows/mcp-deploy.yml`

## AWS (Terraform)

- `aws/` — AWS infrastructure Terraform modules (networking, database, compute, caching, storage, secrets, security, monitoring)

See `aws/README.md` and `aws/DEPLOYMENT_GUIDE.md` for usage instructions.
