# Gayini Codex Context

_Last updated: 2026-06-15_

> Superseded workflow-note: this context predates the 2026-06-23 final pruning pass. Old script names in this file are historical/non-active unless they also appear in `docs/current_run_order.md`.

## 1. Project overview

This repository supports the **Gayini remote-sensing analysis** for former irrigation land on the Murrumbidgee floodplain, now managed for conservation by Gayini / Nari Nari land managers.

The immediate project goal is to produce clear, defensible remote-sensing results for an **August workshop**. The main output will be a concise presentation deck for land managers, supported by technical subsidiary decks and reproducible analysis outputs.

The analysis has shifted away from trying to force a grazing-treatment story. Grazing treatment should be retained as metadata, but the main management question is now:

> Did inundation frequency and ground-cover dynamics change after the 2019 conservation-management shift, and which plots or areas appear wetter, drier, greener, barer, or unchanged?

The working interpretation is that **water drives vegetation response**, so inundation analysis comes before ground-cover response analysis.

## 2. Canonical workflow

The current canonical workflow is:

```text
extraction
  -> inundation pre/post
  -> ground cover pre/post
  -> lag diagnostics
  -> BFAST/tbreak decision
```

### Step 1 — Extraction

Purpose:
- Prepare clean plot and boundary vectors.
- Catalogue rasters.
- Extract plot-level time series from:
  - Landsat / TERN seasonal ground cover rasters.
  - Annual Landsat / NSW inundation rasters.
  - Daily Landsat / Sentinel / NSW-style inundation rasters.

Status:
- Existing extraction outputs should be kept.
- Old test scripts can be archived once full extraction outputs are stable.
- Do not delete old scripts without explicit instruction.

### Step 2 — Inundation pre/post

Purpose:
- Convert inundation observations to annual wet/not-wet layers.
- Build pre-conservation and post-conservation inundation-frequency rasters.
- Extract pre/post/difference values to plots.
- Produce maps, ranked plot summaries, dashboards and QA tables.

Main period logic:
- Water years are July–June.
- Current management-change date: `2019-07-01`.
- Recent pre-conservation baseline: approximately WY2014–WY2019.
- Post-conservation period: approximately WY2020 onward, subject to available data.

Important wording:
- The method estimates **annual inundation occurrence frequency**.
- It does **not** estimate hydroperiod, flood depth, inundation duration, or number of wet days.
- The main change metric is **percentage points**, not percent change.

Core formula:

```text
period_inundation_frequency_pct =
  100 * wet_year_count / valid_year_count

post_minus_pre_inundation_frequency_pct_points =
  post_conservation_inundation_frequency_pct -
  pre_conservation_inundation_frequency_pct
```

Current status:
- Step 7 rasters and summaries have run.
- The 07f fixed plot summary is the reliable plot-level table.
- 07g/07h/07j/07k/07l figure scripts have been iterated.
- Do not rerun expensive raster processing unless explicitly asked.
- Do not modify `scripts/07e_build_pre_post_inundation_frequency_rasters.R` in the first Codex task.

### Step 3 — Ground cover pre/post

Purpose:
- Recode ground-cover bands using the authoritative TERN/JRSRP definitions.
- Summarise ground-cover change pre/post conservation.
- Focus on:
  - total vegetation
  - bare ground

Ground-cover band definitions:
- Band 1 = bare ground.
- Band 2 = green / photosynthetic vegetation.
- Band 3 = non-green / non-photosynthetic vegetation.
- NoData = 255.

Derived variables:
```text
bare_ground_pct = band 1
green_pv_pct = band 2
non_green_npv_pct = band 3
total_veg_pct = green_pv_pct + non_green_npv_pct
delta_total_veg_pct = post_mean_total_veg_pct - pre_mean_total_veg_pct
delta_bare_ground_pct = post_mean_bare_ground_pct - pre_mean_bare_ground_pct
```

Important caveats:
- Treed plots, especially river red gum / woody plots, may confound ground-cover interpretation.
- Tree flags are not final yet.
- Do not exclude treed plots by default unless a setting explicitly requests it.

### Step 4 — Lag diagnostics

Purpose:
- Test whether vegetation/ground-cover responses lag inundation change.
- Start with simple descriptive diagnostics before formal change-point analysis.

Possible outputs:
- ACF summaries for inundation and ground-cover variables.
- Cross-correlation summaries for inundation leading vegetation response.
- Plot-level or grouped lag figures.

Do not overclaim causality from lag diagnostics.

### Step 5 — BFAST/tbreak decision

Purpose:
- Decide whether formal breakpoint / structural-change analysis is justified.

Important:
- BFAST/tbreak is **not** the next immediate task.
- Only revisit it after:
  - curated analysis-base tables are stable,
  - pre/post inundation is stable,
  - pre/post ground-cover results are stable,
  - missingness and lag diagnostics have been reviewed.

