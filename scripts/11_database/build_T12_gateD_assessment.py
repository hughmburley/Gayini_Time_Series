#!/usr/bin/env python3
"""T12 · Gate D — cultivation assessment, spec v4 §2.4 + §2.5 as pre-registered.

Additive. Builds fact_dea_cultivation_assessment (one row per zone × classified era)
and the reading view v_dea_zone_landuse_summary. rule_version = 'T12_prereg_v2_20260728'
(v4 is numeric-only; the RULES are the v2 pre-registration, unchanged). No threshold
is moved, no rule reinterpreted. Nothing written to dim_management_zone.

§2.2 floor = mean(dea_ctv_pct over 2023,2024,2025) per zone.
§2.3 eras: 1988-1992, 1993-2002, 2003-2012, 2013-2018, 2019-2022 (2023-2025 = floor,
  not classified). excess(era) = mean(dea_ctv_pct over era) - floor.
§2.4 class (pre-downgrade):
  indeterminate if  <4 valid yrs  OR  <60% of era yrs present  OR  zone px <3000
                    OR  era overlaps §2.6 suspect (1988-2012) for >50% of its years.
  else likely   if excess>=25 AND max_consec(ctv>=30)>=4 AND era mean ctv>=40
  else possible if excess>=10 AND max_consec(ctv>=30)>=2
  else no_evidence.
§2.5 falsification: per zone corr(ctv, flood) & corr(ctv, veg_mean) across matching
  fact_zone_veg_annual years. If |corr_flood|>=0.5, downgrade one tier
  (likely->possible->no_evidence). Recorded, never silent. Primary alignment
  water_year = dea_calendar_year (align A); align B (wy = cy-1) reported per §6.

Usage: python scripts/11_database/build_T12_gateD_assessment.py [check|execute]
"""
from __future__ import annotations
import sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN = "T12_gateD"; RULE = "T12_prereg_v2_20260728"
ERAS = {"1988-1992": range(1988, 1993), "1993-2002": range(1993, 2003),
        "2003-2012": range(2003, 2013), "2013-2018": range(2013, 2019),
        "2019-2022": range(2019, 2023)}
SUSPECT = set(range(1988, 2013))   # §2.6 union: 1988-2012


def pearson(xs, ys):
    n = len(xs)
    if n < 3:
        return None
    mx = sum(xs) / n; my = sum(ys) / n
    sxy = sum((a - mx) * (b - my) for a, b in zip(xs, ys))
    sxx = sum((a - mx) ** 2 for a in xs); syy = sum((b - my) ** 2 for b in ys)
    if sxx == 0 or syy == 0:
        return None
    return sxy / (sxx ** 0.5 * syy ** 0.5)


def max_consec(years_sorted, ctv, thr=30.0):
    best = cur = 0
    d = dict(zip(years_sorted, ctv))
    for y in years_sorted:
        cur = cur + 1 if d[y] >= thr else 0
        best = max(best, cur)
    return best


def load(con):
    zc = {}
    for zf, y, p in con.execute("SELECT zone_fid, dea_calendar_year, dea_ctv_pct FROM fact_dea_landcover_zone_year"):
        zc.setdefault(zf, {})[y] = p
    zpx = {zf: n for zf, n in con.execute(
        "SELECT zone_fid, CAST(AVG(n_pixels_valid) AS INT) FROM fact_dea_landcover_zone_year GROUP BY zone_fid")}
    names = {zf: n for zf, n in con.execute("SELECT zone_fid, zone_name FROM dim_management_zone")}
    fz = {}
    for zf, wy, fl, vg in con.execute(
        "SELECT zone_fid, water_year, flood_frac_pct, veg_mean FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'"):
        fz.setdefault(zf, {})[wy] = (fl, vg)
    return zc, zpx, names, fz


