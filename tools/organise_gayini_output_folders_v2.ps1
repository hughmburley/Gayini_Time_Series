<#
.SYNOPSIS
  Organise selected Gayini Output folders into clearer maps / plots / diagnostics / csv groupings.

.DESCRIPTION
  This script reorganises existing files under Output/csv, Output/diagnostics and Output/figures
  using conservative move rules discussed during the Gayini repo cleanup.

  By default the script runs in DRY-RUN mode and does not move files.
  Add -Execute to perform the moves.

  No files are deleted.
  Existing folder structure is preserved where needed.
  Every proposed or executed move is logged to a CSV manifest.

.EXAMPLE
  # Dry run only
  powershell -ExecutionPolicy Bypass -File tools/organise_output_folders.ps1

.EXAMPLE
  # Execute moves
  powershell -ExecutionPolicy Bypass -File tools/organise_output_folders.ps1 -Execute

.NOTES
  Intended repo root:
    D:\Github_repos\Gayini

  Recommended location in repo:
    tools/organise_output_folders.ps1
#>

param(
  [string]$RepoRoot = "D:\Github_repos\Gayini",
  [switch]$Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

function Join-RepoPath {
  param([string]$RelativePath)
  return Join-Path $RepoRoot $RelativePath
}

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    if ($Execute) {
      New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
  }
}

function Get-UniqueDestinationPath {
  param([string]$DestinationPath)

  if (-not (Test-Path -LiteralPath $DestinationPath)) {
    return $DestinationPath
  }

  $dir = Split-Path -Parent $DestinationPath
  $base = [System.IO.Path]::GetFileNameWithoutExtension($DestinationPath)
  $ext = [System.IO.Path]::GetExtension($DestinationPath)

  $i = 1
  do {
    $candidate = Join-Path $dir ("{0}__duplicate_{1}{2}" -f $base, $i, $ext)
    $i++
  } while (Test-Path -LiteralPath $candidate)

  return $candidate
}

$script:MoveRows = New-Object System.Collections.Generic.List[object]

function Add-Move {
  param(
    [string]$SourceRelative,
    [string]$DestinationRelative,
    [string]$Category,
    [string]$Reason
  )

  $src = Join-RepoPath $SourceRelative
  $dst = Join-RepoPath $DestinationRelative

  $exists = Test-Path -LiteralPath $src
  $status = "source_missing"
  $finalDst = $dst
  $sizeBytes = $null

  if ($exists) {
    $item = Get-Item -LiteralPath $src
    $sizeBytes = if ($item.PSIsContainer) { $null } else { $item.Length }
    $dstDir = Split-Path -Parent $dst
    $finalDst = Get-UniqueDestinationPath $dst

    if ($Execute) {
      Ensure-Directory -Path $dstDir
      Move-Item -LiteralPath $src -Destination $finalDst
      $status = "moved"
    } else {
      $status = "would_move"
    }
  }

  $script:MoveRows.Add([pscustomobject]@{
    source_relative = $SourceRelative
    destination_relative = $DestinationRelative
    final_destination = if ($finalDst) { $finalDst.Replace($RepoRoot + [System.IO.Path]::DirectorySeparatorChar, "") } else { $DestinationRelative }
    category = $Category
    reason = $Reason
    source_exists = $exists
    size_bytes = $sizeBytes
    action = if ($Execute) { "execute" } else { "dry_run" }
    status = $status
  }) | Out-Null
}

function Add-MoveFilesByPattern {
  param(
    [string]$SourceFolderRelative,
    [string]$Pattern,
    [string]$DestinationFolderRelative,
    [string]$Category,
    [string]$Reason
  )

  $sourceFolder = Join-RepoPath $SourceFolderRelative
  if (-not (Test-Path -LiteralPath $sourceFolder)) {
    $script:MoveRows.Add([pscustomobject]@{
      source_relative = Join-Path $SourceFolderRelative $Pattern
      destination_relative = $DestinationFolderRelative
      final_destination = $DestinationFolderRelative
      category = $Category
      reason = $Reason
      source_exists = $false
      size_bytes = $null
      action = if ($Execute) { "execute" } else { "dry_run" }
      status = "source_folder_missing"
    }) | Out-Null
    return
  }

  $files = Get-ChildItem -LiteralPath $sourceFolder -File -Filter $Pattern -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $srcRel = $f.FullName.Replace($RepoRoot + [System.IO.Path]::DirectorySeparatorChar, "")
    $dstRel = Join-Path $DestinationFolderRelative $f.Name
    Add-Move -SourceRelative $srcRel -DestinationRelative $dstRel -Category $Category -Reason $Reason
  }
}

