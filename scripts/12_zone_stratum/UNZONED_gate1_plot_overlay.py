#!/usr/bin/env python
"""UNZONED Gate 1 - the plot overlay. Spec section 1, last paragraph.

"Report how many of the 66 monitoring plots fall on unzoned ground and how many of
those are the fifteen standard-grazing plots - that is the join between this analysis
and the plot-support results, and it costs one spatial query."

It is computed SPATIALLY, not read from dim_plot.management_zone_coverage_pct. That
column is a persisted assertion, and this project's standing lesson (C-08) is that a
stored verdict cannot notice being wrong. Here it is wrong for three rows.

Read-only. Writes one CSV.
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

import geopandas as gpd

ROOT = Path(__file__).resolve().parents[2]
SP = ROOT / "Output" / "spatial_8058"
OUT = ROOT / "Output" / "tables" / "UNZONED_gate1_plot_overlay.csv"

plots = gpd.read_file(SP / "gayini_hectare_plots_epsg8058.gpkg")
zones = gpd.read_file(SP / "management_zones_epsg8058.gpkg")
zu = zones.union_all()
plots["frac_in_zone"] = plots.geometry.intersection(zu).area / plots.geometry.area
plots["on_unzoned_ground"] = (plots.frac_in_zone < 0.5).astype(int)

con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",
                      uri=True)
con.execute("PRAGMA query_only=1")
stored = {p: (t, c, f) for p, t, c, f in con.execute(
    "SELECT plot_id, plot_attr_treatment, management_zone_coverage_pct, spatial_review_flag "
    "FROM dim_plot")}
con.close()
plots["treatment"] = [stored[p][0] for p in plots.plot_id]
plots["stored_zone_coverage_pct"] = [stored[p][1] for p in plots.plot_id]
plots["spatial_review_flag"] = [stored[p][2] for p in plots.plot_id]
plots["stored_says_unzoned"] = (plots.stored_zone_coverage_pct < 50).astype(int)
plots["stored_agrees"] = (plots.on_unzoned_ground == plots.stored_says_unzoned).astype(int)

n_unz = int(plots.on_unzoned_ground.sum())
sg = plots[plots.treatment == "Standard grazing"]
print("=== the join to plot support ===")
print(f"  monitoring plots                              : {len(plots)}")
print(f"  falling on UNZONED ground (measured)          : {n_unz}")
print(f"  of those, Standard grazing                    : {int(sg.on_unzoned_ground.sum())} "
      f"of {len(sg)} standard-grazing plots")
print(f"  every standard-grazing plot is on unzoned ground: {int(sg.on_unzoned_ground.sum())==len(sg)}")
print("\n  by treatment:")
for t, g in plots.groupby("treatment"):
    print(f"    {t:<18s} {int(g.on_unzoned_ground.sum()):>2} of {len(g):>2} on unzoned ground")

bad = plots[plots.stored_agrees == 0]
print(f"\n=== the stored column against the geometry ===")
print(f"  dim_plot.management_zone_coverage_pct disagrees on {len(bad)} of {len(plots)} plots")
for _, r in bad.sort_values("plot_id").iterrows():
    print(f"    {r.plot_id:<8s} {r.treatment:<18s} stored {r.stored_zone_coverage_pct:>6.1f}%  "
          f"measured {100*r.frac_in_zone:>7.4f}%   spatial_review_flag={r.spatial_review_flag}")
print("  the same three are already flagged for spatial review, but for a VEGETATION overlay")
print("  reason; their zone coverage being wrong is a separate fact and is not what the flag says.")

cols = ["plot_id", "treatment", "frac_in_zone", "on_unzoned_ground",
        "stored_zone_coverage_pct", "stored_says_unzoned", "stored_agrees",
        "spatial_review_flag"]
df = plots[cols].copy()
df["method"] = "measured geometrically against management_zones_epsg8058.gpkg, not read from dim_plot"
df["support_level"] = "plot ~1 ha"
df.sort_values("plot_id").to_csv(OUT, index=False, encoding="utf-8")
print(f"\n[wrote] {OUT.name}  ({len(df)} rows)")
