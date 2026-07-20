# Tier 2 · Task H — all-pixel census, first cut

> ⚠️ **SUPERSEDED — the authoritative Task H spec is [`Tier2_TaskH_all_pixel_census_v4.md`](Tier2_TaskH_all_pixel_census_v4.md).** Retained for lineage only; do not action. *(D1 fix, 20 Jul 2026.)*

*Task spec for Claude Code. Follows Adrian's 15 Jul direction (`Gayini_Adrian_comments_20260715.xlsx`) and the sequenced plan (`Gayini_sequential_task_list_20260715.md`). Item numbers (#n) refer to Adrian's table.*

**Workflow: recon first — report and STOP at Gate 1 before writing analysis code.** Then branch-and-PR into `main`, held for review. Do not merge.

---

## Objective

First cut of the all-pixel (census) approach: replace *sampled* estimates with *every pixel* in each veg × wetness class. Deliver the census flood-frequency result (which removes the "thinly sampled / provisional" caveat by construction), plus a static total-veg percentile raster and the veg-vs-inundation census analysis.

**Additive only.** Nothing is deleted. The sub-sampling code (Task F: `gayini_stratum_allocation`, `gayini_draw_monte_carlo`) stays on `main`, uncalled — it is archived in *emphasis*, not removed. It may be used again.

## Scope decisions already made (do not re-litigate)

