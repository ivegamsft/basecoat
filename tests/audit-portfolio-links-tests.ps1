$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts/audit-portfolio-links.ps1'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $failures.Add($Message) }
}

function New-FixtureState {
    param([bool]$Linked)
    $repos = @(@{ nameWithOwner = 'acme/app' })
    if ($Linked) { $repos += @{ nameWithOwner = 'acme/lib' }; $repos += @{ nameWithOwner = 'other/fork' } }
    return @{
        projects = @(
            @{ id = 'P1'; number = 1; title = 'Wave 1 - Core'; closed = $false; repositories = @{ nodes = $repos } },
            @{ id = 'P2'; number = 2; title = 'Archive'; closed = $true; repositories = @{ nodes = @() } }
        )
        items = @{
            P1 = @(
                @{ content = @{ __typename = 'Issue'; number = 10; url = 'u10'; state = 'OPEN'; repository = @{ nameWithOwner = 'acme/app' }; milestone = @{ title = 'Sprint 1' } } },
                @{ content = @{ __typename = 'Issue'; number = 11; url = 'u11'; state = 'OPEN'; repository = @{ nameWithOwner = 'acme/lib' }; milestone = $null } },
                @{ content = @{ __typename = 'Issue'; number = 12; url = 'u12'; state = 'CLOSED'; repository = @{ nameWithOwner = 'acme/app' }; milestone = $null } },
                @{ content = @{ __typename = 'PullRequest'; number = 13; url = 'u13'; state = 'OPEN'; repository = @{ nameWithOwner = 'other/fork' } } },
                @{ content = $null }
            )
            P2 = @(@{ content = @{ __typename = 'Issue'; number = 20; url = 'u20'; state = 'OPEN'; repository = @{ nameWithOwner = 'acme/old' }; milestone = $null } })
        }
    }
}

function New-MockInvoker {
    param($State, [int]$RateLimitFailures = 0, [string]$RateLimitMessage = 'gh api graphql failed: API rate limit exceeded', [double]$ResetInSeconds = 0, [switch]$PermanentLinkFailure)
    $calls = [System.Collections.Generic.List[string]]::new()
    $sleeps = [System.Collections.Generic.List[double]]::new()
    $counter = @{ rateLimited = 0 }
    $invoker = {
        param($query, $variables)
        if ($query -match 'rateLimit') {
            return @{ data = @{ rateLimit = @{ resetAt = [datetimeoffset]::UtcNow.AddSeconds($ResetInSeconds).ToString('o') } } }
        }
        if ($query -match 'linkProjectV2ToRepository') {
            $calls.Add("link:$($variables.projectId):$($variables.repositoryId)")
            if ($PermanentLinkFailure) { return @{ errors = @(@{ type = 'FORBIDDEN'; message = 'Resource not accessible' }) } }
            if ($counter.rateLimited -lt $RateLimitFailures) {
                $counter.rateLimited++
                throw $RateLimitMessage
            }
            return @{ data = @{ linkProjectV2ToRepository = @{ repository = @{ nameWithOwner = 'x' } } } }
        }
        if ($query -match 'repository\(owner') {
            $calls.Add("repoId:$($variables.owner)/$($variables.name)")
            return @{ data = @{ repository = @{ id = "R_$($variables.name)" } } }
        }
        if ($query -match 'repositoryOwner') {
            $calls.Add('projects')
            return @{ data = @{ repositoryOwner = @{ projectsV2 = @{ nodes = $State.projects; pageInfo = @{ hasNextPage = $false; endCursor = $null } } } } }
        }
        if ($query -match 'items\(first') {
            $calls.Add("items:$($variables.projectId)")
            return @{ data = @{ node = @{ items = @{ nodes = $State.items[$variables.projectId]; pageInfo = @{ hasNextPage = $false; endCursor = $null } } } } }
        }
        throw "Unexpected query: $query"
    }.GetNewClosure()
    $sleeper = { param($seconds) $sleeps.Add($seconds) }.GetNewClosure()
    return @{ Invoker = $invoker; Sleeper = $sleeper; Calls = $calls; Sleeps = $sleeps }
}

function Invoke-Audit {
    param([hashtable]$Mock, [hashtable]$Extra = @{}, [string]$OutputPath)
    $out = if ($OutputPath) { $OutputPath } else { Join-Path ([System.IO.Path]::GetTempPath()) ("portfolio-links-" + [Guid]::NewGuid().ToString('N') + '.json') }
    $params = @{ Owner = 'acme'; OutputPath = $out; GraphQLInvoker = $Mock.Invoker; SleepInvoker = $Mock.Sleeper; BaseDelaySeconds = 0 }
    foreach ($key in $Extra.Keys) { $params[$key] = $Extra[$key] }
    $null = & $scriptPath @params 6>$null 3>$null 2>$null
    $code = $LASTEXITCODE
    $report = $null
    if (-not $OutputPath) {
        $report = Get-Content $out -Raw | ConvertFrom-Json
        Remove-Item $out -Force
    }
    return @{ Code = $code; Report = $report }
}

Write-Host 'Running portfolio link auditor tests...'

