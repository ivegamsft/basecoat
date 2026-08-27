<#
.SYNOPSIS
    Adopt or refresh the BaseCoat overlay in a consumer repository.

.DESCRIPTION
    Windows-first (PowerShell 5.1+) bootstrap for consuming organisations.
    Detects whether this is a fresh adoption or a refresh, downloads the
    BaseCoat assets, copies them into the standard overlay paths, validates
    the result, and optionally opens a pull request.

    Fresh install layout:
        .github/base-coat/          -- full BaseCoat reference copy
        .github/instructions/       -- Copilot instruction files
        .github/prompts/            -- Copilot prompt files
        .github/skills/             -- Copilot skill directories
        .github/agents/             -- Agent definition files (*.agent.md)
        .agents/skills/             -- Cross-client Agent Skills interop

    Environment variables (all optional):
        BASECOAT_REPO       GitHub repo slug or HTTPS URL  (default: IBuySpy-Shared/basecoat)
        BASECOAT_REF        Branch/tag to pull from         (default: main)
        BASECOAT_TARGET_DIR Path inside consumer repo       (default: .github/base-coat)

.PARAMETER BasecoatRepo
    GitHub repo (org/name or full HTTPS URL).
    Defaults to BASECOAT_REPO env var, then 'IBuySpy-Shared/basecoat'.

.PARAMETER Ref
    Branch or tag to pull from BaseCoat. Defaults to 'main'.

.PARAMETER TargetDir
    Relative path within the consumer repo to install the reference copy.
    Defaults to '.github/base-coat'.

.PARAMETER Silent
    Skip all interactive prompts; suitable for CI use.

.PARAMETER SkipPR
    Do not offer to open a pull request after a successful install/refresh.

.PARAMETER DryRun
    Show what would be done without copying any files.

.EXAMPLE
    # Interactive fresh install
    pwsh scripts/bootstrap-basecoat.ps1

.EXAMPLE
    # CI refresh — no prompts, no PR, explicit repo
    pwsh scripts/bootstrap-basecoat.ps1 -Silent -SkipPR -BasecoatRepo "MyOrg/basecoat"

.EXAMPLE
    # Preview what would change
    pwsh scripts/bootstrap-basecoat.ps1 -DryRun
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$BasecoatRepo = $env:BASECOAT_REPO,
    [string]$Ref          = $(if ($env:BASECOAT_REF) { $env:BASECOAT_REF } else { 'main' }),
    [string]$TargetDir    = $(if ($env:BASECOAT_TARGET_DIR) { $env:BASECOAT_TARGET_DIR } else { '.github/base-coat' }),
    [switch]$Silent,
    [switch]$SkipPR,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── output helpers ────────────────────────────────────────────────────────────

function Write-Header([string]$text) {
    Write-Host ''
    Write-Host ('─' * 54) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ('─' * 54) -ForegroundColor Cyan
}

function Write-Ok([string]$msg)   { Write-Host "  ✅  $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  ⚠️   $msg" -ForegroundColor Yellow }
function Write-Fail([string]$msg) { Write-Host "  ❌  $msg" -ForegroundColor Red }
function Write-Info([string]$msg) { Write-Host "  ℹ️   $msg" -ForegroundColor DarkGray }

$script:addedCount   = 0
$script:updatedCount = 0
$script:errCount     = 0

function Confirm-Step([string]$prompt) {
    if ($Silent) { return $true }
    $ans = Read-Host "$prompt [Y/n]"
    return ($ans -eq '' -or $ans -match '^[Yy]')
}

function Test-Cmd([string]$name) {
    return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

# ── Phase 0: prerequisites ────────────────────────────────────────────────────

Write-Host ''
Write-Host '  BaseCoat Bootstrap' -ForegroundColor White
Write-Host "  PowerShell $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
if ($DryRun) { Write-Host '  [DRY RUN — no files will be modified]' -ForegroundColor Yellow }

Write-Header 'Phase 1 — Prerequisites'

# PowerShell version
$psOk = $PSVersionTable.PSVersion.Major -ge 5
if ($psOk) {
    Write-Ok "PowerShell $($PSVersionTable.PSVersion) (5.1+ required)"
} else {
    Write-Fail "PowerShell 5.1 or later required (found $($PSVersionTable.PSVersion))"
    exit 1
}

# git
if (Test-Cmd 'git') {
    $gitVer = (git --version 2>$null)
    Write-Ok "git available ($gitVer)"
} else {
    Write-Fail 'git not found — install from https://git-scm.com'
    exit 1
}

# Inside a git repo?
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Fail 'Not inside a git repository. Run this from within your consumer repo.'
    exit 1
}
Set-Location $repoRoot
Write-Ok "Consumer repo root: $repoRoot"