function Add-MoveFolderContents {
  param(
    [string]$SourceFolderRelative,
    [string]$DestinationFolderRelative,
    [string]$Category,
    [string]$Reason
  )

  $sourceFolder = Join-RepoPath $SourceFolderRelative
  if (-not (Test-Path -LiteralPath $sourceFolder)) {
    $script:MoveRows.Add([pscustomobject]@{
      source_relative = $SourceFolderRelative
      destination_relative = $DestinationFolderRelative
      final_destination = $DestinationFolderRelative
      category = $Category
      reason = $Reason
      source_exists = $false
      size_bytes = $null
      action = if ($Execute) { "execute" } else { "dry_run" }
      status = "source_folder_missing"
    }) | Out-Null
    return
  }

  $items = Get-ChildItem -LiteralPath $sourceFolder -Force
  foreach ($item in $items) {
    $srcRel = $item.FullName.Replace($RepoRoot + [System.IO.Path]::DirectorySeparatorChar, "")
    $dstRel = Join-Path $DestinationFolderRelative $item.Name
    Add-Move -SourceRelative $srcRel -DestinationRelative $dstRel -Category $Category -Reason $Reason
  }
}

# ------------------------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $RepoRoot)) {
  throw "RepoRoot not found: $RepoRoot"
}

$outputRoot = Join-RepoPath "Output"
if (-not (Test-Path -LiteralPath $outputRoot)) {
  throw "Output folder not found: $outputRoot"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDirRel = "Output/reports/output_organisation"
$reportDir = Join-RepoPath $reportDirRel
Ensure-Directory -Path $reportDir

# ------------------------------------------------------------------------------
# Figures organisation
# ------------------------------------------------------------------------------

# Formalise RS coverage plots.
Add-MoveFolderContents `
  -SourceFolderRelative "Output/figures/RS_coverage_plots" `
  -DestinationFolderRelative "Output/figures/plots/RS_coverage" `
  -Category "figures_rs_coverage" `
  -Reason "Formal retained RS coverage/completeness plot group."

# Existing hydrology plots.
Add-MoveFolderContents `
  -SourceFolderRelative "Output/figures/hydrology" `
  -DestinationFolderRelative "Output/figures/plots/hydrology" `
  -Category "figures_hydrology_plots" `
  -Reason "Move hydrology plots into plots/hydrology."

# Existing MODIS plot summaries separate from MODIS maps.
Add-MoveFolderContents `
  -SourceFolderRelative "Output/figures/modis_ground_cover" `
  -DestinationFolderRelative "Output/figures/plots/MODIS_ground_cover" `
  -Category "figures_modis_plots" `
  -Reason "Move MODIS non-map plots into plots/MODIS_ground_cover."

# Legacy / superseded figure groups.
Add-MoveFolderContents `
  -SourceFolderRelative "Output/figures/06_MER_inundation" `
  -DestinationFolderRelative "Output/figures/archive/legacy_MER_plot_centroid" `
  -Category "figures_archive_legacy_mer" `
  -Reason "Archive older plot-centroid MER figures after Task 12 MER raster products."

Add-MoveFolderContents `
  -SourceFolderRelative "Output/figures/10b_ground_cover_prepost_figures" `
  -DestinationFolderRelative "Output/figures/archive/legacy_ground_cover_prepost" `
  -Category "figures_archive_legacy_ground_cover" `
  -Reason "Archive older task-style ground-cover pre/post figures."

# Current review-deck context maps.
$contextMaps = @(
  "gayini_location_context_map.png",
  "gayini_location_context_map_wide.png",
  "gayini_vegetation_group_map.png",
  "gayini_vegetation_group_map_with_plots.png"
)
foreach ($name in $contextMaps) {
  Add-Move -SourceRelative ("Output/figures/review/{0}" -f $name) `
           -DestinationRelative ("Output/figures/maps/context/{0}" -f $name) `
           -Category "figures_context_maps" `
           -Reason "Move context maps from review folder into maps/context."
}

# Workflow/synthesis images are not maps, but are deck-ready review graphics.
$deckGraphics = @(
  "gayini_analysis_workflow_summary.png",
  "gayini_hydrology_inundation_vegetation_synthesis.png"
)
foreach ($name in $deckGraphics) {
  Add-Move -SourceRelative ("Output/figures/review/{0}" -f $name) `
           -DestinationRelative ("Output/figures/review_deck/main_deck/{0}" -f $name) `
           -Category "figures_review_deck_graphics" `
           -Reason "Move deck-ready workflow/synthesis graphics into review_deck/main_deck."
}

# Current inundation maps / map-like products from review folder.
$inundationMaps = @(
  "background_flood_pattern_pre2015.png",
  "inundation_frequency_by_vegetation_group.png",
  "inundation_post_minus_pre_change_main_deck.png",
  "inundation_post_minus_pre_change_with_paddocks.png",
  "inundation_pre_post_frequency_main_deck.png",
  "plot_level_inundation_change_with_paddocks.png",
  "matched_year_inundation_comparison_main_deck.png",
  "matched_year_paired_summary_by_veg_group.png"
)
foreach ($name in $inundationMaps) {
  Add-Move -SourceRelative ("Output/figures/review/{0}" -f $name) `
           -DestinationRelative ("Output/figures/maps/inundation/{0}" -f $name) `
           -Category "figures_inundation_maps" `
           -Reason "Move inundation map/map-like products into maps/inundation."
}

# Current ground-cover / response plots from review folder.
$groundCoverPlots = @(
  "gc_total_veg_with_gauge_context_main_deck.png",
  "inundation_change_vs_total_veg_by_vegetation_group.png",
  "inundation_change_vs_total_veg_by_wetness_group.png",
  "lag_timing_zoom_2013_current_main_deck.png",
  "selected_plot_total_veg_inundation_gauge_examples.png"
)
foreach ($name in $groundCoverPlots) {
  Add-Move -SourceRelative ("Output/figures/review/{0}" -f $name) `
           -DestinationRelative ("Output/figures/plots/ground_cover/{0}" -f $name) `
           -Category "figures_ground_cover_plots" `
           -Reason "Move current response/ground-cover plots into plots/ground_cover."
}

# Appendix-only bare ground figure.
Add-Move -SourceRelative "Output/figures/review/inundation_change_vs_bare_ground_appendix_only.png" `
         -DestinationRelative "Output/figures/review_deck/appendix/inundation_change_vs_bare_ground_appendix_only.png" `
         -Category "figures_appendix" `
         -Reason "Keep bare-ground response only as appendix material."

# Current MER raster maps and plots.
$merMaps = @(
  "mer_annual_max_observed_wet_example.png",
  "mer_pre_post_annual_max_frequency_main_deck.png",
  "mer_post_minus_pre_annual_max_change_main_deck.png",
  "mer_raster_vs_annual_occurrence_change_comparison.png"
)
foreach ($name in $merMaps) {
  Add-Move -SourceRelative ("Output/figures/review/MER/{0}" -f $name) `
           -DestinationRelative ("Output/figures/maps/MER/{0}" -f $name) `
           -Category "figures_mer_maps" `
           -Reason "Move current MER raster map products into maps/MER."
}

