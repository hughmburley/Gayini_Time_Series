#!/usr/bin/env python
"""SPAT-1 Stage 0 - the registered fit on the temporal metric, at pixel grain.

Spec: docs/spatial/Gayini_CC_spec_SPAT1.md section 3.

WHY THIS EXISTS. There is no registered line on veg_p05_temporal_mean. PARTSCATTER's and
UNZONED's curves are DISPLAY SMOOTHERS and no coefficient may be taken from one, so
residuals cannot be computed against anything. Stage A needs residuals, so the fit is
built first.

METRIC, FIXED (section 2): veg_p05_temporal_mean throughout. veg_p05_spatial does not
appear in this task at all. The reason is structural - the spatial floor is a quantile
ACROSS a unit's cells, so its meaning changes as the unit changes size, which on a scale
ladder is not a confound to measure but a definitional change that makes the ladder
meaningless. The temporal metric is a per-cell value, so the same quantity exists at
every rung including the pixel.

THE INTERVAL IS DELIBERATELY WITHHELD. An interval at pixel grain before Stage A would be
the exact error this task exists to correct: it would treat ~1M spatially autocorrelated
cells as independent observations. The interval columns carry
`interval_pending_spat1_stage_a` and the reason travels in the file.

NO P-VALUES (section 7).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "spatial"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"
SCRATCH = Path("C:/Users/HUGHPC~1/AppData/Local/Temp/claude/d--Github-repos-Gayini/"
               "00d60f21-fee6-4bc8-a50a-2623689d36ac/scratchpad")

PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
PROPERTY_HA = 85910.8          # EQ: extent is never stated without both denominators
SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}
PENDING = "interval_pending_spat1_stage_a"


def ols(x, y):
    mx, my = x.mean(), y.mean()
    b = np.sum((x - mx) * (y - my)) / np.sum((x - mx) ** 2)
    a = my - b * mx
    res = y - (a + b * x)
    r = float(np.corrcoef(x, y)[0, 1])
    return float(a), float(b), r, float(res.std(ddof=2)), res


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    d = pd.read_parquet(CENSUS, columns=["pixel_id", "community", "regime_band",
                                         "treed_context_flag", "veg_p05",
                                         "flood_freq_pct", "x_8058", "y_8058"])
    nt = d[(d.treed_context_flag == 0) & (d.regime_band != "context")].copy()
    if len(nt) != 988831:
        print(f"HALT: expected 988,831 non-treed cells, got {len(nt):,}")
        return 1
    n_missing = int(nt.veg_p05.isna().sum())
    nt = nt[nt.veg_p05.notna() & nt.flood_freq_pct.notna()].copy()
    nt["community_short"] = nt.community.map(SHORT)
    analysed_ha = len(nt) * PIXEL_AREA_HA
    print(f"[scope] {len(nt):,} non-treed census cells fitted "
          f"({n_missing} dropped for a missing percentile)")
    print(f"[extent] analysed {analysed_ha:,.1f} ha of a {PROPERTY_HA:,.1f} ha property "
          f"({100 * analysed_ha / PROPERTY_HA:.0f}%) - Ruling EQ, both named or neither")

    rows, resid_parts = [], []
    for scope, g in [("all pooled", nt)] + [
            (cs, nt[nt.community_short == cs]) for cs in ("aeolian", "riverine", "inland")]:
        a, b, r, sd, res = ols(g.flood_freq_pct.to_numpy(float),
                               g.veg_p05.to_numpy(float))
        rows.append({
            "fit_id": f"SPAT1_stage0_{scope.replace(' ', '_')}",
            "scope": scope, "community": scope,
            "estimator": "OLS at PIXEL grain, unweighted (each cell is one observation)",
            "metric": "veg_p05_temporal_mean", "y_variable": "veg_p05 (per-cell temporal)",
            "x_variable": "flood_freq_pct (per-cell counted between-year)",
            "n_cells": len(g), "area_ha": len(g) * PIXEL_AREA_HA,
            "slope": b, "intercept": a, "r": r, "resid_sd": sd,
            "ci_lo": PENDING, "ci_hi": PENDING, "se": PENDING,
            "interval_reason": (
                "WITHHELD ON PURPOSE. An interval here would treat ~1M spatially "
                "autocorrelated cells as independent observations, which is the exact "
                "error SPAT-1 exists to correct. Stage A measures the effective sample "
                "size; the interval is computed then and not before."),
            "composition_note": (
                "POOLED IS COMPOSITION-BEARING: a pooled line is lifted by differences "
                "BETWEEN communities as much as by response within them (Ruling DB and "
                "the PARTSCATTER finding). Read the community rows."
                if scope == "all pooled" else ""),
        })
        if scope != "all pooled":
            gg = g[["pixel_id", "x_8058", "y_8058", "community_short",
                    "flood_freq_pct", "veg_p05"]].copy()
            gg["residual"] = res
            resid_parts.append(gg)
        print(f"  {scope:<11s} n {len(g):>9,}  slope {b:+.5f}  intercept {a:8.4f}  "
              f"r {r:+.4f}  resid sd {sd:6.3f}")

    co = pd.DataFrame(rows)
    co["support_level"] = "pixel"
    co["period_label"] = "1988-2022 (35 water years)"
    co["scope_filter"] = "treed_context_flag = 0 AND regime_band <> 'context'"
    co["pixel_constant_ha"] = PIXEL_AREA_HA
    co["analysed_ha"] = analysed_ha
    co["property_ha"] = PROPERTY_HA
    co["form_note"] = ("OLS is the REGISTERED expectation used for Stage A residuals. The "
                       "GAM fitted alongside is reported for shape and is NOT used to "
                       "compute residuals, so the residual field carries no smoother's "
                       "flexibility.")
    co.to_csv(OUT / "SPAT1_stage0_coefficients.csv", index=False, lineterminator="\n")
    print(f"  [wrote] SPAT1_stage0_coefficients.csv")

    res_df = pd.concat(resid_parts, ignore_index=True)
    res_df.to_parquet(OUT / "SPAT1_stage0_residuals.parquet", index=False)
    print(f"  [wrote] SPAT1_stage0_residuals.parquet  {len(res_df):,} cells")

    # data for the R-side GAM (no arrow in this R install, so a CSV crosses the gap)
    SCRATCH.mkdir(parents=True, exist_ok=True)
    nt[["community_short", "flood_freq_pct", "veg_p05"]].to_csv(
        SCRATCH / "SPAT1_gam_input.csv", index=False, lineterminator="\n")
    print(f"  [wrote] scratch GAM input {len(nt):,} rows")

    # ---- the fitted line against the display smoother it replaces -------------------
    # ACROSS GRAINS, and that is stated rather than glossed: the OLS is fitted on cells,
    # the loess was fitted on units. Evaluating both at the units' own x values compares
    # the two EXPECTATIONS at the same place, but any divergence is confounded with grain
    # and cannot be read as the linear form being wrong on its own.
    ps = pd.read_csv(ROOT / "Output/temporal/PARTSCATTER_scatter_input.csv")
    cmp_rows = []
    for cs in ("aeolian", "riverine", "inland"):
        u = ps[ps.community_short == cs]
        c = co[co.scope == cs].iloc[0]
        pred = c.intercept + c.slope * u.mean_share_cells_wet
        diff = u.veg_p05_temporal_mean - pred
        cmp_rows.append({
            "community": cs, "n_units": len(u),
            "unit_x_min": u.mean_share_cells_wet.min(),
            "unit_x_max": u.mean_share_cells_wet.max(),
            "pixel_ols_slope": c.slope, "pixel_ols_intercept": c.intercept,
            "mean_unit_minus_pixel_prediction_pp": float(diff.mean()),
            "median_diff_pp": float(diff.median()),
            "sd_diff_pp": float(diff.std()),
        })
    cmp = pd.DataFrame(cmp_rows)
    cmp["comparison_note"] = (
        "ACROSS GRAINS. The OLS is fitted on CELLS; the display smoother it replaces was "
        "fitted on UNITS. Both are evaluated at the units' own water values, so this "
        "compares two expectations at the same place - but any divergence is confounded "
        "with grain and is NOT evidence on its own that the linear form is inadequate. "
        "Section 6.2's ladder is what separates them.")
    cmp.to_csv(OUT / "SPAT1_stage0_vs_display_smoother.csv", index=False,
               lineterminator="\n")
    print("\n[vs display smoother] unit value minus the pixel line's prediction, pp")
    print(cmp[["community", "n_units", "mean_unit_minus_pixel_prediction_pp",
               "median_diff_pp", "sd_diff_pp"]].to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
