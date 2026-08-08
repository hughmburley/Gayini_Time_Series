#!/usr/bin/env python
"""TEMPORAL-1 completion - the assembly job.

REUSE RULE (spec section 1). Nothing here builds a pipeline. Every component already
exists and this joins them:

  step 1, per-cell temporal percentiles -> REUSED: veg_p05 / veg_p50 columns already in
          Output/census/gayini_pixel_census_8058.parquet (the same quantity the
          veg_percentiles_8058/*.tif rasters carry, already on the census grid)
  step 2, cell -> unit                  -> REUSED: gayini_pixel_zone_assignment.parquet
  zonal aggregation                     -> REUSED: a groupby on that join; the census
          pipeline's own product, no zonal-statistics machinery re-created
  the X axis                            -> REUSED: v_zone_floor_flood_residual.mean_flood,
          the published 64-paddock value the client has already seen
  the scatter                           -> new y on an existing figure shape (R side)

NO RASTER IS OPENED. Ruling CS says a missing counted raster is not a halt and to use
published unit-level values; in the event nothing needed one, because the census parquet
already carries per-cell flood frequency COUNTED from wet_years / valid_years.

Ruling CT: the Y basis is SEASONAL and every output says so in a column, because
02_build_total_veg_percentile_rasters.R computes over 140 seasonal composites with
MIN_SEASONS = 50. The annual-basis build is deferred to tomorrow.
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
DB = ROOT / "Output/database/Gayini_Results.sqlite"

PIXEL_AREA_HA = 24.970268 ** 2 / 1e4          # DERIVED, never typed

BASIS = ("SEASONAL basis: each cell's percentile is taken over the 140 seasonal "
         "composites (4 per water year x 35 water years) with MIN_SEASONS = 50. "
         "NOT the annual-basis series the regression uses. Ruling CT.")
SCOPE = "treed_context_flag = 0 AND regime_band <> 'context'"
PERIOD = "1988-2022 (35 water years)"

# Ruling CG stated the design-seat bin edges: k = 0 exactly for the dry row and k >= 25
# for the wet row. wet_years IS k here, so the edges are stated in whole years and
# printed as columns rather than implied by a cut().
WET_YEAR_BINS = [(0, 0), (1, 2), (3, 5), (6, 10), (11, 17), (18, 24), (25, 35)]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    d = pd.read_parquet(CENSUS)
    nt = d[(d.treed_context_flag == 0) & (d.regime_band != "context")].copy()
    assert len(nt) == 988831, len(nt)

    # ---- the two facts that shape everything below, measured not asserted -----------
    n_p05_nan = int(nt.veg_p05.isna().sum())
    vy = sorted(nt.valid_years.unique())
    k = (nt.flood_freq_pct / 100 * nt.valid_years).round().astype(int)
    nt["wet_years_k"] = k
    n_distinct = int(nt.flood_freq_pct.dropna().nunique())
    print(f"  non-treed cells {len(nt):,}; valid_years distinct {vy}")
    print(f"  per-cell temporal p05 missing on {n_p05_nan} cells (Ruling BT: 2)")
    print(f"  flood_freq_pct distinct values inside codes 11-33: {n_distinct}"
          f"   (Ruling BQ expects 36; k runs {k.min()}-{k.max()})")

    z = pd.read_parquet(ZONES)
    m = nt.merge(z, on="pixel_id", how="left")
    in_zone = m[m.zone_fid.notna()].copy()
    in_zone["zone_fid"] = in_zone.zone_fid.astype(int)
    print(f"  non-treed cells inside a management zone: {len(in_zone):,} of {len(m):,} "
          f"({100 * len(in_zone) / len(m):.1f}%), {in_zone.zone_fid.nunique()} zones")

    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    pub = pd.read_sql("SELECT zone_fid, zone_name, treatment, mean_floor, mean_flood, "
                      "support_level, series_variant FROM v_zone_floor_flood_residual", con)
    con.close()
    assert len(pub) == 64, len(pub)

    # ---- output 1: the unit-level table --------------------------------------------
    g = in_zone.groupby("zone_fid")
    unit = g.agg(n_cells=("pixel_id", "size"),
                 veg_p05_temporal_mean=("veg_p05", "mean"),
                 veg_p50_temporal_mean=("veg_p50", "mean"),
                 n_cells_missing_p05=("veg_p05", lambda s: int(s.isna().sum()))).reset_index()
    unit["area_ha"] = unit.n_cells * PIXEL_AREA_HA

    shares = (in_zone.groupby(["zone_fid", "community"]).size()
              .unstack(fill_value=0))
    shares_pct = shares.div(shares.sum(axis=1), axis=0) * 100
    dom = shares_pct.idxmax(axis=1).rename("dominant_community")
    dom_share = shares_pct.max(axis=1).rename("dominant_community_share_pct")
    short = {"Aeolian Chenopod Shrublands": "aeolian",
             "Riverine Chenopod Shrublands": "riverine",
             "Inland Floodplain Shrublands / Swamps": "inland"}
    sh = shares_pct.rename(columns=lambda c: f"share_pct_{short.get(c, c)}").reset_index()

    unit = (unit.merge(sh, on="zone_fid")
                .merge(dom.reset_index(), on="zone_fid")
                .merge(dom_share.reset_index(), on="zone_fid")
                .merge(pub, on="zone_fid", how="left"))
    unit["dominant_community_short"] = unit.dominant_community.map(short)
    unit = unit.sort_values("mean_flood").reset_index(drop=True)
    assert len(unit) == 64 and unit.mean_flood.notna().all()

    for f, v in (("support_level", "pixel"), ("unit", "paddock (management zone)"),
                 ("period_label", PERIOD), ("weighting", "unweighted mean over the unit's cells"),
                 ("scope_filter", SCOPE), ("pixel_constant_ha", PIXEL_AREA_HA),
                 ("denominator", "the unit's own non-treed census cells"),
                 ("y_basis", BASIS)):
        unit[f] = v
    unit["x_quantity"] = ("PUBLISHED mean_flood from v_zone_floor_flood_residual: the share of "
                          "the paddock's cells seen wet, MEAN OVER YEARS (%). Ruling AZ - this is "
                          "NOT a between-year flood frequency and is not labelled as one.")
    unit["estimand"] = ("BETWEEN-UNIT description: how a paddock's mean per-cell temporal cover "
                        "percentile relates to how wet that paddock is. Not a within-unit response.")
    unit.to_csv(OUT / "TEMPORAL1_unit_level.csv", index=False, lineterminator="\n")
    print(f"  [wrote] TEMPORAL1_unit_level.csv  {len(unit)} paddocks")

    # ---- output 3: the reconciliation table ----------------------------------------
    rec = unit[["zone_fid", "zone_name", "treatment", "mean_flood", "mean_floor",
                "veg_p05_temporal_mean", "veg_p50_temporal_mean", "n_cells",
                "dominant_community", "dominant_community_share_pct"]].copy()
    rec = rec.rename(columns={"mean_floor": "veg_p05_spatial_published",
                              "mean_flood": "published_share_cells_wet_mean_over_years_pct"})
    rec["difference_temporal_minus_spatial"] = (rec.veg_p05_temporal_mean
                                                - rec.veg_p05_spatial_published)
    rec["TABLE_ONLY_NOTE"] = ("veg_p05_spatial and veg_p05_temporal_mean are DIFFERENT METRICS. "
                              "They appear side by side here so the new figure can be checked "
                              "against the one already sent, and they are NEVER co-plotted or "
                              "captioned with the same word. 'Floor' stays reserved for "
                              "veg_p05_spatial.")
    rec["support_level"] = "pixel"
    rec["unit"] = "paddock (management zone)"
    rec["period_label"] = PERIOD
    rec["weighting"] = "unweighted mean over the unit's cells"
    rec["y_basis"] = BASIS
    rec.to_csv(OUT / "TEMPORAL1_reconciliation.csv", index=False, lineterminator="\n")
    print(f"  [wrote] TEMPORAL1_reconciliation.csv  {len(rec)} paddocks")

    # ---- output 4: community-level table, no zone join -----------------------------
    rows = []
    for lo, hi in WET_YEAR_BINS:
        sel = nt[(nt.wet_years_k >= lo) & (nt.wet_years_k <= hi)]
        for cm, gg in sel.groupby("community"):
            rows.append({
                "community": cm, "wet_years_lo": lo, "wet_years_hi": hi,
                "bin_label": f"k = {lo}" if lo == hi else
                             (f"k >= {lo}" if hi == 35 else f"k = {lo}-{hi}"),
                "flood_freq_lo_pct": 100 * lo / 35, "flood_freq_hi_pct": 100 * hi / 35,
                "n_cells": len(gg),
                "mean_flood_freq_pct": gg.flood_freq_pct.mean(),
                "mean_veg_p05_temporal": gg.veg_p05.mean(),
                "mean_veg_p50_temporal": gg.veg_p50.mean(),
                "gap_p50_minus_p05": gg.veg_p50.mean() - gg.veg_p05.mean(),
            })
    comm = pd.DataFrame(rows)
    # Ruling DA: a thin bin must carry its own warning. Aeolian's top bin is 60 cells
    # (3.7 ha) and Riverine's is 69 - a mean over that is not comparable to a mean over
    # Inland's 16,626, and a reader scanning the column cannot see the difference.
    comm["low_support_flag"] = np.where(comm.n_cells < 1000, "LOW SUPPORT", "")
    comm["low_support_note"] = np.where(
        comm.n_cells < 1000,
        "Fewer than 1,000 cells (" + (comm.n_cells * PIXEL_AREA_HA).round(1).astype(str)
        + " ha). Treat this bin's mean as indicative; it is not comparable to a "
          "well-supported bin in the same column.", "")
    comm["support_level"] = "pixel"
    comm["unit"] = "census cell (24.970268 m)"
    comm["period_label"] = PERIOD
    comm["weighting"] = "unweighted mean over cells"
    comm["scope_filter"] = SCOPE
    comm["y_basis"] = BASIS
    comm["x_quantity"] = ("per-cell between-year flood frequency COUNTED from the census "
                          "wet_years / valid_years, not read from a raster. valid_years = 35 "
                          "for every non-treed cell, so k = wet_years and the bin edges below "
                          "are whole years. Bin edges are columns, not implied.")
    comm["estimand"] = "PER-CELL means by community and wet-year bin; no zone join"
    comm.to_csv(OUT / "TEMPORAL1_community_by_floodbin.csv", index=False, lineterminator="\n")
    print(f"  [wrote] TEMPORAL1_community_by_floodbin.csv  {len(comm)} rows")

    # ---- Ruling DD: the wet end with near-permanent water removed ------------------
    # ADDITIVE. The published k >= 25 rows above are NOT replaced; this is a companion
    # table. A1's Gate 2 found that MIN_SEASONS = 50 leaves 940 cells that are wet in
    # >= 90% of the 35 years inside the non-treed census, so the wet-end means include
    # near-permanent water. This recomputes those rows without them.
    #
    # DESIGN-SEAT PREDICTION TO FALSIFY: removing them RAISES the wet-end p05, because
    # open water reads as low fractional cover - which would make the published
    # relationship conservative. The opposite direction is the more important result.
    NEAR_PERM = 90.0
    wet = nt[nt.wet_years_k >= 25]
    srows = []
    for cm, gg in wet.groupby("community"):
        keep = gg[gg.flood_freq_pct < NEAR_PERM]
        drop = gg[gg.flood_freq_pct >= NEAR_PERM]
        # Two counts, because they differ and collapsing them misleads: rows dropped,
        # and rows dropped that actually carried a percentile. The published mean
        # already skipped the 2 MIN_SEASONS cells, so only the second count moves it.
        srows.append({
            "community": cm, "bin_label": "k >= 25",
            "n_cells_published": len(gg),
            "n_cells_with_percentile_published": int(gg.veg_p05.notna().sum()),
            "n_rows_near_permanent_removed": len(drop),
            "n_cells_with_percentile_removed": int(drop.veg_p05.notna().sum()),
            "n_cells_after_removal": len(keep),
            "mean_veg_p05_published": gg.veg_p05.mean(),
            "mean_veg_p05_excl_near_permanent": keep.veg_p05.mean(),
            "delta_p05": keep.veg_p05.mean() - gg.veg_p05.mean(),
            "mean_veg_p50_published": gg.veg_p50.mean(),
            "mean_veg_p50_excl_near_permanent": keep.veg_p50.mean(),
            "delta_p50": keep.veg_p50.mean() - gg.veg_p50.mean(),
            "mean_veg_p05_of_removed_cells": drop.veg_p05.mean() if len(drop) else np.nan,
        })
    sens = pd.DataFrame(srows)
    sens["near_permanent_definition"] = (
        f"flood_freq_pct >= {NEAR_PERM:.0f}% of the 35 water years, i.e. wet in at least "
        f"{int(np.ceil(NEAR_PERM / 100 * 35))} of 35")
    sens["additive_note"] = ("COMPANION TABLE under Ruling DD. The published k >= 25 rows "
                             "in TEMPORAL1_community_by_floodbin.csv are unchanged and are "
                             "not superseded by this.")
    sens["support_level"] = "pixel"
    sens["unit"] = "census cell (24.970268 m)"
    sens["period_label"] = PERIOD
    sens["weighting"] = "unweighted mean over cells"
    sens["scope_filter"] = SCOPE
    sens["y_basis"] = BASIS
    sens["estimand"] = ("SENSITIVITY of the wet-end per-cell means to near-permanent water; "
                        "not a replacement estimate")
    sens.to_csv(OUT / "TEMPORAL1_wet_end_sensitivity.csv", index=False, lineterminator="\n")
    print("  Ruling DD - wet end (k >= 25) with near-permanent water removed:")
    for _, s in sens.iterrows():
        print(f"    {s.community[:28]:30s} p05 {s.mean_veg_p05_published:6.2f} -> "
              f"{s.mean_veg_p05_excl_near_permanent:6.2f} ({s.delta_p05:+.2f})   "
              f"cells {s.n_cells_published:,} -> {s.n_cells_after_removal:,} "
              f"({s.n_cells_with_percentile_removed} with a percentile removed)")

    # ---- the analysis CSV the R figure reads ---------------------------------------
    unit.to_csv(OUT / "TEMPORAL1_scatter_input.csv", index=False, lineterminator="\n")

    # ---- Ruling A1 Gate 2: the open-water exclusion VERIFIED, not asserted ----------
    # The producer justifies MIN_SEASONS = 50 partly as an open-water mask, verified on a
    # ~347 ha lake that lies ENTIRELY OUTSIDE the veg map. Inside the non-treed census
    # the mechanism is near-inert, and that is measured here rather than taken on trust.
    wet90 = nt[nt.flood_freq_pct >= 90]
    n_wet90_excluded = int(wet90.veg_p05.isna().sum())
    print(f"  A1 Gate 2 (verified): {len(wet90):,} non-treed cells are wet in >=90% of "
          f"years; {n_wet90_excluded} of them are excluded by MIN_SEASONS, "
          f"{len(wet90) - n_wet90_excluded:,} retain a percentile")

    facts = pd.DataFrame([{
        "fact": "non_treed_cells", "value": len(nt),
        "note": "treed_context_flag = 0 AND regime_band <> 'context'"},
        {"fact": "non_treed_cells_wet_ge_90pct_of_years", "value": len(wet90),
         "note": "A1 Gate 2, VERIFIED not asserted"},
        {"fact": "of_those_excluded_by_min_seasons", "value": n_wet90_excluded,
         "note": "so MIN_SEASONS = 50 does NOT scrub near-permanent water from the "
                 "non-treed veg map: it removes 2 of these cells and "
                 f"{len(wet90) - n_wet90_excluded:,} keep a temporal percentile. The "
                 "mechanism is real - it was verified on a ~347 ha lake - but that lake "
                 "lies outside the veg map, so inside the census the extent is negligible"},
        {"fact": "cells_missing_temporal_p05", "value": n_p05_nan,
         "note": "Ruling BT: MIN_SEASONS = 50 removes 2 of 988,831"},
        {"fact": "flood_freq_distinct_values", "value": n_distinct,
         "note": f"Ruling BQ expects 36; observed k runs {k.min()} to {k.max()}, so the "
                 f"36th value (k = 35, every year wet) does not occur in non-treed country"},
        {"fact": "non_treed_cells_inside_a_zone", "value": len(in_zone),
         "note": f"{100 * len(in_zone) / len(m):.1f}% of non-treed cells; the unit table "
                 f"describes these, not the whole census"},
        {"fact": "non_treed_cells_outside_any_zone", "value": len(m) - len(in_zone),
         "note": "outside the 64 management zones"},
    ])
    facts.to_csv(OUT / "TEMPORAL1_facts.csv", index=False, lineterminator="\n")
    print(f"  [wrote] TEMPORAL1_facts.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
