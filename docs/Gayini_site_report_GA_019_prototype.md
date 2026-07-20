<!--
TEMPLATE PROTOTYPE — one real instance (GA_019), built from Gayini_Results.sqlite.
Every number below is pulled from the DB; every [[FIELD]] marks a value the batch build
substitutes per plot. Figures are referenced by path (they live on the workstation).
This file IS the spec for the 66-site batch build — see "Batch-build notes" at the end.
-->

# Gayini site report — GA_019

> **Internal review — not for external release.** Cultural sensitivity: **review required** with the Nari Nari Tribal Council before any sharing beyond the project team. *(from `dim_plot`: `access_level = internal_review`, `public_release_ok = 0`, `cultural_sensitivity = review_required`)*

**Community:** Inland Floodplain Shrublands / Swamps  ·  **Site area:** 1.0 ha  ·  **Record:** 1988–2023 (35 years)  ·  **Grazing:** 14-day grazing

---

## The country this site sits in

GA_019 is a one-hectare monitoring site in the **Inland Floodplain Shrublands / Swamps** — the wettest and largest of the four vegetation communities on the property. It is not a treed site, so it sits inside the analytical focus (not the woodland context group).

## How often it floods

Over the full 35-year record, GA_019 was under water in **48.6% of years — about 17 years in 35**. Measured at the site scale: a year counts as wet if any part of the one-hectare site saw water.

Within its own community, that places GA_019 **just above the middle** — 10th of the 22 Inland Floodplain sites, which range from 5.7% to 100% (median 40%). So this is a **moderately-to-regularly flooded** part of the wettest community: wetter than typical for the property as a whole, ordinary-to-slightly-wet for where it sits.

![Site dashboard — GA_019](../figures/D2_site_GA_019_slide_data.png)
*Site dashboard: flooding and ground-cover history for GA_019 across 1988–2023.*

## What the ground cover looks like

Across the record, total vegetation cover at GA_019 averaged **82.6%** — but most of that is **standing dead or dry material (65.0%)** rather than green growth (**17.7% green**), with **15.9% bare ground**. That pattern — a high total-cover floor made up mostly of dead material — is typical of this floodplain country: even in dry spells the ground holds cover, but the *green* fraction is what moves with the flood pulses.

*(A note on what this can and cannot tell us: the satellite record measures how much cover is present, not whether it is native or introduced, or its condition. Read the ground-cover story as "how much, and how green," not as a condition score.)*

## The paddock it sits in

GA_019 falls within **[[PADDOCK_NAME]]**. Across that paddock, the flood-frequency zones break down as **[[PADDOCK_ZONE_PROFILE]]** — see the paddock map below for how wetness varies across the paddock and how this site sits within it.

![Paddock map — [[PADDOCK_NAME]]](../figures/C1_veg_regime_paddock_[[PADDOCK_KEY]]_data.png)
*Paddock flood-frequency map. GA_019 is marked.*

## Management context

Grazing on this site is recorded as **14-day grazing**. Grazing is carried as management context, not as a driver in this analysis — the story here is hydrology first, then vegetation response.

---

*Data: `Gayini_Results.sqlite`, full record 1988–2023. Flood frequency = share of years the site saw any water (site scale, any-water rule). Ground cover from the seasonal fractional-cover record. This report is internal-review; confirm cultural-sensitivity clearance before any external use.*

<!--
================================ BATCH-BUILD NOTES ================================
Run this template for all 66 plots (GA_001..GA_066). Data-driven fields, all from the DB:

Per-plot, from v_plot_current_summary / dim_plot:
  [[COMMUNITY]]        simplified_vegetation_group
  [[AREA_HA]]          plot_area_ha (round 1 dp)
  [[GRAZING]]          treatment
  [[TREED]]            treed_plot_flag -> focus vs woodland-context wording
  access banner        access_level, public_release_ok, cultural_sensitivity, spatial_review_flag
                       (if spatial_review_flag = 1 -> add a "site geometry under review" line;
                        flagged plots: GA_016, GA_029, GA_006, GA_007, GA_022, GA_066)

Per-plot full record, from v_plot_year_analysis_spine (35 rows/plot):
  [[FLOOD_FREQ]]       AVG(annual_wet_any)*100  -> "X% of years, about N in 35"
  [[TOTAL_VEG]]        AVG(mean_total_veg_pct)
  [[GREEN]] [[DEAD]]   AVG(mean_pv_pct), AVG(mean_npv_pct)
  [[BARE]]             AVG(mean_bare_ground_pct)
  community rank       rank of this plot's flood_freq within its community + community min/median/max
                       -> the "where it sits in its community" sentence (drives dry/typical/wet wording)

Figures (reference by path; confirm they exist for the plot):
  site dashboard       figures/D2_site_{plot_id}_slide_data.png   (BUILT for only 5 of 66 -> see gap)
  paddock map          figures/C1_veg_regime_paddock_{paddock_key}_data.png

TWO WIRING GAPS the batch build must close (neither needs Adrian/Jana):
  1. plot -> paddock link. Not in the DB as a column. Resolve by spatial join of plot centroids
     (dim_plot.centroid_x/y are EPSG:9473 — reproject first) to the paddock polygon layer, then
     map to the C1 paddock figure key. Materialise as a small plot_paddock lookup so it's reused.
  2. site dashboards exist for 5 of 66 (GA_001/003/019/032/052). The other 61 must be built
     (the D2 dashboard generator already exists — run it for all 66) before their reports can embed one.

Wording discipline (carry into every report):
  - Site-scale flood frequency is PLOT support (any-water rule). Do not swap in the census
    pixel-support community means (6/13/28) — different scale (C10).
  - Framing is full-record, NOT pre/post. Do not use pre/post language.
  - Cover, not condition — keep the one-line caveat.
==================================================================================
-->
