function Test-BaseCoatDistributionExcluded {
    param([string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    $frontmatterPattern = '(?m)\A---[ \t]*\r?\n([\s\S]*?)^---[ \t]*\r?(?:\n|$)'
    if ($content -match '\A---[ \t]*\r?\n' -and
        $content -notmatch $frontmatterPattern) {
        throw "Invalid distribution metadata: $Path (unterminated frontmatter)"
    }
    if ($content -match $frontmatterPattern) {
        $fields = @([regex]::Matches($Matches[1], '(?im)^distribute[ \t]*:[^\r\n]*'))
        if ($fields.Count -gt 1) { throw "Invalid distribution metadata: $Path (duplicate distribute key)" }
        if ($fields.Count -eq 0) { return $false }
        $field = $fields[0].Value
        if ($field -cnotmatch '^distribute[ \t]*:') { throw "Invalid distribution metadata: $Path (key must be lowercase)" }
        $value = ($field -replace '^distribute[ \t]*:[ \t]*', '').Trim()
        # Quoted values are YAML strings, not a boolean exclusion.
        if ($value -match '^"[^"]*"([ \t]+#.*)?$|^''[^'']*''([ \t]+#.*)?$') { return $false }
        $value = ($value -replace '[ \t]+#.*$', '').Trim()
        if ($value -cnotmatch '^(true|True|TRUE|false|False|FALSE)$') {
            throw "Invalid distribution metadata: $Path (expected a boolean scalar)"
        }
        return $value -ieq 'false'
    }
    return $false
}

function Get-BaseCoatDistributionExclusions {
    param([Parameter(Mandatory)][string]$Root)
    $catalog = Join-Path $Root 'instructions'
    if (-not (Test-Path -LiteralPath $catalog)) { return }
    $items = @((Get-Item -LiteralPath $catalog -Force))
    $items += @(Get-ChildItem -LiteralPath $catalog -File -Filter '*.instructions.md')
    foreach ($item in $items) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Unsafe distribution source: $($item.FullName) (linked instruction path)"
        }
        if (-not $item.PSIsContainer -and (Test-BaseCoatDistributionExcluded $item.FullName)) {
            "instructions/$($item.Name)"
        }
    }
}

function Remove-BaseCoatDistributionExcluded {
    param([Parameter(Mandatory)][string]$Root)

    $excluded = @(Get-BaseCoatDistributionExclusions -Root $Root)
    foreach ($relative in @('.github', '.github/base-coat', '.github/instructions', '.github/base-coat/instructions', '.agents', '.agents/instructions')) {
        $path = Join-Path $Root $relative
        if ((Test-Path -LiteralPath $path) -and
            ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Unsafe distribution destination: $path"
        }
    }

    # Apply canonical instruction exclusions to packaged reference/discoverable mirrors.
    foreach ($prefix in @('', '.github/base-coat', '.github', '.agents')) {
        foreach ($relative in $excluded) {
            $path = Join-Path $Root (($prefix + '/' + $relative).TrimStart('/'))
            if (Test-Path -LiteralPath $path) {
                if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    throw "Unsafe distribution destination: $path"
                }
                Remove-Item -LiteralPath $path -Force
            }
        }
        $manifestPath = Join-Path $Root (($prefix + '/asset-manifest.json').TrimStart('/'))
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            if ((Get-Item -LiteralPath $manifestPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Unsafe distribution manifest: $manifestPath"
            }
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $manifest.assets = @($manifest.assets | Where-Object {
                $assetPath = $_.path
                -not @($excluded | Where-Object { $assetPath -eq $_ -or $assetPath.StartsWith($_ + '/') }).Count
            })
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        }
    }
    foreach ($relative in $excluded) { Write-Host "Excluded internal instruction: $relative" }
}
