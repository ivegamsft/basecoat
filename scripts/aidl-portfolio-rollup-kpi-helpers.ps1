function Test-IsPullRequestItem {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    return @($Item.PSObject.Properties.Match('pull_request')).Count -gt 0
}

function Get-LabelNames($Item) {
    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($label in @($Item.labels)) {
        if ($null -eq $label) { continue }
        if ($label.PSObject.Properties.Name -contains "name") {
            $name = [string]$label.name
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $labels.Add($name.ToLowerInvariant())
            }
        }
    }
    return ,([string[]]$labels.ToArray())
}

function Test-AnyLabelMatch {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Labels,
        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    if ($null -eq $Labels) {
        return $false
    }
    foreach ($label in $Labels) {
        foreach ($pattern in $Patterns) {
            if ($label -match $pattern) {
                return $true
            }
        }
    }
    return $false
}
