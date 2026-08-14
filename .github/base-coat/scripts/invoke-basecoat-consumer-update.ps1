#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [string]$StagePath = '.github/base-coat',
    [string]$Mode = '',
    [string]$Approval = '',
    [string]$Source = '',
    [string]$Ref = '',
    [string]$Mirror = '',
    [string]$Channel = '',
    [string]$AllowedBumps = '',
    [string]$StatusPath = 'basecoat-update-status.json',
    [string]$ReleaseJson = '',
    [switch]$PlanOnly,
    [switch]$LibraryOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:IssueMarkerPrefix = '<!-- basecoat-consumer-update:'
$script:PrMarker = '<!-- basecoat-consumer-update-pr:v1 -->'

function Get-ConfigLines {
    param([string]$RepoRoot)

    $path = Join-Path $RepoRoot '.basecoat.yml'
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    return @(Get-Content -LiteralPath $path)
}

function Remove-YamlComment {
    param([string]$Value)

    $trimmed = $Value.Trim()
    if ($trimmed -match '^(?<quote>["''])(?<value>.*)\k<quote>\s*(?:#.*)?$') {
        return $Matches['value']
    }
    return ($trimmed -replace '\s+#.*$', '').Trim()
}

function Get-YamlScalar {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Section = ''
    )

    $inSection = [string]::IsNullOrWhiteSpace($Section)
    foreach ($line in $Lines) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            $topKey = $Matches[1]
            $topValue = $Matches[2]
            if ($Section) {
                $inSection = $topKey -eq $Section
                continue
            }
            if ($topKey -eq $Key) { return Remove-YamlComment $topValue }
        }
        elseif ($Section -and $inSection -and $line -match '^\s{2,}([A-Za-z0-9_-]+):\s*(.*)$') {
            if ($Matches[1] -eq $Key) { return Remove-YamlComment $Matches[2] }
        }
    }
    return $null
}

function Get-YamlList {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Section = ''
    )

    $value = Get-YamlScalar -Lines $Lines -Key $Key -Section $Section
    if ($value -match '^\[(.*)\]$') {
        return @($Matches[1].Split(',') | ForEach-Object { (Remove-YamlComment $_).Trim() } | Where-Object { $_ })
    }

    $items = [System.Collections.Generic.List[string]]::new()
    $inSection = [string]::IsNullOrWhiteSpace($Section)
    $inList = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            if ($Section) {
                $inSection = $Matches[1] -eq $Section
            }
            $inList = $false
            continue
        }
        if ($inSection -and $line -match '^\s{2,}([A-Za-z0-9_-]+):\s*$') {
            $inList = $Matches[1] -eq $Key
            continue
        }
        if ($inList -and $line -match '^\s{4,}-\s*(.+)$') {
            $items.Add((Remove-YamlComment $Matches[1]))
            continue
        }
        if ($inList -and $line -match '^\s{0,3}\S') { break }
    }
    return @($items)
}

function Test-YamlKeyPresent {
    param(
        [string[]]$Lines,
        [string]$Key,
        [string]$Section = ''
    )

    $inSection = [string]::IsNullOrWhiteSpace($Section)
    foreach ($line in $Lines) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z0-9_-]+):') {
            if ($Section) {
                $inSection = $Matches[1] -eq $Section
                continue
            }
            if ($Matches[1] -eq $Key) { return $true }
        }
        elseif ($Section -and $inSection -and $line -match '^\s{2,}([A-Za-z0-9_-]+):') {
            if ($Matches[1] -eq $Key) { return $true }
        }
    }
    return $false
}

function Get-YamlMap {
    param(
        [string[]]$Lines,
        [string]$Section
    )

    $result = @{}
    $inSection = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z0-9_-]+):\s*$') {
            $inSection = $Matches[1] -eq $Section
            continue
        }
        if ($inSection -and $line -match '^\s{2,}([^:]+):\s*(.+)$') {
            $mapKey = (Remove-YamlComment $Matches[1]).Trim()
            $mapValue = Remove-YamlComment $Matches[2]
            $result[$mapKey] = $mapValue
            continue
        }
        if ($inSection -and $line -match '^\S') { break }
    }
    return $result
}

function ConvertTo-SemVer {
    param([Parameter(Mandatory)][string]$Value)

    $normalized = $Value.Trim() -replace '^v', ''
    $prereleaseIdentifier = '(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)'
    $pattern = "^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-($prereleaseIdentifier(?:\.$prereleaseIdentifier)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
    if ($normalized -notmatch $pattern) {
        throw "Invalid semantic version '$Value'. Expected vMAJOR.MINOR.PATCH."
    }
    $prerelease = $Matches[4]
    $buildMetadata = $Matches[5]
    $text = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
    if ($prerelease) { $text += "-$prerelease" }
    if ($buildMetadata) { $text += "+$buildMetadata" }
    return [pscustomobject]@{
        Text = $text
        Major = [System.Numerics.BigInteger]::Parse($Matches[1])
        Minor = [System.Numerics.BigInteger]::Parse($Matches[2])
        Patch = [System.Numerics.BigInteger]::Parse($Matches[3])
        Prerelease = $prerelease
        BuildMetadata = $buildMetadata
    }
}

function Get-CompletedElapsedDays {
    param(
        [Parameter(Mandatory)][datetime]$Start,
        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    $elapsedDays = ($Now.ToUniversalTime() - $Start.ToUniversalTime()).TotalDays
    return [math]::Max(0, [int][math]::Floor($elapsedDays))
}

function Get-RunSuffix {
    param(
        [string]$RunId = $env:GITHUB_RUN_ID,
        [string]$RunAttempt = $env:GITHUB_RUN_ATTEMPT,
        [datetime]$Now = (Get-Date)
    )

    if ($RunId) {
        return $(if ($RunAttempt) { "$RunId-attempt-$RunAttempt" } else { $RunId })
    }
    return $Now.ToString('yyyyMMddHHmmss')
}

function Test-ExpectedWorktreeMapping {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$PorcelainLines,
        [Parameter(Mandatory)][string]$WorktreePath,
        [Parameter(Mandatory)][string]$Branch
    )

    $expectedPath = [System.IO.Path]::GetFullPath($WorktreePath).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $currentPath = ''
    $currentBranch = ''
    foreach ($line in @($PorcelainLines) + 'worktree __sentinel__') {
        if ($line -match '^worktree\s+(.+)$') {
            if ($currentPath -and $currentBranch -eq "refs/heads/$Branch") {
                $mappedPath = [System.IO.Path]::GetFullPath($currentPath).TrimEnd(
                    [System.IO.Path]::DirectorySeparatorChar,
                    [System.IO.Path]::AltDirectorySeparatorChar
                )
                if ($mappedPath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $true
                }
            }
            $currentPath = $Matches[1]
            $currentBranch = ''
        }
        elseif ($line -match '^branch\s+(.+)$') {
            $currentBranch = $Matches[1]
        }
    }
    return $false
}

function Get-WorktreePathForBranch {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$PorcelainLines,
        [Parameter(Mandatory)][string]$Branch,
        [Parameter(Mandatory)][string]$ExcludePath
    )

    $excludeFull = [System.IO.Path]::GetFullPath($ExcludePath).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $currentPath = ''
    $currentBranch = ''
    foreach ($line in @($PorcelainLines) + 'worktree __sentinel__') {
        if ($line -match '^worktree\s+(.+)$') {
            if ($currentPath -and $currentBranch -eq "refs/heads/$Branch") {
                $mappedPath = [System.IO.Path]::GetFullPath($currentPath).TrimEnd(
                    [System.IO.Path]::DirectorySeparatorChar,
                    [System.IO.Path]::AltDirectorySeparatorChar
                )
                if (-not $mappedPath.Equals($excludeFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $currentPath
                }
            }
            $currentPath = $Matches[1]
            $currentBranch = ''
        }
        elseif ($line -match '^branch\s+(.+)$') {
            $currentBranch = $Matches[1]
        }
    }
    return ''
}

function Compare-SemVer {
    param($Current, $Target)

    foreach ($part in @('Major', 'Minor', 'Patch')) {
        if ($Current.$part -lt $Target.$part) { return -1 }
        if ($Current.$part -gt $Target.$part) { return 1 }
    }
    if (-not $Current.Prerelease -and $Target.Prerelease) { return 1 }
    if ($Current.Prerelease -and -not $Target.Prerelease) { return -1 }
    if ($Current.Prerelease -or $Target.Prerelease) {
        $currentParts = @([string]$Current.Prerelease -split '\.')
        $targetParts = @([string]$Target.Prerelease -split '\.')
        $length = [math]::Max($currentParts.Count, $targetParts.Count)
        for ($index = 0; $index -lt $length; $index++) {
            if ($index -ge $currentParts.Count) { return -1 }
            if ($index -ge $targetParts.Count) { return 1 }
            $currentNumeric = $currentParts[$index] -match '^\d+$'
            $targetNumeric = $targetParts[$index] -match '^\d+$'
            if ($currentNumeric -and $targetNumeric) {
                $currentNumber = $currentParts[$index].TrimStart('0')
                $targetNumber = $targetParts[$index].TrimStart('0')
                if (-not $currentNumber) { $currentNumber = '0' }
                if (-not $targetNumber) { $targetNumber = '0' }
                if ($currentNumber.Length -lt $targetNumber.Length) { return -1 }
                if ($currentNumber.Length -gt $targetNumber.Length) { return 1 }
                $comparison = [string]::CompareOrdinal($currentNumber, $targetNumber)
                if ($comparison -lt 0) { return -1 }
                if ($comparison -gt 0) { return 1 }
            }
            elseif ($currentNumeric -ne $targetNumeric) {
                return $(if ($currentNumeric) { -1 } else { 1 })
            }
            else {
                $comparison = [string]::CompareOrdinal($currentParts[$index], $targetParts[$index])
                if ($comparison -lt 0) { return -1 }
                if ($comparison -gt 0) { return 1 }
            }
        }
    }
    return 0
}

