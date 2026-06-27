<#
.SYNOPSIS
  Copy old/test development scripts into a dated archive folder.

.DESCRIPTION
  This helper is intentionally conservative: it copies by default, never deletes
  source files, and supports -DryRun for reviewing the manifest before copying.
#>

param(
  [switch]$DryRun,
  [switch]$Move,
  [string]$ArchiveDate = (Get-Date -Format "yyyyMMdd")
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$archiveRoot = Join-Path $repoRoot "archive"
$archiveDir = Join-Path $archiveRoot "code_pre_refactor_$ArchiveDate"
$manifestPath = Join-Path $archiveDir "archive_manifest.csv"
$archiveTimestamp = (Get-Date).ToString("s")

function Get-RepoRelativePath {
  param(
    [string]$RootPath,
    [string]$FullPath
  )

  $rootFullPath = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
  $targetFullPath = [System.IO.Path]::GetFullPath($FullPath)

  if ($targetFullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $targetFullPath.Substring($rootFullPath.Length).TrimStart('\', '/')
  }

  return $targetFullPath
}

if ($Move) {
  Write-Warning "Move mode was requested. Sources will still be copied only; this script never deletes or moves old code."
}

$candidateRules = @(
  @{ Pattern = "scripts\04a_test_*.R"; Reason = "early fractional-cover test script" },
  @{ Pattern = "scripts\04b_test_*.R"; Reason = "development fractional-cover extraction script" },
  @{ Pattern = "scripts\05a_test_*.R"; Reason = "early Landsat inundation test script" },
  @{ Pattern = "scripts\05b_test_*.R"; Reason = "development Landsat inundation extraction script" },
  @{ Pattern = "scripts\06a_test_*.R"; Reason = "early daily inundation test script" },
  @{ Pattern = "scripts\06b_test_*.R"; Reason = "development daily inundation extraction script" },
  @{ Pattern = "scripts\07g_plot_pre_post_inundation_summary_panels.R"; Reason = "older Step 7 plotting script superseded by 07g v2" },
  @{ Pattern = "scripts\07h_plot_annual_inundation_panels.R"; Reason = "older Step 7 plotting script superseded by 07h v2" },
  @{ Pattern = "scripts\extraction_check_*.R"; Reason = "ad hoc extraction checking script" },
  @{ Pattern = "Output\csv\test_*.csv"; Reason = "test extraction output" }
)

$manifestRows = New-Object System.Collections.Generic.List[object]

foreach ($rule in $candidateRules) {
  $matches = Get-ChildItem -Path (Join-Path $repoRoot $rule.Pattern) -File -ErrorAction SilentlyContinue

  foreach ($file in $matches) {
    $relativePath = Get-RepoRelativePath -RootPath $repoRoot -FullPath $file.FullName
    $destinationPath = Join-Path $archiveDir $relativePath
    $action = if ($DryRun) { "dry_run_copy" } else { "copied" }

    $manifestRows.Add([pscustomobject]@{
      source_path = $relativePath
      destination_path = Get-RepoRelativePath -RootPath $repoRoot -FullPath $destinationPath
      file_size_bytes = $file.Length
      last_write_time = $file.LastWriteTime.ToString("s")
      archive_timestamp = $archiveTimestamp
      reason = $rule.Reason
      action = $action
    })

    if (-not $DryRun) {
      $destinationParent = Split-Path -Parent $destinationPath
      New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
      Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
    }
  }
}

if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
  $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation
  Write-Host "Wrote archive manifest: $manifestPath"
} else {
  $manifestRows | Format-Table -AutoSize
  Write-Host "Dry run only. No files copied and no manifest written."
  Write-Host "Archive target would be: $archiveDir"
}
