<#
03_cleanup_R_terra_temp.ps1

Purpose:
  Remove old R / terra temporary raster files and folders.

Safe default:
  Dry run only unless -Delete is supplied.

Recommended:
  Close RStudio before running.
#>

param(
  [switch]$Delete,
  [switch]$KillR,
  [string[]]$AdditionalTempRoots = @(
    "D:\Github_repos\Gayini\data_intermediate\terra_tmp",
    "D:\Github_repos\Gayini\terra_tmp",
    "D:\Github_repos\Gayini\temp",
    "D:\Github_repos\Gayini\tmp",
    "D:\Github_repos\Gayini\Output\temp",
    "D:\Github_repos\Gayini\Output\tmp"
  )
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "R / terra temporary file cleanup" -ForegroundColor Cyan
Write-Host "Delete mode: $Delete"
Write-Host ""

$r_process_names = @(
  "rstudio",
  "rsession",
  "R",
  "Rterm",
  "Rscript"
)

$running_r = Get-Process -ErrorAction SilentlyContinue |
  Where-Object { $r_process_names -contains $_.ProcessName }

if ($running_r) {
  Write-Host "R/RStudio-related processes are currently running:" -ForegroundColor Yellow
  $running_r | Select-Object ProcessName, Id, CPU, WorkingSet64 | Format-Table

  if ($KillR) {
    Write-Host "Stopping R/RStudio processes..." -ForegroundColor Yellow
    $running_r | Stop-Process -Force
    Start-Sleep -Seconds 2
  } else {
    Write-Host ""
    Write-Host "Close RStudio first, or rerun with -KillR if you are sure nothing needs saving." -ForegroundColor Yellow
    Write-Host "No files deleted."
    exit 1
  }
}

$temp_roots = @(
  $env:TEMP,
  $env:TMP,
  "$env:LOCALAPPDATA\Temp"
) + $AdditionalTempRoots

$temp_roots = $temp_roots |
  Where-Object { $_ -and (Test-Path $_) } |
  Sort-Object -Unique

Write-Host "Searching these temp roots:" -ForegroundColor Cyan
$temp_roots | ForEach-Object { Write-Host "  $_" }
Write-Host ""

$r_temp_dirs = foreach ($root in $temp_roots) {
  Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like "Rtmp*" -or
      $_.Name -like "R_tmp*" -or
      $_.Name -like "terra*" -or
      $_.Name -like "spat*"
    }
}

$temp_file_patterns = @(
  "terra*.tif",
  "terra*.tiff",
  "terra*.vrt",
  "terra*.grd",
  "terra*.gri",
  "spat*.tif",
  "spat*.tiff",
  "spat*.vrt",
  "raster_tmp*.tif",
  "r_tmp*.tif"
)

$temp_files = foreach ($root in $temp_roots) {
  foreach ($pattern in $temp_file_patterns) {
    Get-ChildItem -Path $root -File -Filter $pattern -ErrorAction SilentlyContinue
  }
}

$targets = @($r_temp_dirs + $temp_files) | Sort-Object FullName -Unique

if (-not $targets -or $targets.Count -eq 0) {
  Write-Host "No R / terra temp targets found." -ForegroundColor Green
  exit 0
}

$total_bytes = 0

foreach ($target in $targets) {
  if ($target.PSIsContainer) {
    $bytes = (
      Get-ChildItem -Path $target.FullName -Recurse -File -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum
    ).Sum
  } else {
    $bytes = $target.Length
  }

  if ($null -eq $bytes) { $bytes = 0 }
  $total_bytes += $bytes
}

$total_gb = [math]::Round($total_bytes / 1GB, 3)

Write-Host "Found $($targets.Count) temp targets." -ForegroundColor Cyan
Write-Host "Approx size: $total_gb GB"
Write-Host ""

$targets |
  Select-Object FullName, LastWriteTime |
  Format-Table -AutoSize

if (-not $Delete) {
  Write-Host ""
  Write-Host "Dry run only. Nothing deleted." -ForegroundColor Yellow
  Write-Host "To delete, rerun with:"
  Write-Host "  powershell -ExecutionPolicy Bypass -File D:\Github_repos\Gayini\scripts\09_qa\03_cleanup_R_terra_temp.ps1 -Delete"
  exit 0
}

Write-Host ""
Write-Host "Deleting temp targets..." -ForegroundColor Yellow

foreach ($target in $targets) {
  try {
    Remove-Item -Path $target.FullName -Recurse -Force -ErrorAction Stop
    Write-Host "Deleted: $($target.FullName)"
  } catch {
    Write-Host "Could not delete: $($target.FullName)" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "Cleanup complete." -ForegroundColor Green
