<#
collect_gayini_step7_outputs.ps1

Purpose:
  Collect all Gayini Step 7 outputs into one zipped folder for review.

Patch note:
  This version explicitly collects CSV files recursively from:
    - Output\diagnostics
    - Output\csv
    - data_processed
    - Output\figures\07g_prepost_panels
    - Output\figures\07h_annual_inundation_panels
    - Output\rasters\inundation_pre_post
  This fixes cases where CSVs were missed because they were written into
  nested figure/output folders or did not match the earlier filename patterns.

Default project root:
  D:\Github_repos\Gayini
#>

param(
  [string]$ProjectRoot = "D:\Github_repos\Gayini",

  [string]$DestinationZip = "",

  [switch]$SkipAnnualRasters,

  [switch]$FiguresTablesCodeOnly,

  [switch]$IncludeArchive,

  [switch]$DryRun,

  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

function Add-MatchingFiles {
  param(
    [string]$Root,
    [string]$RelativeDir,
    [string[]]$Patterns,
    [System.Collections.Generic.List[string]]$FileList
  )

  $dir = Join-Path $Root $RelativeDir

  if (-not (Test-Path $dir)) {
    Write-Host "Missing directory, skipping: $RelativeDir" -ForegroundColor Yellow
    return
  }

  foreach ($pattern in $Patterns) {
    Get-ChildItem -Path $dir -File -Filter $pattern -ErrorAction SilentlyContinue |
      ForEach-Object {
        $FileList.Add($_.FullName)
      }
  }
}

function Add-RecursiveMatchingFiles {
  param(
    [string]$Root,
    [string]$RelativeDir,
    [string[]]$Patterns,
    [System.Collections.Generic.List[string]]$FileList,
    [string[]]$ExcludePathFragments = @()
  )

  $dir = Join-Path $Root $RelativeDir

  if (-not (Test-Path $dir)) {
    Write-Host "Missing directory, skipping recursive search: $RelativeDir" -ForegroundColor Yellow
    return
  }

  foreach ($pattern in $Patterns) {
    Get-ChildItem -Path $dir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
      Where-Object {
        $include = $true

        foreach ($frag in $ExcludePathFragments) {
          if ($_.FullName -like "*$frag*") {
            $include = $false
            break
          }
        }

        $include
      } |
      ForEach-Object {
        $FileList.Add($_.FullName)
      }
  }
}

function Add-DirectoryFiles {
  param(
    [string]$Root,
    [string]$RelativeDir,
    [System.Collections.Generic.List[string]]$FileList,
    [string[]]$ExcludePathFragments = @()
  )

  $dir = Join-Path $Root $RelativeDir

  if (-not (Test-Path $dir)) {
    Write-Host "Missing directory, skipping: $RelativeDir" -ForegroundColor Yellow
    return
  }

  Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $include = $true

      foreach ($frag in $ExcludePathFragments) {
        if ($_.FullName -like "*$frag*") {
          $include = $false
          break
        }
      }

      $include
    } |
    ForEach-Object {
      $FileList.Add($_.FullName)
    }
}

function Copy-PreserveRelativePath {
  param(
    [string]$SourceFile,
    [string]$ProjectRoot,
    [string]$StagingRoot
  )

  $relative = $SourceFile.Substring($ProjectRoot.Length).TrimStart("\", "/")
  $destination = Join-Path $StagingRoot $relative
  $destinationDir = Split-Path $destination -Parent

  if (-not (Test-Path $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
  }

  Copy-Item -Path $SourceFile -Destination $destination -Force
}

if (-not (Test-Path $ProjectRoot)) {
  throw "Project root not found: $ProjectRoot"
}

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($DestinationZip)) {
  $reportDir = Join-Path $ProjectRoot "Output\reports"
  if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  }

  $DestinationZip = Join-Path $reportDir "Gayini_step7_outputs_$timestamp.zip"
}

$DestinationZipDir = Split-Path $DestinationZip -Parent

if (-not (Test-Path $DestinationZipDir)) {
  New-Item -ItemType Directory -Path $DestinationZipDir -Force | Out-Null
}

$stagingRoot = Join-Path $env:TEMP "Gayini_step7_outputs_$timestamp"

