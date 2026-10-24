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
    Run sync in a temporary clone of the consumer repo (with the current
    overlay working tree copied in) and list the files it would add, update
    or remove. The consumer repo is not modified.

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
$script:removedCount = 0
$script:errCount     = 0
$script:changedPaths = New-Object System.Collections.Generic.List[string]
$script:caseRenamedPaths = New-Object System.Collections.Generic.List[string]
$script:removedPaths = New-Object System.Collections.Generic.List[string]

# Hash overlay files sync writes, keyed by repo-relative path (ordinal, so case-only renames count).
function Get-OverlayFileSnapshot([string]$Root) {
    $snapshot = New-Object System.Collections.Hashtable ([System.StringComparer]::Ordinal)
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    foreach ($rel in @('.github', '.agents', $TargetDir)) {
        $base = Join-Path $rootFull $rel
        if (-not (Test-Path -LiteralPath $base)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction SilentlyContinue)) {
            $relPath = $file.FullName.Substring($rootFull.Length).TrimStart('\', '/') -replace '\\', '/'
            $snapshot[$relPath] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    return $snapshot
}

# Dry run (#3818): clone the consumer and copy its current overlay working tree in, so sync runs on a faithful copy.
function New-OverlayPreview([string]$PreviewRoot) {
    $savedErrorAction = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $cloneOutput = git clone --quiet -- $repoRoot $PreviewRoot 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git clone of the consumer repo failed: $cloneOutput" }
    } finally { $ErrorActionPreference = $savedErrorAction }
    foreach ($rel in @('.github', '.agents', $TargetDir)) {
        $dest = Join-Path $PreviewRoot $rel
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        $src = Join-Path $repoRoot $rel
        if (Test-Path -LiteralPath $src) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force
        }
    }
}

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
if ($BasecoatRepo -notmatch '^(https?://|file://)') {
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

if (-not (Confirm-Step "  Proceed with ${mode}?")) {
    Write-Host '  Aborted.' -ForegroundColor Yellow
    exit 0
}

# ── Phase 2: fetch BaseCoat into temp dir ────────────────────────────────────

Write-Header 'Phase 3 — Downloading BaseCoat'

$tempRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "basecoat-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))"
$sourcePath = Join-Path $tempRoot 'source'

try {
    # Dry runs also clone (into the temp dir only) so the preview can run sync.
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Write-Info "Cloning $BasecoatRepoUrl ($Ref)..."
    $cloneResult = git clone --quiet --depth 1 --branch $Ref $BasecoatRepoUrl $sourcePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "git clone failed: $cloneResult"
        exit 1
    }

    # Read upstream version
    $upstreamVersion = 'unknown'
    $upstreamVerFile = Join-Path $sourcePath 'version.json'
    if (Test-Path $upstreamVerFile) {
        try {
            $upstreamVersion = (Get-Content $upstreamVerFile -Raw | ConvertFrom-Json).version
        } catch { }
    }
    Write-Ok "BaseCoat $upstreamVersion downloaded"

    # ── Phase 3: copy overlay files ──────────────────────────────────────────

    Write-Header 'Phase 4 — Installing Overlay'
    $githubDir = Join-Path $repoRoot '.github'

    # Dry runs (#3818) run the same sync in a temporary clone of the consumer, so the preview lists the files a real run would change.
    $installRoot = $repoRoot
    if ($DryRun) {
        $installRoot = Join-Path $tempRoot 'preview'
        Write-Info 'Previewing sync in a temporary clone of the consumer repo...'
        New-OverlayPreview $installRoot
    }
    . {
        # Use the same ownership-aware install and stale-file preflight as sync.
        $savedSource = $env:BASECOAT_TEST_SOURCE_PATH
        $savedRepo = $env:BASECOAT_REPO
        $savedRef = $env:BASECOAT_REF
        $savedTarget = $env:BASECOAT_TARGET_DIR
        $beforeSnapshot = Get-OverlayFileSnapshot $installRoot
        try {
            Set-Location -LiteralPath $installRoot
            $env:BASECOAT_TEST_SOURCE_PATH = $sourcePath
            $env:BASECOAT_REPO = $BasecoatRepoUrl
            $env:BASECOAT_REF = $Ref
            $env:BASECOAT_TARGET_DIR = $TargetDir
            & (Join-Path $sourcePath 'sync.ps1')
        }
        finally {
            Set-Location -LiteralPath $repoRoot
            $env:BASECOAT_TEST_SOURCE_PATH = $savedSource
            $env:BASECOAT_REPO = $savedRepo
            $env:BASECOAT_REF = $savedRef
            $env:BASECOAT_TARGET_DIR = $savedTarget
        }

        # Count the committable files sync actually wrote or removed (#3812).
        $afterSnapshot = Get-OverlayFileSnapshot $installRoot
        $changes = New-Object System.Collections.Generic.List[object]
        foreach ($path in @($afterSnapshot.Keys | Sort-Object)) {
            if (-not $beforeSnapshot.ContainsKey($path)) {
                $changes.Add([pscustomobject]@{ Path = $path; Kind = 'added' })
            } elseif ($beforeSnapshot[$path] -ne $afterSnapshot[$path]) {
                $changes.Add([pscustomobject]@{ Path = $path; Kind = 'updated' })
            }
        }
        foreach ($path in @($beforeSnapshot.Keys | Sort-Object)) {
            if (-not $afterSnapshot.ContainsKey($path)) {
                $changes.Add([pscustomobject]@{ Path = $path; Kind = 'removed' })
            }
        }
        # Only count changes Git can commit: intersect with post-sync `git status` (excludes ignored files,
        # untracked removals and content restored to HEAD). -z output is unquoted; decode it as UTF-8.
        $gitChanged = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        if ($changes.Count -gt 0) {
            $savedErrorAction = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $savedEncoding = [Console]::OutputEncoding
            try {
                [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
                $status = (git -C $installRoot --literal-pathspecs status --porcelain=v1 -z --no-renames --untracked-files=all -- '.github' '.agents' $TargetDir 2>$null) -join "`n"
                if ($LASTEXITCODE -ne 0) { throw "git status failed (exit $LASTEXITCODE) after sync; cannot determine overlay changes." }
                foreach ($entry in ($status -split "`0")) { if ($entry.Length -gt 3) { [void]$gitChanged.Add($entry.Substring(3)) } }
                # Case-only renames (#3821): with core.ignorecase=true git status may report neither casing. Pair them
                # from the snapshots and keep both sides when Git tracks the old casing; the PR step unstages it first.
                $addedByKey = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($change in $changes) { if ($change.Kind -eq 'added') { $addedByKey[$change.Path] = $change.Path } }
                foreach ($change in @($changes | Where-Object { $_.Kind -eq 'removed' -and $addedByKey.ContainsKey($_.Path) })) {
                    if (-not (git -C $installRoot --literal-pathspecs ls-files -- $change.Path 2>$null)) { continue }
                    [void]$gitChanged.Add($change.Path); [void]$gitChanged.Add($addedByKey[$change.Path])
                    $script:caseRenamedPaths.Add($change.Path)
                }
            } finally { [Console]::OutputEncoding = $savedEncoding; $ErrorActionPreference = $savedErrorAction }
        }
        foreach ($change in $changes) {
            if (-not $gitChanged.Contains($change.Path)) { continue }
            $script:changedPaths.Add($change.Path)
            switch ($change.Kind) { 'added' { $script:addedCount++ } 'updated' { $script:updatedCount++ } 'removed' { $script:removedCount++; $script:removedPaths.Add($change.Path) } }
            if ($DryRun) { Write-Info "[DRY RUN] Would $(@{ added = 'add'; updated = 'update'; removed = 'remove' }[$change.Kind]) $($change.Path)" }
        }
    }

    # ── Phase 4: validate ─────────────────────────────────────────────────────

    Write-Header 'Phase 5 — Validation'

    $requiredOverlay = @('README.md', 'CHANGELOG.md', 'version.json', 'instructions', 'agents', 'skills', 'prompts', 'templates')
    $validationOk = $true
    foreach ($item in $requiredOverlay) {
        $path = Join-Path (Join-Path $installRoot $TargetDir) $item
        if (Test-Path $path) {
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
    $validateScript = Join-Path $overlayDir 'scripts/validate-basecoat.ps1'
    if (-not (Test-Path $validateScript)) {
        $validateScript = Join-Path $repoRoot 'scripts/validate-basecoat.ps1'
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
    Write-Host "  Removed: $($script:removedCount)" -ForegroundColor $(if ($script:removedCount -gt 0) { 'Cyan' } else { 'DarkGray' })
    if ($DryRun) { Write-Info 'Dry-run counts are files sync would change, computed in a temporary clone; nothing was written.' }
    Write-Host "  Errors:  $($script:errCount)" -ForegroundColor $(if ($script:errCount -gt 0) { 'Red' } else { 'DarkGray' })

    if (-not $validationOk) {
        Write-Host ''
        Write-Fail "Validation failed — review errors above before committing."
        exit 1
    }

    # ── Phase 5: open PR ──────────────────────────────────────────────────────

    $changeCount = $script:addedCount + $script:updatedCount + $script:removedCount
    if (-not $DryRun -and $changeCount -eq 0) {
        Write-Info 'No committable overlay changes detected; skipping pull request.'
    }
    if (-not $SkipPR -and $ghAvailable -and -not $DryRun -and $changeCount -gt 0) {
        Write-Host ''
        if (Confirm-Step '  Open a pull request with these changes?') {
            $branchName = "chore/basecoat-$upstreamVersion-$(Get-Date -Format 'yyyyMMdd')"
            $commitMsg  = "chore: adopt BaseCoat overlay v$upstreamVersion

Added $($script:addedCount) new file(s), updated $($script:updatedCount) file(s), removed $($script:removedCount) file(s).
Source: $BasecoatRepo @ $Ref

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"

            # PS 5.1 makes redirected native stderr terminate under 'Stop'; rely on git/gh exit codes.
            $savedErrorAction = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            try {
                $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
                git checkout -b $branchName 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git checkout -b $branchName failed" }
                # Commit exactly the files this run changed from a temporary index built from HEAD, leaving any
                # other staged work alone (`commit --only` cannot record case-only renames on core.ignorecase=true,
                # #3821); a pathspec file avoids command-line length limits.
                $pathspecFile = Join-Path $tempRoot 'changed-paths.txt'
                [System.IO.File]::WriteAllLines($pathspecFile, [string[]]$script:changedPaths, (New-Object System.Text.UTF8Encoding($false)))
                $savedIndex = $env:GIT_INDEX_FILE; $env:GIT_INDEX_FILE = Join-Path $tempRoot 'pr-index'
                try {
                    $null = git rev-parse -q --verify HEAD 2>$null
                    if ($LASTEXITCODE -eq 0) { git read-tree HEAD 2>$null } else { git read-tree --empty 2>$null }
                    if ($LASTEXITCODE -ne 0) { throw 'git read-tree failed' }
                    # Unstage removals (including case-renamed old casings) separately so a removed path that is now a
                    # directory never stages its children; then force-add only the selected files that still exist.
                    if ($script:removedPaths.Count -gt 0) {
                        $removedFile = Join-Path $tempRoot 'removed-paths.txt'
                        [System.IO.File]::WriteAllLines($removedFile, [string[]]$script:removedPaths, (New-Object System.Text.UTF8Encoding($false)))
                        git --literal-pathspecs rm --cached --quiet --ignore-unmatch --pathspec-from-file=$removedFile 2>$null
                        if ($LASTEXITCODE -ne 0) { throw 'git rm --cached failed' }
                    }
                    $addPaths = [string[]]@($script:changedPaths | Where-Object { $script:removedPaths -cnotcontains $_ })
                    if ($addPaths.Count -gt 0) {
                        $addFile = Join-Path $tempRoot 'add-paths.txt'
                        [System.IO.File]::WriteAllLines($addFile, $addPaths, (New-Object System.Text.UTF8Encoding($false)))
                        git --literal-pathspecs add --force --pathspec-from-file=$addFile 2>$null
                        if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
                    }
                    git commit -m $commitMsg 2>$null
                    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
                } finally { $env:GIT_INDEX_FILE = $savedIndex }
                # Point the real index at the new commit for these paths.
                git --literal-pathspecs reset -q --pathspec-from-file=$pathspecFile 2>$null
                if ($LASTEXITCODE -ne 0) { throw 'git reset failed' }
                git push -u origin $branchName 2>$null
                if ($LASTEXITCODE -ne 0) { throw "git push origin $branchName failed" }

                $prBody = "## BaseCoat Overlay — v$upstreamVersion

This PR was generated by ``bootstrap-basecoat.ps1``.

| | |
|---|---|
| Source | [$BasecoatRepo]($($BasecoatRepoUrl -replace '\.git$','')) |
| Branch/tag | ``$Ref`` |
| Files added | $($script:addedCount) |
| Files updated | $($script:updatedCount) |
| Files removed | $($script:removedCount) |

### Review checklist
- [ ] Scan ``$TargetDir/CHANGELOG.md`` for breaking changes
- [ ] Verify any local customisations in ``.github/instructions/`` are preserved
- [ ] Run ``pwsh scripts/validate-basecoat.ps1`` locally to confirm no issues
"
                gh pr create `
                    --title "chore: adopt BaseCoat overlay v$upstreamVersion" `
                    --body  $prBody `
                    --label 'dependencies'
                if ($LASTEXITCODE -ne 0) { throw 'gh pr create failed' }
                Write-Ok 'Pull request created.'
                Write-Info "Branch: $branchName"
                Write-Info "Run 'git checkout $currentBranch' to return to your previous branch."
            } catch {
                Write-Warn "PR creation failed: $_"
                Write-Info "Branch: $branchName. Review the step above, then push and open the PR manually."
            } finally {
                $ErrorActionPreference = $savedErrorAction
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
