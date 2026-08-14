[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot '.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1'
$callablePath = Join-Path $repoRoot '.github/workflows/check-basecoat-version-callable.yml'
$distributedPath = Join-Path $repoRoot '.github/base-coat/workflows/check-version.yml'
$templatePath = Join-Path $repoRoot '.github/workflow-templates/check-basecoat-version.yml'
$scratch = Join-Path $repoRoot 'test-results/consumer-updater-tests'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) { throw "$Message Expected '$Expected', got '$Actual'." }
}

if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing updater script: $scriptPath" }
. $scriptPath -LibraryOnly

Write-Host 'Running consumer updater tests...'

$patchCurrent = ConvertTo-SemVer '4.1.0'
$patchTarget = ConvertTo-SemVer 'v4.1.1'
Assert-Equal (Compare-SemVer $patchCurrent $patchTarget) -1 'Patch drift must be detected.'
Assert-Equal (Get-SemVerBump $patchCurrent $patchTarget) 'patch' 'Patch bump classification failed.'
Assert-Equal (Get-SemVerBump (ConvertTo-SemVer '4.1.9') (ConvertTo-SemVer '4.2.0')) 'minor' 'Minor bump classification failed.'
Assert-Equal (Get-SemVerBump (ConvertTo-SemVer '4.9.9') (ConvertTo-SemVer '5.0.0')) 'major' 'Major bump classification failed.'
Assert-Equal (Get-SemVerBump (ConvertTo-SemVer '5.0.0') (ConvertTo-SemVer '4.9.9')) 'none' `
    'An ahead major version must not report a lower-order bump.'
Assert-Equal (Get-SemVerBump (ConvertTo-SemVer '4.2.0') (ConvertTo-SemVer '4.1.9')) 'none' `
    'An ahead minor version must not report patch drift.'
Assert-Equal (Compare-SemVer (ConvertTo-SemVer '4.2.0-rc.2') (ConvertTo-SemVer '4.2.0-rc.10')) -1 'Prerelease numeric ordering failed.'
Assert-Equal (Compare-SemVer (ConvertTo-SemVer '4.2.0-rc.99999999999999999999') `
    (ConvertTo-SemVer '4.2.0-rc.100000000000000000000')) -1 `
    'Oversized numeric prerelease identifiers must retain SemVer ordering.'
Assert-Equal (Compare-SemVer (ConvertTo-SemVer '4.2.0-rc.1') (ConvertTo-SemVer '4.2.0')) -1 'Stable release must sort after its prerelease.'
$prereleaseCurrent = ConvertTo-SemVer 'v4.2.0-rc.1'
Assert-Equal $prereleaseCurrent.Text '4.2.0-rc.1' 'Normalized SemVer text must preserve prerelease identifiers.'
$buildVersion = ConvertTo-SemVer 'v4.2.0-rc.1+corp.7'
Assert-Equal $buildVersion.Text '4.2.0-rc.1+corp.7' 'Normalized SemVer text must preserve build metadata.'
Assert-Equal (Compare-SemVer (ConvertTo-SemVer '4.2.0+corp.1') (ConvertTo-SemVer '4.2.0+corp.2')) 0 `
    'Build metadata must not affect SemVer precedence.'
foreach ($invalidVersion in @('01.2.3', '1.02.3', '1.2.03', '1.2.3-rc..1', '1.2.3-01', '1.2.3+build..1')) {
    $invalidRejected = $false
    try { ConvertTo-SemVer $invalidVersion | Out-Null }
    catch { $invalidRejected = $_.Exception.Message -match 'Invalid semantic version' }
    Assert-True $invalidRejected "Invalid SemVer '$invalidVersion' must be rejected."
}

$elapsedStart = [datetime]'2026-08-01T00:00:00Z'
foreach ($case in @(
    @{ Offset = [timespan]::FromHours(11) + [timespan]::FromMinutes(59); Expected = 0 },
    @{ Offset = [timespan]::FromHours(12); Expected = 0 },
    @{ Offset = [timespan]::FromHours(23) + [timespan]::FromMinutes(59); Expected = 0 },
    @{ Offset = [timespan]::FromHours(24); Expected = 1 },
    @{ Offset = [timespan]::FromDays(2) + [timespan]::FromHours(23); Expected = 2 }
)) {
    Assert-Equal (Get-CompletedElapsedDays -Start $elapsedStart -Now ($elapsedStart + $case.Offset)) `
        $case.Expected "Drift age must count completed days at offset '$($case.Offset)'."
}
Assert-Equal (Get-RunSuffix -RunId '2765' -RunAttempt '1') '2765-attempt-1' 'First run attempt suffix is invalid.'
Assert-Equal (Get-RunSuffix -RunId '2765' -RunAttempt '2') '2765-attempt-2' 'Rerun suffix must be unique.'
$mappingPath = Join-Path $repoRoot 'test-results/mapped-worktree'
$mappingLines = @(
    "worktree $mappingPath",
    'HEAD 0123456789abcdef0123456789abcdef01234567',
    'branch refs/heads/chore/basecoat-update-v4.2.0-2765-attempt-2',
    ''
)
Assert-True (Test-ExpectedWorktreeMapping -PorcelainLines $mappingLines -WorktreePath $mappingPath `
    -Branch 'chore/basecoat-update-v4.2.0-2765-attempt-2') 'Expected worktree branch mapping was not recognized.'
Assert-True (-not (Test-ExpectedWorktreeMapping -PorcelainLines $mappingLines -WorktreePath $mappingPath `
    -Branch 'chore/basecoat-update-v4.2.0-2765-attempt-1')) 'Cleanup mapping must reject a different attempt branch.'

$config = @(
    'source: "https://github.com/example/basecoat.git" # canonical source',
    "mirror: 'https://github.corp.example/platform/basecoat.git' # corporate mirror",
    'known_bad_releases:',
    '  v4.1.1: "v4.1.2" # redirect',
    'updates:',
    '  mode: "pull-request" # guarded delivery',
    "  approval: 'automatic' # branch protection still applies",
    '  allowed_bumps: [patch, minor] # no major upgrades',
    '  ref: "latest" # stable selector'
)
$policy = Get-UpdatePolicy -Lines $config -Overrides @{}
Assert-Equal $policy.Mode 'pull-request' 'Configured mode was not parsed.'
Assert-Equal $policy.Approval 'automatic' 'Configured approval was not parsed.'
Assert-Equal $policy.Mirror 'https://github.corp.example/platform/basecoat.git' 'Corporate mirror was not parsed.'
Assert-Equal $policy.KnownBad['v4.1.1'] 'v4.1.2' 'Known-bad release remapping was not parsed.'
Assert-True ($policy.AllowedBumps -contains 'patch') 'Patch must be allowed by configured policy.'
$disabledPolicy = Get-UpdatePolicy -Lines @('updates:', '  allowed_bumps: []') -Overrides @{}
Assert-Equal $disabledPolicy.AllowedBumps.Count 0 'Explicit empty allowed_bumps must fail closed instead of restoring defaults.'
Assert-Equal (Normalize-RepoSlug 'https://github.corp.example/platform/basecoat.git') `
    'github.corp.example/platform/basecoat' 'GitHub Enterprise source normalization failed.'
Assert-Equal (Normalize-RepoSlug 'https://user:password@github.com/example/basecoat.git?token=secret') `
    'example/basecoat' 'Repository slug normalization must redact credentials before parsing.'
Assert-Equal (Convert-RepoToCloneUrl 'github.corp.example/platform/basecoat') `
    'https://github.corp.example/platform/basecoat.git' 'GitHub Enterprise clone URL conversion failed.'
$nestedRefFirst = @('updates:', '  ref: latest', 'ref: v4.1.0')
Assert-Equal (Get-YamlScalar -Lines $nestedRefFirst -Key 'ref') 'v4.1.0' `
    'Top-level scalar lookup must ignore matching nested update keys.'

$defaults = Get-UpdatePolicy -Lines @() -Overrides @{}
Assert-Equal $defaults.Mode 'notify' 'Default mode must remain notify.'
Assert-Equal $defaults.Approval 'required' 'Default approval must remain required.'
Assert-True ($defaults.AllowedBumps -contains 'patch') 'Default policy must include patch bumps.'
Assert-True ($defaults.AllowedBumps -notcontains 'major') 'Default policy must fail closed for major bumps.'

$status = New-Status -CurrentVersion '4.1.0' -TargetVersion '4.1.1' -TargetTag 'v4.1.1' `
    -TargetSha ('a' * 40) -Source 'example/basecoat' -Channel 'stable' -Mode 'notify' `
    -Approval 'required' -Bump 'patch' -Disposition 'notified'
