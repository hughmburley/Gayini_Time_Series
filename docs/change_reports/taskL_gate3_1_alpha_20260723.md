# Task L · Gate 3.1 follow-up — haze α bump + diagnostics

**Date:** 2026-07-23 · **Branch:** `tier2L-gate3-rollout` (continued, off `main`) · **Spec:** v11.
**Status:** site dashboards re-rendered at α=0.20; two read-only diagnostics + a findings log produced. Reviewed and committed with the Task L branch. No registration (Gate 5, separate). No AI-authorship trailers.

## 1. Haze alpha bump (0.15 → 0.20)
`R/gayini_veg_water_census_panels.R` — the V2 paddock-haze `stat_density_2d` alpha raised 0.15 → 0.20 for in-grid legibility (the composite cell is smaller than the standalone proof). **Re-rendered the 57 site dashboards only** (paddocks/own-clouds carry no haze — unaffected). On disk: 57 site PNGs refreshed in `Output/figures/dashboards/`. Standalone report figures unaffected. Verified on GA_001: the blue paddock region now reads clearly over the grey with the red ◆ beneath it.

## 2. Mara 7 / Dinan 10 bin-count check (read-only — the wiggle IS an artifact)
Per-flood-freq-bin pixel counts behind the wiggly own-cloud lines (`Output/diagnostics/taskL_gate3_1/percentile_diag/`):
- **Mara 7 Riverine — the wiggle: 686 px, 0 of 8 bins reach the 500 support floor** (bins: 67/138/145/282/23/21/9/1). Because no bin clears 500, `gayini_fit_community_gam`'s cutoff falls to the ELSE branch (fit to the full range) and the k=10 spline over-fits 1–23 points per mid/high bin → the oscillation. **Confirmed a sparse-bin artifact, not ecology.**
- **Dinan 10** (honest short lines): Aeolian 3/11 bins ≥500 (dense low end), Riverine 1/11, Inland 2/11 — lines correctly stop where support runs out.
- **Recommendation (NOT applied — flagged for a later gate):** for small within-paddock community subsets, either raise the effective support floor, lower `k` as a function of the largest bin count, or change the ELSE branch to draw **density-only** when no bin clears the floor (rather than fitting the full range). This is a generator change; deferred pending Hugh's call.

## 3. Percentile diagnostic p05/p10/p20 (read-only, scratch — metric NOT changed)
Figures: `DIAG_percentile_grid_3x3` (3 communities × 3 percentiles + the 3 diagnostic units GA_001/GA_032/GA_052) and `DIAG_Bala6_owncloud_p05_p10_p20`.
- **Ordering:** **Inland ≫ {Aeolian ≈ Riverine}**, holding at all three percentiles (mean floors p05: 46/44/61 · p10: 52.9/51.6/66.8 · p20: 60.3/60.3/72.9). The dry<mid (Aeolian<Riverine) part does **not** hold at the floor — they're indistinguishable; only Inland separates.
- **Shape:** the response holds but **compresses toward the median** — Inland dynamic range ~40 pp at p05 → ~27 pp at p20; Riverine ~24 → ~17. **p05 maximises the flood signal.**
- **Wiggle:** does **not** reduce at p10/p20 — it's a pixel-count problem, independent of the percentile. Fix via support/k, not by switching metric.
- **Conclusion (recommendation, not a decision):** **keep p05 as the headline** — most discriminating (starkest community divergence, e.g. Bala 6). Switching the shipping metric is a science call for Hugh + Adrian; nothing changed here.

## 4. Findings log (new)
`docs/Gayini_taskL_figure_observations.md` — a narrative log of what the figures SHOW (for Gate 4). Seeded with: **Bala 6** (Riverine flat ~38–41 vs Inland climbs 43→73, one paddock two responses); **Bala 12 vs Bala 8/11** (same Inland community — Bala 12 a dip-then-rise S-curve to a ~82 plateau, Bala 8/11 a smooth monotone rise to ~65); **Mara 7** (wiggle = sparse-bin artifact); and the percentile-sensitivity observations above.

## Files touched (uncommitted, on the branch)
- **M** `R/gayini_veg_water_census_panels.R` (alpha 0.15→0.20).
- **New** `docs/Gayini_taskL_figure_observations.md`, this change report. (Diagnostics live under `Output/` — gitignored.)
- 57 site dashboard PNGs refreshed (gitignored `Output/`).

## Not done here
- Generator wiggle fix (flagged, item 2) · Gate 4 reports · Gate 5 registration · whole-farm 2-D key relocation.
