<#
.SYNOPSIS
    Create or refresh the BaseCoat Copilot Space for an organization.

.DESCRIPTION
    Uses the GitHub Copilot Spaces REST API to create an org-owned space and
    attach BaseCoat sources as context. The script is idempotent: existing
    resources are detected and skipped.

.PARAMETER Org
    GitHub organization that will own the Space. Defaults to example-org.

.PARAMETER SpaceName
    Copilot Space name. Defaults to base-coat.

.PARAMETER Description
    Human-readable description for the Space.

.PARAMETER SourceRepo
    Source repository to index. Defaults to ivegamsft/basecoat.

.PARAMETER SourceRef
    Branch or tag to read source files from. Defaults to main.

.PARAMETER SpaceNumber
    If the Space was created manually via the UI, pass the space number
    (from the URL) to skip API-based creation and proceed to resource setup.

.PARAMETER DryRun
    Show the actions without mutating GitHub.

.NOTES
    The Copilot Spaces REST API may return 404 from gh CLI tokens even with
    write:org scope. If that happens, create the Space via the UI at
    https://github.com/copilot/spaces and pass -SpaceNumber to this script.

.EXAMPLE
    pwsh scripts/bootstrap-copilot-space.ps1

.EXAMPLE
    pwsh scripts/bootstrap-copilot-space.ps1 -SpaceNumber 2

.EXAMPLE
    pwsh scripts/bootstrap-copilot-space.ps1 -Org "example-org" -DryRun
#>

[CmdletBinding()]
param(
    [string]$Org = 'example-org',
    [string]$SpaceName = 'base-coat',
    [string]$Description = 'BaseCoat guidance, reference docs, and bootstrap context.',
    [string]$SourceRepo = 'ivegamsft/basecoat',
    [string]$SourceRef = 'main',
    [int]$SpaceNumber = 0,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Header([string]$Text) {
    Write-Host ""
    Write-Host ('=' * 72) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor Cyan
}

function Write-Ok([string]$Text)   { Write-Host "  ✅  $Text" -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host "  ℹ️   $Text" -ForegroundColor DarkGray }
function Write-Warn([string]$Text) { Write-Host "  ⚠️   $Text" -ForegroundColor Yellow }

function Resolve-RepoSlug {
    param([string]$Value)

    if ($Value -match '^https?://github\.com/') {
        return ($Value -replace '^https?://github\.com/', '' -replace '\.git$', '').TrimEnd('/')
    }

    return $Value.TrimEnd('/')
}

function Invoke-GhApiJson {
    param(
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method = 'GET',
        [object]$Body
    )

    $args = @(
        'api',
        $Endpoint,
        '--method', $Method,
        '-H', 'Accept: application/vnd.github+json',
        '-H', 'X-GitHub-Api-Version: 2026-03-10'
    )

    if ($PSBoundParameters.ContainsKey('Body')) {
        $json = $Body | ConvertTo-Json -Depth 20 -Compress
        $result = $json | gh @args --input - 2>&1
    } else {
        $result = gh @args 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        throw "gh api $Method $Endpoint failed: $($result -join ' ')"
    }

    if (-not $result) {
        return $null
    }

    return ($result -join "`n") | ConvertFrom-Json
}

function Test-GhAuth {
    $status = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0 -or -not ($status -match 'Logged in')) {
        throw "GitHub CLI is not authenticated. Run 'gh auth login' first."
    }
}

function Get-SpaceByName {
    param(
        [string]$OrgName,
        [string]$Name
    )

    $result = Invoke-GhApiJson "/orgs/$OrgName/copilot-spaces"
    foreach ($space in @($result.spaces)) {
        if ($space.name -eq $Name) {
            return $space
        }
    }

    return $null
}

function Get-SpaceResources {
    param(
        [string]$OrgName,
        [int]$SpaceNumber
    )

    $result = Invoke-GhApiJson "/orgs/$OrgName/copilot-spaces/$SpaceNumber/resources"
    return @($result.resources)
}

