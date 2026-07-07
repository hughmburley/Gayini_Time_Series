# Gayini Tier 0 — Build the annual analysis foundation

**Task ID:** `tier0-annual-stack`
**Branch:** `feature/tier0-annual-stack`
**Owner model:** Claude Code (agentic, iterative)
**Prepared:** 7 July 2026

---

## 0. Read this first

This is **one task with three gated sub-steps (0.1 → 0.2 → 0.3)**. Do them in order.
Each sub-step ends with an **acceptance gate** (assertions that must pass) and its **own
commit**. Open the pull request only after 0.3 passes.

**Why one task, not three:** the sub-steps share the CRS decision, the stack manifest and
the QA harness. Keeping them together stops those shared choices drifting.

### Fixed decisions (do not re-derive)
- **Target CRS:** `EPSG:28355` (GDA94 / MGA zone 55).
- **Reference grid:** the 25 m Landsat inundation grid (the native grid of the
  `lo_YYYY_YYYY.img` source rasters). All annual layers align to this grid.
- **Water year:** 1 July – 30 June. Water year `1988-1989` = source file `lo_1988_1989.img`.
- **Wet rule (current, pending Adrian confirmation in 0.2):** an annual inundation
  source cell is **wet** where its inundation count/value `> 0`; `0` = not inundated;
  documented no-data codes are masked to `NA` (not valid).

### Ground rules
- **Do not rebuild the pipeline.** Extend it. The 11-stage R workflow and the SQLite
  database are the source of truth.
- **Do not commit large binaries.** Run the `.gitignore` guard in Step A below before the
  first commit. Rasters, `*.sqlite`, `*.gpkg` and intermediate caches stay out of git.
- **Confirm paths before executing.** This repo runs on Windows at
  `D:/Github_repos/Gayini`. The root is resolved from the `GAYINI_ROOT` env var with that
  default. Before running anything, verify the key inputs below actually resolve, and stop
  with a clear message if they do not.
- **Work R-native.** Use `terra` for rasters and the existing `R/` function files. Match
  the existing code style (wrapper in `scripts/`, heavy logic in an `internal/` impl file).

### Key inputs to verify before starting
```
$GAYINI_ROOT/Input/landsat_inundation/lo_1988_1989.img  ... lo_2022_2023.img   # 35 files
$GAYINI_ROOT/Output/database/Gayini_Results.sqlite                              # source of truth
$GAYINI_ROOT/Output/rasters/inundation_background/*/annual/                     # cross-check only
$GAYINI_ROOT/data_intermediate/raster_catalog/raster_catalog.csv               # 741 assets
```

> **Note on the background rasters.** The existing
> `Output/rasters/inundation_background/` folders hold per-year wet/valid rasters but in
> **three overlapping windows** (`strict_1989_2014`, `sensitivity_1989_2015`,
> `recent_landsat_only_2014_2023`), labelled by calendar start year. They do **not** cover
> `1988-1989` and they overlap at 2014. **Do not stitch these three windows.** Build the
> unified stack directly from the **35 canonical `lo_YYYY_YYYY.img` source files**
> (the authoritative set registered in `stg_canonical_annual_inundation`). Use the
> background rasters only as an independent cross-check in the 0.1 gate.

---

## Step A — Repo hygiene (run once, before any commit)

```bash
cd "$GAYINI_ROOT"
git checkout -b feature/tier0-annual-stack

# Guard: keep large binaries out of version control
cat >> .gitignore <<'EOF'
# --- Tier 0 guard: data stays out of git ---
Output/rasters/
Output/database/*.sqlite
Output/database/*.gpkg
data_intermediate/
*.img
*.tif
EOF

git add .gitignore
git commit -m "Tier0: gitignore guard for large binaries"
```

If any of these paths are already tracked, note it and stop — do **not** `git rm` data
without confirming with the human first.

---

## Sub-step 0.1 — Unify the annual inundation stack (1988–2023)

**Goal.** Produce one continuous per-year `wet_any` / `valid_any` raster stack for all 35
water years on the pinned CRS and reference grid, with a manifest and alignment QA. This is
the keystone — sub-steps 1.1, 2.1 and 2.2 (later tiers) all depend on it.

**Suggested files**
- Wrapper: `scripts/03_inundation_products/05_build_unified_annual_stack.R`
- Impl:    `scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R`
- Reuse:   `R/inundation_pre_post_raster_functions.R`,
           `R/raster_catalog_functions.R`, `R/gayini_output_paths.R`

**Steps**
1. Enumerate the 35 source rasters `lo_1988_1989.img … lo_2022_2023.img`. Cross-check the
   list against `stg_canonical_annual_inundation.file_name` in the SQLite DB — the set must
   match exactly (35 files, one per water year, no gaps).
2. For each year, derive two binary layers from the source raster using the wet rule above:
   - `wet_any`   = 1 where inundation value/count `> 0`, else 0, `NA` where no-data;
   - `valid_any` = 1 where the cell has a valid (non-no-data) observation, else `NA`.
