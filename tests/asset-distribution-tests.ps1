$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$validator = Join-Path $repoRoot 'scripts/validate-asset-distribution.ps1'

if (-not (Test-Path $validator)) {
    throw "Asset distribution validator not found: $validator"
}

function New-SkillFixture {
    param([string]$Root, [string]$Name, [string]$Frontmatter)
    $dir = Join-Path $Root "skills/$Name"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Content -Path (Join-Path $dir 'SKILL.md') -Value "---`nname: $Name`ndescription: fixture`n$Frontmatter`n---`n"
}

function Invoke-Validator {
    param([string]$Root)
    $failed = $false
    try { & $validator -RootDir $Root *> $null } catch { $failed = $true }
    return -not $failed
}

# Positive: the real repository (all-defaults, pre-migration) must pass.
& $validator -RootDir $repoRoot | Out-Null

$cases = @(
    # Frontmatter, expectPass, label
    @{ fm = "ships: true`ndogfood: false`nstatus: active"; pass = $true; desc = 'shipped/active' },
    @{ fm = "ships: false`ndogfood: true"; pass = $true; desc = 'internal-only (ships:false,dogfood:true)' },
    @{ fm = "ships: true`ndogfood: true`nstatus: active"; pass = $true; desc = 'both' },
    @{ fm = "ships: false`ndogfood: false`nstatus: deprecated"; pass = $true; desc = 'neither but deprecated' },
    @{ fm = "ships: false`ndogfood: false`nstatus: experimental"; pass = $true; desc = 'neither but experimental' },
    @{ fm = "status: active"; pass = $true; desc = 'defaults only' },
    @{ fm = "ships: nope"; pass = $false; desc = 'invalid ships value' },
    @{ fm = "dogfood: maybe"; pass = $false; desc = 'invalid dogfood value' },
    @{ fm = "status: draft"; pass = $false; desc = 'invalid status value' },
    @{ fm = "ships: false`ndogfood: false"; pass = $false; desc = 'neither without staged status' }
)

$failures = @()
foreach ($case in $cases) {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("asset-dist-" + [guid]::NewGuid().ToString('N'))
    try {
        New-SkillFixture -Root $root -Name 'fixture' -Frontmatter $case.fm
        $result = Invoke-Validator -Root $root
        if ($result -ne $case.pass) {
            $failures += "case '$($case.desc)': expected pass=$($case.pass) but got pass=$result"
        }
    }
    finally {
        if (Test-Path $root) { Remove-Item -Recurse -Force $root }
    }
}

# A body fenced-code sample using `status:` must not be mistaken for frontmatter.
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("asset-dist-" + [guid]::NewGuid().ToString('N'))
try {
    $dir = Join-Path $root 'skills/body-status'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $content = @(
        '---'
        'name: body-status'
        'description: fixture'
        '---'
        ''
        'Example template:'
        '```yaml'
        'status: <draft|ready-for-review|approved>'
        '```'
    ) -join "`n"
    Set-Content -Path (Join-Path $dir 'SKILL.md') -Value $content
    if (-not (Invoke-Validator -Root $root)) {
        $failures += "body-only 'status:' in a fenced code block was wrongly treated as frontmatter"
    }
}
finally {
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
}

# Manifest invariant: the generator must NEVER emit distribution metadata for a
# default-classified asset (ships:true, dogfood:false, status:active). Emitting
# defaults for every asset is pure churn and needless adoption-SHA noise. This
# holds now (no non-defaults exist) and must keep holding as the catalog is
# seeded, so we assert it against the real manifest.
$manifestPath = Join-Path $repoRoot 'asset-manifest.json'
if (Test-Path $manifestPath) {
    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
    foreach ($asset in $manifest.assets) {
        $hasDist = $asset.PSObject.Properties.Name -contains 'distribution'
        if (-not $hasDist) { continue }
        $isDefault = ($asset.ships -eq $true) -and ($asset.dogfood -eq $false) -and ($asset.status -eq 'active')
        if ($isDefault) {
            $failures += "manifest emits default distribution metadata for $($asset.path) (defaults must be omitted)"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Asset distribution tests FAILED:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    throw "Asset distribution tests failed with $($failures.Count) failure(s)"
}

Write-Host "Asset distribution tests passed ($($cases.Count) cases + body-scope + real-repo + manifest-omit-defaults)."