$marker = ConvertTo-IssueMarker -Status $status
Assert-True $marker.StartsWith('<!-- basecoat-consumer-update:') 'Issue marker prefix must be stable.'
Assert-True ($marker -match '"target_version":"4.1.1"') 'Issue marker must expose target version.'
$prereleaseStatus = New-Status -CurrentVersion $prereleaseCurrent.Text -TargetVersion '4.2.0' -TargetTag 'v4.2.0' `
    -TargetSha ('b' * 40) -Source 'example/basecoat' -Channel 'stable' -Mode 'notify' `
    -Approval 'required' -Bump 'patch' -Disposition 'notified'
$prereleaseMarker = ConvertTo-IssueMarker -Status $prereleaseStatus
$prereleaseIssueBody = New-IssueBody -Status $prereleaseStatus -AllowedBumps @('patch', 'minor') -PolicyNote 'test'
Assert-True ($prereleaseMarker -match '"current_version":"4\.2\.0-rc\.1"') 'Issue marker must preserve the current prerelease.'
Assert-True ($prereleaseMarker -match '"target_version":"4\.2\.0"') 'Issue marker must keep the stable target distinct.'
Assert-True ($prereleaseIssueBody -match '\|\s*Current\s*\|[^\r\n]*v4\.2\.0-rc\.1') 'Issue body must display the current prerelease.'
Assert-True ($prereleaseIssueBody -match '\|\s*Target\s*\|[^\r\n]*v4\.2\.0') 'Issue body must display the distinct stable target.'
$deliveryFailureStatus = New-Status -CurrentVersion '4.1.0' -TargetVersion '4.1.1' -TargetTag 'v4.1.1' `
    -TargetSha ('a' * 40) -Source 'example/basecoat' -Channel stable -Mode 'pull-request' `
    -Approval required -Bump patch -Disposition 'delivery-failed' -PrUrl 'https://github.com/example/consumer/pull/7'
$deliveryFailurePath = Join-Path $scratch 'delivery-failed.json'
Write-Status -Status $deliveryFailureStatus -Path $deliveryFailurePath
$persistedDeliveryFailure = Get-Content -LiteralPath $deliveryFailurePath -Raw | ConvertFrom-Json
Assert-Equal $persistedDeliveryFailure.disposition 'delivery-failed' 'Failed delivery status artifact must persist its disposition.'
Assert-Equal $persistedDeliveryFailure.pr_url 'https://github.com/example/consumer/pull/7' 'Failed delivery status artifact must retain its PR URL.'
$redactedStatus = New-Status -CurrentVersion '4.1.0' -TargetVersion '4.1.1' -TargetTag 'v4.1.1' `
    -TargetSha ('c' * 40) -Source 'https://user:password@example.test/basecoat.git?token=secret' `
    -Channel 'stable' -Mode 'notify' -Approval 'required' -Bump 'patch' -Disposition 'notified'
Assert-Equal $redactedStatus.source 'https://example.test/basecoat.git' 'Status artifacts must redact source URL credentials.'

$redactionFailure = ''
try {
    $null = Invoke-Native -Command 'pwsh' -Arguments @(
        '-NoProfile', '-Command',
        "Write-Error 'https://user:password@example.test/repo.git?token=secret-value'"
    )
}
catch {
    $redactionFailure = $_.Exception.Message
}
Assert-True ($redactionFailure -notmatch 'user:password|secret-value|token=') 'Native command failures must redact credential-bearing URLs.'
Assert-True ($redactionFailure -match 'https://example\.test/repo\.git') 'Redacted native error must retain a useful source URL.'

$callable = Get-Content -LiteralPath $callablePath -Raw
$distributed = Get-Content -LiteralPath $distributedPath -Raw
$template = Get-Content -LiteralPath $templatePath -Raw
Assert-True ($callable -match 'invoke-basecoat-consumer-update\.ps1') 'Callable workflow must invoke the consumer updater.'
Assert-True ($distributed -match 'invoke-basecoat-consumer-update\.ps1') 'Distributed workflow must invoke the consumer updater.'
Assert-True ($template -match 'repository_dispatch:') 'Template must support optional release dispatch.'
Assert-True ($template -match 'basecoat-release-published') 'Template dispatch type is missing.'
Assert-True ($template -match 'check-basecoat-version-callable\.yml@[0-9a-f]{40}') 'Template must pin the callable workflow to a full commit SHA.'
Assert-True ($template -notmatch 'check-basecoat-version-callable\.yml@v') 'Template must not invoke the write-capable callable by mutable tag.'
$pinnedCallableSha = [regex]::Match($template, 'check-basecoat-version-callable\.yml@([0-9a-f]{40})').Groups[1].Value
Assert-True ($pinnedCallableSha -match '^[0-9a-f]{40}$') 'The callable pin must be a complete commit SHA.'
$prValidation = Get-Content -LiteralPath (Join-Path $repoRoot '.github/workflows/pr-validation.yml') -Raw
Assert-True ($prValidation -match 'Validate immutable consumer callable pin') `
    'CI must validate immutable callable pin reachability separately from offline unit tests.'
Assert-True ($prValidation -match 'does not contain the finalized mixed-agent-state safeguard') `
    'CI must inspect the pinned callable content after resolving it.'
Assert-True ($callable -notmatch '@main') 'Callable must not fetch moving main.'
Assert-True ($template -match 'pull-requests:\s*write') `
    'Current PR-mode callers must grant pull-request write permission to the dedicated delivery path.'
Assert-True ($callable -match '(?ms)secrets:\s*\r?\n\s+update_token:') 'Callable must declare the dedicated update token contract.'
Assert-True ($callable -match '(?ms)secrets:.*?\r?\n\s+fetch_token:') 'Callable must declare a separate source fetch token contract.'
Assert-True ($callable -match 'BASECOAT_FETCH_HOST:\s*\$\{\{ inputs\.fetch_host \}\}') 'Callable must bind source authentication to an explicit authority.'
Assert-True ($callable -match 'BASECOAT_FETCH_TOKEN:\s*\$\{\{ secrets\.fetch_token \}\}') 'Callable must expose only the named source fetch credential.'
Assert-True ($callable -match 'BASECOAT_MIRROR_FETCH_TOKEN:\s*\$\{\{ secrets\.mirror_fetch_token \}\}') `
    'Callable must expose a separately named mirror fetch credential.'
Assert-True ($callable -match 'mirror_fetch_host:') 'Callable must authority-bind the separate mirror credential.'
Assert-True ($callable -match 'BASECOAT_UPDATE_ACTOR:\s*\$\{\{ inputs\.update_actor \}\}') `
    'Callable must support explicit GitHub App bot identity binding.'
Assert-True ($callable -match 'token:\s*\$\{\{ secrets\.update_token \|\| github\.token \}\}') 'Checkout must use the dedicated token when supplied.'
Assert-True ($callable -match 'GH_TOKEN:\s*\$\{\{ github\.token \}\}') `
    'Issue and reconciliation operations must retain the workflow token until PR delivery.'
Assert-True ($distributed -match 'GH_TOKEN:\s*\$\{\{ github\.token \}\}') `
    'The distributed updater must retain the workflow token until PR delivery.'
Assert-True ($callable -match 'Legacy notification fallback') 'Callable must preserve legacy notification consumers.'
Assert-True ($callable -match 'configure private release lookup') `
    'Legacy callers without an internal-source fetch token must receive a stable setup issue instead of failing.'
Assert-True ($callable -match 'Unable to create the legacy BaseCoat setup issue') `
    'Legacy fallback must fail if its stable setup issue cannot be persisted.'
Assert-True ($distributed -match 'configure private release lookup') `
    'Distributed legacy fallback must preserve the internal-source setup notification.'
Assert-True ($callable -match 'target_version.*?`"`".*?disposition.*?unknown') `
    'Unresolved legacy targets must be reported as unknown rather than current.'
Assert-True ($callable -match 'System\.Management\.Automation\.SemanticVersion') `
    'Callable legacy fallback must accept full SemVer values.'
Assert-True ($callable -match 'Ignoring malformed legacy BaseCoat issue marker') `
    'Callable legacy fallback must repair malformed stable markers.'
Assert-True ($callable -match 'Detect mixed agent naming state') 'Callable must preserve incomplete manual-upgrade detection.'
Assert-True ($callable -match 'basecoat-mixed-agent-state:v1') 'Mixed-agent detection must use a stable issue marker.'
Assert-True ($callable -match 'gh label view maintenance') 'Mixed-agent issue creation must treat the maintenance label as optional.'
Assert-True ($callable.IndexOf('Detect installed consumer updater') -lt $callable.IndexOf('Disable stale updater auto-merge')) `
    'Callable must detect legacy installs before selecting the delivery path.'
Assert-True ($callable.IndexOf('Disable stale updater auto-merge') -lt $callable.IndexOf('Configure pull-request delivery credentials')) `
    'Callable must disable stale auto-merge before credentialed delivery checkout.'
Assert-True ($callable -match '(?ms)Configure pull-request delivery credentials\s+if: steps\.updater\.outputs\.installed == ''true''') `
    'Callable must configure delivery credentials when pull-request mode comes from .basecoat.yml.'