3. Reproject/resample each layer to `EPSG:28355` on the 25 m reference grid. Use
   **nearest-neighbour** (these are categorical/binary layers). The reference grid is the
   first source raster's grid after reprojection; every other year is aligned to it.
4. Assemble two multi-layer GeoTIFFs, layer names = water-year strings
   (`"1988-1989" … "2022-2023"`):
   - `Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif`   (35 layers)
   - `Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif` (35 layers)
5. Write `Output/csv/annual_stack_manifest.csv` — one row per water year:
   `water_year, source_file, crs_in, crs_out, resample_method, n_valid_cells,
   n_wet_cells, mean_occurrence_pct`.
6. Register both stacks in the `raster_asset` table (via the existing DB-registration
   helper or an idempotent insert) with populated CRS/extent metadata.

**Cross-check (informational, not a hard gate).** For the 25 overlapping years where a
`background_strict_1989_2014` annual raster exists, the per-year wet-cell counts from the
new stack should be within a small tolerance of the background raster's counts. Log any
year that diverges by more than, say, 5% of plot-area cells — that flags a wet-rule or
alignment discrepancy to review, it does not block the commit.

**Acceptance gate (must pass before commit)**
```r
library(terra)
wet   <- rast("Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif")
valid <- rast("Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif")
manifest <- readr::read_csv("Output/csv/annual_stack_manifest.csv")

stopifnot(
  nlyr(wet)   == 35L,
  nlyr(valid) == 35L,
  identical(names(wet), names(valid)),
  # single pinned CRS on both stacks
  crs(wet, describe = TRUE)$code == "28355",
  crs(valid, describe = TRUE)$code == "28355",
  # identical geometry
  compareGeom(wet, valid, stopOnError = FALSE, crs = TRUE, ext = TRUE, res = TRUE, rowcol = TRUE),
  # 25 m grid
  all(abs(res(wet) - 25) < 1e-6),
  # every water year present exactly once, ordered 1988-1989 .. 2022-2023
  length(unique(names(wet))) == 35L,
  names(wet)[1]  == "1988-1989",
  names(wet)[35] == "2022-2023",
  # no pixel wet without being valid, across all layers
  as.numeric(global(sum(wet == 1 & is.na(valid), na.rm = TRUE), "sum")[1, 1]) == 0,
  # manifest integrity
  nrow(manifest) == 35L,
  all(!is.na(manifest$n_valid_cells)),
  all(manifest$mean_occurrence_pct >= 0 & manifest$mean_occurrence_pct <= 100)
)
message("0.1 gate PASSED")
```

**Commit & push**
```bash
git add scripts/03_inundation_products/05_build_unified_annual_stack.R \
        scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R \
        R/ Output/csv/annual_stack_manifest.csv
git commit -m "Tier0.1: unify annual wet/valid stack 1988-2023 (EPSG:28355, 25m)"
git push -u origin feature/tier0-annual-stack
```
> The rasters themselves are gitignored; only code + manifest are committed. That is
> intended — the stack is a build artefact, reproducible from the committed code.

---

## Sub-step 0.2 — Resolve raster CRS / legend metadata debt

**Goal.** Populate CRS/extent for the raster assets that lack it, classify the assets with
null `metric_id`, and turn the `needs_legend_check` backlog into a short, reviewable
confirmation sheet for Adrian.

**Context (from the current DB build).**
- `raster_catalog.csv`: 741 assets, **435 flagged `needs_legend_check = TRUE`**.
- `raster_asset` table: 98 assets, **82 with null `metric_id`**, **98 lacking CRS/extent**
  (DB build `issue_0039`, `issue_0040` — no GDAL/proj transformer was available at build
  time; that is why this is deferred here).

**Suggested files**
- Wrapper: `scripts/01_prepare_inputs/03_populate_raster_metadata.R`
- Reuse:   `R/raster_catalog_functions.R`

**Steps**
1. With `terra`, read CRS + extent for every asset in `raster_asset` and write
   `crs_epsg`, `xmin/xmax/ymin/ymax` back to the table (and to the catalogue CSV).
2. Add filename-parser rules so the 82 null-`metric_id` assets are classified (extend the
   existing parser in `raster_catalog_functions.R`; do not hard-code one-offs where a rule
   generalises).
3. Group the `needs_legend_check` assets by **product family** (landsat_inundation,
   sentinel2_inundation, landsat_fractional_cover, modis_fractional_cover, …). For each
   family record the **assumed value semantics** (e.g. "count > 0 = wet") and whether it is
   **source-confirmed** or **assumed**.
4. Emit `Output/reports/legend_confirmation_for_adrian.md` — one row per product family:
   current assumption, count of assets, and the specific question Adrian needs to confirm.

