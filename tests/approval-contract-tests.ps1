[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
& node (Join-Path $PSScriptRoot 'approval-contract-tests.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Approval contract workflow behavior tests failed.' }
