# Gayini report batch - full chain (Windows).
#   .\run_batch.ps1
#   $env:GAYINI_ROOT="D:\Github_repos\Gayini"; .\run_batch.ps1
#
# The lint runs FIRST and is fatal. It checks four things, each of which has stood in for
# a derived value in this code at some point: digit literals in client prose, ${...} inside
# a quoted JS string (which renders literally), counts recorded about the build that
# disagree with the build, and companion files read but never produced.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$paddocks = @("Bala 26ca","Bala 27ca","Bala 28ca","Bala 29ca","Bala 15","Dinan 10","Dinan 8")
$sites    = @("GA_001","GA_002","GA_057","GA_003","GA_004","GA_005","GA_006","GA_007",
              "GA_053","GA_054","GA_066","GA_008","GA_009","GA_010","GA_034","GA_035",
              "GA_036","GA_043","GA_055","GA_056","GA_058","GA_025","GA_026","GA_027","GA_028")

Write-Host "== 0/5  pre-batch lint"
python lint_builder.py
if ($LASTEXITCODE -ne 0) { throw "lint_builder.py failed - fix before building" }

Write-Host "== 1/5  data layer (registry asserts + contract canaries)"
python report_data.py --paddocks @paddocks --sites @sites
Write-Host "== 2/5  figures"
python report_figs.py
Write-Host "== 3/5  documents"
node report_build.js

Write-Host "== 4/5  reproduction check"
python verify_batch.py
if ($LASTEXITCODE -ne 0) {
  Write-Host ""
  Write-Host "verify_batch reported a difference. Diff every CHANGED document and explain it"
  Write-Host "before going near fingerprint_batch.py. Do NOT re-fingerprint to make this pass."
  Write-Host "A run that emitted literal template source into two client documents was caught"
  Write-Host "here, and only because the fingerprints were compared rather than regenerated."
}

Write-Host "== 5/5  render QA"
python check_page_fill.py
Write-Host "done."
