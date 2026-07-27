#!/usr/bin/env python
"""T2 Gate C - persist the Gate B aggregates and build v_zone_veg_annual.

Additive only. Creates fact_zone_veg_annual (zone x water_year x series_variant,
PK-keyed), fact_zone_community_veg_annual (Gate E faceting grain) and the
v_zone_veg_annual view joined to dim_management_zone. INSERT OR REPLACE keyed on
the PK - NEVER OR IGNORE (would pass a stability test while the DB is wrong).
No builder re-run; no existing object modified or dropped.
"""
import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TBL = ROOT / "Output" / "tables"
FACT = TBL / "T2_fact_zone_veg_annual.csv"
FACTC = TBL / "T2_fact_zone_community_veg_annual.csv"
DEN = TBL / "T2_zone_denominator.csv"   # DB/sidecar-derived, repo-relative (prep step)
MIN_PX_COMMUNITY = 30   # zone-community-year cells below this are flagged (0.62 ha at
                        # 24.97 m); a direct query can then exclude the 10-px slices.


def read_csv(p):
    with open(p, newline="") as f:
        return list(csv.DictReader(f))


def fnum(v):
    if v is None or v == "" or v == "NA":
        return None
    return float(v)


def inum(v):
    x = fnum(v)
    return None if x is None else int(round(x))


def main():
    den = {int(r["zone_fid"]): int(r["zone_nontreed_px"]) for r in read_csv(DEN)}
    fact = read_csv(FACT)
    factc = read_csv(FACTC)
    con = sqlite3.connect(DB)
    cur = con.cursor()

    # CREATE IF NOT EXISTS + INSERT OR REPLACE keyed on the PK: the upsert (not a
    # drop-and-recreate) does the work, so a re-run proves convergence and a future
    # manual column/row survives. Never DROP a data table on re-run (Task H lesson).
    cur.execute("""
        CREATE TABLE IF NOT EXISTS fact_zone_veg_annual (
          zone_fid INTEGER, water_year INTEGER, series_variant TEXT,
          n_pixels_valid INTEGER, zone_nontreed_px INTEGER, pixel_support_pct REAL,
          min_valid INTEGER, veg_mean REAL, veg_median REAL, veg_p05_spatial REAL,
          veg_p10_spatial REAL, veg_p25_spatial REAL, n_px_over_100 INTEGER,
          pct_px_over_100 REAL, wet_pixels INTEGER, valid_pixels INTEGER,
          flood_frac_pct REAL, min_support_rule TEXT, support_level TEXT,
          aggregation_unit TEXT,
          PRIMARY KEY (zone_fid, water_year, series_variant))""")
    for r in fact:
        zf = int(r["zone_fid"])
        npv = inum(r["n_pixels_valid"])
        znt = den[zf]
        cur.execute(
            """INSERT OR REPLACE INTO fact_zone_veg_annual VALUES
               (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (zf, inum(r["water_year"]), r["series_variant"], npv, znt,
             100.0 * npv / znt if znt else None, inum(r["min_valid"]),
             fnum(r["veg_mean"]), fnum(r["veg_median"]), fnum(r["veg_p05_spatial"]),
             fnum(r["veg_p10_spatial"]), fnum(r["veg_p25_spatial"]),
             inum(r["n_px_over_100"]), fnum(r["pct_px_over_100"]),
             inum(r["wet_pixels"]), inum(r["valid_pixels"]), fnum(r["flood_frac_pct"]),
             r["min_support_rule"], r["support_level"], r["aggregation_unit"]))

    cur.execute("""
        CREATE TABLE IF NOT EXISTS fact_zone_community_veg_annual (
          zone_fid INTEGER, community TEXT, water_year INTEGER, series_variant TEXT,
          n_pixels_valid INTEGER, veg_mean REAL, veg_p05_spatial REAL,
          below_min_support INTEGER, support_level TEXT, aggregation_unit TEXT,
          PRIMARY KEY (zone_fid, community, water_year, series_variant))""")
    # migration: add the flag to a table that predates this column (IF NOT EXISTS
    # above would otherwise silently keep the old schema). Test 1 caught Bala 28ca's
    # 10-pixel (0.62 ha) Aeolian slice sitting unflagged in this table.
    have = [c[1] for c in cur.execute(
        "PRAGMA table_info(fact_zone_community_veg_annual)")]
    if "below_min_support" not in have:
        cur.execute("ALTER TABLE fact_zone_community_veg_annual "
                    "ADD COLUMN below_min_support INTEGER")
    for r in factc:
        npv = inum(r["n_pixels_valid"])
        # NAMED columns, not positional: the migration ALTER appends below_min_support
        # at the end of a pre-existing table, so positional VALUES would shift.
        cur.execute(
            """INSERT OR REPLACE INTO fact_zone_community_veg_annual
               (zone_fid, community, water_year, series_variant, n_pixels_valid,
                veg_mean, veg_p05_spatial, below_min_support, support_level,
                aggregation_unit)
               VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (int(r["zone_fid"]), r["community"], inum(r["water_year"]),
             r["series_variant"], npv, fnum(r["veg_mean"]),
             fnum(r["veg_p05_spatial"]),
             1 if (npv is not None and npv < MIN_PX_COMMUNITY) else 0,
             "pixel", "zone_community_year"))

    cur.execute("DROP VIEW IF EXISTS v_zone_veg_annual")
    cur.execute("""
        CREATE VIEW v_zone_veg_annual AS
        SELECT f.zone_fid, d.zone_name, d.grazing_treatment, f.water_year,
               f.n_pixels_valid, f.pixel_support_pct,
               f.veg_mean, f.veg_median, f.veg_p05_spatial, f.veg_p10_spatial,
               f.veg_p25_spatial, f.n_px_over_100, f.pct_px_over_100,
               f.wet_pixels, f.valid_pixels, f.flood_frac_pct,
               f.series_variant, f.min_support_rule, f.support_level,
               f.aggregation_unit
        FROM fact_zone_veg_annual f
        JOIN dim_management_zone d ON d.zone_fid = f.zone_fid""")

    con.commit()
    n = cur.execute("SELECT COUNT(*) FROM fact_zone_veg_annual").fetchone()[0]
    nc = cur.execute("SELECT COUNT(*) FROM fact_zone_community_veg_annual").fetchone()[0]
    nv = cur.execute("SELECT COUNT(*) FROM v_zone_veg_annual").fetchone()[0]
    print(f"fact_zone_veg_annual rows           : {n}")
    print(f"fact_zone_community_veg_annual rows : {nc}")
    print(f"v_zone_veg_annual rows              : {nv}")
    print("variants:", cur.execute(
        "SELECT series_variant, COUNT(*) FROM fact_zone_veg_annual GROUP BY 1").fetchall())
    print("support/agg:", cur.execute(
        "SELECT DISTINCT support_level, aggregation_unit FROM fact_zone_veg_annual").fetchall())
    con.close()


if __name__ == "__main__":
    main()