## 3. Current coding priorities

The next coding phase is not more figure polishing. It is a **streamlining and curated-analysis-base pass**.

The next target files are:

```text
tools/archive_legacy_code.ps1
R/gayini_analysis_base_functions.R
scripts/03_curate_rs_hydrology_analysis_base.R
```

The first Codex task should create these files only.

### Do first

1. Create an archive script for old/test code.
2. Create a shared analysis-base helper file.
3. Create a canonical curated analysis-base script.
4. Run only the curated analysis-base script.
5. Report files changed, outputs created, warnings and errors.

### Do not do yet

- Do not refactor the whole repository in one task.
- Do not delete old files.
- Do not modify `scripts/07e_build_pre_post_inundation_frequency_rasters.R`.
- Do not rerun expensive raster processing.
- Do not run BFAST/tbreak.
- Do not change scientific assumptions without making them settings and reporting the change.

## 4. Key existing outputs to read

Prefer current stable outputs where available.

### Ground cover

Likely paths:
```text
data_processed/plot_fractional_cover_timeseries.csv
Output/csv/04c_fractional_cover_full.csv
```

Expected important fields:
```text
plot_id
date_midpoint
band_number
mean_value
median_value
count_value
valid_coverage_status
treatment
vegetation
```

### Pre/post inundation plot summary

Prefer the fixed 07f output:
```text
Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv
data_processed/plot_pre_post_inundation_frequency_fixed.csv
```

Fallback only if needed:
```text
Output/csv/07e_pre_post_inundation_plot_summary.csv
data_processed/plot_pre_post_inundation_frequency.csv
```

Important fields:
```text
plot_id
pre_conservation_inundation_frequency_pct
post_conservation_inundation_frequency_pct
post_minus_pre_inundation_frequency_pct_points
pre_conservation_valid_year_count
post_conservation_valid_year_count
inundation_change_class
```

### Annual inundation

Possible paths:
```text
Output/csv/07j_plot_annual_combined_inundation_summary.csv
Output/csv/07h_plot_annual_combined_inundation_summary.csv
Output/csv/07e_plot_annual_combined_inundation_summary.csv
data_processed/plot_annual_combined_inundation_summary.csv
data_processed/plot_landsat_inundation_timeseries.csv
Output/csv/05c_landsat_inundation_full.csv
```

Fields may vary; scripts should detect likely date/value columns robustly and write diagnostics.

### Daily inundation

Possible paths:
```text
data_processed/plot_daily_inundation_timeseries.csv
Output/csv/06c_daily_inundation_full.csv
```

Daily data are useful for QA and event timing, but the main dashboard hydrology summary should use annual/pre-post values by default.

## 5. New outputs expected from the next script set

### `tools/archive_legacy_code.ps1`

Default behaviour:
- Copy only, do not move.
- Include dry-run mode.
- Archive old test/dev scripts to:

```text
archive/code_pre_refactor_YYYYMMDD/
```

- Write:

```text
archive/code_pre_refactor_YYYYMMDD/archive_manifest.csv
```

Manifest fields:
```text
source_path
destination_path
file_size_bytes
last_write_time
archive_timestamp
reason
action
```

### `R/gayini_analysis_base_functions.R`

Include helpers for:
- finding first existing file
- standardising `plot_id`
- assigning water years
- assigning pre/post periods
- recoding vegetation groups
- recoding TERN/JRSRP ground-cover bands
- creating total vegetation and bare ground variables
- adding gap-aware time-series segments
- checking duplicate keys
- writing row-count diagnostics
- writing basic variable lookup tables

Use magrittr `%>%`, not base `|>`.

### `scripts/07_curate_rs_analysis_base.R`

Purpose:
- Create canonical, analysis-ready CSVs from existing extraction and Step 7 outputs.
- Do not do raster processing.
- Do not rerun 07e.

Expected outputs:
```text
Output/csv/curated_ground_cover_timeseries.csv
Output/csv/curated_annual_inundation_timeseries.csv
Output/csv/curated_daily_inundation_monthly.csv
Output/csv/plot_rs_analysis_base.csv
Output/diagnostics/07_curate_rs_analysis_base/07_curate_row_counts.csv
Output/diagnostics/07_curate_rs_analysis_base/07_curate_duplicate_checks.csv
Output/diagnostics/07_curate_rs_analysis_base/07_curate_variable_lut.csv
```

The curated ground-cover table should be one row per plot-date where possible:
```text
plot_id
date_midpoint
water_year
period
treatment
vegetation
vegetation_adrian_group
bare_ground_pct
green_pv_pct
non_green_npv_pct
total_veg_pct
valid_coverage_status / support fields where available
```

