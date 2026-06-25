param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$ZipPath = "Output\reports\recent_mer_run_changes_20260623.zip"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $RootDir).Path
$zipFullPath = Join-Path $root $ZipPath
$zipParent = Split-Path -Parent $zipFullPath
$stagingRoot = Join-Path $root "Output\reports\recent_mer_run_changes_20260623_staging"
$manifestPath = Join-Path $root "Output\reports\recent_mer_run_changes_20260623_manifest.csv"

$relativeInputs = @(
  "docs\CHANGELOG_MER_inundation_20260623.md",
  "docs\MER_inundation_method_note_20260623.md",
  "docs\current_run_order.md",
  "scripts\09a_curate_rs_hydrology_analysis_base.R",
  "scripts\archive\pre_clean_spine_20260623\05b_MER_extract_inundation.R",
  "Output\csv\05b_MER_plot_inundation_dynamic_metrics.csv",
  "Output\csv\05b_MER_plot_inundation_monthly_seasonal_max.csv",
  "Output\csv\curated_ground_cover_timeseries.csv",
  "Output\csv\curated_annual_inundation_timeseries.csv",
  "Output\csv\curated_daily_inundation_monthly.csv",
  "Output\csv\plot_rs_analysis_base.csv",
  "data_processed\plot_inundation_dynamic_metrics.csv",
  "data_processed\hydrology\plot_rs_gauge_monthly_context.csv",
  "data_processed\hydrology\plot_rs_gauge_water_year_context.csv",
  "Output\diagnostics\06_MER_inundation",
  "Output\diagnostics\07_curate_rs_analysis_base",
  "Output\diagnostics\hydrology",
  "Output\figures\06_MER_inundation"
)

function Assert-InRepo {
  param([string]$PathToCheck)

  $resolved = (Resolve-Path -LiteralPath $PathToCheck -ErrorAction SilentlyContinue)
  if (-not $resolved) {
    return $null
  }

  $resolvedPath = $resolved.Path
  if (-not $resolvedPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to process path outside repo root: $resolvedPath"
  }

  return $resolvedPath
}

function Get-RepoRelativePath {
  param([string]$FullPath)

  if (-not $FullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to relativise path outside repo root: $FullPath"
  }

  return $FullPath.Substring($root.Length).TrimStart("\", "/")
}

New-Item -ItemType Directory -Force -Path $zipParent | Out-Null

if (Test-Path -LiteralPath $stagingRoot) {
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($rel in $relativeInputs) {
  $candidate = Join-Path $root $rel
  $resolvedPath = Assert-InRepo -PathToCheck $candidate
  if (-not $resolvedPath) {
    Write-Warning "Missing, skipped: $rel"
    continue
  }

  $item = Get-Item -LiteralPath $resolvedPath -Force
  if ($item.PSIsContainer) {
    Get-ChildItem -LiteralPath $resolvedPath -File -Recurse -Force | ForEach-Object {
      [void]$files.Add($_)
    }
  } else {
    [void]$files.Add($item)
  }
}

$files = $files |
  Sort-Object FullName -Unique |
  Where-Object {
    $_.FullName -ne $zipFullPath -and
    $_.FullName -ne $manifestPath -and
    -not $_.FullName.StartsWith($stagingRoot, [System.StringComparison]::OrdinalIgnoreCase)
  }

$manifestRows = foreach ($file in $files) {
  $relativePath = Get-RepoRelativePath -FullPath $file.FullName
  $destination = Join-Path $stagingRoot $relativePath
  $destinationParent = Split-Path -Parent $destination
  New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $destination -Force

  [pscustomobject]@{
    relative_path = $relativePath
    size_bytes = $file.Length
    last_write_time = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
  }
}

$manifestRows |
  Sort-Object relative_path |
  Export-Csv -LiteralPath $manifestPath -NoTypeInformation

$manifestDestination = Join-Path $stagingRoot (Get-RepoRelativePath -FullPath $manifestPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $manifestDestination) | Out-Null
Copy-Item -LiteralPath $manifestPath -Destination $manifestDestination -Force

if (Test-Path -LiteralPath $zipFullPath) {
  Remove-Item -LiteralPath $zipFullPath -Force
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipFullPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

$zipItem = Get-Item -LiteralPath $zipFullPath

Write-Output "Created zip: $zipFullPath"
Write-Output "Created manifest: $manifestPath"
Write-Output ("Files included: {0}" -f $manifestRows.Count)
Write-Output ("Zip size MB: {0:N3}" -f ($zipItem.Length / 1MB))
