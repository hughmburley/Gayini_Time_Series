#!/usr/bin/env python
"""Ruling DL - what does the tercile cut cost, measured. REPORT ONLY, nothing applied.

veg_regime_class_8058.tif assigned every cell to a wetness band by cutting the
INTERPOLATED surface at the fixed breaks in regime_band_breaks.csv. Band MEMBERSHIP, not
just the quoted boundary values, therefore came from a surface we have since superseded.

Two measurements, because they answer different questions:

  A. SAME breaks, COUNTED surface. Isolates the surface change with the boundaries held
     fixed - how many cells sit on the other side of an unchanged line.
  B. RECUT terciles on the counted surface, then assign. This is what DL asks for: the
     boundaries move too, because they are quantiles of the surface being cut.

THE CLASS RASTER IS NOT TOUCHED. It is the footprint every zonal statistic is masked to
and it does not move before 10 August.

A caveat that is itself a finding: the counted surface takes only 35 distinct values
(k/35), so exact terciles are not achievable - every candidate boundary is shared by
thousands of cells. The interpolated surface, being continuous, could split cleanly. The
recut therefore reports the closest achievable split and the tie mass at each boundary.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "diag"
BREAKS = ROOT / "Output/diagnostics/regime_band_breaks.csv"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"

FOCUS = ["Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
         "Inland Floodplain Shrublands / Swamps"]


def assign(freq, lo_break, hi_break):
    """low <= t1 < mid <= t2 < high, matching gayini_build_veg_regime_class's cut."""
    b = np.where(freq <= lo_break, "low", np.where(freq <= hi_break, "mid", "high"))
    return b


def main() -> int:
    brk = pd.read_csv(BREAKS)
    cen = pd.read_parquet(CENSUS, columns=["community", "regime_band",
                                           "treed_context_flag", "flood_freq_pct"])
    nt = cen[(cen.treed_context_flag == 0) & (cen.regime_band != "context")].copy()
    assert len(nt) == 988831, len(nt)

    rows = []
    for cm in FOCUS:
        g = nt[nt.community == cm]
        r = brk[brk.community == cm].iloc[0]
        t1, t2 = float(r.tercile_1_pct), float(r.tercile_2_pct)

        # A: same breaks, counted surface
        a = assign(g.flood_freq_pct.values, t1, t2)
        chg_a = int((a != g.regime_band.values).sum())

        # B: recut the terciles on the counted surface
        q1, q2 = np.quantile(g.flood_freq_pct.values, [1 / 3, 2 / 3])
        b = assign(g.flood_freq_pct.values, q1, q2)
        chg_b = int((b != g.regime_band.values).sum())

        # tie mass at each recut boundary - why an exact tercile is unreachable
        tie1 = int((g.flood_freq_pct.values == q1).sum())
        tie2 = int((g.flood_freq_pct.values == q2).sum())
        shares = pd.Series(b).value_counts(normalize=True) * 100

        rows.append({
            "community": cm, "n_cells": len(g),
            "published_tercile_1_pct": t1, "published_tercile_2_pct": t2,
            "recut_tercile_1_pct": float(q1), "recut_tercile_2_pct": float(q2),
            "A_cells_changing_band_same_breaks": chg_a,
            "A_pct_changing_band_same_breaks": 100 * chg_a / len(g),
            "B_cells_changing_band_recut": chg_b,
            "B_pct_changing_band_recut": 100 * chg_b / len(g),
            "tie_mass_at_recut_break_1": tie1, "tie_mass_at_recut_break_2": tie2,
            "recut_share_low_pct": float(shares.get("low", 0)),
            "recut_share_mid_pct": float(shares.get("mid", 0)),
            "recut_share_high_pct": float(shares.get("high", 0)),
        })

    df = pd.DataFrame(rows)
    tot_a = int(df.A_cells_changing_band_same_breaks.sum())
    tot_b = int(df.B_cells_changing_band_recut.sum())
    n = int(df.n_cells.sum())

    print("  Ruling DL - consequence of the tercile cut. REPORT ONLY; nothing applied.\n")
    print(f"  {'community':38s} {'n':>9s} {'A same breaks':>16s} {'B recut':>16s}")
    for _, r in df.iterrows():
        print(f"  {r.community[:36]:38s} {r.n_cells:>9,} "
              f"{r.A_cells_changing_band_same_breaks:>8,} "
              f"({r.A_pct_changing_band_same_breaks:4.1f}%) "
              f"{r.B_cells_changing_band_recut:>8,} "
              f"({r.B_pct_changing_band_recut:4.1f}%)")
    print(f"  {'TOTAL':38s} {n:>9,} {tot_a:>8,} ({100 * tot_a / n:4.1f}%) "
          f"{tot_b:>8,} ({100 * tot_b / n:4.1f}%)")

    print("\n  recut boundaries against published, and the tie mass that makes an exact")
    print("  tercile unreachable on a surface with only 35 distinct values:")
    for _, r in df.iterrows():
        print(f"    {r.community[:36]:38s} t1 {r.published_tercile_1_pct:6.2f} -> "
              f"{r.recut_tercile_1_pct:6.2f} (ties {r.tie_mass_at_recut_break_1:,})   "
              f"t2 {r.published_tercile_2_pct:6.2f} -> {r.recut_tercile_2_pct:6.2f} "
              f"(ties {r.tie_mass_at_recut_break_2:,})")
        print(f"    {'':38s} recut band shares "
              f"{r.recut_share_low_pct:.1f} / {r.recut_share_mid_pct:.1f} / "
              f"{r.recut_share_high_pct:.1f}% against a nominal 33.3 each")

    df["support_level"] = "pixel"
    df["unit"] = "census cell (24.970268 m)"
    df["period_label"] = "1988-2022 (35 water years)"
    df["weighting"] = "unweighted over cells"
    df["scope_filter"] = "treed_context_flag = 0 AND regime_band <> 'context'"
    df["estimand"] = ("CONSEQUENCE of having cut wetness bands on the interpolated "
                      "surface. REPORT ONLY under Ruling DL - the class raster is not "
                      "modified and does not move before 10 August.")
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT / "DL_tercile_recut_consequence.csv", index=False, lineterminator="\n")
    print(f"\n  [wrote] Output/diag/DL_tercile_recut_consequence.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