Assert-True ($callable -notmatch '(?ms)Disable stale updater auto-merge\s+if:') `
    'Callable must reconcile stale auto-merge even after the installed updater is rolled back.'
Assert-True ($callable -match 'continuing for legacy caller compatibility') `
    'Callable reconciliation lookup must preserve legacy callers that lack pull-request permissions.'
Assert-True ($callable -match 'Get-TopLevelValue ''source''') 'Legacy fallback must honor the configured top-level source.'
Assert-True ($callable -match 'Get-SectionValue ''updates'' ''ref''') 'Legacy fallback must honor the configured update target selector.'
Assert-True ($callable -notmatch 'Get-TopLevelValue ''ref''') 'Legacy fallback must not mistake the installed sync pin for an update target.'
Assert-True ($callable -match '\$requestedRef = ''latest''') 'Legacy fallback must default the target selector to latest.'
Assert-True ($callable -match "\(\`$source -split '/'\)\.Count -eq 2\) \{ 'github\.com' \}") `
    'Legacy fallback must treat owner/repo sources as hosted on github.com for credential binding.'
Assert-True ($callable -match 'Convert-ToRepoSlug') 'Legacy fallback must normalize credential-bearing repository URLs before invoking gh.'
Assert-True ($callable -match '\$uri\.AbsolutePath') 'Legacy fallback URL normalization must discard userinfo, query, and fragment values.'
$scriptText = Get-Content -LiteralPath $scriptPath -Raw
Assert-True ($scriptText -match 'Unauthenticated public release lookup failed') `
    'Public release lookup must fail closed without falling back to the delivery token.'
Assert-True ($scriptText -match 'api\.github\.com/repos/') `
    'Public GitHub release lookup must use the unauthenticated REST path when no fetch credential is configured.'
Assert-True ($callable -match 'BASECOAT_SOURCE_REF:\s*\$\{\{ inputs\.source_ref \}\}') 'Legacy fallback must honor the explicit source_ref input.'
Assert-True ($callable -match 'persist-credentials:\s*false') 'Initial callable checkout must retain read-only workflow credentials.'
Assert-True ($callable -match '(?ms)Configure pull-request delivery credentials.*?persist-credentials:\s*false') `
    'Credentialed consumer checkout must not persist a host-wide delivery token.'
Assert-True ($scriptText -match 'function Invoke-ConsumerGit') `
    'Consumer fetch and push operations must use repository-scoped authentication.'
Assert-True ($scriptText -match '\$env:BASECOAT_MIRROR_FETCH_TOKEN = \$null') `
    'Consumer-controlled validation must clear mirror fetch credentials.'
Assert-True ($callable -notmatch '(?ms)jobs:\s.*?^\s{4}permissions:') `
    'Callable job must inherit the caller permission grant for legacy and current compatibility.'
Assert-True ($callable -notmatch "(?m)^\s+(?:Join-Path|\w+\s*=|-StagePath|-Source|-Ref|-Mirror|-Mode|-Approval|-AllowedBumps).*'\$\{\{ inputs\.") `
    'Callable workflow must pass caller-controlled inputs through environment variables instead of PowerShell source.'
Assert-True ($distributed -match 'Detect mixed agent naming state') 'Distributed workflow must preserve incomplete manual-upgrade detection.'
Assert-True ($distributed.IndexOf('Detect installed consumer updater') -lt $distributed.IndexOf('Disable stale updater auto-merge')) `
    'Distributed workflow must detect legacy installs before selecting the delivery path.'
Assert-True ($distributed.IndexOf('Disable stale updater auto-merge') -lt $distributed.IndexOf('Configure pull-request delivery credentials')) `
    'Distributed workflow must disable stale auto-merge before credentialed delivery checkout.'
Assert-True ($distributed -match '(?ms)Configure pull-request delivery credentials\s+if: steps\.updater\.outputs\.installed == ''true''') `
    'Distributed workflow must configure delivery credentials when pull-request mode comes from .basecoat.yml.'
Assert-True ($distributed -notmatch '(?ms)Disable stale updater auto-merge\s+if:') `
    'Distributed workflow must reconcile stale auto-merge after updater rollback.'
Assert-True ($distributed -notmatch '(?ms)jobs:\s.*?^\s{4}permissions:') `
    'Distributed callable job must inherit the caller permission grant.'
Assert-True ($distributed -match 'System\.Management\.Automation\.SemanticVersion') `
    'Distributed legacy fallback must accept full SemVer values.'
Assert-True ($distributed -match 'Ignoring malformed legacy BaseCoat issue marker') `
    'Distributed legacy fallback must repair malformed stable markers.'
Assert-True ($distributed -notmatch "(?m)^\s+(?:Join-Path|\w+\s*=|-StagePath|-Source|-Ref|-Mirror|-Mode|-Approval|-AllowedBumps).*'\$\{\{ inputs\.") `
    'Distributed workflow must pass caller-controlled inputs through environment variables instead of PowerShell source.'
Assert-True ($template -match 'update_token:\s*\$\{\{ secrets\.BASECOAT_UPDATE_TOKEN \}\}') 'Template must forward only the named update token.'
Assert-True ($template -match 'update_actor:\s*\$\{\{ vars\.BASECOAT_UPDATE_ACTOR \}\}') `
    'Template must preserve stable updater actor identity independently of token rotation.'
Assert-True ($template -match 'fetch_token:\s*\$\{\{ secrets\.BASECOAT_FETCH_TOKEN \}\}') 'Template must forward only the named source fetch token.'
Assert-True ($template -notmatch 'secrets:\s*inherit') 'Template must not inherit unrelated secrets.'
Assert-True ($template -match '(?m)^  contents:\s+read\s*$') 'Template caller must keep the default workflow token read-only.'
$workflowDocs = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/guides/workflows-reference.md') -Raw
Assert-True ($workflowDocs -match 'uses: IBuySpy-Shared/basecoat/\.github/workflows/check-basecoat-version-callable\.yml@[0-9a-f]{40}') `
    'Workflow docs must call an immutable remote reusable workflow.'
Assert-True ($workflowDocs -notmatch 'uses: \./\.github/base-coat/workflows/check-version\.yml') 'Workflow docs must not call a nested reusable workflow.'
Assert-True ($workflowDocs -match '(?ms)permissions:\s*\r?\n\s+actions:\s*read\s*\r?\n\s+contents:\s*read\s*\r?\n\s+issues:\s*write\s*\r?\n\s+pull-requests:\s*write') `
    'Workflow docs must grant the caller permissions required by notify and PR modes.'
$driftDocs = Get-Content -LiteralPath (Join-Path $repoRoot 'docs/guides/version-drift.md') -Raw
Assert-True ($driftDocs -match 'check-basecoat-version-callable\.yml@[0-9a-f]{40}') 'Version drift docs must use the immutable callable SHA.'
$exampleConfig = Get-Content -LiteralPath (Join-Path $repoRoot '.basecoat.yml.example') -Raw
Assert-True ($exampleConfig -notmatch '(?ms)^updates:\s.*?^\s{2}source:') 'Example update policy must inherit the top-level source by default.'

$updater = Get-Content -LiteralPath $scriptPath -Raw
Assert-True ($updater -match "'pr', 'merge'") 'Automatic mode must invoke gh pr merge.'
Assert-True ($updater -match "'--auto', '--squash'") 'Automatic mode must use GitHub auto-merge.'
Assert-True ($updater -notmatch '--admin') 'Automatic mode must never use admin bypass.'
Assert-True ($updater -match "if \(\`$bump -eq 'major'\) \{ \`$effectiveApproval = 'required' \}") 'Major upgrades must force required approval.'
Assert-True ($updater -match "'worktree', 'list'") 'Updater must inspect worktree mappings before cleanup.'
Assert-True ($updater -notmatch "'worktree', 'prune'") 'Updater cleanup must not globally prune unrelated worktree metadata.'
Assert-True ($updater.IndexOf("'rebase', `"origin/`$defaultBranch`"") -lt $updater.IndexOf("'diff', '--check'")) 'Final rebase must precede validation.'
Assert-True ($updater -match 'BASECOAT_REF = \$Release\.Sha') 'Sync must use the immutable resolved SHA.'
Assert-True ($updater -match 'BASECOAT_TARGET_DIR = \$StagePath') 'Sync must receive the configured custom stage path.'
Assert-True ($updater -match 'BASECOAT_TARGET_DIR = \$oldTargetDir') 'Sync must restore the previous target-directory environment.'
Assert-True ($updater -match "Set-TopLevelYamlValue -Path \`$configPath -Key 'source' -Value \(Convert-RepoToCloneUrl \`$Policy\.Source\)") `
    'Persisted source shorthand must be normalized to a usable clone URL.'
Assert-True ($updater -match "Set-TopLevelYamlValue -Path \`$configPath -Key 'mirror' -Value \(Convert-RepoToCloneUrl \`$Policy\.Mirror\)") `
    'Persisted mirror shorthand must be normalized to a usable clone URL.'
