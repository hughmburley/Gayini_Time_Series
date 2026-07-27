#!/usr/bin/env python3
"""T1 Gate D - matched grazed/ungrazed contrast + block/zone-support robustness.
Spec: T1_zone_stratum_census_join.md v3, Gate D, plus the 27 Jul robustness ask.

Two views:
  v_zone_stratum_treatment_contrast  - the headline table: one row per non-treed
    stratum, ungrazed-grazed veg_p05_delta beside flood_freq_delta, pixel counts
    AND zone counts on both sides, min_cell_n (pixels < 3000). NOW carries
    n_ungrazed_zones / n_grazed_zones - the honest denominator for a treatment
    contrast (pixels are spatially autocorrelated).
  v_zone_stratum_contrast_bala_robust - block-controlled + zone-support. All four
    ungrazed zones are Bala paddocks (Bala 4 / Mara 0 / Dinan 0), so the headline
    'grazed' side (60 zones incl. Mara/Dinan) confounds treatment with the
    Bala-vs-rest difference. This view compares Bala-only (4 ungrazed vs 22 grazed
    Bala) both pixel-weighted (a) and as unweighted zone-means (b, n = zones),
    and reports the ungrazed-paddock spread so a single paddock carrying the
    effect is visible.

support_level='pixel', aggregation_unit='zone_stratum'. Idempotent (DROP+CREATE
views only). Usage: python scripts/11_database/build_T1_gateD_contrast.py [check|execute]
"""
from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT_CSV = ROOT / "Output" / "tables" / "T1_gateD_contrast.csv"
ROBUST_CSV = ROOT / "Output" / "tables" / "T1_gateD_robustness.csv"
RUN_ID = "T1_gateD"

CONTRAST_VIEW = """
CREATE VIEW v_zone_stratum_treatment_contrast AS
WITH agg AS (
  SELECT community, regime_band, grazing_excluded,
         COUNT(DISTINCT zone_fid) AS n_zones,
         SUM(n_pixels) AS n_px,
         SUM(CASE WHEN veg_p05_mean IS NOT NULL THEN veg_p05_mean*n_pixels END)
           / SUM(CASE WHEN veg_p05_mean IS NOT NULL THEN n_pixels END) AS veg_p05_mean,
         SUM(CASE WHEN flood_freq_mean IS NOT NULL THEN flood_freq_mean*n_pixels END)
           / SUM(CASE WHEN flood_freq_mean IS NOT NULL THEN n_pixels END) AS flood_freq_mean
  FROM v_census_by_zone_stratum
  WHERE zone_fid IS NOT NULL AND treed_context_flag = 0 AND regime_band <> 'context'
  GROUP BY community, regime_band, grazing_excluded
),
strata AS (SELECT DISTINCT community, regime_band FROM agg)
SELECT s.community, s.regime_band,
       u.n_zones AS n_ungrazed_zones, g.n_zones AS n_grazed_zones,
       u.n_px AS ungrazed_px, g.n_px AS grazed_px,
       ROUND(u.veg_p05_mean, 3) AS ungrazed_veg_p05,
       ROUND(g.veg_p05_mean, 3) AS grazed_veg_p05,
       ROUND(u.veg_p05_mean - g.veg_p05_mean, 3) AS veg_p05_delta,
       ROUND(u.flood_freq_mean, 3) AS ungrazed_flood_freq,
       ROUND(g.flood_freq_mean, 3) AS grazed_flood_freq,
       ROUND(u.flood_freq_mean - g.flood_freq_mean, 3) AS flood_freq_delta,
       CASE WHEN COALESCE(u.n_px,0) < 3000 OR COALESCE(g.n_px,0) < 3000 THEN 1 ELSE 0 END AS min_cell_n,
       'pixel' AS support_level, 'zone_stratum' AS aggregation_unit
FROM strata s
LEFT JOIN agg g ON g.community=s.community AND g.regime_band=s.regime_band AND g.grazing_excluded=0
LEFT JOIN agg u ON u.community=s.community AND u.regime_band=s.regime_band AND u.grazing_excluded=1
ORDER BY s.community, s.regime_band
"""

