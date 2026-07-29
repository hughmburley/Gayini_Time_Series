# REG-1 Gate A — recon (read-only)

**Task:** REG-1, per `docs/reference_update/Gayini_REG1_REG2_spec.md` v1.
**Date:** 29 July 2026 · **Prior:** SHA 10b8c0e
**Scope:** Gate A recon. **No writes.** STOP after.
**Verification:** live query / recompute output below.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## (1) Registered slope/r rows (verbatim)

| number_id | pinned_value | spread_min | spread_max | scope_filter |
|---|---|---|---|---|
| `floor_flood_slope_64pdk` | 0.548 | 0.498 | 0.548 | `all 64 paddocks` |
| `floor_flood_r_64pdk` | 0.71 | 0.68 | 0.71 | `all 64 paddocks` |

Both present.

## (2) Bivariate fit recomputed (`mean_of_seasons`, paddock means over 35 yr, n=64)

| statistic | computed | expected | verdict |
|---|---|---|---|
| intercept | **52.6529** | 52.6529 | hit |
| slope | **0.5478** | 0.5478 | hit |
| r | **0.7096** | 0.7096 | hit |
| SE(slope) | **0.0691** | 0.0691 | hit |
| residual SD (ddof=0, ÷n) | **6.6208** | 6.6208 | hit |
| residual SD (ddof=1, ÷n−1) | 6.6732 | — | convention note |

Sanity check reproduces exactly: predicted floor at flood = 8.5% is **57.31** (expected 57.31), against Bala 29ca's observed **40.5**.

**One convention to flag before Gate B (not a data disagreement).** The expected residual SD **6.6208** is the population SD (divide by n=64). The sample SD (÷ n−1) is 6.6732; my earlier T10 Gate C report quoted 6.67 (ddof=1). The two differ by 0.05 pp and both are defensible descriptions of the 64-residual spread. Gate B asks to register 6.6208, which I will honour (ddof=0 — the 64 residuals are the full set of paddock residuals, so the population SD is the natural descriptive choice), recording the ddof=1 value in the caveat so a reader knows which convention the "is this residual large" scale uses.

## (3) T10 output CSV row counts

| CSV | rows | expected | verdict |
|---|---|---|---|
| `T10_gateC_crosssectional_residuals.csv` | 64 | 64 | hit |
| `T10_gateC_temporal_table.csv` | 64 | 64 | hit |
| `T10_gateC_percommunity.csv` | 115 | 115 | hit |

## STOP
All Gate A expected values reproduce (one residual-SD convention flagged for Gate B). No writes. Waiting for review before Gate B (register the intercept + residual SD).
