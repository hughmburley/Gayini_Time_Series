#!/usr/bin/env python
"""SPAT-1 Stage A section 4.4 - the effective sample size, and section 4.4.1 - pinning it.

Spec: docs/spatial/Gayini_CC_spec_SPAT1.md sections 4.4 and 4.4.1.

METHOD, NAMED AND CITED. Clifford, P., Richardson, S. & Hemon, D. (1989), "Assessing the
significance of the correlation between two spatial processes", Biometrics 45(1):123-134.
Their construction deflates the nominal n by the summed correlation between observations.
Implemented in the standard variance-inflation form for a mean:

    n_eff = n / (1 + (n - 1) * rho_bar)

rho_bar is the mean fitted correlation over all pairs in the unit set, taken from Stage A's
fitted variogram as rho(h) = 1 - gamma(h) / (nugget + partial sill), and estimated from a
subsample of the same spatial domain where the set is too large to enumerate.

READ WHAT THIS DOES AT LARGE n. n_eff tends to 1 / rho_bar as n grows, so it SATURATES:
past a point more cells buy no additional independent information. That is the finding the
task exists to produce, not an artefact of the formula.

WHAT IT ASSUMES, STATED. A single isotropic correlation function per community, stationary
over the analysed area. Stage A's directional variograms show the country is NOT isotropic,
so this is an approximation whose direction of error is knowable: an isotropic average of a
directional field understates correlation along the long axis and overstates it across, and
the net effect on n_eff is not signed a priori. The anisotropy is reported beside every
number rather than averaged away (4.3).

RULING EN. A range fitted beyond the maximum lag is not a measured range and is not used
here. Only ranges resolved within the binned lag enter the correlation function.

SECTION 4.4.1. Every value is pinned in dim_headline_number with a number_id, and
SPAT1_effective_n.csv carries that number_id on each row so the file and the registry
cannot drift apart. This is Ruling ER applied to the number most likely to be quoted in
prose from here on: three rulings in this project - EP, EQ and EI - record the registry
holding the right value while prose drifted from it.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "spatial"
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
PROPERTY_HA = 85910.8
MAX_SUB = 6000          # pairs enumerated exactly below this; sampled above
SEED = 20260810
COMMS = ("aeolian", "riverine", "inland")


def spherical(h, nugget, psill, rng):
    h = np.asarray(h, float)
    return np.where(h >= rng, nugget + psill,
                    nugget + psill * (1.5 * h / rng - 0.5 * (h / rng) ** 3))


def mean_rho(x, y, nugget, psill, rng, chunk=400):
    tot = nugget + psill
    if tot <= 0 or len(x) < 2:
        return 0.0
    n = len(x)
    s, c = 0.0, 0
    for i0 in range(0, n, chunk):
        i1 = min(i0 + chunk, n)
        d = np.hypot(x[i0:i1, None] - x[None, :], y[i0:i1, None] - y[None, :])
        rows = np.arange(i0, i1)[:, None]
        cols = np.arange(n)[None, :]
        dd = d[cols > rows]
        if dd.size == 0:
            continue
        s += float(np.sum(1.0 - spherical(dd, nugget, psill, rng) / tot))
        c += dd.size
    return s / c if c else 0.0


def n_eff_of(n, rho):
    rho = max(rho, 0.0)
    return n / (1.0 + (n - 1) * rho) if n > 1 else float(n)


def fit_quality(emp, mod):
    """Does the fitted model actually DESCRIBE the empirical variogram?

    The ten-seed stability check answers a different question. A range can be perfectly
    stable across subsamples and still be a poor summary of a shape that is not
    spherical: stability is about SAMPLING, adequacy is about FORM. Both are needed and
    only one was specified, so this is computed and reported beside it.

    Also detects TURNOVER. A variogram that rises to a peak and falls is not a
    second-order stationary field reaching a sill; it carries large-scale trend or
    periodic structure. A fitted range on such a shape is a summary of something the data
    does not do, and every number derived from it inherits that.
    """
    rows = []
    seed = int(emp.seed.min())
    for cs in emp.community.unique():
        e = emp[(emp.community == cs) & (emp.seed == seed)
                & (emp.direction == "isotropic")].sort_values("lag_m")
        if len(e) < 5:
            continue
        h, g = e.lag_m.to_numpy(), e.semivariance.to_numpy()
        peak = int(np.argmax(g))
        fall = (g[peak] - g[-1]) / g[peak] if g[peak] > 0 else 0.0
        for name in ("spherical", "exponential"):
            m = mod[(mod.community == cs) & (mod.seed == seed)
                    & (mod.direction == "isotropic") & (mod.model == name)]
            if not len(m):
                continue
            m = m.iloc[0]
            if name == "spherical":
                pred = spherical(h, m.nugget, m.psill, m.rng)
            else:
                pred = m.nugget + m.psill * (1 - np.exp(-3 * h / m.rng))
            sill = m.nugget + m.psill
            rmse = float(np.sqrt(np.mean((g - pred) ** 2)))
            r2 = float(1 - np.sum((g - pred) ** 2) / np.sum((g - g.mean()) ** 2))
            rows.append(dict(
                community=cs, model=name, seed=seed, rmse=rmse,
                rmse_pct_of_sill=100 * rmse / sill if sill else np.nan,
                pseudo_r2=r2, empirical_peak_lag_m=float(h[peak]),
                empirical_peak_value=float(g[peak]),
                fall_from_peak_pct=100 * fall,
                turns_over=bool(fall > 0.08),
                adequacy=("model describes the shape" if r2 >= 0.7 and fall <= 0.08
                          else "MODEL IS A POOR SUMMARY OF THE SHAPE - the empirical "
                               "variogram turns over rather than reaching a sill, so the "
                               "field is not second-order stationary and the fitted "
                               "range is a summary of something the data does not do"),
                note=("the ten-seed stability check measures SAMPLING stability and says "
                      "nothing about whether the model form fits; both are reported")))
    return pd.DataFrame(rows)


def main() -> int:
    mod = pd.read_csv(OUT / "SPAT1_variogram_models.csv")
    emp = pd.read_csv(OUT / "SPAT1_variogram_empirical.csv")
    fq = fit_quality(emp, mod)
    fq.to_csv(OUT / "SPAT1_variogram_fit_quality.csv", index=False, lineterminator="\n")
    print("[fit quality] does the model describe the empirical shape?")
    for _, r in fq[fq.model == "spherical"].iterrows():
        print(f"  {r.community:9s} pseudo-R2 {r.pseudo_r2:+.3f}  RMSE {r.rmse_pct_of_sill:5.1f}% of sill"
              f"  peak {r.empirical_peak_lag_m/1000:5.1f} km  falls {r.fall_from_peak_pct:5.1f}%"
              f"  {'TURNS OVER' if r.turns_over else 'plateaus'}")
    fq_sph = fq[fq.model == "spherical"].set_index("community")
    iso = mod[(mod.direction == "isotropic") & (mod.model == "spherical")]
    if "range_resolved_within_max_lag" in iso.columns:
        iso = iso[iso.range_resolved_within_max_lag.astype(str).str.lower() == "true"]
    par = (iso.groupby("community")[["nugget", "psill", "rng"]].median()
              .rename(columns={"rng": "range_m"}))
    spread = (mod[(mod.direction == "isotropic") & (mod.model == "spherical")]
              .groupby("community").rng.agg(["min", "max", "count"]))
    max_lag = float(mod.max_lag_m.iloc[0])
    print("[params] median across ten seeds, spherical, isotropic")
    print(par.to_string())

    rs = np.random.default_rng(SEED)
    res = pd.read_parquet(OUT / "SPAT1_stage0_residuals.parquet",
                          columns=["community_short", "x_8058", "y_8058"])

    # ---- the four unit sets ---------------------------------------------------------
    parts = gpd.read_file(ROOT / "Output/maps/MAP1_paddock_community_areas_epsg8058.gpkg")
    parts = parts[parts.inclusion_class == "plotted"]
    tracts = gpd.read_file(ROOT / "Output/unzoned/UNZONED_patches_epsg8058.gpkg")
    tracts = tracts[tracts.meets_500_cells == 1]
    padd = gpd.read_file(ROOT / "Output/spatial_8058/management_zones_epsg8058.gpkg")
    for nm, gdf, want in (("parts", parts, 100), ("tracts", tracts, 39),
                          ("paddocks", padd, 64)):
        if len(gdf) != want:
            print(f"  NOTE: {nm} has {len(gdf)} rows, expected {want} - reported as found")

    def centroids(gdf, comm=None):
        g = gdf if comm is None else gdf[gdf.community_short == comm]
        c = g.geometry.centroid
        return c.x.to_numpy(), c.y.to_numpy()

    rows = []
    for cs in COMMS:
        if cs not in par.index:
            print(f"  {cs}: no resolved isotropic range - skipped, and reported")
            continue
        p = par.loc[cs]
        nug, psl, rng_m = float(p.nugget), float(p.psill), float(p.range_m)

        g = res[res.community_short == cs]
        idx = rs.choice(len(g), size=min(MAX_SUB, len(g)), replace=False)
        rho = mean_rho(g.x_8058.to_numpy()[idx], g.y_8058.to_numpy()[idx],
                       nug, psl, rng_m)
        sets = [("pixel census", len(g), rho)]
        for nm, gdf in (("paddock x community areas", parts),
                        ("unzoned tracts", tracts)):
            xs, ys = centroids(gdf, cs)
            if len(xs) >= 2:
                sets.append((nm, len(xs), mean_rho(xs, ys, nug, psl, rng_m)))
        for nm, n, rb in sets:
            rows.append(dict(unit_set=nm, community=cs, n=n, rho_bar=rb,
                             n_eff=n_eff_of(n, rb), range_m=rng_m,
                             nugget=nug, partial_sill=psl))
            print(f"  {cs:9s} {nm:<26s} n {n:>8,}  rho_bar {rb:.4f}  "
                  f"n_eff {n_eff_of(n, rb):8.1f}  ratio {n_eff_of(n, rb)/n:.5f}")

    # analysed-area total and the paddock set, on the area-weighted mean parameters
    w = np.array([len(res[res.community_short == c]) for c in par.index], float)
    nug_a = float(np.average(par.nugget, weights=w))
    psl_a = float(np.average(par.psill, weights=w))
    rng_a = float(np.average(par.range_m, weights=w))
    idx = rs.choice(len(res), size=min(MAX_SUB, len(res)), replace=False)
    rho_all = mean_rho(res.x_8058.to_numpy()[idx], res.y_8058.to_numpy()[idx],
                       nug_a, psl_a, rng_a)
    rows.append(dict(unit_set="pixel census", community="analysed area (all)",
                     n=len(res), rho_bar=rho_all, n_eff=n_eff_of(len(res), rho_all),
                     range_m=rng_a, nugget=nug_a, partial_sill=psl_a))
    for nm, gdf in (("paddock x community areas", parts), ("unzoned tracts", tracts),
                    ("paddocks", padd)):
        xs, ys = centroids(gdf)
        rb = mean_rho(xs, ys, nug_a, psl_a, rng_a)
        rows.append(dict(unit_set=nm, community="analysed area (all)", n=len(xs),
                         rho_bar=rb, n_eff=n_eff_of(len(xs), rb), range_m=rng_a,
                         nugget=nug_a, partial_sill=psl_a))
        print(f"  {'ALL':9s} {nm:<26s} n {len(xs):>8,}  rho_bar {rb:.4f}  "
              f"n_eff {n_eff_of(len(xs), rb):8.1f}")

    en = pd.DataFrame(rows)
    en["ratio_n_eff_over_n"] = en.n_eff / en.n
    en["method"] = ("Clifford-Richardson (1989) variance-inflation effective sample "
                    "size: n_eff = n / (1 + (n-1) * rho_bar)")
    en["model_form"] = "spherical, isotropic, median of ten seeds"
    en["max_lag_m"] = max_lag
    en["support_level"] = "pixel"
    en["metric"] = "veg_p05_temporal_mean residual (OLS, Stage 0)"
    en["period_label"] = "1988-2022 (35 water years)"
    en["analysed_ha"] = len(res) * PIXEL_AREA_HA
    en["property_ha"] = PROPERTY_HA
    en["assumption_note"] = (
        "assumes one isotropic correlation function per community, stationary over the "
        "analysed area. Stage A's directional variograms show the country is NOT "
        "isotropic; the anisotropy is reported beside these numbers and not averaged away")
    en["model_adequacy"] = [
        (f"pseudo-R2 {fq_sph.loc[c, 'pseudo_r2']:+.2f}, empirical variogram "
         f"{'TURNS OVER' if fq_sph.loc[c, 'turns_over'] else 'plateaus'} "
         f"(falls {fq_sph.loc[c, 'fall_from_peak_pct']:.0f}% from a peak at "
         f"{fq_sph.loc[c, 'empirical_peak_lag_m']/1000:.1f} km)")
        if c in fq_sph.index else "see SPAT1_variogram_fit_quality.csv"
        for c in en.community]
    en["en_note"] = ("Ruling EN: only ranges resolved within the maximum binned lag enter "
                     "the correlation function; a range fitted past it is not a measured "
                     "range")

    # ---- 4.4.1 · pin every row -------------------------------------------------------
    def nid(u, c):
        u2 = {"pixel census": "pixel", "paddock x community areas": "part",
              "unzoned tracts": "tract", "paddocks": "paddock"}[u]
        c2 = "all" if c.startswith("analysed") else c
        return f"spat1_n_eff_{u2}_{c2}"

    en["number_id"] = [nid(u, c) for u, c in zip(en.unit_set, en.community)]
    en.to_csv(OUT / "SPAT1_effective_n.csv", index=False, lineterminator="\n")
    print(f"\n  [wrote] SPAT1_effective_n.csv  {len(en)} rows, each carrying its number_id")

    con = sqlite3.connect(DB)
    try:
        before = con.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
        for _, r in en.iterrows():
            sp = spread.loc[r.community] if r.community in spread.index else None
            seedtxt = (f"ten-seed spherical range spread {sp['min']:,.0f}-{sp['max']:,.0f} m "
                       f"over {int(sp['count'])} seeds" if sp is not None
                       else "ten-seed spread reported per community in "
                            "SPAT1_variogram_seed_stability.csv")
            con.execute(
                "INSERT OR REPLACE INTO dim_headline_number "
                "(number_id, label, source_object, grain, aggregation_order, "
                " series_variant, scope_filter, period_label, denominator, "
                " pixel_constant, pinned_value, spread_min, spread_max, support_level, "
                " caveat, decided_by, decision_note) "
                "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (r.number_id,
                 f"Effective independent sample size, {r.unit_set}, {r.community}",
                 "Output/spatial/SPAT1_effective_n.csv",
                 r.unit_set,
                 "Clifford-Richardson variance inflation over the fitted spherical "
                 "correlation function; rho_bar is the mean fitted correlation over all "
                 "pairs in the set",
                 "spherical, isotropic, median of ten seeds",
                 "treed_context_flag = 0 AND regime_band <> 'context'",
                 r.period_label,
                 f"nominal n = {int(r.n)}",
                 PIXEL_AREA_HA,
                 round(float(r.n_eff), 2),
                 None, None,
                 "pixel",
                 (f"METHOD: Clifford, Richardson & Hemon (1989), Biometrics 45:123-134, "
                  f"variance-inflation form n_eff = n / (1 + (n-1) rho_bar). "
                  f"FITTED RANGE {r.range_m:,.0f} m (nugget {r.nugget:.2f}, partial sill "
                  f"{r.partial_sill:.2f}). MODEL FORM spherical, isotropic. {seedtxt}. "
                  f"MAXIMUM LAG {max_lag:,.0f} m - Ruling EN, the range is not "
                  f"extrapolated beyond it and neither is anything derived from it. "
                  f"ASSUMES one isotropic correlation function per community; the "
                  f"directional variograms show the country is NOT isotropic and that is "
                  f"reported beside this number rather than averaged away. "
                  f"MODEL ADEQUACY: {r.model_adequacy}. Where the empirical variogram "
                  f"turns over, the field is not second-order stationary, the fitted "
                  f"range summarises a shape the data does not have, and this number "
                  f"inherits that - the ten-seed stability check measures sampling "
                  f"stability only and does not speak to model form. NOT a "
                  f"correction applied to any existing interval - Stage A measures only."),
                 "SPAT-1 section 4.4.1 (docs/spatial/Gayini_CC_spec_SPAT1.md); design-seat "
                 "Rulings ER and EN, 10 Aug 2026; computed and verified by CC 2026-08-10",
                 "Pinned rather than written into a findings note because this number "
                 "will be quoted in prose more often than any the project has produced - "
                 "every interval statement from here rests on it - and EP, EQ and EI each "
                 "record the registry holding the right value while prose drifted from "
                 "it. Any interval computed from it cites the number_id at the point of "
                 "quotation (CZ)."))
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
        chk = pd.read_sql("SELECT number_id, pinned_value FROM dim_headline_number "
                          "WHERE number_id LIKE 'spat1_n_eff_%'", con)
    finally:
        con.close()
    print(f"  dim_headline_number {before} -> {after} rows; "
          f"{len(chk)} spat1_n_eff_* rows read back")
    m = en.merge(chk, on="number_id")
    bad = (m.pinned_value - m.n_eff.round(2)).abs() > 1e-9
    print(f"  read-back matches the CSV on all rows: {not bad.any()}")
    return 0 if not bad.any() else 1


if __name__ == "__main__":
    sys.exit(main())
