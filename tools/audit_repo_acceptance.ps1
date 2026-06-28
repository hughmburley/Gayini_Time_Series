param(
  [string]$Root = (Resolve-Path ".").Path
)

$ErrorActionPreference = "Stop"

function ConvertTo-RepoPath {
  param([string]$Path)
  return ($Path -replace "\\", "/").TrimStart("./")
}

function Add-Check {
  param(
    [string]$Group,
    [string]$Name,
    [string]$Status,
    [string]$Path = "",
    [string]$Message = "",
    [string]$Severity = "info"
  )

  $script:Checks += [pscustomobject]@{
    check_group = $Group
    check_name  = $Name
    status      = $Status
    path        = $Path
    message     = $Message
    severity    = $Severity
  }
}

function Test-GitIgnored {
  param([string]$Path)
  & git -C $Root check-ignore -q $Path
  return ($LASTEXITCODE -eq 0)
}

$activeFolders = @(
  "scripts/00_setup",
  "scripts/01_prepare_inputs",
  "scripts/02_extract_heavy",
  "scripts/03_inundation_products",
  "scripts/04_gauges",
  "scripts/05_ground_cover",
  "scripts/06_mer",
  "scripts/07_figures_dashboards",
  "scripts/08_review_packages",
  "scripts/09_qa",
  "scripts/10_downstream_optional"
)

$oldNamePattern = "^(08a_|08b_|08c_|09a_|09b_|10a_|10b_|10c_|10d_|10e_|10f_|10g_|10h_|14_|18_|22_|23_|24a_|24b_|25_|26_|12_lag_)"
$generatedExtPattern = "\.(tif|tiff|vrt|aux\.xml|rds|rdata|zip|7z|pptx)$"
$packagingPattern = "(^|/)(package_latest_|utility_zip_recent_|collect_.*outputs|zip_.*outputs|codex_bundle)"

$reportDir = Join-Path $Root "Output/reports/repo_acceptance"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$Checks = @()
$trackedFiles = (& git -C $Root ls-files) | ForEach-Object { ConvertTo-RepoPath $_ }

