#!/usr/bin/env python
"""PARTSCATTER - the part-grain companion to the TEMPORAL-1 paddock scatter.

Spec: docs/reference_update/Gayini_CC_spec_PARTSCATTER_update.md.

WHAT THIS IS. A REGROUPING of TEMPORAL1_prepare.py, not a new pipeline. Same census
parquet, same zone assignment, same metric; the grouping key becomes
(zone_fid, community) instead of zone_fid. NO RASTER IS OPENED (spec section 3).

  y  mean over the part's own cells of each cell's TEMPORAL 5th percentile of total
     vegetation cover. SEASONAL basis - identical definition to the paddock figure.
  x  the share of the part's cells seen wet, MEAN OVER YEARS (Rulings AZ / CX).
     Never a between-year flood frequency and never labelled as one.

THE X IDENTITY, AND WHY IT LETS THE PART VALUE BE COMPUTED WITHOUT A RASTER.
valid_years == 35 on every census cell (asserted below). With a constant denominator,

    mean over years of [100 x wet_cells(y) / N]  ==  mean over cells of flood_freq_pct

exactly, because both sides are 100 / (35 N) x SUM over cells of wet_years. So the
part's mean-over-years water value can be taken from the census parquet's per-cell
counted flood_freq_pct. That is an ALGEBRAIC identity, not an approximation, and it is
VERIFIED TWICE below rather than asserted:

  CHECK 1  at paddock grain against the published v_zone_floor_flood_residual.mean_flood
           the client has already seen on the 64-paddock figure.
  CHECK 2  at PART grain against the mean over years of PARTREG's inund_pct
           (PARTREG_part_year_floor_inund.csv), an independently built part-year series.

Both are checks that can FAIL: each stops the script on drift beyond its tolerance.

Ruling DM: the census PARQUET's flood_freq_pct is COUNTED on the 8058 grid and is the
analysis source of truth for water. The census VIEW is not used here and no interpolated
surface enters.

Read-only on the database. Writes CSVs to Output/temporal.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "temporal"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"
ZONES = ROOT / "Output/census/gayini_pixel_zone_assignment.parquet"
PARTREG = ROOT / "Output/tables/PARTREG_part_year_floor_inund.csv"
DB = ROOT / "Output/database/Gayini_Results.sqlite"

PIXEL_AREA_HA = 24.970268 ** 2 / 1e4          # DERIVED, never typed

MIN_CELLS = 500                               # spec section 3
SCOPE = "treed_context_flag = 0 AND regime_band <> 'context'"
PERIOD = "1988-2022 (35 water years)"
BASIS = ("SEASONAL basis: each cell's percentile is taken over the 140 seasonal "
         "composites (4 per water year x 35 water years) with MIN_SEASONS = 50. "
         "Identical to the TEMPORAL-1 paddock figure. Ruling CT.")
X_QUANTITY = ("Share of the part's cells seen wet, MEAN OVER YEARS (%). Rulings AZ / CX "
              "- this is NOT a between-year flood frequency and is not labelled as one. "
              "Computed as the mean over the part's cells of the census parquet's COUNTED "
              "per-cell flood_freq_pct, which is exactly equal to the mean over years of "
              "the part's within-year wet share because valid_years == 35 on every cell.")

SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    chain = []   # the section 2 reconciliation chain: every step with count and area

    # ---- load, and assert the denominator the identity depends on -------------------
    cen = pd.read_parquet(CENSUS)
    vy = sorted(cen.valid_years.dropna().unique().tolist())
    if vy != [35]:
        print(f"HALT: valid_years is not constant 35 ({vy}); the x identity does not hold")
        return 1
    z = pd.read_parquet(ZONES)
    m = cen.merge(z, on="pixel_id", how="left")
    in_zone_all = m[m.zone_fid.notna()].copy()
    in_zone_all["zone_fid"] = in_zone_all.zone_fid.astype(int)

    def step(label, df, note):
        n_parts = df.groupby(["zone_fid", "community"]).ngroups
        chain.append({"step": label, "n_parts": n_parts, "n_cells": len(df),
                      "area_ha": len(df) * PIXEL_AREA_HA, "note": note})
        print(f"  {label:<34s} {n_parts:>4d} parts  {len(df):>9,} cells  "
              f"{len(df) * PIXEL_AREA_HA:>10,.1f} ha")

    print("[chain] section 2 reconciliation")
    step("all paddock x community areas", in_zone_all,
         "every community inside a management zone, treed and context included")

    nt = in_zone_all[(in_zone_all.treed_context_flag == 0)
                     & (in_zone_all.regime_band != "context")].copy()
    step("non-treed", nt,
         "treed and context communities out of scope by design: under a canopy the "
         "satellite's ground-cover number does not mean what it means in the open")

    # The 38 excluded areas are NOT all woodland: 'Other / minor units' is untreed but
    # sits outside the nine-stratum scope, so it leaves by the regime_band test rather
    # than the canopy one. Broken out because a caption that calls all 38 woodland is
    # wrong, and this is the table that stops it being written that way.
    exc = in_zone_all[(in_zone_all.treed_context_flag != 0)
                      | (in_zone_all.regime_band == "context")]
    exc_t = (exc.groupby("community")
                .agg(n_parts=("zone_fid", lambda s: s.nunique()),
                     n_cells=("pixel_id", "size")).reset_index())
    exc_t["area_ha"] = exc_t.n_cells * PIXEL_AREA_HA
    exc_t["why_excluded"] = np.where(
        exc_t.community == "Floodplain Woodland / Forest",
        "treed: ground cover under a canopy is not comparable with ground cover in the open",
        "outside the nine-stratum non-treed scope (regime_band = 'context')")
    exc_t.to_csv(OUT / "PARTSCATTER_excluded_communities.csv", index=False,
                 lineterminator="\n")
    print("  excluded, by community:")
    for _, e in exc_t.iterrows():
        print(f"      {e.community:<38s} {e.n_parts:>3d} parts  {e.n_cells:>7,} cells  "
              f"{e.area_ha:>8,.1f} ha")

    # ---- part-grain aggregation -----------------------------------------------------
    g = nt.groupby(["zone_fid", "community"])
    part = g.agg(n_cells=("pixel_id", "size"),
                 veg_p05_temporal_mean=("veg_p05", "mean"),
                 veg_p50_temporal_mean=("veg_p50", "mean"),
                 n_cells_missing_p05=("veg_p05", lambda s: int(s.isna().sum())),
                 mean_share_cells_wet=("flood_freq_pct", "mean")).reset_index()
    part["area_ha"] = part.n_cells * PIXEL_AREA_HA

    kept = part[part.n_cells >= MIN_CELLS].copy()
    dropped = part[part.n_cells < MIN_CELLS].copy()
    step(f"surviving the {MIN_CELLS}-cell filter",
         nt.merge(kept[["zone_fid", "community"]], on=["zone_fid", "community"]),
         f"a mean over fewer than {MIN_CELLS} cells is not comparable to a mean over "
         f"thousands")
    print(f"  dropped by the filter: {len(dropped)} parts, {dropped.n_cells.sum():,} cells, "
          f"{dropped.area_ha.sum():,.1f} ha "
          f"(sizes {dropped.n_cells.min() if len(dropped) else 0}"
          f"-{dropped.n_cells.max() if len(dropped) else 0})")

    # ---- CHECK 1: paddock grain against the published figure ------------------------
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    pub = pd.read_sql("SELECT zone_fid, zone_name, treatment, mean_flood "
                      "FROM v_zone_floor_flood_residual", con)
    con.close()
    pdk = (nt.groupby("zone_fid").flood_freq_pct.mean().rename("recomputed").reset_index()
             .merge(pub, on="zone_fid"))
    d1 = (pdk.recomputed - pdk.mean_flood).abs()
    print(f"\n[check 1] paddock grain, census route vs published mean_flood over "
          f"{len(pdk)} paddocks: max |diff| = {d1.max():.6f} pp, mean {d1.mean():.6f}")
    if d1.max() > 0.05:
        worst = pdk.loc[d1.idxmax()]
        print(f"HALT: the census route does not reproduce the published paddock water "
              f"value. Worst: {worst.zone_name} {worst.recomputed:.4f} vs "
              f"{worst.mean_flood:.4f}. The x axis would not be the quantity the client "
              f"has already seen.")
        return 1

    # ---- CHECK 2: part grain against PARTREG's independently built series ------------
    pr = pd.read_csv(PARTREG)
    pr_mean = (pr.groupby(["zone_fid", "community"]).inund_pct.mean()
                 .rename("partreg_mean_over_years").reset_index())
    cmp2 = kept.merge(pr_mean, on=["zone_fid", "community"], how="inner")
    d2 = (cmp2.mean_share_cells_wet - cmp2.partreg_mean_over_years).abs()
    print(f"[check 2] part grain, census route vs PARTREG mean-over-years of inund_pct "
          f"over {len(cmp2)} shared parts: max |diff| = {d2.max():.6f} pp, "
          f"mean {d2.mean():.6f}")
    if d2.max() > 0.35:
        worst = cmp2.loc[d2.idxmax()]
        print(f"HALT: the two part-grain water routes disagree. Worst: zone "
              f"{worst.zone_fid} {worst.community} {worst.mean_share_cells_wet:.4f} vs "
              f"{worst.partreg_mean_over_years:.4f}")
        return 1

    # ---- attributes for the figure --------------------------------------------------
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    zn = pd.read_sql("SELECT zone_fid, zone_name, grazing_treatment FROM dim_management_zone",
                     con)
    con.close()
    kept = kept.merge(zn, on="zone_fid", how="left")
    kept["community_short"] = kept.community.map(SHORT)
    kept["part_id"] = kept.zone_name.astype(str) + " / " + kept.community_short

    # a part's share of its parent paddock, so L-01 clustering is visible in the table
    pdk_cells = nt.groupby("zone_fid").size().rename("paddock_cells")
    kept = kept.merge(pdk_cells, on="zone_fid")
    kept["share_of_paddock_pct"] = 100 * kept.n_cells / kept.paddock_cells
    kept["n_parts_in_paddock"] = kept.groupby("zone_fid").zone_fid.transform("size")

    for f, v in (("support_level", "pixel"),
                 ("unit", "paddock x community part"),
                 ("period_label", PERIOD),
                 ("weighting", "unweighted mean over the part's cells"),
                 ("scope_filter", SCOPE),
                 ("pixel_constant_ha", PIXEL_AREA_HA),
                 ("denominator", "the part's own non-treed census cells"),
                 ("y_basis", BASIS),
                 ("x_quantity", X_QUANTITY),
                 ("min_cells_filter", MIN_CELLS)):
        kept[f] = v
    kept["estimand"] = ("BETWEEN-PART description: how a paddock x community area's mean "
                        "per-cell temporal cover percentile relates to how wet that area "
                        "is. Not a within-unit response and no cause is attributed.")
    kept = kept.sort_values("mean_share_cells_wet").reset_index(drop=True)
    kept.to_csv(OUT / "PARTSCATTER_scatter_input.csv", index=False, lineterminator="\n")
    chain.append({"step": "plotted", "n_parts": len(kept), "n_cells": int(kept.n_cells.sum()),
                  "area_ha": float(kept.area_ha.sum()),
                  "note": "one point per part on the figure"})
    print(f"\n  [wrote] PARTSCATTER_scatter_input.csv  {len(kept)} parts")

    # ---- the dropped-parts record, so the filter is auditable ------------------------
    dropped = dropped.merge(zn, on="zone_fid", how="left")
    dropped["community_short"] = dropped.community.map(SHORT)
    dropped["reason"] = f"fewer than {MIN_CELLS} non-treed census cells"
    dropped.to_csv(OUT / "PARTSCATTER_dropped_parts.csv", index=False, lineterminator="\n")
    print(f"  [wrote] PARTSCATTER_dropped_parts.csv  {len(dropped)} parts")

    ch = pd.DataFrame(chain)
    ch["client_slide_states"] = 115
    ch["client_slide_note"] = (
        "The client's slide states 115 paddock x community areas over eight vegetation "
        "communities. The 115 is reproduced exactly by this project's PARTREG series "
        "(118 non-treed parts, 115 carrying >= 25 water years of >= 30 valid cells) and "
        "covers THREE non-treed communities, not eight. This figure differs from PARTREG "
        "by its cell-count filter, not by its scope.")
    ch.to_csv(OUT / "PARTSCATTER_reconciliation_chain.csv", index=False, lineterminator="\n")
    print(f"  [wrote] PARTSCATTER_reconciliation_chain.csv")

    # ---- per-community support table: does the colour actually carry range? ----------
    rows = []
    for cm, gg in kept.groupby("community"):
        x = gg.mean_share_cells_wet
        rows.append({
            "community": cm, "community_short": SHORT[cm], "n_parts": len(gg),
            "n_cells_min": int(gg.n_cells.min()), "n_cells_max": int(gg.n_cells.max()),
            "total_cells": int(gg.n_cells.sum()), "total_area_ha": float(gg.area_ha.sum()),
            "water_min_pct": float(x.min()), "water_max_pct": float(x.max()),
            "water_span_pct": float(x.max() - x.min()),
            "water_span_p10_p90_pct": float(x.quantile(.90) - x.quantile(.10)),
            "water_iqr_pct": float(x.quantile(.75) - x.quantile(.25)),
            "y_min": float(gg.veg_p05_temporal_mean.min()),
            "y_max": float(gg.veg_p05_temporal_mean.max()),
            "n_paddocks": int(gg.zone_fid.nunique()),
        })
    supp = pd.DataFrame(rows).sort_values("n_parts", ascending=False)
    # Pre-registered fork, spec section 3: a smoother needs enough parts AND enough
    # water-axis range. Both thresholds are stated as columns, never implied.
    #
    # OVERRIDE, and why. The fork was first written as min-to-max span >= 10 pp. That
    # measure is manufacturable by ONE point: Aeolian's 12 parts clear it at 10.87 pp
    # only because a single part sits at 11.9% while the other eleven lie between 1.0
    # and 6.1%, a 5.1 pp bulk. A loess fitted through that would be a curve drawn across
    # a gap by one observation - exactly what the spec's fork exists to prevent - so the
    # range test is taken on the CENTRAL 10th-90th percentile instead, which no single
    # point can fabricate. Both measures are kept as columns so the exclusion is
    # auditable and the letter of the original rule is still visible beside it.
    MIN_PARTS, MIN_SPAN = 12, 10.0
    supp["smoother_min_parts"] = MIN_PARTS
    supp["smoother_min_span_p10_p90_pct"] = MIN_SPAN
    supp["smoother_span_rule"] = ("central 10th-90th percentile of the water axis, not "
                                  "min-to-max: a single outlying part must not be able "
                                  "to buy a community a fitted line")
    supp["passes_superseded_minmax_rule"] = ((supp.n_parts >= MIN_PARTS)
                                             & (supp.water_span_pct >= MIN_SPAN))
    supp["smoother_drawn"] = ((supp.n_parts >= MIN_PARTS)
                              & (supp.water_span_p10_p90_pct >= MIN_SPAN))
    supp["smoother_reason"] = np.where(
        supp.smoother_drawn, "enough parts and enough water-axis range",
        "too narrow a range of wetness to support a fitted line; points drawn without "
        "one rather than extrapolating a curve across a gap")
    supp["support_level"] = "pixel"
    supp["period_label"] = PERIOD
    supp.to_csv(OUT / "PARTSCATTER_community_support.csv", index=False, lineterminator="\n")
    print(f"  [wrote] PARTSCATTER_community_support.csv")
    print()
    print(supp[["community_short", "n_parts", "n_paddocks", "n_cells_min", "n_cells_max",
                "water_min_pct", "water_max_pct", "water_span_pct",
                "water_span_p10_p90_pct", "passes_superseded_minmax_rule",
                "smoother_drawn"]].to_string(index=False))

    # ---- L-01 exposure, stated rather than left to be discovered --------------------
    multi = kept[kept.n_parts_in_paddock > 1]
    print(f"\n  L-01: {kept.zone_fid.nunique()} paddocks carry the {len(kept)} plotted parts; "
          f"{len(multi)} parts ({multi.zone_fid.nunique()} paddocks) share a paddock with "
          f"at least one other plotted part")
    return 0


if __name__ == "__main__":
    sys.exit(main())
