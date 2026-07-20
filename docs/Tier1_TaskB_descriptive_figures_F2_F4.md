# Tier 1 · Task B — Describe the water & the cube (F2–F4)

**Branch:** `feature/tier1b-descriptive-figures`
**Type:** one Claude Code task · branch-and-PR into `main`, human-reviewed before merge
**Depends on:** Tier 0 spine only (`Gayini_Results.sqlite`, on `main`). **Does NOT depend on Task A** — this rung is database-only, no raster or CRS work.

---

## Why this task

Phase B of the ladder: the simplest, most legible description of the water signal, before any sampling, trend or surface. Three figures that a non-specialist can read in order — how the metric is built, the whole dataset at a glance, and the vegetation gradient the rest of the analysis is organized around. Every rung ships a **figure pair** (a concept explainer + the real-data figure).

**Organizing axis — the three-class flooding gradient.** The analysis focuses on the three **non-treed** communities, treated as a dry→wet gradient (mean annual occurrence, verified from the database):

- Aeolian Chenopod Shrublands (16 plots) — **dry**, ~4% (90% of plot-years never flood)
- Riverine Chenopod Shrublands (19) — **a bit wetter**, ~12%
- Inland Floodplain Shrublands / Swamps (22) — **wet**, ~31%

Floodplain Woodland / Forest (9 treed plots, red gums, ~27%) is **shown as context but excluded** from the analytical focus — canopy confounds ground cover. No pre/post products anywhere in this task.

## Inputs (all from `Gayini_Results.sqlite`)

- `v_plot_year_analysis_spine` — plot × water year: `annual_occurrence_pct`, `annual_wet_any`, `annual_valid_any`, `annual_valid_coverage_pct`, `mean_total_veg_pct`, `simplified_vegetation_group`, `treed_plot_flag`
- `v_plot_timeseries_inundation_annual` — per-plot annual series incl. `valid_coverage_pct`, `support_class`
- `dim_plot` — community, treed flag, ordering

## The three figure pairs

### F2 — How annual occurrence is computed
- **Concept:** a strip of 35 water-year cells for one real plot, each cell coloured wet / dry / masked, with the fraction `occurrence = 100 × wet-valid-years ÷ valid-years` computed beside it. Use an actual sequence from `v_plot_timeseries_inundation_annual` (pick one wet Inland Floodplain plot and one dry Aeolian plot to contrast). Agreed schematic style.
- **Data:** site-wide annual occurrence time series, 1988–2023 (one point per water year), drought trough (2006-07) and big floods (2010-11, 2016-17, 2022-23) annotated. This **replaces the pre/post map** as the "has inundation changed" figure.

### F3 — The data cube
- **Concept:** a small schematic of the 66 × 35 plot-year matrix, showing one axis = plots (grouped by community), other = water years, cell = occurrence, with the ground-cover layer joined behind it.
- **Data:** the real 66 × 35 occurrence heatmap, **rows ordered by the gradient** (Aeolian → Riverine → Inland Floodplain → Woodland/Forest, treed block visually separated), columns = water years. This is the whole dataset in one view.

### F4 — Inundation regime by vegetation community
- **Concept:** the dry→wet gradient bands (the three non-treed communities as a low→high inundation strip).
- **Data:** distribution of annual occurrence per community (ridgeline or box + jitter), three non-treed communities as the focus in gradient order, Woodland/Forest drawn in a muted "context" style. Annotate each with its mean (4% / 12% / 31%).

## Steps

1. Load the spine; assert 2,310 rows, 66 plots, 35 water years.
2. Define the community order and colour map once (gradient order; treed = muted/context) in a shared helper so F3/F4 and later rungs reuse it.
3. Build each figure pair (concept + data); save PNG + PDF for data figures, SVG + PDF for concept figures.
4. Register all six figures in `Output/figures/figures_manifest.csv` (`step, kind, path, inputs, crs`; crs = `n/a` for these DB figures).
5. Write `docs/change_reports/tier1b_descriptive_figures.md` (local, not committed).
6. **Package for review** (standing convention): copy this task's deliverables into `Output/review_bundles/tier1b_descriptive_figures/` (figures/, diagnostics/, manifest rows, change_report copy) and zip to `Output/review_bundles/tier1b_descriptive_figures.zip`.

## Acceptance gate (must pass before commit)

```r
stopifnot(
  nrow(spine) == 2310, dplyr::n_distinct(spine$plot_id) == 66,
  length(unique(spine$water_year)) == 35,
  all(spine$annual_occurrence_pct >= 0 & spine$annual_occurrence_pct <= 100)
)
# F4 gradient sanity — non-treed community means recover the dry->wet order
m <- tapply(spine$annual_occurrence_pct, spine$simplified_vegetation_group, mean)
stopifnot(
  round(m["Aeolian Chenopod Shrublands"])            <= 6,
  round(m["Riverine Chenopod Shrublands"])  |> dplyr::between(9, 15),
  round(m["Inland Floodplain Shrublands / Swamps"])  >= 28
)
# figure pairs + manifest + review bundle exist
for (f in c("F2","F3","F4")) stopifnot(
  any(grepl(paste0(f,".*concept"), manifest$path)),
  any(grepl(paste0(f,".*data"),    manifest$path))
)
stopifnot(file.exists("Output/review_bundles/tier1b_descriptive_figures.zip"))
```

## Commit & push

```
git add scripts/ R/ Output/figures/ Output/review_bundles/
git commit -m "Tier1B: descriptive figures F2-F4 on the three-class flooding gradient"
git push   # then open PR feature/tier1b-descriptive-figures -> main
```
Do **not** stage `docs/change_reports/` (standing preference — reports stay local).

## Notes

- Database-only: no reprojection, no raster, no CRS. Runs independently of Task A.
- Plots are reference anchors; these figures describe the water and the gradient, not plot-level effects.
- Stop at the acceptance gate; the review-bundle zip is what we open to assess the run.
