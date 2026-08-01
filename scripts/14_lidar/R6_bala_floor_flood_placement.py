#!/usr/bin/env python3
"""Task U · R6 — floor-versus-flood placement of the four Bala reference paddocks.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, rule R6 (added by amendment
1 August 2026, design-seat Gate U2 response §1a). **Pre-registered before any value
was computed. Run BEFORE U-Q4a.**

THE POINT. The spine already says flood frequency sets the drought floor, and that
p05 rises ~2.2x faster than p50 across the gradient. Bala 29ca floods at roughly one
fifth its neighbours' rate. A low floor there is therefore what the spine PREDICTS -
so the reference-state anomaly may be an ordinary instance of the project's own
published result rather than a rival hypothesis to clearing.

  29ca ON the curve   -> dryness accounts for the deficit; no anomaly left to explain
  29ca BELOW the curve -> the residual is real, and THE RESIDUAL - not the raw 42 pp
                          gap - is what the LiDAR structure test should be aimed at

THE VARIABLE TRAP, stated because R6 exists partly to avoid it. The Gate U2 Bala
table is ANNUAL WET FRACTION IN A SINGLE WATER YEAR. This script uses the CENSUS
LONG-RUN FLOOD FREQUENCY over 35 years: 100 * sum(wet) / sum(valid) per pixel, the
project's headline metric at pixel support. Different variables, different scales,
never substituted for one another.

L-01 IS HONOURED BY CONSTRUCTION. A management zone is not an ecological unit, and
Bala 29ca is the extreme case (Inland 35% / Riverine 33% / Aeolian 32%). The fit is
WITHIN COMMUNITY and every paddock is decomposed into its community parts before any
residual is computed. A whole-of-paddock residual would average across communities
whose floors differ by tens of points and would describe no real place.

PRE-REGISTERED AND NOT NEGOTIABLE AFTER SEEING THE RESIDUALS:
  - the fit is OLS of veg_p05 on long-run flood frequency, within community, at pixel
    support, over ALL non-treed census pixels;
  - no paddock is excluded from the fit on the basis of its residual;
  - the fit is not re-specified after the residuals are seen;
  - the fit's own scatter is reported so a residual can be read against it;
  - every residual is reported, whatever its sign.

NO CHANGE TO THE REFERENCE SET IS MADE HERE. Dropping 29ca would raise the reference
floor and narrow the reference-versus-grazed gap - a convergence-favourable move made
after seeing the data. If the residuals suggest one, it returns to the design seat.

Usage:  python scripts/14_lidar/R6_bala_floor_flood_placement.py
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from rasterio.features import rasterize

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT_T = ROOT / "Output" / "tables"
ZONES_GPKG = ROOT / "Output" / "spatial_8058" / "management_zones_epsg8058.gpkg"

CLS = ROOT / "Output" / "rasters" / "veg_regime_class_8058.tif"
VEG_P05 = ROOT / "Output" / "rasters" / "veg_percentiles_8058" / "total_veg_p05_8058.tif"
WET = ROOT / "Output" / "rasters" / "inundation_annual_stack_8058" / \
    "annual_wet_any_1988_2023_8058.tif"
VALID = ROOT / "Output" / "rasters" / "inundation_annual_stack_8058" / \
    "annual_valid_any_1988_2023_8058.tif"

# veg_regime_class encodes community x regime band. 11-13 Aeolian, 21-23 Riverine,
# 31-33 Inland; 40 Floodplain Woodland/Forest (treed context), 50 Other/minor units.
COMMUNITY = {1: "Aeolian Chenopod Shrublands", 2: "Riverine Chenopod Shrublands",
             3: "Inland Floodplain Shrublands / Swamps"}
REF_ZONES = ["Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca"]
MIN_VALID_YEARS = 25          # the census convention, distinct from MIN_SEASONS = 50
MIN_PART_PX = 100             # a paddock-community part below this is reported, not fitted


def _gpkg_geom(blob: bytes):
    from shapely import wkb
    env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]
    return wkb.loads(blob[8 + env:])


def read_zones():
    """Zone polygons from the registered EPSG:8058 layer, with their names."""
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    names = {r[0]: r[1] for r in con.execute(
        "SELECT zone_fid, zone_name FROM dim_management_zone")}
    con.close()
    g = sqlite3.connect(f"file:{ZONES_GPKG.as_posix()}?mode=ro", uri=True)
    tbl, gcol, srs = g.execute("SELECT table_name, column_name, srs_id "
                               "FROM gpkg_geometry_columns LIMIT 1").fetchone()
    if int(srs) != 8058:
        raise SystemExit(f"ABORT: zones are EPSG:{srs}, not 8058")
    cols = [r[1] for r in g.execute(f'PRAGMA table_info("{tbl}")')]
    fidcol = next(c for c in cols if c.lower() in ("fid", "objectid_1", "zone_fid"))
    rows = list(g.execute(f'SELECT "{fidcol}", "{gcol}" FROM "{tbl}"'))
    g.close()
    return [(int(f), names.get(int(f), f"fid_{f}"), _gpkg_geom(b)) for f, b in rows], names


def main() -> None:
    OUT_T.mkdir(parents=True, exist_ok=True)
    print("=" * 78)
    print("R6 - floor vs long-run flood frequency, within community, pixel support")
    print("=" * 78)
    print("Variable: CENSUS LONG-RUN FLOOD FREQUENCY = 100 * sum(wet) / sum(valid)")
    print("over 35 water years. NOT the Gate U2 single-year annual wet fraction.\n")

    with rasterio.open(CLS) as s:
        cls = s.read(1)
        tr, shape, crs = s.transform, (s.height, s.width), s.crs
    with rasterio.open(VEG_P05) as s:
        p05 = s.read(1)
    with rasterio.open(WET) as s:
        wet = s.read()
        wnod = s.nodata
    with rasterio.open(VALID) as s:
        val = s.read()
        vnod = s.nodata

    wet_n = (wet == 1).sum(axis=0).astype("float32")
    val_n = np.where(val == vnod, 0, val == 1).sum(axis=0).astype("float32")
    with np.errstate(invalid="ignore", divide="ignore"):
        flood = np.where(val_n >= MIN_VALID_YEARS, 100.0 * wet_n / val_n, np.nan)
    del wet, val, wet_n

    # non-treed scope: treed_context_flag = 0 AND regime_band <> 'context'
    # (codes 11-33 only; 40 is treed context, 50 is Other/minor units)
    comm_code = np.where((cls >= 11) & (cls <= 33), cls // 10, 0).astype("uint8")
    ok = (comm_code > 0) & np.isfinite(p05) & np.isfinite(flood)
    print(f"non-treed census pixels with both variables: {ok.sum():,}")

    zones, _ = read_zones()
    zr = rasterize([(g, f) for f, _, g in zones], out_shape=shape, transform=tr,
                   fill=0, dtype="int32")

    # ------------------------------------------------------- the within-community fits
    fits, rows = {}, []
    print(f"\n{'community':<40}{'n px':>12}{'slope':>9}{'intercept':>11}"
          f"{'r':>8}{'resid SD':>10}")
    print("-" * 78)
    for code, name in COMMUNITY.items():
        m = ok & (comm_code == code)
        x, y = flood[m].astype("float64"), p05[m].astype("float64")
        slope, intercept = np.polyfit(x, y, 1)
        pred = slope * x + intercept
        resid_sd = float(np.std(y - pred, ddof=2))
        r = float(np.corrcoef(x, y)[0, 1])
        fits[code] = (slope, intercept, resid_sd, int(x.size), r)
        print(f"{name:<40}{x.size:>12,}{slope:>9.4f}{intercept:>11.4f}"
              f"{r:>8.4f}{resid_sd:>10.4f}")
        rows.append(dict(kind="fit", community=name, zone_name="", n_pixels=int(x.size),
                         mean_flood_freq_pct=round(float(x.mean()), 4),
                         mean_veg_p05=round(float(y.mean()), 4),
                         slope=round(float(slope), 6), intercept=round(float(intercept), 6),
                         pearson_r=round(r, 6), fit_residual_sd=round(resid_sd, 4),
                         predicted_veg_p05="", residual_veg_p05="",
                         residual_in_sd="", note="within-community OLS, pixel support, "
                                                 "all non-treed census pixels"))

    # ------------------------------------- place every paddock-community part on its fit
    print(f"\n{'paddock':<12}{'community':<30}{'n px':>9}{'flood%':>9}"
          f"{'obs p05':>9}{'pred p05':>10}{'resid':>9}{'resid/SD':>10}")
    print("-" * 78)
    for fid, zname, _ in zones:
        for code, cname in COMMUNITY.items():
            m = ok & (zr == fid) & (comm_code == code)
            n = int(m.sum())
            if n == 0:
                continue
            xf = float(flood[m].mean())
            yo = float(p05[m].mean())
            slope, intercept, sd, nfit, _ = fits[code]
            pred = slope * xf + intercept
            resid = yo - pred
            rows.append(dict(kind="paddock_part", community=cname, zone_name=zname,
                             n_pixels=n, mean_flood_freq_pct=round(xf, 4),
                             mean_veg_p05=round(yo, 4), slope=round(slope, 6),
                             intercept=round(intercept, 6), pearson_r="",
                             fit_residual_sd=round(sd, 4),
                             predicted_veg_p05=round(pred, 4),
                             residual_veg_p05=round(resid, 4),
                             residual_in_sd=round(resid / sd, 4),
                             note=("below MIN_PART_PX - reported, not interpreted"
                                   if n < MIN_PART_PX else "")))
            if zname in REF_ZONES:
                flag = "  *small n*" if n < MIN_PART_PX else ""
                print(f"{zname:<12}{cname[:28]:<30}{n:>9,}{xf:>9.2f}{yo:>9.2f}"
                      f"{pred:>10.2f}{resid:>+9.2f}{resid / sd:>+10.2f}{flag}")

    with (OUT_T / "taskU_R6_bala_floor_flood_placement.csv").open(
            "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    # ----------------------------------------- where the reference paddocks sit overall
    print(f"\n--- reference paddocks against the grazed distribution of residuals ---")
    parts = [r for r in rows if r["kind"] == "paddock_part"
             and r["n_pixels"] >= MIN_PART_PX]
    print(f"{'community':<30}{'grazed resid':>26}   reference paddock residuals")
    print("-" * 78)
    for code, cname in COMMUNITY.items():
        gz = [r["residual_veg_p05"] for r in parts
              if r["community"] == cname and r["zone_name"] not in REF_ZONES]
        if not gz:
            continue
        q = np.percentile(gz, [5, 50, 95])
        refs = {r["zone_name"]: r["residual_veg_p05"] for r in parts
                if r["community"] == cname and r["zone_name"] in REF_ZONES}
        s = "  ".join(f"{k.replace('Bala ', '')}={v:+.1f}" for k, v in sorted(refs.items()))
        print(f"{cname[:28]:<30}n={len(gz):>3} p05/med/p95 "
              f"{q[0]:+.1f}/{q[1]:+.1f}/{q[2]:+.1f}   {s}")

    print(f"\nwritten: {(OUT_T / 'taskU_R6_bala_floor_flood_placement.csv').relative_to(ROOT)} "
          f"({len(rows)} rows)")
    print("\nNO CHANGE TO THE REFERENCE SET IS MADE HERE (spec R6 / Gate U2 response §2).")


if __name__ == "__main__":
    main()
