#!/usr/bin/env python
"""SPAT-1 Stage B - the regular-grid scale ladder.

Spec: docs/spatial/Gayini_CC_spec_SPAT1.md section 6, with the design-seat amendments of
10 August (Ruling EU).

WHY A REGULAR GRID. Paddocks, parts and tracts differ in SIZE and in HOW THEY WERE DRAWN
at the same time. A regular grid varies size while holding construction constant, which is
the only way to separate them.

RULING EU, AND IT CHANGES WHAT THIS LADDER CAN CLAIM. Stage 0 measured the straight line
departing from the GAM at the wet end. Averaging x within a block and averaging y within a
block are not the same operation when y is a nonlinear function of x (Jensen), and the
discrepancy GROWS WITH BLOCK SIZE. So a climbing OLS ladder is exactly what a curved
relationship produces even if nothing ecological changes with scale. Three things follow
and all three are done:

  1. the same GAM is fitted at every rung and BOTH ladders are reported (R side)
  2. the OLS ladder is ALSO reported restricted to the x-range where the GAM-OLS gap is
     under a stated threshold, with the excluded share named
  3. level-against-grain is unaffected and stands as specified - curvature bias moves
     slopes, not means

NESTED, NOT INDEPENDENTLY TILED. Every rung is anchored to one origin, so each coarser
block is an exact union of finer ones.

INTERVALS COME FROM A SPATIAL BLOCK BOOTSTRAP, not from the block count (6.3), and not
from the Clifford-Richardson n_eff either: that form is derived for a mean and every use
here is a slope. Super-blocks are 8 km, larger than the largest fitted range (3.2 km).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "spatial"
RESID = OUT / "SPAT1_stage0_residuals.parquet"

RUNGS_M = [250.0, 500.0, 1000.0, 2000.0, 4000.0]
PIXEL_SIDE_M = 24.970268
PIXEL_AREA_HA = PIXEL_SIDE_M ** 2 / 1e4
MIN_CELLS = 500
SUPER_BLOCK_M = 8000.0
N_BOOT = 2000
SEED = 20260810
GAP_THRESHOLD_PP = 2.0        # stated before running, per EU point 2
COMMS = ("aeolian", "riverine", "inland")


def wls_slope(x, y):
    mx = x.mean()
    den = np.sum((x - mx) ** 2)
    if den <= 0:
        return np.nan, np.nan, np.nan
    b = np.sum((x - mx) * (y - y.mean())) / den
    a = y.mean() - b * mx
    r = float(np.corrcoef(x, y)[0, 1]) if len(x) > 2 else np.nan
    return float(b), float(a), r


def block_boot_slope(x, y, sb, rng, n_boot=N_BOOT):
    """Resample 8 km super-blocks with replacement; refit exactly from per-block sums."""
    order = np.argsort(sb, kind="stable")
    x, y, s = x[order], y[order], sb[order]
    edges = np.flatnonzero(np.r_[True, s[1:] != s[:-1], True])
    sums = np.array([(z - a, x[a:z].sum(), y[a:z].sum(), (x[a:z] ** 2).sum(),
                      (x[a:z] * y[a:z]).sum())
                     for a, z in zip(edges[:-1], edges[1:])], dtype=float)
    nb = len(sums)
    if nb < 3:
        return np.nan, np.nan, nb
    idx = np.arange(nb)
    out = np.empty(n_boot)
    for i in range(n_boot):
        n_, sx, sy, sxx, sxy = sums[rng.choice(idx, size=nb, replace=True)].sum(axis=0)
        den = sxx - sx * sx / n_
        out[i] = (sxy - sx * sy / n_) / den if den > 0 else np.nan
    return float(np.nanquantile(out, .025)), float(np.nanquantile(out, .975)), nb


def main() -> int:
    res = pd.read_parquet(RESID)
    x0 = res.x_8058.min()
    y0 = res.y_8058.min()
    rng = np.random.default_rng(SEED)

    # ---- the well-fitted x-range per community, from Stage 0's GAM (EU point 2) ------
    cv = pd.read_csv(OUT / "SPAT1_stage0_gam_curves.csv")
    ols0 = pd.read_csv(OUT / "SPAT1_stage0_coefficients.csv")
    good = {}
    for cs in COMMS:
        o = ols0[ols0.scope == cs].iloc[0]
        k = cv[cv.community == cs].sort_values("flood_freq_pct")
        gap = np.abs(k.gam_fitted - (o.intercept + o.slope * k.flood_freq_pct))
        ok = k.flood_freq_pct[gap <= GAP_THRESHOLD_PP]
        good[cs] = (float(ok.min()), float(ok.max())) if len(ok) else (np.nan, np.nan)
        g = res[res.community_short == cs]
        inside = ((g.flood_freq_pct >= good[cs][0]) & (g.flood_freq_pct <= good[cs][1]))
        print(f"[EU range] {cs:9s} |GAM-OLS| <= {GAP_THRESHOLD_PP} pp over "
              f"{good[cs][0]:5.1f}-{good[cs][1]:5.1f}% wet; "
              f"{100 * inside.mean():5.1f}% of cells inside, "
              f"{100 * (~inside).mean():4.1f}% excluded")

    lad, lev, cnt, agg_out = [], [], [], []

    # ---- rung 0 · the pixel census, fitted separately and not subject to the floor ---
    for cs in COMMS:
        g = res[res.community_short == cs]
        x, y = g.flood_freq_pct.to_numpy(float), g.veg_p05.to_numpy(float)
        sb = (np.floor(g.x_8058.to_numpy() / SUPER_BLOCK_M).astype(np.int64) * 100000
              + np.floor(g.y_8058.to_numpy() / SUPER_BLOCK_M).astype(np.int64))
        b, a, r = wls_slope(x, y)
        lo, hi, nsb = block_boot_slope(x, y, sb, rng)
        lad.append(dict(rung="rung 0 (pixel census)", block_m=PIXEL_SIDE_M, community=cs,
                        n_units=len(g), slope=b, intercept=a, r=r, ci_lo=lo, ci_hi=hi,
                        n_super_blocks=nsb, subset="all"))
        lev.append(dict(rung="rung 0 (pixel census)", block_m=PIXEL_SIDE_M, community=cs,
                        n_units=len(g), mean_level=float(y.mean()),
                        mean_x=float(x.mean()), area_ha=len(g) * PIXEL_AREA_HA))

    # ---- rungs 1..5 · nested square blocks ------------------------------------------
    for bm in RUNGS_M:
        bx = np.floor((res.x_8058.to_numpy() - x0) / bm).astype(np.int64)
        by = np.floor((res.y_8058.to_numpy() - y0) / bm).astype(np.int64)
        res["_blk"] = bx * 1000000 + by
        gb = (res.groupby(["_blk", "community_short"])
                 .agg(n_cells=("veg_p05", "size"), y=("veg_p05", "mean"),
                      x=("flood_freq_pct", "mean"), cx=("x_8058", "mean"),
                      cy=("y_8058", "mean")).reset_index())
        max_possible = int(np.floor(bm / PIXEL_SIDE_M) ** 2)
        keep = gb[gb.n_cells >= MIN_CELLS]
        reachable = max_possible >= MIN_CELLS
        cnt.append(dict(rung=f"{bm:.0f} m", block_m=bm,
                        max_cells_a_block_can_hold=max_possible,
                        floor_physically_reachable=reachable,
                        n_units_before=len(gb), n_units_after=len(keep),
                        area_ha_before=float(gb.n_cells.sum() * PIXEL_AREA_HA),
                        area_ha_after=float(keep.n_cells.sum() * PIXEL_AREA_HA),
                        fitted=reachable and len(keep) >= 10))
        print(f"[rung {bm:>6.0f} m] a block holds at most {max_possible:>6,} cells; "
              f"units {len(gb):>5} -> {len(keep):>5} at the {MIN_CELLS}-cell floor; "
              f"{'FITTED' if reachable and len(keep) >= 10 else 'NOT FITTED - the floor is unreachable at this rung'}")
        if not (reachable and len(keep) >= 10):
            continue
        keep = keep.copy()
        keep["rung"] = f"{bm:.0f} m"
        keep["block_m"] = bm
        agg_out.append(keep)
        sb = (np.floor(keep.cx.to_numpy() / SUPER_BLOCK_M).astype(np.int64) * 100000
              + np.floor(keep.cy.to_numpy() / SUPER_BLOCK_M).astype(np.int64))
        for cs in COMMS:
            m = keep.community_short == cs
            if m.sum() < 10:
                continue
            xs, ys = keep.x[m].to_numpy(), keep.y[m].to_numpy()
            b, a, r = wls_slope(xs, ys)
            lo, hi, nsb = block_boot_slope(xs, ys, sb[m.to_numpy()], rng)
            lad.append(dict(rung=f"{bm:.0f} m", block_m=bm, community=cs,
                            n_units=int(m.sum()), slope=b, intercept=a, r=r,
                            ci_lo=lo, ci_hi=hi, n_super_blocks=nsb, subset="all"))
            lev.append(dict(rung=f"{bm:.0f} m", block_m=bm, community=cs,
                            n_units=int(m.sum()), mean_level=float(ys.mean()),
                            mean_x=float(xs.mean()),
                            area_ha=float(keep.n_cells[m].sum() * PIXEL_AREA_HA)))
            # EU point 2 - the same fit restricted to the well-fitted x-range
            lo_x, hi_x = good[cs]
            mm = m & keep.x.between(lo_x, hi_x)
            if mm.sum() >= 10:
                b2, a2, r2 = wls_slope(keep.x[mm].to_numpy(), keep.y[mm].to_numpy())
                lad.append(dict(rung=f"{bm:.0f} m", block_m=bm, community=cs,
                                n_units=int(mm.sum()), slope=b2, intercept=a2, r=r2,
                                ci_lo=np.nan, ci_hi=np.nan, n_super_blocks=np.nan,
                                subset=f"restricted to |GAM-OLS| <= {GAP_THRESHOLD_PP} pp"))

    ladder = pd.DataFrame(lad)
    levels = pd.DataFrame(lev)
    counts = pd.DataFrame(cnt)
    for d in (ladder, levels, counts):
        d["metric"] = "veg_p05_temporal_mean"
        d["support_level"] = "pixel, aggregated to block x vegetation community"
        d["period_label"] = "1988-2022 (35 water years)"
        d["min_cells_filter"] = MIN_CELLS
    ladder["interval_basis"] = (f"spatial block bootstrap, {SUPER_BLOCK_M/1000:.0f} km "
                                f"super-blocks resampled with replacement, {N_BOOT} draws"
                                f" - NOT the block count, and NOT the "
                                f"Clifford-Richardson n_eff, which is derived for a mean")
    ladder["eu_note"] = ("Ruling EU: an OLS ladder alone cannot separate a scale effect "
                         "from aggregation-induced curvature bias. Read this beside the "
                         "GAM ladder in SPAT1_ladder_gam.csv and beside the restricted "
                         "rows here.")
    counts["floor_rule"] = ("500 cells at every rung. A rung whose blocks cannot "
                            "physically reach the floor is reported with its counts and "
                            "NOT fitted (6.1).")
    ladder.to_csv(OUT / "SPAT1_ladder_slopes.csv", index=False, lineterminator="\n")
    levels.to_csv(OUT / "SPAT1_ladder_levels.csv", index=False, lineterminator="\n")
    counts.to_csv(OUT / "SPAT1_ladder_counts.csv", index=False, lineterminator="\n")
    pd.concat(agg_out, ignore_index=True).to_csv(OUT / "SPAT1_ladder_block_units.csv",
                                                 index=False, lineterminator="\n")
    gr = pd.DataFrame([dict(community=c, x_lo=good[c][0], x_hi=good[c][1],
                            gap_threshold_pp=GAP_THRESHOLD_PP) for c in COMMS])
    gr.to_csv(OUT / "SPAT1_eu_wellfitted_range.csv", index=False, lineterminator="\n")

    print("\n[6.2 slope against grain] OLS, all units")
    a = ladder[ladder.subset == "all"]
    for cs in COMMS:
        k = a[a.community == cs].sort_values("block_m")
        print(f"  {cs:9s} " + "  ".join(
            f"{r.rung.split(' ')[0]}:{r.slope:+.3f}" for r in k.itertuples()))
    print("\n[6.2 level against grain] mean cover per rung")
    for cs in COMMS:
        k = levels[levels.community == cs].sort_values("block_m")
        print(f"  {cs:9s} " + "  ".join(
            f"{r.rung.split(' ')[0]}:{r.mean_level:5.1f}" for r in k.itertuples()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
