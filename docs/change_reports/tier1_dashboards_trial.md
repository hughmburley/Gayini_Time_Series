# Change report — Tier 1 · Dashboards Phase 1 (trial)

**Branch:** `feature/tier1e-f7-groundcover-response`
**Date:** 2026-07-10
**Scope:** Phase 1 (trial) only — the composer + modular panels + all three layouts on a subset, plus one A3. Phase 2 production (all 21 paddocks / 66 sites / 9 strata) is held until a layout is picked per set.

## What was built

| Artefact | Path |
|---|---|
| Map-core refactor | `gayini_area_map_core()` in `R/gayini_area_map.R` (extracted from `gayini_plot_area_map`, non-breaking) |
| Panels | `R/gayini_dashboard_panels.R` (map · annual flooding · total veg · veg response · baseline gauge · where-it-sits · site gauge flow) |
| Composer + resolvers | `R/gayini_dashboard_compose.R` (context loader, site/paddock/stratum resolvers, layouts A/B/C, slide + A3 formats) |
| Compact key | `gayini_bivariate_legend_mini()` in `R/gayini_veg_regime_functions.R` |
| Driver | `scripts/07_figures_dashboards/12_build_dashboards_trial.R` |
| Figures | `Output/figures/D{1,2,3}_*_{A,B,C}_slide_data.*` + `D1_paddock_Bala_29ca_C_a3_landscape_data.*` (37 figures, 74 manifest rows) |
| QA | `Output/diagnostics/dashboards_trial_qa.json` (all_pass) |
| Bundle | `Output/review_bundles/tier1_dashboards_trial.zip` |

## Reuse (done first, not forked)

- **Map panels** call `gayini_area_map_core()` — the bare map extracted from the C1 composer (background fill + heavy outline + light neighbours + `extra_layers` for the site radius ring / stratum highlight). `gayini_plot_area_map` now wraps the same core; **C1 re-run reconciles at diff = 0**, so the extraction is non-breaking.
- **"Where it sits"** reuses `gayini_plot_between_year_frequency(spine)` + the gradient palette — ABSOLUTE between-year flood frequency boxed by community, with the unit marked and a descriptive Kruskal–Wallis caption (new highlight + KW layers added).
- **Vegetation response** reuses the F7 masked plot-year scatter (`annual_occurrence_pct` × total veg) + the community `lm` fit, filtered to the unit's plots with the plot count stated.

## Unit types & layouts

- **D2 site** (radius neighbourhood, ring drawn; gauge-flow context) → GA_001, GA_003, GA_019, GA_052, GA_032.
- **D1 paddock** (C1 checkerboard map; flooding over the paddock's valid pixels; veg falls back to community context when no in-paddock plots) → Bala 28ca, Bala 29ca, Dinan 8, Dinan 10.
- **D3 stratum** (checkerboard with this class highlighted, others muted; flooding from the F5/F6 sample-point series; **F6 verdict as provisional trend**) → Aeolian·low, Riverine·mid, Inland·high (all `no_trend`).
- Layouts **A** (map-led), **B** (evolved-classic: series spine + right rail), **C** (card-grid) in `slide`; one **A3 landscape** (layout C, Bala 29ca).

## Choices used

Paddock map = **checkerboard**; site radius = **1 km** (parameterised 500 m–2 km); baseline-gauge recent window = **5 water years**; site gauge station = **410040 (D/S Maude Weir)**.

## Hard rules honoured

No pre/post anywhere — **no 2019/2020 transition line, no `drier_post` label, no pre/post boxplot** (the old pre/post box is replaced by the by-community "where it sits" box). Trend wording is **provisional** ("No trend detected so far (provisional)"). The boxplot compares on **absolute** flood frequency, never band label (bands overlap across communities). EPSG:8058 throughout.

## QA (all_pass = TRUE)

CRS 8058 (both rasters); flooding series span the full record (1988–2022 water-year starts = 35 water years); site neighbourhood pixels come from within R (>0 valid pixels per ring); plot counts stated on every response panel; provisional trend wording on all strata; boxplot unit values are absolute frequencies in [0,100]; all 37 figures built.

## One nuance for review

For a **paddock**, the response panel is restricted to the **dominant community's** usable plots and now names that community (e.g. Bala 29ca header "13 monitoring plots" vs response "n = 1 plot in Inland Floodplain" — the other 12 plots sit in other communities / are cover-excluded). Flag if you'd rather pool all in-paddock plots across communities instead.

## Deck-slide mapping

Each figure is a **paddock / site / stratum dashboard** slide — the evolved `GA_###` design with pre/post removed and a map, baseline gauge, and by-community "where it sits" box added. Phase 1 is the **layout bake-off**: pick A, B or C per unit set, then Phase 2 renders the chosen layout(s) for all units (slide; A3 for the agreed display set).
