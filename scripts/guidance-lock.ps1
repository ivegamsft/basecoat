Set-StrictMode -Version Latest

$script:GuidanceLockSchema = 'guidance-lock/v1'
$script:GuidanceSharedPrefixes = @(
    '.github/skills/',
    '.github/agents/',
    '.github/instructions/',
    '.github/prompts/',
    '.agents/skills/'
)

function Get-GuidanceLockPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    return Join-Path $RepoRoot '.github/base-coat/guidance-lock.json'
}

function Normalize-GuidancePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $normalized = ($Path.Trim() -replace '\\', '/') -replace '/+', '/'
    while ($normalized.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }

    if (-not $normalized -or
        $normalized.EndsWith('/', [System.StringComparison]::Ordinal) -or
        [System.IO.Path]::IsPathRooted($normalized) -or
        $normalized -match '(^|/)\.\.?(/|$)' -or
        $normalized -notmatch '^[A-Za-z0-9._/+@()-]+$') {
        throw "GUIDANCE_LOCK_INVALID path='$Path' reason='path must be a normalized repository-relative file path'"
    }

    $allowed = $false
    foreach ($prefix in $script:GuidanceSharedPrefixes) {
        if ($normalized.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        throw "GUIDANCE_LOCK_INVALID path='$Path' reason='path is outside the shared guidance destinations'"
    }

    $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootFull $normalized))
    $comparison = if ($IsWindows) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    if (-not $candidate.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw "GUIDANCE_LOCK_INVALID path='$Path' reason='path escapes the repository root'"
    }

    return $normalized
}

function Enter-GuidanceLockLease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [int]$TimeoutSeconds = 30
    )

    $leasePath = Join-Path $RepoRoot '.github/base-coat/guidance-lock.lease'
    New-Item -ItemType Directory -Path (Split-Path -Parent $leasePath) -Force | Out-Null
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        try {
            New-Item -ItemType Directory -Path $leasePath -ErrorAction Stop | Out-Null
            [System.IO.File]::WriteAllText(
                (Join-Path $leasePath 'owner'),
                "pid=$PID`nacquired=$([DateTime]::UtcNow.ToString('o'))`n",
                [System.Text.UTF8Encoding]::new($false)
            )
            return $leasePath
        }
        catch {
            if ([DateTime]::UtcNow -ge $deadline) {
                throw "GUIDANCE_LOCK_BUSY lease='$leasePath' timeoutSeconds='$TimeoutSeconds'"
            }
            Start-Sleep -Milliseconds 100
        }
    } while ($true)
}

