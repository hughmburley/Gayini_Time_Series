#!/usr/bin/env python3
"""Pack v1.3 - register flood_frac_pct in dim_metric. Additive, one row.

Task list T1: "flood_frac_pct has no registered name (SCHEM-1 section 9) and PARTREG
quotes it 4,025 times. Register it in this task, with the two collisions recorded."

dim_metric is the right home, not dim_headline_number: this is a METRIC DEFINITION
that takes a different value for every unit-year, not a pinned value. Its two
collisions - census_flood_frequency_pct and inundation_annual_occurrence_pct - are
already dim_metric rows, so the three sit together where a reader meets them at once.

INSERT OR REPLACE, never OR IGNORE.
"""
import sqlite3, sys
from pathlib import Path

DB = Path(__file__).resolve().parents[2] / "Output/database/Gayini_Results.sqlite"
ROW = (
    "inundation_annual_unit_wet_fraction",
    "Annual wet fraction of a unit (flood_frac_pct)",
    "inundation", "pct", "0-100",
    "cells of the unit seen wet in the water year",
    "cells of the unit the satellite could see in the water year",
    "flood_frac_pct = 100 * wet_pixels / valid_pixels, computed WITHIN one water year ACROSS the "
    "unit's cells, on the 24.970268 m EPSG:8058 census grid. Column of fact_zone_veg_annual "
    "(paddock grain) and fact_zone_community_flood_annual (part grain). Registered at pack v1.3; "
    "it had carried no metric_id despite being the x-axis of every cover-and-water figure and being "
    "quoted 4,025 times in the PARTREG spine.",
    "How much of the unit was under water that year. It is an EXTENT within a year, aggregated to "
    "a unit, and it keeps a time axis: one value per unit per year.",
    "COLLISIONS - cite the identifier, never the value. (1) census_flood_frequency_pct is "
    "wet-YEARS / valid-years for ONE CELL over the whole record: pixel support, NO time axis, and it "
    "cannot be recomputed on a shorter window and compared. (2) inundation_annual_occurrence_pct is "
    "PLOT support under the any-pixel rule - a plot is wet if any of its ~16 cells is wet - and "
    "CLAUDE.md forbids presenting it as the headline. Also: this metric does NOT encode duration; a "
    "cell wet for one day and one wet for six months are identical. STORAGE: "
    "fact_zone_community_flood_annual stores this rounded to 4 dp (max deviation 4.999e-05 across "
    "4,130 part-years) while fact_zone_veg_annual stores it at full double precision - re-deriving "
    "from the counts will differ by up to 5e-05 and that is not drift.",
    "pixel 24.97 m (EPSG:8058 census grid), aggregated to the unit; the unit is named by the table "
    "it appears in - zone (paddock) or zone x community (part). NEVER plot support.")

mode = sys.argv[1] if len(sys.argv) > 1 else "check"
con = sqlite3.connect(DB); cur = con.cursor()
before = cur.execute("SELECT COUNT(*) FROM dim_metric").fetchone()[0]
print(f"  dim_metric before: {before}")
print(f"  registering: {ROW[0]}\n    {ROW[1]}")
if mode != "execute":
    print("\ncheck only - no write. Re-run with 'execute'.")
else:
    cur.execute("""INSERT OR REPLACE INTO dim_metric
        (metric_id, metric_name, domain, units, scale, numerator, denominator,
         method_summary, safe_interpretation, caveat, support) VALUES (?,?,?,?,?,?,?,?,?,?,?)""", ROW)
    con.commit()
    after = cur.execute("SELECT COUNT(*) FROM dim_metric").fetchone()[0]
    got = cur.execute("SELECT support FROM dim_metric WHERE metric_id=?", (ROW[0],)).fetchone()[0]
    print(f"\n  dim_metric {before} -> {after}  ({after-before:+d})   support recorded: {got[:46]}...")
    print("  the three wetness metrics now sit together:")
    for r in cur.execute("""SELECT metric_id, support FROM dim_metric WHERE metric_id IN
            ('inundation_annual_unit_wet_fraction','census_flood_frequency_pct',
             'inundation_annual_occurrence_pct') ORDER BY 1"""):
        print(f"    {r[0]:<38s} {str(r[1])[:52]}")
con.close()
