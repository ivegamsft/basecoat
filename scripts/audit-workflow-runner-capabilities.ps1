param(
    [ValidateSet('markdown', 'json')]
    [string]$OutputFormat = 'markdown',
    [string]$OutputPath,
    [switch]$FailOnMismatch,
    [string]$WorkflowDirectory = '.github\workflows',
    [string]$ClassPath = '.github\workflow-runner-capability-classes.json',
    [string]$ContractPath = '.github\workflow-runner-routing-contracts.json',
    [switch]$FailOnContractViolation
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$workflowDir = if ([System.IO.Path]::IsPathRooted($WorkflowDirectory)) {
    $WorkflowDirectory
}
else {
    Join-Path $repoRoot $WorkflowDirectory
}
if (-not (Test-Path $workflowDir)) {
    throw "Workflow directory not found: $workflowDir"
}

$classFilePath = if ([System.IO.Path]::IsPathRooted($ClassPath)) {
    $ClassPath
}
else {
    Join-Path $repoRoot $ClassPath
}
if (-not (Test-Path $classFilePath)) {
    throw "Runner class catalog not found: $ClassPath"
}

$classData = Get-Content $classFilePath -Raw | ConvertFrom-Json
$classCatalogIssues = @()
$capabilitiesProperty = $classData.PSObject.Properties['capabilities']
$supportedCapabilities = @()
if ($null -eq $capabilitiesProperty -or
    $capabilitiesProperty.Value -isnot [System.Array] -or
    $capabilitiesProperty.Value.Count -eq 0) {
    $classCatalogIssues += 'capabilities must be a non-empty array'
}
else {
    $supportedCapabilities = @($capabilitiesProperty.Value | Where-Object {
        $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_)
    })
    if ($supportedCapabilities.Count -ne $capabilitiesProperty.Value.Count) {
        $classCatalogIssues += 'capabilities must contain only non-empty strings'
    }
    foreach ($duplicateCapability in @($supportedCapabilities | Group-Object | Where-Object { $_.Count -gt 1 })) {
        $classCatalogIssues += "$($duplicateCapability.Name) (duplicate capability)"
    }
}
$classesProperty = $classData.PSObject.Properties['classes']
$runnerClasses = @()
if ($null -eq $classesProperty -or
    $classesProperty.Value -isnot [System.Array] -or
    $classesProperty.Value.Count -eq 0) {
    $classCatalogIssues += 'classes must be a non-empty array'
}
else {
    $runnerClasses = @($classesProperty.Value)
}
if ($classData.version -ne 2) {
    $classCatalogIssues += "schema version '$($classData.version)' (expected 2)"
}

$classNames = @()
foreach ($runnerClass in $runnerClasses) {
    $className = [string]$runnerClass.runner_class
    $classNames += $className
    if ([string]::IsNullOrWhiteSpace($className)) {
        $classCatalogIssues += 'class with missing runner_class'
    }
    $priorityProperty = $runnerClass.PSObject.Properties['recommendation_priority']
    if ($null -eq $priorityProperty) {
        $classCatalogIssues += "$className (missing recommendation_priority)"
    }
    elseif ($priorityProperty.Value -isnot [long] -or
        $priorityProperty.Value -lt [int]::MinValue -or
        $priorityProperty.Value -gt [int]::MaxValue) {
        $classCatalogIssues += "$className (recommendation_priority must be an integer)"
    }
    $recommendProperty = $runnerClass.PSObject.Properties['recommend_for_audit']
    if ($null -ne $recommendProperty -and $recommendProperty.Value -isnot [bool]) {
        $classCatalogIssues += "$className (recommend_for_audit must be a boolean)"
    }

    $requiredAllProperty = $runnerClass.PSObject.Properties['required_capabilities']
    $requiredAnyProperty = $runnerClass.PSObject.Properties['required_capabilities_any']
    if ($null -ne $requiredAllProperty -and $requiredAllProperty.Value -isnot [System.Array]) {
        $classCatalogIssues += "$className (required_capabilities must be an array)"
    }
    if ($null -ne $requiredAnyProperty -and $requiredAnyProperty.Value -isnot [System.Array]) {
        $classCatalogIssues += "$className (required_capabilities_any must be an array)"
    }
    $requiredAll = if ($null -ne $requiredAllProperty -and $requiredAllProperty.Value -is [System.Array]) {
        @($requiredAllProperty.Value | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        })
    }
    else {
        @()
    }
    $requiredAny = if ($null -ne $requiredAnyProperty -and $requiredAnyProperty.Value -is [System.Array]) {
        @($requiredAnyProperty.Value | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        })
    }
    else {
        @()
    }
    if ($requiredAll.Count -eq 0 -and $requiredAny.Count -eq 0) {
        $classCatalogIssues += "$className (missing required_capabilities or required_capabilities_any)"
    }
    foreach ($requiredCapability in @($requiredAll + $requiredAny)) {
        if ($supportedCapabilities -notcontains $requiredCapability) {
            $classCatalogIssues += "$className (unknown capability '$requiredCapability')"
        }
    }
}
foreach ($duplicateClass in @($classNames | Group-Object | Where-Object { $_.Count -gt 1 })) {
    $classCatalogIssues += "$($duplicateClass.Name) (duplicate runner_class)"
}
if ($classCatalogIssues.Count -gt 0) {
    throw "Runner class catalog is invalid: $($classCatalogIssues -join '; ')"
}

