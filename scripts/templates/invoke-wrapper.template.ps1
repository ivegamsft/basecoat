<#
.SYNOPSIS
{{WRAPPER_SYNOPSIS}}

.DESCRIPTION
{{WRAPPER_DESCRIPTION}}

Auto-generated wrapper for {{ASSET_TYPE}}: {{ASSET_NAME}}
Source: {{SOURCE_PATH}}

.PARAMETER Mode
Execution mode: 'interactive' (default) for CLI prompts, 'batch' for scripted execution.

.PARAMETER OutputFormat
Output format: 'text' (default), 'json', or 'markdown'.

.PARAMETER ConfigFile
Optional YAML config file with pre-set parameters.

{{PARAMETER_DOCUMENTATION}}

.EXAMPLE
PS> .\{{SCRIPT_NAME}} -Mode interactive
Prompts for all required parameters interactively.

.EXAMPLE
PS> .\{{SCRIPT_NAME}} -ConfigFile params.yaml -OutputFormat json
Loads parameters from YAML file and returns JSON output.

#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('interactive', 'batch')]
    [string]$Mode = 'interactive',

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json', 'markdown')]
    [string]$OutputFormat = 'text',

    [Parameter(Mandatory = $false)]
    [string]$ConfigFile,

    {{PARAMETER_DECLARATIONS}}
)

$ErrorActionPreference = 'Stop'

# Helper: Parse YAML config if provided
function Read-YamlConfig {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Warning "Config file not found: $Path"
        return @{}
    }
    
    # Simple YAML parser (key: value lines)
    $config = @{}
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^:]+):\s*(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"''')
            $config[$key] = $value
        }
    }
    return $config
}

# Helper: Prompt for missing required parameters
function Get-RequiredParameters {
    param([hashtable]$Params, [array]$Required)
    
    foreach ($param in $Required) {
        if (-not $Params.ContainsKey($param) -or [string]::IsNullOrEmpty($Params[$param])) {
            $prompt = switch ($param) {
                {{PARAMETER_PROMPTS}}
                default { "$param (required): " }
            }
            $Params[$param] = Read-Host $prompt
        }
    }
    return $Params
}

# Helper: Format output
function Format-Output {
    param(
        [hashtable]$Result,
        [string]$Format = 'text'
    )
    
    switch ($Format) {
        'json' {
            $Result | ConvertTo-Json -Depth 10
        }
        'markdown' {
            $Result | ForEach-Object {
                "| $($_.Key) | $($_.Value) |"
            }
        }
        default {
            $Result | ForEach-Object {
                "$($_.Key): $($_.Value)"
            }
        }
    }
}

# ====== MAIN EXECUTION ======

try {
    $parameters = @{}
    
    # Load config file if provided
    if ($ConfigFile) {
        $parameters = Read-YamlConfig -Path $ConfigFile
    }
    
    # Override with script parameters (if provided)
    $PSBoundParameters.GetEnumerator() | Where-Object {
        $_.Key -notin @('Mode', 'OutputFormat', 'ConfigFile', 'Verbose', 'Debug')
    } | ForEach-Object {
        $parameters[$_.Key] = $_.Value
    }
    
    # Prompt for required parameters in interactive mode
    if ($Mode -eq 'interactive') {
        {{REQUIRED_PARAMETERS_LIST}}
        $requiredParams = @({{REQUIRED_PARAMETERS_ARRAY}})
        $parameters = Get-RequiredParameters -Params $parameters -Required $requiredParams
    }
    
    # Validate required parameters exist
    {{REQUIRED_PARAMETERS_VALIDATION}}
    
    # ====== EXECUTE ASSET LOGIC ======
    # This section is where the actual skill/agent logic runs
    # For now: return a placeholder result showing parameters were captured
    
    $result = @{
        status = 'success'
        assetType = '{{ASSET_TYPE}}'
        assetName = '{{ASSET_NAME}}'
        executedAt = (Get-Date -Format 'o')
        parameters = $parameters
        message = 'Execution completed successfully'
    }
    
    # TODO: Replace placeholder with actual agent/skill invocation
    # This might call the Copilot SDK, execute a PowerShell script, or invoke a tool
    
    Format-Output -Result $result -Format $OutputFormat
    exit 0
}
catch {
    $errorResult = @{
        status = 'error'
        assetType = '{{ASSET_TYPE}}'
        assetName = '{{ASSET_NAME}}'
        executedAt = (Get-Date -Format 'o')
        error = $_.Exception.Message
        details = $_.ScriptStackTrace
    }
    
    Format-Output -Result $errorResult -Format $OutputFormat | Write-Error
    exit 1
}
