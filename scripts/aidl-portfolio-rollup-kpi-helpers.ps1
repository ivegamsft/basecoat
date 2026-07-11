function Test-IsPullRequestItem {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    return @($Item.PSObject.Properties.Match('pull_request')).Count -gt 0
}