# gh CLI (optional but recommended)
$ghAvailable = Test-Cmd 'gh'
if ($ghAvailable) {
    $ghVer = (gh --version 2>$null | Select-Object -First 1)
    Write-Ok "GitHub CLI available ($ghVer)"
} else {
    Write-Warn 'GitHub CLI (gh) not found — PR creation will be skipped. Install: https://cli.github.com'
}

# ── Phase 1: resolve BaseCoat repo ───────────────────────────────────────────

Write-Header 'Phase 2 — BaseCoat Source'

if (-not $BasecoatRepo) {
    if ($Silent) {
        $BasecoatRepo = 'IBuySpy-Shared/basecoat'
        Write-Info "Defaulting to $BasecoatRepo (set -BasecoatRepo or BASECOAT_REPO to override)"
    } else {
        $BasecoatRepo = Read-Host "  BaseCoat repo [IBuySpy-Shared/basecoat]"
        if (-not $BasecoatRepo) { $BasecoatRepo = 'IBuySpy-Shared/basecoat' }
    }
}

# Normalise: slug -> HTTPS URL
if ($BasecoatRepo -notmatch '^https?://') {
    $BasecoatRepoUrl = "https://github.com/$BasecoatRepo.git"
} else {
    $BasecoatRepoUrl = $BasecoatRepo
    $BasecoatRepo    = $BasecoatRepoUrl -replace '^https://github\.com/', '' -replace '\.git$', ''
}

Write-Ok "Source: $BasecoatRepoUrl @ $Ref"

# Detect fresh vs refresh
$overlayDir = Join-Path $repoRoot $TargetDir
$isFresh = -not (Test-Path $overlayDir)
$mode = if ($isFresh) { 'Fresh install' } else { 'Refresh' }
Write-Ok "$mode detected (overlay path: $TargetDir)"

if (-not $isFresh) {
    # Show current installed version if available
    $verFile = Join-Path $overlayDir 'version.json'
    if (Test-Path $verFile) {
        try {
            $installed = (Get-Content $verFile -Raw | ConvertFrom-Json).version
            Write-Info "Installed version: $installed"
        } catch {
            Write-Warn "Could not read installed version.json"
        }
    }
}

if (-not (Confirm-Step "  Proceed with $mode?")) {
    Write-Host '  Aborted.' -ForegroundColor Yellow
    exit 0
}

# ── Phase 2: fetch BaseCoat into temp dir ────────────────────────────────────

Write-Header 'Phase 3 — Downloading BaseCoat'

$tempRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$sourcePath = Join-Path $tempRoot 'source'

