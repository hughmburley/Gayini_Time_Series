# RS Gauge Context Database Import Note

Date: 2026-06-23

Updated: 2026-06-24

## Purpose

Gauge data are optional context for the broader Gayini remote-sensing workflow. They are not required for MER metrics and are not read by `scripts/06_extract_MER_inundation_metrics.R`.

The active gauge-context import entry point is:

```text
scripts/07_import_murrumbidgee_gauge_context.R
```

## Database Preference

Step 07 checks for a packaged clean gauge database in this order:

```text
Input/hydrology/gayini_murrumbidgee_gauges.gpkg
Input/hydrology/gayini_murrumbidgee_gauges.sqlite
```

If a database is present, only these clean selected tables are read:

- `gauge_sites`
- `daily_flow_wide`
- `monthly_flow`
- `water_year_flow`
- `completeness_by_gauge`
- `completeness_overall`
- `remaining_gaps`
- `large_gap_recovery_status`

Step 07 does not run raw gauge download, API, rescue or patching logic. Those tasks remain outside Gayini.

## Current Import Mode

The 2026-06-24 run found no packaged database in `Input/hydrology`, so it used the clean CSV fallback from:

```text
D:/Github_repos/Murrumbidgee_Gauge_Workflow
```

The manifest is:

```text
Output/diagnostics/hydrology/gauge_database_import_manifest.csv
```

Current mode:

```text
clean_csv_fallback
```

To use the packaged database path efficiently, copy the clean gauge database to one of:

```text
Input/hydrology/gayini_murrumbidgee_gauges.gpkg
Input/hydrology/gayini_murrumbidgee_gauges.sqlite
```

Then rerun only:

```text
scripts/07_import_murrumbidgee_gauge_context.R
```

Do not rerun MER for this. Step 06 is fully remote-sensing derived and does not read the gauge database.

## Default Context Gauges

The default continuous-context gauges for later RS review are:

- Darlington Point (`410021`)
- Hay Weir (`410136`)
- Maude Weir (`410040`)
- Balranald Weir (`410130`), with the existing suspect zero-flow caveat

These records are useful context for broader Gayini interpretation, but they are marked `not_required_for_mer_metrics = TRUE`.

## Excluded From Default Continuous Historical Context

These gauges remain available in the imported reference data, but they are excluded from default continuous historical joins:

- Redbank (`410041`): `use_outside_major_gap_only`; exclude from continuous historical context because the 1993-2006 gap is unresolved.
- Carrathool (`41000281`): `use_outside_major_gap_only`; exclude from continuous historical context because the 1988-1995 gap is unresolved.

## Downstream Use

Optional RS/gauge context joins are created by `scripts/09a_curate_rs_hydrology_analysis_base.R` only when imported gauge summaries exist. The current default joins use the four continuous-context gauges above.

Gauge outputs should be treated as contextual support for review figures and narrative interpretation, not as inputs to MER metric calculation.