**Acceptance gate (must pass before commit)**
```r
ra <- DBI::dbReadTable(con, "raster_asset")   # or read via the existing DB helper
stopifnot(
  sum(is.na(ra$crs_epsg)) == 0L,
  sum(is.na(ra$xmin))     == 0L,
  # metric_id coverage improved to >= 90% of assets
  mean(!is.na(ra$metric_id)) >= 0.90
)
stopifnot(file.exists("Output/reports/legend_confirmation_for_adrian.md"))
message("0.2 gate PASSED")
```

**Commit & push**
```bash
git add scripts/01_prepare_inputs/03_populate_raster_metadata.R \
        R/raster_catalog_functions.R \
        Output/reports/legend_confirmation_for_adrian.md
git commit -m "Tier0.2: populate raster CRS/extent + metric_id parser + legend sheet"
git push
```
> This does **not** require Adrian to answer before proceeding. It makes the outstanding
> legend questions explicit so they stop silently propagating into interpretation.

---

## Sub-step 0.3 — Expose the canonical annual plot-year analysis view

**Goal.** Expose the already-present annual data as one modelling-ready long table (a SQL
view), so Tier 1 modelling reads from a single stable source instead of re-joining ad hoc.

**Inputs (all already in the DB).**
- `fact_plot_year` — annual occurrence, wet_any, valid_any, valid_coverage.
- `stg_canonical_ground_cover_timeseries` — total veg / PV / NPV / bare (aggregate to
  water year using the existing `summary_method = mean`).
- `dim_plot` — vegetation group, `treed_plot_flag`, exclusion + review flags.

**Suggested files**
- Add to the database build: `scripts/11_database/` (the build script that creates views).
- Update the data dictionary: `Output/database/Gayini_Results_data_dictionary.xlsx`.

**Steps**
1. Create view `v_plot_year_analysis_spine`, one row per **plot × water year**, joining:
   annual occurrence (%), valid-coverage (%), wet_any, valid_any → water-year-aggregated
   total veg / PV / NPV / bare ground → `simplified_vegetation_group`, `treed_plot_flag`,
   `ground_cover_exclusion_flag`, `spatial_review_flag`.
2. Ground-cover aggregation to water year uses the mean, consistent with the canonical
   table, so the view matches existing products.
3. Add the view to the data dictionary and to `v_database_release_checks`.

**Acceptance gate (must pass before commit)**
```sql
-- exactly 66 plots x 35 inundation years
SELECT COUNT(*)                   FROM v_plot_year_analysis_spine;  -- expect 2310
SELECT COUNT(DISTINCT plot_id)    FROM v_plot_year_analysis_spine;  -- expect 66
SELECT COUNT(DISTINCT water_year) FROM v_plot_year_analysis_spine;  -- expect 35

-- occurrence within [0,100]; no wet-without-valid
SELECT COUNT(*) FROM v_plot_year_analysis_spine
  WHERE annual_occurrence_pct NOT BETWEEN 0 AND 100;                -- expect 0
SELECT COUNT(*) FROM v_plot_year_analysis_spine
  WHERE annual_wet_any = 1 AND annual_valid_any = 0;                -- expect 0

-- ground-cover join present for the expected ~99.8% overlap
SELECT ROUND(100.0 * SUM(CASE WHEN mean_total_veg_pct IS NOT NULL THEN 1 END) / COUNT(*), 1)
  FROM v_plot_year_analysis_spine;                                  -- expect >= 99.0
```
Run these and confirm each returns the expected value; fail the gate if any does not.

**Commit & push (then open PR)**
```bash
git add scripts/11_database/ Output/database/Gayini_Results_data_dictionary.xlsx
git commit -m "Tier0.3: add v_plot_year_analysis_spine modelling view + data dictionary"

# Tier 0 complete — open the PR for human review
git push
# then open a pull request: feature/tier0-annual-stack -> main
```

---

## Done criteria for Tier 0

- [ ] `.gitignore` guard committed; no data binaries tracked.
- [ ] 0.1 gate passed: unified 35-layer wet/valid stack, EPSG:28355, 25 m, manifest written.
- [ ] 0.2 gate passed: raster CRS/extent populated, ≥90% `metric_id` coverage, legend sheet emitted.
- [ ] 0.3 gate passed: `v_plot_year_analysis_spine` returns 2310 rows / 66 plots / 35 years, all checks clean.
- [ ] Three commits on `feature/tier0-annual-stack`; PR opened to `main` for human review.
- [ ] **Do not merge.** The human reviews the diffs and gate output, then merges.

## What NOT to do in Tier 0
- Do not build trend surfaces, rolling frequency, or any model — that is Tier 1.
- Do not change the wet rule beyond the fixed decision above; if the cross-check in 0.1
  suggests the rule is wrong, **log it in the legend sheet and flag for Adrian** rather
  than silently changing semantics.
- Do not touch the pre/post products; they remain as descriptive context.
- Do not auto-merge or push to `main`.

## If a gate fails
Stop at that sub-step. Report which assertion failed and the observed vs expected value.
Do not commit a sub-step whose gate has not passed, and do not proceed to the next
sub-step.
