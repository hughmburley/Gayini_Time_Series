# UNZONED v3 — data dictionary

One page. Every column, its units, its support, its metric, its period. On the PARTREG
pattern, which is the item that made that pack handoverable.

**Everything here is pixel support** except `UNZONED_v3_plot_overlay_summary.csv`, which is
plot support (~1 ha) and is never mixed into a pixel-support figure (Ruling C10).
**Period is 1988–2022, 35 water years, everywhere.**
**Grid: EPSG:8058, GDA2020 / NSW Lambert. Cell 24.970268 m, 0.062351428 ha.**
**Land use: unzoned standard-grazing country** — set stocking, a designed treatment arm.
Never a reference, a control, or unmanaged.

---

## The two floor metrics — read this before any column

They are **different quantities** and are never co-plotted, differenced, or called by one
word. Both appear in `UNZONED_patch_summary.csv` because a summary must carry both; the
table names which is which in `metric_note`.

| column | construction | time axis | used by |
|---|---|---|---|
| `veg_p05_spatial_mean_over_years` | 5th percentile **across a patch's cells** within one water year, then averaged over the 35 years | intact per year | **Arm B** (within and between) |
| `veg_p05_temporal_mean` | each cell's 5th percentile **across the record**, then averaged over the patch's cells | none | **Arm A** |

`veg_p05_spatial` depends directly on unit size — a quantile over 95 cells is not the same
quantity as one over 31,750. `veg_p05_temporal_mean` was expected not to, and **that
expectation failed** (findings note §2.1).

---

## `UNZONED_patch_summary.csv` — one row per patch, 625 rows

| column | units | meaning |
|---|---|---|
| `patch_id` | — | `U0001`…`U0625`. Stable: reproduced from census coordinates and verified against the Gate 1 inventory |
| `community`, `community_short` | — | vegetation community; a patch is community-pure by construction |
| `n_cells`, `area_ha` | cells, ha | patch size. `area_ha = n_cells × 0.062351428` |
| `n_components` | count | **1 by construction** — a patch *is* one 8-connected component. A real part may be several |
| `veg_p05_temporal_mean` | % cover | **Arm A's** y. Mean over the patch's cells of each cell's temporal 5th percentile |
| `veg_p05_within_sd` | % cover | spread of that per-cell percentile **across the patch's own cells**. Spatial, not temporal. **Not a standard error** — it does not shrink as a patch gets larger. Drives figure opacity |
| `veg_p05_spatial_mean_over_years` | % cover | **Arm B's** y |
| `mean_share_cells_wet` | % | Arm A's x: mean over the patch's cells of the counted per-cell flood frequency. Equals the mean over years of the within-year wet share exactly, because `valid_years = 35` on every cell |
| `mean_share_cells_wet_armB` | % | Arm B's x: mean over years of the patch's within-year wet share, from the Gate 1 series. Agrees with the above to 0.0000 pp |
| `n_years_ge30_valid`, `n_years_fitted` | years | years the patch could be seen at ≥ 30 valid cells; years actually fitted |
| `within_patch_slope` | % cover per % wet | **Arm B §4.1.** OLS of annual spatial floor on annual wet share, within the patch |
| `within_patch_r`, `within_patch_resid_ac1` | — | correlation, and residual lag-1 autocorrelation |
| `within_patch_fitted` | 0/1 | whether a per-patch slope could be fitted |
| `descriptive_offset_pp` | pp | **Arm A §3.4.** Vertical distance from the *zoned* display smoother on the **temporal** metric. **Not a residual and not a test.** `NA` where the patch lies outside the zoned water range for its community — the absence is carried, never extrapolated into |
| `residual_vs_registered_115part_line` | pp | **Arm B §4.6.** Spatial floor minus `52.697196 + 0.547274 × mean water`. Line **applied**, never refitted |
| `residual_vs_registered_64paddock_line` | pp | as above against `52.652934 + 0.547838 ×`. The two agree to 0.03 pp on every patch |
| `meets_support_rule` | 0/1 | ≥ 25 water years with ≥ 30 valid cells. **93 patches.** The analysis set for Arm B |
| `meets_500_cells` | 0/1 | the PARTSCATTER floor. **39 patches.** The plotted set for Arm A |
| `meets_bare_33_cells` | 0/1 | v1's threshold, for contrast. **91 patches** |
| `size_matched` | 0/1 | inside this community's real-part interquartile range (v2 §2.3 rule 3). **11 supported patches; no community reaches ten, so none is fitted** |

