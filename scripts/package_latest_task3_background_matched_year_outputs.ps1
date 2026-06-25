param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$PackageDir = "D:\Github_repos\Gayini\Output\packages"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "Gayini_task3_background_matched_year_outputs_$timestamp"
$stagingDir = Join-Path $PackageDir $packageName
$zipPath = Join-Path $PackageDir "$packageName.zip"
$manifestPath = Join-Path $PackageDir "$packageName.manifest.csv"

$relativeFiles = @(
  "scripts\10f_prepare_background_flood_pattern_matched_years.R",
  "scripts\package_latest_task3_background_matched_year_outputs.ps1",
  "Output\csv\background_inundation_frequency_by_plot.csv",
  "Output\csv\inundation_frequency_by_vegetation_group.csv",
  "Output\csv\matched_year_candidate_ranking.csv",
  "Output\csv\matched_year_gauge_context.csv",
  "Output\diagnostics\10f_background_matched_years\task3_input_report.csv",
  "Output\diagnostics\10f_background_matched_years\background_period_selection.csv",
  "Output\diagnostics\10f_background_matched_years\annual_inundation_year_summary.csv",
  "Output\diagnostics\10f_background_matched_years\task3_checks.csv",
  "Output\diagnostics\10f_background_matched_years\task3_figure_manifest.csv",
  "Output\figures\review\background_flood_pattern_pre2015.png",
  "Output\figures\review\matched_year_inundation_comparison.png",
  "Output\figures\review\inundation_frequency_by_vegetation_group.png",
  "Output\reports\task_3_background_flood_pattern_handoff.md"
)

New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null
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

if (Test-Path -LiteralPath $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

$stagedItems = Get-ChildItem -LiteralPath $stagingDir -Force
if ($stagedItems.Count -eq 0) {
  throw "No staged files were found for packaging: $stagingDir"
}

Compress-Archive -LiteralPath $stagedItems.FullName -DestinationPath $zipPath -Force

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
  throw "Zip file was not created: $zipPath"
}

Write-Host "Package written: $zipPath"
Write-Host "Manifest written: $manifestPath"
Write-Host "Packaged files:" ($manifest | Where-Object { $_.packaged }).Count
Write-Host "Missing files:" ($manifest | Where-Object { -not $_.packaged }).Count
