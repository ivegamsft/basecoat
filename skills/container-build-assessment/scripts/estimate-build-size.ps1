#!/usr/bin/env pwsh
<#
.SYNOPSIS
Estimate final Docker image size and identify optimization opportunities.

.PARAMETER Analysis
JSON object containing analysis output from previous steps (as string).
#>

param([string]$Analysis)

# Parse combined analysis if provided
$analysisObj = if ($Analysis) { $Analysis | ConvertFrom-Json } else { @{} }

$result = @{
    base_image_size = "940 MB"
    dependencies_size = if ($analysisObj.estimated_node_modules_size) { 
        $analysisObj.estimated_node_modules_size 
    } else { 
        "unknown" 
    }
    application_code_size = "2 MB"
    estimated_final_size = "1.39 GB"
    optimization_opportunities = @(
        "Use node:18-alpine instead of node:18 (saves ~800 MB)"
        "Remove node_modules in production multi-stage build"
        "Combine RUN commands to reduce layers"
        "Use .dockerignore to exclude unnecessary files"
        "Consider distroless image for production"
    )
    multi_stage_recommended = if ($analysisObj.has_multistage) { $false } else { $true }
    size_reduction_potential = if ($analysisObj.base_image -match 'alpine|distroless') {
        "20%"
    } else {
        "60%"
    }
}

$result | ConvertTo-Json -Depth 3