Assert-True ($updater -match "disposition = 'delivery-failed'") 'Failed PR delivery must publish a fleet disposition.'
Assert-True ($updater -match "Exception\.Data\['BasecoatPrUrl'\]") 'Failed delivery status must retain a PR URL created before failure.'
Assert-True ($updater -match 'Sync changed unmanaged consumer paths') 'Every generated PR must reject unmanaged consumer file changes before push.'
Assert-True (Test-ManagedUpgradePath -Path '.basecoat.yml' -StagePath '.config/basecoat') 'The installed pin must be a managed path.'
Assert-True (-not (Test-ManagedUpgradePath -Path 'src/application.cs' -StagePath '.config/basecoat')) `
    'Application source must never be included in a generated updater PR.'
Assert-True ($updater -match '\.source-provenance\.json') 'Updater must validate persisted source provenance.'
Assert-True ($updater -match 'Set-TopLevelYamlValue.+-Key ''ref'' -Value \$Release\.Tag') 'Updater must persist the installed release pin.'
Assert-True ($updater -match 'BASECOAT_UPDATE_ACTOR') `
    'PR reconciliation must support explicit GitHub App bot identity.'
Assert-True ($updater -match 'pull-request mode requires update_actor') `
    'PR ownership must fail closed unless a durable PAT/App actor is configured.'
Assert-True ($updater -match '\$configuredUpdateActors = @\(Get-ConfiguredUpdateActors\)') `
    'PR ownership discovery must not require delivery configuration before drift status can be recorded.'
Assert-True ($updater -match '\$updateActorVerificationFailure = \$_.Exception.Message') `
    'Delivery actor verification failures must be deferred until stable issue and status handling.'
Assert-True ($updater -match 'previousSource = Protect-SensitiveText') `
    'Rollback source values must be redacted before publication in a PR body.'
Assert-True ($updater -match '\$reconciliationTarget = if \(\s*\$eligiblePrTarget') `
    'Only fully configured, policy-eligible delivery may preserve the current generated PR.'
Assert-True ($updater -match "disposition = 'credential-required'") `
    'Missing PR-delivery credentials must be recorded in stable issue and fleet status state.'
Assert-True ($updater -match 'Invoke-GitRemoteWithAuthRetry') `
    'Immutable tag resolution must support host-scoped HTTPS authentication.'
Assert-True ($updater -match "uri\.Scheme -ne 'https'") `
    'Tag-resolution authentication must never send a token over plain HTTP.'
Assert-True ($updater -match '- Previous: ``v\$CurrentVersion``') 'Generated PR body must preserve the full current SemVer text.'
$generatedPrIndex = $updater.IndexOf('$generatedPrs = @(Get-GeneratedUpgradePrs -RepoRoot')
$currentExitIndex = $updater.IndexOf('if ($comparison -ge 0)')
Assert-True ($generatedPrIndex -ge 0 -and $currentExitIndex -ge 0 -and $generatedPrIndex -lt $currentExitIndex) `
    'Stale generated PRs must be reconciled before current/ahead early exits.'

New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    Push-Location $repoRoot
    & $scriptPath -PlanOnly -StagePath . `
        -ReleaseJson '{"tag":"v4.1.1","sha":"0123456789abcdef0123456789abcdef01234567","url":"https://example.test/releases/v4.1.1","published_at":"2026-08-09T00:00:00Z"}' `
        -StatusPath 'test-results/consumer-updater-tests/status.json' | Out-Null
    Pop-Location

    $plan = Get-Content -LiteralPath (Join-Path $scratch 'status.json') -Raw | ConvertFrom-Json
    Assert-Equal $plan.current_version '4.1.0' 'Plan must read the installed version.'
    Assert-Equal $plan.target_version '4.1.1' 'Plan must resolve patch target.'
    Assert-Equal $plan.bump 'patch' 'Plan must classify patch drift.'
    Assert-Equal $plan.mode 'notify' 'Plan must retain safe default mode.'
    Assert-Equal $plan.approval 'required' 'Plan must retain safe default approval.'
    Assert-Equal $plan.disposition 'planned' 'Allowed patch drift should be planned.'

    $prereleaseStage = Join-Path $scratch 'prerelease-stage'
    New-Item -ItemType Directory -Path $prereleaseStage -Force | Out-Null
    '{"version":"4.2.0-rc.1"}' | Set-Content -LiteralPath (Join-Path $prereleaseStage 'version.json') -Encoding utf8NoBOM
    & $scriptPath -PlanOnly -StagePath 'test-results/consumer-updater-tests/prerelease-stage' `
        -ReleaseJson '{"tag":"v4.2.0","sha":"0123456789abcdef0123456789abcdef01234567","url":"https://example.test/releases/v4.2.0","published_at":"2026-08-09T00:00:00Z"}' `
        -StatusPath 'test-results/consumer-updater-tests/prerelease-current.json' | Out-Null
    $prereleasePlan = Get-Content -LiteralPath (Join-Path $scratch 'prerelease-current.json') -Raw | ConvertFrom-Json
    Assert-Equal $prereleasePlan.current_version '4.2.0-rc.1' 'Status artifact must preserve the current prerelease.'
    Assert-Equal $prereleasePlan.target_version '4.2.0' 'Status artifact must keep the stable target distinct.'

    $prereleaseRejected = $false
    try {
        & $scriptPath -PlanOnly -StagePath . `
            -ReleaseJson '{"tag":"v4.2.0-rc.1","sha":"0123456789abcdef0123456789abcdef01234567","url":"https://example.test/releases/v4.2.0-rc.1","published_at":"2026-08-09T00:00:00Z"}' `
            -StatusPath 'test-results/consumer-updater-tests/prerelease.json' | Out-Null
    }
    catch {
        $prereleaseRejected = $_.Exception.Message -match 'Stable update policy rejected prerelease'
    }
    Assert-True $prereleaseRejected 'Stable channel must reject explicit prerelease targets.'

    $draftRejected = $false
    try {
        & $scriptPath -PlanOnly -StagePath . `
            -ReleaseJson '{"tag":"v4.2.0","sha":"0123456789abcdef0123456789abcdef01234567","url":"https://example.test/releases/v4.2.0","published_at":"2026-08-09T00:00:00Z","is_draft":true}' `
            -StatusPath 'test-results/consumer-updater-tests/draft.json' | Out-Null
    }
    catch {
        $draftRejected = $_.Exception.Message -match 'Stable update policy rejected prerelease'
    }
    Assert-True $draftRejected 'Stable channel must reject draft releases even when the tag is stable SemVer.'
}
finally {
    if ((Get-Location).Path -ne $repoRoot.Path) { Pop-Location }
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

$sync = Get-Content -LiteralPath (Join-Path $repoRoot 'sync.ps1') -Raw
Assert-True ($sync -match 'BASECOAT_MIRROR') 'Sync must support corporate mirrors.'
Assert-True ($sync -match 'known_bad_releases') 'Sync must support configurable known-bad remapping.'
Assert-True ($sync -match "base-coat' 'scripts") 'Sync must distribute consumer updater scripts.'

$openIssue = [pscustomobject]@{
    state = 'OPEN'
    marker = [pscustomobject]@{ drift_started_at = '2026-08-01T00:00:00Z' }
}
$closedIssue = [pscustomobject]@{
    state = 'CLOSED'
    marker = [pscustomobject]@{ drift_started_at = '2026-07-01T00:00:00Z' }
}
Assert-Equal (Resolve-DriftStartedAt -ExistingIssue $openIssue -Now ([datetime]'2026-08-10T00:00:00Z')) `
    '2026-08-01T00:00:00Z' 'Open drift cycle must preserve its start timestamp.'
