# T13 Gate B — the two continuous measures (115 parts)

**Task:** T13 Gate B, per `Gayini_T13_spec.md` v1 + the design-seat holds (29 Jul).
**Date:** 29 July 2026 · **Prior:** SHA acf1c04 (Gate A)
**Scope:** compute the continuous measures per part; **report only, no DB write** (the classification table is Gate E). **No classification computed** — the pre-registered cut is applied at Gate C.
**Verification:** live output of `build_T13_gateB_measures.py`.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## 1. Flood-variance flag — reported FIRST (the hold)

Where a part's own flood fraction barely varies, `water_slope` is fitted on almost nothing and `trend_adj` becomes a correction computed from noise. Within-part SD of `flood_frac_pct` is on every row of the measures CSV.

**Parts with within-part SD(flood_frac_pct) < 2 pp: 0 of 115.**

No part is flagged. Every `water_slope` is estimated from real flood variance, so **`trend_adj` is reliable for all 115 parts** and the water adjustment is meaningful everywhere. The method's applicability is not compromised at part grain (consistent with paddock grain, where 0 of 64 were flagged). This is reported before the trends, per the hold — had a large share been flagged it would have constrained what Gate C can claim; it does not.

## 2. Community SD — the z-score scale (the hold)

`level_z` and `trend_z` divide each deviation by the **within-community SD** of the deviations. Those SDs differ substantially, so a z of −1.0 means a different amount of ground in each community:

| community | n parts | SD(level_dev) | SD(trend_dev) |
|---|---|---|---|
| Aeolian Chenopod Shrublands | 17 | **11.92 pp** | 0.241 pp/yr |
| Riverine Chenopod Shrublands | 37 | **10.86 pp** | **0.330 pp/yr** |
| Inland Floodplain Shrublands / Swamps | 61 | **6.03 pp** | 0.179 pp/yr |

Inland's level spread is roughly **half** the other two, so a `level_z` = −1.0 is ~12 pp below the community median in Aeolian or Riverine but only ~6 pp in Inland. On trend, Riverine's spread (0.330) is ~1.8× Inland's. **The Gate D map caption must state this** — it is the L-01 grain-and-scale problem in a different coat: a fixed z means unlike amounts of ground across communities. Reported explicitly so it cannot be discovered later.

## 3. The measures

For each of the 115 parts (`mean_of_seasons`, ≥25 yr, `n_pixels_valid ≥ 30`), computed and written to `Output/tables/T13_gateB_part_measures.csv`:

`level`, `level_dev` (vs community median level), `level_z`; `trend_raw` (OLS `veg_p05_spatial`~year), `water_slope` (OLS `veg_p05_spatial`~own annual flood fraction), `trend_adj` (residuals of `water_slope` regressed on year), `trend_dev`, `trend_z`; **SE on `trend_raw`, `water_slope`, and `trend_adj`**; `flood_sd`; `flood_var_flag_lt2pp`; `lag_water_r`.

**No p-values** — 35 consecutive annual observations are not independent and a naive p would overstate significance. The `trend_adj` residual series is written to `Output/tables/T13_gateB_trend_adj_residuals.csv` (4,025 rows) so the autocorrelation is visible.

**Continuity with T10 (continuous measures, no state applied).** Bala 29ca's three parts, in z terms — the paddock T10 traced everything to:

| part | level_z | trend_z |
|---|---|---|
| Bala 29ca · Aeolian | (see CSV) | +1.41 |
| Bala 29ca · Riverine | (see CSV) | +2.56 |
| Bala 29ca · Inland | (see CSV) | −0.03 |

These reproduce the T10 finding as continuous measures: the recovery is concentrated in the dry western (Aeolian/Riverine) parts and its Inland part tracks the community. No cut is applied here.

## 4. Water specification — current vs lagged

Run both. **The one-year-lagged fit beats current-year for 34 of 115 parts** (~30%), against 18 of 64 (~28%) at paddock grain — modestly more relevant at part grain, but still a minority. **Current-year remains primary**, declared in advance (§4), so the choice is not made on the result. The `lag_water_r` per part is in the measures CSV for inspection.

## What was NOT done (pre-registration)
No four-state classification computed, no state counts reported, and the abandoned pilot figure is not reproduced or referenced. The pre-registered ±1.0 cut is applied only at Gate C, after this gate is reviewed and closed.

## Invariants
- Report/compute only: two CSVs written to `Output/tables/`; **no DB write, no builder run, no existing object modified.**
- Producing script tracked.

## STOP
Continuous measures computed for all 115 parts; flood-variance flag (0/115) and community SDs reported first, per the holds. Waiting for review before Gate C (apply the pre-registered ±1.0 cut, the 0.50–1.50 sweep, and the drop-two-floods robustness).
