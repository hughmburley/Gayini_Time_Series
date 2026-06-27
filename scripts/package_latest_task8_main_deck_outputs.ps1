param(
  [string]$Root = "D:\Github_repos\Gayini"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageRoot = Join-Path $Root "Output\packages"
$packageName = "Gayini_task8_main_deck_figure_refresh_outputs_$timestamp"
$stagingDir = Join-Path $packageRoot $packageName
$zipPath = Join-Path $packageRoot "$packageName.zip"
$manifestPath = Join-Path $packageRoot "$packageName`_manifest.csv"

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$relativeFiles = @(
  "scripts\18_refresh_main_deck_figures.R",
  "scripts\package_latest_task8_main_deck_outputs.ps1",
  "Output\figures\review\gauge_context_map_main_deck.png",
  "Output\figures\review\gauge_completeness_by_gauge_main_deck.png",
  "Output\figures\review\kingsford_ratio_context_main_deck.png",
  "Output\figures\review\inundation_pre_post_frequency_main_deck.png",
  "Output\figures\review\inundation_post_minus_pre_change_main_deck.png",
  "Output\figures\review\inundation_post_minus_pre_change_with_paddocks.png",
  "Output\figures\review\plot_level_inundation_change_with_paddocks.png",
  "Output\figures\review\mer_vs_annual_inundation_change_comparison.png",
  "Output\figures\review\mer_change_result_main_deck.png",
  "Output\figures\review\matched_year_inundation_comparison_main_deck.png",
  "Output\figures\review\matched_year_paired_summary_by_veg_group.png",
  "Output\figures\review\inundation_with_gauge_context_main_deck.png",
  "Output\figures\review\gc_total_veg_with_gauge_context_main_deck.png",
  "Output\figures\review\inundation_change_vs_total_veg_by_wetness_group.png",
  "Output\figures\review\inundation_change_vs_total_veg_by_vegetation_group.png",
  "Output\figures\review\inundation_change_vs_bare_ground_appendix_only.png",
  "Output\figures\review\lag_timing_zoom_2013_current_main_deck.png",
  "Output\figures\review\candidate_dashboard_set_for_review_updated.png",
  "Output\csv\candidate_dashboard_set_for_review_updated.csv",
  "Output\reports\task_8_main_deck_figure_refresh_handoff.md",
  "Output\reports\Gayini_ppt_asset_register.csv",
  "Output\reports\Gayini_ppt_missing_assets.csv",
  "Output\diagnostics\18_main_deck_figure_refresh\task8_main_deck_figure_refresh_checks.csv",
  "Output\diagnostics\18_main_deck_figure_refresh\task8_asset_pack_copy_log.csv"
)

$dashboardFiles = Get-ChildItem -Path (Join-Path $Root "Output\figures\review\redesigned_dashboards") -Filter "dashboard_redesigned_*.png" -File |
  ForEach-Object { $_.FullName.Substring($Root.Length + 1) }

$assetPackFiles = @()
$copyLogPath = Join-Path $Root "Output\diagnostics\18_main_deck_figure_refresh\task8_asset_pack_copy_log.csv"
if (Test-Path $copyLogPath) {
  $assetPackFiles = Import-Csv $copyLogPath |
    Where-Object { $_.destination_exists -eq "True" -or $_.destination_exists -eq "TRUE" } |
    ForEach-Object {
      $full = $_.destination_path -replace "/", "\"
      if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $full.Substring($Root.Length + 1)
      }
    }
}

$allRelativeFiles = @($relativeFiles + $dashboardFiles + $assetPackFiles) |
  Where-Object { $_ -and $_.Trim().Length -gt 0 } |
  Sort-Object -Unique

$manifest = foreach ($relativePath in $allRelativeFiles) {
  $sourcePath = Join-Path $Root $relativePath
  $exists = Test-Path $sourcePath
  $destinationPath = Join-Path $stagingDir $relativePath

  if ($exists) {
    New-Item -ItemType Directory -Force -Path (Split-Path $destinationPath -Parent) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $item = Get-Item -LiteralPath $sourcePath
  } else {
    $item = $null
  }

  [pscustomobject]@{
    relative_path = $relativePath
    source_path = $sourcePath
    packaged_path = $destinationPath
    exists = $exists
    packaged = (Test-Path $destinationPath)
    size_bytes = if ($item) { $item.Length } else { $null }
    last_write_time = if ($item) { $item.LastWriteTime.ToString("s") } else { $null }
  }
}

$manifest | Export-Csv -NoTypeInformation -Path $manifestPath
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingDir (Split-Path $manifestPath -Leaf)) -Force

Compress-Archive -Path (Join-Path $stagingDir "*") -DestinationPath $zipPath -Force

Write-Host "Task 8 package created:"
Write-Host $zipPath
Write-Host "Manifest:"
Write-Host $manifestPath
Write-Host "Packaged files:" ($manifest | Where-Object { $_.packaged }).Count "of" $manifest.Count
