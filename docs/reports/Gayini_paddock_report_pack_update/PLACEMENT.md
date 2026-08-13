# Where these files go in D:\Github_repos\Gayini

This zip mirrors the repository layout. Copy each tree to the matching path.

| in this zip | repo destination |
|---|---|
| `scripts/15_reports/` | `D:\Github_repos\Gayini\scripts\15_reports\` — **new folder**, next to `13_pack` and `14_lidar` |
| `docs/reports/` | `D:\Github_repos\Gayini\docs\reports\` |
| `Output/reports/` | `D:\Github_repos\Gayini\Output\reports\` — build output, 32 documents |
| `Output/figures/reports/` | `D:\Github_repos\Gayini\Output\figures\reports\` — 133 figures, not yet registered |

**Read first:** `docs/reports/Gayini_report_batch_CC_handoff.md`.

**Do not commit** `Output/figures/reports/` until the figures are registered through
`write_and_register_figure()` with a new `run_id` — see the handoff §5.

## Getting it running

Paths live in **one file**: `scripts/15_reports/paths.json`. Set `repo_root` there, or override at
run time with the `GAYINI_ROOT` environment variable. Nothing else hardcodes a path.

```powershell
cd D:\Github_repos\Gayini\scripts\15_reports
pip install -r requirements.txt
npm install
$env:GAYINI_ROOT = "D:\Github_repos\Gayini"
.\run_batch.ps1
python verify_batch.py     # must print "32 match · 0 changed · 0 missing"
```

`paths.json` expects `Gayini_Results.sqlite` and `Gayini_Results.gpkg` under `Output/`, and the
existing C1/D2 figure renders under `Output/figures/`. Adjust those four keys if the repo puts them
elsewhere — that is the whole configuration.

## Proving the relocation worked

`verify_batch.py` compares the visible text of each generated document against
`EXPECTED_OUTPUT.json`, a fingerprint of the 32 documents built on 4 August. It has been tested:
a clean run from a relocated copy reproduces all 32 exactly.

If it reports **changed**, a number, caption or degradation branch moved. Investigate before
shipping — do not regenerate the manifest to make it pass.
