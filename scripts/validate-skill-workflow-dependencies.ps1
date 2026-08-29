<#
.SYNOPSIS
    Validates that every executable workflow a public skill promises to dispatch
    is actually installable into a downstream consumer repository.

.DESCRIPTION
    Distributed skills and agents sometimes reference `.github/workflows/<name>.yml`
    entrypoints (or name the workflow file bare, e.g. `<name>.yml`) that exist
    only in this repository's own `.github/workflows/` directory. If that
    workflow was never copied into the managed `.github/base-coat/workflows/`
    source, or never registered in `scripts/configure-downstream-workflows.ps1`,
    a downstream consumer that installs the skill/agent has no way to obtain
    the workflow it depends on. The skill then silently fails closed (or
    worse, an agent invents an unrelated fallback route) at runtime instead of
    at install/validation time.

    This script scans every non-private `skills/*/SKILL.md` (plus any
    `references/*.md` docs under that skill's `references/` subdirectory,
    and any runtime script it points at by relative path, e.g.
    `scripts/ship-it/dispatch-intent.ps1`), every
    `agents/**/*.agent.md`, and every `instructions/*.instructions.md`
    (routing instructions are distributed wholesale to every downstream
    consumer verbatim -- see `scripts/bootstrap-basecoat.ps1`'s overlay copy
    of the entire `instructions` directory) for workflow references -- both
    the literal `.github/workflows/<name>.yml` form and bare `<name>.yml`
    mentions that correspond to a real workflow file in this repo -- and
    confirms each referenced workflow is:
      1. present under `.github/workflows/` (this repo can execute it), and
      2. present under `.github/base-coat/workflows/` (it is distributable), and
      3. registered as a `Source` entry in `configure-downstream-workflows.ps1`
         (a downstream repo can actually install it).

    Skills are skipped only when explicitly marked `visibility: private`;
    visibility defaults to public, so skills without an explicit visibility
    field are still validated. Agents have no public/private visibility
    concept (their `visibility` field is a routing tier: basic/specialized/
    advanced/internal) and are always validated.

    Bare-filename matches are narrowly excluded when the surrounding line
    calls out the reference as illustrative (contains "example" or "e.g.",
    case-insensitive) to avoid false positives on placeholder file names.

    Known pre-existing gaps that are not yet fixed are tracked in
    known-workflow-dependency-gaps.json so this validator can be adopted
    without retroactively failing CI on unrelated, already-tracked debt.
    Each entry is scoped to the specific asset path (a prefix-matched
    `scope`, e.g. `skills/docs-site/`) whose justification it documents, so
    an allowlisted workflow filename cannot silently exempt an unrelated
    asset that happens to reference the same filename without its own
    justification.

.EXAMPLE
    pwsh scripts/validate-skill-workflow-dependencies.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw 'This script must be run inside a git repository.'
}
Set-Location $repoRoot

$skillsDir = Join-Path $repoRoot 'skills'
$agentsDir = Join-Path $repoRoot 'agents'
$instructionsDir = Join-Path $repoRoot 'instructions'
$workflowsDir = Join-Path $repoRoot '.github\workflows'
$managedWorkflowsDir = Join-Path $repoRoot '.github\base-coat\workflows'
$installerPath = Join-Path $repoRoot 'scripts\configure-downstream-workflows.ps1'
$knownGapsPath = Join-Path $repoRoot 'scripts\known-workflow-dependency-gaps.json'

foreach ($path in @($skillsDir, $agentsDir, $instructionsDir, $workflowsDir, $managedWorkflowsDir, $installerPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing required path for dependency validation: $path"
    }
}

