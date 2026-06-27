<#
.SYNOPSIS
  Apply Phase 1 of the pre-Adrian-review Output archive plan.

.DESCRIPTION
  Moves only the conservative Phase 1 subset selected from a prior dry-run
  archive plan. Files are moved into Output/archive with their relative folder
  structure preserved. No files are deleted; only source folders that become
  completely empty after moves are removed.
#>

param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")),
  [string]$DryRunReportDir = "Output\reports\archive_dry_run_20260616_131036",
  [string]$ArchiveDestination = "Output\archive\pre_adrian_review_20260616_131036"
)

$ErrorActionPreference = "Stop"

$rootPath = [System.IO.Path]::GetFullPath((Resolve-Path $Root)).TrimEnd('\', '/')
$dryRunDir = Join-Path $rootPath $DryRunReportDir
$archiveRoot = Join-Path $rootPath $ArchiveDestination
$appliedManifestPath = Join-Path $archiveRoot "archive_applied_manifest.csv"
$selectedBeforeManifestPath = Join-Path $archiveRoot "archive_selected_manifest_before_move.csv"
$archiveSummaryPath = Join-Path $archiveRoot "archive_applied_summary.md"
$dryRunSummaryPath = Join-Path $dryRunDir "archive_phase1_applied_summary.md"
$appliedAt = Get-Date

$archiveCandidatePath = Join-Path $dryRunDir "archive_candidate_manifest.csv"
$protectedKeepPath = Join-Path $dryRunDir "protected_keep_manifest.csv"
$currentReviewPath = Join-Path $dryRunDir "current_review_manifest.csv"
$obsoleteFolderPath = Join-Path $dryRunDir "obsolete_folder_candidate_manifest.csv"
$allInventoryPath = Join-Path $dryRunDir "all_output_files_inventory.csv"

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

function Test-IsInsideFolder {
  param(
    [string]$RelativePath,
    [string[]]$FolderRelativePaths
  )

  $candidate = Convert-ToComparablePath $RelativePath

  foreach ($folder in $FolderRelativePaths) {
    $folderComparable = (Convert-ToComparablePath $folder).TrimEnd('\')

    if ($candidate -eq $folderComparable -or $candidate.StartsWith($folderComparable + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

function New-PathSet {
  param([object[]]$Rows)

  $pathSet = @{}

  foreach ($row in $Rows) {
    if ($row.relative_path) {
      $pathSet[(Convert-ToComparablePath $row.relative_path)] = $true
    }
  }

  return $pathSet
}

foreach ($requiredPath in @($archiveCandidatePath, $protectedKeepPath, $currentReviewPath, $obsoleteFolderPath, $allInventoryPath)) {
  if (-not (Test-Path -LiteralPath $requiredPath)) {
    throw "Required dry-run manifest not found: $requiredPath"
  }
}

$archiveCandidates = @(Import-Csv -LiteralPath $archiveCandidatePath)
$protectedRows = @(Import-Csv -LiteralPath $protectedKeepPath)
$currentReviewRows = @(Import-Csv -LiteralPath $currentReviewPath)
$obsoleteFolderRows = @(Import-Csv -LiteralPath $obsoleteFolderPath)
$allInventoryRows = @(Import-Csv -LiteralPath $allInventoryPath)

$protectedPathSet = New-PathSet -Rows $protectedRows
$currentReviewPathSet = New-PathSet -Rows $currentReviewRows
$obsoleteFolderPaths = @($obsoleteFolderRows | ForEach-Object { $_.relative_path })

$selectedRows = New-Object System.Collections.Generic.List[object]

foreach ($row in $archiveCandidates) {
  $isPhase1Class = $row.decision_class -in @("archive_candidate_obsolete_pattern", "archive_candidate_superseded")
  $isAgeInsideObsoleteFolder = $row.decision_class -eq "archive_candidate_age" -and
    (Test-IsInsideFolder -RelativePath $row.relative_path -FolderRelativePaths $obsoleteFolderPaths)

  if ($isPhase1Class -or $isAgeInsideObsoleteFolder) {
    $selectedRows.Add($row)
  }
}

$selectedCount = $selectedRows.Count
$selectedSizeBytes = ($selectedRows | Measure-Object -Property size_bytes -Sum).Sum
if ($null -eq $selectedSizeBytes) {
  $selectedSizeBytes = 0
}

$safetyMessages = New-Object System.Collections.Generic.List[string]

if ($selectedCount -eq 0) {
  $safetyMessages.Add("STOP: Phase 1 selected archive list is empty.")
}

$selectedPrePostFolderRows = @($selectedRows | Where-Object { (Convert-ToComparablePath $_.relative_path) -like "output\rasters\inundation_pre_post\*" })
$selectedPrePostBundleRows = @($selectedRows | Where-Object { (Convert-ToComparablePath $_.relative_path) -eq "output\rasters\inundation_pre_post.7z" })
$selectedTifRows = @($selectedRows | Where-Object { $_.extension -in @(".tif", ".tiff") })
$selectedProtectedRows = @($selectedRows | Where-Object { $protectedPathSet.ContainsKey((Convert-ToComparablePath $_.relative_path)) })
$selectedCurrentReviewRows = @($selectedRows | Where-Object { $currentReviewPathSet.ContainsKey((Convert-ToComparablePath $_.relative_path)) })
$selectedMissingRows = @($selectedRows | Where-Object { -not (Test-Path -LiteralPath (Join-Path $rootPath $_.relative_path)) })
$selectedFraction = if ($allInventoryRows.Count -gt 0) { $selectedCount / $allInventoryRows.Count } else { 1 }

if ($selectedPrePostFolderRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected files include files inside Output/rasters/inundation_pre_post/.")
}

if ($selectedPrePostBundleRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected files include Output/rasters/inundation_pre_post.7z.")
}

if ($selectedTifRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected files include .tif/.tiff files.")
}

if ($selectedProtectedRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected files include protected_keep_manifest.csv entries.")
}

if ($selectedCurrentReviewRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected files include current_review_manifest.csv entries.")
}

if ($selectedFraction -gt 0.7) {
  $safetyMessages.Add("STOP: Selected files exceed 70% of all scanned files.")
}

if ($selectedMissingRows.Count -gt 0) {
  $safetyMessages.Add("STOP: Selected source files are missing before move.")
}

New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null

$selectedBeforeRows = @(
  $selectedRows | ForEach-Object {
    $sourcePath = Join-Path $rootPath $_.relative_path
    $destinationPath = Join-Path $archiveRoot $_.relative_path

    [pscustomobject]@{
      phase = "phase1_before_move"
      decision_class = $_.decision_class
      relative_path = $_.relative_path
      source_path = $sourcePath
      destination_path = $destinationPath
      extension = $_.extension
      size_bytes = $_.size_bytes
      matched_rule = $_.matched_rule
      reason = $_.reason
      source_exists_before = Test-Path -LiteralPath $sourcePath
      destination_exists_before = Test-Path -LiteralPath $destinationPath
      applied_at = $appliedAt.ToString("s")
    }
  }
)

$selectedBeforeRows | Export-Csv -Path $selectedBeforeManifestPath -NoTypeInformation

Write-Host "Selected Phase 1 files: $selectedCount"
Write-Host "Selected Phase 1 total size bytes: $selectedSizeBytes"
Write-Host "Archive destination: $archiveRoot"
Write-Host "Protected manifest entries checked: $($protectedRows.Count)"
Write-Host "Current-review manifest entries checked: $($currentReviewRows.Count)"

if ($safetyMessages.Count -gt 0) {
  throw ($safetyMessages -join " ")
}

$moveResults = New-Object System.Collections.Generic.List[object]
$sourceDirectories = New-Object System.Collections.Generic.List[string]

foreach ($row in $selectedRows) {
  $sourcePath = Join-Path $rootPath $row.relative_path
  $destinationPath = Join-Path $archiveRoot $row.relative_path
  $destinationParent = Split-Path -Parent $destinationPath
  $sourceParent = Split-Path -Parent $sourcePath
  $moveStatus = "moved"
  $errorMessage = ""

  try {
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null

    if (Test-Path -LiteralPath $destinationPath) {
      throw "Destination already exists: $destinationPath"
    }

    Move-Item -LiteralPath $sourcePath -Destination $destinationPath
    $sourceDirectories.Add($sourceParent)
  } catch {
    $moveStatus = "error"
    $errorMessage = $_.Exception.Message
  }

  $moveResults.Add([pscustomobject]@{
    phase = "phase1_after_move"
    decision_class = $row.decision_class
    relative_path = $row.relative_path
    source_path = $sourcePath
    destination_path = $destinationPath
    extension = $row.extension
    size_bytes = $row.size_bytes
    matched_rule = $row.matched_rule
    reason = $row.reason
    move_status = $moveStatus
    error_message = $errorMessage
    source_exists_after = Test-Path -LiteralPath $sourcePath
    destination_exists_after = Test-Path -LiteralPath $destinationPath
    applied_at = $appliedAt.ToString("s")
  })
}

$moveErrorRows = @($moveResults | Where-Object { $_.move_status -ne "moved" })

if ($moveErrorRows.Count -gt 0) {
  $moveResults | Export-Csv -Path $appliedManifestPath -NoTypeInformation
  throw "One or more files failed to move. See $appliedManifestPath"
}

$foldersRemoved = New-Object System.Collections.Generic.List[object]
$uniqueSourceDirectories = $sourceDirectories |
  Sort-Object -Unique |
  Sort-Object { $_.Length } -Descending

foreach ($folder in $uniqueSourceDirectories) {
  if (-not (Test-Path -LiteralPath $folder)) {
    continue
  }

  $remainingItems = @(Get-ChildItem -LiteralPath $folder -Force -ErrorAction SilentlyContinue)

  if ($remainingItems.Count -eq 0) {
    $relativeFolder = Get-RelativePath -BasePath $rootPath -FullPath $folder
    Remove-Item -LiteralPath $folder -Force
    $foldersRemoved.Add([pscustomobject]@{
      relative_path = $relativeFolder
      full_path = $folder
      reason = "Source folder was completely empty after Phase 1 moves."
      removed_at = (Get-Date).ToString("s")
    })
  }
}

$moveResults | Export-Csv -Path $appliedManifestPath -NoTypeInformation

$movedCount = @($moveResults | Where-Object { $_.move_status -eq "moved" }).Count
$movedSizeBytes = ($moveResults | Where-Object { $_.move_status -eq "moved" } | Measure-Object -Property size_bytes -Sum).Sum
if ($null -eq $movedSizeBytes) {
  $movedSizeBytes = 0
}

$selectedPrePostMovedCount = @($moveResults | Where-Object {
  $_.move_status -eq "moved" -and
  ((Convert-ToComparablePath $_.relative_path) -like "output\rasters\inundation_pre_post\*" -or
   (Convert-ToComparablePath $_.relative_path) -eq "output\rasters\inundation_pre_post.7z")
}).Count

$selectedTifMovedCount = @($moveResults | Where-Object {
  $_.move_status -eq "moved" -and $_.extension -in @(".tif", ".tiff")
}).Count

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add("# Phase 1 Output Archive Applied Summary")
$summaryLines.Add("")
$summaryLines.Add("Applied: $($appliedAt.ToString("s"))")
$summaryLines.Add("")
$summaryLines.Add("## Scope")
$summaryLines.Add("")
$summaryLines.Add("- Source dry-run folder: ``$DryRunReportDir``")
$summaryLines.Add("- Archive destination: ``$ArchiveDestination``")
$summaryLines.Add("- Phase 1 moved obsolete-pattern candidates, superseded candidates, and age candidates only when inside obsolete-folder candidates.")
$summaryLines.Add("- No files were deleted. Empty source folders only were removed after moves.")
$summaryLines.Add("")
$summaryLines.Add("## Counts")
$summaryLines.Add("")
$summaryLines.Add("- Selected files before move: $selectedCount")
$summaryLines.Add("- Files moved: $movedCount")
$summaryLines.Add("- Total size moved bytes: $movedSizeBytes")
$summaryLines.Add("- Empty source folders removed: $($foldersRemoved.Count)")
$summaryLines.Add("- Protected files checked: $($protectedRows.Count)")
$summaryLines.Add("- Current-review files checked: $($currentReviewRows.Count)")
$summaryLines.Add("")
$summaryLines.Add("## Safety Checks")
$summaryLines.Add("")
$summaryLines.Add("- Pre/post raster files selected: $($selectedPrePostFolderRows.Count + $selectedPrePostBundleRows.Count)")
$summaryLines.Add("- Pre/post raster files moved: $selectedPrePostMovedCount")
$summaryLines.Add("- .tif/.tiff files selected: $($selectedTifRows.Count)")
$summaryLines.Add("- .tif/.tiff files moved: $selectedTifMovedCount")
$summaryLines.Add("- Protected files selected: $($selectedProtectedRows.Count)")
$summaryLines.Add("- Current-review files selected: $($selectedCurrentReviewRows.Count)")
$summaryLines.Add("- Selected share of scanned files: $([math]::Round($selectedFraction * 100, 2))%")
$summaryLines.Add("")
$summaryLines.Add("## Empty Folders Removed")
$summaryLines.Add("")

if ($foldersRemoved.Count -eq 0) {
  $summaryLines.Add("- None")
} else {
  foreach ($folderRow in $foldersRemoved) {
    $summaryLines.Add("- ``$($folderRow.relative_path)``")
  }
}

$summaryLines.Add("")
$summaryLines.Add("## Manifests")
$summaryLines.Add("")
$summaryLines.Add("- Before move: ``$selectedBeforeManifestPath``")
$summaryLines.Add("- After move: ``$appliedManifestPath``")

$summaryLines | Set-Content -Path $archiveSummaryPath -Encoding UTF8
$summaryLines | Set-Content -Path $dryRunSummaryPath -Encoding UTF8

Write-Host "Files moved: $movedCount"
Write-Host "Total size moved bytes: $movedSizeBytes"
Write-Host "Empty source folders removed: $($foldersRemoved.Count)"
Write-Host "Applied manifest: $appliedManifestPath"
Write-Host "Archive summary: $archiveSummaryPath"
Write-Host "Dry-run folder summary: $dryRunSummaryPath"