function Get-WorkflowJobBlocks {
    param(
        [string]$WorkflowPath
    )

    $lines = Get-Content $WorkflowPath
    $jobsStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*jobs:\s*$') {
            $jobsStart = $i
            break
        }
    }

    if ($jobsStart -lt 0) {
        return @()
    }

    $jobBlocks = @()
    $currentJobKey = $null
    $currentStart = -1

    for ($i = $jobsStart + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^[A-Za-z0-9_-]+:\s*$') {
            break
        }

        if ($line -match '^\s{2}([A-Za-z0-9_-]+):\s*$') {
            if ($currentJobKey) {
                $jobBlocks += [pscustomobject]@{
                    JobKey = $currentJobKey
                    Start  = $currentStart
                    End    = $i - 1
                }
            }
            $currentJobKey = $matches[1]
            $currentStart = $i
        }
    }

    if ($currentJobKey) {
        $jobBlocks += [pscustomobject]@{
            JobKey = $currentJobKey
            Start  = $currentStart
            End    = $lines.Count - 1
        }
    }

    foreach ($job in $jobBlocks) {
        $job | Add-Member -NotePropertyName Content -NotePropertyValue (($lines[$job.Start..$job.End] -join "`n"))
    }

    return $jobBlocks
}

function Get-YamlKeyBlock {
    param(
        [string]$Content,
        [string]$Key,
        [int]$Indent
    )

    $lines = $Content -split "`n"
    $prefix = [regex]::Escape((' ' * $Indent))
    $keyPattern = "^$prefix$([regex]::Escape($Key)):\s*(.*)$"

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch $keyPattern) {
            continue
        }

        $block = @($lines[$i])
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ($line.Trim().Length -eq 0) {
                $block += $line
                continue
            }

            $lineIndent = ($line -replace '\S.*$', '').Length
            if ($lineIndent -le $Indent) {
                break
            }
            $block += $line
        }
        return ($block -join "`n")
    }

    return ''
}

function Get-YamlStructuralContent {
    param(
        [string]$Content
    )

    $structuralLines = @()
    $blockScalarIndent = $null

    foreach ($line in ($Content -split "`n")) {
        $lineIndent = ([regex]::Match($line, '^[ \t]*').Value).Length
        if ($null -ne $blockScalarIndent) {
            if ($line.Trim().Length -eq 0 -or $lineIndent -gt $blockScalarIndent) {
                continue
            }
            $blockScalarIndent = $null
        }

        $structuralLines += $line
        if ($line -match '^(?<indent>[ \t]*)(?:-\s+)?[A-Za-z0-9_.-]+:\s*[>|][0-9+-]*\s*(?:#.*)?$') {
            $blockScalarIndent = $matches.indent.Length
        }
    }

    return ($structuralLines -join "`n")
}

function Get-ActionStepBlocks {
    param(
        [string]$JobContent,
        [string]$ActionPattern
    )

    $lines = $JobContent -split "`n"
    $stepBlocks = @()
    $currentStep = @()

    foreach ($line in $lines) {
        if ($line -match '^\s{6}-\s+') {
            if ($currentStep.Count -gt 0) {
                $stepContent = Get-YamlStructuralContent -Content ($currentStep -join "`n")
                if ($stepContent -match $ActionPattern) {
                    $stepBlocks += $stepContent
                }
            }
            $currentStep = @($line)
            continue
        }

        if ($currentStep.Count -gt 0) {
            if ($line.Trim().Length -gt 0 -and $line -match '^\s{0,5}\S') {
                $stepContent = Get-YamlStructuralContent -Content ($currentStep -join "`n")
                if ($stepContent -match $ActionPattern) {
                    $stepBlocks += $stepContent
                }
                $currentStep = @()
                continue
            }
            $currentStep += $line
        }
    }

    if ($currentStep.Count -gt 0) {
        $stepContent = Get-YamlStructuralContent -Content ($currentStep -join "`n")
        if ($stepContent -match $ActionPattern) {
            $stepBlocks += $stepContent
        }
    }

    return $stepBlocks
}

function Get-RunStepContents {
    param(
        [string]$JobContent
    )

    $lines = $JobContent -split "`n"
    $runContents = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^(?<indent>[ \t]*)(?:-\s+)?run:\s*(?<value>.*)$') {
            continue
        }

        $keyIndent = $matches.indent.Length
        $value = $matches.value.Trim()
        if ($value -notmatch '^[>|][0-9+-]*(?:\s+#.*)?$') {
            if ($value.Length -ge 2 -and
                $value[0] -eq [char]39 -and
                $value[$value.Length - 1] -eq [char]39) {
                $value = $value.Substring(1, $value.Length - 2) -replace "''", "'"
            }
            elseif ($value.Length -ge 2 -and
                $value[0] -eq [char]34 -and
                $value[$value.Length - 1] -eq [char]34) {
                try {
                    $value = $value | ConvertFrom-Json
                }
                catch {
                    $value = $value.Substring(1, $value.Length - 2)
                }
            }
            $runContents += $value
            continue
        }
        $isFoldedScalar = $value.StartsWith('>')

        $body = @()
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ($line.Trim().Length -eq 0) {
                $body += $line
                continue
            }
            $lineIndent = ([regex]::Match($line, '^[ \t]*').Value).Length
            if ($lineIndent -le $keyIndent) {
                break
            }
            $body += $line
        }
        $runContents += if ($isFoldedScalar) {
            $body -join ' '
        }
        else {
            $body -join "`n"
        }
        $i = $j - 1
    }

    return $runContents
}

function Remove-UnquotedInlineComment {
    param(
        [string]$Line
    )

    $inSingleQuote = $false
    $inDoubleQuote = $false
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $character = $Line[$i]
        if (($character -eq [char]92 -or $character -eq [char]96) -and
            -not $inSingleQuote) {
            $i++
            continue
        }
        if ($character -eq [char]39 -and -not $inDoubleQuote) {
            $inSingleQuote = -not $inSingleQuote
            continue
        }
        if ($character -eq [char]34 -and -not $inSingleQuote) {
            $inDoubleQuote = -not $inDoubleQuote
            continue
        }
        if ($character -ne [char]35 -or $inSingleQuote -or $inDoubleQuote) {
            continue
        }

        $isCommentBoundary = $i -eq 0
        if (-not $isCommentBoundary) {
            $previous = $Line[$i - 1]
            $isCommentBoundary = [char]::IsWhiteSpace($previous) -or
                ';|&(){}<>'.IndexOf($previous) -ge 0
        }
        if ($isCommentBoundary) {
            return $Line.Substring(0, $i).TrimEnd()
        }
    }

    return $Line
}

