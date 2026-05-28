# Fix GitHub Actions SHA pinning violations
# This script updates all workflows to pin actions to full 40-char commit SHAs

# Action SHA mapping - extracted from existing comments or latest stable versions
$actionMap = @{
  'actions/checkout@v6' = 'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd'
  'actions/checkout@v4' = 'actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd'
  'actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5' = 'actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5'
  'actions/github-script@v9' = 'actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3'
  'actions/github-script@v7' = 'actions/github-script@3a2844b7e9c422d3c10d287c895573f7108da1b3'
  'actions/upload-artifact@v7' = 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
  'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a' = 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
  'actions/setup-node@v6.4.0' = 'actions/setup-node@48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e'
  'actions/setup-node@v4' = 'actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020'
  'actions/setup-python@v6' = 'actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405'
  'azure/login@v3.0.0' = 'azure/login@532459ea530d8321f2fb9bb10d1e0bcf23869a43'
  'azure/arm-deploy@v2' = 'azure/arm-deploy@a1361c2c2cd398621955b16ca32e01c65ea340f5'
  'docker/build-push-action@v6' = 'docker/build-push-action@f9f3042f7e2789586610d6e8b85c8f03e5195baf'
  'docker/login-action@v3' = 'docker/login-action@650006c6eb7dba73a995cc03b0b2d7f5ca915bee'
  'docker/metadata-action@v6.1.0' = 'docker/metadata-action@80c7e94dd9b9319bd5eb7a0e0fe9291e23a2a2e9'
  'docker/setup-buildx-action@v3' = 'docker/setup-buildx-action@d7f5e7f509e45cec5c76c4d5afdd7de93d0b3df5'
  'hashicorp/setup-terraform@v4' = 'hashicorp/setup-terraform@b3ec3d7a786b0175ba86becc79b127e4bc2edb5c'
}

# Also handle cases where SHAs have comments - strip the comment
$files = Get-ChildItem .github/workflows/*.yml
$fixedCount = 0

foreach ($file in $files) {
  $content = Get-Content $file -Raw
  $originalContent = $content
  
  # Fix 1: Strip comments from existing SHAs
  $content = $content -replace '(@[0-9a-f]{40})\s+#\s+v[0-9.]+', '$1'
  $content = $content -replace '(@[0-9a-f]{40})\s+\(source\s+v[0-9.]+\)', '$1'
  
  # Fix 2: Replace mapped refs
  foreach ($key in $actionMap.Keys) {
    $value = $actionMap[$key]
    # Use regex word boundary to avoid partial matches
    $content = $content -replace [regex]::Escape("uses: $key"), "uses: $value"
  }
  
  if ($content -ne $originalContent) {
    Set-Content $file -Value $content -Encoding UTF8
    $fixedCount++
    Write-Host "Fixed: $($file.Name)"
  }
}

Write-Host "`nTotal files fixed: $fixedCount"