function Get-RepoId {
    param([string]$RepoSlug)

    $repo = Invoke-GhApiJson "/repos/$RepoSlug"
    return [int64]$repo.id
}

function Get-RepoDefaultBranch {
    param([string]$RepoSlug)

    $repo = Invoke-GhApiJson "/repos/$RepoSlug"
    return $repo.default_branch
}

function Get-FileSha {
    param(
        [string]$RepoSlug,
        [string]$Path,
        [string]$Ref
    )

    $endpoint = "/repos/$RepoSlug/contents/$Path?ref=$Ref"
    $file = Invoke-GhApiJson $endpoint
    return $file.sha
}

function New-Space {
    param(
        [string]$OrgName,
        [string]$Name,
        [string]$DescriptionText
    )

    $payload = @{
        name = $Name
        description = $DescriptionText
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create space '$Name' in org '$OrgName'"
        return [pscustomobject]@{ number = $null; name = $Name; description = $DescriptionText }
    }

    return Invoke-GhApiJson "/orgs/$OrgName/copilot-spaces" -Method POST -Body $payload
}

function Add-ResourceIfMissing {
    param(
        [string]$OrgName,
        [int]$SpaceNumber,
        [array]$ExistingResources,
        [string]$ResourceType,
        [hashtable]$Metadata
    )

    $match = $null
    switch ($ResourceType) {
        'repository' {
            $repoId = [int64]$Metadata.repository_id
            $match = $ExistingResources | Where-Object {
                $_.resource_type -eq 'repository' -and [int64]$_.metadata.repository_id -eq $repoId
            } | Select-Object -First 1
        }
        'github_file' {
            $repoId = [int64]$Metadata.repository_id
            $filePath = $Metadata.file_path
            $sha = $Metadata.sha
            $match = $ExistingResources | Where-Object {
                $_.resource_type -eq 'github_file' -and
                [int64]$_.metadata.repository_id -eq $repoId -and
                $_.metadata.file_path -eq $filePath -and
                $_.metadata.sha -eq $sha
            } | Select-Object -First 1
        }
        'free_text' {
            $name = $Metadata.name
            $match = $ExistingResources | Where-Object {
                $_.resource_type -eq 'free_text' -and $_.metadata.name -eq $name
            } | Select-Object -First 1
        }
    }

    $resourceLabel = if ($Metadata.ContainsKey('file_path')) {
        $Metadata.file_path
    } elseif ($Metadata.ContainsKey('name')) {
        $Metadata.name
    } else {
        $Metadata.repository_id
    }

    if ($match) {
        Write-Ok "Resource already present: $ResourceType $resourceLabel"
        return $match
    }

    $payload = @{
        resource_type = $ResourceType
        metadata = $Metadata
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] Would add $ResourceType resource: $resourceLabel"
        return $null
    }

    return Invoke-GhApiJson "/orgs/$OrgName/copilot-spaces/$SpaceNumber/resources" -Method POST -Body $payload
}

function Show-ManualFallback {
    param(
        [string]$OrgName,
        [string]$Name,
        [string]$SourceRepoSlug
    )

    Write-Warn 'Copilot Spaces API is not available to the current token or tenant.'
    Write-Host ''
    Write-Host '  Manual fallback:' -ForegroundColor Yellow
    Write-Host "  1. Open https://github.com/copilot/spaces" -ForegroundColor White
    Write-Host "  2. Create an organization-owned space named '$Name' under '$OrgName'" -ForegroundColor White
    Write-Host "  3. Add the '$SourceRepoSlug' repository as a source" -ForegroundColor White
    Write-Host "  4. Add README.md, CHANGELOG.md, docs/reference/INVENTORY.md, and docs/guides/ as sources" -ForegroundColor White
    Write-Host "  5. Add a free-text note that tells Copilot to prioritize those docs" -ForegroundColor White
}