# Known-gaps entries are scoped to the specific asset path (prefix-matched,
# e.g. "skills/docs-site/") whose justification they document, not just a
# bare workflow filename. A global-by-filename allowlist would let an
# unrelated public skill/instruction later promise to dispatch the same
# workflow filename (e.g. two skills both hardcoding "docs.yml") and have
# that second, unjustified reference silently skip validation too.
$knownGaps = New-Object System.Collections.Generic.List[pscustomobject]
if (Test-Path $knownGapsPath) {
    $raw = Get-Content -Raw -Path $knownGapsPath | ConvertFrom-Json
    foreach ($entry in $raw) {
        if (-not $entry.scope) {
            throw "known-workflow-dependency-gaps.json entry for '$($entry.workflow)' is missing a required 'scope' field."
        }
        [void]$knownGaps.Add($entry)
    }
}

function Test-KnownGap {
    param(
        [string]$WorkflowName,
        [string]$AssetRelativePath
    )

    foreach ($gap in $knownGaps) {
        if ($gap.workflow -eq $WorkflowName -and $AssetRelativePath.Replace('\', '/').StartsWith($gap.scope, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

$installerSource = Get-Content -Raw -Path $installerPath
# Map each installer-registered Source to its actual installed Destination
# filename (and whether it is Supported), so a reference to the pre-install
# Source name can be distinguished from what a downstream consumer actually
# ends up with -- e.g. `pr-auto-merge-executor.yml` installs as
# `basecoat-pr-auto-merge-executor.yml`, so a skill/agent hardcoding the
# literal source name would otherwise be validated against a filename that
# never exists in the consumer's `.github/workflows/`.
#
# Each `[pscustomobject]@{...}` entry in $workflowMap is parsed independently
# via the PowerShell AST (not a single regex spanning multiple properties):
# a regex assuming a fixed property order (e.g. `Supported` always appearing
# before `Class`) can cross object boundaries entirely when one entry's
# property order differs from that assumption -- `check-version.yml`
# declares `Class` before `Supported`, which made a Supported-then-Class
# regex skip past its own Class value and consume the *next* entry's Class
# instead, silently mis-registering (or entirely skipping) that workflow.
# Parsing each hashtable's own KeyValuePairs makes property order
# irrelevant.
$installerAst = [System.Management.Automation.Language.Parser]::ParseFile($installerPath, [ref]$null, [ref]$null)
$workflowMapAssignment = $installerAst.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.Left.VariablePath.UserPath -eq 'workflowMap'
    },
    $true
) | Select-Object -First 1
if (-not $workflowMapAssignment) {
    throw "Could not locate `$workflowMap in $installerPath to parse installer entries."
}
$hashtableAsts = $workflowMapAssignment.Right.FindAll(
    { param($node) $node -is [System.Management.Automation.Language.HashtableAst] },
    $true
)

$installerEntries = @{}
# Reverse lookup so a reference to the already-renamed Destination filename
# (the correct thing for a skill/agent to name, since that is what actually
# exists in a downstream consumer's .github/workflows/) resolves back to its
# Source for the on-disk/distribution checks below, instead of being treated
# as an unregistered/missing workflow.
$destinationToSource = @{}
foreach ($hashtableAst in $hashtableAsts) {
    $props = @{}
    foreach ($pair in $hashtableAst.KeyValuePairs) {
        $key = $pair.Item1.SafeGetValue()
        $props[$key] = $pair.Item2.SafeGetValue()
    }
    if (-not $props.ContainsKey('Source') -or -not $props.ContainsKey('Class')) {
        # Not a workflow-map entry (or malformed) -- skip rather than
        # guessing at defaults for a required field.
        continue
    }
    $source = [string]$props['Source']
    $destination = if ($props.ContainsKey('Destination')) { [string]$props['Destination'] } else { $source }
    $supported = if ($props.ContainsKey('Supported')) { [bool]$props['Supported'] } else { $false }
    $installerEntries[$source] = [pscustomobject]@{
        Destination = $destination
        Supported   = $supported
        Class       = [string]$props['Class']
    }
    if ($destination -ne $source) {
        $destinationToSource[$destination] = $source
    }
}

# `Supported = $true` alone does not mean a workflow is present after the
# *default* downstream install -- the installer's own -InstallClass default
# only includes a subset of Classes (see configure-downstream-workflows.ps1's
# `[string[]]$InstallClass = @(...)` default value, parsed here directly from
# that file so the two can never silently drift apart). A workflow classed
# outside that default set (e.g. 'templates') is opt-in: a downstream
# consumer that installs a public skill/agent referencing it will NOT
# actually receive it unless they separately pass -IncludeTemplates/
# -InstallClass. Referencing such a workflow is fine only if the referencing
# asset documents a fail-closed contract for the case where it's absent
# (mirroring the ship-it skill's "If any is missing, stop and report it"
# convention) -- silently assuming it is present is exactly the original
# #2919 failure mode.
$defaultInstallClassMatch = [regex]::Match($installerSource, "\[string\[\]\]\`$InstallClass\s*=\s*@\(([^)]*)\)")
if (-not $defaultInstallClassMatch.Success) {
    throw "Could not locate the default -InstallClass value in $installerPath to determine which workflow classes install by default."
}
$defaultInstallClasses = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]([regex]::Matches($defaultInstallClassMatch.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }),
    [System.StringComparer]::OrdinalIgnoreCase
)
$failClosedAcknowledgmentPattern = '(?i)stop and report|optional downstream consumer'


