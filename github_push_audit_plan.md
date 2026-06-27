# Gayini GitHub Push Audit Plan

Audit date: 2026-06-25  
Local folder: `D:\Github_repos\Gayini`  
Target GitHub repository: `https://github.com/hughmburley/Gayini_Time_Series.git`  
Status: audit only. No `git add`, `git commit`, or `git push` commands were executed.

## Summary Recommendation

The repository is suitable for a staged GitHub setup, but not for a whole-folder push.

The first push should be a minimal source-code push: `R/`, `scripts/`, `README.md`, `Gayini.Rproj`, small curated `config/` files, and selected lightweight markdown/CSV docs that explain workflow and expected inputs. Do not push `Input/`, `Output/`, `data_intermediate/`, `data_processed/`, `archive/`, zip files, generated figures, raster/vector data, or raw hydrology/remote-sensing data in the initial commit.

Important repository-state finding: the top-level `.git` directory appears empty, and `git status` returned `fatal: not a git repository`. Treat this as an initialization issue before pushing. `git init -b main` should be run later only after the `.gitignore` is updated and this report is reviewed.

## Folder Census

Approximate recursive counts and sizes from filesystem inspection:

| Folder/file | Approx. files | Approx. size | Key file types | Audit interpretation |
|---|---:|---:|---|---|
| `.agents/` | 0 | 0 MB | none | Local agent metadata; exclude. |
| `.git/` | 0 | 0 MB | none visible | Empty or invalid Git metadata; Git currently not initialized correctly. |
| `.Rproj.user/` | 26 | 0.08 MB | RStudio session files | Local IDE cache; exclude. |
| `archive/` | 448 | 147 MB | PNG, CSV, MD, R, ZIP, PS1, 7z | Historical/generated packages; exclude initially, manually review only if historical code must be preserved. |
| `config/` | 5 | <0.01 MB | CSV, MD | Good candidate for commit after quick content review. |
| `data_intermediate/` | 624 | 184 MB | TIF, XML, CSV, GPKG, ZIP | Derived data/cache/spatial intermediates; exclude. |
| `data_processed/` | 14 | 72 MB | CSV | Processed hydrology/data products; exclude initially; consider data release or LFS only if needed. |
| `docs/` | 36 | 1.17 MB | MD, CSV, DOCX, XLSX, PDF, ZIP | Mixed docs and office artifacts; commit selected markdown/CSV docs, review office/PDF/ZIP files. |
| `Input/` | 1,564 | 52,074 MB | TIF, XML, OVR, TFW, DBF, IMG, JP2, SHP | Raw/source data; definitely exclude. |
| `Output/` | 423 | 145 MB | CSV, PNG, TIF, TXT, MD, XLSX | Generated outputs/figures/diagnostics/reports; exclude initially. |
| `R/` | 22 | 0.48 MB | R | Commit now. |
| `scripts/` | 86 | 0.97 MB | R, PS1, TXT, MJS | Commit main scripts now; consider whether `scripts/archive/` should be excluded or retained as code history. |
| `tbreak/` | 39 | 0.17 MB | R package files, nested `.git` | Looks like a vendored/external package/repo; manual review before commit. |
| `tools/` | 3 | 0.03 MB | PS1 | Commit if these are active workflow utilities; otherwise review. |
| `working/` | 15 | 0.03 MB | scratch R/CSV/PS1/Rproj/TXT | Working scratch/starter area; exclude initially or manually review. |
| root files | 11 | 56.2 MB | README, Rproj, TXT, ZIP | Commit `README.md`, `Gayini.Rproj`, maybe notes after review; exclude zips and local history. |

## Largest Files and Data Risks

Obvious large files:

| Path | Approx. size | Recommendation |
|---|---:|---|
| `Input/ads/*.jp2` | 5.1-7.8 GB each, about 25 GB total | Do not commit. External storage/data release only. |
| `Input/modis_fractional_cover/*.tif` | about 70-75 MB each, about 22.8 GB total | Do not commit. External storage/data release only. |
| `Input/sentinel2_inundation/` and `Input/sentinel2_inundation.zip` | about 2.4 GB folder, 122 MB zip | Do not commit. |
| `Input/landsat_fractionalcover3/` | about 1.25 GB | Do not commit. |
| `data_intermediate/hydrology/gayini_gauge_daily_imported.csv` | 168 MB | Do not commit initially; review licensing/sensitivity. |
| `Input/hydrology/gayini_gauge_daily.csv` | 158 MB | Raw gauge data; do not commit. |
| `Output.zip` | 56 MB | Generated archive; do not commit. |
| `Output/` | 145 MB | Generated outputs; do not commit initially. |