$allFiles = Get-ChildItem -Path $Root -File -Recurse -Force |
  Where-Object { $_.FullName -notmatch "\\.git\\" } |
  ForEach-Object {
    $rel = ConvertTo-RepoPath ($_.FullName.Substring($Root.Length).TrimStart("\", "/"))
    [pscustomobject]@{
      path       = $rel
      extension  = $_.Extension
      size_bytes = $_.Length
      tracked    = $trackedFiles -contains $rel
    }
  }

$allFiles | Export-Csv -NoTypeInformation -Path (Join-Path $reportDir "repo_acceptance_file_inventory.csv")

foreach ($folder in $activeFolders) {
  $folderPath = Join-Path $Root $folder
  if (Test-Path $folderPath) {
    Add-Check "active_structure" "folder_exists_$folder" "pass" $folder "Folder exists."
  } else {
    Add-Check "active_structure" "folder_exists_$folder" "fail" $folder "Required active script folder is missing." "error"
    continue
  }

  $directScripts = Get-ChildItem -Path $folderPath -File |
    Where-Object { $_.Name -match "\.(R|py|ps1)$" } |
    Sort-Object Name

  $numbers = @()
  foreach ($scriptFile in $directScripts) {
    if ($scriptFile.Name -match "^(\d{2})_") {
      $numbers += [int]$Matches[1]
    } else {
      Add-Check "active_structure" "numbered_name_$($scriptFile.Name)" "fail" (ConvertTo-RepoPath $scriptFile.FullName.Substring($Root.Length).TrimStart("\", "/")) "Active script is not numbered with NN_." "error"
    }
  }

  if ($numbers.Count -gt 0) {
    $expected = 1..$numbers.Count
    $actual = $numbers | Sort-Object
    if (($expected -join ",") -eq ($actual -join ",")) {
      Add-Check "active_structure" "sequential_$folder" "pass" $folder "Direct active scripts are sequential."
    } else {
      Add-Check "active_structure" "sequential_$folder" "fail" $folder "Expected $($expected -join ',') but found $($actual -join ',')." "error"
    }
  }
}

$activeScriptFiles = foreach ($folder in $activeFolders) {
  $folderPath = Join-Path $Root $folder
  if (Test-Path $folderPath) {
    Get-ChildItem -Path $folderPath -File -Recurse |
      Where-Object { $_.Name -match "\.(R|py|ps1)$" }
  }
}

$oldActiveNames = $activeScriptFiles | Where-Object { $_.Name -match $oldNamePattern }
if ($oldActiveNames.Count -eq 0) {
  Add-Check "active_structure" "old_active_names_absent" "pass" "scripts" "No old duplicate active names remain."
} else {
  foreach ($f in $oldActiveNames) {
    Add-Check "active_structure" "old_active_name_$($f.Name)" "fail" (ConvertTo-RepoPath $f.FullName.Substring($Root.Length).TrimStart("\", "/")) "Old duplicate active script name remains." "error"
  }
}

if (Test-Path (Join-Path $Root "scripts/obs")) {
  Add-Check "archive_obs" "scripts_obs_absent" "fail" "scripts/obs" "scripts/obs exists in the visible handoff." "error"
} else {
  Add-Check "archive_obs" "scripts_obs_absent" "pass" "scripts/obs" "scripts/obs is absent."
}

if (Test-Path (Join-Path $Root "scripts/archive")) {
  Add-Check "archive_obs" "scripts_archive_absent" "fail" "scripts/archive" "scripts/archive exists in the visible handoff." "error"
} else {
  Add-Check "archive_obs" "scripts_archive_absent" "pass" "scripts/archive" "scripts/archive is absent."
}

$activeArchiveRefs = @()
foreach ($f in $activeScriptFiles) {
  $text = Get-Content -Raw -Path $f.FullName
  if ($text -match "scripts[/\\](archive|obs)") {
    $activeArchiveRefs += $f
  }
}
if ($activeArchiveRefs.Count -eq 0) {
  Add-Check "archive_obs" "active_code_archive_obs_refs_absent" "pass" "scripts" "Active code does not reference scripts/archive or scripts/obs."
} else {
  foreach ($f in $activeArchiveRefs) {
    Add-Check "archive_obs" "active_code_archive_obs_ref_$($f.Name)" "fail" (ConvertTo-RepoPath $f.FullName.Substring($Root.Length).TrimStart("\", "/")) "Active code references scripts/archive or scripts/obs." "error"
  }
}

$runOrderFiles = Get-ChildItem -Path (Join-Path $Root "docs/run_order") -Filter "*.csv" -ErrorAction SilentlyContinue
$runOrderArchiveRefs = @()
foreach ($f in $runOrderFiles) {
  $text = Get-Content -Raw -Path $f.FullName
  if ($text -match "scripts[/\\](archive|obs)") {
    $runOrderArchiveRefs += $f
  }
}
if ($runOrderArchiveRefs.Count -eq 0) {
  Add-Check "run_order" "run_order_archive_obs_refs_absent" "pass" "docs/run_order" "Run-order docs do not direct users to archive/obs scripts."
} else {
  foreach ($f in $runOrderArchiveRefs) {
    Add-Check "run_order" "run_order_archive_obs_ref_$($f.Name)" "fail" (ConvertTo-RepoPath $f.FullName.Substring($Root.Length).TrimStart("\", "/")) "Run-order file references archive/obs material." "error"
  }
}

$expectedRunOrder = @(
  "docs/run_order/README.md",
  "docs/run_order/01_full_rebuild_workflow.csv",
  "docs/run_order/02_lightweight_review_refresh.csv",
  "docs/run_order/03_mer_workflow.csv",
  "docs/run_order/04_qa_workflow.csv",
  "docs/run_order/05_downstream_optional.csv"
)

foreach ($p in $expectedRunOrder) {
  if (Test-Path (Join-Path $Root $p)) {
    Add-Check "run_order" "exists_$p" "pass" $p "Run-order file exists."
  } else {
    Add-Check "run_order" "exists_$p" "fail" $p "Expected run-order file is missing." "error"
  }
}

foreach ($csv in $runOrderFiles) {
  $rows = Import-Csv -Path $csv.FullName
  foreach ($row in $rows) {
    if ($row.script_path) {
      $scriptPath = $row.script_path
      if (Test-Path (Join-Path $Root $scriptPath)) {
        Add-Check "run_order" "script_exists_$scriptPath" "pass" $scriptPath "Run-order script exists."
      } else {
        Add-Check "run_order" "script_exists_$scriptPath" "fail" $scriptPath "Run-order script is missing." "error"
      }
      if ((Split-Path $scriptPath -Leaf) -match $oldNamePattern) {
        Add-Check "run_order" "old_script_name_$scriptPath" "fail" $scriptPath "Run-order references old active script name." "error"
      }
      if ($row.heavy_or_light -eq "heavy" -and ($row.safe_for_new_user -ne "no" -or $row.run_by_default -ne "no")) {
        Add-Check "run_order" "heavy_marked_safe_$scriptPath" "fail" $scriptPath "Heavy script must be safe_for_new_user=no and run_by_default=no." "error"
      }
    }
  }
}

$merRasterRows = @(Import-Csv -Path (Join-Path $Root "docs/run_order/03_mer_workflow.csv") |
  Where-Object { $_.script_path -like "*07_build_mer_annual_max_rasters.R" }
)
if ($merRasterRows.Count -eq 1 -and $merRasterRows[0].heavy_or_light -eq "heavy" -and $merRasterRows[0].safe_for_new_user -eq "no" -and $merRasterRows[0].run_by_default -eq "no") {
  Add-Check "run_order" "mer_raster_production_heavy_no_default" "pass" "docs/run_order/03_mer_workflow.csv" "MER raster production is heavy/no-default."
} else {
  Add-Check "run_order" "mer_raster_production_heavy_no_default" "fail" "docs/run_order/03_mer_workflow.csv" "MER raster production is not marked heavy/no-default." "error"
}

$trackedPackaging = $trackedFiles | Where-Object { $_ -match $packagingPattern }
if ($trackedPackaging.Count -eq 0) {
  Add-Check "packaging" "local_packaging_not_tracked" "pass" "" "No tracked local packaging/output-bundling utilities found."
} else {
  foreach ($p in $trackedPackaging) {
    Add-Check "packaging" "local_packaging_tracked_$p" "fail" $p "Tracked local packaging/output-bundling utility found." "error"
  }
}

if (Test-GitIgnored "Output/test_acceptance_ignore_probe.txt") {
  Add-Check "outputs" "output_ignored" "pass" "Output/" "Output/ is ignored by Git."
} else {
  Add-Check "outputs" "output_ignored" "fail" "Output/" "Output/ is not ignored by Git." "error"
}

if (Test-GitIgnored "_local_archive/test_acceptance_ignore_probe.txt") {
  Add-Check "outputs" "local_archive_ignored" "pass" "_local_archive/" "_local_archive/ is ignored by Git."
} else {
  Add-Check "outputs" "local_archive_ignored" "warning" "_local_archive/" "_local_archive/ is not ignored by Git." "warning"
}

$trackedGenerated = $trackedFiles | Where-Object { $_ -match $generatedExtPattern }
if ($trackedGenerated.Count -eq 0) {
  Add-Check "outputs" "generated_binary_outputs_not_tracked" "pass" "" "No tracked raster/archive/RDS/PPTX generated outputs found."
} else {
  foreach ($p in $trackedGenerated) {
    Add-Check "outputs" "generated_output_tracked_$p" "fail" $p "Tracked generated/binary output found." "error"
  }
}

$trackedOutput = $trackedFiles | Where-Object { $_ -like "Output/*" }
if ($trackedOutput.Count -eq 0) {
  Add-Check "outputs" "output_files_not_tracked" "pass" "Output/" "No Output/ files are tracked."
} else {
  foreach ($p in $trackedOutput) {
    Add-Check "outputs" "output_file_tracked_$p" "fail" $p "Output/ file is tracked." "error"
  }
}

$spineFiles = @("run_spine_smoke_test.R", "DESCRIPTION", "tests/testthat.R", "README.md", "scripts/README.md")
foreach ($p in $spineFiles) {
  if (Test-Path (Join-Path $Root $p)) {
    Add-Check "spine_package" "exists_$p" "pass" $p "Required spine/package file exists."
  } else {
    Add-Check "spine_package" "exists_$p" "fail" $p "Required spine/package file is missing." "error"
  }
}

if (Test-Path (Join-Path $Root "tests/testthat")) {
  $testFiles = Get-ChildItem -Path (Join-Path $Root "tests/testthat") -Filter "test-*.R"
  if ($testFiles.Count -gt 0) {
    Add-Check "spine_package" "helper_tests_exist" "pass" "tests/testthat" "$($testFiles.Count) helper test file(s) found."
  } else {
    Add-Check "spine_package" "helper_tests_exist" "fail" "tests/testthat" "No helper test files found." "error"
  }
}

$headerRows = @()
$commentRows = @()
foreach ($f in $activeScriptFiles) {
  $rel = ConvertTo-RepoPath $f.FullName.Substring($Root.Length).TrimStart("\", "/")
  $text = Get-Content -Raw -Path $f.FullName
  $first = (($text -split "\r?\n") | Select-Object -First 45) -join "`n"
  $hasHeader = ($first -match "Script:\s+scripts/" -and $first -match "Purpose:" -and $first -match "Workflow stage:" -and $first -match "Run mode:" -and $first -match "Heavy processing:" -and $first -match "Key inputs:" -and $first -match "Key outputs:" -and $first -match "Notes:")
  $sectionCount = ([regex]::Matches($text, "(?m)^\s*#.*-{6,}|^\s*##\s+.+----")).Count
  $headerRows += [pscustomobject]@{
    script_path              = $rel
    has_header               = $hasHeader
    purpose_present          = $first -match "Purpose:"
    workflow_stage_present   = $first -match "Workflow stage:"
    run_mode_present         = $first -match "Run mode:"
    heavy_processing_present = $first -match "Heavy processing:"
    inputs_present           = $first -match "Key inputs:"
    outputs_present          = $first -match "Key outputs:"
    notes_present            = $first -match "Notes:"
    updated                  = "audit_only"
    status                   = $(if ($hasHeader) { "pass" } else { "fail" })
  }
  $commentRows += [pscustomobject]@{
    script_path                  = $rel
    n_section_comments           = $sectionCount
    important_steps_documented   = $(if ($sectionCount -gt 0) { "yes" } else { "no" })
    updated                      = "audit_only"
    notes                        = $(if ($sectionCount -gt 0) { "Section markers present." } else { "No section markers found." })
  }
}

$headerRows | Export-Csv -NoTypeInformation -Path (Join-Path $reportDir "script_header_audit.csv")
$commentRows | Export-Csv -NoTypeInformation -Path (Join-Path $reportDir "script_comment_audit.csv")

$missingHeaders = $headerRows | Where-Object { $_.status -ne "pass" }
if ($missingHeaders.Count -eq 0) {
  Add-Check "documentation" "active_script_headers" "pass" "scripts" "All active scripts have standard headers."
} else {
  foreach ($row in $missingHeaders) {
    Add-Check "documentation" "missing_header_$($row.script_path)" "fail" $row.script_path "Active script header is incomplete." "error"
  }
}

$missingComments = $commentRows | Where-Object { $_.important_steps_documented -ne "yes" }
if ($missingComments.Count -eq 0) {
  Add-Check "documentation" "active_script_section_comments" "pass" "scripts" "All active scripts have section comments."
} else {
  foreach ($row in $missingComments) {
    Add-Check "documentation" "missing_comments_$($row.script_path)" "warning" $row.script_path "No section comments found." "warning"
  }
}

if (Test-Path (Join-Path $Root "tbreak")) {
  Add-Check "local_state" "tbreak_untracked_documented" "manual_review" "tbreak/" "tbreak/ exists locally and should remain untracked." "manual_review"
} else {
  Add-Check "local_state" "tbreak_absent" "pass" "tbreak/" "tbreak/ is absent."
}

$Checks | Export-Csv -NoTypeInformation -Path (Join-Path $reportDir "repo_acceptance_audit.csv")
$failures = $Checks | Where-Object { $_.status -eq "fail" }
$failures | Export-Csv -NoTypeInformation -Path (Join-Path $reportDir "repo_acceptance_failures.csv")

$summary = @()
$summary += "# Gayini Repo Acceptance Audit"
$summary += ""
$summary += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
$summary += ""
$summary += "## Summary"
$summary += ""
$summary += "- Checks: $($Checks.Count)"
$summary += "- Pass: $(($Checks | Where-Object { $_.status -eq 'pass' }).Count)"
$summary += "- Warnings: $(($Checks | Where-Object { $_.status -eq 'warning' }).Count)"
$summary += "- Manual review: $(@($Checks | Where-Object { $_.status -eq 'manual_review' }).Count)"
$summary += "- Failures: $($failures.Count)"
$summary += ""

if ($failures.Count -gt 0) {
  $summary += "## Failures"
  $summary += ""
  foreach ($failure in $failures) {
    $summary += "- ``$($failure.path)``: $($failure.message)"
  }
} else {
  $summary += "## Result"
  $summary += ""
  $summary += "No failures detected. Review warnings/manual-review rows before external handoff."
}

$summary -join "`n" | Set-Content -Path (Join-Path $reportDir "repo_acceptance_audit.md") -Encoding UTF8

if ($failures.Count -gt 0) {
  exit 1
}
