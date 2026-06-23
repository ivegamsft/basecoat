param(
    [string]$BaseCoatRepo = 'ivegamsft/basecoat',
    [string]$Version = 'v0.4.3',
    [switch]$KeepRepo
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git is required'
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is required'
}

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    throw 'tar is required'
}

$tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ('basecoat-consumer-' + [System.Guid]::NewGuid().ToString())
$downloadDir = Join-Path $tempRepo '.basecoat-download'
$lockPath = Join-Path $tempRepo '.github/base-coat.lock.json'

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

function Assert-Checksum {
    param(
        [string]$ChecksumFile,
        [string]$Directory
    )

    foreach ($line in Get-Content $ChecksumFile) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split '\s+', 2
        if ($parts.Count -ne 2) {
            throw "Malformed checksum line: $line"
        }

        $expected = $parts[0].Trim().ToLowerInvariant()
        $relativePath = $parts[1].Trim().TrimStart('*')
        $fullPath = Join-Path $Directory $relativePath
        Assert-PathExists -Path $fullPath -Message "Checksum target missing: $relativePath"

        $actual = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            throw "Checksum mismatch for $relativePath"
        }
    }
}

try {
    New-Item -ItemType Directory -Path (Join-Path $tempRepo '.github/workflows') -Force | Out-Null
    git init $tempRepo | Out-Null

    Push-Location $tempRepo
    git config user.name 'basecoat-consumer-test'
    git config user.email 'basecoat-consumer-test@example.com'

    @"
{
  "baseCoatRepo": "$BaseCoatRepo",
  "version": "$Version",
  "installPath": ".github/base-coat",
  "checksumRequired": true
}
"@ | Set-Content -Path $lockPath -NoNewline

    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    $env:GH_PAGER = 'cat'
    gh release download $Version --repo $BaseCoatRepo --pattern 'base-coat-*.tar.gz' --pattern 'base-coat-*.zip' --pattern 'SHA256SUMS.txt' --dir $downloadDir

    $checksumFile = Join-Path $downloadDir 'SHA256SUMS.txt'
    Assert-PathExists -Path $checksumFile -Message 'Checksum file missing from release download'
    Assert-Checksum -ChecksumFile $checksumFile -Directory $downloadDir

    $archive = Get-ChildItem -Path $downloadDir -Filter 'base-coat-*.tar.gz' | Select-Object -First 1
    if (-not $archive) {
        throw 'Release archive not downloaded'
    }

    tar -xzf $archive.FullName -C $tempRepo

    $installPath = Join-Path $tempRepo '.github/base-coat'
    $extractedPath = Join-Path $tempRepo 'base-coat'
    Assert-PathExists -Path $extractedPath -Message 'Expected extracted base-coat folder not found'
    Move-Item -Path $extractedPath -Destination $installPath

    foreach ($path in @(
            '.github/base-coat/instructions',
            '.github/base-coat/skills',
            '.github/base-coat/prompts',
            '.github/base-coat/agents',
            '.github/base-coat/version.json',
            '.github/base-coat/templates/intake/PULL_REQUEST_TEMPLATE.md',
            '.github/base-coat/templates/intake/issue.md'
        )) {
        Assert-PathExists -Path $path -Message "Installed baseline missing: $path"
    }

    & '.\.github\base-coat\scripts\validate-basecoat.ps1' '.\.github\base-coat'
    Write-Host "Consumer smoke test passed in $tempRepo"
}
finally {
    Pop-Location
    if (-not $KeepRepo -and (Test-Path $tempRepo)) {
        Remove-Item -Path $tempRepo -Recurse -Force
    }
}