Repository-wide file type summary includes 1,036 `.tif`, 609 `.xml`, 422 `.png`, 379 `.csv`, 237 `.ovr`, 116 `.R`, 95 `.tfw`, 20 `.zip`, 5 `.gpkg`, 4 `.jp2`, 4 `.shp`, 4 `.xlsx`, 3 `.7z`, and 2 `.docx`.

## Sensitive or Manual-Review Findings

No obvious `.env`, `.Renviron`, credential, token, password, API-key, private-key, or real database files were found by filename scan.

Sensitive-content text scan across small source/docs/config files found only likely false positives such as `date_token`, `sensor_token`, and tidy-eval `.env` usage in R code. No credential-looking content was identified.

Manual review is still needed for project/client material:

| Item | Reason |
|---|---|
| `Gayini_Notes` | Plain project notes may contain internal/client context. |
| `Codex_audit_instructions.txt`, `Codex_clean.txt`, `Codex_review_instructions.txt` | Internal task instructions; probably exclude unless deliberately documenting process. |
| `docs/*.docx`, `docs/*.xlsx`, `docs/*.pdf` | May contain client, workshop, unpublished method, or copied reference material. |
| `Output/reports/*.xlsx`, generated reports | Generated deliverables; may contain derived/client-facing material. |
| `Input/shapefiles/` and `data_intermediate/spatial/*.gpkg` | Spatial boundaries/plot/management-zone data may be sensitive or licensed. |
| `Input/hydrology/` and processed hydrology CSVs | Raw gauge data/licensing/provenance needs review before publication. |
| `tbreak/` | Contains a nested `.git`; decide whether this is external code, a dependency, or something to vendor deliberately. |

One Windows cache file was found: `Input/modis_fractional_cover/Thumbs.db`; exclude.

## Commit, Exclude, Review, Store Elsewhere

| Path/type | Decision | Rationale |
|---|---|---|
| `R/` | Commit now | Core reusable analysis functions; small and source-controlled. |
| `scripts/` | Commit now, with review of `scripts/archive/` | Core executable workflow; small. Archived scripts may be useful but can also clutter first push. |
| `README.md` | Commit now | Required repository entry point. |
| `Gayini.Rproj` | Commit now | Small RStudio project file; useful for collaborators. |
| `config/` | Commit now after quick review | Small class legends and extraction settings; likely needed for reproducibility. |
| `docs/*.md`, selected `docs/*.csv` workflow manifests | Commit in Option B; selected docs only in Option A | Useful lightweight provenance and workflow docs. |
| `docs/scripts/*.R` | Commit or move under `scripts/` later | Small helper scripts; commit if still active. |
| SQL files | None found | If added later, commit schema/query code only; do not commit database dumps. |
| `renv.lock`, `requirements.txt`, `.Rprofile`, `.Renviron` | None found at root | Commit `renv.lock`/requirements if created; never commit `.Renviron` with secrets. |
| `Output/diagnostics` lightweight manifests | Manual review; not first push | Some QA manifests may aid reproducibility, but they are generated outputs. |
| Generated plots/maps (`*.png`, map output folders) | Exclude | Generated outputs; recreate from scripts or store in release artifacts. |
| PowerPoint decks | None found | If added later, review manually; usually exclude generated decks from code repo. |
| Excel workbooks (`*.xlsx`) | Manual review | Small but likely planning/output/client material. |
| Zip/7z archives | Exclude | Generated bundles/backups; not source. |
| Databases | No real DB found; only `Thumbs.db` | Exclude database/cache files. |
| Raster data (`*.tif`, `*.jp2`, `.ovr`, `.tfw`) | Exclude/store externally | Too large and raw/derived geospatial data. |
| Vector spatial data (`*.shp`, `.dbf`, `.shx`, `.gpkg`) | Exclude/store externally or LFS after review | Potential sensitivity/licensing; not code. |
| Raw gauge data | Exclude/store externally | Large and may have licensing/provenance constraints. |
| MODIS/remote-sensing data | Exclude/store externally | Massive raw/source imagery. |
| `archive/` | Exclude initially | Historical generated packages and prior outputs. |
| `working/` | Exclude initially | Scratch/starter area. |
| `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata` | Exclude | Local R/RStudio state. |
| `.agents/` | Exclude | Local agent metadata. |
| `R.zip`, `scripts.zip`, `Output.zip` | Exclude | Archives; source folders should be committed directly. |

