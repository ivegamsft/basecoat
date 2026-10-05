param([string]$PowerShell = 'pwsh')

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scratch = Join-Path $repoRoot 'test-results\distribution-exclusion'
$source = Join-Path $scratch 'source'
$consumer = Join-Path $scratch 'consumer'
$bootstrapConsumer = Join-Path $scratch 'bootstrap-consumer'
$bash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path $bash)) { $bash = (Get-Command bash -ErrorAction SilentlyContinue).Source }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments *> (Join-Path $scratch 'last-command.log')
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed ($LASTEXITCODE): $(Get-Content (Join-Path $scratch 'last-command.log') -Raw)"
    }
}

function Invoke-ConsumerSync([string]$Path) {
    Push-Location $Path
    try {
        $env:BASECOAT_REPO = "file://$($source -replace '\\','/')"
        $env:BASECOAT_REF = 'fixture'
        $env:BASECOAT_TEST_SOURCE_PATH = $source
        Invoke-Checked $PowerShell @('-NoProfile', '-File', (Join-Path $repoRoot 'sync.ps1'))
    }
    finally { Pop-Location }
}

function Assert-Excluded([string]$Root) {
    foreach ($path in @(
        '.github\base-coat\instructions\fixture-hidden.instructions.md',
        '.github\instructions\fixture-hidden.instructions.md'
    )) {
        Assert-True (-not (Test-Path (Join-Path $Root $path))) "Excluded asset leaked: $path"
    }
    foreach ($name in @('absent', 'true', 'quoted', 'body', 'empty')) {
        $destination = Join-Path $Root ".github\instructions\fixture-$name.instructions.md"
        Assert-True (Test-Path $destination) "Normal asset lost: $name"
        $expected = (Get-Content (Join-Path $source "instructions\fixture-$name.instructions.md") -Raw).Replace("`r`n", "`n")
        $actual = (Get-Content $destination -Raw).Replace("`r`n", "`n")
        Assert-True ($actual -ceq $expected) "Normal asset content changed: $Root/$name"
    }
    foreach ($path in @('.github\agents\fixture.agent.md', '.github\prompts\fixture.prompt.md', '.github\skills\fixture\SKILL.md')) {
        Assert-True (Test-Path (Join-Path $Root $path)) "Instruction-only exclusion affected another asset type: $path"
    }
}

