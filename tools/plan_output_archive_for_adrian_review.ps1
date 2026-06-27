<#
.SYNOPSIS
  Build a dry-run archive plan for old Output files before Adrian review.

.DESCRIPTION
  This script is intentionally non-destructive. It scans selected Output
  folders, classifies files using conservative keep/archive/manual-review
  rules, writes dry-run manifests, and stops if any safety rule is violated.

  It does not move, delete, rename, compress, or create the proposed archive
  destination.
#>

param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")),
  [double]$OlderThanHours = 48
)

$ErrorActionPreference = "Stop"

$runTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$now = Get-Date
$rootPath = [System.IO.Path]::GetFullPath((Resolve-Path $Root)).TrimEnd('\', '/')
$dryRunDir = Join-Path $rootPath "Output\reports\archive_dry_run_$runTimestamp"
$proposedArchiveRootRel = "Output\archive\pre_adrian_review_$runTimestamp"
$proposedArchiveRoot = Join-Path $rootPath $proposedArchiveRootRel

$scanFolderRels = @(
  "Output\csv",
  "Output\figures",
  "Output\diagnostics",
  "Output\maps",
  "Output\reports",
  "Output\rasters"
)

$manifestColumns = @(
  "decision_class",
  "relative_path",
  "full_path",
  "extension",
  "size_bytes",
  "last_write_time",
  "age_hours",
  "matched_rule",
  "reason",
  "would_archive_to",
  "protected_reason"
)

function Get-RelativePath {
  param(
    [string]$BasePath,
    [string]$FullPath
  )

  $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
  $targetFull = [System.IO.Path]::GetFullPath($FullPath)

  if ($targetFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $targetFull.Substring($baseFull.Length).TrimStart('\', '/')
  }

  return $targetFull
}

function Convert-ToComparablePath {
  param([string]$Path)

  return $Path.Replace("/", "\").TrimStart('\').ToLowerInvariant()
}

function Test-PathLike {
  param(
    [string]$RelativePath,
    [string[]]$Patterns
  )

  $candidate = Convert-ToComparablePath $RelativePath

  foreach ($pattern in $Patterns) {
    $normalPattern = Convert-ToComparablePath $pattern
    if ($candidate -like $normalPattern) {
      return $true
    }
  }

  return $false
}

function Get-ArchiveDestination {
  param([string]$RelativePath)

  return Join-Path $proposedArchiveRootRel $RelativePath
}

function New-ManifestRow {
  param(
    [System.IO.FileInfo]$File,
    [string]$DecisionClass,
    [string]$MatchedRule,
    [string]$Reason,
    [string]$ProtectedReason = ""
  )

  $relativePath = Get-RelativePath -BasePath $rootPath -FullPath $File.FullName
  $ageHours = [math]::Round((New-TimeSpan -Start $File.LastWriteTime -End $now).TotalHours, 2)
  $archiveDestination = ""

  if ($DecisionClass -like "archive_candidate_*") {
    $archiveDestination = Get-ArchiveDestination -RelativePath $relativePath
  }

  return [pscustomobject]@{
    decision_class = $DecisionClass
    relative_path = $relativePath
    full_path = $File.FullName
    extension = $File.Extension.ToLowerInvariant()
    size_bytes = $File.Length
    last_write_time = $File.LastWriteTime.ToString("s")
    age_hours = $ageHours
    matched_rule = $MatchedRule
    reason = $Reason
    would_archive_to = $archiveDestination
    protected_reason = $ProtectedReason
  }
}

function Export-Manifest {
  param(
    [object[]]$Rows,
    [string]$Path
  )

  if ($Rows.Count -eq 0) {
    @() | Select-Object $manifestColumns | Export-Csv -Path $Path -NoTypeInformation
  } else {
    $Rows | Select-Object $manifestColumns | Export-Csv -Path $Path -NoTypeInformation
  }
}

$protectedPatterns = @(
  "Output\rasters\inundation_pre_post\*",
  "Output\rasters\inundation_pre_post.*",
  "Output\csv\04c_fractional_cover_full.csv",
  "Output\csv\05c_landsat_inundation_full.csv",
  "Output\csv\06c_daily_inundation_full.csv",
  "Output\csv\07f_pre_post_inundation_plot_summary_fixed.csv",
  "Output\csv\curated_ground_cover_timeseries.csv",
  "Output\csv\curated_annual_inundation_timeseries.csv",
  "Output\csv\curated_daily_inundation_monthly.csv",
  "Output\csv\plot_rs_analysis_base.csv"
)

$currentReviewPatterns = @(
  "Output\csv\10a_*",
  "Output\figures\10b_ground_cover_prepost_figures\*",
  "Output\diagnostics\10b_ground_cover_prepost_figures\*",
  "Output\csv\12_*",
  "Output\figures\12_lag_diagnostics\*",
  "Output\diagnostics\12_lag_diagnostics\*",
  "Output\reports\Adrian_review_current_results*\*",
  "Output\reports\Gayini_Adrian*review*.pptx",
  "Output\reports\Gayini_Adrian*review*.zip",
  "Output\reports\Gayini_Adrian*montage*.png",
  "Output\figures\Gayini_Adrian*review*.pptx",
  "Output\figures\Gayini_Adrian*review*.zip",
  "Output\figures\Gayini_Adrian*montage*.png"
)

$doNotTouchPatterns = @(
  "Output\archive\*",
  "Output\reports\archive_dry_run_*\*"
)

$oldTestOutputPatterns = @(
  "Output\csv\04a_*",
  "Output\csv\04b_*",
  "Output\csv\05a_*",
  "Output\csv\05b_*",
  "Output\csv\06a_*",
  "Output\csv\06b_*",
  "Output\figures\04a_*",
  "Output\figures\04b_*",
  "Output\figures\05a_*",
  "Output\figures\05b_*",
  "Output\figures\06a_*",
  "Output\figures\06b_*",
  "Output\diagnostics\04a_*\*",
  "Output\diagnostics\04b_*\*",
  "Output\diagnostics\05a_*\*",
  "Output\diagnostics\05b_*\*",
  "Output\diagnostics\06a_*\*",
  "Output\diagnostics\06b_*\*",
  "Output\csv\test_*",
  "Output\figures\test_*",
  "Output\diagnostics\test_*\*"
)

$obsoleteBundlePatterns = @(
  "Output\reports\*_for_review\*",
  "Output\figures\*_for_review\*",
  "Output\reports\*for_review*",
  "Output\reports\*.zip"
)

$scanRoots = New-Object System.Collections.Generic.List[string]

foreach ($folderRel in $scanFolderRels) {
  $folderPath = Join-Path $rootPath $folderRel
  if (Test-Path -LiteralPath $folderPath) {
    $scanRoots.Add($folderPath)
  }
}

$additionalFolderCandidates = Get-ChildItem -LiteralPath $rootPath -Directory -ErrorAction SilentlyContinue |
  Where-Object {
    $_.Name -like "Output_*extracted*" -or
    $_.Name -like "Output_*only_extracted*" -or
    $_.Name -like "*_for_review"
  }

foreach ($folder in $additionalFolderCandidates) {
  $scanRoots.Add($folder.FullName)
}

$allFiles = $scanRoots |
  ForEach-Object {
    Get-ChildItem -LiteralPath $_ -File -Recurse -ErrorAction SilentlyContinue
  } |
  Sort-Object FullName -Unique

$allRelativePaths = $allFiles | ForEach-Object { Get-RelativePath -BasePath $rootPath -FullPath $_.FullName }
$has07gV2OrV3 = ($allRelativePaths | Where-Object { $_ -match "(^|[\\/])07g_.*v[23]" }).Count -gt 0
$has07hV2OrV3 = ($allRelativePaths | Where-Object { $_ -match "(^|[\\/])07h_.*v[23]" }).Count -gt 0
$latestAdrianZip = $allFiles |
  Where-Object { $_.Name -like "Gayini_Adrian*review*.zip" } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

$inventoryRows = New-Object System.Collections.Generic.List[object]

foreach ($file in $allFiles) {
  $relativePath = Get-RelativePath -BasePath $rootPath -FullPath $file.FullName
  $comparablePath = Convert-ToComparablePath $relativePath
  $ageHours = (New-TimeSpan -Start $file.LastWriteTime -End $now).TotalHours
  $extension = $file.Extension.ToLowerInvariant()

  $decisionClass = "manual_review"
  $matchedRule = "manual_review_default"
  $reason = "No specific archive or keep rule matched; review manually."
  $protectedReason = ""

  if (Test-PathLike -RelativePath $relativePath -Patterns $doNotTouchPatterns) {
    $decisionClass = "do_not_touch"
    $matchedRule = "do_not_touch_archive_system"
    $reason = "Archive and dry-run report areas are not candidates in this planning pass."
  } elseif (Test-PathLike -RelativePath $relativePath -Patterns $protectedPatterns) {
    $decisionClass = "protected_keep"
    $matchedRule = "protected_canonical_current_output"
    $reason = "Canonical/current output explicitly protected regardless of age."
    $protectedReason = "Explicit canonical/current output protection."
  } elseif ($comparablePath -like "output\rasters\inundation_pre_post\*") {
    $decisionClass = "protected_keep"
    $matchedRule = "protected_pre_post_inundation_raster_folder"
    $reason = "All pre/post inundation rasters and diagnostics are protected regardless of age."
    $protectedReason = "Pre/post inundation raster folder protection."
  } elseif (Test-PathLike -RelativePath $relativePath -Patterns $currentReviewPatterns) {
    $decisionClass = "current_review_keep"
    $matchedRule = "current_review_output"
    $reason = "Current Step 10/12 or Adrian review output retained for active review."
    $protectedReason = "Current review output."
  } elseif ($latestAdrianZip -and $file.FullName -eq $latestAdrianZip.FullName) {
    $decisionClass = "current_review_keep"
    $matchedRule = "latest_adrian_review_zip"
    $reason = "Latest Adrian review zip retained as current review package."
    $protectedReason = "Latest Adrian review package."
  } elseif ($extension -in @(".tif", ".tiff")) {
    $decisionClass = "manual_review"
    $matchedRule = "manual_review_raster"
    $reason = "Raster file outside the protected pre/post folder; requires manual review and is not an archive candidate."
  } elseif (Test-PathLike -RelativePath $relativePath -Patterns $oldTestOutputPatterns) {
    $decisionClass = "archive_candidate_obsolete_pattern"
    $matchedRule = "old_test_output_prefix"
    $reason = "Old test/dev output prefix matched 04a/04b/05a/05b/06a/06b/test pattern."
  } elseif ($has07gV2OrV3 -and $file.Name -like "07g_*" -and $file.Name -notlike "*v2*" -and $file.Name -notlike "*v3*") {
    $decisionClass = "archive_candidate_superseded"
    $matchedRule = "superseded_07g_non_v2_v3"
    $reason = "Older 07g output appears superseded by v2/v3 outputs."
  } elseif ($has07hV2OrV3 -and $file.Name -like "07h_*" -and $file.Name -notlike "*v2*" -and $file.Name -notlike "*v3*") {
    $decisionClass = "archive_candidate_superseded"
    $matchedRule = "superseded_07h_non_v2_v3"
    $reason = "Older 07h output appears superseded by v2/v3 outputs."
  } elseif (Test-PathLike -RelativePath $relativePath -Patterns $obsoleteBundlePatterns) {
    $decisionClass = "archive_candidate_obsolete_pattern"
    $matchedRule = "obsolete_review_bundle_pattern"
    $reason = "Stale review bundle or for_review pattern matched."
  } elseif ($ageHours -gt $OlderThanHours) {
    $decisionClass = "archive_candidate_age"
    $matchedRule = "older_than_threshold"
    $reason = "Older than the configured threshold and not protected/current; age is a heuristic for dry-run review only."
  }

  $inventoryRows.Add((New-ManifestRow -File $file -DecisionClass $decisionClass -MatchedRule $matchedRule -Reason $reason -ProtectedReason $protectedReason))
}

$protectedRows = $inventoryRows | Where-Object { $_.decision_class -eq "protected_keep" }
$currentReviewRows = $inventoryRows | Where-Object { $_.decision_class -eq "current_review_keep" }
$archiveCandidateRows = $inventoryRows | Where-Object { $_.decision_class -like "archive_candidate_*" }
$manualReviewRows = $inventoryRows | Where-Object { $_.decision_class -eq "manual_review" }

$candidatePathSet = @{}
foreach ($row in $archiveCandidateRows) {
  $candidatePathSet[$row.full_path.ToLowerInvariant()] = $true
}

$obsoleteFolderRows = New-Object System.Collections.Generic.List[object]
$candidateFolders = $allFiles |
  ForEach-Object { $_.Directory.FullName } |
  Sort-Object -Unique

foreach ($folderPath in $candidateFolders) {
  if ($folderPath -eq $rootPath) {
    continue
  }

  $folderFiles = Get-ChildItem -LiteralPath $folderPath -File -Recurse -ErrorAction SilentlyContinue

  if ($folderFiles.Count -eq 0) {
    continue
  }

  $candidateCount = 0
  foreach ($folderFile in $folderFiles) {
    if ($candidatePathSet.ContainsKey($folderFile.FullName.ToLowerInvariant())) {
      $candidateCount += 1
    }
  }

  if ($candidateCount -eq $folderFiles.Count) {
    $relativeFolder = Get-RelativePath -BasePath $rootPath -FullPath $folderPath
    $obsoleteFolderRows.Add([pscustomobject]@{
      decision_class = "archive_candidate_obsolete_pattern"
      relative_path = $relativeFolder
      full_path = $folderPath
      file_count = $folderFiles.Count
      total_size_bytes = ($folderFiles | Measure-Object -Property Length -Sum).Sum
      matched_rule = "folder_contains_only_archive_candidates"
      reason = "Folder contains only files classified as archive candidates in this dry run."
      would_archive_to = Join-Path $proposedArchiveRootRel $relativeFolder
    })
  }
}

New-Item -ItemType Directory -Force -Path $dryRunDir | Out-Null

$allInventoryPath = Join-Path $dryRunDir "all_output_files_inventory.csv"
$protectedManifestPath = Join-Path $dryRunDir "protected_keep_manifest.csv"
$currentReviewManifestPath = Join-Path $dryRunDir "current_review_manifest.csv"
$archiveCandidateManifestPath = Join-Path $dryRunDir "archive_candidate_manifest.csv"
$obsoleteFolderManifestPath = Join-Path $dryRunDir "obsolete_folder_candidate_manifest.csv"
$summaryPath = Join-Path $dryRunDir "archive_decision_summary.md"

Export-Manifest -Rows $inventoryRows -Path $allInventoryPath
Export-Manifest -Rows $protectedRows -Path $protectedManifestPath
Export-Manifest -Rows $currentReviewRows -Path $currentReviewManifestPath
Export-Manifest -Rows $archiveCandidateRows -Path $archiveCandidateManifestPath
$obsoleteFolderRows | Export-Csv -Path $obsoleteFolderManifestPath -NoTypeInformation

$totalCount = $inventoryRows.Count
$protectedCount = $protectedRows.Count
$currentReviewCount = $currentReviewRows.Count
$archiveCandidateCount = $archiveCandidateRows.Count
$manualReviewCount = $manualReviewRows.Count
$obsoleteFolderCount = $obsoleteFolderRows.Count

$protectedRasterArchiveRows = $archiveCandidateRows |
  Where-Object { (Convert-ToComparablePath $_.relative_path) -like "output\rasters\inundation_pre_post\*" }
$protectedPrePostRasterRows = $inventoryRows |
  Where-Object {
    (Convert-ToComparablePath $_.relative_path) -like "output\rasters\inundation_pre_post\*" -and
    $_.decision_class -like "archive_candidate_*"
  }
$tifArchiveRows = $archiveCandidateRows |
  Where-Object { $_.extension -in @(".tif", ".tiff") }
$archiveFraction = if ($totalCount -gt 0) { $archiveCandidateCount / $totalCount } else { 0 }

$safetyMessages = New-Object System.Collections.Generic.List[string]

if ($protectedRasterArchiveRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Protected pre/post raster files were classified as archive candidates.")
}

if ($protectedPrePostRasterRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Files inside Output/rasters/inundation_pre_post were classified as archive candidates.")
}

if ($tifArchiveRows.Count -gt 0) {
  $safetyMessages.Add("STOP: archive_candidate_manifest.csv contains .tif/.tiff files.")
}

if ($archiveFraction -gt 0.8) {
  $safetyMessages.Add("STOP: More than 80% of scanned files were classified as archive candidates.")
}

$topArchiveCandidates = $archiveCandidateRows |
  Sort-Object {[int64]$_.size_bytes} -Descending |
  Select-Object -First 20

$generatedTime = $now.ToString("s")
$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# Output Archive Dry-Run Summary")
$summaryLines.Add("")
$summaryLines.Add("Generated: $generatedTime")
$summaryLines.Add("")
$summaryLines.Add("## Scope")
$summaryLines.Add("")
$summaryLines.Add("- Dry run only. No files were moved, deleted, renamed, compressed, or archived.")
$summaryLines.Add("- Proposed archive destination, not created: ``$proposedArchiveRootRel``")
$summaryLines.Add("- Older-than threshold: $OlderThanHours hours")
$summaryLines.Add("")
$summaryLines.Add("## Counts")
$summaryLines.Add("")
$summaryLines.Add("- Total files scanned: $totalCount")
$summaryLines.Add("- Protected files: $protectedCount")
$summaryLines.Add("- Current review files: $currentReviewCount")
$summaryLines.Add("- Archive candidates: $archiveCandidateCount")
$summaryLines.Add("- Manual-review files: $manualReviewCount")
$summaryLines.Add("- Obsolete folder candidates: $obsoleteFolderCount")
$summaryLines.Add("")
$summaryLines.Add("## Safety Checks")
$summaryLines.Add("")

if ($safetyMessages.Count -eq 0) {
  $summaryLines.Add("- PASS: No safety stops triggered.")
} else {
  foreach ($message in $safetyMessages) {
    $summaryLines.Add("- $message")
  }
}

$summaryLines.Add("")
$summaryLines.Add("## Pre/Post Raster Check")
$summaryLines.Add("")
$summaryLines.Add("- Pre/post raster files incorrectly flagged as archive candidates: $($protectedRasterArchiveRows.Count)")
$summaryLines.Add("- Files inside Output/rasters/inundation_pre_post flagged as archive candidates: $($protectedPrePostRasterRows.Count)")
$summaryLines.Add("- .tif/.tiff archive candidates: $($tifArchiveRows.Count)")
$summaryLines.Add("")
$summaryLines.Add("## Top 20 Largest Archive Candidates")
$summaryLines.Add("")

if ($topArchiveCandidates.Count -eq 0) {
  $summaryLines.Add("- None")
} else {
  $summaryLines.Add("| Size bytes | Decision | Relative path | Reason |")
  $summaryLines.Add("|---:|---|---|---|")
  foreach ($row in $topArchiveCandidates) {
    $summaryLines.Add(('| {0} | {1} | `{2}` | {3} |' -f $row.size_bytes, $row.decision_class, $row.relative_path, $row.reason))
  }
}

$summaryLines.Add("")
$summaryLines.Add("## Reports")
$summaryLines.Add("")
$summaryLines.Add("- ``$allInventoryPath``")
$summaryLines.Add("- ``$protectedManifestPath``")
$summaryLines.Add("- ``$currentReviewManifestPath``")
$summaryLines.Add("- ``$archiveCandidateManifestPath``")
$summaryLines.Add("- ``$obsoleteFolderManifestPath``")

$summaryLines | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "Dry-run archive reports written to: $dryRunDir"
Write-Host "Total files scanned: $totalCount"
Write-Host "Protected files: $protectedCount"
Write-Host "Current review files: $currentReviewCount"
Write-Host "Archive candidates: $archiveCandidateCount"
Write-Host "Manual-review files: $manualReviewCount"
Write-Host "Obsolete folder candidates: $obsoleteFolderCount"
Write-Host "Pre/post raster files incorrectly flagged: $($protectedRasterArchiveRows.Count)"

if ($safetyMessages.Count -gt 0) {
  throw ($safetyMessages -join " ")
}
