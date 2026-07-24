#!/usr/bin/env python3
"""Tier 2 · Task M · Gate D §D.2 — dual-grid distribution of the floor variable veg_p05.

D.2's JOB HAS CHANGED. Rule 8's committed script
(scripts/05_ground_cover/04_taskM_green_at_floor_area.R ->
Output/tables/taskM_green_at_floor_area.csv) is now the authoritative source for the
majority-green-floor HECTARE figure. This table does NOT settle that number and does not
restate it. It reports the veg_p05 DISTRIBUTION on both grids so the two answers sit side
by side and any discrepancy is visible rather than inferred.

  veg_p05 = 5th-percentile total cover per pixel (across-series, 1988-2023). This is
  TOTAL COVER AT THE FLOOR, a different variable from the green-share measure that Rule 8's
  script counts. The two must never be conflated (see docs/Gayini_established_data_facts.md
  §9, D8 corrected 2026-07-24).

One stats engine (duckdb) over two sources, so the columns are computed identically:
  Grid 1  census 24.97 m : Output/census/gayini_pixel_census_8058.parquet
          focus = treed_context_flag=false AND the three focus communities AND veg_p05 non-null
  Grid 2  native 30 m    : Output/tables/taskM_gateD_native30m_p05_cells.csv
          (per-focus-cell extract from total_veg_percentiles_3577.tif, focus mask carried
           nearest-neighbour; produced by 05_taskM_gateD_native30m_p05_extract.R)

Output (identical content, two homes; the Output/ copy is authoritative per the standing rule):
  Output/tables/taskM_gateD_veg_p05_distribution.csv
  docs/change_reports/taskM_gateD_veg_p05_distribution.csv

Report only. No threshold is named as meaningful, and no spatial pattern is labelled.
"""
from __future__ import annotations

import csv
import shutil
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[2]
PARQUET = ROOT / "Output" / "census" / "gayini_pixel_census_8058.parquet"
NATIVE = ROOT / "Output" / "tables" / "taskM_gateD_native30m_p05_cells.csv"
OUT_MAIN = ROOT / "Output" / "tables" / "taskM_gateD_veg_p05_distribution.csv"
OUT_DOCS = ROOT / "docs" / "change_reports" / "taskM_gateD_veg_p05_distribution.csv"

FOCUS = ("Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
         "Inland Floodplain Shrublands / Swamps")
THRESHOLDS = [40, 45, 50, 55, 60, 65, 70, 75, 80, 85]

STAT_COLS = ["min", "p05", "p10", "p25", "p50", "p75", "p90", "p95", "max", "mean", "sd"]
FIELDS = (["grid", "pixel_area_ha", "crs_epsg", "source_artefact", "section", "group_key", "n"]
          + STAT_COLS + ["threshold", "area_ha", "pct_of_focus"])

GRIDS = {
    "census_24_97m": dict(
        pixel_area_ha=0.0623512, crs_epsg=8058,
        source_artefact="Output/census/gayini_pixel_census_8058.parquet",
        relation=f"""
            SELECT veg_p05, community, flood_zone
            FROM read_parquet('{PARQUET.as_posix()}')
            WHERE treed_context_flag = FALSE
              AND community IN {FOCUS}
              AND veg_p05 IS NOT NULL
              AND isfinite(veg_p05)
        """),
    "native_30m": dict(
        pixel_area_ha=0.09, crs_epsg=3577,
        source_artefact=("Output/tables/taskM_gateD_native30m_p05_cells.csv "
                         "<- Output/rasters/fc_intermediate/total_veg_percentiles_3577.tif "
                         "(focus mask carried NN from veg_regime_class_8058.tif)"),
        relation=f"""
            SELECT veg_p05, community, flood_zone
            FROM read_csv_auto('{NATIVE.as_posix()}')
            WHERE veg_p05 IS NOT NULL AND isfinite(veg_p05)
        """),
}

STAT_SQL = (
    "min(veg_p05) min, quantile_cont(veg_p05,0.05) p05, quantile_cont(veg_p05,0.10) p10, "
    "quantile_cont(veg_p05,0.25) p25, quantile_cont(veg_p05,0.50) p50, "
    "quantile_cont(veg_p05,0.75) p75, quantile_cont(veg_p05,0.90) p90, "
    "quantile_cont(veg_p05,0.95) p95, max(veg_p05) max, avg(veg_p05) mean, "
    "stddev_samp(veg_p05) sd"
)


