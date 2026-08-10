#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$implementation = Join-Path $PSScriptRoot '..\.github\base-coat\scripts\cleanup-branches.ps1'
& $implementation @args