function Remove-QuotedCommandText {
    param(
        [string]$Line,
        [ref]$QuoteState,
        [ref]$QuotedTextState,
        [ref]$QuotePrefixState
    )

    $result = [System.Text.StringBuilder]::new()
    $quotedText = [System.Text.StringBuilder]::new()
    if ($QuotedTextState.Value) {
        [void]$quotedText.Append([string]$QuotedTextState.Value)
    }
    $quote = if ($QuoteState.Value) { [char]$QuoteState.Value } else { [char]0 }
    $quotePrefix = [string]$QuotePrefixState.Value
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $character = $Line[$i]
        if ($quote -ne [char]0) {
            if ($character -eq [char]92 -and $quote -eq [char]34) {
                [void]$quotedText.Append($character)
                if ($i + 1 -lt $Line.Length) {
                    [void]$quotedText.Append($Line[$i + 1])
                    $i++
                }
                continue
            }
            if ($character -eq $quote) {
                $prefix = $quotePrefix
                $segment = $quotedText.ToString()
                $identityCommandPrefix = $prefix -match '(?i)(?:^|&&|\|\||;|\bthen\s+|\$\()\s*(?:if\s+)?(?:sudo\s+)?az\s+login\b' -or
                    $prefix -match '(?i)(?:^|&&|\|\||;)\s*(?:&\s*)?(?:if\s*\(\s*)?(?:\$[A-Za-z_][A-Za-z0-9_]*\s*=\s*)?Connect-AzAccount\b'
                if ($identityCommandPrefix) {
                    [void]$result.Append($segment)
                }
                elseif ($quote -eq [char]34) {
                    foreach ($substitution in [regex]::Matches($segment, '\$\((?<command>[^()]*)\)')) {
                        [void]$result.Append('$(')
                        [void]$result.Append($substitution.Groups['command'].Value)
                        [void]$result.Append(')')
                    }
                }
                else {
                    [void]$result.Append(' ')
                }
                [void]$quotedText.Clear()
                $quote = [char]0
                $quotePrefix = ''
                continue
            }
            [void]$quotedText.Append($character)
            continue
        }

        if ($character -eq [char]39 -or $character -eq [char]34) {
            $quote = $character
            [void]$quotedText.Clear()
            $quotePrefix = $result.ToString()
            continue
        }

        [void]$result.Append($character)
    }

    $QuoteState.Value = $quote
    $QuotedTextState.Value = $quotedText.ToString()
    $QuotePrefixState.Value = $quotePrefix

    return $result.ToString()
}

function Remove-PowerShellBlockCommentText {
    param(
        [string]$Line,
        [ref]$InBlockComment
    )

    $result = [System.Text.StringBuilder]::new()
    $quote = [char]0
    for ($i = 0; $i -lt $Line.Length; $i++) {
        $character = $Line[$i]
        $nextCharacter = if ($i + 1 -lt $Line.Length) { $Line[$i + 1] } else { [char]0 }

        if ($InBlockComment.Value) {
            if ($character -eq '#' -and $nextCharacter -eq '>') {
                $InBlockComment.Value = $false
                $i++
            }
            continue
        }

        if ($quote -ne [char]0) {
            [void]$result.Append($character)
            if ($quote -eq [char]39 -and $character -eq [char]39 -and $nextCharacter -eq [char]39) {
                [void]$result.Append($nextCharacter)
                $i++
                continue
            }
            if ($quote -eq [char]34 -and $character -eq '`' -and $nextCharacter -ne [char]0) {
                [void]$result.Append($nextCharacter)
                $i++
                continue
            }
            if ($character -eq $quote) {
                $quote = [char]0
            }
            continue
        }

        if ($character -eq [char]39 -or $character -eq [char]34) {
            $quote = $character
            [void]$result.Append($character)
            continue
        }
        if ($character -eq '<' -and $nextCharacter -eq '#') {
            $InBlockComment.Value = $true
            $i++
            continue
        }
        [void]$result.Append($character)
    }

    return $result.ToString()
}

function Find-UnquotedHeredocOperator {
    param(
        [string]$Line,
        [char]$InitialQuote = [char]0
    )

    $quote = $InitialQuote
    for ($i = 0; $i -lt $Line.Length - 1; $i++) {
        $character = $Line[$i]
        $nextCharacter = $Line[$i + 1]
        if ($quote -ne [char]0) {
            if (($character -eq [char]92 -or $character -eq [char]96) -and
                $quote -eq [char]34) {
                $i++
                continue
            }
            if ($character -eq $quote) {
                $quote = [char]0
            }
            continue
        }
        if ($character -eq [char]39 -or $character -eq [char]34) {
            $quote = $character
            continue
        }
        if ($character -ne '<' -or $nextCharacter -ne '<') {
            continue
        }

        $match = [regex]::Match(
            $Line.Substring($i),
            '^<<-?\s*(?:''(?<single>[^'']+)''|"(?<double>[^"]+)"|(?<bare>\\?[^\s;&|<>(){}]+))'
        )
        if ($match.Success) {
            $delimiter = @('single', 'double', 'bare') |
                ForEach-Object { $match.Groups[$_].Value } |
                Where-Object { $_ } |
                Select-Object -First 1
            $delimiter = $delimiter -replace '\\(.)', '$1'
            return [pscustomobject]@{
                Index = $i
                Delimiter = $delimiter
            }
        }
    }

    return $null
}

