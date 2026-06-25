param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$PackageDir = "D:\Github_repos\Gayini\Output\packages"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "Gayini_task4_mer_metric_consolidation_outputs_$timestamp"
$stagingDir = Join-Path $PackageDir $packageName
$zipPath = Join-Path $PackageDir "$packageName.zip"
$manifestPath = Join-Path $PackageDir "$packageName.manifest.csv"

$relativeFiles = @(
  "scripts\10g_consolidate_mer_metric_review.R",
  "scripts\package_latest_task4_mer_metric_consolidation_outputs.ps1",
  "Output\csv\mer_metric_comparison_table.csv",
  "Output\csv\mer_metric_keep_defer_decision_table.csv",
  "Output\diagnostics\10g_mer_metric_consolidation\task4_input_report.csv",
  "Output\diagnostics\10g_mer_metric_consolidation\task4_scripts_reviewed.csv",
  "Output\diagnostics\10g_mer_metric_consolidation\task4_mer_summary_stats.csv",
  "Output\diagnostics\10g_mer_metric_consolidation\task4_figure_manifest.csv",
  "Output\diagnostics\10g_mer_metric_consolidation\task4_checks.csv",
  "Output\figures\review\mer_metric_summary_review.png",
  "Output\reports\task_4_mer_metric_consolidation_handoff.md"
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