$savedTemp = $env:TEMP; $savedTmp = $env:TMP; $savedTmpDir = $env:TMPDIR
$savedRepo = $env:BASECOAT_REPO; $savedRef = $env:BASECOAT_REF
$savedSource = $env:BASECOAT_TEST_SOURCE_PATH
try {
    New-Item -ItemType Directory -Force -Path $scratch | Out-Null
    $env:TEMP = $scratch; $env:TMP = $scratch; $env:TMPDIR = $scratch -replace '\\', '/'
    . (Join-Path $repoRoot 'scripts\distribution-filter.ps1')
    $parserFile = Join-Path $scratch 'parser.instructions.md'
    foreach ($case in @(
        @{ value = 'false'; excluded = $true },
        @{ value = 'FALSE'; excluded = $true },
        @{ value = 'False # internal'; excluded = $true },
        @{ value = ' true '; excluded = $false },
        @{ value = '"false"'; excluded = $false },
        @{ value = '"false # string" # outside comment'; excluded = $false },
        @{ value = "'false'"; excluded = $false },
        @{ value = 'false-positive'; invalid = $true },
        @{ value = ''; invalid = $true },
        @{ value = "false`ndistribute: true"; invalid = $true }
    )) {
        $text = "---`ndescription: fixture`ndistribute : $($case.value)`n---`n`ndistribute: false"
        if ($case.value -eq 'FALSE') { $text = $text -replace "`n", "`r`n" }
        [IO.File]::WriteAllText($parserFile, $text, [Text.UTF8Encoding]::new($true))
        $invalid = $case.ContainsKey('invalid')
        $psResult = 1
        try { if (Test-BaseCoatDistributionExcluded $parserFile) { $psResult = 0 } }
        catch { $psResult = 2 }
        Assert-True ($psResult -eq $(if ($invalid) { 2 } elseif ($case.excluded) { 0 } else { 1 })) "PowerShell parser mismatch: $($case.value)"
        $shellFile = $parserFile -replace '\\', '/'
        $shellHelper = (Join-Path $repoRoot 'scripts\distribution-filter.sh') -replace '\\', '/'
        & $bash -c 'source "$1"; basecoat_distribution_excluded "$2"' fixture $shellHelper $shellFile *> $null
        Assert-True ($LASTEXITCODE -eq $psResult) "Bash parser mismatch: $($case.value)"
    }
    # Materialize current working files, not HEAD, so validation covers uncommitted changes.
    New-Item -ItemType Directory -Force -Path $source | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $repoRoot -Force) {
        if ($item.Name -in @('.git', 'test-results', 'dist', 'site', 'node_modules', '.venv')) { continue }
        Copy-Item -LiteralPath $item.FullName -Destination $source -Recurse -Force
    }
    # Keep the runtime fixture small; real-catalog behavior is covered by sync-tests.
    foreach ($directory in @('agents', 'skills', 'prompts', 'instructions')) {
        Remove-Item (Join-Path $source $directory) -Recurse -Force
        New-Item -ItemType Directory -Force -Path (Join-Path $source $directory) | Out-Null
    }
    Set-Content (Join-Path $source 'agents\fixture.agent.md') "---`nname: fixture`ndescription: fixture`ndistribute: false`n---`n`n# Fixture"
    Set-Content (Join-Path $source 'prompts\fixture.prompt.md') "---`ndescription: fixture`ndistribute: false`n---`n`n# Fixture"
    New-Item -ItemType Directory -Force -Path (Join-Path $source 'skills\fixture') | Out-Null
    Set-Content (Join-Path $source 'skills\fixture\SKILL.md') "---`nname: fixture`ndescription: fixture`ndistribute: false`n---`n`n# Fixture"
    $cases = @{
        hidden = 'distribute : false   # internal'
        absent = 'description: fixture'
        true = 'distribute: true'
        quoted = 'distribute: "false"'
        body = "description: fixture`n---`n`ndistribute: false"
        empty = "---`n"
    }
    foreach ($name in $cases.Keys) {
        $fixtureContent = "---`ndescription: fixture`napplyTo: '**/*'`n$($cases[$name])`n---`n`n# Fixture"
        if ($name -eq 'empty') { $fixtureContent = "---`n---`n`n# Fixture" }
        Set-Content (Join-Path $source "instructions\fixture-$name.instructions.md") $fixtureContent
    }
    Invoke-Checked git @('-C', $source, 'init', '-b', 'fixture')
    Invoke-Checked $PowerShell @('-NoProfile', '-File', (Join-Path $source 'scripts\generate-asset-manifest.ps1'))
    Invoke-Checked git @('-C', $source, 'add', '.')
    Invoke-Checked git @('-C', $source, '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
    foreach ($path in @($consumer, $bootstrapConsumer)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
        Invoke-Checked git @('-C', $path, 'init')
    }
    Invoke-ConsumerSync $consumer
    Assert-Excluded $consumer
    $consumerManifest = Get-Content (Join-Path $consumer '.github\base-coat\asset-manifest.json') -Raw | ConvertFrom-Json
    Assert-True (-not @($consumerManifest.assets | Where-Object path -Match 'fixture-hidden').Count) 'Consumer manifest advertises excluded instruction'

    # Exclusion is a retirement: the shared guidance lock owns and hashes stale files.
    $hidden = Join-Path $source 'instructions\fixture-hidden.instructions.md'
    Set-Content $hidden "---`ndescription: fixture`napplyTo: '**/*'`ndistribute: true`n---`n`n# Fixture"
    Invoke-ConsumerSync $consumer
    $installed = Join-Path $consumer '.github\instructions\fixture-hidden.instructions.md'
    Assert-True (Test-Path $installed) 'True asset did not install'
    Set-Content $hidden "---`ndescription: fixture`napplyTo: '**/*'`ndistribute: false`n---`n`n# Fixture"
    Invoke-ConsumerSync $consumer
    Assert-True (-not (Test-Path $installed)) 'Owned stale asset was not pruned'

    Set-Content $hidden "---`ndescription: fixture`napplyTo: '**/*'`ndistribute: true`n---`n`n# Fixture"
    Invoke-ConsumerSync $consumer
    Add-Content $installed 'consumer change'
    Set-Content $hidden "---`ndescription: fixture`napplyTo: '**/*'`ndistribute: false`n---`n`n# Fixture"
    $modifiedContent = Get-Content $installed -Raw
    $failed = $false
    try { Invoke-ConsumerSync $consumer } catch {
        $failed = $_ -match 'GUIDANCE_CONTENT_MODIFIED'
    }
    Assert-True $failed 'Modified stale asset must fail closed'
    Assert-True ((Get-Content $installed -Raw) -eq $modifiedContent) 'Consumer modifications were deleted'
    foreach ($modified in @($false, $true)) {
        $legacyConsumer = Join-Path $scratch "legacy-$modified"
        $legacyRoot = Join-Path $legacyConsumer '.github\base-coat'
        New-Item -ItemType Directory -Force -Path $legacyRoot, (Join-Path $legacyConsumer '.github\instructions') | Out-Null
        Invoke-Checked git @('-C', $legacyConsumer, 'init')
        $legacyInstalled = Join-Path $legacyConsumer '.github\instructions\fixture-hidden.instructions.md'
        Set-Content $legacyInstalled "# Previously distributed instruction"
        $oldBlob = (& git hash-object -- $legacyInstalled).Trim()
        @{ assets = @(@{ path = 'instructions/fixture-hidden.instructions.md'; sha = $oldBlob }) } |
            ConvertTo-Json -Depth 4 | Set-Content (Join-Path $legacyRoot 'asset-manifest.json')
        if ($modified) { Add-Content $legacyInstalled 'consumer change' }
        Set-Content (Join-Path $legacyRoot '.overlay-managed-files') '.github/instructions/fixture-hidden.instructions.md'
        Invoke-ConsumerSync $legacyConsumer
        Assert-True ((Test-Path $legacyInstalled) -eq $modified) 'Legacy exclusion must prune only verified unchanged instructions'
    }
    $malformed = Join-Path $source 'instructions\fixture-invalid.instructions.md'
    Set-Content $malformed "---`ndistribute: false`ndistribute: true`n---"
    $beforeInvalid = (Get-FileHash (Join-Path $consumer '.github\base-coat\asset-manifest.json')).Hash
    $failed = $false
    try { Invoke-ConsumerSync $consumer } catch {
        $failed = $_ -match 'Invalid distribution metadata' -and $_ -match 'fixture-invalid'
    }
    Assert-True $failed 'Invalid metadata must report its source path'
    Assert-True ((Get-FileHash (Join-Path $consumer '.github\base-coat\asset-manifest.json')).Hash -eq $beforeInvalid) 'Invalid metadata partially changed canonical payload'
    Remove-Item $malformed

    # Unmanaged co-located guidance must survive bootstrap and its refresh.
    New-Item -ItemType Directory -Force -Path (Join-Path $bootstrapConsumer '.github\instructions') | Out-Null
    $foreign = Join-Path $bootstrapConsumer '.github\instructions\consumer-owned.instructions.md'
    Set-Content $foreign 'consumer owned'
    Invoke-Checked git @('-C', $source, 'add', '.')
    Invoke-Checked git @('-C', $source, '-c', 'user.name=fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'retire fixture')
    Push-Location $bootstrapConsumer
    try {
        foreach ($refresh in 1..2) {
            Invoke-Checked $PowerShell @('-NoProfile', '-File', (Join-Path $repoRoot 'scripts\bootstrap-basecoat.ps1'),
                '-Silent', '-SkipPR', '-BasecoatRepo', "file://$($source -replace '\\','/')", '-Ref', 'fixture')
            Assert-Excluded $bootstrapConsumer
            Assert-True ((Get-Content $foreign -Raw).Trim() -eq 'consumer owned') 'Bootstrap deleted foreign guidance'
        }
    }
    finally { Pop-Location }

    Invoke-Checked $PowerShell @('-NoProfile', '-File', (Join-Path $source 'scripts\generate-asset-manifest.ps1'))
    $manifest = Get-Content (Join-Path $source 'asset-manifest.json') -Raw | ConvertFrom-Json
    Assert-True (@($manifest.assets | Where-Object path -Match 'fixture-hidden').Count -eq 1) 'Source inventory must retain internal instructions'

    # Both package implementations must filter canonical and projected copies.
    New-Item -ItemType Directory -Force -Path (Join-Path $source '.github\instructions') | Out-Null
    Copy-Item $hidden (Join-Path $source '.github\instructions\fixture-hidden.instructions.md')
    foreach ($packager in @('ps1', 'sh')) {
        if ($packager -eq 'ps1') {
            Invoke-Checked $PowerShell @('-NoProfile', '-File', (Join-Path $source 'scripts\package-basecoat.ps1'), $source)
        }
        elseif ($bash) {
            if ($env:OS -eq 'Windows_NT') {
                Invoke-Checked $bash @('-c', 'exec bash "$(cygpath -u "$1")" "$(cygpath -u "$2")"', 'fixture',
                    (Join-Path $source 'scripts\package-basecoat.sh'), $source)
            }
            else { Invoke-Checked $bash @((Join-Path $source 'scripts\package-basecoat.sh'), $source) }
        }
        else { throw 'Bash is required for packaging parity' }
        $stage = Join-Path $source 'dist\stage\base-coat'
        Assert-True (-not (Test-Path (Join-Path $stage 'instructions\fixture-hidden.instructions.md'))) "$packager stage leaked internal instruction"
        Assert-True (-not (Test-Path (Join-Path $stage '.github\instructions\fixture-hidden.instructions.md'))) "$packager stage leaked projected instruction"
        $packagedManifest = Get-Content (Join-Path $stage 'asset-manifest.json') -Raw | ConvertFrom-Json
        Assert-True (-not @($packagedManifest.assets | Where-Object path -Match 'fixture-hidden').Count) "$packager manifest leaked internal instruction"
        Assert-True (Test-Path (Join-Path $stage 'instructions\fixture-quoted.instructions.md')) "$packager wrongly excluded quoted false"
        $zip = Get-ChildItem (Join-Path $source 'dist') -Filter '*.zip' | Select-Object -First 1
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
        try {
            Assert-True (-not @($archive.Entries | Where-Object FullName -Match 'fixture-hidden').Count) "$packager ZIP leaked internal assets"
        }
        finally { $archive.Dispose() }
        $tar = Get-ChildItem (Join-Path $source 'dist') -Filter '*.tar.gz' | Select-Object -First 1
        $entries = & tar -tzf $tar.FullName
        Assert-True (-not @($entries | Where-Object { $_ -match 'fixture-hidden' }).Count) "$packager tar leaked internal assets"
    }
    $bashConsumer = Join-Path $scratch 'bash-consumer'
    New-Item -ItemType Directory -Force -Path $bashConsumer | Out-Null
    Invoke-Checked git @('-C', $bashConsumer, 'init')
    Push-Location $bashConsumer
    try {
        Invoke-Checked $bash @( ((Join-Path $source 'sync.sh') -replace '\\','/') )
        Assert-Excluded $bashConsumer
    }
    finally { Pop-Location }
    # Run the actual GHCP stage commands locally without dispatching publication.
    $workflow = Get-Content (Join-Path $repoRoot '.github\workflows\package-basecoat.yml') -Raw
    Assert-True ($workflow.Contains('cp -R dist/stage/base-coat/instructions dist/ghcp-stage/')) 'GHCP bypasses filtered instruction stage'
    $ghcpCommands = [regex]::Match($workflow, '(?s)- name: Create GHCP ZIP\r?\n\s+run: \|\r?\n(.*?)\r?\n\s+- name: Verify').Groups[1].Value
    Assert-True ($ghcpCommands.Length -gt 0) 'GHCP stage extraction failed'
    Push-Location $source
    try {
        $zipFallback = 'if ! command -v zip >/dev/null; then zip() { python3 -m zipfile -c "$2" .; }; fi'
        Invoke-Checked $bash @('-c', ($zipFallback + "`n" + ($ghcpCommands -replace '(?m)^          ', '')))
    }
    finally { Pop-Location }
    $ghcpArchive = [IO.Compression.ZipFile]::OpenRead((Join-Path $source 'dist\basecoat-ghcp.zip'))
    try {
        Assert-True (-not @($ghcpArchive.Entries | Where-Object FullName -Match 'fixture-hidden').Count) 'GHCP ZIP leaked internal instruction'
        Assert-True (@($ghcpArchive.Entries | Where-Object FullName -Match 'fixture-true').Count -eq 1) 'GHCP ZIP dropped true instruction'
    }
    finally { $ghcpArchive.Dispose() }
    Write-Host 'Distribution exclusion tests passed: sync retirement, consumer safety, bootstrap refresh, manifest and PS/Bash archives.'
}
finally {
    $env:TEMP = $savedTemp; $env:TMP = $savedTmp; $env:TMPDIR = $savedTmpDir
    $env:BASECOAT_REPO = $savedRepo; $env:BASECOAT_REF = $savedRef; $env:BASECOAT_TEST_SOURCE_PATH = $savedSource
    if (Test-Path $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
