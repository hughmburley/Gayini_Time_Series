#!/usr/bin/env python3
"""T1 Gate D - v_zone_stratum_treatment_contrast. Spec: T1_zone_stratum_census_join.md v3.

One row per (community, regime_band) over the NINE non-treed strata
(treed_context_flag = 0 AND regime_band <> 'context'), with ungrazed-minus-grazed
differences in veg_p05_mean and flood_freq_mean IN THE SAME ROW (so the wetness
confound is visible beside every floor difference), pixel counts on both sides,
and min_cell_n = 1 where either side < 3,000 px. Support split per the Gate C fix:
support_level='pixel', aggregation_unit='zone_stratum'.

Grazed = 14-day grazing (60 zones); ungrazed = No grazing (4 zones, all Bala
26ca-29ca). A zone spans several communities, so ungrazed pixels occur across
strata, not only Riverine. Per-stratum means are pixel-weighted across zones.

Usage: python scripts/11_database/build_T1_gateD_contrast.py [check|execute]
"""
from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT_CSV = ROOT / "Output" / "tables" / "T1_gateD_contrast.csv"
RUN_ID = "T1_gateD"

VIEW = """
CREATE VIEW v_zone_stratum_treatment_contrast AS
WITH agg AS (
  SELECT community, regime_band, grazing_excluded,
         SUM(n_pixels) AS n_px,
         SUM(CASE WHEN veg_p05_mean IS NOT NULL THEN veg_p05_mean*n_pixels END)
           / SUM(CASE WHEN veg_p05_mean IS NOT NULL THEN n_pixels END) AS veg_p05_mean,
         SUM(CASE WHEN flood_freq_mean IS NOT NULL THEN flood_freq_mean*n_pixels END)
           / SUM(CASE WHEN flood_freq_mean IS NOT NULL THEN n_pixels END) AS flood_freq_mean
  FROM v_census_by_zone_stratum
  WHERE zone_fid IS NOT NULL           -- only zoned pixels carry a treatment
    AND treed_context_flag = 0 AND regime_band <> 'context'   -- nine non-treed strata
  GROUP BY community, regime_band, grazing_excluded
),
strata AS (SELECT DISTINCT community, regime_band FROM agg)
SELECT s.community, s.regime_band,
       u.n_px AS ungrazed_px, g.n_px AS grazed_px,
       ROUND(u.veg_p05_mean, 3) AS ungrazed_veg_p05,
       ROUND(g.veg_p05_mean, 3) AS grazed_veg_p05,
       ROUND(u.veg_p05_mean - g.veg_p05_mean, 3) AS veg_p05_delta,
       ROUND(u.flood_freq_mean, 3) AS ungrazed_flood_freq,
       ROUND(g.flood_freq_mean, 3) AS grazed_flood_freq,
       ROUND(u.flood_freq_mean - g.flood_freq_mean, 3) AS flood_freq_delta,
       CASE WHEN COALESCE(u.n_px,0) < 3000 OR COALESCE(g.n_px,0) < 3000
            THEN 1 ELSE 0 END AS min_cell_n,
       'pixel' AS support_level,
       'zone_stratum' AS aggregation_unit
FROM strata s
LEFT JOIN agg g ON g.community=s.community AND g.regime_band=s.regime_band AND g.grazing_excluded=0
LEFT JOIN agg u ON u.community=s.community AND u.regime_band=s.regime_band AND u.grazing_excluded=1
ORDER BY s.community, s.regime_band
"""

COLS = ["community", "regime_band", "ungrazed_px", "grazed_px",
        "ungrazed_veg_p05", "grazed_veg_p05", "veg_p05_delta",
        "ungrazed_flood_freq", "grazed_flood_freq", "flood_freq_delta",
        "min_cell_n", "support_level", "aggregation_unit"]


def main(mode: str) -> None:
    con = sqlite3.connect(DB.as_posix() if mode == "execute" else f"file:{DB.as_posix()}?mode=ro",
                          uri=(mode != "execute"))
    try:
        if mode == "execute":
            con.execute("DROP VIEW IF EXISTS v_zone_stratum_treatment_contrast")
            con.execute(VIEW)
            con.execute("INSERT OR REPLACE INTO workflow_run "
                        "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
                        "VALUES (?,?,?,?,0,'REVIEW')",
                        (RUN_ID, "2026-07-26T00:00:00+00:00",
                         "scripts/11_database/build_T1_gateD_contrast.py", '{"gate": "D"}'))
            con.commit()
            rows = con.execute(f"SELECT {', '.join(COLS)} FROM v_zone_stratum_treatment_contrast").fetchall()
            OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
            with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f); w.writerow(COLS); w.writerows(rows)
        else:
            # dry: create in a temp attached? simplest: build the CTE inline as a SELECT
            rows = con.execute(VIEW.replace("CREATE VIEW v_zone_stratum_treatment_contrast AS", "")).fetchall()

        print(f"[{mode}] v_zone_stratum_treatment_contrast: {len(rows)} rows (expect 9 non-treed strata)")
        hdr = ["community", "band", "unz_px", "grz_px", "unz_p05", "grz_p05",
               "p05_delta", "unz_ff", "grz_ff", "ff_delta", "min_cell_n"]
        print("  " + " | ".join(f"{h:>9}" for h in hdr))
        for r in rows:
            comm = r[0].split()[0]
            vals = [comm, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10]]
            print("  " + " | ".join(f"{str(v):>9}" for v in vals))
        flagged = [f"{r[0].split()[0]}/{r[1]}" for r in rows if r[10] == 1]
        print(f"[{mode}] min_cell_n flagged (<3000 px either side): {flagged}")
        if mode == "execute":
            print(f"[execute] wrote {OUT_CSV.relative_to(ROOT).as_posix()}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
