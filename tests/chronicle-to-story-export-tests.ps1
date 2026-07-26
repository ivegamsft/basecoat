$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running chronicle-to-story export tests...'

$scriptPath = Join-Path $repoRoot 'scripts\chronicle-to-story-export.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\\chronicle-story-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $inputPath = Join-Path $tempDir 'input.json'
    $storyPath = Join-Path $tempDir 'repo-story.md'
    $outputDir = Join-Path $tempDir 'output'

    @'
{
  "cycle_id": "wave-42",
  "story_title": "Repo Story (Test)",
  "source_sessions": [
    "session://abc",
    "session://def"
  ],
  "references": [
    "https://github.com/ivegamsft/basecoat/issues/2621"
  ],
  "timeline": [
    {
      "timestamp": "2026-07-22T00:10:00Z",
      "event": "Planned wave",
      "reference": "#2621"
    },
    {
      "timestamp": "2026-07-22T00:20:00Z",
      "event": "Executed changes",
      "reference": "PR pending"
    }
  ],
  "learnings": [
    {
      "title": "Use bounded loop state",
      "detail": "Cycle state and stop conditions reduced repeated orchestration prompts.",
      "action": "Document bounded loop pattern in control-plane runbooks.",
      "issue_title": "docs: add bounded loop pattern guidance"
    },
    {
      "title": "Use bounded loop state",
      "detail": "Duplicate learning should dedupe by normalized key.",
      "action": "No-op duplicate."
    },
    {
      "title": "Capture first-fail evidence early",
      "detail": "First failing job/step cut RCA turnaround time.",
      "action": "Standardize first-fail evidence capture."
    }
  ]
}
'@ | Set-Content -Path $inputPath -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -InputPath $inputPath `
        -StoryPath $storyPath `
        -Mode append `
        -OutputDir $outputDir `
        -IncludeMemorySuggestions

    if ($LASTEXITCODE -ne 0) {
        throw 'chronicle-to-story export script failed on append mode'
    }

    $packetPath = Join-Path $outputDir 'story-update-packet.md'
    $issuesPath = Join-Path $outputDir 'issue-ready-learnings.md'
    $summaryPath = Join-Path $outputDir 'summary.json'
    $memoryPath = Join-Path $outputDir 'memory-promotion-suggestions.json'

    foreach ($required in @($storyPath, $packetPath, $issuesPath, $summaryPath, $memoryPath)) {
        if (-not (Test-Path $required)) {
            throw "Missing output artifact: $required"
        }
    }

    $story = Get-Content -Path $storyPath -Raw
    if ($story -notmatch '<!-- CHRONICLE:START wave-42 -->') {
        throw 'Story file missing chronicle start marker'
    }
    if ($story -notmatch '\[learning:use-bounded-loop-state\]') {
        throw 'Expected normalized learning key not found in story'
    }
    if ($story -notmatch '\[learning:capture-first-fail-evidence-early\]') {
        throw 'Expected second learning key not found in story'
    }

    $learningMatches = [regex]::Matches($story, '\[learning:')
    if ($learningMatches.Count -ne 2) {
        throw "Expected deduped learning count of 2, got $($learningMatches.Count)"
    }

    $issuesMd = Get-Content -Path $issuesPath -Raw
    if ($issuesMd -notmatch 'docs: add bounded loop pattern guidance') {
        throw 'Issue-ready output missing provided issue title'
    }

    $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json
    if ($summary.learning_count -ne 2) {
        throw "Expected summary learning_count=2, got $($summary.learning_count)"
    }
    if ($summary.issue_ready_count -lt 1) {
        throw 'Expected at least one issue-ready item'
    }

    $memory = @(Get-Content -Path $memoryPath -Raw | ConvertFrom-Json)
    if ($memory.Count -ne 2) {
        throw "Expected 2 memory suggestions after dedupe, got $($memory.Count)"
    }

    # Update mode should replace the cycle section, not append a duplicate section.
    @'
{
  "cycle_id": "wave-42",
  "story_title": "Repo Story (Test)",
  "source_sessions": ["session://xyz"],
  "timeline": [
    {
      "timestamp": "2026-07-22T01:00:00Z",
      "event": "Updated wave section",
      "reference": "refresh"
    }
  ],
  "learnings": [
    {
      "title": "Capture first-fail evidence early",
      "detail": "Updated detail for replacement check.",
      "action": "Keep first-fail capture standardized."
    }
  ]
}
'@ | Set-Content -Path $inputPath -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -InputPath $inputPath `
        -StoryPath $storyPath `
        -Mode update `
        -OutputDir $outputDir

    if ($LASTEXITCODE -ne 0) {
        throw 'chronicle-to-story export script failed on update mode'
    }

    $storyUpdated = Get-Content -Path $storyPath -Raw
    $sectionCount = [regex]::Matches($storyUpdated, '<!-- CHRONICLE:START wave-42 -->').Count
    if ($sectionCount -ne 1) {
        throw "Expected one section after update mode, got $sectionCount"
    }
    if ($storyUpdated -notmatch 'Updated detail for replacement check') {
        throw 'Update mode did not replace section content'
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'chronicle-to-story export tests passed' -ForegroundColor Green
exit 0
