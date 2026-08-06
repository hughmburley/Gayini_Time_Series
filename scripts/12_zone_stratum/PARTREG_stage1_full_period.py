#!/usr/bin/env python
"""PARTREG Stage 1 - Figure 25 recomputed at paddock x community PART grain.

Spec: docs/reference_update/Gayini_CC_spec_PARTREG.md, sections 2 and 4.

WHAT THIS IS. Stage 1 is a SUMMARISING job, not an extraction one. Both axes
already exist at part grain, per part per year:
    fact_zone_community_veg_annual    118 x 35 x 2 variants  ->  veg_p05_spatial
    fact_zone_community_flood_annual  118 x 35               ->  flood_frac_pct
and the inner join is 4,130 rows with zero missing part-years. The part grain is a
PARALLEL output of the same T2 Gate B extraction that produced the paddock grain,
not a step below it - so this switches branches rather than moving down a chain.

The ONE extraction. Section 2.4 needs the part-grain median and 2.5 needs p10, p20,
p30 and p50. Those columns exist at NEITHER grain (zone grain has median/p10/p25;
part grain has p05 and mean only), so one pass over the 35-band cover stack at the
795,602 T2 join points is unavoidable. It costs ~90 s and reuses T2_in_scope_points.csv.

A CHECK THAT CAN FAIL: the extraction recomputes p05 as well as the new percentiles,
and asserts it against the stored veg_p05_spatial for all 4,130 part-years. If the
extraction has drifted from the registered series the script stops rather than
publishing a second, silently different, p05.

NO P-VALUES (spec section 4). 115 parts nested in 64 paddocks are not independent and
35 consecutive years are not 35 independent observations. Intervals come from a
bootstrap that resamples PADDOCKS with replacement - clustered on zone_fid, never on
part - refit 2,000 times.

Read-only on the database. Writes CSVs to Output/tables. Registration is a separate
script (PARTREG_stage1_register.py), as the spec requires.
"""
from __future__ import annotations

import csv
import sqlite3
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import rasterio

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
DATA = ROOT / "Output" / "pack" / "DATA"
OUT = ROOT / "Output" / "tables"
OUT.mkdir(parents=True, exist_ok=True)

VARIANT = "mean_of_seasons"
PERIOD = "1988-2022"                 # water-year starts; the registry's label for the 64-pdk line
MIN_CELLS_YEAR = 30                  # spec section 1: a year counts if the part has >= 30 valid cells
MIN_YEARS = 25                       # ... and a part is supported at >= 25 such years
PCTS = [5, 10, 20, 30, 50]
N_BOOT = 2000
BOOT_SEED = 20260806                 # fixed: the interval must be reproducible

COMM_SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
              "Riverine Chenopod Shrublands": "riverine",
              "Inland Floodplain Shrublands / Swamps": "inland"}

# ---------------------------------------------------------------- 0 - the DB side
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
Q = lambda s, *a: con.execute(s, a).fetchall()

zname = dict(Q("SELECT zone_fid, zone_name FROM dim_management_zone"))

# part size on the correct nine-stratum scope - this is the weight
part_cells = {(zf, cm): n for zf, cm, n in Q(
    """SELECT zone_fid, community, SUM(n_pixels) FROM census_by_zone_stratum
       WHERE treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid IS NOT NULL
       GROUP BY zone_fid, community""")}

spine_rows = Q(
    """SELECT v.zone_fid, v.community, v.water_year, v.n_pixels_valid, v.veg_p05_spatial,
              f.wet_pixels, f.valid_pixels, f.flood_frac_pct
       FROM fact_zone_community_veg_annual v
       JOIN fact_zone_community_flood_annual f
         ON f.zone_fid = v.zone_fid AND f.community = v.community AND f.water_year = v.water_year
       WHERE v.series_variant = ?
       ORDER BY v.zone_fid, v.community, v.water_year""", VARIANT)
con.close()

print(f"[join] {len(spine_rows):,} part-years, "
      f"{len({(r[0], r[1]) for r in spine_rows})} parts, "
      f"{len({r[2] for r in spine_rows})} years - zero raster reads so far")

# support test, exactly as the spec states it
years_ok = defaultdict(int)
for zf, cm, wy, nval, p05, wet, val, ffp in spine_rows:
    if nval is not None and nval >= MIN_CELLS_YEAR:
        years_ok[(zf, cm)] += 1
