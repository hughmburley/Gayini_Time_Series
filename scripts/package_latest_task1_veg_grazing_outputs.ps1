param(
    [string]$Root = "D:\Github_repos\Gayini",
    [string]$PackageRoot = "D:\Github_repos\Gayini\Output\packages"
)

$ErrorActionPreference = "Stop"

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
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
$packageName = "Gayini_task1_veg_groups_treed_grazing_outputs_$timestamp"
$stagingRoot = Join-Path $resolvedPackageRoot "_staging_$packageName"
$zipPath = Join-Path $resolvedPackageRoot "$packageName.zip"
$manifestPath = Join-Path $resolvedPackageRoot "$packageName.manifest.csv"

$relativeTargets = @(
    "scripts\10d_prepare_plot_context_flags.R",
    "Output\csv\plot_context_flags.csv",
    "Output\csv\plot_context_flag_summary.csv",
    "Output\csv\ground_cover_treed_plot_sensitivity.csv",
    "Output\csv\10a_ground_cover_prepost_plot_summary_interpretation.csv",
    "Output\csv\10a_ground_cover_prepost_group_summary_interpretation.csv",
    "Output\figures\review\plot_treed_exclusion_map.png",
    "Output\reports\task_1_veg_groups_treed_grazing_handoff.md",
    "Output\diagnostics\10d_plot_context_flags"
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
if ((Split-Path -Leaf $resolvedStagingRoot) -notlike "_staging_Gayini_task1_veg_groups_treed_grazing_outputs_*") {
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