## Proposed `.gitignore`

Draft only. Review before replacing the current `.gitignore`.

```gitignore
# R / RStudio local state
.Rproj.user/
.Rhistory
.RData
.Ruserdata
.Renviron
*.RData
*.rds
*.Rds
*.RDS

# Local/editor/OS files
.DS_Store
Thumbs.db
desktop.ini
*.tmp
*.temp
*.log
*.bak
~$*

# Local agent/cache metadata
.agents/
.codex/

# Raw and derived data
Input/
data_intermediate/
data_processed/

# Generated outputs and reports
Output/
working/
archive/

# Common generated geospatial/remote-sensing artifacts
*.tif
*.tiff
*.jp2
*.ovr
*.tfw
*.aux
*.pyrx
*.img
*.rrd
*.shp
*.shx
*.dbf
*.prj
*.cpg
*.gpkg

# Archives and packaged outputs
*.zip
*.7z
*.tar
*.tar.gz
*.rar

# Office/generated deliverables - add exceptions if reviewed and intentional
*.ppt
*.pptx

# Databases and local caches
*.sqlite
*.sqlite3
*.db
*.duckdb

# Logs
Output/logs/
*.Rout
```

Possible exceptions after review:

```gitignore
!docs/**/*.md
!docs/**/*.csv
!config/**/*.csv
!config/**/*.md
```

If committing small spatial template files is ever necessary, use explicit `!path/to/file` exceptions rather than allowing whole spatial extensions globally.

## Push Plan Options

### Option A - Minimal Safe Push

Purpose: publish code only with minimal project scaffolding.

Include:

| Include | Notes |
|---|---|
| `.gitignore` | Update first using the proposed ignore rules. |
| `README.md` | Consider expanding with required external data locations. |
| `Gayini.Rproj` | Project entry point. |
| `R/` | Core functions. |
| `scripts/` | Active scripts; consider excluding or separately reviewing `scripts/archive/`. |
| `config/` | Small settings/legends if no sensitive paths or client details. |
| selected `docs/*.md` | Only workflow docs that do not contain client/private material. |

Exclude:

`Input/`, `Output/`, `data_intermediate/`, `data_processed/`, `archive/`, `working/`, `.Rproj.user/`, `.agents/`, all zip/7z files, raw/derived raster and vector data, generated plots/maps, Excel/Word/PDF files unless explicitly reviewed.

### Option B - Reproducible Analysis Push

Purpose: publish code plus lightweight provenance so another analyst can understand how to reproduce the workflow with externally supplied data.

Include Option A plus selected lightweight metadata:

| Include | Notes |
|---|---|
| `docs/current_run_order.md` | Useful run order documentation. |
| `docs/codex_context.md` | Review for internal process/client content first. |
| `docs/canonical_outputs_steps_04_07.md` | Lightweight output expectations. |
| `docs/function_file_inventory.md` | Source-code inventory. |
| `docs/*workflow_manifest*.csv` | Commit if these describe workflow rather than generated results. |
| `docs/*script_rename_map*.csv` | Useful provenance if non-sensitive. |
| `docs/README_Gayini_LOOCB_json_inputs.md` and config templates | Useful input schema docs. |
| `tools/*.ps1` | Include if currently used to run/package workflow. |

Still exclude:

All raw data, remote-sensing imagery, hydrology CSVs, generated outputs, figures, rasters, shapefiles/geopackages, zips, office deliverables, caches, and scratch folders.

## Files/Folders Needing Manual Review