---

## `UNZONED_regression_coefficients.csv` — 13 fits

Stackable with the PARTREG coefficient table.

| column | meaning |
|---|---|
| `fit_id`, `description` | identity |
| **`estimator`** | **`WITHIN` or `BETWEEN`, named on every row.** They answer different questions and are **never two estimates of one number** (spec §5). No two rows may be compared without matching this column |
| `metric` | `veg_p05_spatial` on every row — Arm A produces no registered coefficient |
| `community`, `subset`, `weighting` | scope of the fit |
| `n`, `n_units` | observations and units |
| `slope`, `intercept`, `r`, `resid_sd` | the fit |
| `boot_slope_p2_5 / p50 / p97_5`, `boot_draws` | bootstrap quantiles |
| **`boot_cluster`** | **`patch_id`.** There is no paddock on this ground; the real-part comparators cluster on `zone_fid`. Patches near one another are not independent, so intervals are, if anything, **too narrow** |
| `estimator_warning`, `cluster_warning` | carried in-file so a row cannot be lifted without them |

The AR(1) row is labelled a **sensitivity, not a correction**, and its interval is
**model-based, not a bootstrap** — the two interval types are not comparable and a narrower
model interval is not evidence that serial correlation does not matter.

---

## The other tables

| file | what |
|---|---|
| `UNZONED_v3_size_robustness.csv` | §1.1's fork. Both residual definitions plus the spatial comparator, recomputed (−2.014 against the spec's stated −2.01) |
| `UNZONED_v3_armA_scatter_input.csv` | the 39 plotted patches |
| `UNZONED_v3_armA_community_support.csv` | per community: n, water range, **both** EH range measures, smoother decision, r and its suppression reason |
| `UNZONED_v3_armA_descriptive_offsets.csv` · `_per_patch_offsets.csv` | §3.4, by community and per patch |
| `UNZONED_v3_armA_selection_counts.csv` · `_size_matched.csv` | the three §3.1 rules; v2 §2.3 rule 3 |
| `UNZONED_v3_armB_patch_year.csv` | 3,253 patch-years — the table Arm B actually fitted |
| `UNZONED_v3_armB_per_patch_slopes.csv` · `_slope_distribution.csv` | §4.1 |
| `UNZONED_v3_armB_within_fits.csv` · `_serial_correlation.csv` · `_ar1_fit.csv` | §§4.2–4.4 |
| `UNZONED_v3_EK_ar1_both_sides.csv` | **Ruling EK** — the same refit on both sides of the comparison |
| `UNZONED_v3_armB_between_residuals.csv` · `_between_fits.csv` · `_corroboration.csv` | §4.6 / v2 §§4.1–4.4 |
| `UNZONED_v3_armB_size_range_support.csv` · `_inland_size_quartiles.csv` | whether each community's size slope was measured over the range its patches occupy |
| `UNZONED_v3_armB_community_comparison.csv` · `_predictions.csv` | §4.5 |
| `UNZONED_v3_plot_overlay_summary.csv` | **plot support.** 18 of 66 plots on unzoned ground, all 15 standard-grazing |
| `UNZONED_patches_epsg8058.gpkg` | 625 patch polygons, EPSG:8058, attributes joined. Area closes to 12,048.1 ha against the cell count |
| `UNZONED_v3_manifest.csv` | every artefact with a first-50-MB SHA-256 |

---

## Conventions

- **Checksums:** first-50-MB SHA-256, the project's single convention.
- **No p-values anywhere.** Slope, r, residual SD, share positive, bootstrap quantiles.
- **No size adjustment anywhere.** Size figures are an expectation to read against, never a
  correction to apply.
- **Figures** `UNZONED_A1…` and `UNZONED_A2…` are registered in `figure_asset`; their five
  qualifiers are carried in `provenance_note` because `figure_asset` has no columns for
  them (Ruling EI, held).
