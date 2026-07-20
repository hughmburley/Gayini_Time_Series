# Gayini repo stocktake — pre sub-sampling round (F5 rebalance + F6 re-run)

Read-only audit, 2026-07-13. Nothing refactored. Held at the gate.
Scope: readiness for a proportional-allocation F5 rebalance + ~100-draw Monte-Carlo F6 re-run.

---

## 0. Headline verdict

The **data spine and DB are in a clean, fully-mutated, F5-ready state right now.** The spine reproduces the headline (9.1/22.3/49.6/44.1) and the F7 gradient (0.17→0.26→0.42) from the shipped DB; all post-build objects are present; near-plot pixel headroom is *far* above any target draw size in all 9 strata.

Two things gate a *clean, reproducible* rebalance (neither blocks the analysis today, both are latent traps):
1. **No guard** asserts the post-build objects survived a rebuild, and the canonical `run_order` CSVs are **stale** (they document the retired pre/post pipeline, not the current F-ladder + DB builder + post-build mutations). **This is the top reproducibility risk.**
2. The **F5 draw takes a single scalar `N_PER_STRATUM`**, not a per-stratum allocation, and has **no Monte-Carlo loop** — both are required for the rebalance and need a small, well-scoped code change. Downstream gates hardcode `360`/`40`.

Everything else is hygiene.

---

## 1. Active vs archivable vs supplementary inventory

Tally: **~57 ACTIVE · ~28 ARCHIVABLE · ~11 SUPPLEMENTARY (MER)**.

### 1a. ARCHIVABLE — retired pre/post (2019-2020 management split), safe to move *except where noted*

Scripts:
- `scripts/03_inundation_products/01_build_prepost_inundation_products.R` + `internal/01_build_pre_post_inundation_frequency_rasters_impl.R`
- `scripts/03_inundation_products/02_extract_prepost_inundation_to_plots.R` + `internal/02_reextract_prepost_inundation_to_plots_only_impl.R`
- `scripts/03_inundation_products/03_curate_rs_hydrology_analysis_base.R` + `internal/03_curate_rs_analysis_base_impl.R` — **⚠ feeds the DB build** (curated analysis base → staging). Moving it changes what the Python builder ingests.
- `scripts/05_ground_cover/01_prepare_ground_cover_response_and_review_tables.R` + `internal/01_ground_cover_prepost_response_impl.R`
- `scripts/07_figures_dashboards/00_run_task15_figure_refresh.R`, `01_make_review_figures_and_dashboards.R`, `03_prepare_plot_context_flags.R` (⚠ produces the treed/exclusion flags reused by F7 — extract that before archiving), `04_integrate_gauge_context_review_figures.R`, `06_refresh_main_deck_figures.R`, `internal/01_make_adrian_review_png_assets_impl.R`, `internal/02_plot_rs_gauge_context_impl.R`
- `scripts/08_review_packages/01`, `02`
- `scripts/09_qa/01_check_prepost_inundation_products.R` + `internal/01`, `09_qa/internal/02_check_curated_outputs_impl.R`
- `scripts/_deprecated/01_lag_diagnostics_inundation_gc.R` (already deprecated; superseded by F7 @1839a2e)