- **Percentile = across-the-whole-series, ONE value per pixel.** Not per-year. Five rasters: 5th / 10th / 20th / 30th / 50th of total veg (green + dead). This is a deliberate staged first cut — the annual version is a later re-run if the static result warrants it.
- **Consequence, accepted:** a static raster cannot feed the lag analysis (#3) or any time-resolved veg response. Those stay on the existing per-plot method for now. Not a gap — a sequencing choice.
- **Canonical CRS = EPSG:8058 (GDA2020 / NSW Lambert).** GDA2020 wherever possible; this matches the CLAUDE.md standing rule and the census substrate is already there (`veg_regime_class_8058.tif`; `census_stratum` counts reconcile to it exactly). **All census arithmetic, all new rasters, and all products are 8058.** See §H2 for how the natively-28355 stack is brought across.
- **Out of scope:** the gauge × RS mixed-effects / residual model (#12) — research only, parked.

---

## Gate 1 — Recon (report, then STOP)

Answer these before any analysis code. Report findings and proposed decisions; wait for sign-off.

1. **Do farm-wide fractional-cover source rasters exist locally, or only plot-window extracts?** Every raster-builder in `scripts/03_inundation_products/` currently makes *inundation* rasters; `02_extract_heavy/internal/03_extract_fractional_cover_full_impl.R` is a plot **extraction**. If only plot windows exist, P-veg is a data-acquisition problem, not raster math — say so immediately, it changes everything downstream.
2. **How does the existing pipeline bridge 8058 and 28355?** `census_stratum` reconciles to `veg_regime_class_8058.tif` exactly (independent recount, diff = 0 on all 11 rows), while the annual stack (`annual_wet_any/valid_any_1988_2023.tif`) is **EPSG:28355, 25 m, 35 layers**. Script `09_build_pixel_census_view.R` already bridges these — report **how** (does it reproject the stack, or a derived continuous frequency surface, or the class raster?), and report the exact 8058 grid definition (extent, res, origin) that `veg_regime_class_8058.tif` sits on. The canonical CRS is **decided (8058)** — this question is about *mechanism and grid definition*, not about choosing.
   - **Confirm and report:** are `census_stratum`'s `n_pixels` counts genuinely 8058-grid counts? (They should be — the independent recount was against the 8058 class raster.) If any part of the current census arithmetic actually happens in 28355, say so plainly, because standardising on 8058 would then shift the published counts and that must be surfaced, not absorbed.
3. **Infra options for the census store (#11).** ~240k pixels × 35 yrs × N variables will not fit the results-DB pattern. Propose: separate SQLite vs parquet vs CSV, with a recommendation and reasoning. Do not build yet.
4. **Fractional-cover band semantics.** Confirm which bands compose *total veg = green + dead* (see `config/class_legends/fractional_cover_bands.csv`) and the nodata/mask convention.

## Gate 2 — Work (after sign-off)

### H1 · Quick wins (no dependencies)

- **Dashboard label fix (#21):** "Total vegetation (green cover)" → **"Total veg (green + dead)"**. It includes dead veg; the current label is wrong. Applies to all three dashboards.
- **Archive the Task F spec:** move `docs/Tier1_TaskF_spatial_resampling_spec_v2.md` → `docs/archive/`, add a `SUPERSEDED-BY: Gayini_sequential_task_list_20260715.md` header explaining the all-pixel pivot. **Do not delete; do not touch the Task F code on `main`.**

### H2 · Total-veg percentile rasters (#6, #7)

- Build **5 rasters**: 5th / 10th / 20th / 30th / 50th percentile of **total veg (green + dead)**, computed per pixel **across the whole 1988–2023 record**.
- **Grid discipline — the main trap here.** Build to **EPSG:8058**, on *exactly* the grid `veg_regime_class_8058.tif` sits on: identical CRS, extent, resolution **and origin**. Assert alignment programmatically (`terra::compareGeom()` or equivalent) before any zonal join — a silent misalignment produces plausible-looking wrong numbers, which is worse than a crash. Reproject to **new files only; never mutate originals** (standing rule). Mind the three-CRS situation: 8058 canonical · 28355 stack · 9473 `dim_plot` centroids.
- Register the rasters in `raster_asset` with CRS/extent populated (they are a Deliverable-1 product).
- **Rationale to record in the code header (#7):** lower percentiles are the *floor* of the system — "when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem". Resilience, not average condition — a different question from mean cover.

### H3 · Track A — census inundation (#1, #2, #24)

Needs **no new data** — the annual stack and `veg_regime_class_8058.tif` both already exist. This is a zonal statistic, not a build.

- **H3.0 · Bring the stack onto the canonical grid (do this once, not on the fly).** Reproject the 35-layer `annual_wet_any` / `annual_valid_any` stack from 28355 onto the 8058 census grid **once**, write it as a new registered raster product (`raster_asset`, CRS/extent populated), and have every downstream step consume that. Do not reproject repeatedly inside analysis code — one defined product keeps the numbers stable and reproducible.
  - **Resampling rule — non-negotiable: `method = "near"`.** These are binary/categorical masks. **Never bilinear or cubic** — interpolation would produce fractional "wet" values, which are meaningless and would silently corrupt every frequency count downstream. Assert the reprojected layers contain only the legal value set (`{0,1,2}`, with `3` = mask if present) and fail loudly otherwise.
  - Originals in 28355 remain untouched (standing rule).
  - **Report the reconciliation:** after reprojection, do the census counts per class still match `census_stratum` (diff = 0)? If they shift, report the magnitude and cause rather than proceeding — this is the check that proves the grid is right.

- **H3.1 (#1):** census veg × wetness matrix (p18) — annual flood frequency per class using **every pixel**, per year. Headline metric unchanged: `100 × wet-valid-years ÷ valid-years`. Wet-rule via the neutral `gayini_inundation_wet_rule.R` (`wet ∈ {1,2}`, `valid ∈ {0,1,2}`, `mask = 3`).
- **H3.2 (#2):** re-run the F6 trend test on the census series — Adrian's framing is **systematic vs stochastic**. Same robust test as the shut gate (Theil–Sen + Mann–Kendall, LOESS shape, drop-two-floods).
  - **Expectation, state it in the change report:** a census removes *spatial* sampling uncertainty but adds **no temporal power** — systematic-vs-stochastic is a question about 35 annual observations regardless of pixel count. Expect the verdict to **harden to the existing answer** (8 no-trend · 1 non-stationary · 0 directional; episodic, climate-paced) with the "thinly sampled" caveat gone. That is the win. If the verdict *changes*, that is a red flag to investigate, not a result to celebrate.
- **H3.3 (#24):** per-year cut — analyse each year rather than only whole-record aggregates. Cheap; likely informative given the episodic signal.
- **`MIN_VALID_COVERAGE`:** default **40**, flagged. Still live and now *more* important — a census contains pixels with widely varying valid-year counts. Emit a one-line sensitivity note on how many pixels the threshold drops.

### H4 · Census veg vs inundation (#8)

- Per pixel: **static veg floor** (chosen percentile) vs **flood frequency**, across all valid pixels, grouped by veg × wetness class.
- Report per-class relationship strength. This is the static analogue of F7 — do **not** present it as the lag result.

### H5 · Census display convention (#18) — blocks every census figure

- All-pixel figures must **not** plot thousands of points: use a **kernel-density / hex-bin surface and/or a CI band around the trend**.
- Our existing sqrt-x scatter (α ≈ 0.1 + binned mean ± 95% CI) is **already halfway there** — the binned-mean-and-band layer is exactly the convention. Keep the plot-scale version; **add** a census variant that swaps the point layer for hexbin/2-D density at ~240k points.
- Adrian has examples from his own work — flag that we should request them rather than inventing a convention.

## Acceptance gate

1. Recon reported and signed off before analysis code (Gate 1).
2. **Everything analytical is EPSG:8058.** Veg percentile rasters and the reprojected annual stack align **exactly** to the `veg_regime_class_8058.tif` grid (CRS, extent, res, origin) — asserted via `compareGeom()`, not assumed. Originals unmutated; new products registered in `raster_asset` with CRS/extent populated.
2a. Reprojection of the binary stack used **nearest-neighbour only**; reprojected layers assert to the legal value set; census counts reconcile to `census_stratum` (or the shift is reported, not absorbed).
3. Headline metric = between-year flood frequency; `annual_occurrence_pct` never presented as headline.
4. 4-class `simplified_vegetation_group` only; no `vegetation_adrian_group` / `period` leakage; no pre/post language.
5. Wet-rule sourced from the neutral file.
6. `MIN_VALID_COVERAGE` = 40 flagged, with a sensitivity line.
7. No census figure plots raw points at scale (H5 convention applied).
8. F6 census verdict reported against the expected 8/1/0 — divergence investigated, not celebrated.
9. Task F code untouched on `main`; Task F spec archived (not deleted) with a superseded-by header.
10. Post-build guard (`gayini_assert_post_build_objects()`) passes; spine validation clean.
11. Branch-and-PR, **held — do not merge**.

## Handoff

- Review bundle → `Output/review_bundles/tier2H_all_pixel_census/`, zipped.
- Change report → `docs/change_reports/tier2H_all_pixel_census_<date>.md` (local, per convention). Commit code + small tables only — **never** the census extraction itself.

## Open questions (flag; do not guess)

- Infra decision (#11) — awaiting the Gate 1 recommendation.
- Which percentile becomes canonical (#9)? Compute all five, report which shows the strongest relationship with inundation, **recommend one** — the decision is Hugh's, and once made it is used consistently everywhere.
- Adrian's own examples of the density/CI display convention (#18).

---
*Deliverable 1 (updated database) is the target this task feeds. Site reports (Deliverable 2) are the next task and are largely un-gated — do not start them here.*
