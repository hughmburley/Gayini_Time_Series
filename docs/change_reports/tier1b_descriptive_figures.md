# Change report — Tier 1 · Task B: descriptive figures F2–F4

**Task spec:** `docs/Tier1_TaskB_descriptive_figures_F2_F4.md`
**Branch (intended):** `feature/tier1b-descriptive-figures` (not yet created — stopped at the acceptance gate)
**Base commit:** `6eaf415` (main, after Tier1A merge)
**Status:** acceptance gate PASSED; **not committed** — awaiting human review of the review-bundle zip.
**This report is INTERNAL ONLY and is not committed.**

---

## 1. What was built

Phase B of the ladder: three descriptive figure **pairs** (concept + real-data) describing the water
signal and the vegetation gradient, database-only (no CRS/raster/reproject). Everything is organised
around the **three non-treed communities as a dry→wet gradient**, Floodplain Woodland / Forest shown as
muted context.

## 2. Headline metric decision (RS-lead call, applied here)

**Headline occurrence metric = between-year annual wet frequency** — for each plot,
`100 × wet-valid years ÷ valid years` ("in what fraction of valid years was the plot wet at least
once"). Chosen because it is the annual **flood probability** the F8–F9 probability surface is built
toward, so a single metric runs the whole ladder (F2→F9) and the concept figure and headline no longer
contradict. Community means (verified from the spine): **Aeolian 9.1% · Riverine 22.3% · Inland
Floodplain 49.6%**, with Floodplain Woodland / Forest **44.1%** (context).

The spine's `annual_occurrence_pct` (within-year wet **coverage**, averaged) is **kept as a
clearly-named secondary "wet extent" metric** — not deleted: it drives the F3 secondary figure and a
column in the community summary.

## 3. Code committed (to be staged — NOT yet committed)

Three new files, all additive:

| File | Purpose |
|------|---------|
| `R/gayini_gradient_helpers.R` | Shared flooding-gradient vocabulary (`gayini_gradient_levels()` dry→wet order, `gayini_focus_levels()`, `gayini_gradient_palette()`), **`gayini_plot_between_year_frequency()`** (headline per-plot metric + secondary coverage), **`gayini_site_share_plots_wet()`** (site series), `gayini_apply_gradient_order()`, DB loaders, and idempotent figures-manifest helpers. Reused by F3/F4 and later rungs. |
| `R/gayini_descriptive_figures.R` | The figure builders (F2/F3/F4 × concept/data) + F3 coverage secondary + `gayini_save_figure()` (data → PNG+PDF, concept → SVG+PDF). |
| `scripts/07_figures_dashboards/10_build_descriptive_figures_f2_f4.R` | Orchestration: load spine → community summary (both metrics) → build figures → merge manifest → acceptance gate → package review bundle + zip. Stops before commit. |

## 4. The three figure pairs (all on the between-year headline)

**F2 — how annual wet frequency is computed**
- *Concept* (`F2_annual_occurrence_concept.svg/.pdf`): 35-cell water-year strip for GA_001 (wet Inland
  Floodplain, 32/35 → 91%) vs GA_009 (dry Aeolian, 4/35 → 11%). Occurrence = wet-valid years ÷ valid
  years — the headline metric it now teaches directly.
- *Data* (`F2_annual_occurrence_timeseries_data.png/.pdf`): **share of the 66 plots inundated in each
  water year**, 1988–2023 (between-year-consistent site series). Trough 2006-07 (1.5%), floods 2010-11
  (75.8%), 2016-17 (57.6%), 2022-23 (87.9%). Replaces the pre/post map.

**F3 — the data cube**
- *Concept* (`F3_data_cube_concept.svg/.pdf`): 66×35 wet/dry matrix (row share of wet years = flood
  frequency) with ground cover joined behind.
- *Data (headline)* (`F3_data_cube_heatmap_data.png/.pdf`): the real 66×35 **wet/dry** cube, rows
  ordered by the dry→wet gradient and by flood frequency within each community, treed block separated.
  Each row's blue share is that plot's flood frequency; flood years read as blue verticals.
- *Data (secondary)* (`F3_data_cube_coverage_secondary_data.png/.pdf`): the same cube coloured by
  within-year **wet-extent coverage** (`annual_occurrence_pct`) — clearly labelled SECONDARY, retained
  per the metric decision.

**F4 — inundation regime by community**
- *Concept* (`F4_inundation_regime_concept.svg/.pdf`): dry→wet gradient bands, anchors ~9 / 22 / 50%,
  context ~44%.
- *Data* (`F4_inundation_regime_by_community_data.png/.pdf`): distribution of **per-plot flood
  frequency** by community (box + jitter, one point per plot; `ggridges` unavailable so box+jitter is
  the spec's allowed alternative), three non-treed focus in gradient order, Woodland/Forest muted.
  Means annotated (9 / 22 / 50 / 44%).

## 5. Acceptance gate — all assertions PASS

| Gate check | Result |
|---|---|
| `nrow(spine)==2310`, `n_distinct(plot_id)==66`, `n water_years==35` | ✓ |
| `annual_occurrence_pct ∈ [0,100]` | ✓ |
| headline `round(mean) Aeolian ≤ 12` | ✓ (9.1 → 9) |
| headline `round(mean) Riverine ∈ [18,26]` | ✓ (22.3 → 22) |
| headline `round(mean) Inland Floodplain ≥ 45` | ✓ (49.6 → 50) |
| strict dry→wet ordering Aeolian < Riverine < Inland Floodplain | ✓ |
| F2/F3/F4 each have `concept` + `data` manifest rows | ✓ |
| `Output/review_bundles/tier1b_descriptive_figures.zip` exists | ✓ |

(Gate thresholds were updated from the original within-year numbers to the between-year headline.)

## 6. Generated artefacts (gitignored — reproducible from code, NOT committed)

- `Output/figures/F2_* F3_* F4_*` — three pairs + the F3 coverage secondary (SVG/PDF concepts, PNG/PDF
  data).
- `Output/figures/figures_manifest.csv` — F2–F4 rows merged (F1 rows from Task A preserved). Columns
  `step, kind, path, inputs, crs`; the F3 secondary rows use `kind = data-secondary`.
- `Output/diagnostics/community_occurrence_summary.csv` — per community: n_plots, headline flood
  frequency (mean + median), secondary wet-extent coverage.
- `Output/review_bundles/tier1b_descriptive_figures/` + `.zip` — figures, diagnostics, manifest, task
  manifest rows, change-report copy.

## 7. Data notes

- `v_plot_timeseries_inundation_annual` carries **37 rows/plot**, not 35: two trailing Sentinel-era
  placeholders (2023-24, 2024-25, NULL valid/wet, `support_class = 3`). The F2 concept restricts to the
  35 canonical water years; the spine itself is clean at 35. (Sharpens Adrian Q3 — the sensor-era
  support question — but no action needed here.)
- All 66 plots have ≥1 valid year, so the between-year frequency is defined for every plot.

## 8. Explicitly NOT part of this task

- No pre/post products (F2 data replaces that framing).
- No CRS / raster / reprojection — database-only; independent of Task A.
- No plot-level modelling — these figures describe the water and the gradient only.
- No commit / branch / PR yet — stopped at the acceptance gate.
- Change report is **not** staged (standing preference).

## 9. How to reproduce

```
Rscript scripts/07_figures_dashboards/10_build_descriptive_figures_f2_f4.R
```
