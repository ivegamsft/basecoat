param(
    [string]$BaseCoatRepo = 'IBuySpy-Shared/basecoat',
    [string]$Version = '',
    [ValidateSet('Release', 'Current')]
    [string]$ArtifactSource = 'Release',
    [string]$CallableRefOverride = '',
    [switch]$KeepRepo
)

$ErrorActionPreference = 'Stop'

foreach ($command in @('git', 'gh', 'tar')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is required"
    }
}
$gitBashPath = if ($IsWindows) { Join-Path $env:ProgramFiles 'Git\bin\bash.exe' } else { '' }
$bashCommand = if ($gitBashPath -and (Test-Path $gitBashPath -PathType Leaf)) {
    $gitBashPath
}
else {
    (Get-Command bash -ErrorAction Stop).Source
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $Version) {
    $Version = 'v' + ((Get-Content (Join-Path $repoRoot 'version.json') -Raw | ConvertFrom-Json).version)
}
$tempRepo = Join-Path $repoRoot ('test-results/basecoat-consumer-' + [System.Guid]::NewGuid().ToString())
$downloadDir = Join-Path $tempRepo '.basecoat-download'
$lockPath = Join-Path $tempRepo '.github/base-coat.lock.json'
$installPath = Join-Path $tempRepo '.github/base-coat'

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