function Get-SemVerBump {
    param($Current, $Target)

    if ((Compare-SemVer -Current $Current -Target $Target) -ge 0) { return 'none' }
    if ($Target.Major -gt $Current.Major) { return 'major' }
    if ($Target.Minor -gt $Current.Minor) { return 'minor' }
    if ($Target.Patch -gt $Current.Patch) { return 'patch' }
    if ($Current.Prerelease -and -not $Target.Prerelease) { return 'patch' }
    return 'none'
}

function Normalize-RepoSlug {
    param([string]$Value)

    if (-not $Value) { return $null }
    $slug = (Protect-SensitiveText $Value).Trim() -replace '\.git$', ''
    if ($slug -match '^https?://([^/]+)/([^/]+/[^/]+)$') {
        return $(if ($Matches[1] -eq 'github.com') { $Matches[2] } else { "$($Matches[1])/$($Matches[2])" })
    }
    if ($slug -match '^[^@]+@([^:]+):([^/]+/[^/]+)$') {
        return $(if ($Matches[1] -eq 'github.com') { $Matches[2] } else { "$($Matches[1])/$($Matches[2])" })
    }
    if ($slug -match '^[^/]+/[^/]+$') { return $slug }
    if ($slug -match '^[^/]+/[^/]+/[^/]+$') { return $slug }
    return $null
}

function Convert-RepoToCloneUrl {
    param([string]$Value)

    if ($Value -match '^[^/]+/[^/]+$') { return "https://github.com/$Value.git" }
    if ($Value -match '^([^/]+)/([^/]+/[^/]+)$') { return "https://$($Matches[1])/$($Matches[2]).git" }
    return $Value
}

function Protect-SensitiveText {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $null }
    $text = [string]$Value
    $text = $text -replace '(?i)(https?://)[^/@\s]+@', '$1'
    $text = $text -replace '(?i)(https?://[^\s?#]+)[?#][^\s]*', '$1'
    $text = $text -replace '(?i)(AUTHORIZATION:\s*basic\s+)\S+', '${1}***'
    foreach ($secret in @(
            $env:BASECOAT_UPDATE_TOKEN,
            $env:BASECOAT_FETCH_TOKEN,
            $env:BASECOAT_MIRROR_FETCH_TOKEN,
            $env:GH_TOKEN,
            $env:GITHUB_TOKEN
        )) {
        if ($secret) { $text = $text.Replace($secret, '***') }
    }
    return $text
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $Command @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $safeArguments = @($Arguments | ForEach-Object { Protect-SensitiveText $_ })
    $safeOutput = @($output | ForEach-Object { Protect-SensitiveText $_ })
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "$Command $($safeArguments -join ' ') failed (exit $exitCode): $($safeOutput -join "`n")"
    }
    return [pscustomobject]@{ Output = $safeOutput; ExitCode = $exitCode }
}

function Invoke-ConsumerGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $originResult = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'remote', 'get-url', 'origin')
    $origin = [string]($originResult.Output | Select-Object -First 1)
    $uri = $null
    $prefix = @('-C', $RepoRoot)
    if ([uri]::TryCreate($origin, [System.UriKind]::Absolute, [ref]$uri)) {
        if ($uri.Scheme -eq 'file') {
            return Invoke-Native -Command 'git' -Arguments ($prefix + $Arguments) -AllowFailure:$AllowFailure
        }
        if ($uri.Scheme -ne 'https') {
            throw "Consumer origin must use HTTPS for scoped updater authentication: '$(Protect-SensitiveText $origin)'."
        }
        $expectedRepo = [string]$env:GITHUB_REPOSITORY
        $originRepo = $uri.AbsolutePath.Trim('/').TrimEnd('/') -replace '\.git$', ''
        if ($expectedRepo -and -not $originRepo.Equals($expectedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Consumer origin '$originRepo' does not match GITHUB_REPOSITORY '$expectedRepo'."
        }
        $token = if ($env:BASECOAT_UPDATE_TOKEN) { $env:BASECOAT_UPDATE_TOKEN } else { $env:GH_TOKEN }
        if ($token) {
            $authBytes = [Text.Encoding]::ASCII.GetBytes("x-access-token:$token")
            $authHeader = [Convert]::ToBase64String($authBytes)
            $authUrl = "$($uri.Scheme)://$($uri.Authority)$($uri.AbsolutePath)"
            $prefix += @('-c', "http.$authUrl.extraheader=AUTHORIZATION: basic $authHeader")
        }
    }
    return Invoke-Native -Command 'git' -Arguments ($prefix + $Arguments) -AllowFailure:$AllowFailure
}

function Invoke-GitRemoteWithAuthRetry {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Source,
        [ValidateSet('canonical', 'mirror')][string]$CredentialKind = 'canonical',
        [switch]$AllowFailure
    )

    $result = Invoke-Native -Command 'git' -Arguments $Arguments -AllowFailure
    if ($result.ExitCode -eq 0) { return $result }

    $uri = $null
    $hasAbsoluteUri = [uri]::TryCreate($Source, [System.UriKind]::Absolute, [ref]$uri)
    $token = if ($CredentialKind -eq 'mirror') { $env:BASECOAT_MIRROR_FETCH_TOKEN } else { $env:BASECOAT_FETCH_TOKEN }
    $trustedAuthority = if ($CredentialKind -eq 'mirror') { $env:BASECOAT_MIRROR_FETCH_HOST } else { $env:BASECOAT_FETCH_HOST }
    if (
        $CredentialKind -eq 'mirror' -and
        (-not $token -or -not $trustedAuthority) -and
        $hasAbsoluteUri -and
        $env:BASECOAT_FETCH_TOKEN -and
        $uri.Authority.Equals($env:BASECOAT_FETCH_HOST, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        $token = $env:BASECOAT_FETCH_TOKEN
        $trustedAuthority = $env:BASECOAT_FETCH_HOST
    }
    if (
        -not $token -or
        -not $trustedAuthority -or
        -not $hasAbsoluteUri -or
        $uri.Scheme -ne 'https' -or
        -not $uri.Authority.Equals($trustedAuthority, [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        if ($AllowFailure) { return $result }
        throw "git $(Protect-SensitiveText ($Arguments -join ' ')) failed: $($result.Output -join "`n")"
    }

    $authBytes = [Text.Encoding]::ASCII.GetBytes("x-access-token:$token")
    $authHeader = [Convert]::ToBase64String($authBytes)
    $authOrigin = "$($uri.Scheme)://$($uri.Authority)/"
    $authenticatedArguments = @(
        '-c', "http.$authOrigin.extraheader=AUTHORIZATION: basic $authHeader"
    ) + $Arguments
    return Invoke-Native -Command 'git' -Arguments $authenticatedArguments -AllowFailure:$AllowFailure
}

function Resolve-TagSha {
    param(
        [Parameter(Mandatory)][string]$FetchSource,
        [Parameter(Mandatory)][string]$Tag,
        [ValidateSet('canonical', 'mirror')][string]$CredentialKind = 'canonical'
    )

    $peeled = Invoke-GitRemoteWithAuthRetry -Arguments @(
        'ls-remote', $FetchSource, "refs/tags/$Tag^{}"
    ) -Source $FetchSource -CredentialKind $CredentialKind -AllowFailure
    if ($peeled.ExitCode -eq 0 -and $peeled.Output.Count -gt 0) {
        return (($peeled.Output[0] -split '\s+')[0]).Trim()
    }
    $direct = Invoke-GitRemoteWithAuthRetry -Arguments @(
        'ls-remote', $FetchSource, "refs/tags/$Tag"
    ) -Source $FetchSource -CredentialKind $CredentialKind -AllowFailure
    if ($direct.ExitCode -ne 0) {
        throw "Unable to resolve immutable SHA for tag '$Tag' from '$(Protect-SensitiveText $FetchSource)'."
    }
    if ($direct.Output.Count -eq 0) {
        throw "Unable to resolve immutable SHA for tag '$Tag' from '$(Protect-SensitiveText $FetchSource)'."
    }
    return (($direct.Output[0] -split '\s+')[0]).Trim()
}

