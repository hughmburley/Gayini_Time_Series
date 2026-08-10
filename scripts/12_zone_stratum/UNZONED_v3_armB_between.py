#!/usr/bin/env python
"""UNZONED v3, Arm B section 4.6 - the between-unit prediction, on the SPATIAL floor.

Spec: UNZONED v3 section 4.6, which runs v2 sections 4.1-4.4 as written.

METRIC: veg_p05_spatial throughout. The temporal metric does not appear in this file.

NEITHER REGISTERED LINE IS REFITTED (v2 4.1). Both are READ - the 115-part line from
PARTREG_part_regression_coefficients.csv, the 64-paddock line from dim_headline_number -
and each is checked against the value the spec states before it is used. A quoted
coefficient that has travelled across three specs is exactly the kind of number this
project has been wrong about.

RULING EL. The size-matched branch is expected to survive nothing. That is reported as a
BOUND on what this section may claim, not as an empty table - and it binds the three
communities DIFFERENTLY, because their spatial-floor size slopes differ by a factor of 30
(Aeolian -7.64, Riverine -4.41, Inland -0.23). Inland's all-patches result is
interpretable WITHOUT size matching; the other two are not. That distinction is carried
as a column so the caveat cannot be applied as a blanket.

NO SIZE ADJUSTMENT IS MADE ANYWHERE (v2 2.3, spec section 5).
NO P-VALUES (section 5).
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "unzoned"
T = ROOT / "Output" / "tables"
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"

BOOT_SEED = 20260810
N_BOOT = 2000
# what the spec says these are, checked against what is actually stored
SPEC_115 = (52.697196, 0.547274)
SPEC_64 = (52.652934, 0.547838)
REAL_INTERVAL = (0.359939, 0.750430)     # v2 4.3, the real-part slope interval
PRE_REG_POOLED_OFFSET = 2.4              # spec 4.6, corrected from v1's +1.9
# spatial-floor size slopes, pp per decade, from v2 2.3 - the EL discriminator
SIZE_SLOPE = {"aeolian": -7.64, "riverine": -4.41, "inland": -0.23}
SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}


def wls(x, y, w):
    """Weighted OLS with intercept."""
    W = np.sum(w)
    mx, my = np.sum(w * x) / W, np.sum(w * y) / W
    b = np.sum(w * (x - mx) * (y - my)) / np.sum(w * (x - mx) ** 2)
    a = my - b * mx
    yh = a + b * x
    res = y - yh
    sd = float(np.sqrt(np.sum(w * res ** 2) / W))
    num = np.sum(w * (x - mx) * (y - my))
    den = np.sqrt(np.sum(w * (x - mx) ** 2) * np.sum(w * (y - my) ** 2))
    return float(a), float(b), float(num / den) if den > 0 else np.nan, sd


def main() -> int:
    # ---- the two registered lines, READ and CHECKED ---------------------------------
    co = pd.read_csv(T / "PARTREG_part_regression_coefficients.csv")
    r115 = co[co.fit_id == "2.3_weighted"].iloc[0]
    line115 = (float(r115.intercept), float(r115.slope))
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    hn = pd.read_sql("SELECT number_id, pinned_value, source_object FROM "
                     "dim_headline_number WHERE number_id LIKE '%64pdk%' OR "
                     "number_id LIKE '%floor_flood%'", con)
    con.close()
    print("[lines] dim_headline_number rows matching the 64-paddock fit:")
    print(hn.to_string(index=False))
    slope64 = hn.loc[hn.number_id.str.contains("slope"), "pinned_value"]
    inter64 = hn.loc[hn.number_id.str.contains("intercept"), "pinned_value"]
    line64 = ((float(inter64.iloc[0]) if len(inter64) else SPEC_64[0]),
              (float(slope64.iloc[0]) if len(slope64) else SPEC_64[1]))
    src64 = ("dim_headline_number" if len(slope64) else
             "SPEC-STATED (no pinned row found) - flagged, not silently accepted")
    for nm, got, want in (("115-part", line115, SPEC_115), ("64-paddock", line64, SPEC_64)):
        ok = abs(got[0] - want[0]) < 1e-5 and abs(got[1] - want[1]) < 1e-5
        print(f"  {nm:<11s} intercept {got[0]:.6f} slope {got[1]:.6f}  "
              f"spec says {want[0]:.6f} / {want[1]:.6f}  -> "
              f"{'REPRODUCES' if ok else 'DIFFERS - reported, not overwritten'}")
    print(f"  64-paddock source: {src64}")

    # ---- patch-level between-unit quantities, on the SPATIAL floor ------------------
    py = pd.read_csv(OUT / "UNZONED_v3_armB_patch_year.csv")
    g = py.groupby("patch_id")
    p = g.agg(community=("community", "first"),
              community_short=("community_short", "first"),
              n_cells=("n_cells", "first"), area_ha=("area_ha", "first"),
              n_years=("water_year", "size"),
              floor_mean=("veg_p05_spatial", "mean"),
              inund_mean=("inund_pct", "mean")).reset_index()
    print(f"\n[4.6] {len(p)} supported patches, spatial floor, across-year means")

    sm = pd.read_csv(OUT / "UNZONED_v3_armA_all_patches.csv")[
        ["patch_id", "size_matched"]]
    p = p.merge(sm, on="patch_id", how="left")

    # ---- v2 4.1 · residuals against BOTH registered lines ---------------------------
    for nm, (a, b) in (("line115", line115), ("line64", line64)):
        p[f"predicted_{nm}"] = a + b * p.inund_mean
        p[f"residual_{nm}"] = p.floor_mean - p[f"predicted_{nm}"]

    rows = []
    for subset, sel in (("all supported patches", p),
                        ("size-matched (v2 2.3 rule 3)", p[p.size_matched == 1])):
        for nm in ("line115", "line64"):
            for scope, gg in [("all pooled", sel)] + [
                    (cs, sel[sel.community_short == cs])
                    for cs in ("aeolian", "riverine", "inland")]:
                if not len(gg):
                    continue
                r = gg[f"residual_{nm}"]
                rows.append({
                    "subset": subset, "line": nm, "community": scope, "n_patches": len(gg),
                    "residual_mean": r.mean(), "residual_median": r.median(),
                    "residual_sd": r.std(), "residual_min": r.min(),
                    "residual_max": r.max(),
                    "fitted": "yes" if len(gg) >= 10 else "NO - fewer than ten units",
                })
    res = pd.DataFrame(rows)
    res["metric"] = "veg_p05_spatial"
    res["line_note"] = ("registered line APPLIED, never refitted; residual = patch mean "
                        "floor minus the line's prediction at the patch's mean water")
    res["pre_registered_pooled_offset_pp"] = PRE_REG_POOLED_OFFSET
    res["size_adjustment"] = "NONE - no residual is adjusted for size anywhere (v2 2.3)"
    # Ruling EL, applied per community rather than as a blanket
    res["spatial_size_slope_pp_per_decade"] = res.community.map(SIZE_SLOPE)
    res["EL_bound"] = np.where(
        res.community == "all pooled",
        "pooled mixes three communities whose size slopes differ by a factor of 30; read "
        "the community rows, not this one",
        np.where(res.community.map(SIZE_SLOPE).abs() < 1.0,
                 "INTERPRETABLE WITHOUT SIZE MATCHING - this community's spatial-floor "
                 "size slope is indistinguishable from zero, so the all-patches result "
                 "is not size-confounded and EL's bound does not bite here",
                 "BOUNDED - this community's spatial-floor size slope is steep and the "
                 "size-matched subset cannot be fitted, so the between-unit result "
                 "cannot be size-controlled on this data"))
    res.to_csv(OUT / "UNZONED_v3_armB_between_residuals.csv", index=False,
               lineterminator="\n")

    print("\n[v2 4.1] residuals against the registered lines")
    show = res[res.subset == "all supported patches"]
    for nm in ("line115", "line64"):
        s = show[show.line == nm]
        print(f"  --- {nm} ---")
        for _, r in s.iterrows():
            print(f"    {r.community:<11s} n {r.n_patches:>3}  mean {r.residual_mean:+7.2f}  "
                  f"median {r.residual_median:+7.2f}  sd {r.residual_sd:6.2f}")
    sms = res[res.subset.str.startswith("size-matched")]
    print("  --- size-matched subset ---")
    for _, r in sms[sms.line == "line115"].iterrows():
        print(f"    {r.community:<11s} n {r.n_patches:>3}  {r.fitted}")

    # ---- RANGE-OF-SUPPORT DIAGNOSTIC · not in the spec, and it changes the reading ---
    # EL's bound was framed on the SIZE-SLOPE MAGNITUDE: Aeolian -7.64 and Riverine -4.41
    # are steep, Inland -0.23 is ~zero, so Inland's all-patches result should be
    # interpretable without size matching. That is right about the slope and incomplete
    # about its SUPPORT. Those slopes were measured on the REAL parts, and the real
    # Inland parts start at 588 cells - while HALF the unzoned Inland patches sit below
    # that. Applying Inland's ~zero slope there extrapolates it outside the range on
    # which it was estimated, which is the same refusal Arm A makes for the water axis.
    #
    # Aeolian and Riverine are the reverse: their real parts run down to 33 and 43 cells,
    # so nearly every unzoned patch of those communities IS inside the measured range.
    # The two criteria therefore rank the communities oppositely, and both are reported.
    REAL_MIN = {"aeolian": 33, "riverine": 43, "inland": 588}
    real_med = {"aeolian": 1894, "riverine": 1232, "inland": 8452}
    rs_rows = []
    for cs in ("aeolian", "riverine", "inland"):
        g = p[p.community_short == cs]
        lo = REAL_MIN[cs]
        ins, out = g[g.n_cells >= lo], g[g.n_cells < lo]
        dec = np.log10(real_med[cs]) - np.log10(g.n_cells.median())
        rs_rows.append({
            "community": cs, "real_part_min_cells": lo,
            "n_patches": len(g), "n_inside_real_size_range": len(ins),
            "n_below_real_size_range": len(out),
            "pct_below_real_range": 100 * len(out) / len(g),
            "residual_all": g.residual_line115.mean(),
            "residual_inside_range": ins.residual_line115.mean() if len(ins) else np.nan,
            "residual_below_range": out.residual_line115.mean() if len(out) else np.nan,
            "spatial_size_slope_pp_per_decade": SIZE_SLOPE[cs],
            "decades_smaller_than_real_median": dec,
            "residual_expected_from_size_alone": -SIZE_SLOPE[cs] * dec,
        })
    rs = pd.DataFrame(rs_rows)
    rs["reading"] = np.where(
        rs.residual_all <= rs.residual_expected_from_size_alone,
        "residual is AT OR BELOW what size alone predicts - consistent with a size "
        "artefact and claims nothing beyond it",
        "residual EXCEEDS what size alone predicts - not explained by size on the "
        "measured slope")
    rs["support_caveat"] = np.where(
        rs.pct_below_real_range >= 25,
        "the size slope used here was never measured over the range where much of this "
        "community's unzoned ground sits, so 'size does not explain it' is an "
        "extrapolation and the in-range figure is the defensible one",
        "the unzoned patches sit inside the range the size slope was measured on")
    rs["no_adjustment"] = "NOTHING is adjusted for size; these are expectations to read against"
    rs.to_csv(OUT / "UNZONED_v3_armB_size_range_support.csv", index=False,
              lineterminator="\n")
    print("\n[range of support] the size slope applies only where it was measured")
    for _, r in rs.iterrows():
        print(f"  {r.community:<9s} below the real-part minimum: "
              f"{r.n_below_real_size_range:>2}/{r.n_patches:<2} "
              f"({r.pct_below_real_range:>3.0f}%)   residual all {r.residual_all:+6.2f} "
              f"| in-range {r.residual_inside_range:+6.2f}   "
              f"size alone expects {r.residual_expected_from_size_alone:+6.2f}")

    # does Inland's residual trend with size WITHIN the community?
    gi = p[p.community_short == "inland"].copy()
    gi["size_quartile"] = pd.qcut(gi.n_cells, 4,
                                  labels=["Q1 smallest", "Q2", "Q3", "Q4 largest"])
    q = (gi.groupby("size_quartile", observed=True)
           .agg(n_patches=("patch_id", "size"), median_cells=("n_cells", "median"),
                mean_residual=("residual_line115", "mean")).reset_index())
    q["community"] = "inland"
    q["note"] = ("Inland's residual against the registered line, by size quartile. The "
                 "real-part size slope of -0.23 pp/decade could not detect this because "
                 "it was estimated only on parts of 588 cells and up.")
    q.to_csv(OUT / "UNZONED_v3_armB_inland_size_quartiles.csv", index=False,
             lineterminator="\n")
    print("  Inland residual by size quartile: " +
          "  ".join(f"{r.size_quartile} ({r.median_cells:,.0f} cells) "
                    f"{r.mean_residual:+.2f}" for _, r in q.iterrows()))

    # ---- v2 4.2 · describe the unzoned ground (a description, not a replacement) -----
    rng = np.random.default_rng(BOOT_SEED)
    fits = []
    for scope, gg in [("all pooled", p)] + [(cs, p[p.community_short == cs])
                                            for cs in ("aeolian", "riverine", "inland")]:
        for wname, w in (("pixel-weighted (patch cell count)", gg.n_cells.to_numpy(float)),
                         ("unweighted", np.ones(len(gg)))):
            if len(gg) < 3:
                continue
            a, b, r_, sd = wls(gg.inund_mean.to_numpy(), gg.floor_mean.to_numpy(), w)
            idx = np.arange(len(gg))
            bs = np.empty(N_BOOT)
            for i in range(N_BOOT):
                k = rng.choice(idx, size=len(idx), replace=True)
                bs[i] = wls(gg.inund_mean.to_numpy()[k], gg.floor_mean.to_numpy()[k],
                            w[k])[1]
            fits.append({
                "fit_id": f"UNZONED_v3_between_{scope.replace(' ', '_')}_"
                          f"{'w' if 'weighted' in wname and 'un' not in wname else 'unw'}",
                "description": f"unzoned patches, between-unit, {scope}, {wname}",
                "estimator": "BETWEEN-UNIT (across patches of across-year means)",
                "metric": "veg_p05_spatial", "y_variable": "floor_mean",
                "x_variable": "inund_mean", "community": scope, "weighting": wname,
                "n": len(gg), "slope": b, "intercept": a, "r": r_, "resid_sd": sd,
                "boot_slope_p2_5": float(np.quantile(bs, .025)),
                "boot_slope_p50": float(np.quantile(bs, .5)),
                "boot_slope_p97_5": float(np.quantile(bs, .975)),
                "boot_draws": N_BOOT, "boot_cluster": "patch_id",
                "boot_cluster_note": ("there is no paddock to cluster on. Patches near "
                                      "one another are not independent, so this interval "
                                      "is, if anything, TOO NARROW. Named, not fixed."),
                "status": ("A DESCRIPTION OF THE UNZONED GROUND. Not a replacement for "
                           "the registered line and never applied as one."),
            })
    f = pd.DataFrame(fits)
    f["support_level"] = "pixel"
    f["period_label"] = "1988-2022 (35 water years)"
    f["land_use_label"] = "unzoned standard-grazing country"
    f.to_csv(OUT / "UNZONED_v3_armB_between_fits.csv", index=False, lineterminator="\n")

    pooled_w = f[(f.community == "all pooled") & (f.weighting.str.startswith("pixel"))].iloc[0]
    print(f"\n[v2 4.2] unzoned between-unit fit, pixel-weighted, all pooled:")
    print(f"    slope {pooled_w.slope:+.4f}  intercept {pooled_w.intercept:.4f}  "
          f"r {pooled_w.r:+.3f}  resid sd {pooled_w.resid_sd:.2f}  n {pooled_w.n}")
    print(f"    bootstrap [{pooled_w.boot_slope_p2_5:+.4f}, {pooled_w.boot_slope_p97_5:+.4f}]"
          f"  cluster = patch_id (no paddock exists)")

    # ---- v2 4.3 · compare the two slopes -------------------------------------------
    lo, hi = REAL_INTERVAL
    overlap = not (pooled_w.boot_slope_p97_5 < lo or pooled_w.boot_slope_p2_5 > hi)
    print(f"\n[v2 4.3] real parts {line115[1]:+.4f} [{lo:+.4f}, {hi:+.4f}]  vs  "
          f"unzoned {pooled_w.slope:+.4f} "
          f"[{pooled_w.boot_slope_p2_5:+.4f}, {pooled_w.boot_slope_p97_5:+.4f}]")
    print(f"    intervals {'OVERLAP' if overlap else 'DO NOT OVERLAP'} - "
          f"{'an overlap is a result; no difference is read into it (v2 4.3)' if overlap else 'reported as observed'}")

    # ---- v2 4.4 · the corroboration test -------------------------------------------
    pooled_slope = pooled_w.slope
    comm = f[(f.community != "all pooled") & (f.weighting.str.startswith("pixel"))]
    below = comm[comm.slope < pooled_slope]
    partreg_comm = {"aeolian": -0.308532, "riverine": 0.347532, "inland": 0.285176}
    print(f"\n[v2 4.4] corroboration: do all three community slopes sit BELOW the pooled?")
    print(f"    unzoned pooled {pooled_slope:+.4f}")
    for _, r in comm.iterrows():
        print(f"      {r.community:<9s} {r.slope:+.4f}  "
              f"{'below' if r.slope < pooled_slope else 'ABOVE'}   "
              f"(PARTREG real parts: {partreg_comm[r.community]:+.4f})")
    holds = len(below) == len(comm)
    print(f"    PARTREG's counter-finding {'HOLDS' if holds else 'DOES NOT HOLD'} on this "
          f"independent set ({len(below)} of {len(comm)} below)")

    corr = comm[["community", "slope", "n"]].copy()
    corr["unzoned_pooled_slope"] = pooled_slope
    corr["below_pooled"] = corr.slope < pooled_slope
    corr["partreg_real_part_slope"] = corr.community.map(partreg_comm)
    corr["partreg_pooled_slope"] = line115[1]
    corr["partreg_below_pooled"] = corr.partreg_real_part_slope < line115[1]
    corr["finding"] = ("v2 4.4: PARTREG found all three community slopes below the "
                       "pooled slope, so the pooled line is steepened by BETWEEN-community "
                       "differences rather than within-community response. This is the "
                       "same test on an independent set with a different unit "
                       "construction. Pattern reported; nothing proposed.")
    corr.to_csv(OUT / "UNZONED_v3_armB_corroboration.csv", index=False,
                lineterminator="\n")

    # ---- the pre-registered pooled offset -------------------------------------------
    obs = res[(res.subset == "all supported patches") & (res.line == "line115")
              & (res.community == "all pooled")].residual_mean.iloc[0]
    obs_inl = res[(res.subset == "all supported patches") & (res.line == "line115")
                  & (res.community == "inland")].residual_mean.iloc[0]
    print(f"\n[pre-registered] pooled offset predicted {PRE_REG_POOLED_OFFSET:+.1f} pp, "
          f"Inland near zero")
    print(f"                 observed pooled {obs:+.2f} pp, Inland {obs_inl:+.2f} pp")
    print(f"    v2 2.3's reading: 'a pooled offset near +1.9/+2.4 with an Inland offset "
          f"near zero IS the size artefact; a pooled offset near zero, or an Inland "
          f"offset materially away from zero, is NOT.'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
