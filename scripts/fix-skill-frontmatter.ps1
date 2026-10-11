#Requires -Version 7.0
<#
.SYNOPSIS
Retired legacy skill frontmatter cleanup helper (deprecation guard).

.DESCRIPTION
The former cleanup removed fields such as compatibility, metadata and
allowed-tools that have valid source or portable meanings (#3656). This entry
point is kept only to report the retirement. It never enumerates, reads or
writes any skill or companion file in any mode.

Without -Fix it prints a deprecation notice and exits 0. That exit code means
only that the notice was delivered; it does not mean skills are schema valid,
portable or that nothing needs fixing.

With -Fix it refuses with exit code 2 before any file access. Callers must
handle the failure explicitly and must not treat it as a completed migration.

.PARAMETER Fix
Former mutation switch. Always refused.
#>
[CmdletBinding()]
param(
  [switch]$Fix
)

$notice = @(
  'DEPRECATED: scripts/fix-skill-frontmatter.ps1 is retired (#3656).',
  'Source skill frontmatter validity and the portable projected schema are different questions;',
  'fields such as compatibility, metadata and allowed-tools are not "unsupported" source fields.',
  'Source validation: pwsh scripts/validate-basecoat.ps1 (known profile gaps are tracked in #3655).',
  'Portable export/projection is planned future work in #3654; no conversion command exists yet.',
  'See docs/reference/frontmatter-host-contract.md. No files were read or modified.'
)

if ($Fix) {
  [Console]::Error.WriteLine('ERROR [deprecation] mode=Fix exit=2: the destructive -Fix cleanup is retired and will not modify any skill file.')
  foreach ($line in $notice) { [Console]::Error.WriteLine($line) }
  exit 2
}

foreach ($line in $notice) { Write-Host $line }
exit 0