$merPlots = @(
  "mer_observation_support_by_water_year.png",
  "mer_vs_annual_occurrence_plot_agreement.png",
  "mer_post_minus_pre_by_vegetation_group.png",
  "mer_annual_max_heatmap_appendix.png",
  "mer_observation_support_sensor_note_appendix.png"
)
foreach ($name in $merPlots) {
  Add-Move -SourceRelative ("Output/figures/review/MER/{0}" -f $name) `
           -DestinationRelative ("Output/figures/plots/MER/{0}" -f $name) `
           -Category "figures_mer_plots" `
           -Reason "Move current MER non-map plots into plots/MER."
}

# ------------------------------------------------------------------------------
# CSV organisation
# ------------------------------------------------------------------------------

$coreCsv = @(
  "plot_rs_analysis_base.csv",
  "plot_rs_gauge_analysis_base.csv",
  "curated_annual_inundation_timeseries.csv",
  "curated_daily_inundation_monthly.csv",
  "curated_ground_cover_timeseries.csv"
)
foreach ($name in $coreCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/canonical/{0}" -f $name) `
           -Category "csv_canonical" `
           -Reason "Move core curated/canonical analysis tables into csv/canonical."
}

$extractionCsv = @(
  "04c_fractional_cover_full.csv",
  "05c_landsat_inundation_full.csv",
  "06c_daily_inundation_full.csv",
  "07f_pre_post_inundation_plot_summary_fixed.csv"
)
foreach ($name in $extractionCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/extraction/{0}" -f $name) `
           -Category "csv_extraction" `
           -Reason "Move large/current extraction-derived tables into csv/extraction."
}

$hydrologyCsv = @(
  "gauge_context_for_gayini.csv",
  "gauge_data_completeness_for_gayini.csv",
  "matched_year_gauge_context.csv"
)
foreach ($name in $hydrologyCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/hydrology/{0}" -f $name) `
           -Category "csv_hydrology" `
           -Reason "Move hydrology/gauge tables into csv/hydrology."
}

$groundCoverCsv = @(
  "10a_ground_cover_prepost_group_summary.csv",
  "10a_ground_cover_prepost_group_summary_interpretation.csv",
  "10a_ground_cover_prepost_model_summary.csv",
  "10a_ground_cover_prepost_plot_summary.csv",
  "10a_ground_cover_prepost_plot_summary_interpretation.csv",
  "ground_cover_treed_plot_sensitivity.csv",
  "plot_context_flag_summary.csv",
  "plot_context_flags.csv"
)
foreach ($name in $groundCoverCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/ground_cover/{0}" -f $name) `
           -Category "csv_ground_cover" `
           -Reason "Move ground-cover summaries and interpretation tables into csv/ground_cover."
}

$inundationCsv = @(
  "background_inundation_frequency_by_plot.csv",
  "inundation_frequency_by_vegetation_group.csv",
  "matched_year_candidate_ranking.csv"
)
foreach ($name in $inundationCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/inundation/{0}" -f $name) `
           -Category "csv_inundation" `
           -Reason "Move inundation summary tables into csv/inundation."
}

$modisCsv = @(
  "03_modis_ground_cover_context_full.csv",
  "03_modis_ground_cover_management_zone_summary.csv",
  "03_modis_ground_cover_monthly_farm_buffer_summary.csv",
  "03_modis_ground_cover_prepost_summary.csv",
  "03_modis_ground_cover_seasonal_summary.csv",
  "03_modis_ground_cover_water_year_summary.csv",
  "modis_context_units_summary.csv",
  "modis_fractional_cover_summary.csv"
)
foreach ($name in $modisCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/MODIS/{0}" -f $name) `
           -Category "csv_modis" `
           -Reason "Move MODIS summary/context tables into csv/MODIS."
}

$reviewDeckCsv = @(
  "candidate_dashboard_set_for_review_updated.csv",
  "mer_metric_comparison_table.csv",
  "mer_metric_keep_defer_decision_table.csv"
)
foreach ($name in $reviewDeckCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/review_deck/{0}" -f $name) `
           -Category "csv_review_deck" `
           -Reason "Move review/deck support tables into csv/review_deck."
}

# Older MER plot-metric CSVs; archive only if present at csv root.
$legacyMerCsv = @(
  "05b_MER_plot_inundation_dynamic_metrics.csv",
  "05b_MER_plot_inundation_monthly_seasonal_max.csv"
)
foreach ($name in $legacyMerCsv) {
  Add-Move -SourceRelative ("Output/csv/{0}" -f $name) `
           -DestinationRelative ("Output/csv/archive/legacy_MER_plot_metrics/{0}" -f $name) `
           -Category "csv_archive_legacy_mer" `
           -Reason "Archive older MER plot-metric CSVs if superseded by current MER workflow."
}

