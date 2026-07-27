#!/usr/bin/env python
"""T2 Gate F - give the reference-gap finding a DB home (was C-1: lived only in a CSV
and a chat window; T4 claim_register is deferred).

Builds, additively (CREATE IF NOT EXISTS + INSERT OR REPLACE, no drop):
  fact_community_year_flood      - community x year flood_frac + top-tercile flood_class
                                   (the classification previously only in a CSV)
  fact_reference_gap_decomposition - the ref-vs-grazed decomposition, 3 communities x
                                   {early_8897, late_1322, all} x {flood, non_flood, all}
  v_reference_gap_decomposition  - consumption view over the decomposition table

The decomposition is MATERIALISED, not a live view, because it needs a per-year spatial
MEDIAN of grazed zones (SQLite has no MEDIAN) and a two-stage aggregation (per year, then
per window). It is rebuilt deterministically from fact_zone_community_veg_annual
(mean_of_seasons, below_min_support = 0) by this script - rerun if that table changes.

ref_change_pp / grazed_change_pp are the point: gap_change_pp = ref_change_pp -
grazed_change_pp (pp, additive), so a single narrowing number cannot hide whether the
reference side rose or the grazed side fell.
"""
import csv
import sqlite3
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
FLOOD_CSV = ROOT / "Output" / "tables" / "T2_community_year_flood.csv"
EARLY_MAX, LATE_MIN = 1997, 2013


def q_type7(xs, p):
    """R's default quantile (type 7) - match Gate E's flood-tercile threshold exactly."""
    s = sorted(xs)
    n = len(s)
    if n == 1:
        return s[0]
    h = (n - 1) * p
    lo = int(h)
    frac = h - lo
    hi = min(lo + 1, n - 1)
    return s[lo] + frac * (s[hi] - s[lo])


