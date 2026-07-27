# T2 — Per-zone annual vegetation extraction

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** **v2 · 27 July 2026** — supersedes v1. Overwrite in place.
**Depends on:** T1 (`dim_management_zone` and the pixel–zone assignment — both complete)
**Blocks:** S5 of the spine; the reference-state trajectory; the paddock time-series panel
**Status:** **CRITICAL PATH.** Adrian's 24 July direction (§5.3) asks whether formerly-cropped paddocks are on a *trajectory* toward the conserved reference. The census is static. **This is the only build that produces a time dimension at paddock support.**

---

## Amendment log — v1 → v2, 27 July 2026

| # | Severity | What changed | Where |
|---|---|---|---|
| **A** | **HIGH** | **Gate B's scope filter was the ten-strata bug.** v1 said `treed_context_flag = 0`, which admits `Other / minor units` (4,951 px). Fixed in T3 and never propagated here. Must be `treed_context_flag = 0 AND regime_band <> 'context'`. | Gate B |
| **B** | MED | `support_level = 'zone_year_pixel'` was a composite. Split per the closed-ladder rule already applied in T1: `support_level = 'pixel'`, `aggregation_unit = 'zone_year'`. | Gate C |
| **C** | LOW | Context repeated the spine's `p05 ranges [1.19, 97.00]`. **97.00 is the `veg_p50` max.** p05 is `[1.19, 91.85]` all-pixel, `[1.19, 88.66]` non-treed. | Context |
| **D** | MED | Standing rules said "branch and PR with human review," contradicting `CLAUDE.md` and T1. Now direct commits to `main`. | Standing rules |
| **E** | — | **New Gate B2: the persistence-duration layer.** T3 Gate A2 defers the literal "how many years" measure here, because this task already reads the annual stack and building it in T3 would duplicate raster access. | Gate B2 |
| **F** | — | **New Gate E: the paddock time-series panel.** Conserved vs grazed veg trajectories over 1988–2023. Requested directly; it is the figure the reference-state story rests on. | Gate E |
| **G** | — | Constants now come from `gayini_params`. The magic-number lint fails the run on a bare `0.0625`. | throughout |

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine §2 — **S5** (distance-to-reference on the floor); Adrian §5.3 (reference-state trajectory) |
| **Claim under test** | None. This task builds the *substrate*; it produces no science claim of its own. |
| **Why we are doing this** | The census is **static** — sixteen columns, five across-series percentiles, no time dimension. S5 and Adrian's trajectory question both need time at a support where *n* is defensible. Plot support gives 66 units; MODIS zone-months start in 2001 and miss the entire pre-restoration baseline. The 35-layer annual veg stack exists on disk and has never been extracted to a table. |
| **What would falsify it** | Not applicable — but if extraction shows fewer than ~25 usable years for a material number of zones, S5's window must shorten and the spine changes accordingly. |
| **Spine return** | Adds a row to spine §3 (paddock support: "not yet built" → built, with real *n* and span). Updates §7 blockers. |

---

## Context

`raster_asset` registers, all `legend_status = 'confirmed'`, all `path_exists = 1`:

| Product | Path | Layers | Note |
|---|---|---|---|
| `total_veg_annual_8058` | `Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif` | 35 | Annual total veg, mean of available seasons per WY. **Primary.** |
| `total_veg_annual_8058` | `Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif` | 35 | JJA/SON growing-season mean. **Robustness cross-check.** |
| `annual_inundation_stack_8058` | `Output/rasters/inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif` | 35 | wet=1, dry=0, nodata 255→NA |
| `annual_inundation_stack_8058` | `Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif` | 35 | presence-only: valid=1, nodata 255→NA, **no zero** |

All four on the canonical 8058 grid at 24.970268 m. FC legend gate closed: percent, **no JRSRP +100 offset** — confirmed in `legend_semantics` and independently against the census, where `veg_p05` ranges **[1.19, 91.85]**.

**Do not use MODIS for this.** `fact_context_unit_month` looks like the paddock time series this task needs and is not: 250 m, 2001–2026, different sensor. It stays a context product. This warning is here because the mistake would be easy to make and nearly invisible in a finished figure.

