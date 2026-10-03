$script:BaseCoatDogfoodSkillCategories = @(
    'workflow',
    'flow-governance',
    'governance',
    'platform-governance',
    'sdlc-governance',
    'agent-development',
    'documentation',
    'framework'
)

$script:BaseCoatDogfoodSkillNames = @(
    'ship-it',
    'ship-it-control-loop',
    'sprint-*',
    'flow-*',
    'governance*',
    'backlog-*',
    'ci-*',
    'release-*',
    'create-instruction',
    'create-skill',
    'skill-scripts',
    'repo-cleanup',
    'git-worktrees',
    'rca',
    'handoff',
    'human-in-the-loop',
    'code-review',
    'security',
    'security-operations',
    'refactoring',
    'tech-debt',
    'docs-site',
    'ci-flake-quarantine'
)

$script:BaseCoatDogfoodAgents = @(
    'agentic-sdlc-autonomy.agent.md',
    'basecoat-10-core-agent-designer.agent.md',
    'basecoat-10-core-branch-hygiene-sweeper.agent.md',
    'basecoat-10-core-definition-of-done.agent.md',
    'basecoat-10-core-factory-conductor.agent.md',
    'basecoat-10-core-issue-triage.agent.md',
    'basecoat-10-core-merge-coordinator.agent.md',
    'basecoat-10-core-sprint-planner.agent.md',
    'basecoat-10-core-sprint-project-mapper.agent.md',
    'basecoat-10-core-sprint-retrospective.agent.md',
    'basecoat-50-security-sprint-closeout-auditor.agent.md',
    'basecoat-60-workflow-broken-build-troubleshooter.agent.md',
    'basecoat-60-workflow-release-freeze-enforcer.agent.md',
    'basecoat-60-workflow-release-impact-advisor.agent.md',
    'basecoat-60-workflow-release-manager.agent.md',
    'basecoat-60-workflow-release-readiness-chair.agent.md',
    'basecoat-60-workflow-self-healing-ci.agent.md',
    'basecoat-60-workflow-ship-it-control-loop.agent.md',
    'basecoat-60-workflow-ship-it-orchestrator.agent.md',
    'flow-governance-conductor.agent.md'
)

$script:BaseCoatDogfoodPrompts = @(
    'architect.prompt.md',
    'bugfix.prompt.md',
    'code-review.prompt.md',
    'integrate.prompt.md',
    'plan-sharedStandardsRepo.prompt.md',
    'token-status.prompt.md'
)

function Get-BaseCoatProjectionFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }

    $sourceDirectory = Get-Item -LiteralPath $Path -Force
    if (($sourceDirectory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Projection source contains a symbolic link or reparse point: $($sourceDirectory.FullName)"
    }
    $pendingDirectories = [System.Collections.Generic.Stack[string]]::new()
    $pendingDirectories.Push($sourceDirectory.FullName)

    while ($pendingDirectories.Count -gt 0) {
        $directory = Get-Item -LiteralPath $pendingDirectories.Pop() -Force
        if (($directory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Projection source contains a symbolic link or reparse point: $($directory.FullName)"
        }

        foreach ($item in Get-ChildItem -LiteralPath $directory.FullName -Force) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Projection source contains a symbolic link or reparse point: $($item.FullName)"
            }
            if ($item.PSIsContainer) {
                $pendingDirectories.Push($item.FullName)
            }
            else {
                $item
            }
        }
    }
}

function Test-BaseCoatDogfoodSkill {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory
    )

    $skillPath = Join-Path $Directory.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        return $false
    }
    $skillFile = Get-Item -LiteralPath $skillPath -Force
    if (($skillFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Projection source contains a symbolic link or reparse point: $($skillFile.FullName)"
    }

    $content = Get-Content -LiteralPath $skillPath -Raw
    if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        return $Directory.Name -in $script:BaseCoatDogfoodSkillNames
    }

    $frontmatter = $Matches[1]
    $category = ''
    if ($frontmatter -match '(?m)^category:\s*["'']?([^\r\n"'']+)["'']?\s*$') {
        $category = $Matches[1].Trim()
    }

    if ($category -in $script:BaseCoatDogfoodSkillCategories) {
        return $true
    }
    foreach ($pattern in $script:BaseCoatDogfoodSkillNames) {
        if ($Directory.Name -like $pattern) {
            return $true
        }
    }
    return $false
}