all_parts = sorted({(r[0], r[1]) for r in spine_rows})
supported = sorted(p for p in all_parts if years_ok[p] >= MIN_YEARS)
dropped = [p for p in all_parts if p not in set(supported)]
print(f"[support] {len(supported)} of {len(all_parts)} parts carry >= {MIN_YEARS} years "
      f"of >= {MIN_CELLS_YEAR} valid cells")
for zf, cm in dropped:
    print(f"          dropped: {zname[zf]:<12s} {cm:<40s} "
          f"{years_ok[(zf, cm)]:>2d} yrs, {part_cells.get((zf, cm), 0)} cells")

sizes = sorted(part_cells[p] for p in supported)
print(f"[weights] supported part size {sizes[0]:,} to {sizes[-1]:,} cells "
      f"- a factor of {sizes[-1] / sizes[0]:.0f}, and {sum(1 for s in sizes if s < 636)} parts "
      f"sit below 636")

# ------------------------------------------- 1 - the one extraction: extra percentiles
t0 = time.time()
pts = list(csv.DictReader(open(DATA / "tables/T2_in_scope_points.csv", encoding="utf-8-sig")))
xs = np.array([float(p["x_8058"]) for p in pts])
ys = np.array([float(p["y_8058"]) for p in pts])
key = np.array([f"{p['zone_fid']}|{p['community']}" for p in pts])
order = np.argsort(key, kind="stable")
key, xs, ys = key[order], xs[order], ys[order]
edges = np.flatnonzero(np.r_[True, key[1:] != key[:-1], True])
groups = [(key[a], a, b) for a, b in zip(edges[:-1], edges[1:])]

pct_by_partyear: dict[tuple, dict[int, float]] = {}
with rasterio.open(DATA / "rasters/total_veg_annual_mean_8058.tif") as s:
    wys = [int(n[:4]) for n in s.descriptions]
    cc, rr = (~s.transform) * (xs, ys)
    cc, rr = cc.astype(int), rr.astype(int)
    for j, wy in enumerate(wys, start=1):
        band = s.read(j)
        v = band[rr, cc].astype(float)
        for k, a, b in groups:
            g = v[a:b]
            g = g[~np.isnan(g)]
            if g.size == 0:
                continue
            zf, cm = k.split("|")
            qs = np.quantile(np.sort(g), [p / 100 for p in PCTS])
            pct_by_partyear[(int(zf), cm, wy)] = dict(zip(PCTS, qs.tolist()), n=int(g.size))
print(f"[extract] 35 bands x {len(pts):,} points -> {len(pct_by_partyear):,} part-years "
      f"in {time.time() - t0:.0f} s")

# the check that can fail: recomputed p05 must equal the registered series
diffs = []
for zf, cm, wy, nval, p05, wet, val, ffp in spine_rows:
    got = pct_by_partyear.get((zf, cm, wy))
    if got is None or p05 is None:
        continue
    diffs.append(abs(got[5] - p05))
    if got["n"] != nval:
        raise SystemExit(f"FAIL cell count {zname[zf]}/{cm}/{wy}: {got['n']} vs stored {nval}")
diffs = np.array(diffs)
if diffs.max() > 1e-6:
    raise SystemExit(f"FAIL: recomputed p05 differs from fact_zone_community_veg_annual "
                     f"by up to {diffs.max():.6g} - refusing to publish a second p05")
print(f"[check] recomputed p05 == stored veg_p05_spatial on all {len(diffs):,} part-years "
      f"(max |diff| {diffs.max():.2e})")

# --------------------------------------------------- 2.1 - the part x year spine
SUP = set(supported)
spine = []
for zf, cm, wy, nval, p05, wet, val, ffp in spine_rows:
    if (zf, cm) not in SUP:
        continue
    if nval is None or nval < MIN_CELLS_YEAR:
        continue                      # a year below cell support is dropped, not imputed
    pc = pct_by_partyear[(zf, cm, wy)]
    spine.append(dict(
        part_id=f"{zf:02d}_{COMM_SHORT[cm]}", zone_fid=zf, zone_name=zname[zf],
        community=cm, community_short=COMM_SHORT[cm], water_year=wy,
        n_pixels_part=part_cells[(zf, cm)], n_valid=nval,
        **{f"veg_p{p:02d}_spatial": pc[p] for p in PCTS},
        wet_pixels=wet, valid_pixels=val, inund_pct=ffp,
        support_level="pixel", aggregation_unit="part_year",
        aggregation_order="percentile across the part's cells within one water year",
        period_label=PERIOD, series_variant=VARIANT))
print(f"[2.1] spine {len(spine):,} rows over {len(SUP)} parts "
      f"(complete grid would be {len(SUP) * 35:,}; "
      f"{len(SUP) * 35 - len(spine)} part-years dropped below {MIN_CELLS_YEAR} cells)")


