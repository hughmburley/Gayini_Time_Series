param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$PackageDir = "D:\Github_repos\Gayini\Output\packages"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "Gayini_task2_gauge_integration_outputs_$timestamp"
$stagingDir = Join-Path $PackageDir $packageName
$zipPath = Join-Path $PackageDir "$packageName.zip"
$manifestPath = Join-Path $PackageDir "$packageName.manifest.csv"

$relativeFiles = @(
  "scripts\10e_integrate_gauge_context_review_figures.R",
  "scripts\package_latest_task2_gauge_integration_outputs.ps1",
  "Output\csv\gauge_context_for_gayini.csv",
  "Output\csv\gauge_data_completeness_for_gayini.csv",
  "Output\csv\plot_rs_gauge_analysis_base.csv",
  "Output\diagnostics\10e_gauge_integration\gauge_input_import_report.csv",
  "Output\diagnostics\10e_gauge_integration\gauge_integration_checks.csv",
  "Output\diagnostics\10e_gauge_integration\dashboard_gauge_integration_plot_data.csv",
  "Output\diagnostics\10e_gauge_integration\gauge_integration_figure_manifest.csv",
  "Output\figures\review\gc_total_veg_with_gauge_context.png",
  "Output\figures\review\inundation_with_gauge_context.png",
  "Output\figures\review\dashboard_gauge_integration_prototype.png",
  "Output\figures\review\gauge_flow_by_station_overview.png",
  "Output\figures\review\gauge_data_completeness_overview.png",
  "Output\figures\review\selected_plot_total_veg_inundation_gauge_examples.png",
  "Output\reports\task_2_gauge_integration_handoff.md"
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