function Get-ExecutableRunContents {
    param(
        [string]$JobContent
    )

    $commandContents = @()
    foreach ($runContent in @(Get-RunStepContents -JobContent $JobContent)) {
        $executableLines = @()
        $heredocDelimiter = $null
        $hereStringTerminator = $null
        $powerShellBlockComment = $false
        $shellQuote = [char]0
        $shellQuotedText = ''
        $shellQuotePrefix = ''
        foreach ($line in ($runContent -split "`n")) {
            if ($null -ne $hereStringTerminator) {
                if ($line.Trim() -eq $hereStringTerminator) {
                    $hereStringTerminator = $null
                }
                continue
            }
            if ($null -ne $heredocDelimiter) {
                if ($line.Trim() -eq $heredocDelimiter) {
                    $heredocDelimiter = $null
                }
                continue
            }
            $lineWithoutBlockComments = Remove-PowerShellBlockCommentText `
                -Line $line `
                -InBlockComment ([ref]$powerShellBlockComment)
            $executableLine = Remove-UnquotedInlineComment -Line $lineWithoutBlockComments
            if ([string]::IsNullOrWhiteSpace($executableLine)) {
                continue
            }
            $heredoc = Find-UnquotedHeredocOperator `
                -Line $executableLine `
                -InitialQuote $shellQuote
            if ($null -ne $heredoc) {
                $executablePrefix = $executableLine.Substring(0, $heredoc.Index)
                if (-not [string]::IsNullOrWhiteSpace($executablePrefix)) {
                    $executableLines += Remove-QuotedCommandText `
                        -Line $executablePrefix `
                        -QuoteState ([ref]$shellQuote) `
                        -QuotedTextState ([ref]$shellQuotedText) `
                        -QuotePrefixState ([ref]$shellQuotePrefix)
                }
                $heredocDelimiter = $heredoc.Delimiter
                continue
            }
            if ($executableLine -match '(?:^|[=,(])\s*@(?<quote>[''"])\s*$') {
                $hereStringTerminator = "$($matches.quote)@"
                continue
            }
            $executableLines += Remove-QuotedCommandText `
                -Line $executableLine `
                -QuoteState ([ref]$shellQuote) `
                -QuotedTextState ([ref]$shellQuotedText) `
                -QuotePrefixState ([ref]$shellQuotePrefix)
        }

        $commands = $executableLines -join "`n"
        $commands = $commands -replace '\\[ \t]*\r?\n[ \t]*', ' '
        $commands = $commands -replace '`[ \t]*\r?\n[ \t]*', ' '
        $commandContents += $commands
    }

    return $commandContents
}

function Test-RunnerIdentityRunContent {
    param(
        [string]$JobContent
    )

    foreach ($commands in @(Get-ExecutableRunContents -JobContent $JobContent)) {
        if ($commands -match '(?im)(?:^|&&|\|\||;|\bthen\s+|\$\()\s*(?:if\s+)?(?:sudo\s+)?az\s+login\b[^\r\n]*--identity\b' -or
            $commands -match '(?im)(?:^|&&|\|\||;)\s*(?:&\s*)?(?:if\s*\(\s*)?(?:\$[A-Za-z_][A-Za-z0-9_]*\s*=\s*)?Connect-AzAccount\b[^\r\n]*-Identity\b') {
            return $true
        }
    }

    return $false
}

function Get-RunsOnRaw {
    param(
        [string]$JobContent
    )

    $lines = $JobContent -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s{4}runs-on:\s*(.*)$') {
            $inline = $matches[1].Trim()
            $block = @($inline)
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s{4}[A-Za-z0-9_-]+:\s*') {
                    break
                }
                if ($lines[$j] -match '^\s{2}[A-Za-z0-9_-]+:\s*$') {
                    break
                }
                if ($lines[$j] -match '^\s{6,}') {
                    $block += $lines[$j].Trim()
                    continue
                }
                if ($lines[$j].Trim().Length -eq 0) {
                    continue
                }
                break
            }

            return ($block -join ' ').Trim()
        }
    }

    return ''
}

function Get-TimeoutMinutes {
    param(
        [string]$JobContent
    )

    $lines = $JobContent -split "`n"
    foreach ($line in $lines) {
        if ($line -match '^\s{4}timeout-minutes:\s*(\d+)\s*$') {
            return [int]$matches[1]
        }
    }

    return $null
}

function Get-ActualRunnerClass {
    param(
        [string]$RunsOnRaw,
        [string]$JobContent
    )

    if ([string]::IsNullOrWhiteSpace($RunsOnRaw)) {
        if ($JobContent -match '(?m)^\s{4}uses:\s*[^\r\n]+') {
            return 'reusable-workflow'
        }
        return 'missing-runs-on'
    }
    if ($RunsOnRaw -match 'matrix\.os') { return 'github-hosted-matrix' }
    if ($RunsOnRaw -match 'vars\.RUNNER_RELEASE') { return 'configurable-release' }
    if ($RunsOnRaw -match 'vars\.RUNNER_DEPLOY') { return 'configurable-deploy' }
    if ($RunsOnRaw -match 'self-hosted' -or $RunsOnRaw -match 'group:') { return 'self-hosted-linux' }
    if ($RunsOnRaw -match 'windows-latest') { return 'github-hosted-windows' }
    if ($RunsOnRaw -match 'macos') { return 'github-hosted-macos' }
    if ($RunsOnRaw -match 'ubuntu') { return 'github-hosted-linux' }
    return 'unknown'
}

