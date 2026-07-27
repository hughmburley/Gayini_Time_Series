#!/usr/bin/env python
"""T6 Gate C - persist the three-arm stratum table and the unzoned per-component table,
build v_three_arm_veg_annual. Additive: CREATE IF NOT EXISTS + INSERT OR REPLACE keyed
on the PK (never OR IGNORE, never DROP a data table). fact_zone_community_veg_annual is
NOT touched. Convergence by re-run, not stability.
"""
import csv
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TBL = ROOT / "Output" / "tables"


def rows(p):
    with open(p, newline="") as f:
        return list(csv.DictReader(f))


def fn(v):
    return None if v in (None, "", "NA") else float(v)


def i(v):
    x = fn(v)
    return None if x is None else int(round(x))


def main():
    A = rows(TBL / "T6_fact_three_arm_stratum.csv")
    B = rows(TBL / "T6_fact_unzoned_component.csv")
    con = sqlite3.connect(DB)
    c = con.cursor()

    c.execute("""CREATE TABLE IF NOT EXISTS fact_three_arm_stratum_veg_annual (
        treatment_arm TEXT, community TEXT, regime_band TEXT, water_year INTEGER,
        series_variant TEXT, n_units INTEGER, n_pixels_valid INTEGER,
        veg_mean REAL, veg_median REAL, veg_p05_spatial REAL, veg_p10_spatial REAL,
        wet_pixels INTEGER, valid_pixels INTEGER, flood_frac_pct REAL,
        support_level TEXT, aggregation_unit TEXT,
        PRIMARY KEY (treatment_arm, community, regime_band, water_year, series_variant))""")
    for r in A:
        c.execute("""INSERT OR REPLACE INTO fact_three_arm_stratum_veg_annual
            (treatment_arm, community, regime_band, water_year, series_variant, n_units,
             n_pixels_valid, veg_mean, veg_median, veg_p05_spatial, veg_p10_spatial,
             wet_pixels, valid_pixels, flood_frac_pct, support_level, aggregation_unit)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (r["treatment_arm"], r["community"], r["regime_band"], i(r["water_year"]),
             r["series_variant"], i(r["n_units"]), i(r["n_pixels_valid"]),
             fn(r["veg_mean"]), fn(r["veg_median"]), fn(r["veg_p05_spatial"]),
             fn(r["veg_p10_spatial"]), i(r["wet_pixels"]), i(r["valid_pixels"]),
             fn(r["flood_frac_pct"]), "pixel", "arm_community_band_year"))

    c.execute("""CREATE TABLE IF NOT EXISTS fact_unzoned_community_veg_annual (
        component_id INTEGER, community TEXT, regime_band TEXT, water_year INTEGER,
        series_variant TEXT, n_pixels_valid INTEGER, area_ha REAL,
        below_min_support INTEGER, veg_mean REAL, veg_median REAL, veg_p05_spatial REAL,
        veg_p10_spatial REAL, wet_pixels INTEGER, valid_pixels INTEGER,
        flood_frac_pct REAL, plot_confirmed INTEGER, n_plots INTEGER,
        treatment_arm TEXT, support_level TEXT, aggregation_unit TEXT,
        PRIMARY KEY (component_id, community, regime_band, water_year, series_variant))""")
    for r in B:
        c.execute("""INSERT OR REPLACE INTO fact_unzoned_community_veg_annual
            (component_id, community, regime_band, water_year, series_variant,
             n_pixels_valid, area_ha, below_min_support, veg_mean, veg_median,
             veg_p05_spatial, veg_p10_spatial, wet_pixels, valid_pixels, flood_frac_pct,
             plot_confirmed, n_plots, treatment_arm, support_level, aggregation_unit)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (i(r["component_id"]), r["community"], r["regime_band"], i(r["water_year"]),
             r["series_variant"], i(r["n_pixels_valid"]), fn(r["area_ha"]),
             i(r["below_min_support"]), fn(r["veg_mean"]), fn(r["veg_median"]),
             fn(r["veg_p05_spatial"]), fn(r["veg_p10_spatial"]), i(r["wet_pixels"]),
             i(r["valid_pixels"]), fn(r["flood_frac_pct"]), i(r["plot_confirmed"]),
             i(r["n_plots"]), "unzoned_inferred_standard", "pixel",
             "component_community_band_year"))

    c.execute("DROP VIEW IF EXISTS v_three_arm_veg_annual")
    c.execute("""CREATE VIEW v_three_arm_veg_annual AS
                 SELECT * FROM fact_three_arm_stratum_veg_annual""")
    con.commit()
    print("fact_three_arm_stratum_veg_annual :",
          c.execute("SELECT COUNT(*) FROM fact_three_arm_stratum_veg_annual").fetchone()[0])
    print("fact_unzoned_community_veg_annual :",
          c.execute("SELECT COUNT(*) FROM fact_unzoned_community_veg_annual").fetchone()[0])
    print("arms:", c.execute(
        "SELECT treatment_arm, COUNT(*) FROM v_three_arm_veg_annual GROUP BY 1").fetchall())
    con.close()


if __name__ == "__main__":
    main()
