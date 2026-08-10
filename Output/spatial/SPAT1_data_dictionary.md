# SPAT-1 — data dictionary

One page, on the UNZONED v3 pattern. Every column, its units, its support, its metric, its
period.

**Metric throughout:** `veg_p05_temporal_mean` — each cell's 5th percentile of total
vegetation cover across the record, averaged over whatever cells a unit contains.
**`veg_p05_spatial` does not appear in this task**, because a quantile across a unit's cells
changes meaning as the unit changes size and would make a scale ladder meaningless.

**Support:** pixel throughout, aggregated to block × vegetation community in Stage B.
**Period:** 1988–2022, 35 water years, everywhere.
**Grid:** EPSG:8058, cell 24.970268 m, 0.062351428 ha.
**Extent:** 61,654.9 ha analysed of an 85,910.8 ha property — named together (EQ).

---

## Stage 0 — the registered fit

`SPAT1_stage0_coefficients.csv` · one row per community plus pooled

| column | meaning |
|---|---|
| `slope`, `intercept`, `r`, `resid_sd` | OLS at **pixel** grain, unweighted, one fit per community |
| `ci_lo`, `ci_hi`, `se` | **`interval_pending_spat1_stage_a`** — withheld on purpose. An interval here would treat ~1M autocorrelated cells as independent, the exact error the task exists to correct |
| `interval_reason` | that reason, travelling in the file |
| `composition_note` | on the pooled row only: a pooled line is lifted by differences *between* communities as much as by response within them (DB) |

`SPAT1_stage0_gam_coefficients.csv` · `_gam_curves.csv` — GAM fitted **for shape only** and
**not** used for residuals, so the residual field carries no smoother's flexibility.
`edf_total` is the flexibility actually used.

`SPAT1_stage0_vs_display_smoother.csv` — the pixel line against the unit-grain smoothers it
replaces. **Across grains**, and the `comparison_note` column says so: divergence is
confounded with grain and is not on its own evidence the linear form is inadequate.

`SPAT1_stage0_residuals.parquet` — one residual per non-treed cell with coordinates. Not
version-controlled (size).

## Stage A — how far structure reaches

`SPAT1_variogram_empirical.csv` — `lag_m`, `semivariance`, `n_pairs`, per community, per
seed, per direction. Estimator stated in-column: `gamma(h) = 0.5 × mean (z_i − z_j)²`.

`SPAT1_variogram_models.csv` — `nugget`, `psill`, `rng` per model per seed per direction.

| column | meaning |
|---|---|
| `rng` | fitted range. Exponential is the **practical** range (3a) |
| **`range_resolved_within_max_lag`** | **FALSE means this is NOT a measured range** (EN): the fit ran past the binned lag, so structure had not decayed within it. Use the flag, not the number |
| `max_lag_m` | 20,000. Nothing derived from this table is extrapolated past it |

`SPAT1_variogram_seed_stability.csv` — ten-seed range spread. **Measures sampling stability
only.** It cannot see whether the model form fits — see the next file (ES).

`SPAT1_variogram_fit_quality.csv` — **adequacy, which stability does not cover.**
`pseudo_r2`, `rmse_pct_of_sill`, `empirical_peak_lag_m`, `fall_from_peak_pct`,
`turns_over`. A variogram that turns over is not a stationary field reaching a sill; its
fitted range summarises a shape the data does not have.

`SPAT1_anisotropy_summary.csv` — range by direction, `materially_anisotropic`,
`directions_unresolved_within_max_lag`.

`SPAT1_effective_n.csv` — **the table every interval statement from here rests on.**

| column | meaning |
|---|---|
| `n`, `n_eff`, `ratio_n_eff_over_n` | nominal and effective sample size |
| `method` | Clifford–Richardson (1989) variance inflation, `n_eff = n / (1 + (n−1)ρ̄)` — **derived for a MEAN** |
| `rho_bar` | mean fitted correlation over all pairs in the set |
| `model_adequacy` | carried from the fit-quality table into this one |
| **`number_id`** | **the `dim_headline_number` row this value is pinned as**, so the file and the registry cannot drift apart (§4.4.1) |

`SPAT1_block_bootstrap_slope.csv` · `SPAT1_n_eff_two_routes.csv` — the **second, independent
route**, for the **slope** rather than the mean: spatial block bootstrap, blocks larger than
the fitted range. `n_eff_slope = n × (SE_naive / SE_block)²`. **Use the slope figure when
widening a slope interval.** Both block sizes are reported because the answer moves 25–35%
between them — these are order-of-magnitude quantities.

## Stage B — the scale ladder

`SPAT1_ladder_counts.csv` — per rung: `max_cells_a_block_can_hold`,
`floor_physically_reachable`, units before and after the 500-cell floor, area retained,
`fitted`. **The 250 m and 500 m rungs cannot reach the floor and are not fitted** (§6.1).

`SPAT1_ladder_slopes.csv` — per rung per community: `slope`, `r`, `n_units`, and

| column | meaning |
|---|---|
| `ci_lo`, `ci_hi` | **spatial block bootstrap, 8 km super-blocks, 2,000 draws.** NOT the block count, and NOT the Clifford–Richardson `n_eff`, which is derived for a mean |
| `subset` | `all`, or restricted to the x-range where \|GAM − OLS\| ≤ 2 pp (EU) |
| `eu_note` | that an OLS ladder alone cannot separate a scale effect from curvature bias |

`SPAT1_ladder_gam.csv` — the second ladder. `ame` is the **average marginal effect**, the
mean of dy/dx over each rung's own x, which is what an OLS slope estimates when the
relationship is straight — so the two ladders are directly comparable. `edf` and `k_basis`
show the flexibility used; k is scaled to the rung because coarse rungs carry few units.

`SPAT1_ladder_levels.csv` — mean level per rung per community. **Unaffected by curvature
bias**, which moves slopes and not means, so this is the clean read on UNZONED §1.1.

`SPAT1_eu_wellfitted_range.csv` — the x-interval per community where the straight line and
the curve agree within the stated threshold, and therefore which cells the restricted
ladder excludes.

`SPAT1_ladder_block_units.csv` — the block × community units themselves, per rung.

## Figures

`SPAT1_F1_variogram_by_community.png` · `_F2_directional_variogram.png` ·
`_F3_scale_ladder.png`. Registered in `figure_asset`; five qualifiers in
`provenance_note` because `figure_asset` has no columns for them (EI, held).

## Conventions

- **No p-values anywhere.** Slope, r, residual SD, range, nugget, sill, n, n_eff and
  bootstrap quantiles with their basis named.
- **Nothing is applied.** No interval widened, no estimate corrected, no existing figure
  re-rendered. These tables measure.
- **Checksums:** first-50-MB SHA-256, the project's single convention.