function Get-RequiredCapabilities {
    param(
        [string]$WorkflowName,
        [string]$JobName,
        [string]$JobContent,
        [string]$RootPermissionsContent,
        [string[]]$ContractRequiredCapabilities
    )

    $caps = New-Object System.Collections.Generic.HashSet[string]
    [void]$caps.Add('public-internet')

    $workflowJobKey = "$($WorkflowName.ToLowerInvariant())|$($JobName.ToLowerInvariant())"
    $jobPermissionsContent = Get-YamlKeyBlock -Content $JobContent -Key 'permissions' -Indent 4
    $effectivePermissionsContent = if ([string]::IsNullOrWhiteSpace($jobPermissionsContent)) {
        $RootPermissionsContent
    }
    else {
        $jobPermissionsContent
    }
    $hasOidcPermission = $effectivePermissionsContent -match '(?im)^\s*id-token:\s*[''"]?write[''"]?\s*(?:#.*)?$' -or
        $effectivePermissionsContent -match '(?im)^\s*permissions:\s*[''"]?write-all[''"]?\s*(?:#.*)?$'

    $azureLoginSteps = @(Get-ActionStepBlocks -JobContent $JobContent -ActionPattern '(?m)^\s*(?:-\s+)?uses:\s*[''"]?azure/login@')
    $usesAzureLogin = $azureLoginSteps.Count -gt 0
    $credsInputPattern = '(?m)^\s+creds:\s*(?:"[^"]+"|''[^'']+''|[^\s#]\S*)'
    $clientIdInputPattern = '(?m)^\s+client-id:\s*(?:"[^"]+"|''[^'']+''|[^\s#]\S*)'
    $tenantIdInputPattern = '(?m)^\s+tenant-id:\s*(?:"[^"]+"|''[^'']+''|[^\s#]\S*)'
    $subscriptionIdInputPattern = '(?m)^\s+subscription-id:\s*(?:"[^"]+"|''[^'']+''|[^\s#]\S*)'
    $usesCredentialLogin = @($azureLoginSteps | Where-Object {
        $_ -match $credsInputPattern
    }).Count -gt 0
    $runnerIdentityAuthTypePattern = '(?im)^\s+auth-type:\s*[''"]?IDENTITY[''"]?\s*(?:#.*)?$'
    $usesOidcLogin = @($azureLoginSteps | Where-Object {
        $_ -match $clientIdInputPattern -and
        $_ -match $tenantIdInputPattern -and
        $_ -match $subscriptionIdInputPattern -and
        $_ -notmatch $credsInputPattern -and
        $_ -notmatch $runnerIdentityAuthTypePattern
    }).Count -gt 0
    $usesRunnerIdentityLogin = @($azureLoginSteps | Where-Object {
        $_ -match $runnerIdentityAuthTypePattern
    }).Count -gt 0
    $usesPagesDeploy = @(Get-ActionStepBlocks -JobContent $JobContent -ActionPattern '(?m)^\s*(?:-\s+)?uses:\s*[''"]?actions/deploy-pages@').Count -gt 0

    if ($hasOidcPermission -and ($usesOidcLogin -or $usesPagesDeploy)) {
        [void]$caps.Add('oidc')
    }

    if ($usesCredentialLogin) {
        [void]$caps.Add('credential-auth')
    }

    if ($usesAzureLogin) {
        [void]$caps.Add('public-cloud-deploy')
    }

    if ($usesPagesDeploy) {
        [void]$caps.Add('public-pages-deploy')
    }

    $executableRunContent = @(Get-ExecutableRunContents -JobContent $JobContent) -join "`n"
    $dockerBuildPushSteps = @(Get-ActionStepBlocks `
        -JobContent $JobContent `
        -ActionPattern '(?m)^\s*(?:-\s+)?uses:\s*[''"]?docker/build-push-action@')
    $usesDockerBuildPush = $dockerBuildPushSteps.Count -gt 0
    $usesDockerBuildPushPublish = @($dockerBuildPushSteps | Where-Object {
        $_ -match '(?im)^\s+push:\s*[''"]?true[''"]?\s*(?:#.*)?$'
    }).Count -gt 0

    if ($executableRunContent -match '(?im)(?:^|&&|\|\||;|\bthen\s+)\s*docker\s+push\b' -or
        $usesDockerBuildPushPublish) {
        [void]$caps.Add('public-registry-publish')
    }
    elseif ($executableRunContent -match '(?im)(?:^|&&|\|\||;|\bthen\s+)\s*docker\s+build\b' -or
        $usesDockerBuildPush -or
        $executableRunContent -match '(?im)(?:^|&&|\|\||;|\bthen\s+)\s*az\s+bicep\s+build\b') {
        [void]$caps.Add('public-build')
    }

    if ($executableRunContent -match '(?im)(?:^|&&|\|\||;|\bthen\s+)\s*gh\s+release\s+(create|upload)\b' -or
        $executableRunContent -match '(?im)(?:^|&&|\|\||;|\bthen\s+)\s*git\s+push\b') {
        [void]$caps.Add('public-release-publish')
    }

    $deployWorkflowAllowList = @(
        'close-production-issues.yml',
        'docs-production.yml',
        'extension-deploy.yml',
        'mcp-deploy.yml',
        'portal-deploy.yml',
        'publish-to-production.yml',
        'release.yml'
    )

    $deployJobAllowList = @(
        'deploy',
        'build-push',
        'release'
    )

    # Public-API-only dispatch jobs: these only call the public GitHub REST API
    # (api.github.com) to trigger workflows on the production mirror. They use a
    # token secret but require no private network or self-hosted runtime, so they
    # run safely on github-hosted-linux. Classify them as public API dispatches
    # rather than generic credentialed deployment jobs. Key by workflow AND job
    # so a future deployment job added to either file is classified independently.
    $publicApiDispatchAllowList = @(
        'close-production-issues.yml|close-issues',
        'docs-production.yml|dispatch-production-docs'
    )
    $isPublicApiDispatch = $publicApiDispatchAllowList -contains $workflowJobKey

    if (-not $isPublicApiDispatch -and
        ($deployWorkflowAllowList -contains $WorkflowName.ToLowerInvariant() -or
        $deployJobAllowList -contains $JobName.ToLowerInvariant())) {
        [void]$caps.Add('deployment-credentials')
    }

    if ($WorkflowName.ToLowerInvariant() -eq 'release.yml') {
        [void]$caps.Add('deployment-credentials')
    }

    if (-not $isPublicApiDispatch -and
        $JobContent -match 'environment:\s*production') {
        [void]$caps.Add('deployment-credentials')
    }

    if ($isPublicApiDispatch) {
        [void]$caps.Add('public-api-dispatch')
    }

    $yamlStructuralContent = Get-YamlStructuralContent -Content $JobContent
    foreach ($marker in [regex]::Matches(
        $yamlStructuralContent,
        '^(?:\s*#|\s*[A-Za-z0-9_.-]+:\s+[^#\r\n]+\s+#)\s*runner-capability:\s*(private-network|runner-managed-identity)\s*$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
            [System.Text.RegularExpressions.RegexOptions]::Multiline
    )) {
        [void]$caps.Add($marker.Groups[1].Value.ToLowerInvariant())
    }

    foreach ($capability in @($ContractRequiredCapabilities)) {
        if ($capability -in @('private-network', 'runner-managed-identity')) {
            [void]$caps.Add($capability)
        }
    }

    if ($usesRunnerIdentityLogin -or
        (Test-RunnerIdentityRunContent -JobContent $JobContent)) {
        [void]$caps.Add('runner-managed-identity')
    }

    if ($JobContent -match 'uses:\s*[''"]?[^\s''"]+/\.github/workflows/') {
        [void]$caps.Add('delegated-runner')
    }

    if ($JobContent -match '(?m)^\s{4}uses:\s*[^\r\n]+') {
        [void]$caps.Add('delegated-runner')
    }

    if ($JobContent -match 'permissions:\s*[\r\n]+\s+contents:\s*read' -and
        $JobContent -notmatch 'id-token:\s*write' -and
        $JobContent -notmatch 'environment:\s*production') {
        [void]$caps.Add('public-ci')
    }

    if ($JobContent -match 'windows-latest') {
        [void]$caps.Add('windows-runtime')
    }

    if ($JobContent -match 'macos') {
        [void]$caps.Add('macos-runtime')
    }

    if ($JobContent -match 'pull_request_target') {
        [void]$caps.Add('untrusted-fork-safe')
    }

    if ($JobContent -match '(?s)matrix:.*ubuntu-latest' -and $JobContent -match '(?s)matrix:.*windows-latest') {
        [void]$caps.Add('multi-os-matrix')
    }

    return @($caps | Sort-Object)
}

