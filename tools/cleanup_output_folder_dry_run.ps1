param(
  [string]$Root = (Resolve-Path ".").Path,
  [switch]$Execute
)

$ErrorActionPreference = "Stop"

$candidatePath = Join-Path $Root "Output/reports/output_audit/output_cleanup_candidates.csv"
$reportDir = Join-Path $Root "Output/reports/output_audit"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

if (-not (Test-Path $candidatePath)) {
  throw "Missing cleanup candidates file. Run tools/audit_output_folder.ps1 first: $candidatePath"
}

$candidates = Import-Csv -Path $candidatePath
$actions = foreach ($row in $candidates) {
  $action = switch -Regex ($row.recommended_action) {
    "delete_safe" { "would_delete_after_final_confirmation"; break }
    "delete_after_review" { "would_delete_after_manual_review"; break }
    "move_to_local_archive" { "would_move_to_output_archive_after_review"; break }
    "replace_with_latest" { "would_replace_with_latest_after_review"; break }
    default { "would_not_modify" }
  }

  [pscustomobject]@{
    path                     = $row.path
    classification           = $row.classification
    recommended_action       = $row.recommended_action
    dry_run_action           = $action
    risk_level               = $row.risk_level
    manual_review_required   = $row.manual_review_required
    execute_requested        = [bool]$Execute
    executed                 = $false
    notes                    = "Default dry-run mode never deletes or moves files."
  }
}

$actionsPath = Join-Path $reportDir "output_cleanup_dry_run_actions.csv"
$actions | Export-Csv -NoTypeInformation -Path $actionsPath

$countsByAction = $actions | Group-Object dry_run_action | Sort-Object Name
$countsByRisk = $actions | Group-Object risk_level | Sort-Object Name

$report = @()
$report += "# Output Cleanup Dry Run Report"
$report += ""
$report += "Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")"
$report += ""
$report += "- Execute flag supplied: $([bool]$Execute)"
$report += "- Candidate rows: $($actions.Count)"
$report += "- Actions CSV: Output/reports/output_audit/output_cleanup_dry_run_actions.csv"
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
$report += "## Safety"
$report += ""
if ($Execute) {
  $report += "The `-Execute` flag was supplied, but this Stage 6 helper intentionally records planned actions only. A future approved cleanup task should implement execution after manual review."
} else {
  $report += "Dry-run only. No files were deleted, moved, or modified."
}

$report | Set-Content -Encoding UTF8 -Path (Join-Path $reportDir "output_cleanup_dry_run_report.md")