R:
- `R/gayini_dashboard_figures.R`, `R/gayini_map_inundation_figures.R`, `R/gayini_plot_context_figures.R`, `R/gayini_plot_ground_cover_figures.R`, `R/gayini_plot_hydrology_figures.R`, `R/gayini_review_figure_functions.R`, `R/step7_figure_helpers.R`
- `R/gayini_analysis_base_functions.R` — **⚠ constructs the 5-class `vegetation_adrian_group`** (the retired lineage's origin) *and* holds generic helpers reused elsewhere.
- `R/gayini_figure_manifest.R` — Task-15 helpers **but** the generic manifest/contact-sheet fns are reused by active figures.
- `R/inundation_pre_post_raster_functions.R` — **⚠ HARD BLOCKER for a clean move:** `gayini_make_binary_inundation_layers()` (the confirmed wet rule) lives here and is sourced by the ACTIVE unified-stack impl `05`. Extract the wet-rule fn to a neutral file before archiving.
- `R/rs_gauge_join_functions.R` — defines `pre_post_period_from_date` + `management_change_date`; check active callers before moving.
- `R/gayini_time_helpers.R` (ACTIVE) still defines `gayini_management_transition_date (2019-07-01)` — vestigial, harmless.

### 1b. SUPPLEMENTARY — MER / "annual maximum observed wet footprint" (KEEP, do not archive)
`scripts/06_mer/01–08` (+ `MER_threshold_code.txt`, `04_create_mer_methods_note.py`); `R/gayini_mer_helpers.R`, `R/gayini_mer_inundation_functions.R`, `R/gayini_mer_raster_functions.R`. 67 MER rasters registered in `raster_asset` (product `mer_inundation`).

### 1c. ACTIVE — the live ladder
F1 `01_prepare_inputs/04…`; extraction `02_extract_heavy/*`; annual stack `03_inundation_products/05` (+impl); F5 `06` + `07_figures_dashboards/11`; F6 `07`; F7 `08`; pixel census `09`; checkerboard `10`; F2–F4 `07_figures_dashboards/10`; dashboards `12`; DB builder `11_database/01`; Tier-0 raster metadata `01_prepare_inputs/03`. R: `gayini_area_map`, `gayini_dashboard_{compose,panels}`, `gayini_descriptive_figures`, `gayini_f5_legibility_figures`, `gayini_gradient_helpers`, `gayini_ground_cover_response_*`, `gayini_pixel_census_functions`, `gayini_sampling_design_map`, `gayini_spatial_8058_functions`, `gayini_stratified_sampling_*`, `gayini_trend_test_*`, `gayini_veg_regime_functions`, + infra/extraction helpers.

### 1d. Archive-convention split — inconsistent, needs reconciliation
- `scripts/_deprecated/` **exists** — 1 file (`01_lag_diagnostics_inundation_gc.R`), whose header still self-cites the stale path `scripts/10_downstream_optional/…`.
- `scripts/archive/` **does NOT exist** — but the smoke test *enforces its absence*, and `scripts/README.md` (lines 21-22) documents both `10_downstream_optional/` and `archive/`, neither of which exists.
- A **repo-level** `archive/` does exist (`archive/code_pre_refactor_*`, `repo_cleanup_*`, etc.) — provenance actually lives there, plus `docs/archive/`, `Output/_archive`.
- **Reconciliation needed:** CLAUDE.md says "archived scripts go to `scripts/archive/`; reconcile any `scripts/_deprecated/` into it." But the smoke test asserts `scripts/archive/` is *absent*. These two rules contradict. **Decision required (Adrian/Hugh):** either (a) rename the convention to `scripts/_deprecated/` and update CLAUDE.md + README, or (b) create `scripts/archive/`, move `_deprecated`'s file into it, and flip the smoke-test assertion. Pick one before moving anything.

### 1e. Smoke-test `expected_outputs` still lists retired/legacy artefacts (`run_spine_smoke_test.R:125-130`)
```
Output/csv/plot_rs_analysis_base.csv                                    # curated pre/post base
Output/csv/10a_ground_cover_prepost_plot_summary.csv                    # pre/post
Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_summary.csv   # MER (supplementary — keep)
Output/reports/Gayini_ppt_asset_register.csv
```
These are **warning-severity** and use legacy flat paths (the builder now reads `Output/csv/canonical/…`). If pre/post is archived, drop the two pre/post entries and repoint the MER entry; keep MER.

---

## 2. Post-build DB mutation ordering — TOP REPRODUCIBILITY RISK

### 2a. Required sequence (any full rebuild wipes everything except the spine view)
The Python builder `scripts/11_database/01_build_results_database.py` does `path.unlink()` + full rebuild, has **no GDAL**, and creates: the spine view (survives), staging, generic `raster_asset` rows (NULL CRS/extent), ~20 views. It does **NOT** create: populated raster metadata, the annual-stack registration, or the census. Those are post-build R mutations:

```
1. scripts/11_database/01_build_results_database.py     (unlink + rebuild; spine view lives here)
2. scripts/03_inundation_products/05_build_unified_annual_stack.R   (writes annual_{wet,valid}_any tifs; registers stack_annual_* rows)
3. scripts/01_prepare_inputs/03_populate_raster_metadata.R          (terra → CRS/extent/metric/legend on raster_asset)
4. scripts/03_inundation_products/09_build_pixel_census_view.R      (census_stratum + v_pixel_census_by_veg_regime; reads annual stack)
   (+ 10_build_veg_regime_checkerboard.R for the dim_metric + class raster, if refreshing C1)
```
**⚠ Ordering ambiguity to pin:** the script headers disagree on steps 2↔3 (`09`'s header says "builder → 03 → 05 → 09"; but `05` creates the stack rows whose CRS `03` populates, so `05` must precede `03`). Verified current DB has stack rows with `crs_epsg=28355`, so the working order is **builder → 05 → 03 → 09**. Pin this in one place.

### 2b. Current state (verified from the shipped DB, build run `db_build_20260701_114458`, mutations applied through 2026-07-10)
| Object | Expected | Present? |
|---|---|---|
| `raster_asset` rows | populated | **100** ✓ |
| annual stack registered | 2 rows | `stack_annual_wet_any_1988_2023`, `stack_annual_valid_any_1988_2023` (CRS 28355) ✓ |
| `census_stratum` table | 11 rows | **11** ✓ |
| `v_pixel_census_by_veg_regime` | 11 rows | **11** ✓ |
| `v_plot_year_analysis_spine` | 2310 rows | **2310** ✓ (release check `v_plot_year_analysis_spine_shape` = PASS) |

### 2c. Guard status — **NONE EXISTS**
No script asserts, post-rebuild, that these objects exist. Enforcement is prose only (CLAUDE.md:37, tier0 docs). The builder's own QA only counts rows it just inserted; the smoke test checks files/folders/parseability, not DB objects.

**⚠ Compounding gap:** `docs/run_order/01_full_rebuild_workflow.csv` (the canonical order the smoke test validates for existence) **omits the DB builder and all post-build steps entirely** — it stops at the retired pre/post curation (step 13). There is *no* current run-order doc for the F-ladder + rebuild + post-build mutations.

**Recommended (report-only — proposed, not applied):** add a `post_build_guard.R` (or extend the smoke test's `lightweight_review` mode) asserting: `raster_asset` COUNT>0 with non-null CRS on the stack rows; both `stack_annual_*` rows present; `census_stratum` = 11 & `v_pixel_census_by_veg_regime` = 11; spine = 2310. And add a current `run_order` CSV for the F-ladder pipeline. See the guard sketch in §6.

### 2d. Stale QA view (minor)
`v_current_qa_issues` still reports `qa_0039`/`qa_0040` ("82/98 null metric_id", "98/98 lack CRS/extent") — these were fixed by the post-build `03` step but the QA snapshot is frozen at build time and never refreshed. A reader trusting `v_current_qa_issues` sees a worse state than reality. Note when interpreting.

---

## 3. Spine validation + demo (proposed scaffolds — not committed)

`run_spine_smoke_test.R` validates repo **structure** only (folders, file existence, `parse()`-ability, run-order CSV existence). It does **not** touch the DB. Two additions proposed:

### 3a. Spine data-validation (companion or new smoke-test block) — assertions, all verified passing today
- `v_plot_year_analysis_spine` = **2310 rows** across **66 plots × 35 water years** (1988-1989 … 2022-2023). ✓
- 4-class grouping present: `simplified_vegetation_group` ∈ {Aeolian, Riverine, Inland Floodplain, Floodplain Woodland/Forest}. ✓
- **No leakage in the spine/analysis views:** `vegetation_adrian_group`, `period`, `drier_post` absent from the spine. ✓ (They persist only in upstream `stg_*` staging + `bio_rs_loocb_*` + `stg_mer_*` — see §5.)
- `census_stratum` present (11 rows) & reconciles to `veg_regime_class_8058.tif` (diff = 0, verified §4).
- Headline reproduces: Aeolian 9.1 · Riverine 22.3 · Inland 49.6 · Woodland 44.1.

### 3b. `demo_spine.R` — read-only, no raster, ~1s, reproduces the headline + F7 gradient from the shipped DB
Verified output today (pure-SQL, no packages beyond DBI/RSQLite):
- Headline between-year flood freq: **9.1 / 22.3 / 49.6 / 44.1**.
- F7 same-year veg~intensity community median r (52 usable non-treed plots): **0.172 (Aeolian, n=11) → 0.257 (Riverine, n=19) → 0.421 (Inland, n=22)** — the dry→wet strengthening, from the spine alone.

Ready-to-drop content is in §6.

---

## 4. Sampling readiness (the key rebalance output)

### 4a. Can F5 take per-stratum N + a seed loop? — **Partially. Needs a small change.**
- **N:** `gayini_draw_stratified_sample(..., n_per_stratum, ..., seed)` consumes `n_per_stratum` as a **single scalar** (used at `gayini_stratified_sampling_functions.R:262,284-288,302-303`) applied to every community×band cell. **No per-stratum vector/lookup.** Proportional allocation needs this function modified to accept a named `(community,band) → N` lookup. Low-risk, localised change.
- **Seed:** ✓ isolated — one `set.seed(seed)` at the top (`:234`), the only RNG consumer is `sample.int` (`:285`). Fully wrappable in a `for (s in seeds)` Monte-Carlo loop. **Caveats:** point IDs `SP_%04d` (`:326`) collide across draws (tag per seed); the F5 script writes one fixed `stratified_sample_points.gpkg` and gates one draw (no per-seed fan-out).
- **Downstream gate collisions:** the census gate hardcodes `total_points_360 == 360L` and `focus_strata_9`/`strata_count_11` (`09_…R:257-264`); F5 constant `N_PER_STRATUM=40`. A rebalance changing N breaks the `360` assertion — update it to `sum(allocation)`.
- Constants (`06_…f5.R:48-53`): `NEIGHBOURHOOD_RADIUS=2000`, `EXCLUSION_BUFFER=100`, `N_PER_STRATUM=40`, `MIN_VALID_YEARS=25`, `SEED=20260709`, `TARGET_CRS=8058`.

### 4b. Is `census_stratum` current against the annual stack? — **YES.**
`09` recomputes the flood-frequency surface **live** from the same `annual_{wet,valid}_any_1988_2023.tif` that F5/F6 read (via `gayini_background_flood_frequency`, not a cached tif), bands with the same `regime_band_breaks.csv` terciles. Independent raster recount reconciles to `census_stratum` **exactly (diff = 0 on all 11 rows)** — confirming the census and `veg_regime_class_8058.tif` are current against the stack.

### 4c. Near-plot valid-pixel headroom per stratum (within 2 km of plots) — **the number that gates allocation**

Two independent measures, both consistent, both say **headroom is not binding in any stratum**:

| Stratum (community × band) | F5 candidate pool¹ | Independent recount² | % of stratum reachable | Total valid px (whole farm) |
|---|---:|---:|---:|---:|
| Aeolian · low  | 16,751 | 20,678 | 77.2% | 26,786 |
| Aeolian · mid  | 12,086 | 16,104 | 67.9% | 23,720 |
| Aeolian · high | 18,002 | 21,461 | 79.4% | 27,038 |
| Riverine · low  | 34,163 | 40,269 | 61.2% | 65,781 |
| Riverine · mid  | 24,576 | 37,704 | 58.6% | 64,326 |
| Riverine · high | 19,293 | 40,553 | 63.8% | 63,551 |
| Inland · low  | 31,186 | 65,957 | 27.7% | 238,328 |
| Inland · mid  | 61,039 | 105,738 | 44.1% | 239,666 |
| Inland · high | 76,385 | 112,401 | 46.9% | 239,635 |

¹ `n_candidate_pixels` from `Output/diagnostics/sample_summary.csv` — the exact F5 drawable pool: within 2 km of plot footprints ∩ community, valid_years ≥ 25, minus the 100 m exclusion hole.
² `veg_regime_class_8058.tif` cells of each stratum code within 2 km of plot footprints (no exclusion/strict-within filters) — an upper-bound cross-check.

**Interpretation vs target draw sizes (~50 / 100–500 / 500–1,000):**
- **Every stratum clears the top target (500–1,000) by 12×–76×.** The smallest pool is Aeolian·mid at **12,086** candidate pixels ≈ 12× the 1,000 ceiling.
- So the 2 km radius does **not** need relaxing for any stratum to hit even the largest draw. Headroom is *not* the binding constraint.
- The real constraint at large N is **spatial independence** (pixel is 0.0624 ha; 1,000 points from 12k pixels means ~8% of pixels sampled — fine, but if minimum inter-point spacing is imposed, re-check Aeolian·mid). Reachability is lowest in the large Inland strata (28-47%) because they extend far beyond the plot network, but absolute pools (66k-112k) are the largest of all.

---

## 5. Naming hygiene flags

**Spine + analysis views are clean** — no `vegetation_adrian_group`/`period`/`drier_post`. Residuals live only in the retired/supplementary lineage plus two genuine collisions to fix:

- **`vegetation_adrian_group`** — 15 files, all ARCHIVABLE or SUPPLEMENTARY, **except it is baked into the DB build**: `scripts/11_database/01_build_results_database.py:929,2471` ingests `row.get("vegetation_adrian_group")` into staging, so it lands in `stg_canonical_*`, `stg_mer_*`, `bio_rs_loocb_joined_plot_summary` (confirmed by column scan). Not in any analysis view — tolerable as upstream provenance, but a **decision:** stop ingesting it, or accept it as staging-only.
- **`drier_post`** — only in ARCHIVABLE/SUPPLEMENTARY files (`step7_figure_helpers`, `gayini_dashboard_figures`, `gayini_mer_inundation_functions`, pre/post impls). Active dashboard code references it only to *ban* it.
- **Bare "annual_occurrence" that can read as the headline (fix):**
  - `R/gayini_descriptive_figures.R:136,188` — F2 figure **filenames** `F2_annual_occurrence_concept` / `F2_annual_occurrence_timeseries_data`, but the plotted quantity is the **between-year headline flood frequency** (content `:120-122,141,174-176`). Filename/metric collision on disk — rename the F2 outputs to `F2_annual_flood_frequency_*`.
  - `scripts/11_database/01_build_results_database.py:130` — DB metric_id `inundation_annual_occurrence_pct` shipped as a metric (documented "not hydroperiod" but **not marked secondary**). Consider a `secondary`/`wet_extent` tag in `dim_metric`.
- **Correctly labelled SECONDARY (no action):** every *analysis input* use of `annual_occurrence_pct` in active code (F7, `gayini_gradient_helpers`, dashboard panels, descriptive figures) is explicitly annotated "SECONDARY / within-year wet-extent intensity — not the headline."

---

## 6. Proposed artefacts (report-only — ready to build on your go-ahead)

### 6a. `demo_spine.R` (read-only, no raster) — proposed content
```r
# demo_spine.R — read-only headline + F7 reproduction from the shipped DB (~1s, no rasters)
suppressMessages({library(DBI); library(RSQLite)})
db <- "Output/database/Gayini_Results.sqlite"
con <- dbConnect(SQLite(), db); on.exit(dbDisconnect(con))
sp <- dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine")
stopifnot(nrow(sp) == 2310L,
          !any(c("period","vegetation_adrian_group") %in% names(sp)))
# Headline: between-year annual flood frequency = 100 * wet-valid-years / valid-years
hl <- aggregate(cbind(annual_wet_any, annual_valid_any) ~ simplified_vegetation_group,
                data = sp, sum)
hl$flood_freq_pct <- round(100 * hl$annual_wet_any / hl$annual_valid_any, 1)
print(hl[, c("simplified_vegetation_group","flood_freq_pct")])
# expect Aeolian 9.1 / Riverine 22.3 / Inland 49.6 / Woodland 44.1
# F7 same-year gradient: median within-plot r(total_veg, annual_occurrence_pct) by community
u <- sp[sp$treed_plot_flag==0 & sp$ground_cover_exclusion_flag==0 &
        !is.na(sp$annual_occurrence_pct) & !is.na(sp$mean_total_veg_pct), ]
r_by_plot <- sapply(split(u, u$plot_id), function(d)
  if (nrow(d) >= 3 && sd(d$annual_occurrence_pct) > 0 && sd(d$mean_total_veg_pct) > 0)
    cor(d$annual_occurrence_pct, d$mean_total_veg_pct) else NA_real_)
comm <- u$simplified_vegetation_group[match(names(r_by_plot), u$plot_id)]
print(tapply(r_by_plot, comm, median, na.rm = TRUE))
# expect Aeolian 0.17 / Riverine 0.26 / Inland 0.42
```

### 6b. Post-build guard (sketch) — assertions to enforce after any rebuild
```r
stopifnot(
  DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM raster_asset")$n > 0L,
  DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM raster_asset
     WHERE path LIKE '%annual_wet_any_1988_2023%' AND crs_epsg IS NOT NULL")$n == 1L,
  DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM census_stratum")$n == 11L,
  DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM sqlite_master
     WHERE name='v_pixel_census_by_veg_regime'")$n == 1L,
  DBI::dbGetQuery(con,"SELECT COUNT(*) n FROM v_plot_year_analysis_spine")$n == 2310L)
```

---

## 7. Blockers for a clean F5-rebalance + F6-rerun

| # | Blocker | Severity | Fix |
|---|---|---|---|
| B1 | F5 draw takes scalar N only — no proportional (per-stratum) allocation | **HARD** (rebalance can't proceed) | Add `(community,band)→N` lookup to `gayini_draw_stratified_sample`; consume at :262,:284-288,:302-303 |
| B2 | No Monte-Carlo loop; point IDs collide across seeds; single fixed output path | **HARD** (100-draw re-run) | Wrap in seed loop; tag `SP_<seed>_%04d`; fan out per-seed outputs/summary |
| B3 | Downstream gates hardcode `360`/`40`/`focus_strata_9` | **MED** (gates fail on new N) | Replace `total_points_360==360` with `==sum(allocation)`; parametrise |
| B4 | No post-build guard + stale `run_order` CSVs omit the whole current pipeline | **HARD (reproducibility)** | Add guard (§6b) + a current F-ladder run_order CSV before any rebuild |
| B5 | Archive-convention contradiction (`scripts/archive/` required by CLAUDE.md but banned by smoke test) | **MED** (blocks archiving) | Pick one convention; update CLAUDE.md/README/smoke test together |
| B6 | Wet-rule fn `gayini_make_binary_inundation_layers()` sits in an ARCHIVABLE pre/post file sourced by the ACTIVE stack | **MED** (can't archive cleanly) | Extract wet-rule fn to a neutral file first |
| B7 | F5/F6 rely on `background_flood_frequency_8058.tif` + `veg_regime_class_8058.tif`, **not registered in `raster_asset`** and Output/ is gitignored | **LOW** (reproducible from code, but uncatalogued) | Optionally register in `raster_asset`; else rely on rebuild-from-code |

**Not blockers (confirmed clean):** spine shape/leakage; census currency vs stack; per-stratum headroom (ample in all 9); headline + F7 reproduce from DB.

---

*Report only. No files moved, no code changed, no commits. Awaiting review before any of §6 / §7 fixes.*
