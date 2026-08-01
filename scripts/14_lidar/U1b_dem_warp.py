#!/usr/bin/env python3
"""Task U · Gate U1 run B — warp the 50 cm DEM (`bb0`) to EPSG:8058.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U1 item 1.

Split from run A because `bb0` is 55 GiB of input across the three tiles and only
Gate U3 item 5 (the stable-ground vertical offset) and U-Q4c (the difference DEM
and the 2018 bank-cut check) need it. Run A carried every number the Gate U1 STOP
reports; this run produces no numbers and no interpretation.

STREAMED, NOT LOADED. A 50 cm float32 raster over the 859 km2 property is ~3.4e9
pixels = 13.7 GB per epoch, so the array cannot live in memory. Each source is
opened as a WarpedVRT and copied to the output block by block.

R1 applies at 50 cm exactly as at 5 m and 10 m: d4 takes precedence throughout the
seam, d5 fills only where d4 is absent, NEVER averaged.

T-1 note, restated because it bites hardest here: the GDA94 -> GDA2020 shift is
roughly 1.8 m, which is 0.18 of a 10 m pixel and tolerable for FPC but 3.6 of a
50 cm pixel and NOT tolerable for a difference DEM. That is precisely why both
epochs are warped into one frame rather than differenced in their delivered frames.
It does not remove the VERTICAL datum question, which is a separate risk and is
settled on stable ground at Gate U3 item 5 and nowhere else.

Usage:  python scripts/14_lidar/U1b_dem_warp.py
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from rasterio.crs import CRS
from rasterio.features import geometry_mask
from rasterio.vrt import WarpedVRT
from rasterio.warp import Resampling as WarpResampling
from rasterio.windows import Window
from shapely import wkb
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
LIDAR = ROOT / "Input" / "gayini_lidar"
OUT_R = ROOT / "Output" / "rasters" / "task_U"

CRS_CANONICAL = 8058
RES_M = 0.5
BLOCK = 4096                       # rows per streamed strip

SRC = {"2009": LIDAR / "Gayini_2009_GDA1994_z55" / "apl1dr_rgayini_2009_bb0m5_r50cm.tif",
       "2021_d4": LIDAR / "Gayini_2021_GDA2020_z54" / "apl4dr_rgayini_2021_bb0d4_r50cm.tif",
       "2021_d5": LIDAR / "Gayini_2021_GDA2020_z55" / "apl4dr_rgayini_2021_bb0d5_r50cm.tif"}


def _gpkg_geom(blob: bytes):
    env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]
    return wkb.loads(blob[8 + env:])


def boundary_8058():
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    path, = con.execute("SELECT path FROM spatial_layer_asset "
                        "WHERE layer_name='gayini_boundary_8058'").fetchone()
    con.close()
    p = Path(path)
    p = p if p.is_absolute() else ROOT / p
    g = sqlite3.connect(f"file:{p.as_posix()}?mode=ro", uri=True)
    tbl, gcol, _ = g.execute("SELECT table_name, column_name, srs_id "
                             "FROM gpkg_geometry_columns LIMIT 1").fetchone()
    blobs = [r[0] for r in g.execute(f'SELECT "{gcol}" FROM "{tbl}"')]
    g.close()
    return unary_union([_gpkg_geom(b) for b in blobs])


def main() -> None:
    boundary = boundary_8058()
    dst_crs = CRS.from_epsg(CRS_CANONICAL)
    xmin = np.floor(boundary.bounds[0] / RES_M) * RES_M
    ymin = np.floor(boundary.bounds[1] / RES_M) * RES_M
    xmax = np.ceil(boundary.bounds[2] / RES_M) * RES_M
    ymax = np.ceil(boundary.bounds[3] / RES_M) * RES_M
    width = int(round((xmax - xmin) / RES_M))
    height = int(round((ymax - ymin) / RES_M))
    transform = rasterio.transform.from_origin(xmin, ymax, RES_M, RES_M)
    print(f"target: {width} x {height} @ {RES_M} m EPSG:{CRS_CANONICAL} "
          f"({width * height / 1e9:.2f} Gpx per epoch)")

    profile = dict(driver="GTiff", width=width, height=height, count=1, dtype="float32",
                   crs=dst_crs, transform=transform, nodata=np.nan, compress="deflate",
                   predictor=3, tiled=True, blockxsize=512, blockysize=512,
                   BIGTIFF="YES", num_threads="ALL_CPUS")
    vrt_opts = dict(crs=dst_crs, transform=transform, width=width, height=height,
                    resampling=WarpResampling.bilinear, src_nodata=None, nodata=np.nan)

    OUT_R.mkdir(parents=True, exist_ok=True)
    for epoch, tiles in (("2009", ["2009"]), ("2021", ["2021_d4", "2021_d5"])):
        out = OUT_R / f"taskU_bb0_dem_{epoch}_8058_50cm.tif"
        print(f"\n{epoch}: {' + '.join(tiles)} -> {out.name}")
        srcs = [rasterio.open(SRC[t]) for t in tiles]
        vrts = [WarpedVRT(s, src_nodata=s.nodata, **{k: v for k, v in vrt_opts.items()
                                                     if k != "src_nodata"}) for s in srcs]
        try:
            with rasterio.open(out, "w", **profile) as dst:
                dst.update_tags(
                    stage_code="bb0", epoch=epoch, resampling="bilinear",
                    source_crs=("EPSG:28355" if epoch == "2009"
                                else "EPSG:7854 (d4) + EPSG:7855 (d5)"),
                    sensor="Leica ALS-50" if epoch == "2009" else "Leica ALS-80",
                    semantics=("JRSRP bb0 - raster DEM, natural-neighbour interpolation "
                               "of classified ground points, metres"),
                    mosaic_rule=("R1: d4 precedence, d5 fill, never averaged"
                                 if epoch == "2021" else "single tile"),
                    vertical_datum=("UNRESOLVED - open question to Adrian. NEVER interpret "
                                    "an absolute elevation difference; calibrate on stable "
                                    "ground at Gate U3 item 5."),
                    clip="gayini_boundary_8058")
                for r0 in range(0, height, BLOCK):
                    h = min(BLOCK, height - r0)
                    win = Window(0, r0, width, h)
                    a = vrts[0].read(1, window=win).astype("float32")
                    for v in vrts[1:]:                      # R1: fill only, never average
                        b = v.read(1, window=win).astype("float32")
                        gap = np.isnan(a)
                        a[gap] = b[gap]
                        del b
                    strip = geometry_mask(
                        [boundary], out_shape=(h, width),
                        transform=rasterio.windows.transform(win, transform), invert=True)
                    a[~strip] = np.nan
                    dst.write(a, 1, window=win)
                    del a, strip
                    if (r0 // BLOCK) % 20 == 0:
                        print(f"   row {r0:,} / {height:,} "
                              f"({100 * r0 / height:5.1f}%)", flush=True)
        finally:
            for v in vrts:
                v.close()
            for s in srcs:
                s.close()
        print(f"   done: {out.stat().st_size / 1024 ** 3:.2f} GiB")


if __name__ == "__main__":
    main()