Assert-Equal (Resolve-DriftStartedAt -ExistingIssue $closedIssue -Now ([datetime]'2026-08-10T00:00:00Z')) `
    '2026-08-10T00:00:00.0000000Z' 'Reopened drift cycle must reset its start timestamp.'

$global:BasecoatUpdaterLookupLog = @()
$global:BasecoatOnlyMalformedIssue = $false
function global:gh {
    $arguments = @($args)
    $global:BasecoatUpdaterLookupLog += ($arguments -join ' ')
    $global:LASTEXITCODE = 0
    if ($arguments[0] -eq 'issue' -and $arguments[1] -eq 'list') {
        if ($global:BasecoatOnlyMalformedIssue) {
            return '[{"number":5,"title":"repair me","body":"<!-- basecoat-consumer-update:{\"schema\":1} -->","state":"OPEN","createdAt":"2026-08-10T01:00:00Z","url":"https://example.test/issues/5"}]'
        }
        return '[{"number":5,"title":"missing timestamp","body":"<!-- basecoat-consumer-update:{\"schema\":1} -->","state":"OPEN","createdAt":"2026-08-10T01:00:00Z","url":"https://example.test/issues/5"},{"number":4,"title":"bad json","body":"<!-- basecoat-consumer-update:{bad} -->","state":"OPEN","createdAt":"2026-08-10T00:00:00Z","url":"https://example.test/issues/4"},{"number":3,"title":"bad timestamp","body":"<!-- basecoat-consumer-update:{\"schema\":1,\"drift_started_at\":\"not-a-date\"} -->","state":"OPEN","createdAt":"2026-08-09T00:00:00Z","url":"https://example.test/issues/3"},{"number":2,"title":"old","body":"<!-- basecoat-consumer-update:{\"schema\":1,\"drift_started_at\":\"2026-08-01T00:00:00Z\"} -->","state":"OPEN","createdAt":"2025-01-01T00:00:00Z","url":"https://example.test/issues/2"}]'
    }
    if ($arguments[0] -eq 'pr' -and $arguments[1] -eq 'list') {
        return '[{"number":10,"url":"https://example.test/pull/10","body":"<!-- basecoat-consumer-update-pr:v1 -->\n- Target: v4.1.10","headRefName":"upgrade"}]'
    }
    return ''
}
$env:GITHUB_REPOSITORY = 'example/consumer'
$oldIssue = Get-ExistingIssue
Assert-Equal $oldIssue.number 2 'Marker search must reuse an old stable issue.'
Assert-True ([string]$oldIssue.marker.drift_started_at -match '^2026-08-01T00:00:00') `
    'Issue discovery must skip malformed markers and invalid drift timestamps.'
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match '--search basecoat-consumer-update: in:body') 'Issue discovery must use marker search.'
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match '--limit 1000') 'Issue discovery must not stop at the newest 100 issues.'
$global:BasecoatOnlyMalformedIssue = $true
$repairIssue = Get-ExistingIssue
Assert-Equal $repairIssue.number 5 'Malformed stable markers must be repaired in place instead of creating duplicate issues.'
Assert-True (-not $repairIssue.PSObject.Properties['marker']) 'Malformed repair candidates must not supply invalid drift state.'
$global:BasecoatOnlyMalformedIssue = $false
Assert-True ($null -eq (Get-ExistingUpgradePr -TargetTag 'v4.1.1' -GeneratedPrs @(
    [pscustomobject]@{
        number = 10
        body = "$script:PrMarker`n- Target: v4.1.10"
    }
))) 'PR lookup must not collide with v4.1.10.'
Assert-True ($updater -match "'pr', 'list'.*'--limit', '1000'") `
    'Generated PR discovery must query beyond the newest 100 PRs.'
Assert-True ($updater -match "'--search', 'basecoat-consumer-update-pr:v1 in:body'") `
    'Generated PR discovery must search for the marker server-side.'
Assert-True ($updater -match 'Test-TrustedGeneratedPr') `
    'Marker-owned PR discovery must validate repository, author, branch, provenance, and diff.'
Assert-True ($updater -match '--force-with-lease=') `
    'An existing generated PR must be refreshed with newly validated content before reuse.'
Assert-True ($updater -match '(?ms)if \(\$existing\) \{\s+\$null = Invoke-Native.*?--disable-auto') `
    'Existing generated PRs must have auto-merge disabled until immutable content is rebuilt and force-pushed.'
Assert-True ($updater -notmatch '\$existing -and \$EffectiveApproval') `
    'Automatic policy must not retain auto-merge while an existing PR is being rebuilt.'
Assert-True ($updater.IndexOf("'--disable-auto'") -lt $updater.IndexOf('Test-TrustedGeneratedPr -Pr $_')) `
    'Marker-owned PR discovery must disable auto-merge before performing trust checks.'
$stalePr = [pscustomobject]@{
    number = 10
    url = 'https://example.test/pull/10'
    body = "$script:PrMarker`n- Target: v4.1.10"
    headRefName = 'upgrade'
}
Close-StaleUpgradePrs -TargetTag 'v4.1.1' -GeneratedPrs @($stalePr)
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'pr merge 10 .* --disable-auto') 'Stale generated PR auto-merge must be disabled.'
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'pr close 10 ') 'Stale generated PR must be closed.'
$ineligiblePr = [pscustomobject]@{
    number = 11
    url = 'https://example.test/pull/11'
    body = "$script:PrMarker`n- Target: v4.1.1"
    headRefName = 'upgrade'
}
Close-StaleUpgradePrs -TargetTag '' -GeneratedPrs @($ineligiblePr)
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'pr close 11 ') `
    'All generated PRs must close when no PR target is currently eligible.'
$tamperedPr = [pscustomobject]@{
    number = 12
    url = 'https://example.test/pull/12'
    body = "$script:PrMarker`n- Target: v4.1.1"
    headRefName = 'chore/basecoat-update-v4.1.1-2765-attempt-2'
    trusted = $false
}
Close-StaleUpgradePrs -TargetTag 'v4.1.1' -GeneratedPrs @($tamperedPr)
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'pr merge 12 .* --disable-auto') `
    'Owned but untrusted generated PRs must have auto-merge disabled.'
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'pr close 12 ') `
    'Owned but untrusted generated PRs must be closed even when their target matches.'
$aheadStatus = New-Status -CurrentVersion '4.2.0' -TargetVersion '4.1.1' -TargetTag 'v4.1.1' `
    -TargetSha ('f' * 40) -Source 'example/basecoat' -Channel stable -Mode notify `
    -Approval required -Bump none -Disposition ahead-of-target
$aheadIssue = [pscustomobject]@{ number = 13; state = 'OPEN'; url = 'https://example.test/issues/13' }
Close-DriftIssue -ExistingIssue $aheadIssue -Status $aheadStatus
Assert-True (($global:BasecoatUpdaterLookupLog -join "`n") -match 'ahead of the immutable target') `
    'Ahead-of-target issue closure must explicitly document that no downgrade occurs.'
Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue
Remove-Variable BasecoatUpdaterLookupLog,BasecoatOnlyMalformedIssue -Scope Global -ErrorAction SilentlyContinue

$trustedSha = 'd' * 40
$trustedPr = [pscustomobject]@{
    number = 12
    body = "$script:PrMarker`n- Target: v4.1.1`n- Immutable source SHA: ``$trustedSha``"
    headRefName = 'chore/basecoat-update-v4.1.1-2765-attempt-2'
    headRefOid = 'e' * 40
    baseRefName = 'main'
    isCrossRepository = $false
    headRepositoryOwner = [pscustomobject]@{ login = 'example' }
    author = [pscustomobject]@{ login = 'basecoat-updater' }
}
$global:BasecoatTrustedSha = $trustedSha
function global:gh {
    $global:LASTEXITCODE = 0
    return @('.basecoat.yml', '.github/base-coat/version.json', '.github/base-coat/.source-provenance.json')
}
function global:git {
    $arguments = @($args)
    $global:LASTEXITCODE = 0
    if ($arguments[0] -eq 'ls-remote') { return "$global:BasecoatTrustedSha`t$($arguments[2])" }
    if ($arguments[2] -eq 'show') {
        $spec = [string]$arguments[3]
        if ($spec.EndsWith('/version.json')) { return '{"version":"4.1.1"}' }
        if ($spec.EndsWith('/.source-provenance.json')) {
            return "{`"commit`":`"$global:BasecoatTrustedSha`"}"
        }
        if ($spec.EndsWith(':.basecoat.yml')) { return 'ref: v4.1.1' }
    }
    return ''
}
Assert-True (Test-TrustedGeneratedPr -Pr $trustedPr -RepoRoot $repoRoot -DefaultBranch main `
    -CanonicalSource example/basecoat -FetchSource https://mirror.example/basecoat.git `
    -StagePath .github/base-coat -ExpectedAuthor basecoat-updater) `
    'A same-repository updater PR with resolved provenance and a managed-only diff must be trusted.'
$attackerPr = $trustedPr.PSObject.Copy()
$attackerPr.isCrossRepository = $true
$attackerPr.headRepositoryOwner = [pscustomobject]@{ login = 'untrusted-contributor' }
Assert-True (-not (Test-TrustedGeneratedPr -Pr $attackerPr -RepoRoot $repoRoot -DefaultBranch main `
    -CanonicalSource example/basecoat -FetchSource https://mirror.example/basecoat.git `
    -StagePath .github/base-coat -ExpectedAuthor basecoat-updater)) `
    'A copied public marker from a contributor fork must never be treated as an updater PR.'
$collaboratorPr = $trustedPr.PSObject.Copy()
$collaboratorPr.author = [pscustomobject]@{ login = 'other-collaborator' }
Assert-True (-not (Test-TrustedGeneratedPr -Pr $collaboratorPr -RepoRoot $repoRoot -DefaultBranch main `
    -CanonicalSource example/basecoat -FetchSource https://mirror.example/basecoat.git `
    -StagePath .github/base-coat -ExpectedAuthor basecoat-updater)) `
    'A same-repository collaborator PR must not be treated as updater-owned.'
Remove-Item Function:\gh,Function:\git -Force -ErrorAction SilentlyContinue
Remove-Variable BasecoatTrustedSha -Scope Global -ErrorAction SilentlyContinue

$rotatedActorPr = $trustedPr.PSObject.Copy()
$rotatedActorPr.author = [pscustomobject]@{ login = 'old-basecoat-updater' }
Assert-True (Test-OwnedUpgradePr -Pr $rotatedActorPr -DefaultBranch main `
    -ExpectedAuthor 'old-basecoat-updater,new-basecoat-updater') `
    'A PR opened by a retained actor must remain updater-owned during actor rotation.'
$rotatedActorPr.author = [pscustomobject]@{ login = 'new-basecoat-updater' }
Assert-True (Test-OwnedUpgradePr -Pr $rotatedActorPr -DefaultBranch main `
    -ExpectedAuthor 'old-basecoat-updater,new-basecoat-updater') `
    'A PR opened by the current actor must be updater-owned during actor rotation.'
$rotatedActorPr.author = [pscustomobject]@{ login = 'untrusted-collaborator' }
Assert-True (-not (Test-OwnedUpgradePr -Pr $rotatedActorPr -DefaultBranch main `
    -ExpectedAuthor 'old-basecoat-updater,new-basecoat-updater')) `
    'Actor rotation must not broaden updater ownership to unconfigured collaborators.'

function global:gh {
    $global:BasecoatActorGhToken = $env:GH_TOKEN
    $global:LASTEXITCODE = 0
    return 'new-basecoat-updater'
}
$oldUpdateActor = $env:BASECOAT_UPDATE_ACTOR
$oldUpdateToken = $env:BASECOAT_UPDATE_TOKEN
$oldGhToken = $env:GH_TOKEN
$env:BASECOAT_UPDATE_ACTOR = 'old-basecoat-updater,new-basecoat-updater'
$env:BASECOAT_UPDATE_TOKEN = 'test-token'
$env:GH_TOKEN = 'workflow-token'
$verifiedActors = @(Get-UpdateActor)
Assert-Equal ($verifiedActors -join ',') 'old-basecoat-updater,new-basecoat-updater' `
    'The authenticated delivery actor must be accepted when it is present in the rotation list.'
