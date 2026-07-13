# Paging/JSON helpers for keep-fix-throttle-weekly-scorecard.ps1, extracted so the list-
# envelope unwrapping and pagination can be unit-tested with a mocked Invoke-GhJson.

function Invoke-GhJson {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "gh command failed: gh $($Arguments -join ' ')"
    }

    if ([string]::IsNullOrWhiteSpace($output)) {
        return $null
    }

    return ($output | ConvertFrom-Json -Depth 100)
}

function Get-PagedResults {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        # Injectable fetcher (defaults to a live gh api call) so pagination/envelope
        # handling can be unit-tested without invoking gh.
        [scriptblock]$Fetcher = { param($Path) Invoke-GhJson -Arguments @("api", $Path) }
    )

    $all = [System.Collections.Generic.List[object]]::new()
    $page = 1
    do {
        $connector = if ($Endpoint.Contains("?")) { "&" } else { "?" }
        $paged = "${Endpoint}${connector}per_page=100&page=$page"
        $response = & $Fetcher $paged
        # Some list endpoints (for example actions/runs) return a { total_count, <list> }
        # envelope rather than a bare array; unwrap the list so callers get the records.
        $items = @(
            if ($null -eq $response) {
                @()
            } elseif ($response -is [array]) {
                $response
            } elseif ($response.PSObject.Properties.Name -contains 'workflow_runs') {
                $response.workflow_runs
            } elseif ($response.PSObject.Properties.Name -contains 'artifacts') {
                $response.artifacts
            } elseif ($response.PSObject.Properties.Name -contains 'items') {
                $response.items
            } else {
                $response
            }
        )
        foreach ($item in $items) {
            $all.Add($item)
        }
        $page++
    } while ($items.Count -eq 100)

    return @($all)
}