function Assert-ReleaseAssetDigest {
    param(
        [string]$AssetName,
        [string]$AssetPath
    )

    $expectedDigest = gh release view $Version --repo $BaseCoatRepo --json assets --jq ".assets[] | select(.name == `"$AssetName`") | .digest"
    $digestMatch = [regex]::Match($expectedDigest, '^sha256:([a-fA-F0-9]{64})$')
    if (-not $digestMatch.Success) {
        throw "Release asset is missing an immutable SHA-256 digest: $AssetName"
    }
    $actualDigest = (Get-FileHash -Path $AssetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualDigest -ne $digestMatch.Groups[1].Value.ToLowerInvariant()) {
        throw "Release asset digest mismatch: $AssetName"
    }
}

function Assert-ReusableWorkflowContract {
    param(
        [string]$CallerPath,
        [string]$ValidatorPath
    )

    Assert-PathExists -Path $CallerPath -Message "Released caller missing: $CallerPath"
    $callerContent = Get-Content $CallerPath -Raw
    $match = [regex]::Match(
        $callerContent,
        '(?m)^\s*uses:\s+(?<repo>[^/\s]+/[^/\s]+)/(?<path>\.github/workflows/[^@\s]+)@(?<ref>[^\s#]+)'
    )
    if (-not $match.Success) {
        throw "Unable to resolve reusable callable from actual caller: $CallerPath"
    }

    $callableRepo = $match.Groups['repo'].Value
    if ($callableRepo -match '^(YOUR-ORG|YOUR_ORG)/') {
        $callableRepo = $BaseCoatRepo
    }
    $callablePath = $match.Groups['path'].Value
    $callableRef = $match.Groups['ref'].Value
    if ($CallableRefOverride) {
        Write-Host "Validating the released caller against remote candidate callable ref $CallableRefOverride"
        $callableRef = $CallableRefOverride
    }
    $downloadedCallable = Join-Path $tempRepo (Split-Path $callablePath -Leaf)
    gh api -H 'Accept: application/vnd.github.raw+json' `
        "repos/$callableRepo/contents/$callablePath`?ref=$callableRef" |
        Set-Content -Path $downloadedCallable -Encoding utf8
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to fetch actual callable $callableRepo/$callablePath@$callableRef"
    }

    & python $ValidatorPath $downloadedCallable $CallerPath
    if ($LASTEXITCODE -ne 0) {
        throw "Released caller/callable contract validation failed for $CallerPath"
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
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null

    if ($ArtifactSource -eq 'Release') {
        $env:GH_PAGER = 'cat'
        $packageVersion = $Version.TrimStart('v')
        $assetName = "base-coat-$packageVersion.tar.gz"
        $zipAssetName = "base-coat-$packageVersion.zip"
        $sourceAssetName = "basecoat-$Version.zip"
        gh release download $Version --repo $BaseCoatRepo `
            --pattern $assetName `
            --pattern $zipAssetName `
            --pattern $sourceAssetName `
            --pattern 'SHA256SUMS.txt' `
            --dir $downloadDir
        $archivePath = Join-Path $downloadDir $assetName
        Assert-PathExists -Path $archivePath -Message "Release archive not downloaded: $assetName"
        Assert-Checksum -ChecksumFile (Join-Path $downloadDir 'SHA256SUMS.txt') -Directory $downloadDir
        Assert-ReleaseAssetDigest -AssetName $assetName -AssetPath $archivePath
        tar -xzf $archivePath -C $tempRepo
        Remove-Item $installPath -Recurse -Force
        Move-Item -Path (Join-Path $tempRepo 'base-coat') -Destination $installPath

        $sourceArchivePath = Join-Path $downloadDir $sourceAssetName
        Assert-PathExists -Path $sourceArchivePath -Message "Release source archive not downloaded: $sourceAssetName"
        Assert-ReleaseAssetDigest -AssetName $sourceAssetName -AssetPath $sourceArchivePath
        $sourceExtractPath = Join-Path $tempRepo '.basecoat-release-source'
        Expand-Archive -Path $sourceArchivePath -DestinationPath $sourceExtractPath
        foreach ($sourcePath in @(
                'templates/intake/PULL_REQUEST_TEMPLATE.md',
                'templates/intake/issue.md'
            )) {
            Assert-PathExists `
                -Path (Join-Path $sourceExtractPath $sourcePath) `
                -Message "Released source baseline missing: $sourcePath"
        }
    }
    else {
        & (Join-Path $repoRoot 'scripts/package-basecoat.ps1') $repoRoot
        $packageVersion = (Get-Content (Join-Path $repoRoot 'version.json') -Raw | ConvertFrom-Json).version
        $distDir = Join-Path $repoRoot 'dist'
        $archivePath = Join-Path $distDir "base-coat-$packageVersion.tar.gz"
        Assert-Checksum -ChecksumFile (Join-Path $distDir 'SHA256SUMS.txt') -Directory $distDir
        tar -xzf $archivePath -C $tempRepo
        Remove-Item $installPath -Recurse -Force
        Move-Item -Path (Join-Path $tempRepo 'base-coat') -Destination $installPath
    }
    Set-Location $tempRepo

    $requiredPaths = @(
        '.github/base-coat/instructions',
        '.github/base-coat/skills',
        '.github/base-coat/prompts',
        '.github/base-coat/agents',
        '.github/base-coat/version.json'
    )
    if ($ArtifactSource -eq 'Current') {
        $requiredPaths += @(
            '.github/base-coat/workflows',
            '.github/base-coat/templates/intake/PULL_REQUEST_TEMPLATE.md',
            '.github/base-coat/templates/intake/issue.md',
            '.github/base-coat/scripts/validate-basecoat.ps1',
            '.github/base-coat/scripts/validate-basecoat.sh',
            '.github/base-coat/scripts/validate-workflow-action-pins.ps1',
            '.github/base-coat/scripts/validate-workflow-action-pins.py',
            '.github/base-coat/scripts/validate-reusable-workflow-contracts.py'
        )
    }
    else {
        $requiredPaths += '.github/base-coat/.github/base-coat/workflows'
    }
    foreach ($path in $requiredPaths) {
        Assert-PathExists -Path $path -Message "Installed baseline missing: $path"
    }

    if ($ArtifactSource -eq 'Current') {
        Assert-ReusableWorkflowContract `
            -CallerPath (Join-Path $installPath '.github/workflow-templates/check-basecoat-version.yml') `
            -ValidatorPath (Join-Path $installPath 'scripts/validate-reusable-workflow-contracts.py')
    }
    else {
        Assert-ReusableWorkflowContract `
            -CallerPath (Join-Path $sourceExtractPath '.github/workflow-templates/check-basecoat-version.yml') `
            -ValidatorPath (Join-Path $repoRoot 'scripts/validate-reusable-workflow-contracts.py')
    }

    if ($ArtifactSource -eq 'Current') {
        & '.\.github\base-coat\scripts\validate-basecoat.ps1' '.\.github\base-coat'
    }
    else {
        & $bashCommand '.github/base-coat/scripts/validate-basecoat.sh' '.github/base-coat'
        if ($LASTEXITCODE -ne 0) {
            throw "Released Bash validator failed with exit code $LASTEXITCODE"
        }
    }

    if ($ArtifactSource -eq 'Current') {
        Set-Location $tempRepo
        $invalidWorkflow = Join-Path $installPath 'workflows/consumer-smoke-unpinned.yml'
        Set-Content -Path $invalidWorkflow -Value "jobs:`n  validate:`n    steps:`n      - uses: actions/checkout@v4"
        $rejected = $false
        try {
            & '.\.github\base-coat\scripts\validate-basecoat.ps1' '.\.github\base-coat'
        }
        catch {
            $rejected = $true
        }
        finally {
            Remove-Item $invalidWorkflow -Force
        }
        if (-not $rejected) {
            throw 'Installed payload validation did not reject an unpinned consumer workflow action.'
        }
    }

    Write-Host "$ArtifactSource consumer smoke test passed in $tempRepo"
}
finally {
    Pop-Location
    if (-not $KeepRepo -and (Test-Path $tempRepo)) {
        Remove-Item -Path $tempRepo -Recurse -Force
    }
}
