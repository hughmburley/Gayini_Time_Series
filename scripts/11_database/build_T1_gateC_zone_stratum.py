#!/usr/bin/env python3
"""T1 Gate C - sidecar parquet, census_by_zone_stratum + v_census_by_zone_stratum,
reconciliation. Spec: docs/T1_zone_stratum_census_join.md v3, Gate C.

The point-in-polygon assignment is done in R (T1_gateC_assign.R, reusing the
checkerboard st_intersects). This step consumes its output:
  - writes Output/census/gayini_pixel_zone_assignment.parquet (pixel_id, zone_fid),
    registered in census_asset (first-50-MB SHA-256);
  - aggregates the census parquet x assignment into census_by_zone_stratum
    (area from gayini_params.PIXEL_AREA_HA, NEVER a literal);
  - builds v_census_by_zone_stratum with support_level='pixel_within_zone_stratum';
  - reconciles: Sum(zoned+unzoned) = 1,080,157 diff=0, and area per stratum vs
    census_stratum diff < 0.1 ha.

Usage: python scripts/11_database/build_T1_gateC_zone_stratum.py [check|execute]
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
import gayini_params  # noqa: E402  PIXEL_AREA_HA, TOTAL_CENSUS_PX

DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
CENSUS = ROOT / "Output" / "census" / "gayini_pixel_census_8058.parquet"
ASSIGN_CSV = ROOT / "Output" / "census" / "_tmp" / "assignment.csv"
SIDECAR = ROOT / "Output" / "census" / "gayini_pixel_zone_assignment.parquet"
RECON_CSV = ROOT / "Output" / "tables" / "T1_gateC_reconciliation.csv"
RUN_ID = "T1_gateC"
PIX = gayini_params.PIXEL_AREA_HA

# NaN-guard (census veg_p* store NULLs as NaN, D7): NaN != NaN is TRUE
NN = "CASE WHEN isnan({c}) THEN NULL ELSE {c} END"


def sha256_first50(path: Path) -> str:
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            b = f.read(1024 * 1024)
            if not b:
                break
            h.update(b); read += len(b)
    return h.hexdigest()


def aggregate(dd):
    sql = f"""
    SELECT a.zone_fid AS zone_fid,
           c.community AS community,
           c.regime_band AS regime_band,
           CAST(c.treed_context_flag AS INTEGER) AS treed_context_flag,
           COUNT(*) AS n_pixels,
           AVG(c.flood_freq_pct) AS flood_freq_mean,
           MEDIAN(c.flood_freq_pct) AS flood_freq_median,
           QUANTILE_CONT(c.flood_freq_pct, 0.1) AS flood_freq_p10,
           QUANTILE_CONT(c.flood_freq_pct, 0.9) AS flood_freq_p90,
           AVG({NN.format(c='c.veg_p05')}) AS veg_p05_mean,
           MEDIAN({NN.format(c='c.veg_p05')}) AS veg_p05_median,
           AVG({NN.format(c='c.veg_p10')}) AS veg_p10_mean,
           AVG({NN.format(c='c.veg_p50')}) AS veg_p50_mean
    FROM read_parquet('{CENSUS.as_posix()}') c
    JOIN read_parquet('{SIDECAR.as_posix()}') a USING (pixel_id)
    GROUP BY 1,2,3,4
    """
    return dd.execute(sql).fetchall()


DDL = """
CREATE TABLE IF NOT EXISTS census_by_zone_stratum (
  zone_fid_key       INTEGER NOT NULL,   -- COALESCE(zone_fid,-1) so unzoned has a key
  zone_fid           INTEGER,            -- NULL = unzoned
  community          TEXT NOT NULL,
  regime_band        TEXT NOT NULL,
  treed_context_flag INTEGER NOT NULL,
  n_pixels           INTEGER NOT NULL,
  area_ha            REAL NOT NULL,      -- n_pixels * gayini_params.PIXEL_AREA_HA
  flood_freq_mean    REAL, flood_freq_median REAL, flood_freq_p10 REAL, flood_freq_p90 REAL,
  veg_p05_mean       REAL, veg_p05_median REAL, veg_p10_mean REAL, veg_p50_mean REAL,
  run_id             TEXT,
  PRIMARY KEY (zone_fid_key, community, regime_band, treed_context_flag)
)
"""

VIEW = """
CREATE VIEW v_census_by_zone_stratum AS
SELECT s.zone_fid,
       COALESCE(z.zone_name, 'unzoned') AS zone_name,
       z.grazing_treatment, z.grazing_excluded,
       s.community, s.regime_band, s.treed_context_flag,
       s.n_pixels, s.area_ha,
       s.flood_freq_mean, s.flood_freq_median, s.flood_freq_p10, s.flood_freq_p90,
       s.veg_p05_mean, s.veg_p05_median, s.veg_p10_mean, s.veg_p50_mean,
       'pixel' AS support_level,            -- closed ladder (enumerable, T5 4.4)
       'zone_stratum' AS aggregation_unit   -- free text: what it is aggregated TO
