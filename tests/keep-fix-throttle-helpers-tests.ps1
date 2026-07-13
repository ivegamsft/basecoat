$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$helpersPath = Join-Path $repoRoot 'scripts\keep-fix-throttle-helpers.ps1'

Write-Host 'Running Keep/Fix/Throttle helper tests...'

if (-not (Test-Path $helpersPath)) {
    throw "Missing helper script: $helpersPath"
}

. $helpersPath

# Get-PagedResults accepts an injectable -Fetcher so pagination/envelope handling can be
# exercised without gh. Each fetcher returns a canned response for the requested page.

# Case 1: an actions/runs { total_count, workflow_runs } envelope is unwrapped to its records.
$envelopeFetcher = {
    param($Path)
    [pscustomobject]@{
        total_count   = 2
        workflow_runs = @(
            [pscustomobject]@{ id = 1; created_at = '2026-07-01T00:00:00Z'; conclusion = 'success' },
            [pscustomobject]@{ id = 2; created_at = '2026-07-02T00:00:00Z'; conclusion = 'failure' }
        )
    }
}
$runs = @(Get-PagedResults -Endpoint '/repos/o/r/actions/runs?status=completed' -Fetcher $envelopeFetcher)
if ($runs.Count -ne 2) { throw "Case 1: expected 2 unwrapped records, got $($runs.Count)." }
if ($runs[0].created_at -ne '2026-07-01T00:00:00Z') {
    throw 'Case 1: created_at not surfaced; the workflow_runs envelope was not unwrapped.'
}

# Case 2: a bare array response (issues/pulls) is returned as-is.
$arrayFetcher = {
    param($Path)
    @(
        [pscustomobject]@{ number = 1 },
        [pscustomobject]@{ number = 2 },
        [pscustomobject]@{ number = 3 }
    )
}
$pulls = @(Get-PagedResults -Endpoint '/repos/o/r/pulls?state=open' -Fetcher $arrayFetcher)
if ($pulls.Count -ne 3) { throw "Case 2: expected 3 records from a bare array, got $($pulls.Count)." }

# Case 3: pagination continues while a full page (100) is returned, then stops.
$pagedFetcher = {
    param($Path)
    if ($Path -match 'page=1$') {
        [pscustomobject]@{ total_count = 150; workflow_runs = @(1..100 | ForEach-Object { [pscustomobject]@{ id = $_ } }) }
    } elseif ($Path -match 'page=2$') {
        [pscustomobject]@{ total_count = 150; workflow_runs = @(1..50 | ForEach-Object { [pscustomobject]@{ id = (100 + $_) } }) }
    } else {
        $null
    }
}
$paged = @(Get-PagedResults -Endpoint '/repos/o/r/actions/runs' -Fetcher $pagedFetcher)
if ($paged.Count -ne 150) { throw "Case 3: expected 150 records across pages, got $($paged.Count)." }

# Case 4: a null response yields an empty result rather than throwing.
$nullFetcher = { param($Path) $null }
$empty = @(Get-PagedResults -Endpoint '/repos/o/r/actions/runs' -Fetcher $nullFetcher)
if ($empty.Count -ne 0) { throw "Case 4: expected 0 records for a null response, got $($empty.Count)." }

Write-Host 'Keep/Fix/Throttle helper tests passed' -ForegroundColor Green
exit 0