if (Test-Path $stagingRoot) {
  Remove-Item -Path $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$files = New-Object System.Collections.Generic.List[string]

Write-Host ""
Write-Host "Collecting Gayini Step 7 outputs" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host "Destination ZIP: $DestinationZip"
Write-Host "Skip annual rasters: $SkipAnnualRasters"
Write-Host "Figures/tables/code only: $FiguresTablesCodeOnly"
Write-Host ""

# ---------------------------------------------------------------------
# Step 7 CSV / diagnostics outputs
# ---------------------------------------------------------------------

# Explicit recursive CSV grab: this is the important patched part.
Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "Output\diagnostics" -Patterns @(
  "07*.csv",
  "*pre_post*inundation*.csv",
  "*inundation_frequency*.csv",
  "*inundation*.csv"
) -FileList $files

Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "Output\csv" -Patterns @(
  "07*.csv",
  "*pre_post*inundation*.csv",
  "*inundation_frequency*.csv",
  "*inundation*.csv"
) -FileList $files

Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "data_processed" -Patterns @(
  "07*.csv",
  "*pre_post*inundation*.csv",
  "*inundation_frequency*.csv",
  "*inundation*.csv",
  "plot_pre_post_inundation_frequency*.csv"
) -FileList $files

Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "Output\figures\07g_prepost_panels" -Patterns @(
  "*.csv"
) -FileList $files

Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "Output\figures\07h_annual_inundation_panels" -Patterns @(
  "*.csv"
) -FileList $files

Add-RecursiveMatchingFiles -Root $ProjectRoot -RelativeDir "Output\rasters\inundation_pre_post" -Patterns @(
  "*.csv",
  "*.txt",
  "*.json",
  "*.yml",
  "*.yaml"
) -FileList $files -ExcludePathFragments @(
  "\terra_tmp\",
  "\temp\",
  "\tmp\"
)

# Non-recursive legacy patterns retained.
Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\diagnostics" -Patterns @(
  "07e_pre_post_inundation*.txt",
  "07e_pre_post_inundation*.json",
  "07e_pre_post_inundation*.yml",
  "07e_pre_post_inundation*.yaml",
  "07f_pre_post_inundation*.txt"
) -FileList $files

# ---------------------------------------------------------------------
# Step 7 figures
# ---------------------------------------------------------------------

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\figures" -Patterns @(
  "07e*.png",
  "07f*.png",
  "07g*.png",
  "07h*.png",
  "*pre_post*inundation*.png",
  "*inundation_frequency*.png"
) -FileList $files

Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Output\figures\07g_prepost_panels" -FileList $files
Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Output\figures\07h_annual_inundation_panels" -FileList $files

# ---------------------------------------------------------------------
# Step 7 rasters
# ---------------------------------------------------------------------

if (-not $FiguresTablesCodeOnly) {

  if (-not $SkipAnnualRasters) {
    Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Output\rasters\inundation_pre_post" -FileList $files -ExcludePathFragments @(
      "\terra_tmp\",
      "\temp\",
      "\tmp\"
    )
  } else {
    Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\rasters\inundation_pre_post" -Patterns @(
      "pre_conservation*.tif",
      "post_conservation*.tif",
      "post_minus_pre*.tif",
      "*frequency*.tif",
      "*valid_year_count*.tif",
      "*wet_year_count*.tif",
      "*.csv",
      "*.txt"
    ) -FileList $files
  }
}

# ---------------------------------------------------------------------
# Step 7 scripts and helper functions
# ---------------------------------------------------------------------

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "scripts" -Patterns @(
  "07e_build_pre_post_inundation_frequency_rasters.R",
  "07f_reextract_prepost_inundation_to_plots_only.R",
  "07g_plot_pre_post_inundation_summary_panels.R",
  "07h_plot_annual_inundation_panels.R",
  "collect_gayini_step7_outputs.ps1"
) -FileList $files

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "R" -Patterns @(
  "inundation_pre_post_raster_functions.R",
  "inundation_pre_post_plotting_functions.R",
  "gayini_temp_cleanup_functions.R"
) -FileList $files

# ---------------------------------------------------------------------
# Mapping context files: shapefiles and spatial inputs
# ---------------------------------------------------------------------

Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Input\shapefiles" -FileList $files -ExcludePathFragments @(
  "\archive\",
  "\temp\",
  "\tmp\"
)

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "data_intermediate\spatial" -Patterns @(
  "plots_clean.gpkg",
  "boundary_clean.gpkg",
  "*.csv"
) -FileList $files