Assert-Equal $global:BasecoatActorGhToken 'test-token' `
    'Delivery actor verification must temporarily authenticate with the dedicated update token.'
Assert-Equal $env:GH_TOKEN 'workflow-token' `
    'Delivery actor verification must restore the workflow token for issue handling.'
$actorMismatchFailure = ''
try {
    $env:BASECOAT_UPDATE_ACTOR = 'old-basecoat-updater'
    Get-UpdateActor | Out-Null
}
catch {
    $actorMismatchFailure = $_.Exception.Message
}
Assert-True ($actorMismatchFailure -match 'authenticated update token actor') `
    'Pull-request mode must fail closed when the authenticated delivery actor is not configured.'
Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue

function global:gh {
    $arguments = @($args)
    $global:BasecoatActorGhToken = $env:GH_TOKEN
    if ($arguments[0] -eq 'api' -and $arguments[1] -eq 'user') {
        $global:LASTEXITCODE = 1
        return ''
    }
    if ($arguments[0] -eq 'api' -and $arguments[1] -eq 'repos/example/consumer') {
        $global:LASTEXITCODE = 0
        return 'example/consumer'
    }
    $global:LASTEXITCODE = 1
    return ''
}
$oldActorRepository = $env:GITHUB_REPOSITORY
$env:GITHUB_REPOSITORY = 'example/consumer'
$env:BASECOAT_UPDATE_ACTOR = 'basecoat-updater[bot]'
$appActors = @(Get-UpdateActor)
Assert-Equal ($appActors -join ',') 'basecoat-updater[bot]' `
    'A repository-scoped GitHub App installation token must accept one configured bot actor.'
Assert-Equal $global:BasecoatActorGhToken 'test-token' `
    'GitHub App repository verification must use the dedicated update token.'
Assert-Equal $env:GH_TOKEN 'workflow-token' `
    'GitHub App verification must restore the workflow token.'
$env:GITHUB_REPOSITORY = $oldActorRepository
Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue

$env:BASECOAT_UPDATE_ACTOR = 'old-basecoat-updater,new-basecoat-updater'
$env:BASECOAT_UPDATE_TOKEN = $null
$retainedActors = @(Get-UpdateActor)
Assert-Equal ($retainedActors -join ',') 'old-basecoat-updater,new-basecoat-updater' `
    'Configured actor ownership must remain available after a delivery token is removed.'
$env:BASECOAT_UPDATE_ACTOR = $oldUpdateActor
$env:BASECOAT_UPDATE_TOKEN = $oldUpdateToken
$env:GH_TOKEN = $oldGhToken
Remove-Variable BasecoatActorGhToken -Scope Global -ErrorAction SilentlyContinue

$missingActor = @(Get-MissingPullRequestDeliveryConfiguration -EligiblePrTarget v4.2.0 `
    -UpdateToken test-token -UpdateActors @())
Assert-Equal ($missingActor -join ',') 'update_actor' `
    'An eligible PR must report a missing durable actor without failing before issue handling.'
$missingToken = @(Get-MissingPullRequestDeliveryConfiguration -EligiblePrTarget v4.2.0 `
    -UpdateToken '' -UpdateActors @('basecoat-updater'))
Assert-Equal ($missingToken -join ',') 'update_token' `
    'An eligible PR must report a missing delivery token.'
$blockedDeliveryRequirements = @(Get-MissingPullRequestDeliveryConfiguration -EligiblePrTarget '' `
    -UpdateToken '' -UpdateActors @())
Assert-Equal $blockedDeliveryRequirements.Count 0 `
    'A policy-blocked or non-drift target must not require PR delivery configuration.'

$global:BasecoatMissingTagLog = @()
function global:git {
    $global:BasecoatMissingTagLog += (@($args) -join ' ')
    $global:LASTEXITCODE = 0
}
$missingTagFailure = ''
try {
    $credentialSource = 'https://' + 'user' + ':' + 'password' + '@example.test/basecoat.git?token=secret-value'
    Resolve-TagSha -FetchSource $credentialSource -Tag v9.9.9 | Out-Null
}
catch {
    $missingTagFailure = $_.Exception.Message
}
Assert-True ($missingTagFailure -notmatch 'user:password|secret-value|token=') `
    'Tag-resolution failures must redact credential-bearing source URLs.'
Assert-True ($missingTagFailure -match 'https://example\.test/basecoat\.git') `
    'Tag-resolution failures must retain useful redacted source context.'
Remove-Item Function:\git -Force -ErrorAction SilentlyContinue
Remove-Variable BasecoatMissingTagLog -Scope Global -ErrorAction SilentlyContinue

$global:BasecoatFetchAuthLog = @()
function global:git {
    $global:BasecoatFetchAuthLog += ,@($args)
    $global:LASTEXITCODE = if ($global:BasecoatFetchAuthLog.Count -eq 1) { 1 } else { 0 }
}
$env:BASECOAT_UPDATE_TOKEN = 'consumer-write-token'
$env:BASECOAT_MIRROR_FETCH_TOKEN = 'mirror-read-token'
$env:BASECOAT_MIRROR_FETCH_HOST = 'mirror.example'
$authResult = Invoke-GitRemoteWithAuthRetry -Arguments @('ls-remote', 'https://mirror.example/basecoat.git', 'refs/tags/v4.1.1') `
    -Source 'https://mirror.example/basecoat.git' -CredentialKind mirror
Assert-Equal $authResult.ExitCode 0 'Trusted source authentication retry should succeed.'
$rawAuthInvocation = ($global:BasecoatFetchAuthLog[1] -join ' ')
$fetchHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:mirror-read-token'))
$updateHeader = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('x-access-token:consumer-write-token'))
Assert-True ($rawAuthInvocation.Contains($fetchHeader)) 'Source retry must use the dedicated read-only fetch token.'
Assert-True (-not $rawAuthInvocation.Contains($updateHeader)) 'Source retry must never forward the consumer delivery token.'
$global:BasecoatFetchAuthLog = @()
$mismatch = Invoke-GitRemoteWithAuthRetry -Arguments @('ls-remote', 'https://evil.example/basecoat.git', 'refs/tags/v4.1.1') `
    -Source 'https://evil.example/basecoat.git' -CredentialKind mirror -AllowFailure
Assert-Equal $mismatch.ExitCode 1 'Untrusted source authority must not receive an authenticated retry.'
Assert-Equal $global:BasecoatFetchAuthLog.Count 1 'Untrusted source authority must receive only the anonymous attempt.'
Remove-Item Function:\git -Force -ErrorAction SilentlyContinue
Remove-Item Env:\BASECOAT_UPDATE_TOKEN,Env:\BASECOAT_MIRROR_FETCH_TOKEN,Env:\BASECOAT_MIRROR_FETCH_HOST -ErrorAction SilentlyContinue
Remove-Variable BasecoatFetchAuthLog -Scope Global -ErrorAction SilentlyContinue

$global:BasecoatReleaseLookupToken = ''
function global:gh {
    $global:BasecoatReleaseLookupToken = if ($env:GH_ENTERPRISE_TOKEN) {
        $env:GH_ENTERPRISE_TOKEN
    }
    else {
        $env:GH_TOKEN
    }
    $global:LASTEXITCODE = 0
    return '{"tagName":"v4.1.1","url":"https://source.example/releases/v4.1.1","publishedAt":"2026-08-09T00:00:00Z"}'
}
$env:GH_TOKEN = 'consumer-write-token'
$env:BASECOAT_FETCH_TOKEN = 'source-read-token'
$env:BASECOAT_FETCH_HOST = 'source.example'
$null = Invoke-ReleaseLookup -CanonicalSource 'https://source.example/platform/basecoat.git' `
    -RequestedRef latest `
    -Arguments @('release', 'view', '--repo', 'source.example/platform/basecoat', '--json', 'tagName,url,publishedAt')
Assert-Equal $global:BasecoatReleaseLookupToken 'source-read-token' `
    'Private canonical release lookup must use the authority-bound source token.'
