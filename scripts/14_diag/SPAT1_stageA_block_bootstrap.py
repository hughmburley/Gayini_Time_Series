#!/usr/bin/env python
"""SPAT-1 - the effective n FOR A SLOPE, by a second and independent route.

Design-seat amendment, 10 August 2026, before Stage B's intervals use anything.

THE PROBLEM WITH THE FIRST ROUTE, STATED PLAINLY. Clifford-Richardson's variance-inflation
form gives the effective n for the variance of a MEAN or a correlation. Every use this
project will make of the number is to widen a REGRESSION SLOPE's interval, and those are
not the same quantity: a slope's inflation depends on the spatial structure of x as well as
of the residuals, and x here is a flood-frequency surface, which is about as spatially
structured as anything on the property. The analytic form was derived for a different
estimand and cannot be assumed to transfer.

THE SECOND ROUTE. A spatial block bootstrap with blocks LARGER THAN THE FITTED RANGE:
resample whole blocks with replacement, refit, and read the interval width directly. This
measures what is actually needed without depending on an analytic form derived for
something else.

    n_eff_slope = n * (SE_naive / SE_block) ** 2

where SE_naive is the ordinary OLS standard error that treats every cell as independent.
The ratio IS the variance inflation, so this is directly comparable to Stage A's n_eff.

EXACT, NOT SAMPLED. The slope is a closed form in five per-block sums, so a bootstrap draw
costs a pooling of block sums rather than a refit over ~700k rows. Every draw uses all the
cells of every block it draws.

PRE-REGISTERED HANDLING OF THE COMPARISON, recorded before the numbers are seen:
  agree      -> the pinned Stage A numbers stand and their caveats gain a line
  diverge    -> the block-bootstrap number is what Stage B uses, and the pinned rows gain
                a SECOND COLUMN rather than being replaced
"agree" is taken as within a factor of two, the same tolerance section 4.2 used for seed
stability, stated here before running.

The design seat's own approximation from the nugget and partial sill gave Inland n_eff
around 78 against Stage A's 170 - offered as a prediction to check, not a claim. It is
reported against below.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "spatial"
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"

BLOCK_M = 5000.0          # > the largest fitted range (3,217 m)
BLOCK_ALT_M = 8000.0      # sensitivity: comfortably > 2x the largest range
N_BOOT = 2000
SEED = 20260810
COMMS = ("aeolian", "riverine", "inland")
AGREE_FACTOR = 2.0
DESIGN_SEAT_PREDICTION = {"inland": 78.0}


def block_sums(x, y, bid):
    """Per-block n, Sx, Sy, Sxx, Sxy - everything a slope needs."""
    order = np.argsort(bid, kind="stable")
    x, y, b = x[order], y[order], bid[order]
    edges = np.flatnonzero(np.r_[True, b[1:] != b[:-1], True])
    out = []
    for a, z in zip(edges[:-1], edges[1:]):
        xi, yi = x[a:z], y[a:z]
        out.append((z - a, xi.sum(), yi.sum(), (xi * xi).sum(), (xi * yi).sum()))
    return np.array(out, dtype=float)     # (n_blocks, 5)


def slope_from(sums):
    n, sx, sy, sxx, sxy = sums.sum(axis=0)
    den = sxx - sx * sx / n
    return (sxy - sx * sy / n) / den if den > 0 else np.nan


def naive_se(x, y):
    n = len(x)
    mx = x.mean()
    sxx = np.sum((x - mx) ** 2)
    b = np.sum((x - mx) * (y - y.mean())) / sxx
    a = y.mean() - b * mx
    rss = np.sum((y - (a + b * x)) ** 2)
    return float(np.sqrt(rss / (n - 2) / sxx)), float(b), n


def run(res, block_m, rng):
    rows = []
    for cs in COMMS:
        g = res[res.community_short == cs]
        x = g.flood_freq_pct.to_numpy(float)
        y = g.veg_p05.to_numpy(float)
        bx = np.floor(g.x_8058.to_numpy() / block_m).astype(np.int64)
        by = np.floor(g.y_8058.to_numpy() / block_m).astype(np.int64)
        bid = bx * 100000 + by
        sums = block_sums(x, y, bid)
        nb = len(sums)
        se_n, b_hat, n = naive_se(x, y)
        idx = np.arange(nb)
        draws = np.empty(N_BOOT)
        for i in range(N_BOOT):
            pick = rng.choice(idx, size=nb, replace=True)
            draws[i] = slope_from(sums[pick])
        se_b = float(np.nanstd(draws, ddof=1))
        infl = (se_b / se_n) ** 2 if se_n > 0 else np.nan
        n_eff = n / infl if infl and np.isfinite(infl) else np.nan
        rows.append(dict(
            community=cs, block_m=block_m, n_blocks=nb, n_cells=n, slope=b_hat,
            se_naive=se_n, se_block_bootstrap=se_b,
            variance_inflation=infl, n_eff_slope=n_eff,
            ratio_n_eff_over_n=n_eff / n,
            boot_p2_5=float(np.nanquantile(draws, .025)),
            boot_p50=float(np.nanquantile(draws, .5)),
            boot_p97_5=float(np.nanquantile(draws, .975)),
            n_boot=N_BOOT))
        print(f"  {cs:9s} blocks {nb:>4} of {block_m/1000:.0f} km   slope {b_hat:+.4f}  "
              f"SE naive {se_n:.5f} -> block {se_b:.5f}   inflation {infl:8.1f}x   "
              f"n_eff(slope) {n_eff:8.1f}")
    return pd.DataFrame(rows)


def main() -> int:
    res = pd.read_parquet(OUT / "SPAT1_stage0_residuals.parquet")
    rng = np.random.default_rng(SEED)
    print(f"[block bootstrap] {N_BOOT:,} draws, blocks resampled with replacement, "
          f"slope refitted exactly from per-block sums")
    print(f"  primary blocks {BLOCK_M/1000:.0f} km (> the largest fitted range, 3.2 km)")
    main_df = run(res, BLOCK_M, rng)
    print(f"  sensitivity blocks {BLOCK_ALT_M/1000:.0f} km")
    alt_df = run(res, BLOCK_ALT_M, rng)
    bb = pd.concat([main_df, alt_df], ignore_index=True)

    # ---- against Stage A's analytic n_eff --------------------------------------------
    en = pd.read_csv(OUT / "SPAT1_effective_n.csv")
    px = en[(en.unit_set == "pixel census") & (en.community.isin(COMMS))][
        ["community", "n", "n_eff", "number_id"]].rename(
        columns={"n_eff": "n_eff_mean_clifford_richardson"})
    cmp = (bb[bb.block_m == BLOCK_M]
           .merge(px, on="community", how="left"))
    cmp["ratio_slope_over_mean"] = (cmp.n_eff_slope
                                    / cmp.n_eff_mean_clifford_richardson)
    cmp["agree_within_factor_2"] = ((cmp.ratio_slope_over_mean.between(1 / AGREE_FACTOR,
                                                                       AGREE_FACTOR)))
    print("\n[comparison] the two routes, pixel grain")
    for _, r in cmp.iterrows():
        pred = DESIGN_SEAT_PREDICTION.get(r.community)
        ptxt = f"   design-seat prediction {pred:.0f}" if pred else ""
        print(f"  {r.community:9s} Clifford-Richardson (mean) {r.n_eff_mean_clifford_richardson:8.1f}"
              f"   block bootstrap (slope) {r.n_eff_slope:8.1f}"
              f"   ratio {r.ratio_slope_over_mean:6.2f}"
              f"   {'AGREE' if r.agree_within_factor_2 else 'DIVERGE'}{ptxt}")

    verdict = "AGREE" if bool(cmp.agree_within_factor_2.all()) else "DIVERGE"
    print(f"\n  PRE-REGISTERED HANDLING -> {verdict}: "
          + ("the pinned Stage A numbers stand and their caveats gain a line"
             if verdict == "AGREE" else
             "the block-bootstrap number is what Stage B uses, and the pinned rows gain a "
             "SECOND COLUMN rather than being replaced"))

    bb["estimand"] = "SLOPE of veg_p05_temporal_mean on flood_freq_pct, pixel grain"
    bb["method"] = ("spatial block bootstrap, blocks resampled with replacement, slope "
                    "refitted exactly from per-block sums; n_eff_slope = n * "
                    "(SE_naive / SE_block)^2")
    bb["why_second_route"] = (
        "Clifford-Richardson's variance-inflation form is derived for the variance of a "
        "MEAN or a correlation. Every use here widens a SLOPE interval, whose inflation "
        "depends on the spatial structure of x as well as of the residuals, and x is a "
        "flood-frequency surface. The analytic form cannot be assumed to transfer.")
    bb["support_level"] = "pixel"
    bb["period_label"] = "1988-2022 (35 water years)"
    bb.to_csv(OUT / "SPAT1_block_bootstrap_slope.csv", index=False, lineterminator="\n")
    cmp.to_csv(OUT / "SPAT1_n_eff_two_routes.csv", index=False, lineterminator="\n")
    print(f"  [wrote] SPAT1_block_bootstrap_slope.csv, SPAT1_n_eff_two_routes.csv")

    # ---- the pinned rows gain a line (or a second column) ---------------------------
    con = sqlite3.connect(DB)
    try:
        for _, r in cmp.iterrows():
            extra = (
                f" SLOPE CHECK (design-seat amendment, 10 Aug): a spatial block bootstrap "
                f"on {BLOCK_M/1000:.0f} km blocks, larger than the fitted range, gives an "
                f"effective n FOR THE SLOPE of {r.n_eff_slope:,.0f} against this row's "
                f"{r.n_eff_mean_clifford_richardson:,.0f} for the mean, a ratio of "
                f"{r.ratio_slope_over_mean:.2f} "
                f"({'agreeing' if r.agree_within_factor_2 else 'DIVERGING'} within the "
                f"pre-registered factor of two). The two answer different questions: "
                f"Clifford-Richardson is derived for a mean, the bootstrap measures the "
                f"slope directly. USE THE SLOPE FIGURE WHEN WIDENING A SLOPE INTERVAL.")
            con.execute("UPDATE dim_headline_number SET caveat = caveat || ? "
                        "WHERE number_id = ?", (extra, r.number_id))
        con.commit()
        n_upd = con.execute("SELECT COUNT(*) FROM dim_headline_number WHERE "
                            "number_id LIKE 'spat1_n_eff_pixel_%' AND caveat LIKE "
                            "'%SLOPE CHECK%'").fetchone()[0]
    finally:
        con.close()
    print(f"  {n_upd} pinned pixel rows had the slope check appended to their caveat "
          f"(Ruling F: caveat is amendable in place and logged)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