def r(v, nd=4):
    return "" if v is None else round(float(v), nd)


def main() -> None:
    if not NATIVE.is_file():
        raise SystemExit("ABORT: run scripts/05_ground_cover/"
                         "05_taskM_gateD_native30m_p05_extract.R first.")
    con = duckdb.connect()
    rows = []

    for grid, cfg in GRIDS.items():
        con.execute(f"CREATE OR REPLACE TEMP VIEW src AS {cfg['relation']}")
        base = dict(grid=grid, pixel_area_ha=cfg["pixel_area_ha"], crs_epsg=cfg["crs_epsg"],
                    source_artefact=cfg["source_artefact"])
        area = cfg["pixel_area_ha"]
        n_focus = con.execute("SELECT count(*) FROM src").fetchone()[0]

        # overall
        s = con.execute(f"SELECT count(*), {STAT_SQL} FROM src").fetchone()
        rows.append({**base, "section": "overall", "group_key": "", "n": s[0],
                     **{c: r(v) for c, v in zip(STAT_COLS, s[1:])},
                     "threshold": "", "area_ha": r(s[0] * area, 2), "pct_of_focus": 100.0})

        # by community
        for community in FOCUS:
            s = con.execute(f"SELECT count(*), {STAT_SQL} FROM src WHERE community = ?",
                            [community]).fetchone()
            rows.append({**base, "section": "by_community", "group_key": community, "n": s[0],
                         **{c: r(v) for c, v in zip(STAT_COLS, s[1:])},
                         "threshold": "", "area_ha": r(s[0] * area, 2),
                         "pct_of_focus": r(100 * s[0] / n_focus, 3)})

        # by flood_zone 0..4
        for zone in range(5):
            s = con.execute(f"SELECT count(*), {STAT_SQL} FROM src WHERE flood_zone = ?",
                            [zone]).fetchone()
            if not s[0]:
                continue
            rows.append({**base, "section": "by_flood_zone", "group_key": str(zone), "n": s[0],
                         **{c: r(v) for c, v in zip(STAT_COLS, s[1:])},
                         "threshold": "", "area_ha": r(s[0] * area, 2),
                         "pct_of_focus": r(100 * s[0] / n_focus, 3)})

        # cumulative area for veg_p05 >= threshold
        for t in THRESHOLDS:
            n_ge = con.execute("SELECT count(*) FROM src WHERE veg_p05 >= ?", [t]).fetchone()[0]
            rows.append({**base, "section": "cumulative_area", "group_key": "",
                         "n": n_ge, **{c: "" for c in STAT_COLS},
                         "threshold": t, "area_ha": r(n_ge * area, 2),
                         "pct_of_focus": r(100 * n_ge / n_focus, 3)})

    OUT_MAIN.parent.mkdir(parents=True, exist_ok=True)
    with OUT_MAIN.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in FIELDS})
    OUT_DOCS.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(OUT_MAIN, OUT_DOCS)

    print(f"rows: {len(rows)}")
    print(f"wrote {OUT_MAIN.relative_to(ROOT).as_posix()}")
    print(f"copied to {OUT_DOCS.relative_to(ROOT).as_posix()} (Output/ copy is authoritative)")

    # Console comparison block for the gate report - thresholds side by side.
    print("\nthreshold | census_24_97m ha | native_30m ha | ratio(native/census)")
    cen = {rr["threshold"]: rr for rr in rows
           if rr["grid"] == "census_24_97m" and rr["section"] == "cumulative_area"}
    nat = {rr["threshold"]: rr for rr in rows
           if rr["grid"] == "native_30m" and rr["section"] == "cumulative_area"}
    for t in THRESHOLDS:
        ca, na = float(cen[t]["area_ha"]), float(nat[t]["area_ha"])
        ratio = na / ca if ca else float("nan")
        print(f"   {t:>3}    | {ca:>14,.2f} | {na:>12,.2f} | {ratio:.4f}")


if __name__ == "__main__":
    main()
