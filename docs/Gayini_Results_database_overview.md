# Gayini Results Database — Overview

*A guide to `Gayini_Results.sqlite` for analysts and collaborators. Read-only unless you are running the build pipeline.*

`Gayini_Results.sqlite` is the **authoritative relational results store** for the Gayini remote-sensing environmental-change assessment. `Gayini_Results.gpkg` is a map-ready spatial companion (build mode: `polygon`). Raster binaries are **not** stored in either — they live externally and are registered in `raster_asset`. The full field/metric/QA catalogue is in `Gayini_Results_data_dictionary.xlsx`; this note is the orientation layer above it.

The database is a dimensional model (`dim_*` / `fact_*`) with an analysis-ready **canonical staging** layer (`stg_canonical_*`) and a set of **views** that are the intended entry points. There are 66 tables and 20 views.

## Conventions you need before querying

- **Coordinate system:** everything analytical is GDA2020 / NSW Lambert (**EPSG:8058**). One known gotcha discovered during F7: `dim_plot` centroid columns (`centroid_x/y`) are stored in **EPSG:9473 (GDA2020 Australian Albers)**, *not* 8058 — reproject centroids before any spatial join or raster extraction. (Confirm and record this in the builder.)
- **Headline metric:** *between-year annual flood frequency* = `100 × wet-valid-years ÷ valid-years`. This one metric runs the whole analysis.
- **Secondary metric — naming trap:** the within-year *wet-extent coverage* is the field `annual_occurrence_pct`. Despite the word "occurrence," this is the **secondary** metric, not the headline. Do not treat `annual_occurrence_pct` as the flood-frequency headline.
- **Vegetation grouping — use the 4-class scheme.** `simplified_vegetation_group` (Aeolian Chenopod · Riverine Chenopod · Inland Floodplain · Floodplain Woodland/Forest) is canonical. A legacy 5-class `vegetation_adrian_group` (which splits the treed community in two) survives in some `stg_*` tables — do not use it for analysis; join to `dim_plot` for the 4-class group and the treed/exclusion flags.

## The layers

### 1. Analysis spine and sampling substrate (start here)

| Object | Rows | What it is |
|---|---|---|
| `v_plot_year_analysis_spine` | 2,310 | **The modelling spine** — plot × water-year (66 × 35): `annual_occurrence_pct`, `annual_wet_any`, `annual_valid_any`, `annual_valid_coverage_pct`, cover means (`mean_total_veg_pct`, `mean_pv_pct`, `mean_npv_pct`, `mean_bare_ground_pct`), `simplified_vegetation_group`, `treed_plot_flag`, `ground_cover_exclusion_flag`, `spatial_review_flag`. |
| `v_pixel_census_by_veg_regime` / `census_stratum` | 11 | **Sampling substrate** — per vegetation × wetness-band stratum: valid-pixel count, area (ha), % of farm, points currently sampled, sampling fraction and density. The basis for the sub-sampling design. |
| `v_groundcover_response_by_hydro_class` | — | Ground-cover response summarised by hydrological class (F7 lineage). |
| `v_inundation_change_by_vegetation_group` | — | Between-community inundation contrast. |

### 2. Canonical staging (curated, analysis-ready)

| Object | Rows | What it is |
|---|---|---|
| `stg_canonical_annual_inundation` | 2,310 | Plot × water-year wet/valid annual series (the spine's inundation source). |
| `stg_canonical_daily_inundation_monthly` | 7,848 | Plot × month inundation intensity (`mean_daily_inundated_pct`) — the sub-annual/lag source. |
| `stg_canonical_ground_cover_timeseries` | 8,742 | Plot × observation-date fractional cover (total veg, PV, NPV, bare) — sub-annual cover. |
| `stg_canonical_plot_rs_analysis_base` | 66 | One row per plot — plot-level analysis base. |
| `stg_canonical_plot_rs_gauge_analysis_base` | 66 | As above, joined to gauge context. |

### 3. Dimensional model

Dimensions: `dim_plot` (66 monitoring plots + flags/centroids), `dim_metric` (43 metric definitions), `dim_time` (706), `dim_spatial_unit` (67), `dim_gauge` (6), `dim_source_product` (6), `dim_species` (empty). Facts: `fact_plot_year` (12,144), `fact_plot_month` (31,392), `fact_plot_observation` (43,710), `fact_plot_period` (792), `fact_gauge_month` / `fact_gauge_water_year`, `fact_context_unit_month` (141,638 — MODIS context), `fact_biodiversity_context` (132). The `stg_canonical_*` layer and the spine are the recommended analysis surface; the `fact_*` tables are the normalised store beneath them.

### 4. Companion imports (context, not the spine)

- **Gauge / hydrology:** `gauge_*` (Murrumbidgee monthly & water-year flow, Kingsford flow ratios, completeness, QA), `stg_hydrology_gauge_context`, `v_gauge_context_by_water_year`. Flow is contextual support for dashboards — not a driver in the current analysis.
- **Biodiversity:** `bio_*` (waterbird/monitoring headlines and time series, plot LOOCB context) and `fact_biodiversity_context` — imported when the companion DB is present.
- **MODIS context:** `stg_modis_context_*`, `v_modis_*` — coarse-resolution farm-vs-buffer and management-zone context.

### 5. MER lineage (supplementary)

`stg_mer_*` and `v_mer_vs_rs_agreement` are the **annual maximum observed wet footprint** (renamed away from "MER"). Supplementary/diagnostic — kept alongside the main analysis, not part of the headline chain.

### 6. Registries and governance

Asset registries: `raster_asset` (100), `source_file` (547), `figure_asset` (139), `report_asset` (38), `spatial_layer_asset` (5). QA and release control: `qa_check` (47), `diagnostic_issue` (11), `spatial_review_flags` (9), and the views `v_database_release_checks` and `v_current_qa_issues`. **Known spatial-review plots:** GA_006, GA_007, GA_016, GA_022, GA_029, GA_066 — flagged, not dropped. Data access defaults to internal review; spatial and biodiversity sensitivities are preserved.

## How to consume it

1. **Just want the results?** Open `v_plot_year_analysis_spine` and `v_pixel_census_by_veg_regime`; run the spine demo (`demo_spine.R`). Everything you need for the headline story is there, read-only.
2. **Go through views, not raw `fact_*` tables** — the views encode the joins, the 4-class grouping, and the metric definitions, and they insulate you from internal schema churn.
3. **Check `v_database_release_checks` and `v_current_qa_issues`** before trusting a fresh build.
4. **Post-build mutations exist.** The Python builder rebuilds the DB from scratch (unlink + rebuild, no GDAL), so raster metadata, the unified annual stack, and the pixel census are **applied after the build** and must be re-run, in order, after any full rebuild. A DB that is missing `raster_asset` rows, the annual stack registration, or `v_pixel_census_by_veg_regime` has not had its post-build steps applied.

## Scientific framing (from the README)

Hydrology is the lead ecological driver; vegetation response is lagged, spatially uneven, and community-specific; grazing is important management metadata but does not overwrite the hydrological/vegetation interpretation. The main inundation metric is annual flood frequency — not hydroperiod, duration, depth, or flood days.