function Invoke-ReleaseLookup {
    param(
        [Parameter(Mandatory)][string]$CanonicalSource,
        [Parameter(Mandatory)][string]$RequestedRef,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $cloneUrl = Convert-RepoToCloneUrl $CanonicalSource
    $uri = $null
    $hasAbsoluteUri = [uri]::TryCreate($cloneUrl, [System.UriKind]::Absolute, [ref]$uri)
    $useFetchCredential = (
        $env:BASECOAT_FETCH_TOKEN -and
        $env:BASECOAT_FETCH_HOST -and
        $hasAbsoluteUri -and
        $uri.Scheme -eq 'https' -and
        $uri.Authority.Equals($env:BASECOAT_FETCH_HOST, [System.StringComparison]::OrdinalIgnoreCase)
    )
    if (-not $useFetchCredential) {
        if (-not $uri -or $uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com') {
            throw "Release lookup for '$(Protect-SensitiveText $CanonicalSource)' requires BASECOAT_FETCH_TOKEN and matching BASECOAT_FETCH_HOST."
        }
        $slug = (Normalize-RepoSlug $CanonicalSource) -replace '^github\.com/', ''
        $encodedSlug = (($slug -split '/', 2) | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
        $endpoint = if ($RequestedRef -in @('latest', 'stable')) {
            "https://api.github.com/repos/$encodedSlug/releases/latest"
        }
        else {
            "https://api.github.com/repos/$encodedSlug/releases/tags/$([uri]::EscapeDataString($RequestedRef))"
        }
        try {
            $publicRelease = Invoke-RestMethod -Uri $endpoint -Headers @{
                Accept = 'application/vnd.github+json'
                'User-Agent' = 'basecoat-consumer-updater'
                'X-GitHub-Api-Version' = '2022-11-28'
            }
            $payload = [ordered]@{
                tagName = [string]$publicRelease.tag_name
                url = [string]$publicRelease.html_url
                publishedAt = [string]$publicRelease.published_at
                isDraft = [bool]$(if ($publicRelease.PSObject.Properties['draft']) { $publicRelease.draft } else { $false })
                isPrerelease = [bool]$(if ($publicRelease.PSObject.Properties['prerelease']) { $publicRelease.prerelease } else { $false })
            } | ConvertTo-Json -Compress
            return [pscustomobject]@{ ExitCode = 0; Output = @($payload) }
        }
        catch {
            throw "Unauthenticated public release lookup failed for '$(Protect-SensitiveText $CanonicalSource)'. Configure an authority-bound BASECOAT_FETCH_TOKEN for private sources."
        }
    }

    $oldGhToken = $env:GH_TOKEN
    $oldEnterpriseToken = $env:GH_ENTERPRISE_TOKEN
    $oldGhHost = $env:GH_HOST
    try {
        if ($uri.Host -eq 'github.com') {
            $env:GH_TOKEN = $env:BASECOAT_FETCH_TOKEN
        }
        else {
            $env:GH_ENTERPRISE_TOKEN = $env:BASECOAT_FETCH_TOKEN
            $env:GH_HOST = $uri.Authority
        }
        return Invoke-Native -Command 'gh' -Arguments $Arguments
    }
    finally {
        $env:GH_TOKEN = $oldGhToken
        $env:GH_ENTERPRISE_TOKEN = $oldEnterpriseToken
        $env:GH_HOST = $oldGhHost
    }
}

function Resolve-Release {
    param(
        [Parameter(Mandatory)][string]$CanonicalSource,
        [Parameter(Mandatory)][string]$FetchSource,
        [Parameter(Mandatory)][string]$RequestedRef,
        [AllowEmptyString()][string]$ReleaseOverrideJson,
        [switch]$VerifyProvenance
    )

    if ($ReleaseOverrideJson) {
        $release = $ReleaseOverrideJson | ConvertFrom-Json
        $tag = [string]$release.tag
        $expectedSha = [string]$release.sha
        $null = ConvertTo-SemVer $tag
        if ($expectedSha -notmatch '^[0-9a-fA-F]{40}$') {
            throw "Release metadata for '$tag' does not contain a valid immutable SHA."
        }
        if ($VerifyProvenance) {
            $canonicalFetch = Convert-RepoToCloneUrl $CanonicalSource
            $fetchCredentialKind = if ($FetchSource.Equals($canonicalFetch, [System.StringComparison]::OrdinalIgnoreCase)) {
                'canonical'
            }
            else {
                'mirror'
            }
            $canonicalSha = Resolve-TagSha -FetchSource $canonicalFetch -Tag $tag
            $fetchSha = Resolve-TagSha -FetchSource $FetchSource -Tag $tag -CredentialKind $fetchCredentialKind
            if ($canonicalSha -ne $fetchSha -or $canonicalSha -ne $expectedSha) {
                throw "Release provenance mismatch for tag '$tag': canonical '$canonicalSha', mirror '$fetchSha', and supplied '$expectedSha' must match."
            }
        }
        return [pscustomobject]@{
            Tag = $tag
            Sha = $expectedSha
            Url = [string]$release.url
            PublishedAt = [string]$release.published_at
            IsDraft = [bool]$(if ($release.PSObject.Properties['is_draft']) { $release.is_draft } elseif ($release.PSObject.Properties['isDraft']) { $release.isDraft } else { $false })
            IsPrerelease = [bool]$(if ($release.PSObject.Properties['is_prerelease']) { $release.is_prerelease } elseif ($release.PSObject.Properties['isPrerelease']) { $release.isPrerelease } else { $false })
        }
    }

    $slug = Normalize-RepoSlug $CanonicalSource
    if (-not $slug) {
        throw "Source '$(Protect-SensitiveText $CanonicalSource)' is not a GitHub owner/repo or github.com URL. Set updates.ref to a tag and provide release metadata through the corporate mirror workflow."
    }

    $refSelector = if ($RequestedRef) { $RequestedRef } else { 'latest' }
    $releaseArgs = @('release', 'view')
    if ($refSelector -notin @('latest', 'stable')) { $releaseArgs += $refSelector }
    $releaseArgs += @('--repo', $slug, '--json', 'tagName,url,publishedAt,isDraft,isPrerelease')
    $releaseResult = Invoke-ReleaseLookup -CanonicalSource $CanonicalSource -RequestedRef $refSelector -Arguments $releaseArgs
    $release = ($releaseResult.Output -join "`n") | ConvertFrom-Json
    $tag = [string]$release.tagName
    $null = ConvertTo-SemVer $tag
    $canonicalFetch = Convert-RepoToCloneUrl $CanonicalSource
    $fetchCredentialKind = if ($FetchSource.Equals($canonicalFetch, [System.StringComparison]::OrdinalIgnoreCase)) {
        'canonical'
    }
    else {
        'mirror'
    }
    $canonicalSha = Resolve-TagSha -FetchSource $canonicalFetch -Tag $tag
    $fetchSha = Resolve-TagSha -FetchSource $FetchSource -Tag $tag -CredentialKind $fetchCredentialKind
    if ($canonicalSha -ne $fetchSha) {
        throw "Release provenance mismatch: canonical and mirror tag '$tag' resolve to different commits."
    }
    return [pscustomobject]@{
        Tag = $tag
        Sha = $canonicalSha
        Url = [string]$release.url
        PublishedAt = [string]$release.publishedAt
        IsDraft = [bool]$(if ($release.PSObject.Properties['isDraft']) { $release.isDraft } else { $false })
        IsPrerelease = [bool]$(if ($release.PSObject.Properties['isPrerelease']) { $release.isPrerelease } else { $false })
    }
}

function Get-UpdatePolicy {
    param(
        [string[]]$Lines,
        [hashtable]$Overrides
    )

    $sourceValue = if ($Overrides['Source']) { $Overrides['Source'] } else {
        Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'source'
    }
    if (-not $sourceValue) { $sourceValue = Get-YamlScalar -Lines $Lines -Key 'source' }
    if (-not $sourceValue) { $sourceValue = 'IBuySpy-Shared/basecoat' }

    $mirrorValue = if ($Overrides['Mirror']) { $Overrides['Mirror'] } else {
        Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'mirror'
    }
    if (-not $mirrorValue) { $mirrorValue = Get-YamlScalar -Lines $Lines -Key 'mirror' }

    $allowedConfigured = [bool]$Overrides['AllowedBumps'] -or
        (Test-YamlKeyPresent -Lines $Lines -Section 'updates' -Key 'allowed_bumps')
    $allowed = @(
        if ($Overrides['AllowedBumps']) {
            $Overrides['AllowedBumps'].Split(',') |
                ForEach-Object { $_.Trim().ToLowerInvariant() } |
                Where-Object { $_ }
        }
        else {
            Get-YamlList -Lines $Lines -Section 'updates' -Key 'allowed_bumps'
        }
    )
    if (-not $allowedConfigured) { $allowed = @('patch', 'minor') }

    $policy = [ordered]@{
        Channel = if ($Overrides['Channel']) { $Overrides['Channel'] } else { Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'channel' }
        Mode = if ($Overrides['Mode']) { $Overrides['Mode'] } else { Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'mode' }
        Approval = if ($Overrides['Approval']) { $Overrides['Approval'] } else { Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'approval' }
        Source = $sourceValue
        Mirror = $mirrorValue
        Ref = if ($Overrides['Ref']) { $Overrides['Ref'] } else { Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'ref' }
        AllowedBumps = @($allowed)
        Validation = Get-YamlScalar -Lines $Lines -Section 'updates' -Key 'validation'
        KnownBad = Get-YamlMap -Lines $Lines -Section 'known_bad_releases'
    }
    if (-not $policy.Channel) { $policy.Channel = 'stable' }
    if (-not $policy.Mode) { $policy.Mode = 'notify' }
    if (-not $policy.Approval) { $policy.Approval = 'required' }
    if (-not $policy.Ref) { $policy.Ref = 'latest' }

    if ($policy.Mode -notin @('notify', 'pull-request')) { throw "Invalid updates.mode '$($policy.Mode)'." }
    if ($policy.Approval -notin @('required', 'automatic')) { throw "Invalid updates.approval '$($policy.Approval)'." }
    if ($policy.Channel -ne 'stable') { throw "Unsupported updates.channel '$($policy.Channel)'; only stable is fail-closed today." }
    foreach ($bump in $policy.AllowedBumps) {
        if ($bump -notin @('patch', 'minor', 'major')) { throw "Invalid allowed bump '$bump'." }
    }
    return [pscustomobject]$policy
}

function New-Status {
    param(
        [string]$CurrentVersion,
        [string]$TargetVersion,
        [string]$TargetTag,
        [string]$TargetSha,
        [string]$Source,
        [string]$Channel,
        [string]$Mode,
        [string]$Approval,
        [string]$Bump,
        [string]$Disposition,
        [int]$DriftAgeDays = 0,
        [string]$IssueUrl = '',
        [string]$PrUrl = '',
        [string]$ReleaseNotesUrl = '',
        [string]$DriftStartedAt = ''
    )

    return [ordered]@{
        schema_version = 1
        checked_at = (Get-Date).ToUniversalTime().ToString('o')
        current_version = $CurrentVersion
        target_version = $TargetVersion
        target_tag = $TargetTag
        target_sha = $TargetSha
        source = Protect-SensitiveText $Source
        channel = $Channel
        mode = $Mode
        approval = $Approval
        bump = $Bump
        drift_age_days = $DriftAgeDays
        drift_started_at = $DriftStartedAt
        issue_url = $IssueUrl
        pr_url = $PrUrl
        release_notes_url = $ReleaseNotesUrl
        disposition = $Disposition
    }
}

function ConvertTo-IssueMarker {
    param([System.Collections.IDictionary]$Status)

    $markerData = [ordered]@{
        schema = 1
        current_version = $Status.current_version
        target_version = $Status.target_version
        target_sha = $Status.target_sha
        disposition = $Status.disposition
        pr_url = $Status.pr_url
        drift_started_at = $Status.drift_started_at
    }
    return "$script:IssueMarkerPrefix$($markerData | ConvertTo-Json -Compress) -->"
}

function Get-ExistingIssue {
    $result = Invoke-Native -Command 'gh' -Arguments @(
        'issue', 'list', '--repo', $env:GITHUB_REPOSITORY, '--state', 'all', '--limit', '1000',
        '--search', 'basecoat-consumer-update: in:body',
        '--json', 'number,title,body,state,createdAt,url'
    )
    $issues = ($result.Output -join "`n") | ConvertFrom-Json
    $candidates = $issues | Where-Object { $_.body -and $_.body.Contains($script:IssueMarkerPrefix) } |
        Sort-Object -Property createdAt -Descending
    $repairCandidate = $candidates | Select-Object -First 1
    foreach ($issue in $candidates) {
        if ($issue.body -notmatch '<!-- basecoat-consumer-update:(\{[^\r\n]*\}) -->') { continue }
        try {
            $markerJson = $Matches[1]
            $marker = $markerJson | ConvertFrom-Json
            if (
                -not $marker -or
                -not $marker.PSObject.Properties['schema'] -or
                [int]$marker.schema -ne 1 -or
                -not $marker.PSObject.Properties['drift_started_at'] -or
                -not $marker.drift_started_at
            ) { continue }
            if ($markerJson -notmatch '"drift_started_at"\s*:\s*"([^"]+)"') { continue }
            $timestampText = $Matches[1]
            $parsedTimestamp = [datetimeoffset]::MinValue
            if (-not [datetimeoffset]::TryParse($timestampText, [ref]$parsedTimestamp)) { continue }
            $marker.PSObject.Properties.Remove('drift_started_at')
            $marker | Add-Member -NotePropertyName drift_started_at `
                -NotePropertyValue $parsedTimestamp.UtcDateTime.ToString('o')
            $issue | Add-Member -NotePropertyName marker -NotePropertyValue $marker -Force
            return $issue
        }
        catch {
            continue
        }
    }
    return $repairCandidate
}

function Resolve-DriftStartedAt {
    param(
        $ExistingIssue,
        [datetime]$Now = (Get-Date).ToUniversalTime()
    )

    if (
        $ExistingIssue -and
        $ExistingIssue.state -eq 'OPEN' -and
        $ExistingIssue.PSObject.Properties['marker'] -and
        $ExistingIssue.marker.drift_started_at
    ) {
        return [string]$ExistingIssue.marker.drift_started_at
    }
    return $Now.ToUniversalTime().ToString('o')
}

function New-IssueBody {
    param(
        [System.Collections.IDictionary]$Status,
        [string[]]$AllowedBumps,
        [string]$PolicyNote
    )

    $marker = ConvertTo-IssueMarker -Status $Status
    return @"
$marker
## BaseCoat consumer update

| Field | Value |
|---|---|
| Current | ``v$($Status.current_version)`` |
| Target | ``$($Status.target_tag)`` |
| Immutable source SHA | ``$($Status.target_sha)`` |
| Bump | ``$($Status.bump)`` |
| Channel | ``$($Status.channel)`` |
| Mode | ``$($Status.mode)`` |
| Approval | ``$($Status.approval)`` |
| Allowed bumps | ``$($AllowedBumps -join ', ')`` |
| Disposition | ``$($Status.disposition)`` |
| Drift started | ``$($Status.drift_started_at)`` |
| Upgrade PR | $($Status.pr_url) |

$PolicyNote

[Release notes]($($Status.release_notes_url))

This issue is updated in place by the BaseCoat consumer updater. It closes only
after the installed version reaches the resolved target.
"@
}

function Set-DriftIssue {
    param(
        [System.Collections.IDictionary]$Status,
        [string[]]$AllowedBumps,
        [string]$PolicyNote,
        $ExistingIssue
    )

    $title = "chore(basecoat): update v$($Status.current_version) to v$($Status.target_version)"
    $body = New-IssueBody -Status $Status -AllowedBumps $AllowedBumps -PolicyNote $PolicyNote
    if ($ExistingIssue) {
        $null = Invoke-Native -Command 'gh' -Arguments @(
            'issue', 'edit', [string]$ExistingIssue.number, '--repo', $env:GITHUB_REPOSITORY,
            '--title', $title, '--body', $body
        )
        if ($ExistingIssue.state -eq 'CLOSED') {
            $null = Invoke-Native -Command 'gh' -Arguments @(
                'issue', 'reopen', [string]$ExistingIssue.number, '--repo', $env:GITHUB_REPOSITORY
            )
        }
        return [pscustomobject]@{
            number = $ExistingIssue.number
            url = $ExistingIssue.url
            createdAt = $ExistingIssue.createdAt
            state = 'OPEN'
        }
    }

    $create = Invoke-Native -Command 'gh' -Arguments @(
        'issue', 'create', '--repo', $env:GITHUB_REPOSITORY, '--title', $title,
        '--body', $body
    )
    $url = ($create.Output | Select-Object -Last 1).Trim()
    $number = [int]($url -replace '^.*/', '')
    return [pscustomobject]@{
        number = $number
        url = $url
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        state = 'OPEN'
    }
}

function Close-DriftIssue {
    param($ExistingIssue, [System.Collections.IDictionary]$Status)

    if (-not $ExistingIssue) { return }
    $isAhead = $Status.disposition -eq 'ahead-of-target'
    $policyNote = if ($isAhead) {
        'The installed version is newer than the resolved target; the updater will not downgrade it.'
    }
    else {
        'The installed version now matches the resolved target.'
    }
    $body = New-IssueBody -Status $Status -AllowedBumps @() -PolicyNote $policyNote
    $title = if ($isAhead) {
        "chore(basecoat): consumer v$($Status.current_version) is ahead of target v$($Status.target_version)"
    }
    else {
        "chore(basecoat): consumer is current at v$($Status.current_version)"
    }
    $null = Invoke-Native -Command 'gh' -Arguments @(
        'issue', 'edit', [string]$ExistingIssue.number, '--repo', $env:GITHUB_REPOSITORY,
        '--title', $title, '--body', $body
    )
    if ($ExistingIssue.state -eq 'OPEN') {
        $comment = if ($isAhead) {
            'Installed BaseCoat version is ahead of the immutable target; closing without downgrade.'
        }
        else {
            'Installed BaseCoat version reached the immutable target.'
        }
        $null = Invoke-Native -Command 'gh' -Arguments @(
            'issue', 'close', [string]$ExistingIssue.number, '--repo', $env:GITHUB_REPOSITORY,
            '--comment', $comment
        )
    }
}

function Find-SyncScript {
    param([string]$WorktreePath, [string[]]$ConfigLines)

    $configured = Get-YamlScalar -Lines $ConfigLines -Section 'sync' -Key 'script'
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($configured) { $candidates.Add((Join-Path $WorktreePath $configured)) }
    $candidates.Add((Join-Path $WorktreePath 'sync.ps1'))
    $candidates.Add((Join-Path $WorktreePath 'sync.sh'))
    $scriptsPath = Join-Path $WorktreePath 'scripts'
    if (Test-Path -LiteralPath $scriptsPath) {
        Get-ChildItem -LiteralPath $scriptsPath -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^sync.*basecoat.*\.(ps1|sh)$' } |
            Sort-Object -Property FullName |
            ForEach-Object { $candidates.Add($_.FullName) }
    }
    $candidates.Add((Join-Path $WorktreePath '.github/base-coat/sync.ps1'))
    $candidates.Add((Join-Path $WorktreePath '.github/base-coat/sync.sh'))
    return $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

function Get-DefaultBranch {
    $result = Invoke-Native -Command 'gh' -Arguments @(
        'repo', 'view', $env:GITHUB_REPOSITORY, '--json', 'defaultBranchRef', '--jq', '.defaultBranchRef.name'
    )
    $branch = ($result.Output | Select-Object -First 1).Trim()
    if (-not $branch) { throw 'Unable to resolve the consumer default branch.' }
    return $branch
}

function Get-PrMarkerValue {
    param([object]$Pr, [string]$Label)

    if (-not $Pr -or -not $Pr.PSObject.Properties['body']) { return $null }
    $match = [regex]::Match([string]$Pr.body, "(?m)^- $([regex]::Escape($Label)): (.+?)\s*$")
    return $(if ($match.Success) { $match.Groups[1].Value.Trim('`') } else { $null })
}

function Test-ManagedUpgradePath {
    param([string]$Path, [string]$StagePath)

    $normalized = $Path -replace '\\', '/'
    $stage = ($StagePath -replace '\\', '/').TrimEnd('/')
    return (
        $normalized -eq '.basecoat.yml' -or
        $normalized.StartsWith("$stage/") -or
        $normalized.StartsWith('.github/agents/') -or
        $normalized.StartsWith('.github/instructions/') -or
        $normalized.StartsWith('.github/prompts/') -or
        $normalized.StartsWith('.github/skills/') -or
        $normalized.StartsWith('.agents/skills/') -or
        $normalized -eq '.github/release-notes/templates/default.md' -or
        $normalized -eq '.github/PULL_REQUEST_TEMPLATE.md' -or
        $normalized -eq '.github/ISSUE_TEMPLATE/issue.md'
    )
}

function Test-TrustedGeneratedPr {
    param(
        [object]$Pr,
        [string]$RepoRoot,
        [string]$DefaultBranch,
        [string]$CanonicalSource,
        [string]$FetchSource,
        [string]$StagePath,
        [string]$ExpectedAuthor
    )

    if (-not (Test-OwnedUpgradePr -Pr $Pr -DefaultBranch $DefaultBranch -ExpectedAuthor $ExpectedAuthor)) { return $false }

    $repoOwner = ($env:GITHUB_REPOSITORY -split '/', 2)[0]
    $headOwner = if ($Pr.headRepositoryOwner) { [string]$Pr.headRepositoryOwner.login } else { '' }
    if ($headOwner -ne $repoOwner) { return $false }

    $tag = Get-PrMarkerValue -Pr $Pr -Label 'Target'
    $declaredSha = Get-PrMarkerValue -Pr $Pr -Label 'Immutable source SHA'
    if (-not $tag -or $declaredSha -notmatch '^[0-9a-fA-F]{40}$') { return $false }
    try {
        $targetVersion = (ConvertTo-SemVer $tag).Text
        $canonicalSha = Resolve-TagSha -FetchSource (Convert-RepoToCloneUrl $CanonicalSource) -Tag $tag
        $canonicalFetch = Convert-RepoToCloneUrl $CanonicalSource
        $fetchCredentialKind = if ($FetchSource.Equals($canonicalFetch, [System.StringComparison]::OrdinalIgnoreCase)) {
            'canonical'
        }
        else {
            'mirror'
        }
        $fetchSha = Resolve-TagSha -FetchSource $FetchSource -Tag $tag -CredentialKind $fetchCredentialKind
        if ($canonicalSha -ne $declaredSha -or $fetchSha -ne $declaredSha) { return $false }

        $number = [string]$Pr.number
        $files = Invoke-Native -Command 'gh' -Arguments @(
            'api', '--paginate', "repos/$($env:GITHUB_REPOSITORY)/pulls/$number/files?per_page=100",
            '--jq', '.[].filename'
        )
        if ($files.Output.Count -eq 0 -or @($files.Output | Where-Object {
            -not (Test-ManagedUpgradePath -Path $_ -StagePath $StagePath)
        }).Count -gt 0) { return $false }

        $head = [string]$Pr.headRefName
        $null = Invoke-ConsumerGit -RepoRoot $RepoRoot -Arguments @(
            'fetch', 'origin', "+refs/heads/$head`:refs/remotes/origin/$head"
        )
        $versionResult = Invoke-Native -Command 'git' -Arguments @(
            '-C', $RepoRoot, 'show', "origin/$head`:$StagePath/version.json"
        )
        $installed = [string](($versionResult.Output -join "`n") | ConvertFrom-Json).version
        if ($installed -ne $targetVersion) { return $false }
        $provenanceResult = Invoke-Native -Command 'git' -Arguments @(
            '-C', $RepoRoot, 'show', "origin/$head`:$StagePath/.source-provenance.json"
        )
        $provenance = ($provenanceResult.Output -join "`n") | ConvertFrom-Json
        if ([string]$provenance.commit -ne $declaredSha) { return $false }
        $configResult = Invoke-Native -Command 'git' -Arguments @(
            '-C', $RepoRoot, 'show', "origin/$head`:.basecoat.yml"
        )
        if ((Get-YamlScalar -Lines $configResult.Output -Key 'ref') -ne $tag) { return $false }
        return $true
    }
    catch {
        Write-Warning "Ignoring untrusted BaseCoat PR #$($Pr.number): $(Protect-SensitiveText $_.Exception.Message)"
        return $false
    }
}

function Test-OwnedUpgradePr {
    param([object]$Pr, [string]$DefaultBranch, [string]$ExpectedAuthor)

    if (-not $ExpectedAuthor -or -not $Pr -or -not $Pr.body -or -not $Pr.body.Contains($script:PrMarker)) { return $false }
    $repoOwner = ($env:GITHUB_REPOSITORY -split '/', 2)[0]
    $headOwner = if ($Pr.headRepositoryOwner) { [string]$Pr.headRepositoryOwner.login } else { '' }
    $author = if ($Pr.author) { [string]$Pr.author.login } else { '' }
    $expectedAuthors = @($ExpectedAuthor.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    return -not (
        [bool]$Pr.isCrossRepository -or
        [string]$Pr.baseRefName -ne $DefaultBranch -or
        $headOwner -ne $repoOwner -or
        -not ($expectedAuthors | Where-Object { $author.Equals($_, [System.StringComparison]::OrdinalIgnoreCase) }) -or
        [string]$Pr.headRefName -notmatch '^chore/basecoat-update-[A-Za-z0-9._-]+-\d+(?:-attempt-\d+)?$'
    )
}

function Get-ConfiguredUpdateActors {
    if (-not $env:BASECOAT_UPDATE_ACTOR) { return @() }
    return @($env:BASECOAT_UPDATE_ACTOR.Split(',') |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ })
}

function Get-UpdateActor {
    $allowedActors = @(Get-ConfiguredUpdateActors)
    if ($allowedActors.Count -eq 0) {
        throw 'pull-request mode requires update_actor to persist the authorized PAT/App login for safe stale-PR reconciliation.'
    }
    if (-not $env:BASECOAT_UPDATE_TOKEN) { return ($allowedActors -join ',') }
    $oldGhToken = $env:GH_TOKEN
    try {
        $env:GH_TOKEN = $env:BASECOAT_UPDATE_TOKEN
        $result = Invoke-Native -Command 'gh' -Arguments @('api', 'user', '--jq', '.login') -AllowFailure
        if ($result.ExitCode -ne 0 -or -not ($result.Output | Select-Object -First 1)) {
            $repoCheck = Invoke-Native -Command 'gh' -Arguments @(
                'api', "repos/$($env:GITHUB_REPOSITORY)", '--jq', '.full_name'
            ) -AllowFailure
            $botActors = @($allowedActors | Where-Object { $_ -match '\[bot\]$' })
            if (
                $repoCheck.ExitCode -eq 0 -and
                [string]($repoCheck.Output | Select-Object -First 1) -eq $env:GITHUB_REPOSITORY -and
                $botActors.Count -eq 1
            ) {
                return ($allowedActors -join ',')
            }
        }
    }
    finally {
        $env:GH_TOKEN = $oldGhToken
    }
    $actor = [string]($result.Output | Select-Object -First 1)
    if ($result.ExitCode -ne 0 -or -not $actor) {
        throw 'Unable to verify the authenticated update token actor.'
    }
    if ($allowedActors -notcontains $actor.Trim()) {
        throw "update_actor does not include the authenticated update token actor '$($actor.Trim())'."
    }
    return ($allowedActors -join ',')
}

function Get-MissingPullRequestDeliveryConfiguration {
    param(
        [string]$EligiblePrTarget,
        [string]$UpdateToken,
        [string[]]$UpdateActors
    )

    if (-not $EligiblePrTarget) { return @() }
    return @(
        if (-not $UpdateToken) { 'update_token' }
        if (@($UpdateActors).Count -eq 0) { 'update_actor' }
    )
}

function Get-GeneratedUpgradePrs {
    param(
        [string]$RepoRoot,
        [string]$DefaultBranch,
        [string]$CanonicalSource,
        [string]$FetchSource,
        [string]$StagePath,
        [string]$ExpectedAuthor
    )

    $result = Invoke-Native -Command 'gh' -Arguments @(
        'pr', 'list', '--repo', $env:GITHUB_REPOSITORY, '--state', 'open', '--limit', '1000',
        '--search', 'basecoat-consumer-update-pr:v1 in:body',
        '--json', 'number,url,body,headRefName,headRefOid,baseRefName,isCrossRepository,headRepositoryOwner,author'
    )
    $prs = ($result.Output -join "`n") | ConvertFrom-Json
    return @($prs | Where-Object { Test-OwnedUpgradePr -Pr $_ -DefaultBranch $DefaultBranch -ExpectedAuthor $ExpectedAuthor } | ForEach-Object {
        $null = Invoke-Native -Command 'gh' -Arguments @(
            'pr', 'merge', [string]$_.number, '--repo', $env:GITHUB_REPOSITORY, '--disable-auto'
        ) -AllowFailure
        $trusted = Test-TrustedGeneratedPr -Pr $_ -RepoRoot $RepoRoot -DefaultBranch $DefaultBranch `
            -CanonicalSource $CanonicalSource -FetchSource $FetchSource -StagePath $StagePath -ExpectedAuthor $ExpectedAuthor
        $_ | Add-Member -NotePropertyName trusted -NotePropertyValue $trusted -Force
        $_
    })
}

function Get-ExistingUpgradePr {
    param(
        [string]$TargetTag,
        [object[]]$GeneratedPrs
    )

    $escapedTag = [regex]::Escape($TargetTag)
    return $GeneratedPrs | Where-Object {
        $_ -and
        (-not $_.PSObject.Properties['trusted'] -or [bool]$_.trusted) -and
        $_.PSObject.Properties['body'] -and
        $_.body -match "(?m)^- Target: $escapedTag\s*$"
    } | Select-Object -First 1
}

function Close-StaleUpgradePrs {
    param(
        [string]$TargetTag,
        [object[]]$GeneratedPrs
    )

    $escapedTag = [regex]::Escape($TargetTag)
    foreach ($pr in $GeneratedPrs) {
        if (-not $pr -or -not $pr.PSObject.Properties['body']) { continue }
        $trusted = -not $pr.PSObject.Properties['trusted'] -or [bool]$pr.trusted
        if ($trusted -and $TargetTag -and $pr.body -match "(?m)^- Target: $escapedTag\s*$") { continue }
        $number = [string]$pr.number
        $null = Invoke-Native -Command 'gh' -Arguments @(
            'pr', 'merge', $number, '--repo', $env:GITHUB_REPOSITORY, '--disable-auto'
        ) -AllowFailure
        $comment = if ($TargetTag) {
            "Superseded by BaseCoat target $TargetTag; closing to prevent a stale upgrade or downgrade."
        }
        else {
            'No generated BaseCoat upgrade PR is currently eligible; closing to prevent a stale upgrade or policy violation.'
        }
        $null = Invoke-Native -Command 'gh' -Arguments @(
            'pr', 'close', $number, '--repo', $env:GITHUB_REPOSITORY,
            '--comment', $comment
        )
    }
}

function Set-TopLevelYamlValue {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    $lines = if (Test-Path -LiteralPath $Path) { @(Get-Content -LiteralPath $Path) } else { @() }
    $updated = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match "^$([regex]::Escape($Key)):\s*") {
            $lines[$index] = "$Key`: $Value"
            $updated = $true
            break
        }
    }
    if (-not $updated) { $lines += "$Key`: $Value" }
    $lines | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Wait-ForRequiredChecks {
    param(
        [string]$PrNumber,
        [int]$MaxAttempts = 60,
        [int]$DelaySeconds = 10
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $result = Invoke-Native -Command 'gh' -Arguments @(
            'pr', 'checks', $PrNumber, '--repo', $env:GITHUB_REPOSITORY,
            '--required', '--json', 'name,state,bucket'
        ) -AllowFailure
        if (($result.Output -join "`n").Trim().StartsWith('[')) {
            $checks = @(($result.Output -join "`n") | ConvertFrom-Json)
            if ($checks.Count -eq 0) { return }
            $failed = @($checks | Where-Object { $_.bucket -eq 'fail' -or $_.state -in @('FAILURE', 'ERROR', 'CANCELLED') })
            if ($failed.Count -gt 0) { throw "Consumer required checks failed; automatic merge remains disabled." }
            $pending = @($checks | Where-Object { $_.bucket -eq 'pending' -or $_.state -in @('PENDING', 'QUEUED', 'IN_PROGRESS') })
            if ($pending.Count -eq 0) { return }
        }
        if ($attempt -lt $MaxAttempts) { Start-Sleep -Seconds $DelaySeconds }
    }
    throw 'Consumer required checks did not run and pass before the automatic-update timeout.'
}

function Invoke-UpgradePullRequest {
    param(
        [string]$RepoRoot,
        [pscustomobject]$Policy,
        [pscustomobject]$Release,
        [string]$CurrentVersion,
        [string]$IssueUrl,
        [string]$EffectiveApproval,
        [AllowNull()][object[]]$GeneratedPrs = $null
    )

    if (-not $env:BASECOAT_UPDATE_TOKEN) {
        throw 'pull-request mode requires the dedicated BASECOAT_UPDATE_TOKEN secret (GitHub App token or fine-grained PAT) so generated push and pull_request events trigger consumer CI.'
    }
    $oldDeliveryGhToken = $env:GH_TOKEN
    try {
        $env:GH_TOKEN = $env:BASECOAT_UPDATE_TOKEN

        $defaultBranch = $null
        if ($null -eq $GeneratedPrs) {
            $defaultBranch = Get-DefaultBranch
            $fetchSource = Convert-RepoToCloneUrl $(if ($Policy.Mirror) { $Policy.Mirror } else { $Policy.Source })
            $GeneratedPrs = @(Get-GeneratedUpgradePrs -RepoRoot $RepoRoot -DefaultBranch $defaultBranch `
                -CanonicalSource $Policy.Source -FetchSource $fetchSource -StagePath $StagePath)
            Close-StaleUpgradePrs -TargetTag $Release.Tag -GeneratedPrs $GeneratedPrs
        }
        $existing = Get-ExistingUpgradePr -TargetTag $Release.Tag -GeneratedPrs $GeneratedPrs
        if ($existing) {
            $null = Invoke-Native -Command 'gh' -Arguments @(
                'pr', 'merge', [string]$existing.number, '--repo', $env:GITHUB_REPOSITORY, '--disable-auto'
            ) -AllowFailure
        }
        if (-not $defaultBranch) { $defaultBranch = Get-DefaultBranch }

        $runSuffix = Get-RunSuffix
        $safeTag = $Release.Tag -replace '[^A-Za-z0-9._-]', '-'
        $branch = if ($existing) { [string]$existing.headRefName } else { "chore/basecoat-update-$safeTag-$runSuffix" }
        $parent = Split-Path $RepoRoot -Parent
        $repoName = Split-Path $RepoRoot -Leaf
        $worktreePath = Join-Path $parent "$repoName-wt-basecoat-$runSuffix"
        $deliverySucceeded = $false
        $prUrl = ''

        $null = Invoke-ConsumerGit -RepoRoot $RepoRoot -Arguments @('fetch', 'origin')
        $worktreesBefore = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'list', '--porcelain')
        Write-Host ($worktreesBefore.Output -join "`n")
        # A prior attempt that failed after selecting this PR's head branch leaves
        # a worktree still checked out on that branch (see the failure-path
        # `Write-Warning ... preserving worktree` below). `git worktree add -B`
        # cannot reuse a branch that is checked out in another worktree, so a naive
        # retry with a fresh run-suffixed path fails permanently. Recover by
        # removing only the worktree that is verifiably mapped to this exact
        # branch (never an unrelated one) before adding the new one.
        if ($existing) {
            $preservedWorktree = Get-WorktreePathForBranch -PorcelainLines $worktreesBefore.Output -Branch $branch -ExcludePath $RepoRoot
            if ($preservedWorktree) {
                Write-Warning "Recovering worktree '$preservedWorktree' still checked out on '$branch' from an earlier failed attempt."
                $null = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'remove', '--force', $preservedWorktree) -AllowFailure
            }
        }
        if (Test-Path -LiteralPath $worktreePath) { throw "Refusing to reuse existing worktree path '$worktreePath'." }
        $worktreeBranchMode = if ($existing) { '-B' } else { '-b' }
        $null = Invoke-Native -Command 'git' -Arguments @(
            '-C', $RepoRoot, 'worktree', 'add', $worktreeBranchMode, $branch, $worktreePath, "origin/$defaultBranch"
        )

        try {
            $worktreeConfig = Get-ConfigLines -RepoRoot $worktreePath
        $previousRef = Get-YamlScalar -Lines $worktreeConfig -Key 'ref'
        if (-not $previousRef) { $previousRef = '<unset>' }
        $previousSource = Get-YamlScalar -Lines $worktreeConfig -Key 'source'
        if (-not $previousSource) { $previousSource = '<unset>' }
        $previousMirror = Get-YamlScalar -Lines $worktreeConfig -Key 'mirror'
        if (-not $previousMirror) { $previousMirror = '<unset>' }
        $previousSource = Protect-SensitiveText $previousSource
        $previousMirror = Protect-SensitiveText $previousMirror
        $syncScript = Find-SyncScript -WorktreePath $worktreePath -ConfigLines $worktreeConfig
        if (-not $syncScript) {
            throw 'No BaseCoat sync entrypoint found. Configure sync.script or add sync.ps1/sync.sh.'
        }

        $oldRepo = $env:BASECOAT_REPO
        $oldRef = $env:BASECOAT_REF
        $oldMirror = $env:BASECOAT_MIRROR
        $oldExpectedSha = $env:BASECOAT_EXPECTED_SHA
        $oldReleaseTag = $env:BASECOAT_RELEASE_TAG
        $oldTargetDir = $env:BASECOAT_TARGET_DIR
        $oldSyncFetchHost = $env:BASECOAT_FETCH_HOST
        $oldSyncFetchToken = $env:BASECOAT_FETCH_TOKEN
        try {
            $env:BASECOAT_REPO = Convert-RepoToCloneUrl $Policy.Source
            $env:BASECOAT_REF = $Release.Sha
            $env:BASECOAT_EXPECTED_SHA = $Release.Sha
            $env:BASECOAT_RELEASE_TAG = $Release.Tag
            $env:BASECOAT_TARGET_DIR = $StagePath
            if ($Policy.Mirror) {
                $mirrorCloneUrl = Convert-RepoToCloneUrl $Policy.Mirror
                $env:BASECOAT_MIRROR = $mirrorCloneUrl
                $mirrorUri = $null
                $mirrorMatchesCanonicalAuthority = (
                    [uri]::TryCreate($mirrorCloneUrl, [System.UriKind]::Absolute, [ref]$mirrorUri) -and
                    $env:BASECOAT_FETCH_HOST -and
                    $mirrorUri.Authority.Equals($env:BASECOAT_FETCH_HOST, [System.StringComparison]::OrdinalIgnoreCase)
                )
                if ($env:BASECOAT_MIRROR_FETCH_HOST -and $env:BASECOAT_MIRROR_FETCH_TOKEN) {
                    $env:BASECOAT_FETCH_HOST = $env:BASECOAT_MIRROR_FETCH_HOST
                    $env:BASECOAT_FETCH_TOKEN = $env:BASECOAT_MIRROR_FETCH_TOKEN
                }
                elseif (-not $mirrorMatchesCanonicalAuthority) {
                    $env:BASECOAT_FETCH_HOST = $null
                    $env:BASECOAT_FETCH_TOKEN = $null
                }
            }
            Push-Location $worktreePath
            try {
                $oldChildGhToken = $env:GH_TOKEN
                $oldChildUpdateToken = $env:BASECOAT_UPDATE_TOKEN
                try {
                    $env:GH_TOKEN = $null
                    $env:BASECOAT_UPDATE_TOKEN = $null
                    if ($syncScript.EndsWith('.ps1')) {
                        $null = Invoke-Native -Command 'pwsh' -Arguments @('-NoProfile', '-File', $syncScript)
                    }
                    else {
                        $null = Invoke-Native -Command 'bash' -Arguments @($syncScript)
                    }
                }
                finally {
                    $env:GH_TOKEN = $oldChildGhToken
                    $env:BASECOAT_UPDATE_TOKEN = $oldChildUpdateToken
                }
            }
            finally {
                Pop-Location
            }
        }
        finally {
            $env:BASECOAT_REPO = $oldRepo
            $env:BASECOAT_REF = $oldRef
            $env:BASECOAT_MIRROR = $oldMirror
            $env:BASECOAT_EXPECTED_SHA = $oldExpectedSha
            $env:BASECOAT_RELEASE_TAG = $oldReleaseTag
            $env:BASECOAT_TARGET_DIR = $oldTargetDir
            $env:BASECOAT_FETCH_HOST = $oldSyncFetchHost
            $env:BASECOAT_FETCH_TOKEN = $oldSyncFetchToken
        }

        $versionPath = Join-Path $worktreePath "$StagePath/version.json"
        if (-not (Test-Path -LiteralPath $versionPath)) { throw "Sync did not produce '$versionPath'." }
        $installed = (Get-Content -LiteralPath $versionPath -Raw | ConvertFrom-Json).version
        $target = (ConvertTo-SemVer $Release.Tag).Text
        if ($installed -ne $target) { throw "Sync provenance mismatch: installed '$installed', target '$target'." }
        $provenancePath = Join-Path $worktreePath "$StagePath/.source-provenance.json"
        if (-not (Test-Path -LiteralPath $provenancePath)) { throw "Sync did not produce '$provenancePath'." }
        $provenance = Get-Content -LiteralPath $provenancePath -Raw | ConvertFrom-Json
        if ([string]$provenance.commit -ne $Release.Sha) {
            throw "Sync source provenance mismatch: synced '$($provenance.commit)', resolved '$($Release.Sha)'."
        }

        foreach ($persistentSource in @($Policy.Source, $Policy.Mirror) | Where-Object { $_ }) {
            if ((Protect-SensitiveText $persistentSource) -ne $persistentSource) {
                throw 'Source and mirror URLs persisted in .basecoat.yml must not contain userinfo or query credentials. Configure authentication separately.'
            }
        }
        $configPath = Join-Path $worktreePath '.basecoat.yml'
        Set-TopLevelYamlValue -Path $configPath -Key 'source' -Value (Convert-RepoToCloneUrl $Policy.Source)
        if ($Policy.Mirror) {
            Set-TopLevelYamlValue -Path $configPath -Key 'mirror' -Value (Convert-RepoToCloneUrl $Policy.Mirror)
        }
        Set-TopLevelYamlValue -Path $configPath -Key 'ref' -Value $Release.Tag

        $statusResult = Invoke-Native -Command 'git' -Arguments @('-C', $worktreePath, 'status', '--porcelain')
        if ($statusResult.Output.Count -eq 0 -or -not ($statusResult.Output -join '')) {
            $deliverySucceeded = $true
            return ''
        }

        $null = Invoke-Native -Command 'git' -Arguments @('-C', $worktreePath, 'add', '-A')
        $message = "chore(basecoat): upgrade to $($Release.Tag)"
        $null = Invoke-Native -Command 'git' -Arguments @(
            '-C', $worktreePath,
            '-c', 'user.name=basecoat-updater',
            '-c', 'user.email=basecoat-updater@users.noreply.github.com',
            'commit', '-m', $message, '-m',
            'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
        )
        $null = Invoke-ConsumerGit -RepoRoot $worktreePath -Arguments @('fetch', 'origin')
        $null = Invoke-Native -Command 'git' -Arguments @('-C', $worktreePath, 'rebase', "origin/$defaultBranch")

        $diffCheck = Invoke-Native -Command 'git' -Arguments @(
            '-C', $worktreePath, 'diff', '--check', "origin/$defaultBranch...HEAD"
        ) -AllowFailure
        if ($diffCheck.ExitCode -ne 0) { throw "Post-rebase git diff --check failed: $($diffCheck.Output -join "`n")" }
        if ($Policy.Validation) {
            Push-Location $worktreePath
            try {
                $oldChildGhToken = $env:GH_TOKEN
                $oldChildUpdateToken = $env:BASECOAT_UPDATE_TOKEN
                $oldChildFetchToken = $env:BASECOAT_FETCH_TOKEN
                $oldChildMirrorFetchToken = $env:BASECOAT_MIRROR_FETCH_TOKEN
                try {
                    $env:GH_TOKEN = $null
                    $env:BASECOAT_UPDATE_TOKEN = $null
                    $env:BASECOAT_FETCH_TOKEN = $null
                    $env:BASECOAT_MIRROR_FETCH_TOKEN = $null
                    $validation = Invoke-Native -Command 'pwsh' -Arguments @(
                        '-NoProfile', '-Command', $Policy.Validation
                    ) -AllowFailure
                }
                finally {
                    $env:GH_TOKEN = $oldChildGhToken
                    $env:BASECOAT_UPDATE_TOKEN = $oldChildUpdateToken
                    $env:BASECOAT_FETCH_TOKEN = $oldChildFetchToken
                    $env:BASECOAT_MIRROR_FETCH_TOKEN = $oldChildMirrorFetchToken
                }
                if ($validation.ExitCode -ne 0) {
                    throw "Post-rebase updates.validation failed: $($validation.Output -join "`n")"
                }
            }
            finally {
                Pop-Location
            }
        }
        $postValidationStatus = Invoke-Native -Command 'git' -Arguments @('-C', $worktreePath, 'status', '--porcelain')
        if (($postValidationStatus.Output -join '')) {
            throw 'Configured validation modified the post-rebase worktree; refusing to push unvalidated content.'
        }
        $changedResult = Invoke-Native -Command 'git' -Arguments @(
            '-C', $worktreePath, 'diff', '--name-only', "origin/$defaultBranch...HEAD"
        )
        $changed = @($changedResult.Output | Where-Object { $_ })
        $unmanaged = @($changed | Where-Object {
            -not (Test-ManagedUpgradePath -Path $_ -StagePath $StagePath)
        })
        if ($unmanaged.Count -gt 0) {
            throw "Sync changed unmanaged consumer paths: $($unmanaged -join ', ')."
        }
        if ($existing) {
            $lease = "refs/heads/$branch`:$([string]$existing.headRefOid)"
            $null = Invoke-ConsumerGit -RepoRoot $worktreePath -Arguments @(
                'push', "--force-with-lease=$lease", 'origin', "HEAD:refs/heads/$branch"
            )
        }
        else {
            $null = Invoke-ConsumerGit -RepoRoot $worktreePath -Arguments @('push', '-u', 'origin', $branch)
        }

        $changedList = ($changed | ForEach-Object { "- ``$_``" }) -join "`n"
        $prBody = @"
$script:PrMarker
## BaseCoat upgrade

- Previous: ``v$CurrentVersion``
- Target: $($Release.Tag)
- Immutable source SHA: ``$($Release.Sha)``
- Release notes: $($Release.Url)
- Tracking issue: $IssueUrl
- Approval policy: ``$EffectiveApproval``

### Changed assets

$changedList

### Validation

- ``git diff --check``
  (post-rebase against ``origin/$defaultBranch...HEAD``)
$(if ($Policy.Validation) { "- ``$($Policy.Validation)``" } else { '- Consumer required checks and branch protection must pass.' })

### Rollback

Revert this PR or restore these top-level values in ``.basecoat.yml`` and rerun
the consumer sync entrypoint:

- ``source: $previousSource``
- ``mirror: $previousMirror``
- ``ref: $previousRef``
"@
        if ($existing) {
            $null = Invoke-Native -Command 'gh' -Arguments @(
                'pr', 'edit', [string]$existing.number, '--repo', $env:GITHUB_REPOSITORY,
                '--title', $message, '--body', $prBody
            )
            $prUrl = [string]$existing.url
        }
        else {
            $create = Invoke-Native -Command 'gh' -Arguments @(
                'pr', 'create', '--repo', $env:GITHUB_REPOSITORY, '--base', $defaultBranch,
                '--head', $branch, '--title', $message, '--body', $prBody
            )
            $prUrl = ($create.Output | Select-Object -Last 1).Trim()
        }
        if ($EffectiveApproval -eq 'automatic') {
            $prNumber = [string]([int]($prUrl -replace '^.*/', ''))
            Wait-ForRequiredChecks -PrNumber $prNumber
            $null = Invoke-Native -Command 'gh' -Arguments @(
                'pr', 'merge', $prNumber, '--repo', $env:GITHUB_REPOSITORY, '--auto', '--squash'
            )
        }
        $deliverySucceeded = $true
        return $prUrl
        }
        catch {
            if ($prUrl) { $_.Exception.Data['BasecoatPrUrl'] = $prUrl }
            throw
        }
        finally {
            if ($deliverySucceeded) {
                $mapped = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'list', '--porcelain')
                Write-Host ($mapped.Output -join "`n")
                if (-not (Test-ExpectedWorktreeMapping -PorcelainLines $mapped.Output -WorktreePath $worktreePath -Branch $branch)) {
                    throw "Refusing cleanup because worktree '$worktreePath' is not mapped to 'refs/heads/$branch'."
                }
                $null = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'remove', $worktreePath)
                $null = Invoke-Native -Command 'git' -Arguments @('-C', $RepoRoot, 'branch', '-D', $branch)
            }
            else {
                Write-Warning "Upgrade delivery failed; preserving worktree '$worktreePath' and branch '$branch' for recovery."
            }
        }
    }
    finally {
        $env:GH_TOKEN = $oldDeliveryGhToken
    }
}

function Write-Status {
    param([System.Collections.IDictionary]$Status, [string]$Path)

    $parent = Split-Path $Path -Parent
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $Status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM

    if ($env:GITHUB_STEP_SUMMARY) {
        @"
## BaseCoat consumer update

| Current | Target | Bump | Mode | Approval | Drift age | Disposition |
|---|---|---|---|---|---:|---|
| v$($Status.current_version) | v$($Status.target_version) | $($Status.bump) | $($Status.mode) | $($Status.approval) | $($Status.drift_age_days) days | $($Status.disposition) |

- Issue: $($Status.issue_url)
- PR: $($Status.pr_url)
- Source SHA: ``$($Status.target_sha)``
"@ | Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY
    }
}

if ($LibraryOnly) { return }

$repoRootResult = Invoke-Native -Command 'git' -Arguments @('rev-parse', '--show-toplevel')
$repoRoot = ($repoRootResult.Output | Select-Object -First 1).Trim()
$configLines = Get-ConfigLines -RepoRoot $repoRoot
$policy = Get-UpdatePolicy -Lines $configLines -Overrides @{
    Mode = $Mode
    Approval = $Approval
    Source = $Source
    Ref = $Ref
    Mirror = $Mirror
    Channel = $Channel
    AllowedBumps = $AllowedBumps
}

$requestedRef = $policy.Ref
if ($policy.KnownBad.ContainsKey($requestedRef)) {
    Write-Warning "Remapping known-bad release '$requestedRef' to '$($policy.KnownBad[$requestedRef])'."
    $requestedRef = $policy.KnownBad[$requestedRef]
}
$fetchSource = Convert-RepoToCloneUrl $(if ($policy.Mirror) { $policy.Mirror } else { $policy.Source })
$release = Resolve-Release -CanonicalSource $policy.Source -FetchSource $fetchSource -RequestedRef $requestedRef `
    -ReleaseOverrideJson $ReleaseJson -VerifyProvenance:(-not $PlanOnly)
if ($policy.KnownBad.ContainsKey($release.Tag)) {
    $remapped = $policy.KnownBad[$release.Tag]
    Write-Warning "Resolved release '$($release.Tag)' is known-bad; remapping to '$remapped'."
    $release = Resolve-Release -CanonicalSource $policy.Source -FetchSource $fetchSource -RequestedRef $remapped -ReleaseOverrideJson ''
}

$versionPath = Join-Path $repoRoot "$StagePath/version.json"
if (-not (Test-Path -LiteralPath $versionPath)) { throw "Consumer version file not found: '$versionPath'." }
$currentVersion = [string](Get-Content -LiteralPath $versionPath -Raw | ConvertFrom-Json).version
$current = ConvertTo-SemVer $currentVersion
$target = ConvertTo-SemVer $release.Tag
if ($policy.Channel -eq 'stable' -and ($target.Prerelease -or $release.IsDraft -or $release.IsPrerelease)) {
    throw "Stable update policy rejected prerelease target '$($release.Tag)'."
}
$comparison = Compare-SemVer -Current $current -Target $target
$bump = Get-SemVerBump -Current $current -Target $target
$effectiveApproval = $policy.Approval
if ($bump -eq 'major') { $effectiveApproval = 'required' }

$status = New-Status -CurrentVersion $current.Text -TargetVersion $target.Text -TargetTag $release.Tag `
    -TargetSha $release.Sha -Source $policy.Source -Channel $policy.Channel -Mode $policy.Mode `
    -Approval $effectiveApproval -Bump $bump -Disposition 'current' -ReleaseNotesUrl $release.Url

if ($PlanOnly) {
    if ($comparison -lt 0) {
        $status.disposition = if ($bump -in $policy.AllowedBumps) { 'planned' } else { 'blocked-by-policy' }
    }
    elseif ($comparison -gt 0) {
        $status.disposition = 'ahead-of-target'
    }
    Write-Status -Status $status -Path (Join-Path $repoRoot $StatusPath)
    $status | ConvertTo-Json -Depth 5
    exit 0
}

if (-not $env:GITHUB_REPOSITORY) { throw 'GITHUB_REPOSITORY is required for issue and pull-request operations.' }
$eligiblePrTarget = if (
    $policy.Mode -eq 'pull-request' -and
    $comparison -lt 0 -and
    $bump -in $policy.AllowedBumps
) { $release.Tag } else { '' }
$defaultBranch = Get-DefaultBranch
$configuredUpdateActors = @(Get-ConfiguredUpdateActors)
$updateActor = $configuredUpdateActors -join ','
$updateActorVerificationFailure = ''
if (
    $eligiblePrTarget -and
    $env:BASECOAT_UPDATE_TOKEN -and
    $configuredUpdateActors.Count -gt 0
) {
    try {
        $updateActor = Get-UpdateActor
    }
    catch {
        $updateActorVerificationFailure = $_.Exception.Message
    }
}
$generatedPrs = @(Get-GeneratedUpgradePrs -RepoRoot $repoRoot -DefaultBranch $defaultBranch `
    -CanonicalSource $policy.Source -FetchSource $fetchSource -StagePath $StagePath -ExpectedAuthor $updateActor)
$reconciliationTarget = if (
    $eligiblePrTarget -and
    $env:BASECOAT_UPDATE_TOKEN -and
    $configuredUpdateActors.Count -gt 0 -and
    -not $updateActorVerificationFailure
) {
    $eligiblePrTarget
}
else {
    ''
}
Close-StaleUpgradePrs -TargetTag $reconciliationTarget -GeneratedPrs $generatedPrs
$existingIssue = Get-ExistingIssue
$now = (Get-Date).ToUniversalTime()
$existingDriftStartedAt = ''
if ($existingIssue -and $existingIssue.PSObject.Properties['marker'] -and $existingIssue.marker.drift_started_at) {
    $existingDriftStartedAt = [string]$existingIssue.marker.drift_started_at
}

if ($comparison -ge 0) {
    $status.disposition = if ($comparison -eq 0) { 'current' } else { 'ahead-of-target' }
    if ($existingIssue) {
        $status.issue_url = [string]$existingIssue.url
        $status.drift_started_at = $existingDriftStartedAt
        Close-DriftIssue -ExistingIssue $existingIssue -Status $status
    }
    Write-Status -Status $status -Path (Join-Path $repoRoot $StatusPath)
    exit 0
}

$missingDeliveryConfiguration = @(Get-MissingPullRequestDeliveryConfiguration `
    -EligiblePrTarget $eligiblePrTarget -UpdateToken $env:BASECOAT_UPDATE_TOKEN `
    -UpdateActors $configuredUpdateActors)
if ($missingDeliveryConfiguration.Count -gt 0 -or $updateActorVerificationFailure) {
    $status.disposition = 'credential-required'
    $status.drift_started_at = Resolve-DriftStartedAt -ExistingIssue $existingIssue -Now $now
    $status.drift_age_days = Get-CompletedElapsedDays -Start ([datetime]$status.drift_started_at) -Now $now
    $missingText = if ($missingDeliveryConfiguration.Count -gt 0) {
        $missingDeliveryConfiguration -join ' and '
    }
    else {
        'a verified update_actor binding'
    }
    $verificationNote = if ($updateActorVerificationFailure) {
        " $updateActorVerificationFailure"
    }
    else {
        ''
    }
    $credentialNote = "Pull-request delivery is fail-closed until $missingText is configured. Use a dedicated fine-grained PAT or runtime GitHub App installation token and retain the authorized actor login.$verificationNote"
    $issue = Set-DriftIssue -Status $status -AllowedBumps $policy.AllowedBumps `
        -PolicyNote $credentialNote -ExistingIssue $existingIssue
    $status.issue_url = [string]$issue.url
    Write-Status -Status $status -Path (Join-Path $repoRoot $StatusPath)
    throw "pull-request mode requires $missingText. Drift was recorded with credential-required disposition; generated PR delivery remains disabled."
}

$policyNote = if ($bump -notin $policy.AllowedBumps) {
    "The ``$bump`` upgrade is outside ``allowed_bumps`` and is fail-closed."
}
elseif ($bump -eq 'major') {
    'Major upgrades always require explicit approval. Automatic approval was downgraded to required.'
}
else {
    'The resolved release satisfies the configured update policy.'
}
$status.disposition = if ($bump -notin $policy.AllowedBumps) { 'blocked-by-policy' } elseif ($policy.Mode -eq 'notify') { 'notified' } else { 'preparing-pr' }
$status.drift_started_at = Resolve-DriftStartedAt -ExistingIssue $existingIssue -Now $now
$status.drift_age_days = Get-CompletedElapsedDays -Start ([datetime]$status.drift_started_at) -Now $now
$issue = Set-DriftIssue -Status $status -AllowedBumps $policy.AllowedBumps -PolicyNote $policyNote -ExistingIssue $existingIssue
$status.issue_url = [string]$issue.url

if ($policy.Mode -eq 'pull-request' -and $bump -in $policy.AllowedBumps) {
    try {
        $prUrl = Invoke-UpgradePullRequest -RepoRoot $repoRoot -Policy $policy -Release $release `
            -CurrentVersion $current.Text -IssueUrl $status.issue_url -EffectiveApproval $effectiveApproval `
            -GeneratedPrs $generatedPrs
        $status.pr_url = $prUrl
        $status.disposition = if ($prUrl) {
            if ($effectiveApproval -eq 'automatic') { 'auto-merge-pending' } else { 'approval-required' }
        }
        else {
            'sync-no-change'
        }
        $null = Set-DriftIssue -Status $status -AllowedBumps $policy.AllowedBumps -PolicyNote $policyNote -ExistingIssue $issue
    }
    catch {
        if ($_.Exception.Data.Contains('BasecoatPrUrl')) {
            $status.pr_url = [string]$_.Exception.Data['BasecoatPrUrl']
        }
        $status.disposition = 'delivery-failed'
        $failureNote = 'Pull-request delivery failed closed. The preserved worktree and branch can be inspected before retrying.'
        $null = Set-DriftIssue -Status $status -AllowedBumps $policy.AllowedBumps `
            -PolicyNote $failureNote -ExistingIssue $issue
        Write-Status -Status $status -Path (Join-Path $repoRoot $StatusPath)
        throw
    }
}

Write-Status -Status $status -Path (Join-Path $repoRoot $StatusPath)
