#!/usr/bin/env python
"""REG-1 Gate C — promote the three T10 output CSVs to first-class DB objects.
ADDITIVE: three NEW fact tables + a labelled view each. No existing object modified, no
builder run. Idempotent by convergence (DROP IF EXISTS + rebuild of these NEW objects only).
Every CSV column is preserved by name (the report stream reads them by name); four meta
columns are appended (support_level, aggregation_unit, series_variant, run_id).
"""
import sqlite3, csv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
TAB=ROOT/"Output"/"tables"; RUN="REG1_gateC_20260729"
con=sqlite3.connect(DB); c=con.cursor()

SPECS=[
 dict(table="fact_zone_floor_flood_residual", view="v_zone_floor_flood_residual", csv="T10_gateC_crosssectional_residuals.csv",
      agg="zone", expect=64,
      cols=[("zone_fid","INTEGER"),("zone_name","TEXT"),("treatment","TEXT"),("mean_floor","REAL"),
            ("mean_flood","REAL"),("predicted_floor","REAL"),("residual","REAL"),("rank","INTEGER")],
      label="Cross-sectional floor~flood residual per paddock (bivariate; predicted = floor_flood_intercept + slope*flood)."),
 dict(table="fact_zone_floor_temporal", view="v_zone_floor_temporal", csv="T10_gateC_temporal_table.csv",
      agg="zone", expect=64,
      cols=[("zone_fid","INTEGER"),("zone_name","TEXT"),("treatment","TEXT"),("raw_floor_trend","REAL"),
            ("within_paddock_water_slope","REAL"),("water_response_r","REAL"),("water_adjusted_floor_trend","REAL"),
            ("adj_se","REAL"),("flood_sd","REAL"),("lag_r","REAL"),("current_r","REAL"),
            ("rank_by_adjusted","INTEGER"),("n","INTEGER")],
      label="Per-paddock within-paddock water-adjusted floor trend (T10 temporal arm)."),
 dict(table="fact_zone_community_part_summary", view="v_zone_community_part_summary", csv="T10_gateC_percommunity.csv",
      agg="zone_community", expect=115,
      cols=[("zone_fid","INTEGER"),("zone_name","TEXT"),("treatment","TEXT"),("community","TEXT"),("n_years","INTEGER"),
            ("level_floor","REAL"),("community_median_level","REAL"),("level_dev","REAL"),("level_rank","INTEGER"),
            ("n_parts_in_community","INTEGER"),("trend","REAL"),("community_median_trend","REAL"),("trend_dev","REAL"),
            ("comp_inland_pct","REAL"),("comp_riverine_pct","REAL"),("comp_aeolian_pct","REAL")],
      label="Paddock x community part summary (>=25 yr, >=30 px/cell). L-01 substrate; T13 consumes this."),
]
INT={"INTEGER"}
for s in SPECS:
    rows=list(csv.DictReader(open(TAB/s["csv"],encoding="utf-8")))
    csv_cols=[k for k in rows[0].keys()]
    want=[c0 for c0,_ in s["cols"]]
    assert csv_cols==want, f"{s['csv']} columns {csv_cols} != {want}"   # no column dropped/renamed
    coldefs=", ".join(f"{n} {t}" for n,t in s["cols"])
    c.execute(f"DROP VIEW IF EXISTS {s['view']}"); c.execute(f"DROP TABLE IF EXISTS {s['table']}")
    c.execute(f"CREATE TABLE {s['table']} ({coldefs}, support_level TEXT, aggregation_unit TEXT, series_variant TEXT, run_id TEXT)")
    ins=[]
    for r in rows:
        vals=[ (int(r[n]) if t in INT and r[n] not in ('','nan') else (float(r[n]) if t=='REAL' and r[n] not in ('','nan') else r[n])) for n,t in s["cols"]]
        ins.append(tuple(vals)+("pixel",s["agg"],"mean_of_seasons",RUN))
    ph=",".join("?"*(len(s["cols"])+4))
    c.executemany(f"INSERT INTO {s['table']} VALUES ({ph})", ins)
    c.execute(f"CREATE VIEW {s['view']} AS SELECT * FROM {s['table']}")   # labelled passthrough
con.commit()
print("promoted:")
for s in SPECS:
    n=c.execute(f"SELECT COUNT(*) FROM {s['table']}").fetchone()[0]
    ncols=len(c.execute(f"PRAGMA table_info({s['table']})").fetchall())
    vok=bool(c.execute("SELECT 1 FROM sqlite_master WHERE name=? AND type='view'",(s['view'],)).fetchone())
    print(f"  {s['table']}: {n} rows (expect {s['expect']}) {'OK' if n==s['expect'] else 'DIFFER'}; {ncols} cols; view {s['view']} {'OK' if vok else 'MISSING'}")
con.close(); print("DONE")