Assert-Equal $env:GH_TOKEN 'consumer-write-token' 'Release lookup must restore the consumer delivery token.'
Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue
Remove-Item Env:\BASECOAT_FETCH_TOKEN,Env:\BASECOAT_FETCH_HOST,Env:\GH_TOKEN,Env:\GH_ENTERPRISE_TOKEN,Env:\GH_HOST -ErrorAction SilentlyContinue
Remove-Variable BasecoatReleaseLookupToken -Scope Global -ErrorAction SilentlyContinue

$global:BasecoatPublicReleaseLookup = $null
function global:Invoke-RestMethod {
    param($Uri, $Headers)
    $global:BasecoatPublicReleaseLookup = [pscustomobject]@{ Uri = $Uri; Headers = $Headers }
    return [pscustomobject]@{
        tag_name = 'v4.1.1'
        html_url = 'https://github.com/example/basecoat/releases/tag/v4.1.1'
        published_at = '2026-08-09T00:00:00Z'
    }
}
$env:GH_TOKEN = 'consumer-write-token'
$null = Invoke-ReleaseLookup -CanonicalSource 'https://user:secret@github.com/example/basecoat.git?token=secret' `
    -RequestedRef latest `
    -Arguments @('release', 'view', '--repo', 'example/basecoat', '--json', 'tagName,url,publishedAt')
Assert-Equal $global:BasecoatPublicReleaseLookup.Uri 'https://api.github.com/repos/example/basecoat/releases/latest' `
    'Public release lookup must strip URL credentials before constructing the API endpoint.'
Assert-True (-not $global:BasecoatPublicReleaseLookup.Headers.ContainsKey('Authorization')) `
    'Public release lookup must not send the ambient delivery token.'
Remove-Item Function:\Invoke-RestMethod -Force -ErrorAction SilentlyContinue
Remove-Item Env:\GH_TOKEN -ErrorAction SilentlyContinue
Remove-Variable BasecoatPublicReleaseLookup -Scope Global -ErrorAction SilentlyContinue

$global:BasecoatUpdaterRequiredChecksLog = @()
function global:gh {
    $global:BasecoatUpdaterRequiredChecksLog += (@($args) -join ' ')
    $global:LASTEXITCODE = 0
    return '[]'
}
Wait-ForRequiredChecks -PrNumber '12' -MaxAttempts 1 -DelaySeconds 0
Assert-True (($global:BasecoatUpdaterRequiredChecksLog -join "`n") -match 'pr checks 12 .* --required') `
    'Automatic mode must query required checks before treating an unprotected PR as ready for auto-merge.'
Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue
Remove-Variable BasecoatUpdaterRequiredChecksLog -Scope Global -ErrorAction SilentlyContinue

$shaA = ('a' * 40) -join ''
$shaB = ('b' * 40) -join ''
$global:BasecoatCanonicalSha = $shaA
$global:BasecoatMirrorSha = $shaA
function global:Invoke-RestMethod {
    return [pscustomobject]@{
        tag_name = 'v4.1.1'
        html_url = 'https://example.test/releases/v4.1.1'
        published_at = '2026-08-09T00:00:00Z'
    }
}
function global:git {
    $arguments = @($args)
    $global:LASTEXITCODE = 0
    if ($arguments[0] -eq 'ls-remote') {
        $sha = if ($arguments[1] -match 'mirror') { $global:BasecoatMirrorSha } else { $global:BasecoatCanonicalSha }
        return "$sha`t$($arguments[2])"
    }
    return ''
}
$resolved = Resolve-Release -CanonicalSource 'example/basecoat' -FetchSource 'https://mirror.example/basecoat.git' -RequestedRef latest -ReleaseOverrideJson ''
Assert-Equal $resolved.Sha $shaA 'Canonical and mirror release SHA resolution failed.'
$overrideJson = @{
    tag = 'v4.1.1'
    sha = $shaA
    url = 'https://example.test/releases/v4.1.1'
    published_at = '2026-08-09T00:00:00Z'
} | ConvertTo-Json -Compress
$parsedOverride = $overrideJson | ConvertFrom-Json
Assert-Equal ([string]$parsedOverride.sha) $shaA 'Release metadata fixture SHA is invalid.'
Assert-Equal (Resolve-TagSha -FetchSource 'https://github.com/example/basecoat.git' -Tag 'v4.1.1') $shaA 'Canonical tag fixture SHA is invalid.'
Assert-Equal (Resolve-TagSha -FetchSource 'https://mirror.example/basecoat.git' -Tag 'v4.1.1') $shaA 'Mirror tag fixture SHA is invalid.'
$resolvedOverride = Resolve-Release -CanonicalSource 'example/basecoat' -FetchSource 'https://mirror.example/basecoat.git' -RequestedRef latest -ReleaseOverrideJson $overrideJson -VerifyProvenance
Assert-Equal $resolvedOverride.Sha $shaA 'Supplied release metadata must be verified against canonical and mirror SHAs.'
$global:BasecoatMirrorSha = $shaB
$mismatchRejected = $false
try {
    Resolve-Release -CanonicalSource 'example/basecoat' -FetchSource 'https://mirror.example/basecoat.git' -RequestedRef latest -ReleaseOverrideJson '' | Out-Null
}
catch {
    $mismatchRejected = $_.Exception.Message -match 'canonical and mirror'
}
Assert-True $mismatchRejected 'Release resolution must reject canonical/mirror SHA divergence.'
Remove-Item Function:\Invoke-RestMethod,Function:\git -Force -ErrorAction SilentlyContinue
Remove-Variable BasecoatCanonicalSha,BasecoatMirrorSha -Scope Global -ErrorAction SilentlyContinue

$missingTokenRejected = $false
try {
    Remove-Item Env:\BASECOAT_UPDATE_TOKEN -ErrorAction SilentlyContinue
    Invoke-UpgradePullRequest -RepoRoot $repoRoot -Policy ([pscustomobject]@{}) `
        -Release ([pscustomobject]@{ Tag = 'v4.1.1' }) -CurrentVersion '4.1.0' `
        -IssueUrl '' -EffectiveApproval 'required' | Out-Null
}
catch {
    $missingTokenRejected = $_.Exception.Message -match 'dedicated BASECOAT_UPDATE_TOKEN'
}
Assert-True $missingTokenRejected 'Pull-request mode must fail closed without a dedicated update token.'