function Get-ReferencedWorkflows {
    param(
        [string]$Content
    )

    $referenced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Only match `.github/workflows/<file>` when it is NOT preceded by a
    # third-party `owner/repo/` prefix (e.g. a reusable-workflow `uses:` line
    # like `slsa-framework/slsa-github-generator/.github/workflows/x.yml@v1`).
    # Such references point at another org's own repository/workflow and
    # carry no expectation of being distributed or installable in this repo.
    foreach ($match in [regex]::Matches($Content, '(?<![\w.\-]/[\w.\-]+/)\.github/workflows/([\w.\-]+\.ya?ml)')) {
        [void]$referenced.Add($match.Groups[1].Value)
    }

    # Bare `<name>.yml` mentions carry no `.github/workflows/` prefix, so they
    # must be scoped some other way to avoid matching arbitrary prose that
    # merely contains ".yml". A markdown code span (`` `name.yml` ``) is the
    # convention this repo's skills/agents already use to call out a
    # concrete, contractual workflow filename (see skills/ship-it/SKILL.md),
    # so bare references are recognized by that span, independent of whether
    # the filename already exists on disk -- otherwise a skill that newly
    # references a not-yet-created (or renamed-away) workflow would be
    # silently ignored instead of failing the validation it exists to
    # enforce. Lines flagged as illustrative (example/e.g.) are still
    # excluded to avoid false positives on placeholder file names, as are a
    # small set of well-known filenames this repo's own skills document that
    # are never GitHub Actions workflows (MkDocs/Docker Compose/consumer sync
    # config, issue-template filenames, and similar plain-data conventions).
    $wellKnownNonWorkflowFiles = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@(
            '.basecoat.yml',
            'mkdocs.yml',
            'docker-compose.yml',
            'docker-compose.yaml',
            'environment-map.yml',
            'feature.yml',
            'bug.yml',
            'manifest.yaml',
            'pnpm-workspace.yaml',
            '.eval.yaml',
            'environment.yml'
        ),
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $lines = $Content -split "`r?`n"
    foreach ($line in $lines) {
        if ($line -match '(?i)\bexample\b|\be\.g\.') {
            continue
        }
        foreach ($match in [regex]::Matches($line, '`([\w.\-]+\.ya?ml)`')) {
            $candidate = $match.Groups[1].Value
            if ($wellKnownNonWorkflowFiles.Contains($candidate)) {
                continue
            }
            [void]$referenced.Add($candidate)
        }
    }

    return $referenced
}

