#!/usr/bin/env python
"""PARTREG Stage 2 - the three periods, and across-year spread.

Spec section 5 as amended by the design seat, 6 Aug 2026 (Parts 3 and 4).

PERIODS.  Whole record 1988-2022 (35 wy) - cropping era 1988-2013 (26 wy) -
post-management 2018-2022.  2014-2017 is EXCLUDED as a transition: control passed to
NNTC in 2013 and the bank cuts are dated 2018, so the four years between belong to
neither window.  26 + 4 + 5 = 35, which is how the post-management window is FIVE
water years and not the six the ruling stated - water year 2018 is the last that
starts before the record ends in 2022.

WHAT IS AND IS NOT COMPARED.  Only the fitted RELATIONSHIPS. Never the period LEVELS.
A slope is robust to how wet the window happened to be because both axes move
together; a mean is not. That distinction is why this survives the period-boundary
objection that cut Figure 24 from the pack.

RESIDUALS are taken against EACH PERIOD'S OWN LINE, never the whole-record line, so
each period reads as "who beat their water in this era" and the three are a
comparable set.

SPREAD, never uncertainty.  SD, IQR, min, max and the p10-p90 range across years,
per part per period.  No interval is placed on it: 35 consecutive years are not 35
independent observations.  2.5-97.5 is deliberately NOT computed - on 35 values those
percentiles fall outside the observed data and are min and max under a false label.

Bootstrap as Stage 1: 2,000 draws resampling PADDOCKS with replacement, clustered on
zone_fid. No p-values.

Read-only on the database. Writes CSVs to Output/tables.
"""
from __future__ import annotations

import csv
import sqlite3
from collections import defaultdict
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
T = ROOT / "Output" / "tables"

PERIODS = [("whole_record", 1988, 2022, "1988-2022"),
           ("cropping_era", 1988, 2013, "1988-2013"),
           ("post_management", 2018, 2022, "2018-2022")]
TRANSITION = (2014, 2017)
MIN_CELLS_YEAR = 30
MIN_FRAC_YEARS = 25 / 35          # Stage 1's 25-of-35, carried across as a proportion
N_BOOT, BOOT_SEED = 2000, 20260806

# ------------------------------------------------------------------ inputs
spine = list(csv.DictReader(open(T / "PARTREG_part_year_floor_inund.csv", encoding="utf-8-sig")))
for r in spine:
    r["water_year"] = int(r["water_year"])
    r["floor"] = float(r["veg_p05_spatial"])
    r["inund"] = float(r["inund_pct"])
    r["weight"] = float(r["n_pixels_part"])
    r["zone_fid"] = int(r["zone_fid"])
print(f"[in] Stage 1 spine {len(spine):,} part-years, "
      f"{len({r['part_id'] for r in spine})} parts")

con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
conserved = {zf for (zf,) in con.execute(
    "SELECT zone_fid FROM dim_management_zone WHERE grazing_excluded = 1")}
allflood = defaultdict(list)
for zf, cm, wy, f in con.execute(
        "SELECT zone_fid, community, water_year, flood_frac_pct FROM fact_zone_community_flood_annual"):
    allflood[(zf, cm)].append(f)
con.close()

# ------------------------------------- Part 4 - the spread ratio, as a result
means = np.array([np.mean(v) for v in allflood.values()])
sds = np.array([np.std(v, ddof=0) for v in allflood.values()])
iqrs = np.array([np.quantile(v, .75) - np.quantile(v, .25) for v in allflood.values()])
BETWEEN, WITHIN_SD, WITHIN_IQR = means.std(ddof=0), np.median(sds), np.median(iqrs)
RATIO = WITHIN_SD / BETWEEN
print(f"\n[spread ratio] all {len(allflood)} parts, water axis")
print(f"  between-part spread of mean water : SD {BETWEEN:.1f} points")
print(f"  within-part across-year spread    : median SD {WITHIN_SD:.1f}, median IQR {WITHIN_IQR:.1f}")
print(f"  year-to-year movement is {RATIO:.1f}x the differences between parts")
print(f"  parts whose water IQR exceeds 92 points: {int((iqrs > 92).sum())}")


def spread(a):
    a = np.asarray(a, float)
    return dict(sd=float(a.std(ddof=0)),
                iqr=float(np.quantile(a, .75) - np.quantile(a, .25)),
                min=float(a.min()), max=float(a.max()),
                p10_p90=float(np.quantile(a, .90) - np.quantile(a, .10)))


# --------------------------------- per part per period: means and spread
by_part = defaultdict(list)
for r in spine:
    by_part[r["part_id"]].append(r)
meta = {pid: rows[0] for pid, rows in by_part.items()}