Write-Host 'Running consumer updater worktree/PR smoke test...'
$e2eRoot = Join-Path $repoRoot 'test-results/consumer-updater-e2e'
$origin = Join-Path $e2eRoot 'origin.git'
$consumer = Join-Path $e2eRoot 'consumer'
$ghLog = Join-Path $e2eRoot 'gh.log'
$credentialLog = Join-Path $e2eRoot 'child-credentials.log'
try {
    Remove-Item -LiteralPath $e2eRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $e2eRoot -Force | Out-Null
    git init --bare $origin | Out-Null
    git clone $origin $consumer | Out-Null
    $customStage = '.config/basecoat'
    New-Item -ItemType Directory -Path (Join-Path $consumer $customStage) -Force | Out-Null
    '{"version":"4.1.0"}' | Set-Content -LiteralPath (Join-Path $consumer "$customStage/version.json") -Encoding utf8NoBOM
    @'
sync:
  script: sync.ps1
ref: v4.1.0
updates:
  mode: pull-request
  approval: automatic
  allowed_bumps: [patch, minor]
'@ | Set-Content -LiteralPath (Join-Path $consumer '.basecoat.yml') -Encoding utf8NoBOM
    @'
$ErrorActionPreference = 'Stop'
$target = Join-Path (git rev-parse --show-toplevel) $env:BASECOAT_TARGET_DIR
New-Item -ItemType Directory -Path $target -Force | Out-Null
Add-Content -LiteralPath $env:BASECOAT_TEST_CREDENTIAL_LOG `
    -Value "sync|$env:GH_TOKEN|$env:BASECOAT_UPDATE_TOKEN|$env:BASECOAT_FETCH_TOKEN|$env:BASECOAT_MIRROR_FETCH_TOKEN"
$releaseTag = $env:BASECOAT_RELEASE_TAG
if (-not $releaseTag) {
    $releaseTag = (Select-String -Path .basecoat.yml -Pattern '^ref:\s*(.+)$').Matches.Groups[1].Value.Trim()
}
$version = $releaseTag -replace '^v', ''
@{ version = $version } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target 'version.json') -Encoding utf8NoBOM
@{ commit = $env:BASECOAT_EXPECTED_SHA } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target '.source-provenance.json') -Encoding utf8NoBOM
"updated $version" | Set-Content -LiteralPath (Join-Path $target 'smoke.txt') -Encoding utf8NoBOM
'@ | Set-Content -LiteralPath (Join-Path $consumer 'sync.ps1') -Encoding utf8NoBOM
    '# consumer' | Set-Content -LiteralPath (Join-Path $consumer 'README.md') -Encoding utf8NoBOM
    git -C $consumer add -A
    git -C $consumer -c user.name=basecoat-updater-test `
        -c user.email=basecoat-updater-test@example.com commit -m 'initial consumer' | Out-Null
    git -C $consumer branch -M main
    git -C $consumer push -u origin main | Out-Null
    git --git-dir=$origin symbolic-ref HEAD refs/heads/main

    $global:BasecoatUpdaterGhLog = $ghLog
    function global:gh {
        $arguments = @($args)
        Add-Content -LiteralPath $global:BasecoatUpdaterGhLog -Value "$env:GH_TOKEN :: $($arguments -join ' ')"
        $global:LASTEXITCODE = 0
        if ($arguments[0] -eq 'pr' -and $arguments[1] -eq 'list') { return '[]' }
        if ($arguments[0] -eq 'repo' -and $arguments[1] -eq 'view') { return 'main' }
        if ($arguments[0] -eq 'pr' -and $arguments[1] -eq 'create') { return 'https://github.com/example/consumer/pull/7' }
        if ($arguments[0] -eq 'pr' -and $arguments[1] -eq 'checks') {
            return '[{"name":"consumer-ci","state":"SUCCESS","bucket":"pass"}]'
        }
        return ''
    }

    $env:GITHUB_REPOSITORY = 'example/consumer'
    $env:GITHUB_RUN_ID = '2765'
    $env:GITHUB_RUN_ATTEMPT = '2'
    $env:BASECOAT_UPDATE_TOKEN = 'dedicated-update-token'
    $env:GH_TOKEN = 'workflow-token'
    $env:BASECOAT_FETCH_TOKEN = 'source-read-token'
    $env:BASECOAT_MIRROR_FETCH_TOKEN = 'mirror-read-token'
    $env:BASECOAT_TEST_CREDENTIAL_LOG = $credentialLog
    $escapedCredentialLog = $credentialLog.Replace("'", "''")
    $smokePolicy = [pscustomobject]@{
        Source = 'example/basecoat'
        Mirror = 'example/basecoat-mirror'
        Validation = "Add-Content -LiteralPath '$escapedCredentialLog' -Value (`"validation|`$env:GH_TOKEN|`$env:BASECOAT_UPDATE_TOKEN|`$env:BASECOAT_FETCH_TOKEN|`$env:BASECOAT_MIRROR_FETCH_TOKEN`")"
    }
    $smokeRelease = [pscustomobject]@{
        Tag = 'v4.1.1'
        Sha = '0123456789abcdef0123456789abcdef01234567'
        Url = 'https://example.test/releases/v4.1.1'
    }
    $oldScriptStagePath = $script:StagePath
    $script:StagePath = $customStage
    try {
        $prUrl = Invoke-UpgradePullRequest -RepoRoot $consumer -Policy $smokePolicy `
            -Release $smokeRelease -CurrentVersion '4.1.0' `
            -IssueUrl 'https://github.com/example/consumer/issues/3' -EffectiveApproval 'automatic'
    }
    finally {
        $script:StagePath = $oldScriptStagePath
    }

    Assert-Equal $prUrl 'https://github.com/example/consumer/pull/7' 'PR smoke test did not return created PR.'
    Assert-Equal $env:GH_TOKEN 'workflow-token' 'PR delivery must restore the workflow token after completion.'
    Assert-True ((Get-Content -LiteralPath $ghLog -Raw) -match 'dedicated-update-token :: pr create') `
        'PR creation must authenticate with the dedicated update token.'
    Assert-True ((Get-Content -LiteralPath $ghLog -Raw) -match 'pr checks 7 .* --required') 'Automatic mode must wait for consumer required checks to run.'
    Assert-True ((Get-Content -LiteralPath $ghLog -Raw) -match 'pr merge 7 .* --auto --squash') 'Automatic smoke test did not request policy-respecting auto-merge.'
    $childCredentialLines = @(Get-Content -LiteralPath $credentialLog)
    Assert-Equal $childCredentialLines.Count 2 'Sync and validation must both record credential isolation evidence.'
    Assert-Equal $childCredentialLines[0] 'sync||||mirror-read-token' `
        'Mirror sync must receive only its authority-bound source credential.'
    Assert-Equal $childCredentialLines[1] 'validation||||' `
        'Consumer-controlled validation must not inherit delivery or source credentials.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $e2eRoot 'consumer-wt-basecoat-2765-attempt-2'))) 'Successful delivery must remove its attempt-specific worktree.'
    $remoteBranch = git -C $consumer branch -r --list 'origin/chore/basecoat-update-v4.1.1-2765-attempt-2'
    Assert-True (-not [string]::IsNullOrWhiteSpace(($remoteBranch -join ''))) 'Upgrade branch was not pushed to origin.'
    $localBranch = git -C $consumer branch --list 'chore/basecoat-update-v4.1.1-2765-attempt-2'
    Assert-True ([string]::IsNullOrWhiteSpace(($localBranch -join ''))) 'Successful cleanup must delete the local update branch.'
    $pinnedConfig = git -C $consumer show 'origin/chore/basecoat-update-v4.1.1-2765-attempt-2:.basecoat.yml'
    Assert-True (($pinnedConfig -join "`n") -match '(?m)^ref:\s*v4\.1\.1$') 'Generated PR must persist the new top-level ref pin.'
    $customVersion = git -C $consumer show "origin/chore/basecoat-update-v4.1.1-2765-attempt-2`:$customStage/version.json"
    Assert-True (($customVersion -join "`n") -match '"version":\s*"4\.1\.1"') 'Generated PR must sync and validate the configured custom stage path.'
    Assert-True (($pinnedConfig -join "`n") -match '(?m)^source:\s*https://github\.com/example/basecoat\.git$') `
        'Generated PR must persist a usable canonical clone URL with the ref pin.'
    Assert-True (($pinnedConfig -join "`n") -match '(?m)^mirror:\s*https://github\.com/example/basecoat-mirror\.git$') `
        'Generated PR must persist a usable mirror clone URL with the ref pin.'
    Assert-True ((Get-Content -LiteralPath $ghLog -Raw) -match 'source: <unset>') `
        'Generated PR rollback instructions must preserve the previous source.'

    git -C $consumer checkout -B verify-pin 'origin/chore/basecoat-update-v4.1.1-2765-attempt-2' | Out-Null
    Push-Location $consumer
    try {
        Remove-Item Env:\BASECOAT_REF,Env:\BASECOAT_RELEASE_TAG,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        $env:BASECOAT_TARGET_DIR = $customStage
        & pwsh -NoProfile -File .\sync.ps1 | Out-Null
    }
    finally {
        Remove-Item Env:\BASECOAT_TARGET_DIR -ErrorAction SilentlyContinue
        Pop-Location
    }
    $manualVersion = (Get-Content -LiteralPath (Join-Path $consumer "$customStage/version.json") -Raw | ConvertFrom-Json).version
    Assert-Equal $manualVersion '4.1.1' 'A later manual sync must retain the new installed pin.'
}
finally {
    Remove-Item Function:\gh -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\GITHUB_REPOSITORY -ErrorAction SilentlyContinue
    Remove-Item Env:\GITHUB_RUN_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\GITHUB_RUN_ATTEMPT -ErrorAction SilentlyContinue
    Remove-Item Env:\BASECOAT_UPDATE_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:\BASECOAT_FETCH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:\BASECOAT_MIRROR_FETCH_TOKEN -ErrorAction SilentlyContinue
    Remove-Item Env:\BASECOAT_TEST_CREDENTIAL_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:\GH_TOKEN -ErrorAction SilentlyContinue
    Remove-Variable BasecoatUpdaterGhLog -Scope Global -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $e2eRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Consumer updater tests passed.'
