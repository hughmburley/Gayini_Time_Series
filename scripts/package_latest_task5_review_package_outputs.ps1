param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$PackageDir = "D:\Github_repos\Gayini\Output\packages"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "Gayini_task5_review_package_outputs_$timestamp"
$stagingDir = Join-Path $PackageDir $packageName
$zipPath = Join-Path $PackageDir "$packageName.zip"
$manifestPath = Join-Path $PackageDir "$packageName.manifest.csv"

$relativeFiles = @(
  "scripts\10h_prepare_review_package_spine.R",
  "scripts\package_latest_task5_review_package_outputs.ps1",
  "docs\codex_context.md",
  "docs\current_run_order.md",
  "Output\reports\task_1_veg_groups_treed_grazing_handoff.md",
  "Output\reports\task_2_gauge_integration_handoff.md",
  "Output\reports\task_3_background_flood_pattern_handoff.md",
  "Output\reports\task_4_mer_metric_consolidation_handoff.md",
  "Output\reports\Gayini_review_variable_LUT.csv",
  "Output\reports\Gayini_review_key_figure_manifest.csv",
  "Output\reports\Gayini_analysis_spine.csv",
  "Output\reports\Gayini_questions_for_Adrian.csv",
  "Output\reports\Gayini_story_structure.md",
  "Output\reports\Gayini_review_package_handoff.md",
  "Output\diagnostics\10h_review_package_spine\task5_input_inventory.csv",
  "Output\diagnostics\10h_review_package_spine\task5_review_package_checks.csv"
)

New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

if (Test-Path -LiteralPath $stagingDir) {
  throw "Package staging directory already exists: $stagingDir"
}

if (Test-Path -LiteralPath $zipPath) {
  throw "Package zip already exists: $zipPath"
}

New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

$manifest = foreach ($relativeFile in $relativeFiles) {
  $sourcePath = Join-Path $RootDir $relativeFile
  $exists = Test-Path -LiteralPath $sourcePath -PathType Leaf

  if ($exists) {
    $destinationPath = Join-Path $stagingDir $relativeFile
    $destinationDir = Split-Path -Parent $destinationPath
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $item = Get-Item -LiteralPath $sourcePath
    $hash = Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256
  } else {
    $item = $null
    $hash = $null
  }

  [pscustomobject]@{
    relative_path = $relativeFile
    source_path = $sourcePath
    packaged = $exists
    size_bytes = if ($item) { $item.Length } else { $null }
    last_write_time = if ($item) { $item.LastWriteTime.ToString("s") } else { $null }
    sha256 = if ($hash) { $hash.Hash } else { $null }
  }
}

$manifest | Export-Csv -LiteralPath $manifestPath -NoTypeInformation
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingDir (Split-Path -Leaf $manifestPath)) -Force

$stagedItems = Get-ChildItem -LiteralPath $stagingDir -Force
if ($stagedItems.Count -eq 0) {
  throw "No staged files were found for packaging: $stagingDir"
}

Compress-Archive -LiteralPath $stagedItems.FullName -DestinationPath $zipPath

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
  throw "Zip file was not created: $zipPath"
}

Write-Host "Package written: $zipPath"
Write-Host "Manifest written: $manifestPath"
Write-Host "Packaged files:" ($manifest | Where-Object { $_.packaged }).Count
Write-Host "Missing files:" ($manifest | Where-Object { -not $_.packaged }).Count