function Test-WorkflowDependencies {
    param(
        [string]$FileName,
        [string]$WorkflowName,
        [string]$Content
    )

    # A reference to the already-installed Destination name (the filename a
    # downstream consumer will actually have) is correct as written and
    # should be validated against its Source's distribution state, not
    # treated as an unregistered Source in its own right.
    $sourceName = if ($installerEntries.ContainsKey($WorkflowName)) {
        $WorkflowName
    } elseif ($destinationToSource.ContainsKey($WorkflowName)) {
        $destinationToSource[$WorkflowName]
    } else {
        $WorkflowName
    }

    $rootPath = Join-Path $workflowsDir $sourceName
    $managedPath = Join-Path $managedWorkflowsDir $sourceName
    $entry = $installerEntries[$sourceName]

    $problems = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path $rootPath)) {
        $problems.Add('missing from .github/workflows (not executable in this repo)')
    }
    if (-not (Test-Path $managedPath)) {
        $problems.Add('missing from .github/base-coat/workflows (not distributed)')
    }
    if (-not $entry) {
        $problems.Add('not registered as a Source in scripts/configure-downstream-workflows.ps1 (not installable downstream)')
    } elseif (-not $entry.Supported) {
        $problems.Add('registered but marked Supported = $false in scripts/configure-downstream-workflows.ps1 (installer will not install it downstream)')
    } else {
        if ($entry.Destination -ne $WorkflowName -and $sourceName -eq $WorkflowName) {
            # The installer unconditionally renames the file on install (see
            # configure-downstream-workflows.ps1's Destination handling), so a
            # reference to the pre-install Source name describes a filename that
            # will never exist in a downstream consumer's .github/workflows/.
            $problems.Add("installs downstream as '$($entry.Destination)', not '$WorkflowName' (reference the installed Destination filename, not the Source name)")
        }
        if (-not $defaultInstallClasses.Contains($entry.Class) -and $Content -notmatch $failClosedAcknowledgmentPattern) {
            # Class 'templates'/'internal'/etc. is opt-in: a default `pwsh
            # configure-downstream-workflows.ps1` run will NOT install this
            # workflow, so a downstream consumer of this skill/agent won't
            # have it unless they separately opt in. That's fine only if the
            # referencing asset documents what happens when it's absent --
            # otherwise this is the exact #2919 failure mode (a skill
            # silently assumes a workflow it depends on is present).
            $problems.Add("only installs via opt-in Class '$($entry.Class)' (not part of the default -InstallClass set) and '$FileName' does not document a fail-closed or optional-consumer contract for when it's missing (expected an acknowledgment such as 'stop and report' or 'optional downstream consumer')")
        }
    }

    if ($problems.Count -gt 0) {
        $script:errors.Add("$FileName references '$WorkflowName' but it is: $($problems -join '; ')")
    }
}

$errors = New-Object System.Collections.Generic.List[string]

