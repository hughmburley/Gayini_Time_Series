<#
collect_gayini_new_step7_png_figures.ps1

Purpose:
  Collect only the PNG figure files from the new Gayini Step 7 figure scripts
  into a single ZIP for review/upload.

Default project root:
  D:\Github_repos\Gayini

Default output:
  D:\Github_repos\Gayini\Output\reports\Gayini_new_step7_png_figures_YYYYMMDD_HHMMSS.zip

Default collection scope:
  Recursively searches Output\figures for PNGs matching new Step 7 figure prefixes:
    - 07g*
    - 07h*
    - 07i*
    - 07j*
    - 07k*
    - 07a_gc*
    - *prepost*
    - *pre_post*
    - *plot_dashboard*

Useful modes:
  Dry run:
    powershell -ExecutionPolicy Bypass -File D:\Github_repos\Gayini\scripts\collect_gayini_new_step7_png_figures.ps1 -DryRun

  Create ZIP:
    powershell -ExecutionPolicy Bypass -File D:\Github_repos\Gayini\scripts\collect_gayini_new_step7_png_figures.ps1

  Include every PNG under Output\figures:
    powershell -ExecutionPolicy Bypass -File D:\Github_repos\Gayini\scripts\collect_gayini_new_step7_png_figures.ps1 -AllPngUnderFigures

  Open destination folder after ZIP is made:
    powershell -ExecutionPolicy Bypass -File D:\Github_repos\Gayini\scripts\collect_gayini_new_step7_png_figures.ps1 -OpenFolder
#>

param(
  [string]$ProjectRoot = "D:\Github_repos\Gayini",

  [string]$DestinationZip = "",

  [switch]$AllPngUnderFigures,

  [switch]$DryRun,

  [switch]$OpenFolder
)

$ErrorActionPreference = "Stop"

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

$figuresDir = Join-Path $ProjectRoot "Output\figures"

if (-not (Test-Path $figuresDir)) {
  throw "Figures directory not found: $figuresDir"
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($DestinationZip)) {
  $reportDir = Join-Path $ProjectRoot "Output\reports"
  if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  }

  $DestinationZip = Join-Path $reportDir "Gayini_new_step7_png_figures_$timestamp.zip"
}

$DestinationZipDir = Split-Path $DestinationZip -Parent

if (-not (Test-Path $DestinationZipDir)) {
  New-Item -ItemType Directory -Path $DestinationZipDir -Force | Out-Null
}

$stagingRoot = Join-Path $env:TEMP "Gayini_new_step7_png_figures_$timestamp"

if (Test-Path $stagingRoot) {
  Remove-Item -Path $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

Write-Host ""
Write-Host "Collecting new Gayini Step 7 PNG figures" -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot"
Write-Host "Figures dir:  $figuresDir"
Write-Host "Destination:  $DestinationZip"
Write-Host "All PNGs:     $AllPngUnderFigures"
Write-Host ""

if ($AllPngUnderFigures) {

  $files = Get-ChildItem -Path $figuresDir -Recurse -File -Filter "*.png" -ErrorAction SilentlyContinue

} else {

  $patterns = @(
    "07g*.png",
    "07h*.png",
    "07i*.png",
    "07j*.png",
    "07k*.png",
    "07a_gc*.png",
    "*prepost*.png",
    "*pre_post*.png",
    "*plot_dashboard*.png"
  )

  $files = foreach ($pattern in $patterns) {
    Get-ChildItem -Path $figuresDir -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
  }

  $files = $files | Sort-Object FullName -Unique
}

$files = $files |
  Where-Object {
    $_.FullName -notlike "*\archive\*" -and
    $_.FullName -notlike "*\tmp\*" -and
    $_.FullName -notlike "*\temp\*"
  } |
  Sort-Object FullName -Unique

if ($files.Count -eq 0) {
  throw "No matching PNG files found under: $figuresDir"
}

$totalBytes = 0

$fileSummary = foreach ($f in $files) {
  $totalBytes += $f.Length

  [PSCustomObject]@{
    RelativePath = $f.FullName.Substring($ProjectRoot.Length).TrimStart("\", "/")
    SizeMB = [math]::Round($f.Length / 1MB, 3)
    LastWriteTime = $f.LastWriteTime
  }
}

$totalMB = [math]::Round($totalBytes / 1MB, 2)

Write-Host "PNG files found: $($files.Count)" -ForegroundColor Cyan
Write-Host "Approx total size: $totalMB MB"
Write-Host ""

$fileSummary |
  Sort-Object RelativePath |
  Format-Table -AutoSize

if ($DryRun) {
  Write-Host ""
  Write-Host "Dry run only. Nothing copied or zipped." -ForegroundColor Yellow
  Remove-Item -Path $stagingRoot -Recurse -Force
  exit 0
}

foreach ($f in $files) {
  Copy-PreserveRelativePath -SourceFile $f.FullName -ProjectRoot $ProjectRoot -StagingRoot $stagingRoot
}

$manifestPath = Join-Path $stagingRoot "Gayini_new_step7_png_figure_manifest.csv"

$fileSummary |
  Sort-Object RelativePath |
  Export-Csv -Path $manifestPath -NoTypeInformation

$readmePath = Join-Path $stagingRoot "README_Gayini_new_step7_png_figures.txt"

@"
Gayini new Step 7 PNG figure bundle
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Project root: $ProjectRoot

Purpose:
  Review/upload only the PNG figures generated by the new Step 7 plotting scripts.

Collection scope:
  AllPngUnderFigures: $AllPngUnderFigures

Included folder roots may include:
  Output/figures/07g_prepost_panels_v2/
  Output/figures/07h_annual_inundation_panels_v2/
  Output/figures/07j_plot_dashboards_prepost_v2/
  Output/figures/07k_ground_cover_summary_no_treatment/
  Other matching 07g/07h/07i/07j/07k/07a_gc PNG files under Output/figures/

Manifest:
  Gayini_new_step7_png_figure_manifest.csv
"@ | Set-Content -Path $readmePath -Encoding UTF8

if (Test-Path $DestinationZip) {
  Remove-Item -Path $DestinationZip -Force
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $DestinationZip -Force

Remove-Item -Path $stagingRoot -Recurse -Force

Write-Host ""
Write-Host "Created PNG figure ZIP:" -ForegroundColor Green
Write-Host $DestinationZip
Write-Host ""

if ($OpenFolder) {
  Invoke-Item $DestinationZipDir
}