FROM census_by_zone_stratum s
LEFT JOIN dim_management_zone z ON z.zone_fid = s.zone_fid
"""


def main(mode: str) -> None:
    if not ASSIGN_CSV.is_file():
        raise SystemExit(f"ABORT: {ASSIGN_CSV} missing - run T1_gateC_assign.R first.")
    dd = duckdb.connect()

    # sidecar parquet (pixel_id, zone_fid) from the R assignment
    dd.execute(f"""COPY (SELECT CAST(pixel_id AS INTEGER) AS pixel_id,
                         CAST(zone_fid AS INTEGER) AS zone_fid
                        FROM read_csv_auto('{ASSIGN_CSV.as_posix()}', nullstr=''))
                   TO '{SIDECAR.as_posix()}' (FORMAT PARQUET)""")
    n_assign = dd.execute(f"SELECT COUNT(*), COUNT(zone_fid) FROM read_parquet('{SIDECAR.as_posix()}')").fetchone()
    n_total, n_zoned = n_assign
    n_unzoned = n_total - n_zoned
    print(f"[assign] total={n_total} zoned={n_zoned} unzoned={n_unzoned}")

    rows = aggregate(dd)
    # attach area + zone_fid_key
    built = []
    for r in rows:
        zone_fid = r[0]
        n_pixels = r[4]
        built.append((-1 if zone_fid is None else zone_fid, zone_fid, r[1], r[2], r[3],
                      n_pixels, round(n_pixels * PIX, 6),
                      r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], RUN_ID))

    # reconciliation figures
    sum_px = sum(b[5] for b in built)
    sum_ha = sum(b[6] for b in built)
    unzoned_px = sum(b[5] for b in built if b[1] is None)
    unzoned_ha = round(unzoned_px * PIX, 4)
    print(f"[recon] Sum n_pixels={sum_px} (expect {gayini_params.TOTAL_CENSUS_PX}, "
          f"diff={sum_px - gayini_params.TOTAL_CENSUS_PX})")
    print(f"[recon] unzoned {unzoned_px} px = {unzoned_ha} ha "
          f"(priors: 194,865 px / 12,179 ha and ~12,001 ha - comparisons, not targets)")

    if mode == "check":
        print(f"[check] census_by_zone_stratum rows to write: {len(built)}  area_ha/px={PIX}")
        print("[check] NO DB WRITE.")
        return

    con = sqlite3.connect(DB.as_posix())
    try:
        # register the sidecar in census_asset
        ck = sha256_first50(SIDECAR)
        con.execute(
            "INSERT OR REPLACE INTO census_asset "
            "(census_asset_id, path, product, crs_epsg, grid_reference, n_rows, "
            " checksum_sha256, path_exists, qa_status, run_id, schema_version) "
            "VALUES (?,?,?,?,?,?,?,1,'REVIEW',?,?)",
            ("census_zone_assignment_8058", SIDECAR.relative_to(ROOT).as_posix(),
             "pixel_zone_assignment", 8058, "raster_veg_regime_class_8058", n_total,
             ck, RUN_ID, "pixel_zone_assignment/2026-07-26"))

        con.execute("INSERT OR REPLACE INTO workflow_run "
                    "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
                    "VALUES (?,?,?,?,0,'REVIEW')",
                    (RUN_ID, "2026-07-26T00:00:00+00:00",
                     "scripts/11_database/build_T1_gateC_zone_stratum.py",
                     '{"gate": "C"}'))

        con.execute(DDL)
        con.execute("DELETE FROM census_by_zone_stratum WHERE run_id=?", (RUN_ID,))
        con.executemany(
            "INSERT OR REPLACE INTO census_by_zone_stratum "
            "(zone_fid_key, zone_fid, community, regime_band, treed_context_flag, "
            " n_pixels, area_ha, flood_freq_mean, flood_freq_median, flood_freq_p10, "
            " flood_freq_p90, veg_p05_mean, veg_p05_median, veg_p10_mean, veg_p50_mean, run_id) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", built)

        con.execute("DROP VIEW IF EXISTS v_census_by_zone_stratum")
        con.execute(VIEW)
        con.commit()

        # reconcile area per stratum vs census_stratum
        recon = con.execute("""
            SELECT s.community, s.regime_band,
                   ROUND(SUM(z.area_ha),4) AS zone_area,
                   ROUND(cs.area_ha,4) AS census_area,
                   ROUND(SUM(z.area_ha) - cs.area_ha, 4) AS diff_ha
            FROM census_by_zone_stratum z
            JOIN census_stratum cs ON cs.community=z.community AND cs.regime_band=z.regime_band
            JOIN (SELECT DISTINCT community, regime_band FROM census_stratum) s
                 ON s.community=z.community AND s.regime_band=z.regime_band
            GROUP BY s.community, s.regime_band, cs.area_ha
            ORDER BY ABS(SUM(z.area_ha) - cs.area_ha) DESC""").fetchall()
        max_diff = max((abs(r[4]) for r in recon), default=0.0)
        nrows = con.execute("SELECT COUNT(*) FROM census_by_zone_stratum").fetchone()[0]
        vsum = con.execute("SELECT SUM(n_pixels), ROUND(SUM(area_ha),2) FROM v_census_by_zone_stratum").fetchone()
        print(f"[execute] census_by_zone_stratum rows={nrows}; view sum_px={vsum[0]} sum_ha={vsum[1]}")
        print(f"[execute] pixel reconciliation diff = {vsum[0] - gayini_params.TOTAL_CENSUS_PX} (must be 0)")
        print(f"[execute] max per-stratum area diff vs census_stratum = {max_diff} ha (must be < 0.1)")
        print(f"[execute] worst strata:")
        for r in recon[:3]:
            print(f"      {r[0]} / {r[1]}: zone={r[2]} census={r[3]} diff={r[4]}")
        # write reconciliation artefact
        RECON_CSV.parent.mkdir(parents=True, exist_ok=True)
        import csv as _csv
        with RECON_CSV.open("w", newline="", encoding="utf-8") as f:
            w = _csv.writer(f)
            w.writerow(["community", "regime_band", "zone_area_ha", "census_area_ha", "diff_ha"])
            w.writerows(recon)
            w.writerow([])
            w.writerow(["zoned_px", n_zoned, "unzoned_px", n_unzoned, "total", n_total])
            w.writerow(["pixel_diff_vs_total_census_px", vsum[0] - gayini_params.TOTAL_CENSUS_PX])
        print(f"[execute] wrote {RECON_CSV.relative_to(ROOT).as_posix()}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