summ = {}
for code, lo, hi, plabel in PERIODS:
    n_window = hi - lo + 1
    need = int(np.ceil(MIN_FRAC_YEARS * n_window))
    rows_p = []
    for pid, rows in by_part.items():
        sel = [r for r in rows if lo <= r["water_year"] <= hi and int(r["n_valid"]) >= MIN_CELLS_YEAR]
        if not sel:
            continue
        m = meta[pid]
        rec = dict(part_id=pid, zone_fid=m["zone_fid"], zone_name=m["zone_name"],
                   community=m["community"], community_short=m["community_short"],
                   period=code, period_label=plabel, n_years=len(sel),
                   n_years_in_window=n_window, min_years_required=need,
                   meets_support=int(len(sel) >= need),
                   n_pixels_part=int(float(m["n_pixels_part"])), weight=float(m["n_pixels_part"]),
                   conserved=int(int(m["zone_fid"]) in conserved),
                   floor_mean=float(np.mean([r["floor"] for r in sel])),
                   inund_mean=float(np.mean([r["inund"] for r in sel])))
        for lab, vals in (("floor", [r["floor"] for r in sel]), ("inund", [r["inund"] for r in sel])):
            for k, v in spread(vals).items():
                rec[f"{lab}_spread_{k}"] = v
        rec.update(spread_definition="across-year spread within the period; SD/IQR/min/max/p10-p90. "
                                     "SPREAD, not uncertainty - no interval is placed on it because "
                                     "consecutive years are not independent observations",
                   support_level="pixel", aggregation_unit="part_period",
                   weighting="pixel-weighted by part cell count")
        rows_p.append(rec)
    summ[code] = rows_p
    ok = sum(r["meets_support"] for r in rows_p)
    yc = [r["n_years"] for r in rows_p]
    print(f"[{code:16s}] {plabel}  window {n_window} wy  need >={need}  "
          f"{ok}/{len(rows_p)} parts meet support  years per part {min(yc)}-{max(yc)}")

# --------------------------------- 5.1 the common part set
common = sorted(set.intersection(*[{r["part_id"] for r in summ[c] if r["meets_support"]}
                                   for c, *_ in PERIODS]))
full = sorted({r["part_id"] for r in summ["whole_record"] if r["meets_support"]})
dropped = [p for p in full if p not in set(common)]
print(f"\n[5.1 common set] {len(common)} parts meet support in ALL THREE periods "
      f"(of {len(full)} on the whole record)")
print(f"  dropped by the restriction: {len(dropped)}" + (f" -> {dropped}" if dropped else " - none"))


# --------------------------------------------------------------- the fitter
def ols(x, y, w=None):
    x, y = np.asarray(x, float), np.asarray(y, float)
    w = np.ones_like(x) if w is None else np.asarray(w, float)
    sw = w.sum()
    mx, my = (w * x).sum() / sw, (w * y).sum() / sw
    sxx = (w * (x - mx) ** 2).sum(); sxy = (w * (x - mx) * (y - my)).sum()
    syy = (w * (y - my) ** 2).sum()
    sl = sxy / sxx; it = my - sl * mx
    e = y - (it + sl * x)
    return dict(slope=float(sl), intercept=float(it),
                r=float(sxy / np.sqrt(sxx * syy)) if sxx * syy > 0 else float("nan"),
                resid_sd=float(np.sqrt((w * e ** 2).sum() / sw)), n=int(len(x)))


def boot(recs, weighted):
    rng = np.random.default_rng(BOOT_SEED)
    cl = defaultdict(list)
    for r in recs:
        cl[r["zone_fid"]].append(r)
    zfs = list(cl)
    out = []
    for _ in range(N_BOOT):
        pick = rng.choice(len(zfs), size=len(zfs), replace=True)
        rs = [r for i in pick for r in cl[zfs[i]]]
        if len({r["inund_mean"] for r in rs}) < 3:
            continue
        out.append(ols([r["inund_mean"] for r in rs], [r["floor_mean"] for r in rs],
                       [r["weight"] for r in rs] if weighted else None)["slope"])
    a = np.sort(np.array(out))
    return float(np.quantile(a, .025)), float(np.quantile(a, .5)), float(np.quantile(a, .975)), len(a)


fits, COMMON = [], set(common)


def run(fit_id, desc, code, plabel, recs, weighted, part_set):
    f = ols([r["inund_mean"] for r in recs], [r["floor_mean"] for r in recs],
            [r["weight"] for r in recs] if weighted else None)
    lo, mid, hi, nb = boot(recs, weighted)
    fits.append(dict(fit_id=fit_id, description=desc, period=code, period_label=plabel,
                     part_set=part_set,
                     weighting="pixel-weighted (part cell count)" if weighted else "unweighted",
                     y_variable="floor_mean", x_variable="inund_mean", community="all pooled",
                     support_level="pixel", aggregation_unit="part",
                     aggregation_order="OLS across parts of across-year means of within-year "
                                       "across-cell quantities",
                     comparison_rule="RELATIONSHIPS only; period LEVELS are never compared",
                     **f, boot_slope_p2_5=lo, boot_slope_p50=mid, boot_slope_p97_5=hi,
                     boot_draws=nb, boot_cluster="zone_fid (paddock)"))
    return f


