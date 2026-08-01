#!/usr/bin/env python3
"""Task U · Gate U2 — place the two LiDAR epochs in the 35-year Landsat record.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U2.

NO NEW DATA. Every number is queried from Gayini_Results.sqlite. Read-only against
the database; writes three CSVs and nothing else.

THE FIGURE IS BUILT IN R, not here. matplotlib is not installed in this environment
and installing it would introduce a second figure stack; the project's is R+ggplot2,
and `gayini_write_and_register_figure()` writes and registers in ONE transaction,
which is the rule that stopped figures landing on disk unregistered. This script
emits the tidy series CSV that `U2_epoch_context_figure.R` renders.

WHY THIS GATE EXISTS (trap T-3): 2009 sits at the end of the Millennium Drought and
2021 follows the 2016 and 2020-21 floods. A woody gain between them may be drought
recovery rather than land-use change. Every later interpretation of change is
conditioned on this table.

THE FLIGHT-MONTH PROBLEM IS A WATER-YEAR PROBLEM.
Gate U0.6 established that flight months are unrecoverable from the delivery. The
project's water year starts in JULY (dim_time.water_year_start), so a calendar-2009
capture falls in WY2008 if flown Jan-Jun and WY2009 if flown Jul-Dec. The same holds
at 2021. Each epoch therefore has TWO candidate water years and this script reports
BOTH for every metric, so the reader can see whether a conclusion survives the
ambiguity. Collapsing to one water year would invent a fact the delivery does not
carry.

METRIC DISCIPLINE:
  - `veg_p05_spatial` is the WITHIN-UNIT, WITHIN-YEAR spatial 5th percentile. It is
    NOT the census temporal `veg_p05`. Two p05 objects exist and must never be called
    by the same name (CLAUDE.md).
  - Flood frequency here is the per-community annual wet fraction from
    fact_community_year_flood, PIXEL support. Never compare with plot support.
  - series_variant = mean_of_seasons throughout (the T8 PIN 2 convention).

Usage:  python scripts/14_lidar/U2_epoch_context.py
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT_T = ROOT / "Output" / "tables"

VARIANT = "mean_of_seasons"
GAUGE = "410040"          # Murrumbidgee at Downstream Maude Weir - local_upstream
REF_ZONES = ["Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca"]

# Each capture year maps to two candidate water years because the flight month is
# unknown and the water year starts in July.
EPOCH_CANDIDATES = {2009: [2008, 2009], 2021: [2020, 2021]}


def q(con, sql, params=()):
    cur = con.execute(sql, params)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def classify(value, dist) -> tuple[str, float]:
    """Tercile label plus percentile rank against the full 35-year distribution."""
    d = np.asarray([x for x in dist if x is not None], dtype="float64")
    lo, hi = np.percentile(d, [100 / 3, 200 / 3])
    label = "low" if value < lo else ("high" if value > hi else "typical")
    rank = 100.0 * float((d < value).sum()) / (d.size - 1)
    return label, round(rank, 1)


def main() -> None:
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    OUT_T.mkdir(parents=True, exist_ok=True)

    print("=" * 78)
    print("Gate U2 - the two LiDAR epochs against the 35-year Landsat record")
    print("=" * 78)
    print("Water year starts in JULY (dim_time). Flight months are unrecoverable")
    print("(Gate U0.6), so each capture year has TWO candidate water years. Both are")
    print("reported for every metric; neither is collapsed away.\n")

    # ---------------------------------------------------------------- flood
    flood = q(con, "SELECT community, water_year, flood_frac_pct, flood_class, "
                   "support_level FROM fact_community_year_flood ORDER BY community, water_year")
    communities = sorted({r["community"] for r in flood})
    fseries = {c: {r["water_year"]: r["flood_frac_pct"] for r in flood if r["community"] == c}
               for c in communities}
    years = sorted(fseries[communities[0]])

    # ------------------------------------------------------------------ veg
    # aggregation_order: within-zone spatial percentile FIRST, then pixel-weighted
    # mean across zones. Stated because a weighted mean of per-zone p05s is NOT the
    # farm p05, and the two must not be confused.
    zveg = q(con, "SELECT water_year, zone_name, n_pixels_valid, veg_p05_spatial, "
                  "veg_median, flood_frac_pct FROM v_zone_veg_annual "
                  "WHERE series_variant = ? ORDER BY water_year", (VARIANT,))
    farm = {}
    for y in years:
        rows = [r for r in zveg if r["water_year"] == y
                and r["veg_p05_spatial"] is not None and r["n_pixels_valid"]]
        w = np.array([r["n_pixels_valid"] for r in rows], dtype="float64")
        farm[y] = dict(
            veg_p05_spatial=float(np.average([r["veg_p05_spatial"] for r in rows], weights=w)),
            veg_median=float(np.average([r["veg_median"] for r in rows], weights=w)),
            n_zones=len(rows))

    cveg = q(con, "SELECT community, water_year, SUM(n_pixels_valid) AS npx, "
                  "SUM(veg_p05_spatial * n_pixels_valid) / SUM(n_pixels_valid) AS p05, "
                  "SUM(veg_mean * n_pixels_valid) / SUM(n_pixels_valid) AS vmean "
                  "FROM fact_zone_community_veg_annual WHERE series_variant = ? "
                  "AND n_pixels_valid > 0 GROUP BY community, water_year", (VARIANT,))
    cser = {c: {r["water_year"]: r for r in cveg if r["community"] == c} for c in communities}

    # ---------------------------------------------------------------- gauge
    gauge = q(con, "SELECT water_year, mean_value_numeric, quality_flag FROM "
                   "v_gauge_context_by_water_year WHERE station_id = ? "
                   "AND variable_code = 'mean_flow_mld' ORDER BY water_year", (GAUGE,))
    gser = {int(r["water_year"].split("-")[0]): r["mean_value_numeric"] for r in gauge}
    gyears = [y for y in years if y in gser]

    # ============================================================ main table
    rows = []

    def add(scope, unit, metric, wy, value, dist, units, note=""):
        if value is None:
            return
        label, rank = classify(value, dist)
        rows.append(dict(scope=scope, unit=unit, metric=metric, water_year=wy,
                         water_year_span=f"Jul {wy} - Jun {wy + 1}",
                         value=round(float(value), 4), units=units,
                         tercile_class=label, percentile_rank_35yr=rank,
                         n_years_in_distribution=len([x for x in dist if x is not None]),
                         note=note))

    for capture, cands in EPOCH_CANDIDATES.items():
        for wy in cands:
            tag = ("flown Jan-Jun" if wy == capture - 1 else "flown Jul-Dec") + \
                  f" {capture}; capture year {capture}"
            add("farm", "whole property (zoned)", "veg_p05_spatial", wy,
                farm[wy]["veg_p05_spatial"],
                [farm[y]["veg_p05_spatial"] for y in years], "percent", tag)
            add("farm", "whole property (zoned)", "veg_median", wy,
                farm[wy]["veg_median"], [farm[y]["veg_median"] for y in years], "percent", tag)
            if wy in gser:
                add("gauge", f"{GAUGE} Maude Weir (d/s)", "mean_flow_mld", wy, gser[wy],
                    [gser[y] for y in gyears], "ML/day", tag)
            for c in communities:
                add("community", c, "flood_frac_pct", wy, fseries[c].get(wy),
                    [fseries[c][y] for y in years], "percent",
                    tag + "; PIXEL support, never compare with plot support")
                if wy in cser[c]:
                    add("community", c, "veg_p05_spatial", wy, cser[c][wy]["p05"],
                        [cser[c][y]["p05"] for y in sorted(cser[c])], "percent", tag)

    with (OUT_T / "taskU_gateU2_epoch_context.csv").open("w", newline="",
                                                         encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # ------------------------------------------------------------- printout
    for capture, cands in EPOCH_CANDIDATES.items():
        print(f"--- {capture} capture -> candidate water years {cands} ---")
        print(f"{'metric':<34}{'unit':<38}" +
              "".join(f"WY{y}".rjust(19) for y in cands))
        print("-" * 78)
        seen = []
        for r in rows:
            if r["water_year"] not in cands:
                continue
            k = (r["metric"], r["unit"])
            if k in seen:
                continue
            seen.append(k)
            cells = ""
            for y in cands:
                m = [x for x in rows if x["water_year"] == y and x["metric"] == r["metric"]
                     and x["unit"] == r["unit"]]
                cells += (f"{m[0]['value']:>9.2f} {m[0]['tercile_class']:<8}" if m
                          else " " * 19)
            print(f"{r['metric']:<34}{r['unit'][:36]:<38}{cells}")
        print()

    # ================================================== Bala reference paddocks
    bala = []
    for z in REF_ZONES:
        s = {r["water_year"]: r for r in zveg if r["zone_name"] == z}
        for capture, cands in EPOCH_CANDIDATES.items():
            for wy in cands:
                if wy not in s:
                    continue
                for metric, key in (("veg_p05_spatial", "veg_p05_spatial"),
                                    ("veg_median", "veg_median"),
                                    ("flood_frac_pct", "flood_frac_pct")):
                    dist = [s[y][key] for y in sorted(s) if s[y][key] is not None]
                    if s[wy][key] is None:
                        continue
                    label, rank = classify(s[wy][key], dist)
                    bala.append(dict(zone_name=z, capture_year=capture, water_year=wy,
                                     metric=metric, value=round(float(s[wy][key]), 4),
                                     tercile_class=label, percentile_rank_35yr=rank,
                                     n_years_in_distribution=len(dist)))
    with (OUT_T / "taskU_gateU2_bala_reference.csv").open("w", newline="",
                                                          encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(bala[0].keys()))
        w.writeheader()
        w.writerows(bala)

    print("--- the four Bala reference paddocks (U-Q1 depends on these) ---")
    print(f"{'paddock':<12}{'metric':<18}" +
          "".join(f"WY{y}".rjust(16) for c in EPOCH_CANDIDATES for y in EPOCH_CANDIDATES[c]))
    print("-" * 78)
    allwy = [y for c in EPOCH_CANDIDATES for y in EPOCH_CANDIDATES[c]]
    for z in REF_ZONES:
        for metric in ("veg_p05_spatial", "flood_frac_pct"):
            cells = ""
            for y in allwy:
                m = [b for b in bala if b["zone_name"] == z and b["water_year"] == y
                     and b["metric"] == metric]
                cells += (f"{m[0]['value']:>7.1f} {m[0]['tercile_class']:<8}" if m else " " * 16)
            print(f"{z:<12}{metric:<18}{cells}")
        print()

    # ============================== tidy series for the R figure (long format)
    series = []
    for y in years:
        series.append(dict(water_year=y, panel="cover", series="veg_p05_spatial",
                           value=round(farm[y]["veg_p05_spatial"], 4)))
        series.append(dict(water_year=y, panel="cover", series="veg_median",
                           value=round(farm[y]["veg_median"], 4)))
        for c in communities:
            series.append(dict(water_year=y, panel="flood", series=c,
                               value=round(fseries[c][y], 4)))
    for y in gyears:
        series.append(dict(water_year=y, panel="flow", series=f"gauge {GAUGE}",
                           value=round(gser[y], 3)))
    with (OUT_T / "taskU_gateU2_series_35yr.csv").open("w", newline="",
                                                       encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["water_year", "panel", "series", "value"])
        w.writeheader()
        w.writerows(series)

    for p, n in ((OUT_T / "taskU_gateU2_epoch_context.csv", len(rows)),
                 (OUT_T / "taskU_gateU2_bala_reference.csv", len(bala)),
                 (OUT_T / "taskU_gateU2_series_35yr.csv", len(series))):
        print(f"written: {p.relative_to(ROOT)} ({n} rows)")
    print("\nfigure: run scripts/14_lidar/U2_epoch_context_figure.R "
          "(R owns write+register in one transaction)")
    con.close()


if __name__ == "__main__":
    main()
