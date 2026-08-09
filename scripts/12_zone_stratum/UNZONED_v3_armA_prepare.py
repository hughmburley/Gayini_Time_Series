#!/usr/bin/env python
"""UNZONED v3, Arm A - the between-place scatter on the TEMPORAL metric.

Spec: docs/reference_update/Gayini_CC_spec_UNZONED_v3.md sections 2 and 3.

WHAT THIS IS. A regrouping, exactly as PARTSCATTER was: same census parquet, same
metric, same two axes, same three channels. The grouping key is the Gate 1 PATCH
instead of the paddock x community part. NO RASTER IS OPENED and no new metric is
computed (section 3.1).

THE ONE THING GATE 1 DID NOT PERSIST is the pixel -> patch mapping: it labels in memory
and writes only the inventory and the patch-year series. So the labelling is REBUILT
here from the census coordinates alone - 8-connected within one community, communities
taken in sorted order, exactly as Gate 1 did it - and then CHECKED against the Gate 1
inventory. That check can fail: 625 patches, and every patch's cell count and community
must match. If the rebuild drifts, the patch ids in this table would silently mean
something different from the patch ids in the Arm B series.

NO RASTER IS NEEDED FOR THE REBUILD. Gate 1 took its row/col from the cover raster's
affine transform; connectivity only needs a lattice, and an affine translation does not
change which cells touch. Row/col are derived from x_8058/y_8058 and the grid spacing
is MEASURED from the coordinates rather than assumed.

Ruling DB: 795,602 of 988,831 non-treed cells sit inside a management zone. The
remaining 193,229 are this ground.

NAMING IS FIXED (section 2). This is "unzoned standard-grazing country". It is not a
reference set, not a control, not unmanaged, and no column, file or caption may say so.

Read-only on the database. Writes to Output/unzoned.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "unzoned"
T = ROOT / "Output" / "tables"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"
ZONES = ROOT / "Output/census/gayini_pixel_zone_assignment.parquet"

PIXEL_SIDE_M = 24.970268
PIXEL_AREA_HA = PIXEL_SIDE_M ** 2 / 1e4        # DERIVED, never typed

MIN_CELLS = 500                                 # the PARTSCATTER floor, section 3.1
BARE_33 = 33                                    # v1's threshold, reported for contrast
LAND_USE = "unzoned standard-grazing country"
UNIT_CONSTRUCTION = ("8-connected component within one community, outside every "
                     "management zone")
SCOPE = ("treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid IS NULL")
PERIOD = "1988-2022 (35 water years)"
BASIS = ("SEASONAL basis: each cell's percentile is taken over the 140 seasonal "
         "composites (4 per water year x 35 water years) with MIN_SEASONS = 50. "
         "Identical to PARTSCATTER and to the TEMPORAL-1 paddock figure.")
X_QUANTITY = ("Share of the patch's cells seen wet, MEAN OVER YEARS (%). Rulings AZ / "
              "CX - NOT a between-year flood frequency. Mean over the patch's cells of "
              "the census parquet's COUNTED per-cell flood_freq_pct, exactly equal to "
              "the mean over years of the patch's within-year wet share because "
              "valid_years == 35 on every cell.")

SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}

# real-part interquartile ranges, from Gate 1's own size table - the size-matching
# window of v2 section 2.3 rule 3. Read from the file, never typed here.


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    cen = pd.read_parquet(CENSUS)
    if sorted(cen.valid_years.dropna().unique().tolist()) != [35]:
        print("HALT: valid_years is not constant 35; the x identity does not hold")
        return 1
    z = pd.read_parquet(ZONES)
    m = cen.merge(z, on="pixel_id", how="left")
    nt = m[(m.treed_context_flag == 0) & (m.regime_band != "context")]
    unz = nt[nt.zone_fid.isna()].copy()
    print(f"[mask] non-treed cells outside every management zone: {len(unz):,} "
          f"({len(unz) * PIXEL_AREA_HA:,.1f} ha)   Ruling DB expects 193,229")
    if len(unz) != 193229:
        print(f"HALT: expected 193,229 unzoned non-treed cells, got {len(unz):,}")
        return 1

    # ---- rebuild Gate 1's labelling from coordinates only ---------------------------
    x = unz.x_8058.to_numpy(float)
    y = unz.y_8058.to_numpy(float)
    # measure the spacing rather than assume it
    ux = np.unique(np.round(x, 4))
    step = float(np.median(np.diff(ux)))
    if abs(step - PIXEL_SIDE_M) > 1e-3:
        print(f"HALT: measured grid spacing {step:.6f} m differs from "
              f"PIXEL_SIDE_M {PIXEL_SIDE_M}")
        return 1
    col = np.rint((x - x.min()) / step).astype(np.int64)
    row = np.rint((y.max() - y) / step).astype(np.int64)
    H, W = int(row.max()) + 1, int(col.max()) + 1
    comm = unz.community.to_numpy(str)

    patch_id = np.zeros(len(unz), dtype=np.int64)
    meta = {}
    nxt = 0
    for cm in sorted(set(comm)):          # sorted(), exactly as Gate 1 iterated
        sel = comm == cm
        g = np.zeros((H, W), dtype=bool)
        g[row[sel], col[sel]] = True
        lab, n = ndimage.label(g, structure=np.ones((3, 3), dtype=int))   # 8-connected
        patch_id[sel] = nxt + lab[row[sel], col[sel]]
        for k in range(1, n + 1):
            meta[nxt + k] = cm
        nxt += n
        print(f"  {cm:<40s} {n:>4} components (8-connected)")
    unz["patch_ord"] = patch_id
    unz["patch_id"] = ["U%04d" % p for p in patch_id]
    print(f"[rebuild] {nxt} patches over {len(unz):,} cells")

    # ---- THE CHECK THAT CAN FAIL: does the rebuild reproduce Gate 1? -----------------
    inv = pd.read_csv(T / "UNZONED_gate1_patch_inventory.csv")
    got = (unz.groupby("patch_id")
              .agg(n_cells_rebuilt=("pixel_id", "size"),
                   community_rebuilt=("community", "first")).reset_index())
    chk = inv.merge(got, on="patch_id", how="outer", indicator=True)
    bad_join = chk[chk._merge != "both"]
    bad_cells = chk[chk.n_cells != chk.n_cells_rebuilt]
    bad_comm = chk[chk.community != chk.community_rebuilt]
    print(f"[check] Gate 1 patches {len(inv)}; rebuilt {len(got)}; "
          f"unmatched ids {len(bad_join)}; cell-count mismatches {len(bad_cells)}; "
          f"community mismatches {len(bad_comm)}")
    if len(bad_join) or len(bad_cells) or len(bad_comm):
        print("HALT: the rebuilt labelling does not reproduce Gate 1's inventory. Patch "
              "ids here would not mean what they mean in the Arm B series.")
        print(bad_cells.head(10).to_string())
        return 1
    print("  PASS - every patch id, cell count and community reproduces exactly")

    # ---- aggregate to patch grain ---------------------------------------------------
    g = unz.groupby("patch_id")
    p = g.agg(n_cells=("pixel_id", "size"),
              veg_p05_temporal_mean=("veg_p05", "mean"),
              veg_p05_within_sd=("veg_p05", "std"),
              veg_p50_temporal_mean=("veg_p50", "mean"),
              n_cells_missing_p05=("veg_p05", lambda s: int(s.isna().sum())),
              mean_share_cells_wet=("flood_freq_pct", "mean"),
              community=("community", "first")).reset_index()
    p["community_short"] = p.community.map(SHORT)
    p["area_ha"] = p.n_cells * PIXEL_AREA_HA
    p = p.merge(inv[["patch_id", "n_years_ge30_valid", "meets_support_rule",
                     "meets_bare_33_cells"]], on="patch_id", how="left")

    # ---- cross-check the water axis against Gate 1's independently built series ------
    ser = np.load(T / "UNZONED_gate1_patch_series.npy")
    sdf = pd.DataFrame(ser, columns=["patch_ord", "water_year", "n_valid", "p05",
                                     "wet_pixels", "valid_pixels", "flood_frac_pct"])
    sdf["patch_id"] = ["U%04d" % int(v) for v in sdf.patch_ord]
    gate_water = (sdf.groupby("patch_id").flood_frac_pct.mean()
                     .rename("gate1_mean_over_years").reset_index())
    cw = p.merge(gate_water, on="patch_id")
    dif = (cw.mean_share_cells_wet - cw.gate1_mean_over_years).abs()
    sup = cw[cw.meets_support_rule == 1]
    dsup = (sup.mean_share_cells_wet - sup.gate1_mean_over_years).abs()
    print(f"[check] water axis vs Gate 1 series mean-over-years: all {len(cw)} patches "
          f"max |diff| {dif.max():.4f} pp; on the {len(sup)} supported patches "
          f"max {dsup.max():.4f} pp, mean {dsup.mean():.4f}")
    # These are NOT the same construction: the census counts wet YEARS per cell over a
    # constant 35, Gate 1 divides each year's wet cells by that year's VALID cells. They
    # agree closely where coverage is complete and drift where it is not, so the
    # tolerance is stated against the supported set and reported rather than asserted
    # tightly over patches of 1 cell.
    if dsup.max() > 3.0:
        print(f"HALT: the two water routes disagree by {dsup.max():.3f} pp on a "
              f"supported patch; the x axis would not be PARTSCATTER's quantity.")
        return 1

    # ---- the three selection rules of section 3.1 -----------------------------------
    p["meets_500_cells"] = (p.n_cells >= MIN_CELLS).astype(int)
    supported = p[p.meets_support_rule == 1]
    counts = []
    for label, sel, note in [
        ("PARTSCATTER floor: >= 500 cells", p[p.n_cells >= MIN_CELLS],
         "the floor PARTSCATTER used; the two figures are read side by side and a "
         "different floor makes them incomparable"),
        ("v2 rule: >=25 yrs of >=30 valid cells", supported,
         "Gate 1's support rule - observability over time, not size"),
        (f"bare {BARE_33}-cell threshold", p[p.n_cells >= BARE_33],
         "v1's threshold, reported for contrast"),
    ]:
        counts.append({"rule": label, "n_patches": len(sel),
                       "n_cells": int(sel.n_cells.sum()),
                       "area_ha": float(sel.n_cells.sum() * PIXEL_AREA_HA),
                       "note": note})
        print(f"  {label:<40s} {len(sel):>4} patches  {sel.n_cells.sum():>8,} cells  "
              f"{sel.n_cells.sum() * PIXEL_AREA_HA:>9,.1f} ha")
    pd.DataFrame(counts).to_csv(OUT / "UNZONED_v3_armA_selection_counts.csv",
                                index=False, lineterminator="\n")

    kept = p[p.n_cells >= MIN_CELLS].copy()
    print(f"[floor] {len(kept)} of {len(supported)} supported patches survive the "
          f"{MIN_CELLS}-cell floor")
    print(kept.groupby("community_short").agg(n=("patch_id", "size"),
                                              cells=("n_cells", "sum"),
                                              ha=("area_ha", "sum")).to_string())

    # ---- size matching, v2 section 2.3 rule 3 (the failed-fork branch) --------------
    sz = pd.read_csv(T / "UNZONED_gate1_size_distributions.csv")
    real = sz[sz.set.str.startswith("real parts, ")].copy()
    real["community_short"] = real.set.str.replace("real parts, ", "", regex=False)
    iqr = {r.community_short: (r.q1, r.q3) for r in real.itertuples()
           if r.community_short != "all"}
    p["size_matched"] = 0
    for cs, (q1, q3) in iqr.items():
        k = (p.community_short == cs) & (p.n_cells >= q1) & (p.n_cells <= q3)
        p.loc[k, "size_matched"] = 1
    sm = p[(p.size_matched == 1) & (p.meets_support_rule == 1)]
    print(f"[size-match] real-part IQR window per community: "
          + "; ".join(f"{k} {v[0]:,}-{v[1]:,}" for k, v in iqr.items()))
    print(f"  supported patches inside their community's window: {len(sm)}")
    smt = (sm.groupby("community_short").agg(n=("patch_id", "size"),
                                             cells=("n_cells", "sum")).reset_index())
    smt["fitted"] = np.where(smt.n >= 10, "yes", "NO - fewer than ten survive")
    print(smt.to_string(index=False))
    smt.to_csv(OUT / "UNZONED_v3_armA_size_matched.csv", index=False,
               lineterminator="\n")

    # ---- qualifiers as columns, never prose -----------------------------------------
    for f, v in (("support_level", "pixel"),
                 ("unit", "unzoned patch (8-connected, community-pure)"),
                 ("unit_construction", UNIT_CONSTRUCTION),
                 ("land_use_label", LAND_USE),
                 ("period_label", PERIOD),
                 ("weighting", "unweighted mean over the patch's cells"),
                 ("scope_filter", SCOPE),
                 ("pixel_constant_ha", PIXEL_AREA_HA),
                 ("denominator", "the patch's own non-treed census cells"),
                 ("y_basis", BASIS),
                 ("x_quantity", X_QUANTITY),
                 ("y_metric", "veg_p05_temporal_mean"),
                 ("min_cells_filter", MIN_CELLS)):
        p[f] = v
        kept[f] = v
    p.to_csv(OUT / "UNZONED_v3_armA_all_patches.csv", index=False, lineterminator="\n")
    kept = kept.sort_values("mean_share_cells_wet").reset_index(drop=True)
    kept.to_csv(OUT / "UNZONED_v3_armA_scatter_input.csv", index=False,
                lineterminator="\n")
    print(f"  [wrote] UNZONED_v3_armA_scatter_input.csv  {len(kept)} patches")

    # ---- per-community support, EH's two range measures -----------------------------
    rows = []
    for cm, gg in kept.groupby("community"):
        xw = gg.mean_share_cells_wet
        rows.append({
            "community": cm, "community_short": SHORT[cm], "n_patches": len(gg),
            "n_cells_min": int(gg.n_cells.min()), "n_cells_max": int(gg.n_cells.max()),
            "total_cells": int(gg.n_cells.sum()),
            "total_area_ha": float(gg.area_ha.sum()),
            "water_min_pct": float(xw.min()), "water_max_pct": float(xw.max()),
            "water_span_pct": float(xw.max() - xw.min()),
            "water_span_p10_p90_pct": float(xw.quantile(.90) - xw.quantile(.10)),
            "y_min": float(gg.veg_p05_temporal_mean.min()),
            "y_max": float(gg.veg_p05_temporal_mean.max()),
            "within_area_sd_min": float(gg.veg_p05_within_sd.min()),
            "within_area_sd_max": float(gg.veg_p05_within_sd.max()),
            "r_across_patches": (float(np.corrcoef(xw, gg.veg_p05_temporal_mean)[0, 1])
                                 if len(gg) >= 3 else np.nan),
        })
    supp = pd.DataFrame(rows).sort_values("n_patches", ascending=False)
    # Two independent gates, and BOTH must pass. Section 3.1's ten-patch rule reaches
    # the same place as EH by a different route, so both are stated as columns.
    MIN_PATCHES, MIN_SPAN = 10, 10.0
    supp["min_patches_rule"] = MIN_PATCHES
    supp["min_span_p10_p90_rule"] = MIN_SPAN
    supp["passes_patch_count"] = supp.n_patches >= MIN_PATCHES
    supp["passes_EH_range"] = supp.water_span_p10_p90_pct >= MIN_SPAN
    supp["smoother_drawn"] = supp.passes_patch_count & supp.passes_EH_range
    supp["r_printed_on_figure"] = supp.smoother_drawn
    supp["r_suppression_note"] = np.where(
        supp.smoother_drawn, "",
        "r retained here but NOT printed: this community carries too few patches or too "
        "narrow a water range for a fitted line, and a correlation printed beside fitted "
        "communities would be read as one")
    supp["ruling"] = "EH (range) + UNZONED v3 section 3.1 (patch count)"
    supp.to_csv(OUT / "UNZONED_v3_armA_community_support.csv", index=False,
                lineterminator="\n")
    print()
    print(supp[["community_short", "n_patches", "water_min_pct", "water_max_pct",
                "water_span_p10_p90_pct", "passes_patch_count", "passes_EH_range",
                "smoother_drawn", "r_across_patches"]].to_string(index=False))

    if len(kept) < 10:
        print("\nArm A produces NO FIGURE: fewer than ten patches survive the floor. "
              "The unzoned ground does not support a between-place comparison at "
              "PARTSCATTER's floor. Pre-registered in section 3.1.")

    # ---- section 2's plot join ------------------------------------------------------
    po = pd.read_csv(T / "UNZONED_gate1_plot_overlay.csv")
    on_unz = po[po.on_unzoned_ground == 1]
    print(f"\n[section 2] {len(on_unz)} of {len(po)} monitoring plots fall on unzoned "
          f"ground")
    print(on_unz.treatment.value_counts().to_string())
    sg = po[po.treatment.astype(str).str.contains("tandard", na=False)]
    print(f"  standard-grazing plots in total: {len(sg)}; of those on unzoned ground: "
          f"{int((sg.on_unzoned_ground == 1).sum())}")
    po_out = (po.groupby(["treatment", "on_unzoned_ground"]).size()
                .rename("n_plots").reset_index())
    po_out["support_level"] = "plot ~1 ha"
    po_out["note"] = ("C10: plot support. This table is the join between the unzoned "
                      "analysis and every plot-support result; it is never mixed into a "
                      "pixel-support figure.")
    po_out.to_csv(OUT / "UNZONED_v3_plot_overlay_summary.csv", index=False,
                  lineterminator="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