def iqr(a):
    return float(np.quantile(a, 0.75) - np.quantile(a, 0.25))


# --------------------------------------------------------- 2.2 - the part summary
by_part = defaultdict(list)
for r in spine:
    by_part[(r["zone_fid"], r["community"])].append(r)

summary = []
for (zf, cm), rows in sorted(by_part.items()):
    rec = dict(part_id=rows[0]["part_id"], zone_fid=zf, zone_name=zname[zf], community=cm,
               community_short=COMM_SHORT[cm], period_label=PERIOD, n_years=len(rows),
               n_pixels_part=part_cells[(zf, cm)], weight=part_cells[(zf, cm)],
               weighting="part cell count (census, nine-stratum non-treed scope)",
               support_level="pixel", aggregation_unit="part",
               aggregation_order="mean/median/SD/IQR across water years of a within-year "
                                 "across-cell quantity", series_variant=VARIANT)
    for p in PCTS:
        a = np.array([r[f"veg_p{p:02d}_spatial"] for r in rows], float)
        rec[f"floor_p{p:02d}_mean"] = float(a.mean())
        if p == 5:
            rec.update(floor_median=float(np.median(a)), floor_sd=float(a.std(ddof=0)),
                       floor_iqr=iqr(a))
    a = np.array([r["inund_pct"] for r in rows], float)
    rec.update(inund_mean=float(a.mean()), inund_median=float(np.median(a)),
               inund_sd=float(a.std(ddof=0)), inund_iqr=iqr(a))
    rec["floor_mean"] = rec["floor_p05_mean"]
    summary.append(rec)
print(f"[2.2] summary {len(summary)} parts")


# ------------------------------------------------------------------- the fitter
def ols(x, y, w=None):
    x, y = np.asarray(x, float), np.asarray(y, float)
    w = np.ones_like(x) if w is None else np.asarray(w, float)
    sw = w.sum()
    mx, my = (w * x).sum() / sw, (w * y).sum() / sw
    sxx = (w * (x - mx) ** 2).sum()
    sxy = (w * (x - mx) * (y - my)).sum()
    syy = (w * (y - my) ** 2).sum()
    slope = sxy / sxx
    inter = my - slope * mx
    r = sxy / np.sqrt(sxx * syy) if sxx * syy > 0 else float("nan")
    e = y - (inter + slope * x)
    return dict(slope=float(slope), intercept=float(inter), r=float(r),
                resid_sd=float(np.sqrt((w * e ** 2).sum() / sw)), n=int(len(x)))


def boot_slope(recs, xk, yk, weighted, n=N_BOOT):
    """Resample PADDOCKS with replacement - clustered on zone_fid, never on part."""
    rng = np.random.default_rng(BOOT_SEED)
    clusters = defaultdict(list)
    for rec in recs:
        clusters[rec["zone_fid"]].append(rec)
    zfs = list(clusters)
    out = []
    for _ in range(n):
        pick = rng.choice(len(zfs), size=len(zfs), replace=True)
        rs = [rec for i in pick for rec in clusters[zfs[i]]]
        if len({rec[xk] for rs_ in [rs] for rec in rs_}) < 3:
            continue
        x = [rec[xk] for rec in rs]
        y = [rec[yk] for rec in rs]
        w = [rec["weight"] for rec in rs] if weighted else None
        try:
            out.append(ols(x, y, w)["slope"])
        except Exception:
            continue
    a = np.sort(np.array(out))
    return (float(np.quantile(a, 0.025)), float(np.quantile(a, 0.5)),
            float(np.quantile(a, 0.975)), len(a))


fits = []


def record(tag, note, recs, xk, yk, weighted, boot=True):
    w = [r["weight"] for r in recs] if weighted else None
    f = ols([r[xk] for r in recs], [r[yk] for r in recs], w)
    lo, mid, hi, nb = boot_slope(recs, xk, yk, weighted) if boot else (None, None, None, 0)
    fits.append(dict(fit_id=tag, description=note, period_label=PERIOD,
                     weighting="pixel-weighted (part cell count)" if weighted else "unweighted",
                     y_variable=yk, x_variable=xk, community="all pooled",
                     support_level="pixel", aggregation_unit="part",
                     aggregation_order="OLS across parts of across-year means of "
                                       "within-year across-cell quantities",
                     series_variant=VARIANT, **f,
                     boot_slope_p2_5=lo, boot_slope_p50=mid, boot_slope_p97_5=hi,
                     boot_draws=nb, boot_cluster="zone_fid (paddock)"))
    return f


