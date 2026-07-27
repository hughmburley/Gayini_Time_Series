#!/usr/bin/env python
"""T6 Gate B prep - export all in-scope census pixels (zoned + unzoned) tagged with
the fields the extraction needs, plus a zone->arm map. Repo-relative, DB/sidecar-
derived (no temp, no absolute paths) - the T2 hardcoded-path lesson.

  T6_in_scope_points.csv : pixel_id, x_8058, y_8058, community, regime_band, zone_fid
                           (zone_fid NULL => unzoned arm)  -- SCOPE_NON_TREED, nine strata
  T6_zone_arm_map.csv     : zone_fid, grazing_excluded, treatment_arm

treatment_arm: zone_fid NULL -> unzoned_inferred_standard; grazing_excluded=1 ->
not_grazed; else grazed_14day.
"""
import csv
import sqlite3
import duckdb
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENS = (ROOT / "Output" / "census" / "gayini_pixel_census_8058.parquet").as_posix()
SIDE = (ROOT / "Output" / "census" / "gayini_pixel_zone_assignment.parquet").as_posix()
OUT = ROOT / "Output" / "tables"
OUT.mkdir(parents=True, exist_ok=True)
SCOPE = "c.treed_context_flag = FALSE AND c.regime_band <> 'context'"


def main():
    d = duckdb.connect()
    pts = (OUT / "T6_in_scope_points.csv").as_posix()
    d.execute(f"""
        COPY (
          SELECT c.pixel_id, c.x_8058, c.y_8058, c.community, c.regime_band, a.zone_fid
          FROM read_parquet('{CENS}') c JOIN read_parquet('{SIDE}') a USING(pixel_id)
          WHERE {SCOPE}
          ORDER BY a.zone_fid NULLS FIRST, c.pixel_id
        ) TO '{pts}' (HEADER, DELIMITER ',')""")
    n = d.execute(f"SELECT COUNT(*), COUNT(zone_fid) FROM read_csv_auto('{pts}')").fetchone()
    print(f"T6_in_scope_points.csv: {n[0]} rows ({n[1]} zoned, {n[0]-n[1]} unzoned)  "
          "[expect all nine-stratum in-scope pixels: zoned from T2 + unzoned]")

    # all census pixel centroids (1,080,157) - the mapped-extent mask, to confirm the
    # 7 standard plots sit OUTSIDE the mapped census (correction 4).
    cxy = (OUT / "T6_census_xy.csv").as_posix()
    d.execute(f"""COPY (SELECT x_8058, y_8058 FROM read_parquet('{CENS}'))
                  TO '{cxy}' (HEADER, DELIMITER ',')""")
    nc = d.execute(f"SELECT COUNT(*) FROM read_csv_auto('{cxy}')").fetchone()[0]
    print(f"T6_census_xy.csv: {nc} pixels (mapped-extent mask)")

    con = sqlite3.connect(ROOT / "Output" / "database" / "Gayini_Results.sqlite")
    rows = con.execute(
        "SELECT zone_fid, grazing_excluded FROM dim_management_zone").fetchall()
    con.close()
    with open(OUT / "T6_zone_arm_map.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["zone_fid", "grazing_excluded", "treatment_arm"])
        for zf, gx in rows:
            arm = "not_grazed" if gx == 1 else "grazed_14day"
            w.writerow([zf, gx, arm])
    print(f"T6_zone_arm_map.csv: {len(rows)} zones")


if __name__ == "__main__":
    main()
