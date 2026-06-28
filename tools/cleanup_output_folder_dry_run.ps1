param(
  [string]$Root = (Resolve-Path ".").Path,
  [string]$ArchiveName = "",
  [switch]$Execute
)

$ErrorActionPreference = "Stop"

function ConvertTo-RepoPath {
  param([string]$Path)
  return ($Path -replace "\\", "/").TrimStart("./")
}

$candidatePath = Join-Path $Root "Output/reports/output_audit/output_cleanup_candidates.csv"
$handoffPath = Join-Path $Root "Output/reports/output_audit/current_handoff_output_set.csv"
$referencePath = Join-Path $Root "Output/reports/output_audit/output_reference_index.csv"
$reportDir = Join-Path $Root "Output/reports/output_audit"
$outputRoot = Join-Path $Root "Output"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

if (-not (Test-Path $candidatePath)) {
  throw "Missing cleanup candidates file. Run tools/audit_output_folder.ps1 first: $candidatePath"
}
if (-not (Test-Path $handoffPath)) {
  throw "Missing current handoff set file. Run tools/audit_output_folder.ps1 first: $handoffPath"
}
if (-not (Test-Path $referencePath)) {
  throw "Missing output reference index file. Run tools/audit_output_folder.ps1 first: $referencePath"
}

if ([string]::IsNullOrWhiteSpace($ArchiveName)) {
  $ArchiveName = "stage7_output_cleanup_$(Get-Date -Format "yyyyMMdd_HHmmss")"
}

$archiveRoot = Join-Path $outputRoot "_archive/$ArchiveName"

$candidates = Import-Csv -Path $candidatePath
$handoff = Import-Csv -Path $handoffPath
$references = Import-Csv -Path $referencePath

$handoffSet = @{}
foreach ($row in $handoff) {
  $handoffSet[$row.path.ToLowerInvariant()] = $true
}

$activeReferenceTypes = @(
  "script_input",
  "script_output",
  "doc_reference",
  "run_order_reference",
  "test_reference",
  "spine_check_reference"
)
$activeReferenceSet = @{}
foreach ($row in $references) {
  if ($activeReferenceTypes -contains $row.reference_type -and $row.reference_status -eq "exists") {
    $activeReferenceSet[$row.output_path.ToLowerInvariant()] = $true
  }
}

