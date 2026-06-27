param(
  [string]$RootDir = "D:\Github_repos\Gayini",
  [string]$RegisterPath = "D:\Github_repos\Gayini\Output\reports\Gayini_ppt_asset_register.csv",
  [string]$AssetPackDir = "",
  [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RegisterPath -PathType Leaf)) {
  throw "Asset register not found: $RegisterPath"
}

if ([string]::IsNullOrWhiteSpace($AssetPackDir)) {
  $dateStamp = Get-Date -Format "yyyyMMdd"
  $AssetPackDir = Join-Path $RootDir "Output\reports\ppt_asset_pack_$dateStamp"
}

$subfolders = @(
  "01_main_deck_figures",
  "02_supporting_figures",
  "03_appendix_figures",
  "04_tables",
  "05_reference_reports"
)

foreach ($subfolder in $subfolders) {
  New-Item -ItemType Directory -Path (Join-Path $AssetPackDir $subfolder) -Force | Out-Null
}

$register = Import-Csv -LiteralPath $RegisterPath

$selected = $register | Where-Object {
  $_.asset_status -eq "Current canonical" -or
  $_.deck_priority -in @("Headline", "Supporting", "Appendix")
}

$copyLog = foreach ($row in $selected) {
  $sourcePath = $row.full_path
  $exists = -not [string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)

  $destinationFolder = switch ($row.deck_priority) {
    "Headline" { "01_main_deck_figures"; break }
    "Supporting" { "02_supporting_figures"; break }
    "Appendix" { "03_appendix_figures"; break }
    default {
      if ($row.file_type -match "csv|xlsx") { "04_tables" }
      elseif ($row.file_type -match "md|pdf|ppt|pptx") { "05_reference_reports" }
      else { "03_appendix_figures" }
    }
  }

  if ($row.file_type -match "csv|xlsx") {
    $destinationFolder = "04_tables"
  }

  if ($row.file_type -match "md|pdf|ppt|pptx") {
    $destinationFolder = "05_reference_reports"
  }

  $destinationPath = if ($exists) {
    Join-Path (Join-Path $AssetPackDir $destinationFolder) (Split-Path -Leaf $sourcePath)
  } else {
    ""
  }

  $copied = $false
  $message = ""

  if ($exists) {
    if ((Test-Path -LiteralPath $destinationPath -PathType Leaf) -and -not $Overwrite) {
      $message = "Destination exists; left unchanged. Use -Overwrite to replace same-name file."
    } else {
      Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force:$Overwrite
      $copied = $true
      $message = "Copied"
    }
  } else {
    $message = "Missing source path"
    Write-Warning "Missing source path for asset $($row.asset_id): $sourcePath"
  }

  [pscustomobject]@{
    asset_id = $row.asset_id
    filename = $row.filename
    source_path = $sourcePath
    destination_folder = $destinationFolder
    destination_path = $destinationPath
    copied = $copied
    source_exists = $exists
    asset_status = $row.asset_status
    deck_priority = $row.deck_priority
    message = $message
  }
}

$copyLogPath = Join-Path $AssetPackDir "ppt_asset_copy_log.csv"
$copyLog | Export-Csv -LiteralPath $copyLogPath -NoTypeInformation

Write-Host "Asset pack: $AssetPackDir"
Write-Host "Copy log: $copyLogPath"
Write-Host "Selected rows:" ($selected | Measure-Object).Count
Write-Host "Copied files:" ($copyLog | Where-Object { $_.copied }).Count
Write-Host "Missing source files:" ($copyLog | Where-Object { -not $_.source_exists }).Count