function Get-RecommendedRunnerClass {
    param(
        [string[]]$Capabilities,
        [object[]]$RunnerClasses
    )

    $matches = @()
    foreach ($runnerClass in $RunnerClasses) {
        if ($runnerClass.PSObject.Properties.Name -contains 'recommend_for_audit' -and
            $runnerClass.recommend_for_audit -eq $false) {
            continue
        }

        $requiredAll = @($runnerClass.required_capabilities | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        })
        $requiredAny = @($runnerClass.required_capabilities_any | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        })
        $matchesAll = @($requiredAll | Where-Object { $Capabilities -notcontains $_ }).Count -eq 0
        $matchesAny = $requiredAny.Count -eq 0 -or
            @($requiredAny | Where-Object { $Capabilities -contains $_ }).Count -gt 0
        if ($matchesAll -and $matchesAny) {
            $matches += [pscustomobject]@{
                RunnerClass = [string]$runnerClass.runner_class
                Priority = [int]$runnerClass.recommendation_priority
            }
        }
    }

    $selected = @($matches | Sort-Object -Property @{ Expression = 'Priority'; Descending = $true }, RunnerClass | Select-Object -First 1)
    if ($selected.Count -eq 0) {
        return 'unknown'
    }
    return $selected[0].RunnerClass
}

function Get-AssignmentStatus {
    param(
        [string]$ActualRunnerClass,
        [string]$RecommendedRunnerClass
    )

    if ($ActualRunnerClass -eq 'reusable-workflow' -and $RecommendedRunnerClass -eq 'reusable-workflow') { return 'aligned' }
    if ($ActualRunnerClass -eq $RecommendedRunnerClass) { return 'aligned' }
    if ($ActualRunnerClass -eq 'configurable-deploy' -and $RecommendedRunnerClass -eq 'self-hosted-linux') { return 'conditional' }
    if ($ActualRunnerClass -eq 'configurable-release' -and $RecommendedRunnerClass -eq 'self-hosted-linux') { return 'conditional' }
    return 'mismatch'
}

function Escape-MarkdownCell {
    param(
        [string]$Value
    )

    if ($null -eq $Value) { return '' }
    return ($Value -replace '\|', '\|')
}

$contractFilePath = if ([System.IO.Path]::IsPathRooted($ContractPath)) {
    $ContractPath
}
else {
    Join-Path $repoRoot $ContractPath
}
$contracts = @()
$contractLookup = @{}
$contractDocumentViolations = @()
if (Test-Path $contractFilePath) {
    $contractData = Get-Content $contractFilePath -Raw | ConvertFrom-Json
    $contractsProperty = $contractData.PSObject.Properties['contracts']
    if ($null -eq $contractsProperty -or $contractsProperty.Value -isnot [System.Array]) {
        $contractDocumentViolations += [pscustomobject]@{
            Workflow = '(global)'
            Job = '(global)'
            Rule = 'contract-collection'
            Message = 'The v2 contracts property must be an array.'
        }
    }
    else {
        $contracts = @($contractsProperty.Value)
    }
    foreach ($contract in $contracts) {
        $contractLookup["$($contract.workflow)|$($contract.job)"] = $contract
    }
}

$workflowFiles = Get-ChildItem $workflowDir -Filter '*.yml' -File | Where-Object { $_.Name -notmatch '\.lock\.yml$' -and $_.Name -ne 'README.md' } | Sort-Object Name
$rows = @()
$jobLookup = @{}