print("\n=== 5.1 - the cost of the restriction, on the whole record ===")
wr = {r["part_id"]: r for r in summ["whole_record"]}
a = run("S2_whole_full115", "whole record, all supported parts", "whole_record", "1988-2022",
        [wr[p] for p in full], True, f"full {len(full)}")
b = run("S2_whole_common", "whole record, common part set", "whole_record", "1988-2022",
        [wr[p] for p in common], True, f"common {len(common)}")
for lab, f in (("full   ", a), ("common ", b)):
    print(f"  {lab} slope {f['slope']:+.4f}  intercept {f['intercept']:.3f}  r {f['r']:.4f}  n {f['n']}")

print("\n=== the three periods, common part set, pixel-weighted ===")
per = {}
for code, lo, hi, plabel in PERIODS:
    d = {r["part_id"]: r for r in summ[code]}
    recs = [d[p] for p in common]
    f = run(f"S2_{code}_common", f"{code}, common part set, pixel-weighted", code, plabel,
            recs, True, f"common {len(common)}")
    run(f"S2_{code}_common_unweighted", f"{code}, common part set, unweighted", code, plabel,
        recs, False, f"common {len(common)}")
    per[code] = (f, recs)
    fb = fits[-2]
    print(f"  {code:16s} {plabel}  slope {f['slope']:+.4f}  intercept {f['intercept']:7.3f}  "
          f"r {f['r']:+.4f}  residSD {f['resid_sd']:5.2f}  "
          f"95% [{fb['boot_slope_p2_5']:+.3f}, {fb['boot_slope_p97_5']:+.3f}]")

print("\n  slope interval overlap between periods:")
iv = {c: (fits[[f["fit_id"] for f in fits].index(f"S2_{c}_common")]["boot_slope_p2_5"],
          fits[[f["fit_id"] for f in fits].index(f"S2_{c}_common")]["boot_slope_p97_5"])
      for c, *_ in PERIODS}
for x, y in (("cropping_era", "post_management"), ("whole_record", "post_management"),
             ("whole_record", "cropping_era")):
    ov = not (iv[x][1] < iv[y][0] or iv[y][1] < iv[x][0])
    print(f"    {x:16s} vs {y:16s} {'OVERLAP' if ov else 'DISJOINT'}")

# ------------------- residuals against EACH PERIOD'S OWN line + attribute table
attr = {}
for code, lo, hi, plabel in PERIODS:
    f, recs = per[code]
    for r in recs:
        pred = f["intercept"] + f["slope"] * r["inund_mean"]
        r["predicted_floor"] = pred
        r["residual"] = r["floor_mean"] - pred
    for i, r in enumerate(sorted(recs, key=lambda z: z["residual"]), start=1):
        r["residual_rank_1_is_largest_shortfall"] = i
    for r in recs:
        a_ = attr.setdefault(r["part_id"], dict(
            part_id=r["part_id"], zone_fid=r["zone_fid"], zone_name=r["zone_name"],
            community=r["community"], community_short=r["community_short"],
            n_pixels_part=r["n_pixels_part"], conserved=r["conserved"], support_level="pixel",
            residual_basis="each period's OWN fitted line, never the whole-record line",
            comparison_rule="RELATIONSHIPS only; period LEVELS are never compared"))
        for k in ("n_years", "floor_mean", "inund_mean", "predicted_floor", "residual",
                  "residual_rank_1_is_largest_shortfall", "floor_spread_sd", "floor_spread_iqr",
                  "floor_spread_min", "floor_spread_max", "floor_spread_p10_p90",
                  "inund_spread_sd", "inund_spread_iqr", "inund_spread_min",
                  "inund_spread_max", "inund_spread_p10_p90"):
            a_[f"{code}__{k}"] = r[k]

# ---------------------------------------------------------------- outputs
def write(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader(); w.writerows(rows)
    print(f"  wrote {path.name:44s} {len(rows):>5,} rows")


print("\n=== outputs ===")
allsum = [r for code, *_ in PERIODS for r in summ[code]]
write(T / "PARTREG_S2_part_summary_by_period.csv", allsum)
write(T / "PARTREG_S2_regression_coefficients.csv", fits)
write(T / "PARTREG_S2_part_period_attributes.csv", list(attr.values()))
write(T / "PARTREG_S2_spread_ratio.csv", [dict(
    metric="water-axis spread ratio", n_parts=len(allflood),
    between_part_sd_of_mean_water=round(float(BETWEEN), 4),
    within_part_across_year_median_sd=round(float(WITHIN_SD), 4),
    within_part_across_year_median_iqr=round(float(WITHIN_IQR), 4),
    ratio_within_over_between=round(float(RATIO), 4),
    parts_with_water_iqr_over_92=int((iqrs > 92).sum()),
    support_level="pixel", aggregation_unit="part", period_label="1988-2022",
    note="SPREAD, not uncertainty. Year-to-year movement in a part's inundation is "
         f"{RATIO:.1f}x the differences in mean inundation BETWEEN parts - the argument for "
         "comparing cover at like wetness rather than between periods")])
print("\nDONE - Stage 2 fits and spread. Maps are NOT drawn (gate).")
