#!/usr/bin/env python
"""SPAT-1 Stage A - how far spatial structure reaches, and what n we actually have.

Spec: docs/spatial/Gayini_CC_spec_SPAT1.md section 4.

THE ASSERTION THIS TASK MEASURES. Every figure in the project carries a version of
"intervals are display only" or "~1M pixels is sampling uncertainty, not independent n".
None of those has ever been measured. This is I-40 at the scale of the whole project.

METHOD, NAMED. The empirical variogram is computed directly rather than through a library
(neither gstat nor scikit-gstat is installed), so the estimator is visible:

    gamma(h) = 0.5 * mean over pairs in lag bin h of (z_i - z_j)^2

Spherical and exponential models are fitted to the binned points by least squares, each
returning nugget, partial sill and range.

SUBSAMPLING IS REQUIRED AND ITS STABILITY IS SHOWN, NOT ASSUMED (4.2). A full variogram
over ~1M points is not computable - it is ~5e11 pairs. Ten independent subsamples of
10,000 cells are drawn per community and the spread of the fitted range across the ten is
reported. If the range varies by more than a factor of two across seeds the estimate is
not stable, and the spread is reported instead of a number.

EFFECTIVE SAMPLE SIZE (4.4). Following Clifford, Richardson & Hemon (1989), the effective
n deflates the nominal n by the summed correlation between observations:

    n_eff = n / (1 + (n - 1) * rho_bar)

where rho_bar is the mean of the fitted correlation function over all pairs in the set,
estimated from a subsample of the same spatial domain. The correlation function comes from
the fitted variogram: rho(h) = (partial_sill / (nugget + partial_sill)) * (1 - gamma_s(h))
in standardised form. NOTE WHAT THIS FORMULA DOES AT LARGE n: n_eff tends to 1/rho_bar, so
it SATURATES - past a point, more cells buy no more independent information. That is the
whole point of the exercise and not an artefact.

RULING EN BINDS THE RANGE. It is not extrapolated beyond the maximum lag computed, and the
maximum lag travels with every number derived from it.

NOTHING IS WIDENED, CORRECTED OR RE-RENDERED HERE (4.5). Stage A measures. What is done
with the measurement is a design-seat decision after the STOP.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.optimize import curve_fit

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "spatial"
RESID = OUT / "SPAT1_stage0_residuals.parquet"

N_SUB = 10_000
N_SEEDS = 10
MAX_LAG_M = 20_000.0
N_BINS = 80
SEED0 = 20260810
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
PROPERTY_HA = 85910.8
COMMS = ("aeolian", "riverine", "inland")


def spherical(h, nugget, psill, rng):
    h = np.asarray(h, float)
    out = np.where(h >= rng, nugget + psill,
                   nugget + psill * (1.5 * h / rng - 0.5 * (h / rng) ** 3))
    return np.where(h == 0, nugget, out)


def exponential(h, nugget, psill, rng):
    h = np.asarray(h, float)
    return nugget + psill * (1.0 - np.exp(-3.0 * h / rng))   # practical range


def empirical_variogram(x, y, z, max_lag=MAX_LAG_M, n_bins=N_BINS, angle=None,
                        tol_deg=22.5, chunk=500):
    """Binned semivariance. angle in degrees from east, None for isotropic."""
    edges = np.linspace(0.0, max_lag, n_bins + 1)
    ssq = np.zeros(n_bins)
    cnt = np.zeros(n_bins, dtype=np.int64)
    n = len(x)
    if angle is not None:
        a0 = np.deg2rad(angle)
        tol = np.deg2rad(tol_deg)
    for i0 in range(0, n, chunk):
        i1 = min(i0 + chunk, n)
        dx = x[i0:i1, None] - x[None, :]
        dy = y[i0:i1, None] - y[None, :]
        d = np.hypot(dx, dy)
        dz2 = (z[i0:i1, None] - z[None, :]) ** 2
        keep = np.zeros_like(d, dtype=bool)
        rows = np.arange(i0, i1)[:, None]
        cols = np.arange(n)[None, :]
        keep = cols > rows                      # upper triangle only, no self-pairs
        keep &= (d > 0) & (d <= max_lag)
        if angle is not None:
            th = np.arctan2(dy, dx) % np.pi     # undirected
            dth = np.abs(((th - (a0 % np.pi)) + np.pi / 2) % np.pi - np.pi / 2)
            keep &= dth <= tol
        if not keep.any():
            continue
        b = np.clip(np.digitize(d[keep], edges) - 1, 0, n_bins - 1)
        np.add.at(ssq, b, dz2[keep])
        np.add.at(cnt, b, 1)
    centres = 0.5 * (edges[:-1] + edges[1:])
    with np.errstate(invalid="ignore", divide="ignore"):
        gamma = 0.5 * ssq / cnt
    ok = cnt >= 30
    return centres[ok], gamma[ok], cnt[ok]


def fit_model(fn, h, g):
    sill0 = float(np.nanmax(g))
    p0 = [max(1e-6, float(g[0]) * 0.5), max(1e-6, sill0), MAX_LAG_M / 4]
    bounds = ([0, 1e-9, 50.0], [sill0 * 1.5 + 1e-9, sill0 * 5 + 1, MAX_LAG_M * 3])
    try:
        p, _ = curve_fit(fn, h, g, p0=p0, bounds=bounds, maxfev=20000)
        pred = fn(h, *p)
        ss = float(np.sum((g - pred) ** 2))
        return dict(nugget=p[0], psill=p[1], rng=p[2], sse=ss)
    except Exception as e:                       # a failed fit is reported, not silent
        return dict(nugget=np.nan, psill=np.nan, rng=np.nan, sse=np.nan, error=str(e))


def rho_bar(x, y, nugget, psill, rng, model, chunk=500):
    """Mean fitted correlation over all pairs of a point set."""
    tot = nugget + psill
    if tot <= 0:
        return 0.0
    n = len(x)
    s, c = 0.0, 0
    for i0 in range(0, n, chunk):
        i1 = min(i0 + chunk, n)
        d = np.hypot(x[i0:i1, None] - x[None, :], y[i0:i1, None] - y[None, :])
        rows = np.arange(i0, i1)[:, None]
        cols = np.arange(n)[None, :]
        keep = cols > rows
        dd = d[keep]
        g = spherical(dd, nugget, psill, rng) if model == "spherical" \
            else exponential(dd, nugget, psill, rng)
        s += float(np.sum(1.0 - g / tot))
        c += dd.size
    return s / c if c else 0.0


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    res = pd.read_parquet(RESID)
    print(f"[input] {len(res):,} residual cells "
          f"({len(res) * PIXEL_AREA_HA:,.1f} ha analysed of a {PROPERTY_HA:,.1f} ha "
          f"property - Ruling EQ)")

    emp_rows, mod_rows = [], []
    rng_master = np.random.default_rng(SEED0)

    for cs in COMMS:
        g = res[res.community_short == cs]
        x_all = g.x_8058.to_numpy(float)
        y_all = g.y_8058.to_numpy(float)
        z_all = g.residual.to_numpy(float)
        print(f"\n[{cs}] {len(g):,} cells; {N_SEEDS} subsamples of {N_SUB:,}")
        for s in range(N_SEEDS):
            seed = SEED0 + 1000 * s
            rs = np.random.default_rng(seed)
            idx = rs.choice(len(g), size=min(N_SUB, len(g)), replace=False)
            h, gam, cnt = empirical_variogram(x_all[idx], y_all[idx], z_all[idx])
            for hh, gg, cc in zip(h, gam, cnt):
                emp_rows.append(dict(community=cs, seed=seed, direction="isotropic",
                                     lag_m=hh, semivariance=gg, n_pairs=int(cc)))
            for name, fn in (("spherical", spherical), ("exponential", exponential)):
                f = fit_model(fn, h, gam)
                mod_rows.append(dict(community=cs, seed=seed, direction="isotropic",
                                     model=name, **f))
            if s == 0:
                sph = [m for m in mod_rows if m["community"] == cs
                       and m["seed"] == seed and m["model"] == "spherical"][0]
                print(f"    seed {seed}: spherical range {sph['rng']:,.0f} m, "
                      f"nugget {sph['nugget']:.2f}, partial sill {sph['psill']:.2f}")

        # ---- 4.3 anisotropy, on one seed per direction (pairs per bin drop by ~4x) ----
        for ang in (0, 45, 90, 135):
            seed = SEED0
            rs = np.random.default_rng(seed)
            idx = rs.choice(len(g), size=min(N_SUB, len(g)), replace=False)
            h, gam, cnt = empirical_variogram(x_all[idx], y_all[idx], z_all[idx],
                                              angle=ang)
            if len(h) < 5:
                continue
            for hh, gg, cc in zip(h, gam, cnt):
                emp_rows.append(dict(community=cs, seed=seed, direction=f"{ang}deg",
                                     lag_m=hh, semivariance=gg, n_pairs=int(cc)))
            for name, fn in (("spherical", spherical), ("exponential", exponential)):
                f = fit_model(fn, h, gam)
                mod_rows.append(dict(community=cs, seed=seed, direction=f"{ang}deg",
                                     model=name, **f))

    emp = pd.DataFrame(emp_rows)
    mod = pd.DataFrame(mod_rows)
    for df in (emp, mod):
        df["metric"] = "veg_p05_temporal_mean residual (OLS, Stage 0)"
        df["support_level"] = "pixel"
        df["period_label"] = "1988-2022 (35 water years)"
        df["max_lag_m"] = MAX_LAG_M
        df["n_subsample"] = N_SUB
    emp["estimator"] = "gamma(h) = 0.5 * mean (z_i - z_j)^2 over pairs in the lag bin"
    # RULING EN, ENFORCED IN THE TABLE. A fitted range longer than the maximum lag the
    # data were binned to is an extrapolation of the model beyond its support, not a
    # measured distance. It is flagged and must not be used as a range: what it licenses
    # is the statement that structure had NOT decayed within the measured lag.
    mod["range_resolved_within_max_lag"] = mod.rng <= MAX_LAG_M
    mod["range_note"] = np.where(
        mod.rng <= MAX_LAG_M,
        "range measured inside the binned lag; exponential range is the PRACTICAL range (3a)",
        "NOT A MEASURED RANGE (Ruling EN): the fit ran past max_lag_m, so structure had "
        "not decayed within the measured lag in this direction. Use the flag, not the "
        "number.")
    emp.to_csv(OUT / "SPAT1_variogram_empirical.csv", index=False, lineterminator="\n")
    mod.to_csv(OUT / "SPAT1_variogram_models.csv", index=False, lineterminator="\n")
    mod[mod.direction != "isotropic"].to_csv(OUT / "SPAT1_variogram_directional.csv",
                                             index=False, lineterminator="\n")
    print(f"\n  [wrote] empirical {len(emp):,} rows; models {len(mod)} rows")

    # ---- ten-seed stability, 4.2 ----------------------------------------------------
    iso = mod[(mod.direction == "isotropic")]
    stab_rows = []
    print("\n[4.2 stability] fitted range across the ten seeds")
    for cs in COMMS:
        for name in ("spherical", "exponential"):
            k = iso[(iso.community == cs) & (iso.model == name)].rng.dropna()
            if not len(k):
                continue
            ratio = float(k.max() / k.min()) if k.min() > 0 else np.inf
            stable = ratio <= 2.0
            stab_rows.append(dict(community=cs, model=name, n_seeds=len(k),
                                  range_min_m=k.min(), range_median_m=k.median(),
                                  range_max_m=k.max(), max_over_min=ratio,
                                  stable_within_factor_2=stable))
            print(f"  {cs:9s} {name:<12s} min {k.min():8,.0f}  median {k.median():8,.0f}"
                  f"  max {k.max():8,.0f} m   max/min {ratio:4.2f}  "
                  f"{'STABLE' if stable else 'NOT STABLE - report the spread'}")
    stab = pd.DataFrame(stab_rows)
    stab["rule"] = ("4.2: if the estimated range varies by more than a factor of two "
                    "across seeds the estimate is not stable and the spread is reported "
                    "rather than a number")
    stab.to_csv(OUT / "SPAT1_variogram_seed_stability.csv", index=False,
                lineterminator="\n")

    # ---- 4.3 anisotropy summary -----------------------------------------------------
    dirs = mod[(mod.direction != "isotropic") & (mod.model == "spherical")]
    print("\n[4.3 anisotropy] spherical range by direction (0 deg = east-west)")
    an_rows = []
    for cs in COMMS:
        k = dirs[dirs.community == cs]
        if not len(k):
            continue
        best = k.loc[k.rng.idxmax()]
        ratio = float(k.rng.max() / k.rng.min()) if k.rng.min() > 0 else np.inf
        unres = k[~k.range_resolved_within_max_lag].direction.tolist()
        an_rows.append(dict(community=cs,
                            **{f"range_{r.direction}_m": r.rng for r in k.itertuples()},
                            longest_direction=best.direction, max_over_min=ratio,
                            materially_anisotropic=ratio >= 1.5,
                            directions_unresolved_within_max_lag=";".join(unres),
                            en_note=("a direction listed as unresolved has NO measured "
                                     "range: structure had not decayed within "
                                     f"{MAX_LAG_M:,.0f} m along it, and the fitted number "
                                     "is an extrapolation that must not be quoted")))
        print(f"  {cs:9s} " + "  ".join(
            f"{r.direction}: " + (f"{r.rng:7,.0f} m" if r.range_resolved_within_max_lag
                                  else "UNRESOLVED >20 km")
            for r in k.itertuples())
              + f"   longest {best.direction}, max/min {ratio:4.2f}")
    pd.DataFrame(an_rows).to_csv(OUT / "SPAT1_anisotropy_summary.csv", index=False,
                                 lineterminator="\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
