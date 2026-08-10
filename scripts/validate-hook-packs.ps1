[CmdletBinding()]
param(
    [string]$TemplateRoot = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) '.github\template-repos\repo-template')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing required file: $Path"
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

function Assert-Condition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$templateRootPath = Resolve-Path $TemplateRoot
$manifestPath = Join-Path $templateRootPath '.github\basecoat-hook-profiles.json'
$hooksDir = Join-Path $templateRootPath '.github\hooks'
$scriptDir = Join-Path $templateRootPath 'scripts\hooks'

$manifest = Read-JsonFile -Path $manifestPath
Assert-Condition ($manifest.version -eq 1) 'Hook profile manifest version must be 1.'
Assert-Condition (-not [string]::IsNullOrWhiteSpace($manifest.defaultProfile)) 'Hook profile manifest must declare defaultProfile.'
Assert-Condition ($null -ne $manifest.profiles) 'Hook profile manifest must declare profiles.'
Assert-Condition ($null -ne $manifest.packs) 'Hook profile manifest must declare packs.'

$profileNames = @($manifest.profiles.PSObject.Properties.Name)
$packNames = @($manifest.packs.PSObject.Properties.Name)
Assert-Condition ($profileNames.Count -gt 0) 'Hook profile manifest must declare at least one profile.'
Assert-Condition ($packNames.Count -gt 0) 'Hook profile manifest must declare at least one pack.'
Assert-Condition ($profileNames -contains $manifest.defaultProfile) "Default profile '$($manifest.defaultProfile)' must exist in profiles."

$requiredProfiles = @('none', 'memory', 'guardrails', 'lane-closeout', 'standard')
foreach ($profileName in $requiredProfiles) {
    Assert-Condition ($profileNames -contains $profileName) "Hook profile manifest missing required profile '$profileName'."
}

$allowedEvents = @('SessionStart', 'Stop', 'preToolUse', 'postToolUse', 'errorOccurred')
$disallowedEvents = @{
    'SessionEnd' = 'Use Stop in .github/hooks JSON files instead of SessionEnd.'
    'OnError' = 'Use errorOccurred in .github/hooks JSON files instead of OnError.'
    'OnBudgetExceeded' = 'Use postToolUse plus a budget-threshold handler instead of OnBudgetExceeded.'
}

$expectedPackEvents = @{
    '10-session-memory' = @('SessionStart', 'Stop')
    '20-tool-guardrails' = @('preToolUse', 'postToolUse')
    '30-error-and-budget' = @('errorOccurred', 'postToolUse')
    '40-lane-closeout' = @('Stop')
}