**T1 is complete** and supplies `dim_management_zone` (64 zones, verified identity) and `gayini_pixel_zone_assignment.parquet` (885,292 zoned + 194,865 unzoned = 1,080,157). **Do not re-derive zone membership** — join to the assignment sidecar.

### The reference set must be pinned before Gate E

The four `No grazing` zones are `Bala 26ca, 27ca, 28ca, 29ca` (fids 1–4). **Verbal accounts have referred to three conserved paddocks.** Adrian's §5.2 places the lignum swamp inside "the pink paddocks."

**This set defines the reference state for S5, for the trajectory metric and for Gate E's panel.** Gate A must report which zones are in and out, from the DB, and whether the fourth is a definitional difference or a miscount. It must not be carried verbally into a figure.

Note also: `dim_management_zone.cropping_history` and the other four RESERVED columns are **NULL pending Ernest's land-use table.** So "conserved vs grazed" is available now; **"conserved vs formerly-cropped" is not.** Gate E builds what the data supports and names the gap.

---

## Gates

### Gate A — Recon (read-only) · **STOP**

- Resolve all four raster paths **from `raster_asset`**. Verify `path_exists`, CRS = 8058, resolution ≈ 24.970268, and identical extent across all four. **Read geometry from the headers via `terra`**, and run `compareGeom()`. *Note: T1 Gate A verified only 7 of the 18 8058 rasters — the two `total_veg_annual_8058` layers were **not** among them, so verify them here rather than assuming.*
- Confirm layer counts = 35 each, and report the water-year labelling of band 1 (WY1988 expected — do **not** assume; read band descriptions or the manifest).
- Report nodata handling for each: `255 → NA` must survive. **If a 255 enters a mean it adds 255 and silently destroys the series.** Assert no 255 remains a legal value after read.
- Confirm `valid_any` is presence-only (`{1}` + NA, no zero). A naive `mean()` over it is meaningless; it must be counted, not averaged.
- Confirm `dim_management_zone` = 64 rows and the assignment sidecar reconciles to 1,080,157.
- **Report the reference set** — which zone_fids carry `No grazing`, with names, and answer the three-vs-four question from the DB.

**STOP.** Review before any extraction.

### Gate B — Zonal extraction

For each of the 64 zones × 35 water years, extract from the **primary** annual veg stack, restricted to **the nine non-treed strata**:

```
gayini_params.SCOPE_NON_TREED  =  treed_context_flag = 0 AND regime_band <> 'context'
```

**Not `treed_context_flag = 0` alone** — that admits `Other / minor units` and was v1's bug.

Join zone membership via the T1 assignment sidecar. Extract:

- `n_pixels_valid`, `veg_mean`, `veg_median`, `veg_p05_spatial`, `veg_p10_spatial`, `veg_p25_spatial`
- from the inundation stack: `wet_pixels`, `valid_pixels`, `flood_frac_pct`

Two design decisions that must not be silently made in code:

1. **`veg_p05_spatial` is a within-zone, within-year *spatial* percentile.** It is **not** the census `veg_p05`, which is an across-series *temporal* percentile per pixel. These must never appear in the same figure or be compared numerically. **The column is named `veg_p05_spatial` to make the difference impossible to lose — do not shorten it.**
2. **Minimum valid support.** Drop a zone-year to NULL where `n_pixels_valid` < 500 **or** < 30% of the zone's non-treed pixel count, whichever is larger. Record the rule in the view; do not hardcode it silently.

### Gate B2 — Persistence duration layer · *new in v2*

Deferred here from T3 Gate A2 because this task already has the annual stack open.

Produce a per-pixel **count of years where annual total veg exceeds a threshold**, from the 35-layer primary stack:

- Compute at thresholds 50, 60, 70 and 80 (four layers), so the duration surface can be compared against T3's percentile surfaces at matching cuts.
- Denominator is `valid_years` per pixel, **counted from `valid_any`, not assumed to be 35.** Report `n_years_above` and `pct_years_above` separately — a pixel valid in 20 years and above threshold in 18 is not the same as 18 of 35.
- Register the raster in `raster_asset` with a `legend_semantics` string stating threshold, denominator handling, scope and the 30 m native-resolution provenance of the FC source.

