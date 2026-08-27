$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts' 'generate-registry.ps1'

if (-not (Test-Path $scriptPath)) {
    throw "Script not found: $scriptPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('basecoat-registry-test-' + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $agentsDir = Join-Path $tempRoot 'agents'
    $outputDir = Join-Path $tempRoot 'out'
    New-Item -ItemType Directory -Path $agentsDir | Out-Null
    New-Item -ItemType Directory -Path $outputDir | Out-Null

    @'
---
name: model-test-agent
description: Ensures model frontmatter is propagated.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-model-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registryPath = Join-Path $outputDir 'basecoat-registry.json'
    if (-not (Test-Path $registryPath)) {
        throw 'Registry output was not generated'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $entry = $registry.agents.'model-test-agent'
    if (-not $entry) {
        throw 'Expected model-test-agent registry entry not found'
    }
    if ($entry.model -ne 'gpt-5.3-codex') {
        throw "Expected model gpt-5.3-codex, got $($entry.model)"
    }
    if ($entry.description -ne 'Ensures model frontmatter is propagated.') {
        throw "Expected description to be propagated from frontmatter, got '$($entry.description)'"
    }

    # Regression guard for #2891: description/name extraction must not depend on
    # frontmatter key ordering. `name:` is typically the first key, so a
    # non-multiline `^description:` regex silently falls back to
    # "No description" for every agent whose description isn't the first line.
    @'
---
description: "Vocabulary-bearing description. USE FOR: testing key-order independence."
name: order-test-agent
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-order-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $orderEntry = $registry.agents.'order-test-agent'
    if (-not $orderEntry) {
        throw 'Expected order-test-agent registry entry not found'
    }
    if ($orderEntry.name -ne 'order-test-agent') {
        throw "Expected name 'order-test-agent' when description precedes name, got '$($orderEntry.name)'"
    }
    if ($orderEntry.description -notmatch '^Vocabulary-bearing description\. USE FOR: testing key-order independence\.') {
        throw "Expected description to be extracted even when it is not the first frontmatter key, got '$($orderEntry.description)'"
    }

    # Regression guard: YAML block-scalar (`>` folded / `|` literal) descriptions
    # must be folded into their continuation lines, not left as the bare
    # block-scalar indicator character (see basecoat-80-data-data-integrity.agent.md).
    @'
---
name: block-scalar-test-agent
description: >
  Folded block scalar description spanning
  multiple continuation lines.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-block-scalar-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $blockScalarEntry = $registry.agents.'block-scalar-test-agent'
    if (-not $blockScalarEntry) {
        throw 'Expected block-scalar-test-agent registry entry not found'
    }
    $expectedFolded = "Folded block scalar description spanning multiple continuation lines.`n"
    if ($blockScalarEntry.description -ne $expectedFolded) {
        throw "Expected folded block-scalar description '$expectedFolded', got '$($blockScalarEntry.description)'"
    }

    # Regression guard: a blank line inside a folded (`>`) block scalar is a
    # valid paragraph break, not a terminator -- content after the blank line
    # must still be captured (previously the scan stopped at the first blank
    # line and silently dropped everything after it).
    @'
---
name: multi-paragraph-test-agent
description: >
  First paragraph spanning
  two lines.

  Second paragraph after a blank line,
  including a DO NOT USE FOR clause.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-multi-paragraph-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $multiParaEntry = $registry.agents.'multi-paragraph-test-agent'
    if (-not $multiParaEntry) {
        throw 'Expected multi-paragraph-test-agent registry entry not found'
    }
    $expectedMultiPara = "First paragraph spanning two lines.`nSecond paragraph after a blank line, including a DO NOT USE FOR clause.`n"
    if ($multiParaEntry.description -ne $expectedMultiPara) {
        throw "Expected multi-paragraph folded description to survive the blank line, got '$($multiParaEntry.description)'"
    }

    # Regression guard: per YAML folding rules, N consecutive blank lines
    # between content lines must fold to exactly N newline characters (not
    # a fixed paragraph separator), so re-running the generator reproduces
    # the exact blank-line count of the source frontmatter.
    @'
---
name: double-blank-line-test-agent
description: >
  Paragraph one.


  Paragraph two after two blank lines.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-double-blank-line-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $doubleBlankEntry = $registry.agents.'double-blank-line-test-agent'
    if (-not $doubleBlankEntry) {
        throw 'Expected double-blank-line-test-agent registry entry not found'
    }
    $expectedDoubleBlank = "Paragraph one.`n`nParagraph two after two blank lines.`n"
    if ($doubleBlankEntry.description -ne $expectedDoubleBlank) {
        throw "Expected two consecutive blank lines to fold to exactly two newlines, got '$($doubleBlankEntry.description)'"
    }

    # Regression guard: the registry must not truncate long descriptions.
    # Truncating "USE FOR"/"DO NOT USE FOR" routing guidance (previously
    # capped at 120 chars) can silently drop stop conditions and cause the
    # exact behavioral drift the vocabulary-surfacing feature is meant to
    # prevent (see PR #2924 review).
    $longDescription = 'USE FOR: ' + ('x' * 200) + '. DO NOT USE FOR: ' + ('y' * 50) + '.'
    @"
---
name: long-description-test-agent
description: "$longDescription"
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
"@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-long-description-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $longDescEntry = $registry.agents.'long-description-test-agent'
    if (-not $longDescEntry) {
        throw 'Expected long-description-test-agent registry entry not found'
    }
    if ($longDescEntry.description -ne $longDescription) {
        throw "Expected full untruncated description to be preserved (length $($longDescription.Length)), got length $($longDescEntry.description.Length)"
    }

    # Regression guard: literal (`|`) block scalars must preserve relative
    # indentation beyond the block's base indentation (e.g. a nested list),
    # not have every line fully Trim()'d flush-left.
    @'
---
name: literal-indent-test-agent
description: |
  Top level line.
    Nested indented line.
  Back to top level.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-literal-indent-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $literalIndentEntry = $registry.agents.'literal-indent-test-agent'
    if (-not $literalIndentEntry) {
        throw 'Expected literal-indent-test-agent registry entry not found'
    }
    $expectedLiteralIndent = "Top level line.`n  Nested indented line.`nBack to top level.`n"
    if ($literalIndentEntry.description -ne $expectedLiteralIndent) {
        throw "Expected literal block scalar to preserve relative indentation, got '$($literalIndentEntry.description)'"
    }

    # Regression guard: the strip (`|-`) and keep (`|+`) chomping indicators
    # must behave differently from the default clip -- strip must not
    # produce a trailing newline, keep must preserve trailing blank lines.
    @'
---
name: chomp-strip-test-agent
description: |-
  Stripped literal description.
model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-chomp-strip-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $chompStripEntry = $registry.agents.'chomp-strip-test-agent'
    if (-not $chompStripEntry) {
        throw 'Expected chomp-strip-test-agent registry entry not found'
    }
    if ($chompStripEntry.description -ne 'Stripped literal description.') {
        throw "Expected strip ('|-') chomping to omit the trailing newline, got '$($chompStripEntry.description)'"
    }

    # Regression guard: keep (`|+`) chomping must preserve all trailing
    # blank lines (unlike default clip, which keeps exactly one trailing
    # newline, and strip, which keeps none).
    @'
---
name: chomp-keep-test-agent
description: |+
  Kept literal description.


model: gpt-5.3-codex
maturity: production
category: Quality
metadata:
  tags: [test]
---
'@ | Set-Content -Path (Join-Path $agentsDir 'basecoat-99-test-chomp-keep-test-agent.agent.md') -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -AgentsPath $agentsDir `
        -OutputPath (Join-Path $outputDir 'basecoat-registry.json')
    if ($LASTEXITCODE -ne 0) {
        throw 'generate-registry.ps1 exited with non-zero status'
    }

    $registry = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $chompKeepEntry = $registry.agents.'chomp-keep-test-agent'
    if (-not $chompKeepEntry) {
        throw 'Expected chomp-keep-test-agent registry entry not found'
    }
    $expectedChompKeep = "Kept literal description.`n`n`n"
    if ($chompKeepEntry.description -ne $expectedChompKeep) {
        throw "Expected keep ('|+') chomping to preserve all trailing blank lines, got '$($chompKeepEntry.description -replace "``n", '\n')'"
    }

    Write-Host 'Generate registry tests passed'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