# ------------------------------------------------------------------------------
# Diagnostics organisation
# ------------------------------------------------------------------------------

# RS coverage diagnostics.
Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "04c_fractional_cover_full_*" `
  -DestinationFolderRelative "Output/diagnostics/RS_coverage/fractional_cover" `
  -Category "diagnostics_rs_fractional_cover" `
  -Reason "Move current fractional-cover RS coverage diagnostics."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "05c_landsat_inundation_full_*" `
  -DestinationFolderRelative "Output/diagnostics/RS_coverage/landsat_inundation" `
  -Category "diagnostics_rs_landsat_inundation" `
  -Reason "Move current Landsat inundation coverage diagnostics."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "06c_daily_inundation_full_*" `
  -DestinationFolderRelative "Output/diagnostics/RS_coverage/daily_inundation" `
  -Category "diagnostics_rs_daily_inundation" `
  -Reason "Move current daily inundation coverage diagnostics."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "07e_pre_post_inundation_*" `
  -DestinationFolderRelative "Output/diagnostics/RS_coverage/prepost_inundation" `
  -Category "diagnostics_rs_prepost" `
  -Reason "Move current pre/post inundation diagnostics."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "07f_pre_post_inundation_*" `
  -DestinationFolderRelative "Output/diagnostics/RS_coverage/prepost_inundation" `
  -Category "diagnostics_rs_prepost" `
  -Reason "Move current pre/post inundation plot-summary diagnostics."

# Archive dev/test extraction diagnostics.
$devPatterns = @(
  "04b_fractional_cover_all_dev_*",
  "05a_landsat_inundation_10_plots_*",
  "05b_landsat_inundation_all_dev_*",
  "06a_daily_inundation_10_plots_*",
  "06b_daily_inundation_all_dev_*",
  "test_fractional_cover_*",
  "raster_dev_subset_checks.csv"
)
foreach ($pat in $devPatterns) {
  Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern $pat `
    -DestinationFolderRelative "Output/diagnostics/archive/dev_and_test_extractions" `
    -Category "diagnostics_archive_dev_test" `
    -Reason "Archive dev/test/subset extraction diagnostics superseded by full extraction outputs."
}