**This is a distinct quantity from both T3 floors.** T3's `veg_p05` is *the level held 95% of the time*; this is *the number of years above a fixed level*. Report the correlation between them but **do not present them as versions of the same measure.**

### Gate C — Persist and register

```
v_zone_veg_annual
  zone_fid, zone_name, grazing_treatment, water_year,
  n_pixels_valid, pixel_support_pct,
  veg_mean, veg_median, veg_p05_spatial, veg_p10_spatial, veg_p25_spatial,
  wet_pixels, valid_pixels, flood_frac_pct,
  series_variant,          -- 'mean_of_seasons' | 'jja_son'
  min_support_rule,        -- the literal rule applied
  support_level,           -- 'pixel'       (closed ladder)
  aggregation_unit         -- 'zone_year'   (free text)
```

Run the extraction **twice** — once per series variant — and stack both into the same view with `series_variant` distinguishing them. The JJA/SON variant is the robustness cross-check and is worthless if it lives in a separate file nobody opens.

Underlying table `fact_zone_veg_annual`. Register any new raster or parquet with a first-50-MB SHA-256. **Additive `INSERT OR REPLACE` keyed on `(zone_fid, water_year, series_variant)`. No builder re-run.**

### Gate D — Sanity checks against known quantities · **STOP**

Report, do not interpret:

- Area-weighted mean `flood_frac_pct` across all zones per year against `v_pixel_census_by_veg_regime` totals. Should reconcile once the 18% unzoned area is accounted for.
- Zone-mean `flood_frac_pct` over all 35 years against `v_census_by_zone_stratum.flood_freq_mean` from T1. **These are independent derivations of the same quantity and should agree closely; a material discrepancy means one of the two extractions is wrong.**
- Correlation between the two `series_variant` series per zone. Low correlation in any zone is a flag, not a result.
- Count of zone-years dropped for low support, by zone.
- Correlation between Gate B2's `pct_years_above` and the census `veg_p05`, per pixel, reported as a diagnostic — **not** as evidence the two measure the same thing.

**STOP.** Review before Gate E.

### Gate E — The paddock trajectory panel · *new in v2*

The figure the reference-state story rests on. Built from `v_zone_veg_annual`, `series_variant = 'mean_of_seasons'`.

**`T2_E_paddock_trajectories.png`** — small-multiple or overlaid time series, 1988–2023:

- **Reference paddocks** (the `No grazing` set confirmed at Gate A) drawn as a distinct, heavier series — individually, **not** pooled into a mean. With *n* = 3 or 4, a mean hides whether one paddock drives the pattern.
- **Grazed paddocks** as a light band (interquartile or 10–90 range) plus the median, so 60 series don't obscure the reference.
- **Y axis: `veg_p05_spatial`.** The floor is where the flooding signal lives (p05 climbs ~45→78% across the gradient; p50 is nearly flat), and the floor is harder to manufacture by a land-use switch than mean cover. Produce a `veg_mean` variant as a secondary panel for comparison.
- **Flood years marked** on the x axis from `flood_frac_pct`, because Dawson et al.'s headline was that restoration signal appeared *only after inundation*. If convergence happens in flood years, the panel should show it.
- **Faceted by community**, because a zone spans several communities and pooling across them mixes the dry→wet gradient into the treatment comparison.

**Caption must state:** support level, `aggregation_unit`, *n* reference paddocks, *n* grazed paddocks, that `veg_p05_spatial` is a within-year spatial percentile and not the census floor, and that **cropping history is unavailable** so this is conserved-vs-grazed, not conserved-vs-formerly-cropped.

**Report, do not interpret:** whether the gap between reference and grazed narrows, widens or holds over 1988–2023. **Do not compute a distance-to-reference metric or a convergence statistic.** That definition is a science decision pinned in the spine chat (see below) — Gate E delivers the picture that informs it.

