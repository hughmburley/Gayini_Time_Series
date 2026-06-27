param(
  [string]$Root = "D:\Github_repos\Gayini"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageRoot = Join-Path $Root "Output\packages"
$packageName = "Gayini_task9_standalone_mer_package_outputs_$timestamp"
$stagingDir = Join-Path $packageRoot $packageName
$zipPath = Join-Path $packageRoot "$packageName.zip"
$manifestPath = Join-Path $packageRoot "$packageName`_manifest.csv"

New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null
New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$relativeFiles = @(
  "scripts\22_build_mer_standalone_package_tables.R",
  "scripts\23_create_mer_methods_note.py",
  "scripts\package_latest_task9_mer_package_outputs.ps1",
  "Output\reports\MER\Gayini_MER_analysis_review_deck.pptx",
  "Output\reports\MER\Gayini_MER_methods_and_interpretation_note.docx",
  "Output\reports\MER\Gayini_MER_analysis_workbook.xlsx",
  "Output\reports\MER\task_9_mer_package_handoff.md",
  "Output\reports\Gayini_ppt_asset_register.csv",
  "Output\csv\MER\mer_vs_annual_occurrence_agreement_summary.csv",
  "Output\csv\MER\mer_vs_annual_occurrence_plot_review_flags.csv",
  "Output\csv\MER\mer_metric_definitions.csv",
  "Output\csv\MER\mer_input_files_inventory.csv",
  "Output\csv\MER\mer_output_files_inventory.csv",
  "Output\csv\MER\mer_recommended_figures.csv",
  "Output\csv\MER\mer_adrian_questions.csv",
  "Output\csv\MER\mer_keep_defer_archive_decisions.csv",
  "Output\figures\review\MER\mer_vs_annual_occurrence_main_deck_comparison.png",
  "Output\figures\review\MER\mer_metric_summary_main_deck.png",
  "Output\figures\review\MER\mer_metric_keep_defer_summary_review.png",
  "Output\figures\review\MER\mer_observation_support_sensor_note_appendix.png",
  "Output\figures\review\MER\mer_annual_max_heatmap_appendix.png",
  "Output\diagnostics\22_mer_standalone_package\task9_mer_package_table_checks.csv",
  "Output\diagnostics\22_mer_standalone_package\task9_mer_figure_copy_log.csv",
  "Output\diagnostics\22_mer_standalone_package\task9_mer_asset_pack_copy_log.csv",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-deck-slide-01-fixed.png",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-deck-slide-03.png",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-deck-slide-08.png",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-deck-slide-13.png",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-workbook-readme-preview.png",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-deck-inspect.ndjson",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-workbook-inspect.ndjson",
  "Output\diagnostics\22_mer_standalone_package\office_qa\mer-workbook-error-scan.ndjson"
)

$assetPackFiles = @()
$copyLogPath = Join-Path $Root "Output\diagnostics\22_mer_standalone_package\task9_mer_asset_pack_copy_log.csv"
if (Test-Path $copyLogPath) {
  $assetPackFiles = Import-Csv $copyLogPath |
    Where-Object { $_.destination_exists -eq "True" -or $_.destination_exists -eq "TRUE" } |
    ForEach-Object {
      $full = $_.destination_path -replace "/", "\"
      if ($full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $full.Substring($Root.Length + 1)
      }
    }
}

$allRelativeFiles = @($relativeFiles + $assetPackFiles) |
  Where-Object { $_ -and $_.Trim().Length -gt 0 } |
  Sort-Object -Unique

$manifest = foreach ($relativePath in $allRelativeFiles) {
  $sourcePath = Join-Path $Root $relativePath
  $exists = Test-Path $sourcePath
  $destinationPath = Join-Path $stagingDir $relativePath

  if ($exists) {
    New-Item -ItemType Directory -Force -Path (Split-Path $destinationPath -Parent) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    $item = Get-Item -LiteralPath $sourcePath
  } else {
    $item = $null
  }

  [pscustomobject]@{
    relative_path = $relativePath
    source_path = $sourcePath
    packaged_path = $destinationPath
    exists = $exists
    packaged = (Test-Path $destinationPath)
    size_bytes = if ($item) { $item.Length } else { $null }
    last_write_time = if ($item) { $item.LastWriteTime.ToString("s") } else { $null }
  }
}

$manifest | Export-Csv -NoTypeInformation -Path $manifestPath
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingDir (Split-Path $manifestPath -Leaf)) -Force

Compress-Archive -Path (Join-Path $stagingDir "*") -DestinationPath $zipPath -Force

Write-Host "Task 9 package created:"
Write-Host $zipPath
Write-Host "Manifest:"
Write-Host $manifestPath
Write-Host "Packaged files:" ($manifest | Where-Object { $_.packaged }).Count "of" $manifest.Count