# MER diagnostics.
Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/06_MER_inundation" `
  -DestinationFolderRelative "Output/diagnostics/MER/plot_metrics" `
  -Category "diagnostics_mer_plot_metrics" `
  -Reason "Move current MER plot-metric diagnostics into diagnostics/MER/plot_metrics."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/10g_mer_metric_consolidation" `
  -DestinationFolderRelative "Output/diagnostics/MER/plot_metrics/task4_consolidation" `
  -Category "diagnostics_mer_plot_metrics" `
  -Reason "Move MER metric consolidation diagnostics into diagnostics/MER."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/24_mer_raster_build" `
  -DestinationFolderRelative "Output/diagnostics/MER/raster_census_smoke_test" `
  -Category "diagnostics_mer_raster_census" `
  -Reason "Move MER raster census/smoke-test diagnostics into diagnostics/MER."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/25_mer_annual_max_raster_build" `
  -DestinationFolderRelative "Output/diagnostics/MER/annual_max_raster_build" `
  -Category "diagnostics_mer_annual_max" `
  -Reason "Move current MER annual-max raster build diagnostics into diagnostics/MER."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/05b_MER_inundation" `
  -DestinationFolderRelative "Output/diagnostics/MER/archive/old_05b_MER_inundation" `
  -Category "diagnostics_archive_legacy_mer" `
  -Reason "Archive older 05b MER diagnostics."