def corr_zone(ctv_by_year, fz_zone, offset):
    xs, yf, yv = [], [], []
    for y, c in ctv_by_year.items():
        rec = fz_zone.get(y - offset)
        if rec is not None:
            xs.append(c); yf.append(rec[0]); yv.append(rec[1])
    return pearson(xs, yf), pearson(xs, yv), len(xs)


def build(con):
    zc, zpx, names, fz = load(con)
    rows = []
    for zf in sorted(zc):
        ctv = zc[zf]
        floor = sum(ctv.get(y, 0) for y in (2023, 2024, 2025)) / 3.0
        cfA, cvA, nA = corr_zone(ctv, fz.get(zf, {}), 0)   # wy = cy
        cfB, cvB, nB = corr_zone(ctv, fz.get(zf, {}), 1)   # wy = cy-1
        for era, yrs in ERAS.items():
            yrs = list(yrs); present = [y for y in yrs if y in ctv]
            vals = [ctv[y] for y in present]
            n_years = len(present); n_suspect = sum(1 for y in present if y in SUSPECT)
            mean_ctv = sum(vals) / n_years if n_years else None
            excess = (mean_ctv - floor) if mean_ctv is not None else None
            mc = max_consec(present, vals)
            indet = (n_years < 4 or n_years / len(yrs) < 0.60 or zpx[zf] < 3000
                     or (n_suspect / len(yrs)) > 0.50)
            if indet:
                cls = "dea_indeterminate"
            elif excess >= 25 and mc >= 4 and mean_ctv >= 40:
                cls = "dea_likely_cultivated"
            elif excess >= 10 and mc >= 2:
                cls = "dea_possible_cultivated"
            else:
                cls = "dea_no_evidence"
            # §2.5 downgrade on |corr_flood (align A)| >= 0.5
            order = ["dea_likely_cultivated", "dea_possible_cultivated", "dea_no_evidence"]
            downgraded = 0; final = cls
            if cls in order and cfA is not None and abs(cfA) >= 0.5:
                i = order.index(cls)
                if i < len(order) - 1:
                    final = order[i + 1]; downgraded = 1
            rows.append(dict(zone_fid=zf, era_label=era, mean_ctv_pct=mean_ctv, dea_ctv_floor=floor,
                             dea_ctv_excess=excess, max_consecutive_ge30=mc, n_years_in_era=n_years,
                             n_suspect_years=n_suspect, corr_ctv_flood=cfA, corr_ctv_vegmean=cvA,
                             downgraded_flag=downgraded, dea_cultivation_class=cls,
                             dea_cultivation_class_final=final, rule_version=RULE,
                             support_level="zone_era_dea_l3", run_id=RUN,
                             _name=names[zf], _cfB=cfB, _zpx=zpx[zf]))
    return rows


COLS = ["zone_fid", "era_label", "mean_ctv_pct", "dea_ctv_floor", "dea_ctv_excess",
        "max_consecutive_ge30", "n_years_in_era", "n_suspect_years", "corr_ctv_flood",
        "corr_ctv_vegmean", "downgraded_flag", "dea_cultivation_class",
        "dea_cultivation_class_final", "rule_version", "support_level", "run_id"]


