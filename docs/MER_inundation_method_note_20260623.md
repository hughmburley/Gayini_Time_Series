# MER/Flow_MER Inundation Method Note

Date: 2026-06-23

Updated: 2026-06-24

## Purpose

This note documents the Gayini MER/Flow_MER-style inundation metrics added as supporting observed extent/timing diagnostics. The MER stage is remote-sensing first: it uses satellite-derived daily plot inundation outputs only, and it does not read gauge, hydrology, SQLite or GeoPackage inputs.

The annual inundation occurrence workflow remains the core annual RS hydrology result. MER metrics complement that workflow by adding observed maximum extent, timing and support diagnostics from the existing daily inundation extraction.

## Flow_MER Contribution

The reference Flow_MER repository is a remote-sensing surface-water extent/inundation workflow. Its scripts and notebooks informed the emphasis on annual/seasonal maximum water extent, observed inundation timing, dynamic metrics and observation support. The Gayini adaptation keeps that RS framing and consumes the existing plot-level daily inundation table rather than re-reading rasters.

Reference: <https://github.com/andressutton/Flow_MER>

## Active Entry Point

```text
scripts/06_extract_MER_inundation_metrics.R
```

This script sources the active implementation module:

```text
R/gayini_mer_inundation_functions.R
```

It consumes:

```text
data_processed/plot_daily_inundation_timeseries.csv
```

with fallback to:

```text
Output/csv/06c_daily_inundation_full.csv
```

## Wet Rule And Invalid Support

The primary wet rule remains strict value 1 inundation:

```text
daily_inundated_pct = value_1_inundated_pct
```

Value 2 (`value_2_ors_water_pct`) is retained as a sensitivity metric and is not mixed into the primary wet metric. Cloud/shadow, explicit NoData and other values are tracked as invalid/missing support rather than dry observations.

## Metrics

Main metric labels are intentionally cautious:

- `annual_max_inundated_area_pct`
- `monthly_max_inundated_pct`
- `seasonal_max_inundated_pct`
- `longest_observed_wet_sequence_days`
- `start_date_longest_observed_wet_sequence`
- `n_valid_observations`
- `n_wet_observations`
- `n_sensor_dates`
- `sensor_mix`

The annual, monthly and seasonal maximum metrics are maxima of selected valid daily observations. Annual MER metrics are currently the strongest deck-facing level.

Monthly and seasonal metrics are retained for QA and targeted review, but they should not be headline metrics yet because many monthly/seasonal bins have lower observation support.

The longest observed wet sequence is the longest run of observed wet detections where gaps between wet observations are not greater than the configured gap rule. It is a support/timing diagnostic only, not hydroperiod, true duration or wet days.

## What The Metrics Do Not Mean

These metrics are not:

- hydroperiod;
- flood depth;
- true continuous inundation duration;
- wet days;
- gauge-flow response or causal evidence.

They are observation-dependent satellite metrics. A low or zero value can mean the plot was observed dry, but interpretation always depends on valid observation count, sensor mix and invalid/cloud/nodata support.

## Observation Support

Every annual and monthly/seasonal output includes observation-support fields. Key support diagnostics are:

```text
Output/diagnostics/06_MER_inundation/support_metrics_by_plot_water_year.csv
Output/diagnostics/06_MER_inundation/observation_density_by_water_year.csv
Output/diagnostics/06_MER_inundation/missingness_checks.csv
```

The 2026-06-24 run classified all 726 annual plot-year rows as high-density after the adequate-coverage filter. Monthly checks still flag many low-support months, which is expected because monthly bins can have few satellite observations.

Additional deck-use notes are written to:

```text
Output/diagnostics/06_MER_inundation/mer_deck_metric_use_notes.csv
Output/diagnostics/06_MER_inundation/mer_monthly_seasonal_support_summary.csv
Output/diagnostics/06_MER_inundation/mer_annual_support_summary.csv
```

## Relationship To Annual Occurrence

The annual occurrence workflow estimates annual inundation occurrence frequency from annual valid/wet water-year rasters. MER metrics provide supporting observed extent/timing information from the daily extraction.

RS-only comparison diagnostics are:

```text
Output/diagnostics/06_MER_inundation/mer_vs_annual_occurrence_flags.csv
Output/diagnostics/06_MER_inundation/mer_vs_annual_occurrence_common_period.csv
```

Current comparison summary:

- 48 plots show matching pre/post direction between annual occurrence and MER mean annual maximum extent;
- 12 plots disagree and should be manually reviewed;
- 6 plots have near/no-change behaviour in one metric.

Disagreements are retained because they may reflect different metric meaning, observation timing, local plot behaviour, or support differences.

## Gauge Context

Gauge data are not part of the MER metric calculation and are not used in `scripts/06_extract_MER_inundation_metrics.R`.

Gauge context is imported separately by:

```text
scripts/07_import_murrumbidgee_gauge_context.R
```

Later curation/review scripts can use gauge summaries defensively as optional context. The default continuous-context gauges are Darlington Point, Hay Weir, Maude Weir and Balranald Weir. Redbank and Carrathool are retained as reference records but excluded from default continuous historical context because of unresolved major gaps.

## Current Output Locations

```text
Output/csv/
Output/diagnostics/06_MER_inundation/
Output/figures/06_MER_inundation/
```

Current MER figures are:

- `annual_max_inundated_area_by_plot_water_year.png`
- `ranked_post_minus_pre_annual_max_inundated_area.png`
- `prepost_annual_max_inundated_area.png`
- `observation_support_by_water_year_sensor.png`
- `mer_annual_max_vs_annual_occurrence.png`

Deck-candidate figures are written to:

```text
Output/figures/06_MER_inundation/deck_candidates/
```

The compact review shortlist is:

```text
Output/diagnostics/06_MER_inundation/mer_plot_review_shortlist.csv
```

Historical diagnostics under `Output/diagnostics/05b_MER_inundation/` are preserved for provenance. Stale gauge-context artifacts previously written under the MER folder were archived under:

```text
Output/archive/repo_cleanup_20260623/MER_gauge_context_removed_from_06_20260624/
```
