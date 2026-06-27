# MER Inundation Changelog

Date: 2026-06-23

Updated: 2026-06-24

## Summary

Updated the active MER/Flow_MER-style inundation pass so `scripts/06_extract_MER_inundation_metrics.R` is remote-sensing only. Step 06 now consumes the daily inundation extraction, writes RS-only diagnostics and figures, and does not read gauge, hydrology, SQLite or GeoPackage inputs.

The live MER implementation now lives in `R/gayini_mer_inundation_functions.R`. Archived `05b` code remains for provenance only and is no longer sourced by the active step 06 driver.

No raster processing was rerun. The annual inundation occurrence workflow remains the core annual RS hydrology result.

## Script Changes

- Added `R/gayini_mer_inundation_functions.R` as the active MER implementation module.
- Updated `scripts/06_extract_MER_inundation_metrics.R` so it sources `R/gayini_mer_inundation_functions.R` and no longer depends on archived code.
- Added MER deck-output writing for a compact review shortlist and deck-candidate figures.
- Updated `scripts/07_import_murrumbidgee_gauge_context.R` so gauge context is isolated in its own optional import step. It checks for `Input/hydrology/gayini_murrumbidgee_gauges.gpkg` first, then `.sqlite`, and otherwise falls back to clean CSV exports.
- Updated `R/hydrology_import_functions.R` to mark default continuous-context gauges and flag all gauge records as not required for MER metrics.
- Updated `R/rs_gauge_join_functions.R` so default RS/gauge context joins use four continuous-context gauges, excluding Redbank and Carrathool from default continuous historical context.
- Updated `scripts/09a_curate_rs_hydrology_analysis_base.R` so gauge joins are optional and defensive.

## Output Convention

MER outputs use:

- `Output/csv/`
- `Output/diagnostics/06_MER_inundation/`
- `Output/figures/06_MER_inundation/`

Existing historical diagnostics under `Output/diagnostics/05b_MER_inundation/` were preserved and not deleted.

## Outputs Refreshed

- `Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv`
- `data_processed/plot_inundation_dynamic_metrics.csv`
- `Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv`
- `Output/csv/plot_rs_analysis_base.csv`
- `data_processed/hydrology/plot_rs_gauge_monthly_context.csv`
- `data_processed/hydrology/plot_rs_gauge_water_year_context.csv`

## MER Diagnostics

Diagnostics under `Output/diagnostics/06_MER_inundation/` now include:

- row counts by plot, water year, sensor and source;
- unique observation dates by water year;
- duplicate-key checks;
- missingness and invalid/cloud/nodata checks;
- value-range checks;
- annual, monthly and seasonal maximum reproducibility checks;
- longest observed wet-sequence reproducibility checks;
- support metrics by plot and water year;
- MER pre/post support caveats;
- MER versus annual occurrence flags;
- MER versus annual occurrence same-plot/water-year common-period comparison.
- compact MER plot review shortlist;
- annual versus monthly/seasonal support notes for deck use;
- metric-use notes that keep observed wet sequence as timing/support context only.

Gauge monthly, water-year and pulse-timing diagnostics were removed from the visible MER diagnostics folder and archived under:

```text
Output/archive/repo_cleanup_20260623/MER_gauge_context_removed_from_06_20260624/
```

## Figures

Five RS-only QA/review figures were written under `Output/figures/06_MER_inundation/`:

- annual maximum observed inundated area by plot and water year;
- ranked post-minus-pre change in annual maximum observed inundated area;
- pre/post annual maximum observed inundated area;
- observation support by water year and sensor;
- MER annual maximum change versus annual occurrence change.

Deck-candidate figures were written under:

```text
Output/figures/06_MER_inundation/deck_candidates/
```

The current pre/post boxplot remains QA rather than the preferred deck figure.

## Key Diagnostic Findings

- Annual MER rows: 726.
- Monthly/seasonal MER rows: 11214.
- Same plot/water-year MER versus annual occurrence comparison rows: 594.
- Observation support class: all 726 annual plot-year rows are currently high-density after the adequate-coverage filter.
- MER versus annual occurrence: 48 plots agree in pre/post direction, 12 disagree and need review, and 6 are near/no-change in one metric.
- Duplicate-key checks and value-range checks passed after the final run.
- Optional RS/gauge context joins now use four default continuous-context gauges.

## Interpretation Caution

MER metrics are observed extent/timing metrics. They are not hydroperiod, depth, true continuous duration, wet days, or gauge-flow response evidence. Gauge context can support broader interpretation later in the workflow, but it is not part of MER metric calculation.
