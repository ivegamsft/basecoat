$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Assert-PathExists {
    param([string]$Path, [string]$Message)
    if (-not (Test-Path $Path)) { throw $Message }
}

function Assert-JsonValid {
    param([string]$Path, [string]$Message)
    try {
        Get-Content $Path -Raw | ConvertFrom-Json | Out-Null
    } catch {
        throw "${Message}: $_"
    }
}

function Assert-FileContains {
    param([string]$Path, [string]$Pattern, [string]$Message)
    $content = Get-Content $Path -Raw
    if ($content -notmatch $Pattern) { throw $Message }
}

Write-Host 'MCP tests: checking required files...'

# Source files
Assert-PathExists 'mcp/basecoat-metrics/src/index.ts'         'mcp/basecoat-metrics/src/index.ts is missing'
Assert-PathExists 'mcp/basecoat-metrics/package.json'          'mcp/basecoat-metrics/package.json is missing'
Assert-PathExists 'mcp/basecoat-metrics/tsconfig.json'         'mcp/basecoat-metrics/tsconfig.json is missing'
Assert-PathExists 'mcp/basecoat-metrics/Dockerfile'            'mcp/basecoat-metrics/Dockerfile is missing'
Assert-PathExists 'mcp/basecoat-metrics/README.md'             'mcp/basecoat-metrics/README.md is missing'

# IaC
Assert-PathExists 'infra/mcp/main.bicep'  'infra/mcp/main.bicep is missing'
Assert-PathExists 'infra/mcp/README.md'   'infra/mcp/README.md is missing'

# Workflows
Assert-PathExists '.github/workflows/mcp-build.yml'   '.github/workflows/mcp-build.yml is missing'
Assert-PathExists '.github/workflows/mcp-deploy.yml'  '.github/workflows/mcp-deploy.yml is missing'

# VS Code config
Assert-PathExists '.vscode/mcp.json'  '.vscode/mcp.json is missing'

Write-Host 'MCP tests: validating package.json...'
$pkg = Get-Content 'mcp/basecoat-metrics/package.json' -Raw | ConvertFrom-Json
if (-not $pkg.scripts.build) { throw 'package.json is missing scripts.build' }
if (-not $pkg.scripts.start) { throw 'package.json is missing scripts.start' }
if (-not $pkg.scripts.test)  { throw 'package.json is missing scripts.test' }
if ($pkg.dependencies.'@modelcontextprotocol/sdk' -eq $null) {
    throw "package.json missing @modelcontextprotocol/sdk dependency"
}

Write-Host 'MCP tests: validating JSON files...'
Assert-JsonValid 'mcp/basecoat-metrics/package.json'  'package.json is not valid JSON'
Assert-JsonValid 'mcp/basecoat-metrics/tsconfig.json' 'tsconfig.json is not valid JSON'
Assert-JsonValid '.vscode/mcp.json'                   '.vscode/mcp.json is not valid JSON'

Write-Host 'MCP tests: validating .vscode/mcp.json entries...'
$mcpJson = Get-Content '.vscode/mcp.json' -Raw | ConvertFrom-Json
$serverNames = $mcpJson.servers.PSObject.Properties.Name
if ('basecoat-metrics' -notin $serverNames) {
    throw ".vscode/mcp.json is missing the 'basecoat-metrics' server entry"
}

Write-Host 'MCP tests: validating Bicep outputs...'
Assert-FileContains 'infra/mcp/main.bicep' 'output fqdn'      'infra/mcp/main.bicep is missing fqdn output'
Assert-FileContains 'infra/mcp/main.bicep' 'output healthUrl' 'infra/mcp/main.bicep is missing healthUrl output'
Assert-FileContains 'infra/mcp/main.bicep' 'output mcpUrl'    'infra/mcp/main.bicep is missing mcpUrl output'

Write-Host 'MCP tests: validating HTTP transport in src/index.ts...'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'StreamableHTTPServerTransport' `
    'src/index.ts is missing StreamableHTTPServerTransport (HTTP transport not implemented)'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' '/health' `
    'src/index.ts is missing /health endpoint'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'MCP_TRANSPORT' `
    'src/index.ts is missing MCP_TRANSPORT env var switch'

Write-Host 'MCP tests: validating asset search tools in src/index.ts...'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'search-skills' `
    'src/index.ts is missing search-skills tool'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'search-agents' `
    'src/index.ts is missing search-agents tool'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'get-asset-details' `
    'src/index.ts is missing get-asset-details tool'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'REPO_DIR' `
    'src/index.ts is missing REPO_DIR environment variable support'
Assert-FileContains 'mcp/basecoat-metrics/src/index.ts' 'parseFrontmatter' `
    'src/index.ts is missing parseFrontmatter helper function'

Write-Host 'MCP tests: validating Dockerfile...'
Assert-FileContains 'mcp/basecoat-metrics/Dockerfile' 'HEALTHCHECK' `
    'Dockerfile is missing HEALTHCHECK instruction'
Assert-FileContains 'mcp/basecoat-metrics/Dockerfile' 'node:22' `
    'Dockerfile must use node:22 base image'
Assert-FileContains 'mcp/basecoat-metrics/Dockerfile' 'USER' `
    'Dockerfile must drop to non-root USER'

Write-Host 'MCP tests: validating deploy workflow has required secrets...'
Assert-FileContains '.github/workflows/mcp-deploy.yml' 'AZURE_CREDENTIALS' `
    'mcp-deploy.yml is missing AZURE_CREDENTIALS secret reference'
Assert-FileContains '.github/workflows/mcp-deploy.yml' 'MCP_RESOURCE_GROUP' `
    'mcp-deploy.yml is missing MCP_RESOURCE_GROUP secret reference'

Write-Host 'MCP tests: validating build workflow is pinned to ubuntu-latest (CI-only workflow)...'
Assert-FileContains '.github/workflows/mcp-build.yml' "runs-on: ubuntu-latest" `
    'mcp-build.yml must use ubuntu-latest (CI check workflow — Docker smoke test requires Linux runner with Docker)'

Write-Host 'MCP tests: validating deploy workflow build-push is pinned to ubuntu-latest and deploy uses vars.RUNNER_DEPLOY...'
$deployContent = Get-Content '.github/workflows/mcp-deploy.yml' -Raw
if ($deployContent -notmatch '(?m)^  build-push:[\s\S]*?^\s+runs-on:\s+ubuntu-latest') {
    throw "mcp-deploy.yml build-push job must be pinned to ubuntu-latest (Docker required)"
}
if ($deployContent -notmatch '(?m)^\s+runs-on:\s.*vars\.RUNNER_DEPLOY') {
    throw "mcp-deploy.yml deploy job must route runs-on through vars.RUNNER_DEPLOY"
}
if ($deployContent -notmatch "(?m)^\s+runs-on:\s.*ubuntu-latest") {
    throw "mcp-deploy.yml must include ubuntu-latest as fallback in runs-on expressions"
}

Write-Host 'MCP tests: validating dead resolve-deploy-runner job is removed from deploy workflow...'
if ($deployContent -match '(?m)^  resolve-deploy-runner:') {
    throw 'mcp-deploy.yml still contains resolve-deploy-runner job; should have been removed'
}

Write-Host 'MCP tests passed' -ForegroundColor Green