def main():
    con = sqlite3.connect(DB)
    cur = con.cursor()

    # ---- flood table + per-community top-tercile classification ----
    flood = {}
    with open(FLOOD_CSV, newline="") as f:
        for r in csv.DictReader(f):
            flood.setdefault(r["community"], []).append(
                (int(r["water_year"]), float(r["valid_pixels"]),
                 float(r["wet_pixels"]), float(r["flood_frac_pct"])))
    thr = {cm: q_type7([x[3] for x in rows], 2 / 3) for cm, rows in flood.items()}
    fclass = {}  # (community, year) -> 'flood' | 'non_flood'
    cur.execute("""CREATE TABLE IF NOT EXISTS fact_community_year_flood (
        community TEXT, water_year INTEGER, valid_pixels INTEGER, wet_pixels INTEGER,
        flood_frac_pct REAL, flood_tercile_thr REAL, flood_class TEXT,
        support_level TEXT, aggregation_unit TEXT,
        PRIMARY KEY (community, water_year))""")
    for cm, rows in flood.items():
        for (yr, vp, wp, ff) in rows:
            cls = "flood" if ff >= thr[cm] else "non_flood"
            fclass[(cm, yr)] = cls
            cur.execute("""INSERT OR REPLACE INTO fact_community_year_flood VALUES
                           (?,?,?,?,?,?,?,?,?)""",
                        (cm, yr, int(vp), int(wp), ff, thr[cm], cls,
                         "pixel", "community_year"))

    # ---- pull the in-support mean_of_seasons cells, split ref / grazed ----
    rows = cur.execute("""
        SELECT f.community, f.water_year, d.grazing_excluded, f.zone_fid, f.veg_p05_spatial
        FROM fact_zone_community_veg_annual f
        JOIN dim_management_zone d ON d.zone_fid = f.zone_fid
        WHERE f.series_variant = 'mean_of_seasons' AND f.below_min_support = 0
    """).fetchall()
    # index: community -> year -> {'ref': {fid:val}, 'grz': {fid:val}}
    idx = {}
    for cm, yr, gx, fid, v in rows:
        d = idx.setdefault(cm, {}).setdefault(yr, {"ref": {}, "grz": {}})
        d["ref" if gx == 1 else "grz"][fid] = v

    def window_years(yrs, win):
        if win == "early_8897":
            return [y for y in yrs if y <= EARLY_MAX]
        if win == "late_1322":
            return [y for y in yrs if y >= LATE_MIN]
        return list(yrs)

    def level(cm, win, fc):
        """(ref_p05_mean, grazed_p05_median, gap, n_ref, n_grz) for a cell, or Nones."""
        yrs = [y for y in idx.get(cm, {})
               if fc == "all" or fclass.get((cm, y)) == fc]
        yrs = window_years(yrs, win)
        ref_by_yr, grz_by_yr = [], []
        refs, grzs = set(), set()
        for y in yrs:
            d = idx[cm][y]
            if d["ref"]:
                ref_by_yr.append(statistics.mean(d["ref"].values()))
                refs.update(d["ref"].keys())
            if d["grz"]:
                grz_by_yr.append(statistics.median(d["grz"].values()))
                grzs.update(d["grz"].keys())
        if not ref_by_yr or not grz_by_yr:
            return (None, None, None, len(refs), len(grzs))
        rm = statistics.mean(ref_by_yr)
        gm = statistics.mean(grz_by_yr)          # mean of yearly grazed medians (Gate E)
        return (rm, gm, rm - gm, len(refs), len(grzs))

    cur.execute("""CREATE TABLE IF NOT EXISTS fact_reference_gap_decomposition (
        community TEXT, window TEXT, flood_class TEXT,
        n_ref_paddocks INTEGER, n_grazed_zones INTEGER,
        ref_p05_mean REAL, grazed_p05_median REAL, gap_pp REAL,
        ref_change_pp REAL, grazed_change_pp REAL, gap_change_pp REAL,
        support_level TEXT, aggregation_unit TEXT,
        PRIMARY KEY (community, window, flood_class))""")

    def rnd(x):
        return None if x is None else round(x, 2)

    for cm in sorted(idx):
        for fc in ("flood", "non_flood", "all"):
            e = level(cm, "early_8897", fc)
            l = level(cm, "late_1322", fc)
            # change columns (late - early within flood_class); same across window rows
            rc = None if None in (e[0], l[0]) else l[0] - e[0]
            gc = None if None in (e[1], l[1]) else l[1] - e[1]
            gpc = None if None in (e[2], l[2]) else l[2] - e[2]
            for win in ("early_8897", "late_1322", "all"):
                rm, gm, gap, nref, ngrz = level(cm, win, fc)
                cur.execute("""INSERT OR REPLACE INTO fact_reference_gap_decomposition
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (cm, win, fc, nref, ngrz, rnd(rm), rnd(gm), rnd(gap),
                     rnd(rc), rnd(gc), rnd(gpc), "pixel", "community_window"))

    cur.execute("DROP VIEW IF EXISTS v_reference_gap_decomposition")
    cur.execute("""CREATE VIEW v_reference_gap_decomposition AS
                   SELECT * FROM fact_reference_gap_decomposition""")
    con.commit()

    print("fact_community_year_flood rows      :",
          cur.execute("SELECT COUNT(*) FROM fact_community_year_flood").fetchone()[0])
    print("v_reference_gap_decomposition rows  :",
          cur.execute("SELECT COUNT(*) FROM v_reference_gap_decomposition").fetchone()[0])
    print("\n-- window=all, flood_class=all (headline decomposition) --")
    for r in cur.execute("""SELECT community, n_ref_paddocks, n_grazed_zones,
             ref_p05_mean, grazed_p05_median, gap_pp,
             ref_change_pp, grazed_change_pp, gap_change_pp
             FROM v_reference_gap_decomposition
             WHERE window='all' AND flood_class='all' ORDER BY community"""):
        print(f"  {r[0][:26]:26s} nref={r[1]} ngrz={r[2]} "
              f"ref={r[3]:.1f} grz={r[4]:.1f} gap={r[5]:.2f} | "
              f"dref={r[6]:+.1f} dgrz={r[7]:+.1f} dgap={r[8]:+.2f}")
    print("\n-- gap_change_pp by flood_class (window rows collapse; use 'all' window) --")
    for r in cur.execute("""SELECT community, flood_class, gap_change_pp
             FROM v_reference_gap_decomposition
             WHERE window='all' AND flood_class IN ('flood','non_flood')
             ORDER BY community, flood_class"""):
        print(f"  {r[0][:26]:26s} {r[1]:10s} dgap={r[2]:+.2f}")
    con.close()


if __name__ == "__main__":
    main()