foreach ($packName in $packNames) {
    $packInfo = $manifest.packs.$packName
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($packInfo.path)) "Pack '$packName' must declare a path."

    $packPath = Join-Path $templateRootPath $packInfo.path.Replace('/', '\')
    $pack = Read-JsonFile -Path $packPath
    Assert-Condition ($pack.version -eq 1) "Pack '$packName' must declare version 1."
    Assert-Condition ($null -ne $pack.hooks) "Pack '$packName' must declare a hooks object."

    $eventNames = @($pack.hooks.PSObject.Properties.Name)
    Assert-Condition ($eventNames.Count -gt 0) "Pack '$packName' must declare at least one hook event."

    foreach ($disallowedEvent in $disallowedEvents.Keys) {
        Assert-Condition (-not ($eventNames -contains $disallowedEvent)) "Pack '$packName' uses disallowed event '$disallowedEvent'. $($disallowedEvents[$disallowedEvent])"
    }

    foreach ($eventName in $eventNames) {
        Assert-Condition ($allowedEvents -contains $eventName) "Pack '$packName' uses unsupported event '$eventName'."

        $handlers = @($pack.hooks.$eventName)
        Assert-Condition ($handlers.Count -gt 0) "Pack '$packName' event '$eventName' must declare at least one handler."

        foreach ($handler in $handlers) {
            Assert-Condition ($handler.type -eq 'command') "Pack '$packName' event '$eventName' must use type 'command'."
            $timeoutValue = [int]$handler.timeoutSec
            Assert-Condition ($timeoutValue -gt 0) "Pack '$packName' event '$eventName' must declare a positive timeoutSec."
            Assert-Condition (-not [string]::IsNullOrWhiteSpace($handler.bash)) "Pack '$packName' event '$eventName' must declare a bash handler for Cloud Agent support."
            Assert-Condition (-not [string]::IsNullOrWhiteSpace($handler.powershell)) "Pack '$packName' event '$eventName' must declare a powershell handler for local Windows support."

            $bashPath = Join-Path $templateRootPath $handler.bash.Replace('/', '\')
            $powershellPath = Join-Path $templateRootPath $handler.powershell.Replace('/', '\')
            Assert-Condition (Test-Path $bashPath) "Pack '$packName' event '$eventName' references missing bash script '$($handler.bash)'."
            Assert-Condition (Test-Path $powershellPath) "Pack '$packName' event '$eventName' references missing PowerShell script '$($handler.powershell)'."
        }
    }

    $expectedEvents = $expectedPackEvents[$packName]
    if ($null -ne $expectedEvents) {
        $unexpected = @($eventNames | Where-Object { $_ -notin $expectedEvents })
        $missing = @($expectedEvents | Where-Object { $_ -notin $eventNames })
        Assert-Condition ($unexpected.Count -eq 0) "Pack '$packName' declares unexpected events: $($unexpected -join ', ')."
        Assert-Condition ($missing.Count -eq 0) "Pack '$packName' is missing expected events: $($missing -join ', ')."
    }
}

$budgetPack = Read-JsonFile -Path (Join-Path $hooksDir '30-error-and-budget.json')
$budgetHandlers = @($budgetPack.hooks.postToolUse)
Assert-Condition ($budgetHandlers.Count -eq 1) '30-error-and-budget.json must have exactly one postToolUse handler for budget threshold handling.'
Assert-Condition ($budgetHandlers[0].bash -eq './scripts/hooks/budget-threshold.sh') 'Budget threshold handler must use ./scripts/hooks/budget-threshold.sh.'
Assert-Condition ($budgetHandlers[0].powershell -eq './scripts/hooks/budget-threshold.ps1') 'Budget threshold handler must use ./scripts/hooks/budget-threshold.ps1.'

$lanePack = Read-JsonFile -Path (Join-Path $hooksDir '40-lane-closeout.json')
$laneHandlers = @($lanePack.hooks.Stop)
Assert-Condition ($laneHandlers.Count -eq 1) '40-lane-closeout.json must have exactly one Stop handler.'
Assert-Condition ($laneHandlers[0].bash -eq './scripts/hooks/lane-closeout-safe.sh') 'Lane closeout must use lane-closeout-safe.sh.'
Assert-Condition ($laneHandlers[0].powershell -eq './scripts/hooks/lane-closeout-safe.ps1') 'Lane closeout must use lane-closeout-safe.ps1.'

$lanePowerShell = Get-Content (Join-Path $scriptDir 'lane-closeout-safe.ps1') -Raw
$laneBash = Get-Content (Join-Path $scriptDir 'lane-closeout-safe.sh') -Raw
foreach ($content in @($lanePowerShell, $laneBash)) {
    Assert-Condition ($content -match 'wip/') 'Lane closeout handler must preserve dirty work on a wip/ ref.'
    Assert-Condition ($content -match 'PARKED') 'Lane closeout handler must record PARKED state.'
    Assert-Condition ($content -notmatch 'reset\s+--hard') 'Lane closeout handler must not hard reset.'
    Assert-Condition ($content -notmatch 'clean\s+-[a-zA-Z]*f') 'Lane closeout handler must not force-clean.'
    Assert-Condition ($content -notmatch 'branch\s+-D') 'Lane closeout handler must not force-delete branches.'
}

foreach ($profileName in $profileNames) {
    $profile = $manifest.profiles.$profileName
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($profile.description)) "Profile '$profileName' must include a description."

    $enabledPacks = @($profile.enabledHookPacks)
    foreach ($enabledPack in $enabledPacks) {
        Assert-Condition ($packNames -contains $enabledPack) "Profile '$profileName' references unknown pack '$enabledPack'."
    }
}

$hooksDocPath = Join-Path $templateRootPath '..\..\..\docs\reference\hooks.md'
$hooksDoc = Get-Content $hooksDocPath -Raw
Assert-Condition ($hooksDoc -match [regex]::Escape('.github/basecoat-hook-profiles.json')) 'docs/reference/hooks.md must document .github/basecoat-hook-profiles.json.'
Assert-Condition ($hooksDoc -match 'Onboarding hook packs') 'docs/reference/hooks.md must include the onboarding hook packs section.'
Assert-Condition ($hooksDoc -match '\| Profile \| Enabled packs \| Platform support \|') 'docs/reference/hooks.md must include the onboarding profile support matrix.'
Assert-Condition ($hooksDoc -match '40-lane-closeout') 'docs/reference/hooks.md must document the safe lane-closeout hook pack.'

$agentPath = Join-Path $templateRootPath '..\..\..\agents\basecoat-10-core-project-onboarding.agent.md'
$agentContent = Get-Content $agentPath -Raw
Assert-Condition ($agentContent -match '`hook_profile`') 'Project onboarding agent must document the hook_profile input.'
Assert-Condition ($agentContent -match [regex]::Escape('.github/basecoat-hook-profiles.json')) 'Project onboarding agent must mention the hook profile manifest.'
Assert-Condition ($agentContent -match [regex]::Escape('.github/hooks/')) 'Project onboarding agent must mention .github/hooks pack files.'

$sampleTemplatePath = Join-Path $templateRootPath 'sample-repo-template.md'
$sampleTemplate = Get-Content $sampleTemplatePath -Raw
Assert-Condition ($sampleTemplate -match [regex]::Escape('.github/basecoat-hook-profiles.json')) 'Sample repo template guide must mention .github/basecoat-hook-profiles.json.'
Assert-Condition ($sampleTemplate -match [regex]::Escape('.github/hooks/')) 'Sample repo template guide must mention .github/hooks/.'

Write-Host 'Hook pack contract validation passed' -ForegroundColor Green