def report(rows):
    from collections import Counter
    print("=== dea_cultivation_class_final counts by era ===")
    for era in ERAS:
        c = Counter(r["dea_cultivation_class_final"] for r in rows if r["era_label"] == era)
        print(f"  {era}: " + ", ".join(f"{k}={v}" for k, v in sorted(c.items())))
    print("\n=== zones reaching likely/possible (final or pre-downgrade), named ===")
    hit = [r for r in rows if "likely" in r["dea_cultivation_class"] or "possible" in r["dea_cultivation_class"]]
    hit.sort(key=lambda r: (-r["dea_ctv_excess"]))
    print(f"  {'zone':16} {'era':10} {'excess':>7} {'maxc>=30':>8} {'meanCTV':>7} {'corrF_A':>7} {'corrV_A':>7} {'dgrade':>6} {'pre->final'}")
    for r in hit:
        print(f"  {r['_name']:16} {r['era_label']:10} {r['dea_ctv_excess']:7.1f} {r['max_consecutive_ge30']:8d} "
              f"{r['mean_ctv_pct']:7.1f} {(r['corr_ctv_flood'] or 0):7.2f} {(r['corr_ctv_vegmean'] or 0):7.2f} "
              f"{r['downgraded_flag']:6d} {r['dea_cultivation_class'].replace('dea_','')}->{r['dea_cultivation_class_final'].replace('dea_','')}")
    print(f"\n  total likely (pre): {sum(r['dea_cultivation_class']=='dea_likely_cultivated' for r in rows)} | "
          f"likely (final): {sum(r['dea_cultivation_class_final']=='dea_likely_cultivated' for r in rows)} | "
          f"downgraded: {sum(r['downgraded_flag'] for r in rows)}")
    zpx_small = sorted({(r['_name'], r['_zpx']) for r in rows if r['_zpx'] < 3000})
    print(f"  zones with <3000 DEA px (indeterminate by §2.4): {zpx_small if zpx_small else 'none'}")
    # §6 alignment disagreement on the downgrade
    dis = [r['_name'] for r in rows if r['dea_cultivation_class'] in
           ('dea_likely_cultivated','dea_possible_cultivated')
           and (abs(r['corr_ctv_flood'] or 0) >= 0.5) != (abs(r['_cfB'] or 0) >= 0.5)]
    print(f"  §6 downgrade differs A vs B for zones: {sorted(set(dis)) if dis else 'none'}")


def main(mode):
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True) if mode == "check" else sqlite3.connect(DB.as_posix())
    rows = build(con)
    report(rows)
    if mode == "check":
        print("\n[check] NO DB WRITE."); con.close(); return
    con.execute("""CREATE TABLE IF NOT EXISTS fact_dea_cultivation_assessment (
        zone_fid INTEGER, era_label TEXT, mean_ctv_pct REAL, dea_ctv_floor REAL, dea_ctv_excess REAL,
        max_consecutive_ge30 INTEGER, n_years_in_era INTEGER, n_suspect_years INTEGER,
        corr_ctv_flood REAL, corr_ctv_vegmean REAL, downgraded_flag INTEGER,
        dea_cultivation_class TEXT, dea_cultivation_class_final TEXT, rule_version TEXT,
        support_level TEXT, run_id TEXT, PRIMARY KEY (zone_fid, era_label))""")
    ph = ", ".join(["?"] * len(COLS))
    con.executemany(f"INSERT OR REPLACE INTO fact_dea_cultivation_assessment ({', '.join(COLS)}) VALUES ({ph})",
                    [tuple(r[c] for c in COLS) for r in rows])
    con.execute("DROP VIEW IF EXISTS v_dea_zone_landuse_summary")
    con.execute("""CREATE VIEW v_dea_zone_landuse_summary AS
        SELECT a.zone_fid, z.zone_name, z.zone_group, z.grazing_treatment, a.era_label,
               a.mean_ctv_pct, a.dea_ctv_floor, a.dea_ctv_excess, a.max_consecutive_ge30,
               a.n_years_in_era, a.n_suspect_years, a.corr_ctv_flood, a.corr_ctv_vegmean,
               a.downgraded_flag, a.dea_cultivation_class, a.dea_cultivation_class_final,
               a.rule_version, a.support_level
        FROM fact_dea_cultivation_assessment a JOIN dim_management_zone z ON z.zone_fid = a.zone_fid""")
    con.commit()
    print(f"\n[execute] fact_dea_cultivation_assessment rows: {con.execute('SELECT COUNT(*) FROM fact_dea_cultivation_assessment').fetchone()[0]}")
    print(f"[execute] v_dea_zone_landuse_summary rows: {con.execute('SELECT COUNT(*) FROM v_dea_zone_landuse_summary').fetchone()[0]}")
    con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