try {
    Write-Header 'BaseCoat Copilot Space Bootstrap'
    Test-GhAuth

    $Org = Resolve-RepoSlug $Org
    $SourceRepo = Resolve-RepoSlug $SourceRepo

    Write-Info "Org: $Org"
    Write-Info "Space: $SpaceName"
    Write-Info "Source repo: $SourceRepo @ $SourceRef"

    $space = $null
    if ($SpaceNumber -gt 0) {
        Write-Ok "Using provided space number: #$SpaceNumber"
        $space = [pscustomobject]@{ number = $SpaceNumber; name = $SpaceName }
    } else {
        $space = Get-SpaceByName -OrgName $Org -Name $SpaceName
        if ($space) {
            Write-Ok "Space already exists (#$($space.number))"
        } else {
            $space = New-Space -OrgName $Org -Name $SpaceName -DescriptionText $Description
            if ($space.number) {
                Write-Ok "Created space #$($space.number)"
            }
        }
    }

    if (-not $space.number) {
        if ($DryRun) {
            Write-Info 'Dry run complete. No resources were created.'
            return
        }

        throw "Unable to determine the Copilot Space number for '$SpaceName'."
    }

    $spaceNumber = [int]$space.number
    $resources = Get-SpaceResources -OrgName $Org -SpaceNumber $spaceNumber
    Write-Info "Existing resources: $($resources.Count)"

    $repoId = Get-RepoId -RepoSlug $SourceRepo
    Add-ResourceIfMissing -OrgName $Org -SpaceNumber $spaceNumber -ExistingResources $resources -ResourceType 'repository' -Metadata @{
        repository_id = $repoId
    } | Out-Null

    $guideFiles = @(
        'README.md',
        'CHANGELOG.md',
        'docs/reference/INVENTORY.md'
    )

    $defaultBranch = Get-RepoDefaultBranch -RepoSlug $SourceRepo
    $tree = Invoke-GhApiJson "/repos/$SourceRepo/git/trees/$defaultBranch?recursive=1"
    $guideFiles += @(
        $tree.tree |
            Where-Object { $_.type -eq 'blob' -and $_.path -like 'docs/guides/*.md' } |
            Select-Object -ExpandProperty path
    )

    $guideFiles = $guideFiles | Sort-Object -Unique

    foreach ($path in $guideFiles) {
        try {
            $sha = Get-FileSha -RepoSlug $SourceRepo -Path $path -Ref $defaultBranch
            Add-ResourceIfMissing -OrgName $Org -SpaceNumber $spaceNumber -ExistingResources $resources -ResourceType 'github_file' -Metadata @{
                repository_id = $repoId
                file_path = $path
                sha = $sha
            } | Out-Null
        } catch {
            Write-Warn "Skipping missing file: $path"
        }
    }

    $instructions = @(
        "Focus on BaseCoat bootstrap and adoption guidance.",
        "Prioritize README.md, CHANGELOG.md, docs/reference/INVENTORY.md, and docs/guides/.",
        "Use the latest main branch content from $SourceRepo."
    ) -join ' '

    Add-ResourceIfMissing -OrgName $Org -SpaceNumber $spaceNumber -ExistingResources $resources -ResourceType 'free_text' -Metadata @{
        name = 'bootstrap-context.md'
        text = $instructions
    } | Out-Null

    Write-Host ''
    Write-Ok "Copilot Space bootstrap complete."
    Write-Info "Space URL: https://github.com/copilot/spaces/$Org/$spaceNumber"
}
catch {
    $message = $_.Exception.Message
    if ($message -match 'HTTP 404|Not found') {
        Show-ManualFallback -OrgName $Org -Name $SpaceName -SourceRepoSlug $SourceRepo
        Write-Info 'Manual fallback complete.'
        exit 0
    }

    Write-Host ''
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
