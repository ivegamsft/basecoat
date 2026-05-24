param([switch]$Strict)

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel
$gitignore = Get-Content (Join-Path $repoRoot '.gitignore') -Raw

$patterns = @(
    @{ Pattern = 'site/';          Rationale = 'MkDocs generated site output' },
    @{ Pattern = 'dist/';          Rationale = 'Build output' },
    @{ Pattern = 'node_modules/';  Rationale = 'npm dependencies' },
    @{ Pattern = '*.db';           Rationale = 'SQLite databases' },
    @{ Pattern = 'test-results/';  Rationale = 'Generated test output' },
    @{ Pattern = '.terraform/';    Rationale = 'Terraform working dir' },
    @{ Pattern = '__pycache__/';   Rationale = 'Python bytecode cache' },
    @{ Pattern = '*.pyc';          Rationale = 'Python compiled files' },
    @{ Pattern = '.pytest_cache/'; Rationale = 'pytest cache' },
    @{ Pattern = 'coverage/';      Rationale = 'Code coverage output' },
    @{ Pattern = '.nyc_output/';   Rationale = 'NYC/Istanbul coverage' },
    @{ Pattern = '*.log';          Rationale = 'Log files' }
)

$warnings = @()
foreach ($entry in $patterns) {
    $p = $entry.Pattern
    if ($gitignore -notmatch [regex]::Escape($p)) {
        $warnings += "  ⚠️  '$p' — $($entry.Rationale) — not found in .gitignore"
    }
}

if ($warnings.Count -gt 0) {
    Write-Host 'Gitignore coverage warnings:' -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    if ($Strict) { exit 1 }
} else {
    Write-Host '✅ .gitignore covers all standard generated artifact patterns' -ForegroundColor Green
}
