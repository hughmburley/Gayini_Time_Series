# D2 site-dashboard batch build — change report

**Date:** 20 July 2026 · **Branch (planned):** `d2-site-dashboard-batch` off `main` · **Status:** Gates 0–3 complete (3b executed against the live DB). Held for human review — **do not merge; staging/commit is the human step.** No AI authorship in commits.

## What changed
- **All 57 non-treed site dashboards rebuilt fresh from `main`** into a new subfolder `Output/figures/dashboards/` (57 PNG + 57 PDF, 3999×2250), via the generator's own code path (`gayini_dashboard_context → gayini_resolve_site → gayini_build_dashboard`); **generator source unedited** — the subfolder is set purely through `out_dir`.
- **The 5 stale shipped PNGs (+ 5 PDF siblings) were moved** (never deleted) from `Output/figures/` to `Output/figures/_archive/`. They predate the committed #21 label fix (`67977bd`) and are not canonical.
- All 57 carry the corrected label **"Total veg (green + dead)"**; **no cultural/spatial banner is rendered** (the generator has no banner path — deferred, see below).
- **The 57 PNGs are additively registered in `figure_asset`** via a new targeted registrar (57 INSERTs; builder never run). DB row count 139 → 196.
- Deliverable tables written to `Output/tables/` (the repo's tracked-tables home; force-add at commit).

## Gate 0 (closed) — generator + parity
Generator = `scripts/07_figures_dashboards/12_build_dashboards.R` + `R/gayini_dashboard_compose.R` + `R/gayini_dashboard_panels.R`. Both correctness checks pass from source: site flood freq = `100*wet_years/valid_years` over valid years (spine; `v_plot_current_summary` never queried → no pre/post leak); "Where it sits" boxes the per-plot spine aggregate = **plot support** (no census source read). Parity re-render of the 5 reproduces `main` on values + layout (3999×2250, ≤1 KB size delta); the only difference is the #21 label. Remote: `hughmburley/Gayini_Time_Series`.

## Gate 1 (closed) — roster, paths, paddock, flags
- Roster: 66 plots; **57 non-treed** (assert PASS); 9 treed excluded (all "Floodplain Woodland / Forest"): GA_011/012/014/015/021/023/029/030/065.
- Inputs resolve off `root_dir`, not the DB registries (shadow-input issue — separate task).
- plot→paddock (centroids 9473→8058): **39/57 on a paddock, all with a C1 figure; 18/57 outside all zones** (report-assembly gap only).
- Flags: all 57 `internal_review` / `public_release_ok=0` / `review_required`; `spatial_review_flag=1` on **23/57** (5 known-review ∪ the 18 paddock-gap). Generator renders no banner (GA_032 positive control).

## Gate 2 (closed) — build
57 built; community "this unit" means **9.1 / 22.3 / 49.6** (n=16/19/22) = plot support (not census 6/13/28). 114 benign edge-NA warnings (2/site). Bundle `Output/review_bundles/d2_site_dashboard_batch/` (+ `.zip`, 60 entries) with a README carrying the sensitivity status. Builder not invoked.

## Gate 3a (closed) — registration recon
### The builder is the only writer of `figure_asset`; no additive registrar existed
`figure_asset` is written in exactly one place: the destructive builder `scripts/11_database/01_build_results_database.py:1524` (`executemany INSERT ... figure_rows`), populated from an unfiltered `rglob` (:1466). Recon confirmed there was **no standalone additive registrar** — so one was built for this task (Gate 3b), and the builder was **not** run.

### The spec's "5 previously-registered D2 rows" did not exist
Before this task, `figure_asset` held **139 rows, all from the stale builder run** `db_build_20260701_114458` (the 1-July snapshot), all `qa_status=REVIEW`; **zero `D2_site_*` and zero current-ladder rows** (the old-gen review figures under `Output/figures/review/*`). Registering the 57 was therefore a **pure additive INSERT** (no updates, no collisions), not the "re-point the 5" flow the spec anticipated.

### Schema / checksum / row convention (recorded)
Columns (10): `figure_asset_id` **TEXT PK**, `path` **TEXT NOT NULL**, `title`, `domain`, `metric_id`, `recommended_use`, `checksum_sha256`, `path_exists` INTEGER, `qa_status`, `run_id`. Constraints: PK/UNIQUE on `figure_asset_id` only — **no FK, no UNIQUE on `path`, no CHECK, no triggers** (so dedup lives in registrar logic). Checksum = `sha256(path, max_bytes=50*1024*1024)` (first-50 MB; whole-file for these <1 MB PNGs). Existing rows use repo-relative posix paths (`Output/figures/...`) and the single-token vocab `qa_status='REVIEW'` / `recommended_use='review_or_reporting'` — the new rows match both.

### Paddock-coverage report → `Output/tables/d2_batch_paddock_coverage_20260720.csv`
16 distinct paddocks across the 57; **39 sites on a paddock, all 39 with their C1 checkerboard; 18 sites with no paddock.** Reconciles exactly with Gate 1 (39 covered + 18 NA). The 18: GA_018/024/031/032/033/037/038/042/044/045/047/048/049/059/060/061/062/064.

## Gate 3b (executed) — additive registration
- **Registrar:** `scripts/11_database/register_d2_site_dashboards.py` — self-contained; `check` (read-only) / `execute` modes. Idempotent on `figure_asset_id` (in-logic dedup + `INSERT OR IGNORE`), touches only the 57 `figure_d2_site_%` rows, rebuilds each row from the real `dashboards/` PNG and verifies `path_exists=1` + first-50-MB checksum before writing, explicit 10-column INSERT. PDFs not registered (out of scope; `report_asset` untouched). Builder never invoked.
- **Row values:** id `figure_d2_site_<plot_id>` · path `Output/figures/dashboards/D2_site_<plot_id>_slide_data.png` · title `D2 site <plot_id> slide data` · **domain `site_dashboard`** (set explicitly — the builder's `infer_domain` would yield NULL for these paths) · `metric_id` NULL · `recommended_use` `review_or_reporting` · first-50-MB `checksum_sha256` · `path_exists` 1 · `qa_status` `REVIEW` · `run_id` `d2_site_dashboard_batch_20260720`.
- **Result:** `before=139 → after=196, inserted=57`; `figure_d2_site_%` count = **57**, all `path_exists=1`, single `run_id`. **Idempotency proven** — re-run `check` reports "196 rows, would INSERT 0, skip 57". One DB write (mtime `2026-07-20T21:30:30`, size +24 KB). `v_database_release_checks` / `v_current_qa_issues` not affected by an additive figure insert.

## Deferred / follow-up (not this batch)
- **Source-side builder fix** (the broader shadow-registry problem): make a future rebuild register the current-ladder figures (filtered), so this additive registration isn't lost on the next build. Logged, not actioned here.
- **Cultural/spatial-review banner** (own task, wording/placement with Adrian / Tribal Council); when it lands, re-render all 57.
- **Shadow-input registration** (`background_flood_frequency_8058.tif`, the 4 `*_epsg8058.gpkg`, the 3 F5/F6 CSVs).
- **18 paddock-gap sites** — report-assembly stand-ins.