# Drift fixture: unlinked same-owner repo, missing milestone, cross-owner repo, closed project skipped.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false)
$result = Invoke-Audit -Mock $mock
Assert-True ($result.Code -eq 1) "Drift fixture should exit 1, got $($result.Code)"
Assert-True ($result.Report.projectsScanned -eq 1) 'Closed projects must be skipped by default'
Assert-True (@($result.Report.unlinkedRepos).Count -eq 1 -and $result.Report.unlinkedRepos[0].repository -eq 'acme/lib') 'Should report acme/lib as unlinked'
Assert-True (@($result.Report.missingMilestones).Count -eq 1 -and $result.Report.missingMilestones[0].issue -eq 11) 'Only open issue #11 should lack a milestone'
Assert-True (@($result.Report.crossOwnerRepos).Count -eq 1 -and $result.Report.gapCount -eq 3) 'Unlinked cross-owner repo must count as a report-only gap'
Assert-True (-not ($mock.Calls | Where-Object { $_ -like 'link:*' })) 'Audit mode must not mutate'

# Clean fixture: linked repos and milestone gaps only matter on sprint/wave projects.
$clean = New-FixtureState -Linked $true
$clean.projects[0].title = 'Platform roadmap'
$result = Invoke-Audit -Mock (New-MockInvoker -State $clean)
Assert-True ($result.Code -eq 0) "Clean fixture should exit 0, got $($result.Code)"
Assert-True ($result.Report.gapCount -eq 0) 'Clean fixture should report zero gaps'

# Fix mode survives transient rate limits and links once.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false) -RateLimitFailures 2
$result = Invoke-Audit -Mock $mock -Extra @{ Fix = $true }
$links = @($mock.Calls | Where-Object { $_ -like 'link:*' })
Assert-True ($links.Count -eq 3) "Fix should retry the link twice then succeed, saw $($links.Count) attempts"
Assert-True (@($result.Report.crossOwnerRepos).Count -eq 1) 'Fix must never link cross-owner repos'
Assert-True (@($result.Report.linked).Count -eq 1) 'Fix should record one created link'
Assert-True (@($result.Report.unlinkedRepos).Count -eq 0) 'Fixed link should not remain a gap'
Assert-True ($result.Code -eq 1) 'Milestone gap stays report-only, so Fix still exits 1'

# Fix is idempotent: a linked state performs no mutations.
$mock = New-MockInvoker -State (New-FixtureState -Linked $true)
$null = Invoke-Audit -Mock $mock -Extra @{ Fix = $true }
Assert-True (-not ($mock.Calls | Where-Object { $_ -like 'link:*' })) 'Already-linked repos must not be relinked'

# Non-retryable link failure is reported as a remaining gap, not retried.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false) -PermanentLinkFailure
$result = Invoke-Audit -Mock $mock -Extra @{ Fix = $true }
Assert-True (@($mock.Calls | Where-Object { $_ -like 'link:*' }).Count -eq 1) 'Permanent failures must not be retried'
Assert-True (@($result.Report.linkFailures).Count -eq 1 -and @($result.Report.unlinkedRepos).Count -eq 1) 'Permanent failure must remain a gap'
# Secondary rate limits wait for the cooldown rather than short exponential back-off.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false) -RateLimitFailures 1 -RateLimitMessage 'You have exceeded a secondary rate limit'
$result = Invoke-Audit -Mock $mock -Extra @{ Fix = $true; SecondaryLimitDelaySeconds = 60 }
Assert-True ($mock.Sleeps.Count -eq 1 -and $mock.Sleeps[0] -ge 60) "Secondary limit should wait 60s, waited $($mock.Sleeps -join ',')"
Assert-True (@($result.Report.linked).Count -eq 1) 'Link should succeed after the secondary cooldown'

# Primary rate limits wait until the server-reported reset.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false) -RateLimitFailures 1 -ResetInSeconds 120
$null = Invoke-Audit -Mock $mock -Extra @{ Fix = $true }
Assert-True ($mock.Sleeps.Count -eq 1 -and $mock.Sleeps[0] -ge 100 -and $mock.Sleeps[0] -le 125) "Primary limit should wait for reset, waited $($mock.Sleeps -join ',')"

# Waits beyond MaxWaitSeconds fail closed without sleeping.
$mock = New-MockInvoker -State (New-FixtureState -Linked $false) -RateLimitFailures 1 -ResetInSeconds 3000
$result = Invoke-Audit -Mock $mock -Extra @{ Fix = $true; MaxWaitSeconds = 900 }
Assert-True ($mock.Sleeps.Count -eq 0) 'Must not sleep beyond MaxWaitSeconds'
Assert-True (@($result.Report.linkFailures).Count -eq 1 -and @($result.Report.unlinkedRepos).Count -eq 1) 'Exceeded wait must remain an unresolved gap'

# Report write failures exit 2, not the drift code.
$dirOut = Join-Path ([System.IO.Path]::GetTempPath()) ("portfolio-links-dir-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dirOut | Out-Null
try {
    $result = Invoke-Audit -Mock (New-MockInvoker -State (New-FixtureState -Linked $false)) -OutputPath $dirOut
    Assert-True ($result.Code -eq 2) "Unwritable report path should exit 2, got $($result.Code)"
}
finally {
    Remove-Item $dirOut -Recurse -Force
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "  FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'Portfolio link auditor tests passed.' -ForegroundColor Green
exit 0
