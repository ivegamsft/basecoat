#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$implementation = Join-Path $PSScriptRoot '..\.github\base-coat\scripts\publish-orphaned-lane-ledger.ps1'
& $implementation @args
