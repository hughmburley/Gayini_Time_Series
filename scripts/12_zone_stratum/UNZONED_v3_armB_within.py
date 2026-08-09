#!/usr/bin/env python
"""UNZONED v3, Arm B sections 4.1-4.5 - the within-patch replication.

Spec: docs/reference_update/Gayini_CC_spec_UNZONED_v3.md section 4.

METRIC: veg_p05_spatial. Arm B CANNOT be moved onto the temporal metric - that metric
has no time axis, so no within-unit slope exists on it. This is stated because the two
arms sit in one task and the temptation to "modernise" Arm B onto the newer metric would
silently destroy the estimand.

INPUT: Output/tables/UNZONED_gate1_patch_series.npy. NO NEW EXTRACTION.

The series is REBUILT into patch-years here and CHECKED against the stored
UNZONED_stageA1_patch_year.csv from the earlier A1 run rather than that file being
consumed on trust. Every fit below is recomputed from the .npy by an independent code
path; where the earlier run published a number, the recomputation is compared to it and
the comparison is reported. I-40: asserting a fact is not verifying it.

THE CLUSTER IS THE PATCH, and that is not the same choice as the real-part estimate,
which clusters on zone_fid. There is no paddock here to cluster on. Section 4.3 requires
this to be stated on the output rather than silently substituted, so `cluster` is a
column on every fit row.

NO P-VALUES (section 5). Slope, r, residual SD, share positive, bootstrap quantiles.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = ROOT / "Output" / "unzoned"

BOOT_SEED = 20260810
CLUSTER_NOTE = ("no paddock exists on this ground, so the cluster is the PATCH. The "
                "real-part within estimate clusters on zone_fid; these are different "
                "choices and the intervals are not interchangeable.")
REAL_WITHIN = 0.1613          # the real-part comparator, section 4.2
REAL_AC1 = 0.364              # real-part median residual lag-1, section 4.4
LAND_USE = "unzoned standard-grazing country"

SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}


def wls_through_origin(x, y, w):
    """Weighted least squares with no intercept - the demeaned within estimator."""
    den = float(np.sum(w * x * x))
    return float(np.sum(w * x * y)) / den if den > 0 else np.nan


def within_fit(df):
    """Demean both axes BY PATCH, then fit pixel-weighted. Section 4.2."""
    g = df.groupby("patch_id")
    xd = df.inund_pct - g.inund_pct.transform("mean")
    yd = df.veg_p05_spatial - g.veg_p05_spatial.transform("mean")
    w = df.n_cells.to_numpy(float)
    b = wls_through_origin(xd.to_numpy(), yd.to_numpy(), w)
    resid = yd.to_numpy() - b * xd.to_numpy()
    r = float(np.corrcoef(xd, yd)[0, 1]) if len(df) > 2 else np.nan
    sd = float(np.sqrt(np.average(resid ** 2, weights=w)))
    return b, r, sd, resid


def cluster_boot(df, draws, rng):
    """Resample PATCHES with replacement; refit. Section 4.3."""
    ids = df.patch_id.unique()
    parts = {k: v for k, v in df.groupby("patch_id")}
    out = np.empty(draws)
    for i in range(draws):
        pick = rng.choice(ids, size=len(ids), replace=True)
        # relabel so a patch drawn twice contributes two independent fixed effects
        chunks = []
        for j, p in enumerate(pick):
            c = parts[p].copy()
            c["patch_id"] = f"{p}#{j}"
            chunks.append(c)
        out[i] = within_fit(pd.concat(chunks, ignore_index=True))[0]
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    # ---- rebuild patch-years from the .npy ------------------------------------------
    ser = np.load(T / "UNZONED_gate1_patch_series.npy")
    d = pd.DataFrame(ser, columns=["patch_ord", "water_year", "n_valid", "veg_p05_spatial",
                                   "wet_pixels", "valid_pixels", "inund_pct"])
    d["patch_id"] = ["U%04d" % int(v) for v in d.patch_ord]
    d["water_year"] = d.water_year.astype(int)

    inv = pd.read_csv(T / "UNZONED_gate1_patch_inventory.csv")
    sup = inv[inv.meets_support_rule == 1]
    print(f"[input] {len(inv)} patches in Gate 1; {len(sup)} supported (spec says 93)")
    if len(sup) != 93:
        print(f"HALT: expected 93 supported patches, found {len(sup)}")
        return 1

    d = d.merge(sup[["patch_id", "community", "community_short", "n_cells", "area_ha"]],
                on="patch_id", how="inner")
    before = len(d)
    # A YEAR COUNTS ONLY IF IT HAS >= MIN_CELLS_YEAR VALID CELLS, and that is not the
    # same filter as "the value is not NaN".
    #
    # Caught by the check below on the first run. Dropping only NaN kept U0562's 1991,
    # where a spatial 5th percentile had been computed over FOUR valid cells of a
    # 64-cell patch and stored as 90.15. It is not NaN, so a null test passes it - and
    # it is not the same quantity as the p05 over 64 cells sitting in every other year
    # of that patch's series. Gate 1's own rule already says a year counts at >= 30
    # valid cells; that rule belongs here too, and the earlier A1 run applied it.
    MIN_CELLS_YEAR = 30
    d = d[(d.n_valid >= MIN_CELLS_YEAR) & d.veg_p05_spatial.notna()
          & d.inund_pct.notna()]
    print(f"[input] patch-years on supported patches {before:,}; "
          f"with >= {MIN_CELLS_YEAR} valid cells and both axes present {len(d):,} "
          f"(dropped {before - len(d)})")

    # ---- CHECK against the earlier A1 run, not consumed on trust --------------------
    prev = pd.read_csv(T / "UNZONED_stageA1_patch_year.csv")
    j = d.merge(prev[["patch_id", "water_year", "veg_p05_spatial", "inund_pct"]],
                on=["patch_id", "water_year"], suffixes=("", "_prev"), how="outer",
                indicator=True)
    unmatched = int((j._merge != "both").sum())
    dp05 = (j.veg_p05_spatial - j.veg_p05_spatial_prev).abs().max()
    dinu = (j.inund_pct - j.inund_pct_prev).abs().max()
    print(f"[check] vs UNZONED_stageA1_patch_year.csv: rows {len(prev):,} stored, "
          f"{len(d):,} rebuilt, unmatched {unmatched}; "
          f"max |d p05| {dp05:.3e}; max |d inund| {dinu:.3e}")
    if unmatched or not (dp05 < 1e-9 and dinu < 1e-9):
        print("HALT: the rebuild does not reproduce the stored patch-year table.")
        return 1
    print("  PASS - the two agree exactly")

    # ---- 4.1 per-patch slopes -------------------------------------------------------
    rows = []
    for pid, g in d.groupby("patch_id"):
        if g.inund_pct.nunique() < 2 or len(g) < 3:
            rows.append({"patch_id": pid, "community_short": g.community_short.iloc[0],
                         "n_cells": int(g.n_cells.iloc[0]), "n_years": len(g),
                         "slope": np.nan, "r": np.nan, "ac1_resid": np.nan,
                         "fitted": 0, "why_not": "water axis has no variation"})
            continue
        b, a = np.polyfit(g.inund_pct, g.veg_p05_spatial, 1)
        res = g.veg_p05_spatial - (a + b * g.inund_pct)
        ac1 = (float(np.corrcoef(res[:-1], res[1:])[0, 1])
               if len(res) > 3 and res[:-1].std() > 0 else np.nan)
        rows.append({"patch_id": pid, "community_short": g.community_short.iloc[0],
                     "n_cells": int(g.n_cells.iloc[0]), "n_years": len(g),
                     "slope": float(b),
                     "r": float(np.corrcoef(g.inund_pct, g.veg_p05_spatial)[0, 1]),
                     "ac1_resid": ac1, "fitted": 1, "why_not": ""})
    ps = pd.DataFrame(rows)
    ps["estimator"] = "within (patch fixed effects), per patch"
    ps["metric"] = "veg_p05_spatial"
    ps["cluster"] = "n/a - per-patch fit"
    ps["land_use_label"] = LAND_USE
    ps.to_csv(OUT / "UNZONED_v3_armB_per_patch_slopes.csv", index=False,
              lineterminator="\n")
    fit = ps[ps.fitted == 1]
    print(f"\n[4.1] per-patch slopes fitted on {len(fit)} of {len(ps)} supported patches "
          f"({int((ps.fitted == 0).sum())} have no water variation)")

    dist_rows = []
    for label, g in [("all", fit)] + [(cs, fit[fit.community_short == cs])
                                      for cs in ("aeolian", "riverine", "inland")]:
        if not len(g):
            continue
        q = g.slope.quantile([.25, .5, .75])
        dist_rows.append({
            "scope": label, "n_patches": len(g), "slope_min": g.slope.min(),
            "slope_q1": q[.25], "slope_median": q[.5], "slope_q3": q[.75],
            "slope_max": g.slope.max(),
            "share_positive": float((g.slope > 0).mean()),
            "n_positive": int((g.slope > 0).sum()),
            "median_ac1_resid": float(g.ac1_resid.median())})
        print(f"  {label:<9s} n {len(g):>3}  min {g.slope.min():+7.3f}  "
              f"q1 {q[.25]:+6.3f}  med {q[.5]:+6.3f}  q3 {q[.75]:+6.3f}  "
              f"max {g.slope.max():+7.3f}  share+ {(g.slope > 0).mean():5.1%}")
    dist = pd.DataFrame(dist_rows)
    dist["metric"] = "veg_p05_spatial"
    dist["estimator"] = "within (patch fixed effects), per patch"
    dist.to_csv(OUT / "UNZONED_v3_armB_slope_distribution.csv", index=False,
                lineterminator="\n")

    # ---- 4.2 / 4.3 pooled within, with clustered bootstrap --------------------------
    rng = np.random.default_rng(BOOT_SEED)
    fits = []
    for label, g in [("pooled", d)] + [(cs, d[d.community_short == cs])
                                       for cs in ("aeolian", "riverine", "inland")]:
        b, r, sd, resid = within_fit(g)
        row = {"label": f"UNZONED v3 within, {label}", "scope": label,
               "estimator": "within (patch fixed effects), demeaned, pixel-weighted",
               "metric": "veg_p05_spatial", "y_variable": "veg_p05_spatial",
               "x_variable": "inund_pct", "weighting": "weighted by n_cells",
               "cluster": "patch_id", "cluster_note": CLUSTER_NOTE,
               "n_obs": len(g), "n_units": g.patch_id.nunique(),
               "slope": b, "r": r, "resid_sd": sd}
        for draws in (2000, 10000) if label == "pooled" else (2000,):
            bs = cluster_boot(g, draws, rng)
            row[f"boot{draws}_p2_5"] = float(np.quantile(bs, .025))
            row[f"boot{draws}_p50"] = float(np.quantile(bs, .5))
            row[f"boot{draws}_p97_5"] = float(np.quantile(bs, .975))
        fits.append(row)
        print(f"\n[4.2] {label:<9s} slope {b:+.4f}  r {r:+.3f}  resid sd {sd:.2f}  "
              f"n {len(g):,} obs / {g.patch_id.nunique()} patches")
        if label == "pooled":
            print(f"[4.3]   2,000 draws  [{row['boot2000_p2_5']:+.4f}, "
                  f"{row['boot2000_p97_5']:+.4f}]")
            print(f"        10,000 draws [{row['boot10000_p2_5']:+.4f}, "
                  f"{row['boot10000_p97_5']:+.4f}]   cluster = patch_id")

    # ---- 4.4 serial correlation -----------------------------------------------------
    med_ac1 = float(fit.ac1_resid.median())
    n_eff = 35 * (1 - med_ac1) / (1 + med_ac1)
    real_neff = 35 * (1 - REAL_AC1) / (1 + REAL_AC1)
    print(f"\n[4.4] residual lag-1 autocorrelation, median over {int(fit.ac1_resid.notna().sum())} "
          f"patches: {med_ac1:+.3f}")
    print(f"      effective n ~ {n_eff:.1f} of 35 years   "
          f"(real parts: {REAL_AC1:+.3f} -> {real_neff:.1f} of 35)")
    ac = pd.DataFrame([{"set": "unzoned patches", "median_ac1_resid": med_ac1,
                        "effective_n_of_35": n_eff,
                        "n_units": int(fit.ac1_resid.notna().sum())},
                       {"set": "real parts (comparator, section 4.4)",
                        "median_ac1_resid": REAL_AC1,
                        "effective_n_of_35": real_neff, "n_units": 115}])
    ac["formula"] = "n_eff = n (1 - r1) / (1 + r1)"
    ac["metric"] = "veg_p05_spatial"
    ac.to_csv(OUT / "UNZONED_v3_armB_serial_correlation.csv", index=False,
              lineterminator="\n")

    co = pd.DataFrame(fits)
    co["land_use_label"] = LAND_USE
    co["unit_construction"] = ("8-connected component within one community, outside "
                               "every management zone")
    co["period_label"] = "1988-2022 (35 water years)"
    co["support_level"] = "pixel"
    co["boot_seed"] = BOOT_SEED
    co.to_csv(OUT / "UNZONED_v3_armB_within_fits.csv", index=False, lineterminator="\n")

    # the tidy patch-year table this arm actually fitted, for the manifest
    d.to_csv(OUT / "UNZONED_v3_armB_patch_year.csv", index=False, lineterminator="\n")

    # ---- comparison against the earlier A1 run's published fits ---------------------
    prevf = pd.read_csv(T / "UNZONED_stageA1_fits.csv")
    pw = prevf[prevf.label == "UNZONED A1 within, 2k draws"].iloc[0]
    mine = co[co.scope == "pooled"].iloc[0]
    print(f"\n[check] pooled within vs the earlier A1 run: "
          f"{mine.slope:+.6f} recomputed vs {pw.slope:+.6f} stored "
          f"(|diff| {abs(mine.slope - pw.slope):.2e})")

    # ---- 4.5 lives in UNZONED_v3_armB_predictions.py --------------------------------
    # It needs the AR(1) refit, which is R-side, so it cannot be completed here; and
    # keeping it here would mean re-running 18,000 bootstrap draws to re-word a verdict.
    print("\n[4.5] run UNZONED_v3_armB_predictions.py after the AR(1) refit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