$skillFiles = Get-ChildItem -Path $skillsDir -Recurse -Filter 'SKILL.md'
foreach ($skillFile in $skillFiles) {
    $content = Get-Content -Raw -Path $skillFile.FullName
    $isPrivate = $content -match '(?m)^visibility:\s*private\s*$'
    if ($isPrivate) {
        continue
    }

    # Scan reachable supporting assets too, not just SKILL.md itself: a
    # skill's references/*.md docs and any runtime scripts it directly
    # invokes (referenced by relative path from SKILL.md, e.g.
    # `scripts/ship-it/dispatch-intent.ps1`) can independently hardcode a
    # workflow filename that SKILL.md itself never mentions. Scanning only
    # SKILL.md let such references silently bypass this validator entirely.
    # Scope is deliberately limited to the `references/` subdirectory (the
    # documented convention for a skill's supporting reference docs, e.g.
    # `skills/issue-triage/references/metadata-contract.md`) rather than
    # every markdown file under the skill -- sibling files like
    # `layer-boundary-matrix-template.md` are illustrative templates/
    # checklists, not dependency-bearing documentation, and scanning them
    # produces false positives on placeholder workflow names.
    $skillDir = $skillFile.Directory.FullName
    $referencesDir = Join-Path $skillDir 'references'
    $combinedContent = [System.Text.StringBuilder]::new()
    [void]$combinedContent.Append($content)
    if (Test-Path $referencesDir) {
        $referenceFiles = Get-ChildItem -Path $referencesDir -Recurse -Filter '*.md' -File
        foreach ($referenceFile in $referenceFiles) {
            [void]$combinedContent.Append("`n").Append((Get-Content -Raw -Path $referenceFile.FullName))
        }
    }

    # Also pull in any runtime script SKILL.md points at by relative path
    # (e.g. `scripts/ship-it/dispatch-intent.ps1`), since those scripts can
    # themselves hardcode a `.github/workflows/*.yml` path independent of
    # anything written in the skill's own markdown.
    foreach ($scriptMatch in [regex]::Matches($content, '`((?:scripts|\.github/base-coat/scripts)/[\w./\-]+\.(?:ps1|sh|py))`')) {
        $scriptRelPath = $scriptMatch.Groups[1].Value
        $scriptFullPath = Join-Path $repoRoot ($scriptRelPath -replace '/', '\')
        if (Test-Path $scriptFullPath) {
            [void]$combinedContent.Append("`n").Append((Get-Content -Raw -Path $scriptFullPath))
        }
    }

    $referencedWorkflows = Get-ReferencedWorkflows -Content $combinedContent.ToString()

    $skillRelativePath = $skillFile.FullName.Substring($repoRoot.ToString().Length + 1) -replace '\\', '/'
    foreach ($workflowName in $referencedWorkflows) {
        if (Test-KnownGap -WorkflowName $workflowName -AssetRelativePath $skillRelativePath) {
            continue
        }
        Test-WorkflowDependencies -FileName $skillFile.Name -WorkflowName $workflowName -Content $combinedContent.ToString()
    }
}

$agentFiles = Get-ChildItem -Path $agentsDir -Recurse -Filter '*.agent.md'
foreach ($agentFile in $agentFiles) {
    $content = Get-Content -Raw -Path $agentFile.FullName
    $referencedWorkflows = Get-ReferencedWorkflows -Content $content

    $agentRelativePath = $agentFile.FullName.Substring($repoRoot.ToString().Length + 1) -replace '\\', '/'
    foreach ($workflowName in $referencedWorkflows) {
        if (Test-KnownGap -WorkflowName $workflowName -AssetRelativePath $agentRelativePath) {
            continue
        }
        Test-WorkflowDependencies -FileName $agentFile.Name -WorkflowName $workflowName -Content $content
    }
}

# Routing instructions (instructions/*.instructions.md) are distributed
# wholesale to every downstream consumer verbatim (see
# scripts/bootstrap-basecoat.ps1's overlay copy of the entire `instructions`
# directory), so any workflow filename they reference -- even inside an
# illustrative debugging-prompt example -- carries the same "this must
# resolve downstream" contract as a skill/agent reference. A stale
# pre-rename Source filename (e.g. `issue-approve.yml`, which the installer
# renames to `basecoat-issue-approve.yml` on install) would otherwise ship
# to every consumer unnoticed.
$instructionFiles = Get-ChildItem -Path $instructionsDir -Recurse -Filter '*.instructions.md'
foreach ($instructionFile in $instructionFiles) {
    $content = Get-Content -Raw -Path $instructionFile.FullName
    $referencedWorkflows = Get-ReferencedWorkflows -Content $content

    $instructionRelativePath = $instructionFile.FullName.Substring($repoRoot.ToString().Length + 1) -replace '\\', '/'
    foreach ($workflowName in $referencedWorkflows) {
        if (Test-KnownGap -WorkflowName $workflowName -AssetRelativePath $instructionRelativePath) {
            continue
        }
        Test-WorkflowDependencies -FileName $instructionFile.Name -WorkflowName $workflowName -Content $content
    }
}

if ($errors.Count -gt 0) {
    Write-Host 'Skill/agent workflow dependency validation FAILED:' -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "  - $e" -ForegroundColor Red
    }
    throw "$($errors.Count) skill/agent reference(s) point to workflow(s) unavailable to downstream consumers."
}

Write-Host 'Skill/agent workflow dependency validation passed: every referenced workflow is installable downstream.' -ForegroundColor Green
