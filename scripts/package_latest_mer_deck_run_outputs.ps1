param(
    [string]$Root = "D:\Github_repos\Gayini",
    [string]$PackageRoot = ""
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $PackageRoot = Join-Path $resolvedRoot "Output\packages"
}

if (!(Test-Path -LiteralPath $PackageRoot)) {
    New-Item -ItemType Directory -Force -Path $PackageRoot | Out-Null
}
$resolvedPackageRoot = (Resolve-Path -LiteralPath $PackageRoot).Path

function Get-RepoRelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseWithSeparator = $BasePath.TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    if (!$FullPath.StartsWith($baseWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not under repository root: $FullPath"
    }

    return $FullPath.Substring($baseWithSeparator.Length)
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "Gayini_MER_deck_ready_latest_outputs_$timestamp"
$stagingRoot = Join-Path $resolvedPackageRoot "_staging_$packageName"
$zipPath = Join-Path $resolvedPackageRoot "$packageName.zip"
$manifestPath = Join-Path $resolvedPackageRoot "$packageName.manifest.csv"

$relativeTargets = @(
    "scripts\06_extract_MER_inundation_metrics.R",
    "R\gayini_mer_inundation_functions.R",
    "R\gayini_analysis_base_functions.R",
    "Output\csv\05b_MER_plot_inundation_dynamic_metrics.csv",
    "Output\csv\05b_MER_plot_inundation_monthly_seasonal_max.csv",
    "Output\csv\plot_rs_analysis_base.csv",
    "data_processed\plot_inundation_dynamic_metrics.csv",
    "Output\diagnostics\06_MER_inundation",
    "Output\figures\06_MER_inundation",
    "docs\MER_inundation_method_note_20260623.md",
    "docs\CHANGELOG_MER_inundation_20260623.md",
    "docs\rs_gauge_context_database_import_note_20260623.md",
    "docs\current_run_order.md",
    "Output\archive\repo_cleanup_20260623\MER_gauge_context_removed_from_06_20260624\archive_manifest.csv"
)

if (Test-Path -LiteralPath $stagingRoot) {
    throw "Staging directory already exists: $stagingRoot"
}
New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

$manifestRows = New-Object System.Collections.Generic.List[object]

foreach ($relativeTarget in $relativeTargets) {
    $sourcePath = Join-Path $resolvedRoot $relativeTarget
    if (!(Test-Path -LiteralPath $sourcePath)) {
        $manifestRows.Add([pscustomobject]@{
            relative_path = $relativeTarget
            source_path = $sourcePath
            package_path = ""
            bytes = 0
            last_write_time = ""
            status = "missing"
        })
        continue
    }

    $item = Get-Item -LiteralPath $sourcePath
    $files = if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $sourcePath -Recurse -File
    } else {
        @($item)
    }

    foreach ($file in $files) {
        $relativeFilePath = Get-RepoRelativePath -BasePath $resolvedRoot -FullPath $file.FullName
        $destinationPath = Join-Path $stagingRoot $relativeFilePath
        $destinationDir = Split-Path -Parent $destinationPath
        New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force

        $manifestRows.Add([pscustomobject]@{
            relative_path = $relativeFilePath
            source_path = $file.FullName
            package_path = $destinationPath
            bytes = $file.Length
            last_write_time = $file.LastWriteTime.ToString("s")
            status = "packaged"
        })
    }
}

$manifestRows |
    Sort-Object relative_path |
    Export-Csv -NoTypeInformation -Path $manifestPath

Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingRoot "package_manifest.csv") -Force

if (Test-Path -LiteralPath $zipPath) {
    throw "Zip already exists: $zipPath"
}

Compress-Archive -Path (Join-Path $stagingRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal

$resolvedStagingRoot = (Resolve-Path -LiteralPath $stagingRoot).Path
if (!$resolvedStagingRoot.StartsWith($resolvedPackageRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove staging directory outside package root: $resolvedStagingRoot"
}
if ((Split-Path -Leaf $resolvedStagingRoot) -notlike "_staging_Gayini_MER_deck_ready_latest_outputs_*") {
    throw "Refusing to remove unexpected staging directory: $resolvedStagingRoot"
}
Remove-Item -LiteralPath $resolvedStagingRoot -Recurse -Force

$packagedCount = ($manifestRows | Where-Object { $_.status -eq "packaged" }).Count
$missingCount = ($manifestRows | Where-Object { $_.status -eq "missing" }).Count
$zipInfo = Get-Item -LiteralPath $zipPath

[pscustomobject]@{
    zip_path = $zipInfo.FullName
    manifest_path = $manifestPath
    packaged_files = $packagedCount
    missing_targets = $missingCount
    zip_bytes = $zipInfo.Length
}
