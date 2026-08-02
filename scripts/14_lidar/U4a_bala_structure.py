#!/usr/bin/env python3
"""Task U · U-Q4a — structure at the four Bala reference paddocks.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U4 U-Q4a, reframed by
amendment 1 August 2026.

THE QUESTION, as reframed: **is Bala 29ca's hydrological isolation natural or
engineered?** Not "structural or hydrological" - those are not separable here,
because dryness on this property can be manufactured.

TWO CONSTRAINTS FROM EARLIER GATES, both binding:

1. NO CHANGE STATISTIC. Gate U3 found the change-detection floor on vegetated
   ground is 9.7 FPC pp at 500 m grain against an observed 0.257 pp, and that height
   change is not separable from drought recovery. So every epoch is reported
   SEPARATELY and nothing is differenced. Gate U3 §7 also measured why: on treed
   stable ground the difference-of-medians is +1.42 m while the median-of-differences
   is +0.158 m, so the epochs are not cleanly comparable pixel-by-pixel in complex
   canopy at 5 m. ZONAL MEDIANS PER EPOCH, never a per-pixel difference.

2. L-01. A management zone is not an ecological unit, and Bala 29ca is the extreme
   case (Inland 35% / Riverine 33% / Aeolian 32%). Every statistic is reported
   DECOMPOSED BY COMMUNITY. A whole-of-paddock median would average across
   communities whose structure differs and would describe no real place.

Per-zone LiDAR coverage fraction is reported alongside every statistic (spec): a
paddock at 60% coverage is not comparable to one at 100%.

Reads the registered Gate U1 outputs. Writes CSVs; the figure is R.

Usage:  python scripts/14_lidar/U4a_bala_structure.py
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from rasterio.features import rasterize
from rasterio.warp import Resampling as WR
from rasterio.warp import reproject
from shapely import wkb

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TU = ROOT / "Output" / "rasters" / "task_U"
OUT_T = ROOT / "Output" / "tables"
ZONES_GPKG = ROOT / "Output" / "spatial_8058" / "management_zones_epsg8058.gpkg"
CLS = ROOT / "Output" / "rasters" / "veg_regime_class_8058.tif"

COMMUNITY = {1: "Aeolian Chenopod Shrublands", 2: "Riverine Chenopod Shrublands",
             3: "Inland Floodplain Shrublands / Swamps"}
REF_ZONES = ["Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca"]
MIN_PART_PX = 200            # below this a part is reported but not interpreted

PRODUCTS = [("bbh_fpc", "taskU_bbh_fpc_{e}_8058_10m.tif", "percent", "uint8"),
            ("bbd_p95_height", "taskU_bbd_p95_height_{e}_8058_5m.tif", "metres", "f32"),
            ("bbb_p50_height", "taskU_bbb_p50_height_{e}_8058_5m.tif", "metres", "f32")]


def _gpkg_geom(blob: bytes):
    env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]
    return wkb.loads(blob[8 + env:])


def zone_geoms():
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    names = {r[0]: r[1] for r in con.execute(
        "SELECT zone_fid, zone_name FROM dim_management_zone")}
    treat = {r[0]: r[1] for r in con.execute(
        "SELECT zone_fid, grazing_treatment FROM dim_management_zone")}
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
    return [(int(f), names.get(int(f), f"fid_{f}"), treat.get(int(f), "unknown"),
             _gpkg_geom(b)) for f, b in rows]


def onto(path, tr, shape, crs, method, dtype, nodata):
    out = np.full(shape, nodata, dtype=dtype)
    with rasterio.open(path) as s:
        reproject(source=rasterio.band(s, 1), destination=out, src_transform=s.transform,
                  src_crs=s.crs, src_nodata=s.nodata, dst_transform=tr, dst_crs=crs,
                  dst_nodata=nodata, resampling=method)
    return out


def main() -> None:
    OUT_T.mkdir(parents=True, exist_ok=True)
    zones = zone_geoms()
    print("=" * 78)
    print("U-Q4a - structure at the four Bala reference paddocks")
    print("=" * 78)
    print("Every epoch reported SEPARATELY - Gate U3 permits no change statistic.")
    print("Every statistic DECOMPOSED BY COMMUNITY - L-01.")
    print(f"{len(zones)} management zones\n")

    rows = []
    for pname, tmpl, units, kind in PRODUCTS:
        with rasterio.open(TU / tmpl.format(e="2009")) as s:
            tr, shape, crs = s.transform, (s.height, s.width), s.crs
            res = s.res[0]
        px_ha = res * res / 1e4

        zr = rasterize([(g, f) for f, _, _, g in zones], out_shape=shape, transform=tr,
                       fill=0, dtype="int32")
        cl = onto(CLS, tr, shape, crs, WR.nearest, "uint8", 255)
        comm = np.where((cl >= 11) & (cl <= 33), cl // 10, 0).astype("uint8")

        arr = {}
        for e in ("2009", "2021"):
            with rasterio.open(TU / tmpl.format(e=e)) as s:
                a = s.read(1)
                arr[e] = (a.astype("float32") if kind == "f32"
                          else np.where(a == 255, np.nan, a).astype("float32"))
        print(f"--- {pname} ({units}, {res:g} m) ---")

        for fid, zname, treat, _ in zones:
            zm = zr == fid
            if not zm.any():
                continue
            for code, cname in COMMUNITY.items():
                part = zm & (comm == code)
                n_part = int(part.sum())
                if n_part == 0:
                    continue
                rec = dict(product=pname, units=units, resolution_m=res,
                           zone_fid=fid, zone_name=zname, grazing_treatment=treat,
                           community=cname, is_reference=int(zname in REF_ZONES),
                           part_pixels=n_part, part_area_ha=round(n_part * px_ha, 3))
                for e in ("2009", "2021"):
                    v = arr[e][part]
                    v = v[np.isfinite(v)]
                    cov = v.size / n_part if n_part else 0.0
                    rec[f"coverage_frac_{e}"] = round(cov, 5)
                    rec[f"median_{e}"] = round(float(np.median(v)), 4) if v.size else ""
                    rec[f"p75_{e}"] = round(float(np.percentile(v, 75)), 4) if v.size else ""
                    rec[f"p90_{e}"] = round(float(np.percentile(v, 90)), 4) if v.size else ""
                    rec[f"mean_{e}"] = round(float(v.mean()), 4) if v.size else ""
                    rec[f"n_valid_{e}"] = int(v.size)
                rec["note"] = ("below MIN_PART_PX - reported, not interpreted"
                               if n_part < MIN_PART_PX else "")
                rows.append(rec)

        # ---- reference paddocks against the grazed distribution, per community
        for code, cname in COMMUNITY.items():
            sub = [r for r in rows if r["product"] == pname and r["community"] == cname
                   and r["part_pixels"] >= MIN_PART_PX]
            if not sub:
                continue
            print(f"  {cname[:34]:<36}", end="")
            for e in ("2009", "2021"):
                gz = [r[f"median_{e}"] for r in sub
                      if not r["is_reference"] and r[f"median_{e}"] != ""]
                if gz:
                    q = np.percentile(gz, [25, 50, 75])
                    print(f"  {e} grazed med {q[1]:6.2f} [{q[0]:.2f},{q[2]:.2f}] n={len(gz):>2}",
                          end="")
            print()
            for z in REF_ZONES:
                m = [r for r in sub if r["zone_name"] == z]
                if not m:
                    continue
                r0 = m[0]
                print(f"      {z:<12}", end="")
                for e in ("2009", "2021"):
                    gz = [r[f"median_{e}"] for r in sub
                          if not r["is_reference"] and r[f"median_{e}"] != ""]
                    val = r0[f"median_{e}"]
                    if val == "" or not gz:
                        print(f"  {e}      n/a                      ", end="")
                        continue
                    pct = 100.0 * sum(1 for g in gz if g < val) / len(gz)
                    print(f"  {e} {val:7.2f} (pctile {pct:5.1f}, cov "
                          f"{100 * r0[f'coverage_frac_{e}']:5.1f}%)", end="")
                print(f"   n={r0['part_pixels']:,}")
        print()

    with (OUT_T / "taskU_gateU4a_zonal_structure.csv").open("w", newline="",
                                                            encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"written: {(OUT_T / 'taskU_gateU4a_zonal_structure.csv').relative_to(ROOT)} "
          f"({len(rows)} rows)")


if __name__ == "__main__":
    main()