$actions = foreach ($row in $candidates) {
  $normalizedPath = ($row.path -replace "\\", "/")
  $key = $normalizedPath.ToLowerInvariant()
  $sourcePath = Join-Path $Root $normalizedPath
  $relativeUnderOutput = if ($normalizedPath -match "^Output/") { $normalizedPath.Substring(7) } else { $normalizedPath }
  $destinationPath = Join-Path $archiveRoot $relativeUnderOutput
  $eligibleForArchive = (
    $row.recommended_action -eq "move_to_local_archive" -and
    $row.manual_review_required -eq "False" -and
    $row.risk_level -ne "high" -and
    -not $handoffSet.ContainsKey($key) -and
    -not $activeReferenceSet.ContainsKey($key) -and
    $normalizedPath -match "^Output/" -and
    $normalizedPath -notmatch "^Output/_archive/"
  )

  $dryRunAction = switch -Regex ($row.recommended_action) {
    "delete_safe" { "would_not_modify_delete_not_allowed"; break }
    "delete_after_review" { "would_not_modify_delete_not_allowed"; break }
    "move_to_local_archive" {
      if ($eligibleForArchive) { "would_move_to_output_archive_after_review" } else { "would_not_modify_guardrail" }
      break
    }
    "replace_with_latest" { "would_not_modify_replace_not_allowed"; break }
    default { "would_not_modify" }
  }

  $executed = $false
  $executionStatus = "dry_run_only"
  $notes = "Dry-run mode never deletes or moves files."

  if ($Execute) {
    $notes = "Execute mode only moves eligible archive candidates; it never deletes files."
    if ($eligibleForArchive) {
      $resolvedSource = Resolve-Path -LiteralPath $sourcePath -ErrorAction SilentlyContinue
      if ($null -eq $resolvedSource) {
        $executionStatus = "source_missing"
      } else {
        $resolvedSourcePath = $resolvedSource.Path
        $resolvedOutputRoot = (Resolve-Path -LiteralPath $outputRoot).Path
        if (-not $resolvedSourcePath.StartsWith($resolvedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
          $executionStatus = "blocked_outside_output_root"
        } elseif (Test-Path -LiteralPath $destinationPath) {
          $executionStatus = "blocked_destination_exists"
        } else {
          New-Item -ItemType Directory -Force -Path (Split-Path $destinationPath -Parent) | Out-Null
          Move-Item -LiteralPath $resolvedSourcePath -Destination $destinationPath
          $executed = $true
          $executionStatus = "moved_to_output_archive"
        }
      }
    } else {
      $executionStatus = "not_eligible_guardrail"
    }
  }

  [pscustomobject]@{
    path                     = $row.path
    classification           = $row.classification
    recommended_action       = $row.recommended_action
    dry_run_action           = $dryRunAction
    risk_level               = $row.risk_level
    manual_review_required   = $row.manual_review_required
    in_current_handoff_set    = $handoffSet.ContainsKey($key)
    referenced_by_active_repo = $activeReferenceSet.ContainsKey($key)
    archive_destination       = ConvertTo-RepoPath ($destinationPath.Substring($Root.Length).TrimStart("\", "/"))
    execute_requested        = [bool]$Execute
    executed                 = $executed
    execution_status         = $executionStatus
    notes                    = $notes
  }
}

$actionsPath = Join-Path $reportDir "output_cleanup_dry_run_actions.csv"
$actions | Export-Csv -NoTypeInformation -Path $actionsPath
$executionPath = Join-Path $reportDir "output_cleanup_execution_actions.csv"
if ($Execute) {
  $actions | Export-Csv -NoTypeInformation -Path $executionPath
}

$countsByAction = $actions | Group-Object dry_run_action | Sort-Object Name
$countsByRisk = $actions | Group-Object risk_level | Sort-Object Name
$countsByExecutionStatus = $actions | Group-Object execution_status | Sort-Object Name

$report = @()
$report += $(if ($Execute) { "# Output Cleanup Execution Report" } else { "# Output Cleanup Dry Run Report" })
$report += ""
$report += "Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")"
$report += ""
$report += "- Execute flag supplied: $([bool]$Execute)"
$report += "- Candidate rows: $($actions.Count)"
$report += "- Archive root: $(ConvertTo-RepoPath ($archiveRoot.Substring($Root.Length).TrimStart("\", "/")))"
$report += "- Actions CSV: Output/reports/output_audit/output_cleanup_dry_run_actions.csv"
if ($Execute) {
  $report += "- Execution actions CSV: Output/reports/output_audit/output_cleanup_execution_actions.csv"
}
$report += ""
$report += "## Counts by dry-run action"
$report += ""
foreach ($g in $countsByAction) {
  $report += "- $($g.Name): $($g.Count)"
}
$report += ""
$report += "## Counts by risk"
$report += ""
foreach ($g in $countsByRisk) {
  $report += "- $($g.Name): $($g.Count)"
}
$report += ""
$report += "## Counts by execution status"
$report += ""
foreach ($g in $countsByExecutionStatus) {
  $report += "- $($g.Name): $($g.Count)"
}
$report += ""
$report += "## Safety"
$report += ""
if ($Execute) {
  $report += "Execute mode moved eligible archive candidates only. No files were deleted. Manual-review, high-risk, current-handoff, and active-reference rows were left in place."
} else {
  $report += "Dry-run only. No files were deleted, moved, or modified."
}

if ($Execute) {
  $report | Set-Content -Encoding UTF8 -Path (Join-Path $reportDir "output_cleanup_execution_report.md")
} else {
  $report | Set-Content -Encoding UTF8 -Path (Join-Path $reportDir "output_cleanup_dry_run_report.md")
}