# ------------------------------------------------------- 2.3 - the headline fit
print("\n=== 2.3 - floor_mean ~ inund_mean ===")
hw = record("2.3_weighted", "headline: pixel-weighted OLS at part grain",
            summary, "inund_mean", "floor_mean", True)
hu = record("2.3_unweighted", "robustness: unweighted OLS at part grain",
            summary, "inund_mean", "floor_mean", False)
for tag, f in (("weighted  ", hw), ("unweighted", hu)):
    print(f"  {tag}  slope {f['slope']:+.4f}  intercept {f['intercept']:.4f}  "
          f"r {f['r']:.4f}  resid SD {f['resid_sd']:.4f}  n {f['n']}")
print(f"  registered 64-paddock line: slope +0.547838  intercept 52.652934  r 0.71  "
      f"resid SD 6.6208  n 64")

# ------------------------------------------------------------- 2.4 - median fit
print("\n=== 2.4 - floor_median ~ inund_median ===")
mw = record("2.4_median_weighted", "central-tendency check: medians, pixel-weighted",
            summary, "inund_median", "floor_median", True)
print(f"  weighted    slope {mw['slope']:+.4f}  intercept {mw['intercept']:.4f}  "
      f"r {mw['r']:.4f}  resid SD {mw['resid_sd']:.4f}")

# -------------------------------------------------------- 2.5 - percentile sweep
print("\n=== 2.5 - the percentile sweep ===")
for p in PCTS:
    f = record(f"2.5_p{p:02d}", f"sweep: cover floor at p{p:02d}, pixel-weighted",
               summary, "inund_mean", f"floor_p{p:02d}_mean", True)
    print(f"  p{p:02d}  slope {f['slope']:+.4f}  r {f['r']:.4f}  "
          f"resid SD {f['resid_sd']:.4f}")

# --------------------------------------------------- 2.6 - community, and test it
print("\n=== 2.6 - pooled against three community lines ===")
comm_fits = {}
for cs in ("aeolian", "riverine", "inland"):
    recs = [r for r in summary if r["community_short"] == cs]
    w = [r["weight"] for r in recs]
    f = ols([r["inund_mean"] for r in recs], [r["floor_mean"] for r in recs], w)
    lo, mid, hi, nb = boot_slope(recs, "inund_mean", "floor_mean", True)
    comm_fits[cs] = (f, lo, hi)
    fits.append(dict(fit_id=f"2.6_{cs}", description=f"community line: {cs}, pixel-weighted",
                     period_label=PERIOD, weighting="pixel-weighted (part cell count)",
                     y_variable="floor_mean", x_variable="inund_mean", community=cs,
                     support_level="pixel", aggregation_unit="part",
                     aggregation_order="OLS across parts within one community",
                     series_variant=VARIANT, **f, boot_slope_p2_5=lo, boot_slope_p50=mid,
                     boot_slope_p97_5=hi, boot_draws=nb, boot_cluster="zone_fid (paddock)"))
    print(f"  {cs:<9s} slope {f['slope']:+.4f}  r {f['r']:+.4f}  n {f['n']:>3d}  "
          f"95% [{lo:+.4f}, {hi:+.4f}]")
print(f"  {'pooled':<9s} slope {hw['slope']:+.4f}  r {hw['r']:+.4f}  n {hw['n']:>3d}  "
      f"95% [{fits[0]['boot_slope_p2_5']:+.4f}, {fits[0]['boot_slope_p97_5']:+.4f}]")

pairs = [("aeolian", "riverine"), ("aeolian", "inland"), ("riverine", "inland")]
print("  interval overlap between community slopes:")
for a, b in pairs:
    (_, la, ha), (_, lb, hb) = comm_fits[a], comm_fits[b]
    ov = not (ha < lb or hb < la)
    print(f"    {a:<9s} vs {b:<9s} {'OVERLAP' if ov else 'DISJOINT'}")

# ------------------------------------------------------------------- 6 - outputs
def write_csv(path, rows):
    cols = list(rows[0])
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(f"  wrote {path.name:38s} {len(rows):>5,} rows")


print("\n=== outputs ===")
write_csv(OUT / "PARTREG_part_year_floor_inund.csv", spine)
write_csv(OUT / "PARTREG_part_summary_by_period.csv", summary)
write_csv(OUT / "PARTREG_part_regression_coefficients.csv", fits)
print("\nDONE - Stage 1 computation. Registration is PARTREG_stage1_register.py.")
