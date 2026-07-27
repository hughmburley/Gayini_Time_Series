#!/usr/bin/env python
"""T2 Gate B prep - derive the extraction inputs from the DB + sidecar, not temp.

Emits, to Output/tables/ (repo-relative, no absolute paths), the nine-stratum
SCOPE_NON_TREED zoned join so the scope chain that proves the filter is a tracked
artefact, not a session-scoped temp file:

  T2_in_scope_points.csv : pixel_id, x_8058, y_8058, zone_fid, community, regime_band
  T2_zone_denominator.csv: zone_fid, zone_nontreed_px  (min-support denominator)

SCOPE_NON_TREED = treed_context_flag = 0 AND regime_band <> 'context'  (nine strata),
zoned only (zone_fid IS NOT NULL). Deterministic: same parquet -> same bytes.
"""
import duckdb
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENS = (ROOT / "Output" / "census" / "gayini_pixel_census_8058.parquet").as_posix()
SIDE = (ROOT / "Output" / "census" / "gayini_pixel_zone_assignment.parquet").as_posix()
OUT = ROOT / "Output" / "tables"
OUT.mkdir(parents=True, exist_ok=True)

SCOPE = "c.treed_context_flag = FALSE AND c.regime_band <> 'context' AND a.zone_fid IS NOT NULL"


def main():
    d = duckdb.connect()
    pts = (OUT / "T2_in_scope_points.csv").as_posix()
    den = (OUT / "T2_zone_denominator.csv").as_posix()
    d.execute(f"""
        COPY (
          SELECT c.pixel_id, c.x_8058, c.y_8058, a.zone_fid, c.community, c.regime_band
          FROM read_parquet('{CENS}') c JOIN read_parquet('{SIDE}') a USING(pixel_id)
          WHERE {SCOPE}
          ORDER BY a.zone_fid, c.pixel_id
        ) TO '{pts}' (HEADER, DELIMITER ',')""")
    d.execute(f"""
        COPY (
          SELECT a.zone_fid, COUNT(*) AS zone_nontreed_px
          FROM read_parquet('{CENS}') c JOIN read_parquet('{SIDE}') a USING(pixel_id)
          WHERE {SCOPE}
          GROUP BY a.zone_fid ORDER BY a.zone_fid
        ) TO '{den}' (HEADER, DELIMITER ',')""")
    n = d.execute(f"SELECT COUNT(*) FROM read_csv_auto('{pts}')").fetchone()[0]
    z = d.execute(f"SELECT COUNT(*), SUM(zone_nontreed_px) FROM read_csv_auto('{den}')").fetchone()
    print(f"T2_in_scope_points.csv : {n} rows   (expect 795602)")
    print(f"T2_zone_denominator.csv: {z[0]} zones, {z[1]} px (expect 64, 795602)")


if __name__ == "__main__":
    main()