foreach ($workflow in $workflowFiles) {
    $workflowContent = Get-Content $workflow.FullName -Raw
    $rootPermissionsContent = Get-YamlKeyBlock -Content $workflowContent -Key 'permissions' -Indent 0
    $jobBlocks = Get-WorkflowJobBlocks -WorkflowPath $workflow.FullName
    foreach ($job in $jobBlocks) {
        $runsOnRaw = Get-RunsOnRaw -JobContent $job.Content
        $timeoutMinutes = Get-TimeoutMinutes -JobContent $job.Content
        $actualRunnerClass = Get-ActualRunnerClass -RunsOnRaw $runsOnRaw -JobContent $job.Content
        $contractKey = "$($workflow.Name)|$($job.JobKey)"
        $contractRequiredCapabilities = if ($contractLookup.ContainsKey($contractKey)) {
            @($contractLookup[$contractKey].required_capabilities)
        }
        else {
            @()
        }
        $requiredCaps = Get-RequiredCapabilities `
            -WorkflowName $workflow.Name `
            -JobName $job.JobKey `
            -JobContent $job.Content `
            -RootPermissionsContent $rootPermissionsContent `
            -ContractRequiredCapabilities $contractRequiredCapabilities
        $recommendedRunnerClass = Get-RecommendedRunnerClass -Capabilities $requiredCaps -RunnerClasses $runnerClasses
        $status = Get-AssignmentStatus -ActualRunnerClass $actualRunnerClass -RecommendedRunnerClass $recommendedRunnerClass

        $row = [pscustomobject]@{
            Workflow               = $workflow.Name
            Job                    = $job.JobKey
            RequiredCapabilities   = ($requiredCaps -join ', ')
            RecommendedRunnerClass = $recommendedRunnerClass
            ActualRunnerClass      = $actualRunnerClass
            RunsOn                 = if ($runsOnRaw) { $runsOnRaw } else { '(missing)' }
            TimeoutMinutes         = $timeoutMinutes
            Status                 = $status
        }

        $rows += $row
        $jobLookup["$($workflow.Name)|$($job.JobKey)"] = [pscustomobject]@{
            Row        = $row
            JobContent = $job.Content
        }
    }
}

$mismatches = @($rows | Where-Object { $_.Status -eq 'mismatch' })
$conditionals = @($rows | Where-Object { $_.Status -eq 'conditional' })
$unclassified = @($rows | Where-Object { $_.ActualRunnerClass -in @('unknown', 'missing-runs-on') })
$contractViolations = @($contractDocumentViolations)

if (Test-Path $contractFilePath) {
    if ($contractData.version -ne 2) {
        $contractViolations += [pscustomobject]@{
            Workflow = '(global)'
            Job = '(global)'
            Rule = 'contract-schema-version'
            Message = "Contract schema version '$($contractData.version)' is invalid; expected version 2."
        }
    }

    $seenContractKeys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($contract in $contracts) {
        $key = "$($contract.workflow)|$($contract.job)"
        if (-not $seenContractKeys.Add($key)) {
            $contractViolations += [pscustomobject]@{
                Workflow = $contract.workflow
                Job = $contract.job
                Rule = 'duplicate-contract'
                Message = 'Duplicate workflow/job routing contract.'
            }
        }

        foreach ($requiredField in @(
            'workflow',
            'job',
            'allowed_runner_classes',
            'required_capabilities',
            'forbidden_capabilities',
            'max_timeout_minutes'
        )) {
            if ($contract.PSObject.Properties.Name -notcontains $requiredField) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'contract-v2-field'
                    Message = "Missing required v2 contract field '$requiredField'."
                }
            }
        }

        foreach ($arrayField in @(
            'allowed_runner_classes',
            'required_capabilities',
            'forbidden_capabilities'
        )) {
            $arrayProperty = $contract.PSObject.Properties[$arrayField]
            if ($null -eq $arrayProperty -or $arrayProperty.Value -isnot [System.Array]) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'contract-array-field'
                    Message = "Contract field '$arrayField' must be an array."
                }
            }
            elseif (@($arrayProperty.Value | Where-Object {
                -not [string]::IsNullOrWhiteSpace([string]$_)
            }).Count -eq 0) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'contract-nonempty-array'
                    Message = "Contract field '$arrayField' must contain at least one value."
                }
            }
            elseif ($arrayField -in @('required_capabilities', 'forbidden_capabilities')) {
                foreach ($capability in @($arrayProperty.Value)) {
                    if ($supportedCapabilities -notcontains $capability) {
                        $contractViolations += [pscustomobject]@{
                            Workflow = $contract.workflow
                            Job = $contract.job
                            Rule = 'known-capability'
                            Message = "Capability '$capability' is not defined in the runner capability catalog."
                        }
                    }
                }
            }
        }

        $maxTimeoutMinutes = $null
        if ($contract.max_timeout_minutes -is [long] -and $contract.max_timeout_minutes -gt 0) {
            $maxTimeoutMinutes = [long]$contract.max_timeout_minutes
        }
        else {
            $contractViolations += [pscustomobject]@{
                Workflow = $contract.workflow
                Job = $contract.job
                Rule = 'contract-positive-integer-timeout'
                Message = 'max_timeout_minutes must be a positive integer.'
            }
        }

        if (-not $jobLookup.ContainsKey($key)) {
            $contractViolations += [pscustomobject]@{
                Workflow = $contract.workflow
                Job = $contract.job
                Rule = 'job-exists'
                Message = 'Contracted workflow/job was not found in repository workflows.'
            }
            continue
        }

        $jobInfo = $jobLookup[$key]
        $row = $jobInfo.Row
        $jobContent = $jobInfo.JobContent

        if ($null -ne $contract.allowed_runner_classes -and $contract.allowed_runner_classes.Count -gt 0) {
            $allowedClasses = @($contract.allowed_runner_classes)
            foreach ($allowedClass in $allowedClasses) {
                if ($classNames -notcontains $allowedClass) {
                    $contractViolations += [pscustomobject]@{
                        Workflow = $contract.workflow
                        Job = $contract.job
                        Rule = 'known-runner-class'
                        Message = "Allowed runner class '$allowedClass' is not defined in the runner class catalog."
                    }
                }
            }
            if ($allowedClasses -notcontains $row.ActualRunnerClass) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'allowed-runner-classes'
                    Message = "Runner class '$($row.ActualRunnerClass)' is not in allowed classes: $($allowedClasses -join ', ')."
                }
            }
        }

        if ($null -ne $maxTimeoutMinutes) {
            if ($null -eq $row.TimeoutMinutes) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'max-timeout-minutes'
                    Message = "Missing timeout-minutes; expected <= $maxTimeoutMinutes."
                }
            }
            elseif ([long]$row.TimeoutMinutes -gt $maxTimeoutMinutes) {
                $contractViolations += [pscustomobject]@{
                    Workflow = $contract.workflow
                    Job = $contract.job
                    Rule = 'max-timeout-minutes'
                    Message = "timeout-minutes is $($row.TimeoutMinutes); expected <= $maxTimeoutMinutes."
                }
            }
        }

        if ($null -ne $contract.required_job_markers -and $contract.required_job_markers.Count -gt 0) {
            foreach ($marker in @($contract.required_job_markers)) {
                if ($jobContent -notmatch [regex]::Escape($marker)) {
                    $contractViolations += [pscustomobject]@{
                        Workflow = $contract.workflow
                        Job = $contract.job
                        Rule = 'required-job-marker'
                        Message = "Missing required marker '$marker'."
                    }
                }
            }
        }

        $rowCapabilities = @($row.RequiredCapabilities -split ',' | ForEach-Object { $_.Trim() })
        if ($null -ne $contract.required_capabilities -and $contract.required_capabilities.Count -gt 0) {
            foreach ($capability in @($contract.required_capabilities)) {
                if ($rowCapabilities -notcontains $capability) {
                    $contractViolations += [pscustomobject]@{
                        Workflow = $contract.workflow
                        Job = $contract.job
                        Rule = 'required-capability'
                        Message = "Missing required capability '$capability'."
                    }
                }
            }
        }

        if ($null -ne $contract.forbidden_capabilities -and $contract.forbidden_capabilities.Count -gt 0) {
            foreach ($capability in @($contract.forbidden_capabilities)) {
                if ($rowCapabilities -contains $capability) {
                    $contractViolations += [pscustomobject]@{
                        Workflow = $contract.workflow
                        Job = $contract.job
                        Rule = 'forbidden-capability'
                        Message = "Forbidden capability '$capability' was inferred."
                    }
                }
            }
        }
    }
}
elseif ($FailOnContractViolation) {
    $contractViolations += [pscustomobject]@{
        Workflow = '(global)'
        Job = '(global)'
        Rule = 'contract-file-present'
        Message = "Runner contract file not found: $ContractPath"
    }
}

$summary = [pscustomobject]@{
    total_workflows    = $workflowFiles.Count
    total_jobs         = $rows.Count
    mismatches         = $mismatches.Count
    conditional_routes = $conditionals.Count
    unclassified_jobs  = $unclassified.Count
    contracted_jobs    = if ($null -ne $contracts) { @($contracts).Count } else { 0 }
    contract_violations = $contractViolations.Count
}

if ($OutputFormat -eq 'json') {
    $result = [pscustomobject]@{
        summary            = $summary
        jobs               = $rows
        contract_violations = $contractViolations
    } | ConvertTo-Json -Depth 5
}
else {
    $lines = @()
    $lines += '# Workflow Runner Capability Audit'
    $lines += ''
    $lines += "| Metric | Value |"
    $lines += "|---|---|"
    $lines += "| Workflows scanned | $($summary.total_workflows) |"
    $lines += "| Jobs classified | $($summary.total_jobs) |"
    $lines += "| Mismatches | $($summary.mismatches) |"
    $lines += "| Conditional routes | $($summary.conditional_routes) |"
    $lines += "| Unclassified jobs | $($summary.unclassified_jobs) |"
    $lines += "| Contracted jobs | $($summary.contracted_jobs) |"
    $lines += "| Contract violations | $($summary.contract_violations) |"
    $lines += ''
    $lines += "| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | Status |"
    $lines += "|---|---|---|---|---|---|"
    foreach ($row in $rows) {
        $lines += "| $(Escape-MarkdownCell $row.Workflow) | $(Escape-MarkdownCell $row.Job) | $(Escape-MarkdownCell $row.RequiredCapabilities) | $(Escape-MarkdownCell $row.RecommendedRunnerClass) | $(Escape-MarkdownCell $row.ActualRunnerClass) | $(Escape-MarkdownCell $row.Status) |"
    }

    if ($mismatches.Count -gt 0) {
        $lines += ''
        $lines += '## Mismatch Details'
        $lines += ''
        $lines += "| Workflow | Job | Required capabilities | Recommended runner class | Actual runner class | runs-on |"
        $lines += "|---|---|---|---|---|---|"
        foreach ($row in $mismatches) {
            $lines += "| $(Escape-MarkdownCell $row.Workflow) | $(Escape-MarkdownCell $row.Job) | $(Escape-MarkdownCell $row.RequiredCapabilities) | $(Escape-MarkdownCell $row.RecommendedRunnerClass) | $(Escape-MarkdownCell $row.ActualRunnerClass) | $(Escape-MarkdownCell $row.RunsOn) |"
        }
    }

    if ($contractViolations.Count -gt 0) {
        $lines += ''
        $lines += '## Runner Contract Violations'
        $lines += ''
        $lines += '| Workflow | Job | Rule | Message |'
        $lines += '|---|---|---|---|'
        foreach ($violation in $contractViolations) {
            $lines += "| $(Escape-MarkdownCell $violation.Workflow) | $(Escape-MarkdownCell $violation.Job) | $(Escape-MarkdownCell $violation.Rule) | $(Escape-MarkdownCell $violation.Message) |"
        }
    }

    $result = $lines -join "`n"
}

if ($OutputPath) {
    Set-Content -Path $OutputPath -Value $result
}
else {
    Write-Host $result
}

if ($FailOnMismatch -and ($summary.mismatches -gt 0 -or $summary.unclassified_jobs -gt 0)) {
    throw "Runner capability audit failed with $($summary.mismatches) mismatch(es) and $($summary.unclassified_jobs) unclassified job(s)."
}

if ($FailOnContractViolation -and $summary.contract_violations -gt 0) {
    throw "Runner capability contracts failed with $($summary.contract_violations) violation(s)."
}

exit 0