# Ground-cover diagnostics.
Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/10a_ground_cover_prepost_response" `
  -DestinationFolderRelative "Output/diagnostics/ground_cover/prepost_response" `
  -Category "diagnostics_ground_cover" `
  -Reason "Move ground-cover pre/post response diagnostics."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/10b_ground_cover_prepost_figures" `
  -DestinationFolderRelative "Output/diagnostics/ground_cover/prepost_figures" `
  -Category "diagnostics_ground_cover" `
  -Reason "Move ground-cover figure diagnostics."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/10d_plot_context_flags" `
  -DestinationFolderRelative "Output/diagnostics/ground_cover/plot_context_flags" `
  -Category "diagnostics_ground_cover" `
  -Reason "Move plot context flag diagnostics."

# Review-deck diagnostics.
Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/14_ppt_missing_assets" `
  -DestinationFolderRelative "Output/diagnostics/review_deck/ppt_missing_assets" `
  -Category "diagnostics_review_deck" `
  -Reason "Move PPT missing asset diagnostics into diagnostics/review_deck."

Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/18_main_deck_figure_refresh" `
  -DestinationFolderRelative "Output/diagnostics/review_deck/main_deck_figure_refresh" `
  -Category "diagnostics_review_deck" `
  -Reason "Move main deck figure refresh diagnostics into diagnostics/review_deck."

# MODIS diagnostics.
Add-MoveFolderContents -SourceFolderRelative "Output/diagnostics/modis_ground_cover" `
  -DestinationFolderRelative "Output/diagnostics/MODIS/modis_ground_cover" `
  -Category "diagnostics_modis" `
  -Reason "Move MODIS diagnostic folder into diagnostics/MODIS."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "03_modis_ground_cover_*" `
  -DestinationFolderRelative "Output/diagnostics/MODIS" `
  -Category "diagnostics_modis" `
  -Reason "Move MODIS diagnostic files into diagnostics/MODIS."

Add-MoveFilesByPattern -SourceFolderRelative "Output/diagnostics" -Pattern "modis_*" `
  -DestinationFolderRelative "Output/diagnostics/MODIS" `
  -Category "diagnostics_modis" `
  -Reason "Move MODIS diagnostic files into diagnostics/MODIS."

# System diagnostics.
$systemDiag = @(
  "R_raster_temp_file_search.csv",
  "raster_catalog_warnings.csv",
  "vector_checks.csv",
  "vector_layer_summary.csv",
  "vector_qc_plot_paths.csv"
)
foreach ($name in $systemDiag) {
  Add-Move -SourceRelative ("Output/diagnostics/{0}" -f $name) `
           -DestinationRelative ("Output/diagnostics/system/{0}" -f $name) `
           -Category "diagnostics_system" `
           -Reason "Move system/vector/raster housekeeping diagnostics into diagnostics/system."
}

# ------------------------------------------------------------------------------
# Write CSV manifest
# ------------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $reportDir)) {
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

$manifestPath = Join-Path $reportDir ("output_folder_organisation_manifest_{0}.csv" -f $timestamp)

$script:MoveRows | Export-Csv -NoTypeInformation -Path $manifestPath

$totalRows = $script:MoveRows.Count
$wouldMove = ($script:MoveRows | Where-Object { $_.status -eq "would_move" }).Count
$moved = ($script:MoveRows | Where-Object { $_.status -eq "moved" }).Count
$missing = ($script:MoveRows | Where-Object { $_.status -like "source*missing" }).Count
$bytes = ($script:MoveRows | Where-Object { $_.size_bytes -ne $null } | Measure-Object -Property size_bytes -Sum).Sum
if ($null -eq $bytes) { $bytes = 0 }

Write-Host "Output organisation complete."
Write-Host "Execute mode: $Execute"
Write-Host "Total move rules / matched items: $totalRows"
Write-Host "Would move: $wouldMove"
Write-Host "Moved: $moved"
Write-Host "Missing sources / missing folders: $missing"
Write-Host "Total size of matched existing files: $bytes bytes"
Write-Host "Manifest: $manifestPath"
if (-not $Execute) {
  Write-Host "Dry run only. Re-run with -Execute to move files."
}