function Get-BaseCoatProjectionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [ValidateSet('Consumer', 'Dogfood')]
        [string]$Mode = 'Consumer'
    )

    $rootItem = Get-Item -LiteralPath $SourceRoot -Force
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Projection source root is a symbolic link or reparse point: $($rootItem.FullName)"
    }
    $resolvedRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
    $entries = [System.Collections.Generic.List[object]]::new()

    function Add-ProjectionTree {
        param(
            [string]$SourceDirectory,
            [string]$DestinationPrefix,
            [string]$GuidanceUnitPrefix,
            [string]$Kind = 'file'
        )

        if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
            return
        }
        $sourceDirectoryPath = (Resolve-Path -LiteralPath $SourceDirectory).Path
        foreach ($file in Get-BaseCoatProjectionFiles -Path $sourceDirectoryPath) {
            $relative = $file.FullName.Substring($sourceDirectoryPath.Length).TrimStart('\', '/') -replace '\\', '/'
            $entries.Add([pscustomobject]@{
                SourcePath = $file.FullName
                DestinationPath = "$DestinationPrefix/$relative"
                GuidanceUnit = "$GuidanceUnitPrefix/$relative"
                Kind = $Kind
            })
        }
    }

    if ($Mode -eq 'Consumer') {
        foreach ($directoryName in @('instructions', 'prompts', 'skills')) {
            Add-ProjectionTree `
                -SourceDirectory (Join-Path $resolvedRoot $directoryName) `
                -DestinationPrefix ".github/$directoryName" `
                -GuidanceUnitPrefix $directoryName
        }
        Add-ProjectionTree `
            -SourceDirectory (Join-Path $resolvedRoot 'skills') `
            -DestinationPrefix '.agents/skills' `
            -GuidanceUnitPrefix 'skills'

        $agentsRoot = Join-Path $resolvedRoot 'agents'
        if (Test-Path -LiteralPath $agentsRoot -PathType Container) {
            foreach ($agent in Get-ChildItem -LiteralPath $agentsRoot -File -Filter '*.agent.md' -Force) {
                if (($agent.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Projection source contains a symbolic link or reparse point: $($agent.FullName)"
                }
                $entries.Add([pscustomobject]@{
                    SourcePath = $agent.FullName
                    DestinationPath = ".github/agents/$($agent.Name)"
                    GuidanceUnit = "agents/$($agent.Name)"
                    Kind = 'agent'
                })
            }
            Add-ProjectionTree `
                -SourceDirectory (Join-Path $agentsRoot 'references') `
                -DestinationPrefix '.github/agents/references' `
                -GuidanceUnitPrefix 'agents/references'
        }
    }
    else {
        $skillsRoot = Join-Path $resolvedRoot 'skills'
        if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
            $skillsRootItem = Get-Item -LiteralPath $skillsRoot -Force
            if (($skillsRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Projection source contains a symbolic link or reparse point: $($skillsRootItem.FullName)"
            }
            foreach ($skill in Get-ChildItem -LiteralPath $skillsRoot -Directory -Force) {
                if (($skill.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Projection source contains a symbolic link or reparse point: $($skill.FullName)"
                }
                if (Test-BaseCoatDogfoodSkill -Directory $skill) {
                    Add-ProjectionTree `
                        -SourceDirectory $skill.FullName `
                        -DestinationPrefix ".github/skills/$($skill.Name)" `
                        -GuidanceUnitPrefix "skills/$($skill.Name)"
                    Add-ProjectionTree `
                        -SourceDirectory $skill.FullName `
                        -DestinationPrefix ".agents/skills/$($skill.Name)" `
                        -GuidanceUnitPrefix "skills/$($skill.Name)"
                }
            }
        }

        $agentsRoot = Join-Path $resolvedRoot 'agents'
        if (Test-Path -LiteralPath $agentsRoot -PathType Container) {
            $agentsRootItem = Get-Item -LiteralPath $agentsRoot -Force
            if (($agentsRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Projection source contains a symbolic link or reparse point: $($agentsRootItem.FullName)"
            }
            $referenceComparer = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
                [System.StringComparer]::OrdinalIgnoreCase
            }
            else {
                [System.StringComparer]::Ordinal
            }
            $referencePaths = [System.Collections.Generic.HashSet[string]]::new($referenceComparer)
            foreach ($agent in Get-ChildItem -LiteralPath $agentsRoot -File -Filter '*.agent.md' -Force) {
                if ($agent.Name -in $script:BaseCoatDogfoodAgents) {
                    if (($agent.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                        throw "Projection source contains a symbolic link or reparse point: $($agent.FullName)"
                    }
                    $agentContent = Get-Content -LiteralPath $agent.FullName -Raw
                    foreach ($referenceMatch in [regex]::Matches($agentContent, '(?i)(?:\.{1,2}/)?references/([A-Za-z0-9._/-]+\.md)')) {
                        $referencePath = $referenceMatch.Groups[1].Value
                        if (@($referencePath -split '/' | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
                            throw "Selected agent has an unsafe reference path: '$($agent.Name)' -> '$referencePath'"
                        }
                        $null = $referencePaths.Add($referencePath)
                    }
                    $entries.Add([pscustomobject]@{
                        SourcePath = $agent.FullName
                        DestinationPath = ".github/agents/$($agent.Name)"
                        GuidanceUnit = "agents/$($agent.Name)"
                        Kind = 'agent'
                    })
                }
            }
            $referencesRoot = Join-Path $agentsRoot 'references'
            if (Test-Path -LiteralPath $referencesRoot -PathType Container) {
                $referenceRootItem = Get-Item -LiteralPath $referencesRoot -Force
                if (($referenceRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Projection source contains a symbolic link or reparse point: $($referenceRootItem.FullName)"
                }
            }
            foreach ($referencePath in $referencePaths) {
                $sourcePath = Join-Path $referencesRoot ($referencePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                    throw "Selected agent reference does not exist: '$referencePath'"
                }
                $currentPath = $referencesRoot
                foreach ($segment in ($referencePath -split '/')) {
                    $currentPath = Join-Path $currentPath $segment
                    if (Test-Path -LiteralPath $currentPath) {
                        $pathItem = Get-Item -LiteralPath $currentPath -Force
                        if (($pathItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                            throw "Projection source contains a symbolic link or reparse point: $($pathItem.FullName)"
                        }
                    }
                }
                $reference = Get-Item -LiteralPath $sourcePath -Force
                if (($reference.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Projection source contains a symbolic link or reparse point: $($reference.FullName)"
                }
                $entries.Add([pscustomobject]@{
                    SourcePath = $reference.FullName
                    DestinationPath = ".github/agents/references/$referencePath"
                    GuidanceUnit = "agents/references/$referencePath"
                    Kind = 'file'
                })
            }
        }

        $promptsRoot = Join-Path $resolvedRoot 'prompts'
        if (Test-Path -LiteralPath $promptsRoot -PathType Container) {
            $promptsRootItem = Get-Item -LiteralPath $promptsRoot -Force
            if (($promptsRootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Projection source contains a symbolic link or reparse point: $($promptsRootItem.FullName)"
            }
        }
        foreach ($promptName in $script:BaseCoatDogfoodPrompts) {
            $promptPath = Join-Path $promptsRoot $promptName
            if (Test-Path -LiteralPath $promptPath -PathType Leaf) {
                $prompt = Get-Item -LiteralPath $promptPath -Force
                if (($prompt.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    throw "Projection source contains a symbolic link or reparse point: $($prompt.FullName)"
                }
                $entries.Add([pscustomobject]@{
                    SourcePath = $prompt.FullName
                    DestinationPath = ".github/prompts/$($prompt.Name)"
                    GuidanceUnit = "prompts/$($prompt.Name)"
                    Kind = 'file'
                })
            }
        }
    }

    return @($entries | Sort-Object DestinationPath)
}
