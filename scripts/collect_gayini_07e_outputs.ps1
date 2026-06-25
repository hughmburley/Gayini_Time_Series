<#
collect_gayini_07e_outputs.ps1

Purpose:
  Collect the Gayini 07e PRE/POST inundation outputs into one zipped folder
  for upload/review.

Default project root:
  D:\Github_repos\Gayini

Main contents:
  - Output/diagnostics/07e_pre_post_inundation*
  - Output/csv/07e_pre_post_inundation*
  - data_processed/*pre_post*inundation*
  - Output/rasters/inundation_pre_post
  - scripts/07e_build_pre_post_inundation_frequency_rasters.R
  - R/inundation_pre_post_raster_functions.R
  - R/gayini_temp_cleanup_functions.R, if present

Usage:
  Dry run:
    powershell -ExecutionPolicy Bypass -File .\collect_gayini_07e_outputs.ps1 -DryRun

  Create ZIP:
    powershell -ExecutionPolicy Bypass -File .\collect_gayini_07e_outputs.ps1

  Create ZIP without annual rasters:
    powershell -ExecutionPolicy Bypass -File .\collect_gayini_07e_outputs.ps1 -SkipAnnualRasters
#>

param(
  [string]$ProjectRoot = "D:\Github_repos\Gayini",

  [string]$DestinationZip = "",

  [switch]$SkipAnnualRasters,

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

  $DestinationZip = Join-Path $reportDir "Gayini_07e_prepost_outputs_$timestamp.zip"
}

$DestinationZipDir = Split-Path $DestinationZip -Parent

if (-not (Test-Path $DestinationZipDir)) {
  New-Item -ItemType Directory -Path $DestinationZipDir -Force | Out-Null
}

$stagingRoot = Join-Path $env:TEMP "Gayini_07e_prepost_outputs_$timestamp"

if (Test-Path $stagingRoot) {
  Remove-Item -Path $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$files = New-Object System.Collections.Generic.List[string]

Write-Host ""
Write-Host "Collecting Gayini 07e PRE/POST outputs" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host "Destination ZIP: $DestinationZip"
Write-Host "Skip annual rasters: $SkipAnnualRasters"
Write-Host ""

# Diagnostics and CSV outputs
Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\diagnostics" -Patterns @(
  "07e_pre_post_inundation*.csv",
  "07e_pre_post_inundation*.txt",
  "07e_pre_post_inundation*.tif",
  "07e_pre_post_inundation*.json",
  "07e_pre_post_inundation*.yml",
  "07e_pre_post_inundation*.yaml"
) -FileList $files

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\csv" -Patterns @(
  "07e_pre_post_inundation*.csv",
  "*pre_post*inundation*.csv",
  "*inundation_frequency*.csv"
) -FileList $files

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "data_processed" -Patterns @(
  "*pre_post*inundation*.csv",
  "*inundation_frequency*.csv",
  "plot_pre_post_inundation_frequency.csv"
) -FileList $files

# Raster outputs
if (-not $SkipAnnualRasters) {
  Add-DirectoryFiles -Root $ProjectRoot -RelativeDir "Output\rasters\inundation_pre_post" -FileList $files -ExcludePathFragments @(
    "\terra_tmp\",
    "\temp\",
    "\tmp\"
  )
} else {
  # Keep only final PRE/POST/difference rasters and key metadata if annual rasters are skipped.
  Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\rasters\inundation_pre_post" -Patterns @(
    "pre_conservation*.tif",
    "post_conservation*.tif",
    "post_minus_pre*.tif",
    "*frequency*.tif",
    "*valid_year_count*.tif",
    "*.csv",
    "*.txt"
  ) -FileList $files
}

# Optional figures, if present
Add-MatchingFiles -Root $ProjectRoot -RelativeDir "Output\figures" -Patterns @(
  "07e*.png",
  "*pre_post*inundation*.png",
  "*inundation_frequency*.png"
) -FileList $files

# Include exact code used
Add-MatchingFiles -Root $ProjectRoot -RelativeDir "scripts" -Patterns @(
  "07e_build_pre_post_inundation_frequency_rasters.R"
) -FileList $files

Add-MatchingFiles -Root $ProjectRoot -RelativeDir "R" -Patterns @(
  "inundation_pre_post_raster_functions.R",
  "gayini_temp_cleanup_functions.R"
) -FileList $files

# Keep unique files only
$uniqueFiles = $files |
  Sort-Object -Unique |
  Where-Object { Test-Path $_ }

if ($uniqueFiles.Count -eq 0) {
  throw "No files found to collect. Check that 07e outputs exist under Output/."
}

# Summarise size
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

$fileSummary |
  Sort-Object SizeMB -Descending |
  Select-Object -First 30 |
  Format-Table -AutoSize

if ($DryRun) {
  Write-Host ""
  Write-Host "Dry run only. Nothing copied or zipped." -ForegroundColor Yellow
  Remove-Item -Path $stagingRoot -Recurse -Force
  exit 0
}

# Copy files into staging folder with relative paths preserved
foreach ($f in $uniqueFiles) {
  Copy-PreserveRelativePath -SourceFile $f -ProjectRoot $ProjectRoot -StagingRoot $stagingRoot
}

# Write manifest into staging folder
$manifestPath = Join-Path $stagingRoot "Gayini_07e_prepost_output_manifest.csv"
$fileSummary |
  Sort-Object RelativePath |
  Export-Csv -Path $manifestPath -NoTypeInformation

# Add README
$readmePath = Join-Path $stagingRoot "README_Gayini_07e_prepost_outputs.txt"

@"
Gayini 07e PRE/POST inundation output bundle
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project root: $ProjectRoot

Contents include:
- 07e diagnostics CSVs
- 07e output CSVs
- PRE/POST inundation frequency rasters
- Annual combo rasters unless -SkipAnnualRasters was used
- Exact 07e script and helper functions used
- Manifest: Gayini_07e_prepost_output_manifest.csv

Suggested review files:
- Output/diagnostics/07e_pre_post_inundation_logical_checks.csv
- Output/diagnostics/07e_pre_post_inundation_observation_density_by_year.csv
- Output/diagnostics/07e_pre_post_inundation_annual_cell_value_summary.csv
- Output/diagnostics/07e_pre_post_inundation_annual_cell_value_checks.csv
- Output/csv/07e_pre_post_inundation_plot_summary.csv
- Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif
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