---

## Explicitly out of scope

**The distance-to-reference metric itself.** T2 builds the substrate and the descriptive panel only. The metric definition — what counts as convergence, over what window, against which reference set, and the pre-registered decision rule for convergence / no change / divergence — is a **science decision pinned in the spine chat before any code computes a number** (spine §6, §7). Do not implement it here even if it seems obvious from the panel.

**Formerly-cropped classification.** Blocked on Ernest's land-use table. The five RESERVED columns on `dim_management_zone` are its home and are deliberately NULL.

---

## Gate figures

Via `write_and_register_figure()` (R, first-50-MB SHA-256, one transaction). `figures/diagnostics/`, `T2_` prefix. Every caption states the support level.

| Gate | Figure | Passes if |
|---|---|---|
| A | `T2_A_stack_alignment.png` — four raster extents over the census grid, plus a nodata map proving 255 → NA | All coincide; no 255 survives |
| B | `T2_B_support_heatmap.png` — zone × water-year heatmap of `n_pixels_valid`, low-support cells struck out | Dropped cells are visibly identified, not silently absent |
| B2 | `T2_B2_duration_map.png` — `pct_years_above` at threshold 70 | Coherent spatial pattern; channel association visible or absent |
| D | `T2_D_variant_scatter.png` — the two `series_variant` series per zone, 1:1 line | Points near 1:1; outlier zones named |
| E | `T2_E_paddock_trajectories.png` — **the panel above** | Reference paddocks individually legible; flood years marked; faceted by community |
| E | `T2_E_paddock_trajectories_mean.png` — the `veg_mean` secondary variant | Shows why the floor was chosen |

---

## Acceptance criteria

- [ ] `fact_zone_veg_annual` = 64 zones × 35 years × 2 variants = 4,480 rows minus documented low-support drops.
- [ ] **Scope filter is the nine-stratum `SCOPE_NON_TREED`** — `Other / minor units` absent.
- [ ] No value outside [0, 100] in any veg column; **no 255 anywhere.**
- [ ] `veg_p05_spatial` named as such — no column called plain `veg_p05` in this table.
- [ ] Both series variants present; `min_support_rule` recorded in the view.
- [ ] Zone-mean flood fraction reconciles with T1's independent derivation, or the discrepancy is reported unadjusted.
- [ ] `support_level = 'pixel'` and `aggregation_unit = 'zone_year'` on every row.
- [ ] Gate B2 duration raster registered, with `valid_years` denominator handled and stated.
- [ ] **Reference set answered from the DB at Gate A** (three or four paddocks, named).
- [ ] Gate E panel written and registered, reference paddocks shown individually, flood years marked, faceted by community, caption carrying the cropping-history gap.
- [ ] **No distance-to-reference metric or convergence statistic computed.**
- [ ] Areas and constants from `gayini_params`; magic-number lint passes.
- [ ] Re-run produces identical row counts and checksums (convergence, not just stability).
- [ ] No existing table or view modified or dropped.
- [ ] Change report in `docs/change_reports/`, committed.

## Standing rules

- **Additive only.** No deletes; moves to `_archive/` only.
- **Never re-run the builder.** `reset_file` would destroy 12 unreproducible Task H rows.
- **Idempotence by convergence** — mutate an input, re-run, confirm the DB moves to the new value. `INSERT OR REPLACE`, never `OR IGNORE`.
- **Paths from the DB**; constants from `gayini_params`.
- **Never merge supports.** Closed ladder in `support_level`; precision in `aggregation_unit`. `veg_p05_spatial` and census `veg_p05` are different quantities.
- **Four-CRS discipline:** 8058 canonical · 28355 inundation · 3577 FC source · 9473 plot centroids.
- **Do not rebase** mapped area (67,349.332 ha) against true farm (85,910.8 ha).
- **Verify against data, not prose — including this spec.**
- **Git:** direct commits to `main`. No branch, no PR. Review at the STOP points. No AI attribution in commit messages.
- **Change reports committed** to `docs/change_reports/`.