ROBUST_VIEW = """
CREATE VIEW v_zone_stratum_contrast_bala_robust AS
WITH bala AS (
  SELECT s.community, s.regime_band, z.grazing_excluded,
         s.zone_fid, s.n_pixels, s.veg_p05_mean, s.flood_freq_mean
  FROM census_by_zone_stratum s JOIN dim_management_zone z ON z.zone_fid = s.zone_fid
  WHERE z.zone_group = 'Bala' AND s.treed_context_flag = 0
    AND s.regime_band <> 'context' AND s.veg_p05_mean IS NOT NULL
),
agg AS (
  SELECT community, regime_band, grazing_excluded,
         COUNT(*) AS n_zones,
         SUM(veg_p05_mean*n_pixels)/SUM(n_pixels) AS veg_pxwtd,
         AVG(veg_p05_mean) AS veg_zonemean,
         MIN(veg_p05_mean) AS veg_min, MAX(veg_p05_mean) AS veg_max,
         SUM(flood_freq_mean*n_pixels)/SUM(n_pixels) AS ff_pxwtd
  FROM bala GROUP BY community, regime_band, grazing_excluded
),
strata AS (SELECT DISTINCT community, regime_band FROM agg)
SELECT s.community, s.regime_band,
       u.n_zones AS n_ungrazed_bala, g.n_zones AS n_grazed_bala,
       ROUND(u.veg_pxwtd - g.veg_pxwtd, 3) AS veg_p05_delta_bala_pxwtd,
       ROUND(u.veg_zonemean - g.veg_zonemean, 3) AS veg_p05_delta_zonesupport,
       ROUND(u.ff_pxwtd - g.ff_pxwtd, 3) AS flood_freq_delta_bala,
       ROUND(u.veg_min, 1) AS ungrazed_p05_min, ROUND(u.veg_max, 1) AS ungrazed_p05_max,
       'pixel' AS support_level, 'zone_stratum' AS aggregation_unit
FROM strata s
LEFT JOIN agg g ON g.community=s.community AND g.regime_band=s.regime_band AND g.grazing_excluded=0
LEFT JOIN agg u ON u.community=s.community AND u.regime_band=s.regime_band AND u.grazing_excluded=1
ORDER BY s.community, s.regime_band
"""


def dump(con, view, cols):
    return con.execute(f"SELECT {', '.join(cols)} FROM {view}").fetchall()


CCOLS = ["community", "regime_band", "n_ungrazed_zones", "n_grazed_zones",
         "ungrazed_px", "grazed_px", "ungrazed_veg_p05", "grazed_veg_p05",
         "veg_p05_delta", "ungrazed_flood_freq", "grazed_flood_freq",
         "flood_freq_delta", "min_cell_n", "support_level", "aggregation_unit"]
RCOLS = ["community", "regime_band", "n_ungrazed_bala", "n_grazed_bala",
         "veg_p05_delta_bala_pxwtd", "veg_p05_delta_zonesupport",
         "flood_freq_delta_bala", "ungrazed_p05_min", "ungrazed_p05_max"]


def main(mode: str) -> None:
    if mode != "execute":
        raise SystemExit("use: execute")
    con = sqlite3.connect(DB.as_posix())
    try:
        for v in ("v_zone_stratum_treatment_contrast", "v_zone_stratum_contrast_bala_robust"):
            con.execute(f"DROP VIEW IF EXISTS {v}")
        con.execute(CONTRAST_VIEW)
        con.execute(ROBUST_VIEW)
        con.execute("INSERT OR REPLACE INTO workflow_run "
                    "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
                    "VALUES (?,?,?,?,0,'REVIEW')",
                    (RUN_ID, "2026-07-27T00:00:00+00:00",
                     "scripts/11_database/build_T1_gateD_contrast.py", '{"gate": "D"}'))
        con.commit()

        crows = dump(con, "v_zone_stratum_treatment_contrast", CCOLS)
        rrows = dump(con, "v_zone_stratum_contrast_bala_robust", RCOLS)
        for path, hdr, rows in [(OUT_CSV, CCOLS, crows), (ROBUST_CSV, RCOLS, rrows)]:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f); w.writerow(hdr); w.writerows(rows)

        print(f"v_zone_stratum_treatment_contrast: {len(crows)} rows (all-zones, pixel-weighted)")
        print("  community/band       nU nG  p05d   ffd  min_cell_n")
        for r in crows:
            print(f"  {r[0].split()[0]:8}/{r[1]:4}  {r[2]:2} {r[3]:2}  {r[8]:+6.2f} {r[11]:+6.2f}  {r[12]}")
        print(f"\nv_zone_stratum_contrast_bala_robust: {len(rrows)} rows (Bala-only, 4 vs <=22)")
        print("  community/band       nUb nGb  (a)Bala-px p05d  (b)zone-supp p05d  ungrazed p05 range")
        for r in rrows:
            a = f"{r[4]:+6.2f}" if r[4] is not None else "   n/a"
            b = f"{r[5]:+6.2f}" if r[5] is not None else "   n/a"
            rng = f"{r[7]}-{r[8]}" if r[7] is not None else "n/a"
            print(f"  {r[0].split()[0]:8}/{r[1]:4}  {str(r[2]):>3} {str(r[3]):>3}      {a}           {b}          {rng}")
        print(f"\nwrote {OUT_CSV.relative_to(ROOT).as_posix()} and {ROBUST_CSV.relative_to(ROOT).as_posix()}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "execute")