# ---------------------------------------------------------------------
# Optional archive inclusion
# ---------------------------------------------------------------------

if ($IncludeArchive) {
  Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Output\archive" -FileList $files -ExcludePathFragments @(
    "\terra_tmp\",
    "\temp\",
    "\tmp\"
  )
}

# ---------------------------------------------------------------------
# Unique / summarize
# ---------------------------------------------------------------------

$uniqueFiles = $files |
  Sort-Object -Unique |
  Where-Object { Test-Path $_ }

if ($uniqueFiles.Count -eq 0) {
  throw "No files found to collect. Check that Step 7 outputs exist under Output/."
}

$totalBytes = 0

$fileSummary = foreach ($f in $uniqueFiles) {
  $item = Get-Item $f
  $totalBytes += $item.Length

  [PSCustomObject]@{
    RelativePath = $f.Substring($ProjectRoot.Length).TrimStart("\", "/")
    SizeMB = [math]::Round($item.Length / 1MB, 3)
    LastWriteTime = $item.LastWriteTime
  }
}

$totalGB = [math]::Round($totalBytes / 1GB, 3)

Write-Host "Files found: $($uniqueFiles.Count)" -ForegroundColor Cyan
Write-Host "Approx total size: $totalGB GB"
Write-Host ""

Write-Host "CSV files included:" -ForegroundColor Cyan
$fileSummary |
  Where-Object { $_.RelativePath -like "*.csv" } |
  Sort-Object RelativePath |
  Format-Table -AutoSize

Write-Host ""
Write-Host "Largest files:" -ForegroundColor Cyan
$fileSummary |
  Sort-Object SizeMB -Descending |
  Select-Object -First 40 |
  Format-Table -AutoSize

if ($DryRun) {
  Write-Host ""
  Write-Host "Dry run only. Nothing copied or zipped." -ForegroundColor Yellow
  Remove-Item -Path $stagingRoot -Recurse -Force
  exit 0
}

# ---------------------------------------------------------------------
# Copy, manifest, README, zip
# ---------------------------------------------------------------------

foreach ($f in $uniqueFiles) {
  Copy-PreserveRelativePath -SourceFile $f -ProjectRoot $ProjectRoot -StagingRoot $stagingRoot
}

$manifestPath = Join-Path $stagingRoot "Gayini_step7_output_manifest.csv"

$fileSummary |
  Sort-Object RelativePath |
  Export-Csv -Path $manifestPath -NoTypeInformation

$readmePath = Join-Path $stagingRoot "README_Gayini_step7_outputs.txt"

@"
Gayini Step 7 output bundle
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project root: $ProjectRoot

Purpose:
  Review and tweak Step 7 outputs for the pre/post inundation-frequency analysis.

Contents may include:
  - 07e PRE/POST raster build outputs
  - 07f fixed plot extraction outputs
  - 07g pre/post summary panels
  - 07h annual inundation panels
  - Step 7 scripts and helper functions
  - spatial context files used for plotting

Key review files:
  Output/diagnostics/07e_pre_post_inundation_logical_checks.csv
  Output/diagnostics/07e_pre_post_inundation_observation_density_by_year.csv
  Output/diagnostics/07e_pre_post_inundation_period_raster_value_summary.csv
  Output/diagnostics/07f_pre_post_inundation_plot_extraction_checks.csv
  Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv
  data_processed/plot_pre_post_inundation_frequency_fixed.csv

Key figure folders:
  Output/figures/07g_prepost_panels/
  Output/figures/07h_annual_inundation_panels/

Key raster folders:
  Output/rasters/inundation_pre_post/
  Output/rasters/inundation_pre_post/annual/

Manifest:
  Gayini_step7_output_manifest.csv

Collection settings:
  SkipAnnualRasters: $SkipAnnualRasters
  FiguresTablesCodeOnly: $FiguresTablesCodeOnly
  IncludeArchive: $IncludeArchive
"@ | Set-Content -Path $readmePath -Encoding UTF8

if (Test-Path $DestinationZip) {
  Remove-Item -Path $DestinationZip -Force
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $DestinationZip -Force

Remove-Item -Path $stagingRoot -Recurse -Force

Write-Host ""
Write-Host "Created ZIP:" -ForegroundColor Green
Write-Host $DestinationZip
Write-Host ""

if ($OpenFolder) {
  Invoke-Item $DestinationZipDir
}
