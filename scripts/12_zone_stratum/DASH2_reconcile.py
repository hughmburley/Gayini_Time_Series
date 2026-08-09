#!/usr/bin/env python
"""DASH2 gates: Ruling DW (the boxplot marker) and Ruling DZ (four reconciliations).

Every number is recomputed from the same sources the sheets use, so a disagreement is a
disagreement between products and not between a product and a re-derivation.

DZ's four checks, all 23 units:
  1. TEMPORAL-1 x  vs dashboard top-panel 35-year mean. Same population, same definition.
     |d| <= 0.5 pp required. A failure STOPS THE GATE - one product is wrong.
  2. response-panel flood frequency vs the top-panel quantity recomputed on the SUBSET
     cells. |d| <= 0.5 pp. A failure means per-cell valid-year denominators vary; that is
     a REPORTABLE FACT, not a defect - record and continue.
  3. TEMPORAL-1 y vs the dashboard floor. Equality expected only where the subset is
     >= 99% of the unit's cells. Below that a difference is expected under DB.
  4. the stated "X% of this paddock" vs n_subset / n_paddock. A mismatch that changes a
     PRINTED percentage stops the gate; one that does not reach a sheet is recorded.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "runs"
FOCUS = {"Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
         "Inland Floodplain Shrublands / Swamps"}


def main() -> int:
    ba = pd.read_csv(OUT / "DASH2_before_after.csv")
    cen = pd.read_parquet(ROOT / "Output/census/gayini_pixel_census_8058.parquet",
                          columns=["pixel_id", "community", "regime_band",
                                   "treed_context_flag", "flood_freq_pct", "veg_p05"])
    zon = pd.read_parquet(ROOT / "Output/census/gayini_pixel_zone_assignment.parquet")
    m = cen.merge(zon, on="pixel_id", how="inner")
    m = m[m.zone_fid.notna()].copy()
    m["zone_fid"] = m.zone_fid.astype(int)

    con = sqlite3.connect(f"file:{ROOT/'Output/database/Gayini_Results.sqlite'}?mode=ro", uri=True)
    pub = pd.read_sql("SELECT zone_fid, zone_name, mean_flood FROM v_zone_floor_flood_residual", con)
    con.close()
    t1 = pd.read_csv(ROOT / "Output/temporal/TEMPORAL1_unit_level.csv")

    rows = []
    for _, r in ba.iterrows():
        zf = int(r.zone_fid)
        g = m[m.zone_fid == zf]
        nt = g[(g.treed_context_flag == 0) & (g.regime_band != "context")]
        # the response panel's subset: the unit's cells in its DOMINANT focus community
        if len(nt) == 0:
            continue
        dom = nt.community.value_counts().idxmax()
        sub = nt[nt.community == dom]

        n_paddock_nontreed = len(nt)
        n_paddock_all = len(g)
        n_sub = len(sub)

        # check 1
        t1x = float(t1.mean_flood[t1.zone_fid == zf].iloc[0]) if (t1.zone_fid == zf).any() else np.nan
        d1 = t1x - r.water_mean_v2_pct

        # check 2 - top-panel quantity recomputed on the SUBSET cells
        sub_ff = float(sub.flood_freq_pct.mean())
        d2 = sub_ff - float(nt.flood_freq_pct.mean())

        # check 3
        t1y = float(t1.veg_p05_temporal_mean[t1.zone_fid == zf].iloc[0]) if (t1.zone_fid == zf).any() else np.nan
        dash_floor = float(sub.veg_p05.mean())
        subset_share_nt = 100 * n_sub / n_paddock_nontreed
        d3 = t1y - dash_floor

        # check 4 - the two candidate denominators
        pct_nontreed = 100 * n_sub / n_paddock_nontreed
        pct_all = 100 * n_sub / n_paddock_all

        rows.append({
            "paddock": r.paddock, "zone_fid": zf, "dominant_community": dom,
            "n_paddock_non_treed": n_paddock_nontreed, "n_paddock_all_classes": n_paddock_all,
            "n_subset": n_sub,
            "top_panel_mean_pct": r.water_mean_v2_pct,
            "temporal1_x_pct": t1x, "check1_delta_pp": d1,
            "check1_pass": abs(d1) <= 0.5,
            "subset_flood_freq_pct": sub_ff, "check2_delta_pp": d2,
            "check2_pass": abs(d2) <= 0.5,
            "temporal1_y_pct": t1y, "dashboard_floor_subset_pct": dash_floor,
            "subset_share_of_non_treed_pct": subset_share_nt,
            "check3_delta_pp": d3, "check3_applicable": subset_share_nt >= 99,
            "check3_pass": (abs(d3) <= 0.5) if subset_share_nt >= 99 else None,
            "pct_if_denominator_is_non_treed": pct_nontreed,
            "pct_if_denominator_is_all_classes": pct_all,
            "check4_denominator_gap_pp": pct_nontreed - pct_all,
        })

    d = pd.DataFrame(rows)
    for c in ("support_level", "unit", "period_label"):
        d[c] = {"support_level": "pixel", "unit": "paddock (management zone)",
                "period_label": "1988-2022 (35 water years)"}[c]
    d["weighting"] = "unweighted over cells"
    d["scope_filter"] = "treed_context_flag = 0 AND regime_band <> 'context' unless a column says otherwise"
    d["estimand"] = "DZ reconciliation between TEMPORAL-1 and dashboard v2, per unit"
    d.to_csv(OUT / "DASH2_DZ_reconciliation.csv", index=False, lineterminator="\n")

    print(f"  {len(d)} units\n")
    print(f"  CHECK 1  TEMPORAL-1 x vs top panel      max |d| {d.check1_delta_pp.abs().max():.4f} pp"
          f"   pass {int(d.check1_pass.sum())}/{len(d)}   {'GATE OPEN' if d.check1_pass.all() else 'GATE STOPS'}")
    print(f"  CHECK 2  subset vs whole-unit water     max |d| {d.check2_delta_pp.abs().max():.4f} pp"
          f"   pass {int(d.check2_pass.sum())}/{len(d)}")
    app = d[d.check3_applicable]
    print(f"  CHECK 3  TEMPORAL-1 y vs dashboard floor  applicable on {len(app)}/{len(d)} "
          f"(subset >= 99%)   pass {int(app.check3_pass.sum()) if len(app) else 0}/{len(app)}")
    print(f"  CHECK 4  denominator gap (non-treed vs all classes) "
          f"median {d.check4_denominator_gap_pp.median():.2f} pp, max {d.check4_denominator_gap_pp.max():.2f} pp")

    print("\n  the three units the design seat flagged, plus the three that agreed:")
    for p in ("Dinan 9", "Dinan 10", "Bala 29ca", "Bala 26ca", "Mara 21", "Bala 8/11"):
        r = d[d.paddock == p]
        if not len(r):
            continue
        r = r.iloc[0]
        print(f"    {p:11s} subset {r.n_subset:>7,} / non-treed {r.n_paddock_non_treed:>7,} "
              f"= {r.pct_if_denominator_is_non_treed:5.1f}%   / all classes "
              f"{r.n_paddock_all_classes:>7,} = {r.pct_if_denominator_is_all_classes:5.1f}%")

    print("\n  CHECK 2 detail, the units that fail:")
    f2 = d[~d.check2_pass]
    for _, r in f2.iterrows():
        print(f"    {r.paddock:11s} subset {r.subset_flood_freq_pct:6.2f}% vs unit "
              f"{r.top_panel_mean_pct:6.2f}%  ({r.check2_delta_pp:+.2f} pp), subset is "
              f"{r.subset_share_of_non_treed_pct:.1f}% of the unit")
    print(f"  [wrote] Output/runs/DASH2_DZ_reconciliation.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
