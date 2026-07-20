# Claude Code task — pixel census, sampling robustness, and baseline / bivariate rasters

**Goal.** Add the data-side pieces behind four presentation asks: (1) a pixel census of the vegetation × wetness strata as a **database view**, (2) a **robustness** check of the "no lasting trend" result under repeated sampling, (3) a **baseline-anomaly** raster, and (4) a **vegetation × wetness bivariate** raster with per-paddock maps. All outputs feed the Gayini deck.

## Standing conventions (do not re-litigate)
- One CRS: **EPSG:8058** (GDA2020 / NSW Lambert). Reproject-on-read; never overwrite source files.
- **Pre/post is retired** — everything is full-record (1988–2023) or baseline-relative. Do not resurrect a transition date.
- Headline metric = **between-year flood frequency** = wet-valid years ÷ valid years. The column `inundation_annual_occurrence_pct` is the **secondary** within-year wet-extent metric — keep them clearly separate.
- Register every new figure in `figures_manifest.csv`; new DB objects follow the existing `v_*` view naming; new metrics get a row in `dim_metric` with `units`, `safe_interpretation`, `caveat`.
- QA every output: row counts, null/þNaN checks, that fractions sum sensibly, and that CRS/extent match the plot layers. Emit a short `*_qa.json` per task.

## Inputs (confirm paths on the real filesystem)
- `background_flood_frequency_8058.tif` — per-pixel long-run flood frequency (0–100%), full record.
- Annual stack `annual_wet_any_1988_2023.tif` and `annual_valid_any_1988_2023.tif` (per-year wet / valid flags).
- Vegetation communities layer (BCT groups, non-treed focus + treed context) — polygon or raster.
- `regime_band_breaks.csv` — within-community tercile breaks (low/mid/high), **relative to each community**.
- `stratified_sample_points.gpkg` — current sample points (near plots, footprints excluded).
- Paddock / management-zone polygons; plot polygons (`v_plot_current_summary_map`).
- The results database (star schema; `v_plot_year_analysis_spine`, `dim_plot`, `dim_metric`, `fact_plot_year`).

---

## Task 1 — Pixel census as a database view  ⭐ (the one the slide needs)
Create **`v_pixel_census_by_veg_regime`**.

For every **vegetation community × wetness band** stratum (3 non-treed communities × low/mid/high, plus the treed Woodland/Forest as a context row):
- `n_pixels` — count of valid pixels across the farm in that stratum (apply the valid-coverage mask).
- `area_ha` and `pct_of_farm`.
- `n_points_sampled` — current stratified points in that stratum.
- `sampling_fraction` = `n_points_sampled / n_pixels` (and points per 1000 ha).
- The within-community band breaks used (from `regime_band_breaks.csv`).

Method: classify each pixel by community (overlay veg layer) and by its band (apply the community-relative tercile breaks to `background_flood_frequency_8058.tif`), then group-count. Mask pixels failing the valid-coverage threshold (see Task 3 note on threshold — parameterise it).

**Deliverables:** the view; `pixel_census.csv`; a small figure `Fx_pixel_census_data` (bar or table of pixels available vs sampled per stratum) registered in the manifest. **Acceptance:** pixel counts reconcile to total farm area; equal-allocation over/under-sampling is visible (expect small strata oversampled).

## Task 2 — Sampling robustness (multiple runs)
Test whether the F6 "no lasting trend" verdict is an artefact of one draw.
- Repeat the stratified random draw **K = 100** times (same design; independent seeds; enforce a minimum inter-point spacing to limit spatial autocorrelation).
- Optionally raise n per stratum where pixels allow (e.g. 40 → 100); record the value used.
- Re-run the per-stratum trend test each time (Theil–Sen slope + Mann–Kendall, plus the drop-the-two-biggest-floods robustness check).
- Summarise per stratum: proportion of runs returning trend / no-trend / episodic; distribution of slopes and p-values.

**Deliverables:** `trend_verdict_stability.csv`; optional view `v_trend_verdict_stability`; figure `Fx_trend_stability_data` (per-stratum verdict proportions). **Acceptance:** headline reproduced — no-trend dominant across runs; any stratum whose verdict flips is flagged. Note explicitly that this strengthens the **flooding** side only; the vegetation-response side is capped by the 66 plots.

## Task 3 — Baseline-anomaly raster (descriptive snapshot)
Per pixel: `anomaly = recent-window flood frequency − long-run (35-yr) baseline`.
- Parameterise the recent window (default: most recent 5 water years); also emit a standardised version (anomaly ÷ pixel temporal SD) for a comparable scale.
- Output a **zero-centred diverging** raster (blue = wetter than baseline, red = drier), EPSG:8058, with the valid-coverage support mask applied.
- **Framing guard:** filename and metadata must label this a *descriptive departure-from-baseline snapshot, not a trend* (F6 shows no robust trend). Do not derive a slope or "change" claim from it.

**Deliverables:** `baseline_anomaly_recent5_8058.tif` (+ standardised variant); figure `Fx_baseline_anomaly_data` registered in the manifest; `dim_metric` row for the anomaly metric with the "snapshot not trend" caveat.

## Task 4 — Vegetation × wetness bivariate raster + per-paddock maps
Assign each pixel a **(community × band)** class (the 9 non-treed classes; treed as context) → the "checkerboard".
- Use the bivariate scheme from the concept slide: community = hue (Aeolian gold / Riverine teal / Inland blue), wetness = light→dark within hue.
- Render: a whole-farm bivariate map + **one map per major paddock** (Bala 28ca, Bala 29ca, Dinan 8, Dinan 10, and others), each with the 3×3 bivariate legend and paddock outline heavy / neighbours light.

**Deliverables:** `veg_regime_class_8058.tif`; figures `Fx_veg_regime_bivariate_farm` and `Fx_veg_regime_paddock_<name>` per paddock, registered in the manifest.

## Task 5 — Pixel water-detection provenance (for the methods slide)
Document the **actual** per-observation water-detection method used to build the annual wet/valid stack (e.g. DEA Water Observations / WOfS decision-tree, or an NDWI-sum457 classifier à la Thomas & Kingsford 2015). Record: index/classifier, threshold/confidence, sensor handling (Landsat 5/7/8/9 → Sentinel-2), and the valid-coverage rule. Output a short `water_detection_method.md` so the deck's methods slide states the real recipe rather than a generic one.

---

### Priority order
1 (census view) → 5 (provenance) → 3 (baseline anomaly) → 4 (bivariate + paddocks) → 2 (robustness).

### Definition of done
All new views + rasters + figures created, QA JSONs pass, `figures_manifest.csv` and `dim_metric` updated, and a one-paragraph note per task on how it maps to its deck slide.