try {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
        Write-Info "Cloning $BasecoatRepoUrl ($Ref)..."
        $cloneResult = git clone --depth 1 --branch $Ref $BasecoatRepoUrl $sourcePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "git clone failed: $cloneResult"
            exit 1
        }
    } else {
        Write-Info "[DRY RUN] Would clone $BasecoatRepoUrl @ $Ref to temp dir"
    }

    # Read upstream version
    $upstreamVersion = 'unknown'
    if (-not $DryRun) {
        $upstreamVerFile = Join-Path $sourcePath 'version.json'
        if (Test-Path $upstreamVerFile) {
            try {
                $upstreamVersion = (Get-Content $upstreamVerFile -Raw | ConvertFrom-Json).version
            } catch { }
        }
        Write-Ok "BaseCoat $upstreamVersion downloaded"
    }

    # ── Phase 3: copy overlay files ──────────────────────────────────────────

    Write-Header 'Phase 4 — Installing Overlay'

    # Helper: copy a single source item (file or dir) to dest, tracking add vs update
    function Copy-OverlayItem {
        param(
            [string]$Src,
            [string]$Dest,
            [string]$Label
        )
        if (-not (Test-Path $Src)) {
            Write-Warn "Source not found, skipping: $Label"
            return
        }
        $existed = Test-Path $Dest
        if ($DryRun) {
            $action = if ($existed) { 'update' } else { 'add' }
            Write-Info "[DRY RUN] Would $action $Label"
            if ($existed) { $script:updatedCount++ } else { $script:addedCount++ }
            return
        }
        if ($existed) {
            Remove-Item -Path $Dest -Recurse -Force
        }
        Copy-Item -Path $Src -Destination $Dest -Recurse -Force
        if ($existed) {
            Write-Ok "Updated: $Label"
            $script:updatedCount++
        } else {
            Write-Ok "Added:   $Label"
            $script:addedCount++
        }
    }

    $supportedAgentFrontmatterKeys = @('name', 'description', 'tools', 'mcp-servers')

    function Convert-AgentToCliCompatibleContent {
        param(
            [string]$Content
        )

        if ($Content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n?(.*)$') {
            return $Content
        }

        $frontmatter = $Matches[1]
        $body = $Matches[2]
        $frontLines = $frontmatter -split "`r?`n"
        $chunks = [System.Collections.Generic.List[object]]::new()
        $currentChunk = $null

        foreach ($line in $frontLines) {
            if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
                if ($null -ne $currentChunk) {
                    $chunks.Add($currentChunk)
                }
                $currentChunk = [pscustomobject]@{
                    Key   = $Matches[1]
                    Value = $Matches[2]
                    Lines = [System.Collections.Generic.List[string]]::new()
                }
                $currentChunk.Lines.Add($line)
            }
            elseif ($null -ne $currentChunk) {
                $currentChunk.Lines.Add($line)
            }
        }
        if ($null -ne $currentChunk) {
            $chunks.Add($currentChunk)
        }

        $selected = [System.Collections.Generic.List[object]]::new()
        $toolsChunk = $null
        $allowedToolsChunk = $null

        foreach ($chunk in $chunks) {
            if ($chunk.Key -eq 'tools') { $toolsChunk = $chunk }
            if ($chunk.Key -eq 'allowed-tools') { $allowedToolsChunk = $chunk }
            if ($chunk.Key -in $supportedAgentFrontmatterKeys) {
                $selected.Add($chunk)
            }
        }

        if (-not $toolsChunk -and $allowedToolsChunk) {
            $remapped = [pscustomobject]@{
                Key   = 'tools'
                Value = $allowedToolsChunk.Value
                Lines = [System.Collections.Generic.List[string]]::new()
            }
            foreach ($line in $allowedToolsChunk.Lines) {
                if ($line -match '^allowed-tools:') {
                    $remapped.Lines.Add(($line -replace '^allowed-tools:', 'tools:'))
                }
                else {
                    $remapped.Lines.Add($line)
                }
            }
            $selected.Add($remapped)
        }

        $ordered = @()
        foreach ($key in @('name', 'description', 'tools', 'mcp-servers')) {
            $match = $selected | Where-Object { $_.Key -eq $key } | Select-Object -First 1
            if ($match) { $ordered += $match }
        }

        $newFrontmatterLines = [System.Collections.Generic.List[string]]::new()
        foreach ($chunk in $ordered) {
            foreach ($line in $chunk.Lines) {
                $newFrontmatterLines.Add($line)
            }
        }
        $newFrontmatter = ($newFrontmatterLines -join "`n").TrimEnd()

        return "---`n$newFrontmatter`n---`n`n$body"
    }

    # Helper: copy only *.agent.md files from a source directory
    function Copy-AgentFiles {
        param([string]$SrcDir, [string]$DestDir)
        if (-not (Test-Path $SrcDir)) { return }
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
        }
        $agents = Get-ChildItem -Path $SrcDir -Filter '*.agent.md' -ErrorAction SilentlyContinue
        foreach ($agent in $agents) {
            $dest = Join-Path $DestDir $agent.Name
            $existed = Test-Path $dest
            if ($DryRun) {
                $action = if ($existed) { 'update' } else { 'add' }
                Write-Info "[DRY RUN] Would $action agent: $($agent.Name)"
                if ($existed) { $script:updatedCount++ } else { $script:addedCount++ }
            } else {
                $raw = Get-Content -Path $agent.FullName -Raw
                $sanitized = Convert-AgentToCliCompatibleContent -Content $raw
                Set-Content -Path $dest -Value $sanitized -Encoding UTF8
                if ($existed) {
                    Write-Ok "Updated agent: $($agent.Name)"
                    $script:updatedCount++
                } else {
                    Write-Ok "Added agent:   $($agent.Name)"
                    $script:addedCount++
                }
            }
        }

        # Agent references: agent files may link to references/<name>-detail.md for
        # overflow content moved out to satisfy the token budget. Copy the whole
        # subtree so those relative links resolve for installed agents.
        $referencesSrc = Join-Path $SrcDir 'references'
        if (Test-Path $referencesSrc) {
            $referencesDest = Join-Path $DestDir 'references'
            if ($DryRun) {
                Write-Info "[DRY RUN] Would sync agent references subtree"
            } else {
                if (Test-Path $referencesDest) { Remove-Item -Path $referencesDest -Recurse -Force }
                Copy-Item -Path $referencesSrc -Destination $referencesDest -Recurse -Force
                Write-Ok "Synced agent references subtree"
            }
        }
    }

    $githubDir  = Join-Path $repoRoot '.github'
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $overlayDir | Out-Null
        New-Item -ItemType Directory -Force -Path $githubDir  | Out-Null
    }

    # 1. Reference copy: core metadata and asset directories
    foreach ($item in @('README.md', 'CHANGELOG.md', 'version.json',
                        'instructions', 'skills', 'prompts', 'agents', 'docs', 'templates')) {
        Copy-OverlayItem `
            -Src   (Join-Path $sourcePath $item) `
            -Dest  (Join-Path $overlayDir $item) `
            -Label ".github/base-coat/$item"
    }

    # INVENTORY.md — may live in docs/reference/ in newer versions; also copy to overlay root
    $invSrc = Join-Path $sourcePath 'docs/reference/INVENTORY.md'
    if (-not (Test-Path $invSrc)) { $invSrc = Join-Path $sourcePath 'INVENTORY.md' }
    if (Test-Path $invSrc) {
        Copy-OverlayItem -Src $invSrc -Dest (Join-Path $overlayDir 'INVENTORY.md') -Label '.github/base-coat/INVENTORY.md'
    }

    # Remove taxonomy subdirectories from agents reference copy (they contain only READMEs
    # with relative links that break outside the source repo)
    if (-not $DryRun) {
        foreach ($taxDir in @('models', 'orchestrator', 'tasks', 'types')) {
            $taxPath = Join-Path $overlayDir "agents/$taxDir"
            if (Test-Path $taxPath) { Remove-Item -Path $taxPath -Recurse -Force }
        }
    }

    # 2. Copilot-discoverable paths: instructions, prompts, skills
    foreach ($dir in @('instructions', 'prompts', 'skills')) {
        Copy-OverlayItem `
            -Src   (Join-Path $sourcePath $dir) `
            -Dest  (Join-Path $githubDir $dir) `
            -Label ".github/$dir"
    }

    # 3. Agents: *.agent.md only (skip taxonomy subdirs)
    Copy-AgentFiles `
        -SrcDir  (Join-Path $sourcePath 'agents') `
        -DestDir (Join-Path $githubDir 'agents')

    # 4. Cross-client Agent Skills interop (.agents/skills/)
    $agentSkillsDest = Join-Path $repoRoot '.agents' 'skills'
    $skillsSrc       = Join-Path $sourcePath 'skills'
    if (Test-Path $skillsSrc) {
        Copy-OverlayItem -Src $skillsSrc -Dest $agentSkillsDest -Label '.agents/skills'
    }

    # 5. Intake contract templates
    $managedPrTemplate = Join-Path $sourcePath 'templates/intake/PULL_REQUEST_TEMPLATE.md'
    $customPrTemplate = Join-Path $githubDir 'PULL_REQUEST_TEMPLATE.md'
    if ((Test-Path $managedPrTemplate) -and -not (Test-Path $customPrTemplate)) {
        Copy-OverlayItem -Src $managedPrTemplate -Dest $customPrTemplate -Label '.github/PULL_REQUEST_TEMPLATE.md'
    }

    $managedIssueTemplate = Join-Path $sourcePath 'templates/intake/issue.md'
    $customIssueTemplate = Join-Path $githubDir 'ISSUE_TEMPLATE' 'issue.md'
    if ((Test-Path $managedIssueTemplate) -and -not (Test-Path $customIssueTemplate)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $customIssueTemplate) | Out-Null
        }
        Copy-OverlayItem -Src $managedIssueTemplate -Dest $customIssueTemplate -Label '.github/ISSUE_TEMPLATE/issue.md'
    }

    # ── Phase 4: validate ─────────────────────────────────────────────────────

    Write-Header 'Phase 5 — Validation'

    $requiredOverlay = @('README.md', 'CHANGELOG.md', 'version.json', 'instructions', 'agents', 'skills', 'prompts', 'templates')
    $validationOk = $true
    foreach ($item in $requiredOverlay) {
        $path = Join-Path $overlayDir $item
        if ($DryRun -or (Test-Path $path)) {
            Write-Ok "Present: $TargetDir/$item"
        } else {
            Write-Fail "Missing: $TargetDir/$item"
            $validationOk = $false
            $script:errCount++
        }
    }

    # Count assets
    if (-not $DryRun) {
        $agentCount       = @(Get-ChildItem (Join-Path $githubDir 'agents') -Filter '*.agent.md'       -ErrorAction SilentlyContinue).Count
        $instructionCount = @(Get-ChildItem (Join-Path $githubDir 'instructions') -Filter '*.instructions.md' -ErrorAction SilentlyContinue).Count
        $promptCount      = @(Get-ChildItem (Join-Path $githubDir 'prompts') -Filter '*.prompt.md'     -ErrorAction SilentlyContinue).Count
        $skillCount       = @(Get-ChildItem (Join-Path $githubDir 'skills') -Directory                 -ErrorAction SilentlyContinue).Count

        Write-Host ''
        Write-Host "  Asset counts after install:" -ForegroundColor Cyan
        Write-Host "    Agents:       $agentCount" -ForegroundColor White
        Write-Host "    Instructions: $instructionCount" -ForegroundColor White
        Write-Host "    Prompts:      $promptCount" -ForegroundColor White
        Write-Host "    Skills:       $skillCount" -ForegroundColor White
    }

    # Run validate-basecoat.ps1 if present in the overlay
    $validateScript = Join-Path $overlayDir 'scripts' 'validate-basecoat.ps1'
    if (-not (Test-Path $validateScript)) {
        $validateScript = Join-Path $repoRoot 'scripts' 'validate-basecoat.ps1'
    }
    if (-not $DryRun -and (Test-Path $validateScript)) {
        Write-Info "Running validate-basecoat.ps1..."
        try {
            & pwsh -File $validateScript $overlayDir
            Write-Ok 'validate-basecoat.ps1 passed'
        } catch {
            Write-Warn "validate-basecoat.ps1 reported issues (non-fatal): $_"
        }
    }

    # ── Summary ───────────────────────────────────────────────────────────────

    Write-Header 'Summary'
    Write-Host "  Mode:    $mode" -ForegroundColor White
    Write-Host "  Version: $upstreamVersion" -ForegroundColor White
    Write-Host "  Added:   $($script:addedCount)" -ForegroundColor $(if ($script:addedCount -gt 0) { 'Green' } else { 'DarkGray' })
    Write-Host "  Updated: $($script:updatedCount)" -ForegroundColor $(if ($script:updatedCount -gt 0) { 'Cyan' } else { 'DarkGray' })
    Write-Host "  Errors:  $($script:errCount)" -ForegroundColor $(if ($script:errCount -gt 0) { 'Red' } else { 'DarkGray' })

    if (-not $validationOk) {
        Write-Host ''
        Write-Fail "Validation failed — review errors above before committing."
        exit 1
    }

    # ── Phase 5: open PR ──────────────────────────────────────────────────────

    if (-not $SkipPR -and $ghAvailable -and -not $DryRun -and ($script:addedCount + $script:updatedCount) -gt 0) {
        Write-Host ''
        if (Confirm-Step '  Open a pull request with these changes?') {
            $branchName = "chore/basecoat-$upstreamVersion-$(Get-Date -Format 'yyyyMMdd')"
            $commitMsg  = "chore: adopt BaseCoat overlay v$upstreamVersion

Added $($script:addedCount) new file(s), updated $($script:updatedCount) file(s).
Source: $BasecoatRepo @ $Ref

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

            try {
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                git checkout -b $branchName 2>$null
                git add $TargetDir '.github/instructions' '.github/prompts' '.github/skills' '.github/agents' '.agents/skills' 2>$null
                git commit -m $commitMsg 2>$null
                git push -u origin $branchName 2>$null

                $prBody = "## BaseCoat Overlay — v$upstreamVersion

This PR was generated by ``bootstrap-basecoat.ps1``.

| | |
|---|---|
| Source | [$BasecoatRepo]($($BasecoatRepoUrl -replace '\.git$','')) |
| Branch/tag | ``$Ref`` |
| Files added | $($script:addedCount) |
| Files updated | $($script:updatedCount) |

### Review checklist
- [ ] Scan ``$TargetDir/CHANGELOG.md`` for breaking changes
- [ ] Verify any local customisations in ``.github/instructions/`` are preserved
- [ ] Run ``pwsh scripts/validate-basecoat.ps1`` locally to confirm no issues
"
                gh pr create `
                    --title "chore: adopt BaseCoat overlay v$upstreamVersion" `
                    --body  $prBody `
                    --label 'dependencies'

                Write-Ok 'Pull request created.'
                Write-Info "Branch: $branchName"
                Write-Info "Run 'git checkout $currentBranch' to return to your previous branch."
            } catch {
                Write-Warn "PR creation failed: $_"
                Write-Info "Your changes are committed. Open the PR manually."
            }
        }
    }

    Write-Host ''
    Write-Host '  BaseCoat bootstrap complete.' -ForegroundColor Green
    Write-Host ''

} finally {
    if ((Test-Path variable:tempRoot) -and (Test-Path $tempRoot)) {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