| Path | Review question |
|---|---|
| `scripts/archive/` | Preserve as historical code in Git, or omit from first push to keep history clean? |
| `docs/codex_context.md` and other Codex handoff/audit docs | Are these useful public workflow docs or internal working notes? |
| `Gayini_Notes` | Does it contain internal/client material? If safe, consider renaming to `docs/project_notes.md`. |
| `docs/*.docx`, `docs/*.xlsx`, `docs/*.pdf` | Are these publishable, licensed, and useful in source control? |
| `config/extraction_settings.csv` | Check for local absolute paths or client-specific assumptions. |
| `tools/*.ps1` | Confirm these are active utilities and not one-off local packaging scripts. |
| `tbreak/` | Decide whether to ignore, add as submodule, declare as dependency, or vendor intentionally. |
| `Output/diagnostics/*.csv` | Decide whether any small QA manifest is required for reproducibility. |

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Accidentally pushing 52 GB of raw data | Ignore `Input/` and all raster/vector extensions before first `git add`. Use `git add -n` dry-runs. |
| Publishing generated/client-facing outputs | Ignore `Output/`, `archive/`, `working/`, office deliverables, and archive files. |
| Publishing sensitive spatial boundaries or plot data | Keep shapefiles/GPKG out of Git until licensing/privacy review. |
| Invalid Git state because `.git` is empty | Initialize Git only after review; confirm `git status` works before any staging. |
| Missing reproducibility context | Commit lightweight docs/config; document external data requirements in `README.md`. |
| Large files accidentally staged by extension exceptions | Run `git status --short`, `git diff --cached --stat`, and a large-file check before commit. |
| Dependency drift | Consider adding `renv.lock` later using `renv::snapshot()` after package state is stable. |

## Commands To Run Later - Not Yet Executed

These commands are proposed only. They were not run during this audit.

### Preflight

```powershell
Set-Location D:\Github_repos\Gayini

# Confirm the folder and inspect current Git state
Get-Location
Get-ChildItem -Force .git
git status
```

If `git status` still reports `fatal: not a git repository`, initialize the repository:

```powershell
git init -b main
git remote add origin https://github.com/hughmburley/Gayini_Time_Series.git
git remote -v
```

If a remote already exists after initialization, use:

```powershell
git remote set-url origin https://github.com/hughmburley/Gayini_Time_Series.git
```

### Dry-run staging checks

Option A dry-run:

```powershell
git add -n .gitignore README.md Gayini.Rproj R scripts config
git add -n docs/*.md docs/*.csv
git status --short
```

Option B dry-run:

```powershell
git add -n .gitignore README.md Gayini.Rproj R scripts config tools
git add -n docs/*.md docs/*.csv docs/config docs/scripts
git status --short
```

Check for accidentally staged large files after real staging:

```powershell
git diff --cached --stat
git diff --cached --name-only | Select-String -Pattern '(^Input/|^Output/|^data_intermediate/|^data_processed/|^archive/|^working/|\.zip$|\.7z$|\.tif$|\.jp2$|\.gpkg$|\.shp$|\.xlsx$|\.docx$|\.pptx$)'
```

### Real staging and first commit

Run only after manual review and `.gitignore` update.

```powershell
git add .gitignore README.md Gayini.Rproj R scripts config
git add docs/*.md docs/*.csv
git status --short
git diff --cached --stat
git commit -m "Initial Gayini analysis code push"
git push -u origin main
```

## Bottom Line

Safe to initialize and push after review: yes, if the push is restricted to source code, small config, and selected lightweight docs.

Push first: `R/`, active `scripts/`, `README.md`, `Gayini.Rproj`, `config/`, and reviewed markdown/CSV docs.

Definitely do not push first: `Input/`, `Output/`, `data_intermediate/`, `data_processed/`, `archive/`, `working/`, zip/7z archives, raster/vector spatial data, raw gauge data, MODIS/remote-sensing data, generated plots/maps, RStudio state, and local caches.

Human review questions before pushing:

1. Should `scripts/archive/` be included as historical source code or omitted from the first clean push?
2. Which `docs/*.md` and `docs/*.csv` are safe and useful to publish?
3. Are `Gayini_Notes`, Codex instruction files, Word docs, Excel files, or PDFs intended for public repository history?
4. Should `tbreak/` be ignored, declared as a dependency, added as a submodule, or vendored?
5. Is any small generated manifest essential enough to commit, or should all outputs remain external?
