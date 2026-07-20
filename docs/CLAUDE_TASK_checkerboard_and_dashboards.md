# Claude Code task — checkerboard maps and dashboards (paddock + site)

**Goal.** Add three figure families to the Gayini repo, all built on the existing paddock-zoom machinery: (C1) the **vegetation × wetness "checkerboard"** bivariate maps, (D1) **paddock dashboards**, and (D2) **site dashboards** (pixels within a radius of each plot). These realise the concept slides in the deck.

## Reuse principle (do this first)
The F5c paddock zooms already draw: the background flood-frequency surface, the heavy paddock outline + light neighbours, the locator inset, and within-community regime-band points. **Refactor that into one reusable function** — e.g. `plot_area_map(extent, surface, outline, points=NULL, fill=NULL, inset=TRUE)` — and build all three figures below on it. Do not fork the plotting code three times.

## Standing conventions
- One CRS: **EPSG:8058**. Reproject-on-read; never overwrite sources.
- **No pre/post anything.** Full record 1988–2023, or baseline-relative. The old per-site dashboards (GA_001, GA_003) still carry a Pre/post boxplot — the new site set must NOT.
- Between-year **flood frequency** (wet ÷ valid years) is the headline; within-year occurrence % is the secondary metric — keep them labelled distinctly.
- Register every figure in `figures_manifest.csv`; follow `v_*` view naming for any new views; add `dim_metric` rows for any new per-pixel/per-area metric (with `units`, `safe_interpretation`, `caveat`). Emit a `*_qa.json` per task.
- Community colours + within-community tercile band breaks are fixed (below) — read them from `regime_band_breaks.csv`, don't recompute.

## Inputs
- `background_flood_frequency_8058.tif`; annual `*_wet_any` / `*_valid_any` stack + valid-coverage mask.
- Vegetation-community layer (3 non-treed focus groups; treed Woodland/Forest = context; plus Other/minor).
- `regime_band_breaks.csv` (within-community terciles). Current values, for cross-checking:
  - Aeolian Chenopod: low 0.0–0.2 · mid 0.2–5.7 · high 5.7–76.0 (% flood freq.)
  - Riverine Chenopod: low 0.0–5.4 · mid 5.4–16.2 · high 16.2–85.2
  - Inland Floodplain / Swamps: low 0.0–18.7 · mid 18.7–34.4 · high 34.4–97.1
- Paddock / management-zone polygons; plot centroids + geometry (`v_plot_current_summary_map`); ground-cover series; gauge context (background).
- `v_pixel_census_by_veg_regime` (from the previous task) — reuse for legend counts / QA.

---

## Task C1 — Checkerboard (vegetation × wetness) bivariate maps
Per pixel, assign a **community × band** class → a bivariate fill (this replaces the single-hue blue surface with a two-variable fill on the same paddock layout).

- Build/confirm `veg_regime_class_8058.tif` (9 non-treed classes + a treed context class + Other/minor).
- Bivariate scheme: **community = hue, wetness band = light→dark**:
  | | low | mid | high |
  |---|---|---|---|
  | Aeolian | `#E5D3A0` | `#C79A3C` | `#8F6E24` |
  | Riverine | `#B3E0D6` | `#3FAE97` | `#27725F` |
  | Inland Floodplain | `#AAC6E4` | `#2E6DB0` | `#1B4270` |
  | Woodland (context) | muted grey, single shade | | |
- Render: a **whole-farm** bivariate map + **one map per major paddock** (Bala 28ca, Bala 29ca, Dinan 8, Dinan 10, and the rest), each via `plot_area_map(..., fill=veg_regime_class)`, with the heavy outline / light neighbours / inset, and the **3×3 bivariate legend**.
- Keep the deck's concept-slide styling so the schematic and the real figure read as one.

**Deliverables:** `veg_regime_class_8058.tif`; `Fx_veg_regime_bivariate_farm`; `Fx_veg_regime_paddock_<name>` per paddock; manifest entries. **Acceptance:** class areas reconcile to `v_pixel_census_by_veg_regime`; legend matches the fixed scheme; woodland shown as context only.

## Task D1 — Paddock dashboards
One page per paddock, four panels, reusing the paddock map:

1. **Flood-frequency map** — the F5c paddock zoom (or the C1 bivariate variant), reused directly.
2. **Annual flooding, 1988–2023** — share of the paddock's valid pixels wet each water year (line + 35-yr mean). No transition line.
3. **Vegetation response** — ground-cover-vs-wetness for the paddock. NB limited by how many ground-cover plots fall inside the paddock; if few/none, fall back to the paddock's community-level response as context, and say so.
4. **Local knowledge & confidence** — space for on-ground notes + coverage/confidence flags.

**Deliverables:** `Fx_paddock_dashboard_<name>` per paddock; a per-paddock annual-flooding table; manifest entries. **Acceptance:** panel 2 aggregates only valid pixels; panel 3 states its plot count; no pre/post.

## Task D2 — Site dashboards (radius neighbourhood)
One page per plot (the 66 anchors), using **all pixels within radius R of the site** (default: reuse the F5 sampling-neighbourhood radius; parameterise, ~500 m–2 km; include the footprint here since this is descriptive, and draw the radius ring on the map).

Panels (evolve the old GA_### layout, minus pre/post):
1. **Site map** — `plot_area_map` centred on the plot, radius ring drawn, background flood-frequency fill.
2. **Gauge flow context** (background) — keep, clearly secondary.
3. **RS inundation** — annual flooding for the site neighbourhood (not just the footprint).
4. **Total vegetation** — the plot's ground-cover series.
5. **Replace the Pre/post boxplot** with a **recent-vs-long-run-baseline** gauge (a single "wetter / same / drier than its own average" indicator) — descriptive snapshot, not a trend, consistent with the baseline-anomaly figure.

**Deliverables:** `Fx_site_dashboard_<plot_id>` for the 66 plots; the neighbourhood definition recorded (radius, footprint handling); manifest entries. **Acceptance:** neighbourhood pixels come from within R; the pre/post panel is gone; the baseline gauge is labelled "snapshot, not trend".

---

### Priority order
C1 (checkerboard — also gives the class raster the dashboards can reuse) → D1 (paddock dashboards) → D2 (site dashboards).

### Definition of done
Reusable `plot_area_map` in place; all figures generated + registered in `figures_manifest.csv`; QA JSONs pass (area/count reconciliation, no pre/post artefacts, CRS/extent match); and a one-line note per figure on which deck slide it lands on.