The plot-level analysis base should be one row per plot:
```text
plot_id
treatment
vegetation
vegetation_adrian_group
area_ha
pre_conservation_inundation_frequency_pct
post_conservation_inundation_frequency_pct
post_minus_pre_inundation_frequency_pct_points
inundation_change_class
pre_conservation_valid_year_count
post_conservation_valid_year_count
ground-cover support summaries where available
```

## 6. Coding style

Use:
- R
- tidyverse style
- `magrittr` `%>%` pipes
- clear section headers
- explicit settings at top of script
- small helper functions
- readable variable names
- diagnostics written to CSV

Avoid:
- base R pipe `|>`
- silent assumptions
- over-complex wrappers
- hidden global state
- overwriting expensive outputs
- deleting old code
- rerunning expensive raster builds unless explicitly requested

## 7. Scientific assumptions to keep configurable

At the top of relevant scripts, keep these as settings:

```r
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
PRE_START_DATE <- as.Date("2013-07-01")
POST_END_DATE <- as.Date("2026-06-30")
WATER_YEAR_START_MONTH <- 7
ONLY_ADEQUATE_COVERAGE <- TRUE
EXCLUDE_TREE_FLAGGED_PLOTS <- FALSE
DAILY_WET_RULE <- "strict_value_1"
```

Do not hard-code decisions deep inside functions.

## 8. Presentation and interpretation priorities

The final August output will probably include:
- a main summary deck of about 20 slides
- a technical inundation deck
- a technical ground-cover deck
- subsidiary QA material

The most important current figures are:
- whole-farm pre/post inundation frequency
- whole-farm post-minus-pre inundation difference
- all-plot inundation change dot map
- ranked plot-level inundation change
- low-inundation / low-support plot summaries
- total vegetation + bare ground summaries
- selected plot dashboards

Keep figure scripts presentation-oriented but do not overload plots with technical details. Put detailed variable definitions in lookup tables and captions.

## 9. Interpretation cautions

Use these cautions in comments, captions and generated LUTs where relevant:

- Inundation frequency is annual occurrence frequency, not duration or hydroperiod.
- The post-minus-pre raster is in percentage points, not percent change.
- Sensor density differs among years; Sentinel-rich years may detect short-lived water more readily.
- `annual_valid_any = 1` means valid coverage, not flooding.
- Treatment comparisons are secondary sanity checks, not the main causal story.
- Non-significant treatment models do not prove no treatment effect.
- Ground-cover estimates may be uncertain in treed or woody plots.
- BFAST/tbreak should be deferred until simpler diagnostics justify it.

## 10. First bounded Codex task

Please do this task first.

Create the first streamlined analysis-base pass for the Gayini R workflow.

Constraints:
- Do not delete old files.
- Do not modify `scripts/07e_build_pre_post_inundation_frequency_rasters.R`.
- Do not run expensive raster processing.
- Use magrittr `%>%`, not base `|>`.
- Keep scientific assumptions configurable at the top of each script.
- Prefer clear diagnostics and stop conditions over silent assumptions.

Please create:

1. `tools/archive_legacy_code.ps1`
   - Default mode should copy, not move.
   - Archive old test/dev scripts to `archive/code_pre_refactor_YYYYMMDD/`.
   - Write `archive_manifest.csv` with source path, destination path, file size, timestamp, and reason.
   - Include a dry-run mode.

2. `R/gayini_analysis_base_functions.R`
   - Helpers for:
     - finding files
     - standardising `plot_id`
     - assigning pre/post periods
     - assigning water years
     - recoding vegetation groups
     - recoding TERN/JRSRP ground-cover bands
     - adding total vegetation
     - adding gap-aware time-series segments
     - writing row-count diagnostics
     - duplicate-key checks

3. `scripts/03_curate_rs_hydrology_analysis_base.R`
   - Read existing outputs from 04c, 05c/06c if present, and 07f.
   - Create `Output/csv/curated_ground_cover_timeseries.csv`.
   - Create `Output/csv/curated_annual_inundation_timeseries.csv`.
   - Create `Output/csv/curated_daily_inundation_monthly.csv` if daily data are present.
   - Create `Output/csv/plot_rs_analysis_base.csv`.
   - Write diagnostics to `Output/diagnostics/07_curate_rs_analysis_base/`.
   - Stop on missing required inputs or duplicated plot-date records where uniqueness is expected.
   - Use TERN/JRSRP ground-cover bands: band 1 = bare ground, band 2 = green / PV, band 3 = non-green / NPV, NoData = 255.

After writing the code, run only:

```powershell
Rscript --vanilla scripts/03_curate_rs_hydrology_analysis_base.R
```

Then report:
- files changed
- files created
- whether the script ran
- any errors/warnings
- what you changed to fix errors
- any assumptions you made