function Exit-GuidanceLockLease {
    [CmdletBinding()]
    param([AllowNull()][string]$LeasePath)

    if ($LeasePath) {
        Remove-Item -LiteralPath $LeasePath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-GuidanceContentHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "GUIDANCE_LOCK_INVALID path='$Path' reason='content hash requires an existing file'"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-GuidanceOptionalProperty {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return [string]$property.Value
}

function New-GuidanceLockEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Owner,
        [Parameter(Mandatory)][string]$Sha256,
        [string]$GuidanceUnit,
        [string]$SourceVersion,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $normalizedPath = Normalize-GuidancePath -Path $Path -RepoRoot $RepoRoot
    if ($Owner -notmatch '^[a-z0-9][a-z0-9._-]*$') {
        throw "GUIDANCE_LOCK_INVALID path='$normalizedPath' reason='owner must match ^[a-z0-9][a-z0-9._-]*$'"
    }
    $hash = $Sha256.ToLowerInvariant()
    if ($hash -notmatch '^[a-f0-9]{64}$') {
        throw "GUIDANCE_LOCK_INVALID path='$normalizedPath' reason='sha256 must be 64 lowercase hexadecimal characters'"
    }
    foreach ($optionalValue in @($GuidanceUnit, $SourceVersion)) {
        if ($optionalValue -and $optionalValue -notmatch '^[A-Za-z0-9][A-Za-z0-9._/+:-]{0,511}$') {
            throw "GUIDANCE_LOCK_INVALID path='$normalizedPath' reason='optional metadata must use the portable [A-Za-z0-9._/+:-] vocabulary'"
        }
    }

    $entry = [ordered]@{
        path = $normalizedPath
        owner = $Owner
    }
    if ($GuidanceUnit) { $entry.guidanceUnit = $GuidanceUnit }
    if ($SourceVersion) { $entry.sourceVersion = $SourceVersion }
    $entry.sha256 = $hash
    return [pscustomobject]$entry
}

function Read-GuidanceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$LockPath = (Get-GuidanceLockPath -RepoRoot $RepoRoot)
    )

    if (Test-Path -LiteralPath $LockPath) {
        $lockItem = Get-Item -LiteralPath $LockPath -Force
        if ($lockItem.PSIsContainer -or $null -ne $lockItem.ResolveLinkTarget($false) -or
            -not (Test-Path -LiteralPath $LockPath -PathType Leaf)) {
            throw "GUIDANCE_LOCK_INVALID file='$LockPath' reason='lock path must be a regular file'"
        }
    }
    else {
        return [pscustomobject]@{
            schema = $script:GuidanceLockSchema
            entries = @()
        }
    }

    try {
        $lock = Get-Content -LiteralPath $LockPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "GUIDANCE_LOCK_INVALID file='$LockPath' reason='malformed JSON: $($_.Exception.Message)'"
    }
    if ($lock.schema -ne $script:GuidanceLockSchema -or $null -eq $lock.entries) {
        throw "GUIDANCE_LOCK_INVALID file='$LockPath' reason='expected schema guidance-lock/v1 and an entries array'"
    }

    $validated = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in @($lock.entries)) {
        $allowedProperties = @('path', 'owner', 'guidanceUnit', 'sourceVersion', 'sha256')
        $unknownProperties = @($entry.PSObject.Properties.Name | Where-Object { $_ -notin $allowedProperties })
        if ($unknownProperties.Count -gt 0) {
            throw "GUIDANCE_LOCK_INVALID file='$LockPath' reason='unknown entry properties: $($unknownProperties -join ', ')'"
        }
        if (-not $entry.path -or -not $entry.owner -or -not $entry.sha256) {
            throw "GUIDANCE_LOCK_INVALID file='$LockPath' reason='every entry requires path, owner, and sha256'"
        }
        $normalized = Normalize-GuidancePath -Path ([string]$entry.path) -RepoRoot $RepoRoot
        if ($normalized -cne [string]$entry.path) {
            throw "GUIDANCE_LOCK_INVALID path='$($entry.path)' reason='stored paths must already be normalized'"
        }
        if (-not $seen.Add($normalized)) {
            throw "GUIDANCE_LOCK_INVALID path='$normalized' reason='duplicate path entry'"
        }
        $validated.Add((New-GuidanceLockEntry `
            -Path $normalized `
            -Owner ([string]$entry.owner) `
            -Sha256 ([string]$entry.sha256) `
            -GuidanceUnit (Get-GuidanceOptionalProperty -InputObject $entry -Name 'guidanceUnit') `
            -SourceVersion (Get-GuidanceOptionalProperty -InputObject $entry -Name 'sourceVersion') `
            -RepoRoot $RepoRoot))
    }

    return [pscustomobject]@{
        schema = $script:GuidanceLockSchema
        entries = @($validated | Sort-Object -Property path)
    }
}

function Write-GuidanceLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Entries,
        [string]$LockPath = (Get-GuidanceLockPath -RepoRoot $RepoRoot)
    )

    $validated = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $Entries) {
        $item = New-GuidanceLockEntry `
            -Path ([string]$entry.path) `
            -Owner ([string]$entry.owner) `
            -Sha256 ([string]$entry.sha256) `
            -GuidanceUnit (Get-GuidanceOptionalProperty -InputObject $entry -Name 'guidanceUnit') `
            -SourceVersion (Get-GuidanceOptionalProperty -InputObject $entry -Name 'sourceVersion') `
            -RepoRoot $RepoRoot
        if (-not $seen.Add($item.path)) {
            throw "GUIDANCE_LOCK_INVALID path='$($item.path)' reason='duplicate path entry'"
        }
        $validated.Add($item)
    }

    $payload = [ordered]@{
        schema = $script:GuidanceLockSchema
        entries = @($validated | Sort-Object -Property path)
    }
    $parent = Split-Path -Parent $LockPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $temporaryPath = "$LockPath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $json = $payload | ConvertTo-Json -Depth 6
        [System.IO.File]::WriteAllText(
            $temporaryPath,
            $json + "`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        [System.IO.File]::Move($temporaryPath, $LockPath, $true)
    }
    finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
}
