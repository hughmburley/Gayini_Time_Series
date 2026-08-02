#!/usr/bin/env python3
"""Task U · Gate U1 — common frame: warp, mosaic under R1, clip, denominators,
R2 screen, co-registration.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U1.

Run A (this script) covers everything the three questions need at 5 m and 10 m:
  bbh  FPC, 10 m                       - all three questions
  bb9/bba/bbb/bbc/bbd/bbe, 5 m         - the height ladder; bbd is R3's instrument
  bb5  first-return density, 50 cm     - warped to 5 m, for the R2 density diagnostic

Run B (U1b_dem_warp.py) covers bb0 at 50 cm, which only Gate U3 item 5 and U-Q4c
need and which is 55 GiB of input. Splitting keeps this STOP timely.

NOT warped, deliberately:
  bbi  hillshade      - serves no question (spec, The delivery)
  bb3/bb4             - `bb4` is a screening aid only; 2009's is single-valued
                        (D-U2) and d5's is quarantined (D-U3, R4)
  bbm  CSM            - secondary check only, carries D-U4; deferred with bb0

R1  d4 takes precedence throughout the seam; d5 fills only where d4 is absent.
    NEVER averaged. The seam is written out as a mask.
R2  50 m physical-plausibility height ceiling, applied identically at both epochs
    across the WHOLE height stack, exclusions counted and reported BEFORE use.
R4  d5 bb3/bb4 quarantined (not read); bbm deferred.

The height ladder is screened in TWO PASSES - pass 1 builds the exclusion masks by
streaming each stage and freeing it, pass 2 re-warps and writes. Holding all twelve
5 m stage arrays at once would need ~5 GB; two passes need three arrays. The extra
warping is cheap because the 5 m products are ~140 MB each.

Writes to Output/rasters/task_U/. Registers nothing - registration is the companion
registrar, run after this passes review.

Usage:  python scripts/14_lidar/U1_common_frame.py
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from rasterio.crs import CRS
from rasterio.features import geometry_mask
from rasterio.warp import Resampling as WarpResampling
from rasterio.warp import reproject, transform_bounds
from shapely import wkb
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
LIDAR = ROOT / "Input" / "gayini_lidar"
OUT_R = ROOT / "Output" / "rasters" / "task_U"
OUT_T = ROOT / "Output" / "tables"

CRS_CANONICAL = 8058
NODATA_U8 = 255
NAN = np.float32(np.nan)          # float nodata convention, as veg_duration_8058

# --- R2, pre-registered. Vegetation ecology, not the observed distribution. ---
HEIGHT_CEILING_M = 50.0
HEIGHT_CEILING_SENSITIVITY = (30.0, 50.0, 80.0)

# The height ladder common to BOTH epochs across ALL tiles. bb8 (1st percentile)
# exists in 2009 and d4 but NOT in d5, so including it would make the two epochs
# compositionally different - the one thing a change comparison must not be.
LADDER = {"bb9": "p05", "bba": "p25", "bbb": "p50", "bbc": "p75",
          "bbd": "p95", "bbe": "p99"}
LADDER_RES_M = 5.0
FPC_RES_M = 10.0

FOLDERS = {"2009": ("Gayini_2009_GDA1994_z55", "apl1dr_rgayini_2009", "m5"),
           "2021_d4": ("Gayini_2021_GDA2020_z54", "apl4dr_rgayini_2021", "d4"),
           "2021_d5": ("Gayini_2021_GDA2020_z55", "apl4dr_rgayini_2021", "d5")}
TILES_2021 = ["2021_d4", "2021_d5"]
RES_TAG = {5.0: "r500cm", 10.0: "r10m", 0.5: "r50cm"}

RESAMPLING_CALL = ("rasterio.warp.reproject(source=rasterio.band(src,1), "
                   "destination=<ndarray>, src_transform, src_crs, src_nodata, "
                   "dst_transform, dst_crs=EPSG:8058, dst_nodata, resampling=<method>)")


def src_path(tile: str, stage: str, res: float) -> Path:
    folder, prefix, proj = FOLDERS[tile]
    return LIDAR / folder / f"{prefix}_{stage}{proj}_{RES_TAG[res]}.tif"


# --------------------------------------------------------- boundary (U-I1 contract)

def _gpkg_geom(blob: bytes):
    if blob[:2] != b"GP":
        raise ValueError("not a GeoPackage geometry blob")
    env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]
    return wkb.loads(blob[8 + env:])


def read_registered_layer(layer_name: str):
    """read_registered_layer()'s contract, implemented inline - the function is
    mandated by CLAUDE.md but defined nowhere in the repo (U-I1)."""
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    try:
        aid, path, target_crs = con.execute(
            "SELECT spatial_layer_asset_id, path, target_crs FROM spatial_layer_asset "
            "WHERE layer_name = ?", (layer_name,)).fetchone()
    finally:
        con.close()
    p = Path(path)
    p = p if p.is_absolute() else ROOT / p
    g = sqlite3.connect(f"file:{p.as_posix()}?mode=ro", uri=True)
    try:
        tbl, gcol, srs_id = g.execute(
            "SELECT table_name, column_name, srs_id FROM gpkg_geometry_columns "
            "LIMIT 1").fetchone()
        blobs = [r[0] for r in g.execute(f'SELECT "{gcol}" FROM "{tbl}"')]
    finally:
        g.close()
    if int(str(target_crs).split(":")[-1]) != CRS_CANONICAL or int(srs_id) != CRS_CANONICAL:
        raise SystemExit(f"ABORT: {aid} is not EPSG:{CRS_CANONICAL}")
    return unary_union([_gpkg_geom(b) for b in blobs])


# ------------------------------------------------------------------ target grids

class Grid:
    """One EPSG:8058 grid, origin snapped to a whole multiple of the resolution."""

    def __init__(self, res: float, bounds):
        xmin = np.floor(bounds[0] / res) * res
        ymin = np.floor(bounds[1] / res) * res
        xmax = np.ceil(bounds[2] / res) * res
        ymax = np.ceil(bounds[3] / res) * res
        self.res = res
        self.width = int(round((xmax - xmin) / res))
        self.height = int(round((ymax - ymin) / res))
        self.transform = rasterio.transform.from_origin(xmin, ymax, res, res)
        self.bounds = (xmin, ymin, xmax, ymax)
        self.px_area_ha = res * res / 1e4          # DERIVED, never typed
        self.crs = CRS.from_epsg(CRS_CANONICAL)
        self.shape = (self.height, self.width)

    def __repr__(self):
        return f"{self.res:g} m, {self.width}x{self.height}"


def union_bounds_8058(paths) -> tuple:
    dst = CRS.from_epsg(CRS_CANONICAL)
    xs, ys = [], []
    for p in paths:
        with rasterio.open(p) as s:
            b = transform_bounds(s.crs, dst, *s.bounds, densify_pts=64)
        xs += [b[0], b[2]]
        ys += [b[1], b[3]]
    return min(xs), min(ys), max(xs), max(ys)


def warp(path: Path, grid: Grid, method, dtype, dst_nodata):
    out = np.full(grid.shape, dst_nodata, dtype=dtype)
    with rasterio.open(path) as s:
        reproject(source=rasterio.band(s, 1), destination=out,
                  src_transform=s.transform, src_crs=s.crs, src_nodata=s.nodata,
                  dst_transform=grid.transform, dst_crs=grid.crs,
                  dst_nodata=dst_nodata, resampling=method)
    return out


def valid_of(a, nodata):
    """Validity mask for either nodata convention.

    BUG FIXED 1 Aug 2026 (U-I11). This previously tested `isinstance(nodata, float)`
    to decide whether nodata was NaN. `np.float32(np.nan)` is NOT an instance of
    Python `float` - only `np.float64` is - so the NaN branch never fired for the
    float32 rasters, the test fell through to `a != nan` which is True EVERYWHERE,
    and mosaic_r1 therefore treated the d4 tile as valid across the whole grid. The
    d5 tile contributed nothing to the 5 m height mosaic and the 5 m seam mask came
    out all-ones. The 10 m FPC path was unaffected (integer nodata 255) and so was
    the 50 cm DEM path (explicit np.isnan there). Detected because U-Q4a found the
    2021 height ladder covering 51,167 ha - exactly the d4-only figure - instead of
    ~85,880 ha.
    """
    if nodata is None:
        return np.ones(a.shape, dtype=bool)
    try:
        if np.isnan(nodata):
            return ~np.isnan(a)
    except TypeError:
        pass
    return a != nodata


def mosaic_r1(a4, a5, nodata):
    """R1: d4 precedence, d5 fills only where d4 is absent. NEVER averaged."""
    v4, v5 = valid_of(a4, nodata), valid_of(a5, nodata)
    return np.where(v4, a4, np.where(v5, a5, nodata)).astype(a4.dtype), (v4 & v5)


def warp_2021(stage, grid, method, dtype, nodata, src_res=None):
    """src_res is the SOURCE product's native resolution, which is not always the
    target grid's - bb5 is a 50 cm product warped onto the 5 m grid."""
    src_res = grid.res if src_res is None else src_res
    a4 = warp(src_path("2021_d4", stage, src_res), grid, method, dtype, nodata)
    a5 = warp(src_path("2021_d5", stage, src_res), grid, method, dtype, nodata)
    out, seam = mosaic_r1(a4, a5, nodata)
    del a4, a5
    return out, seam


def write(path: Path, arr, grid: Grid, nodata, **tags):
    path.parent.mkdir(parents=True, exist_ok=True)
    with rasterio.open(path, "w", driver="GTiff", width=grid.width, height=grid.height,
                       count=1, dtype=arr.dtype, crs=grid.crs, transform=grid.transform,
                       nodata=nodata, compress="deflate", predictor=2, tiled=True,
                       blockxsize=512, blockysize=512, BIGTIFF="IF_SAFER") as d:
        d.write(arr, 1)
        d.update_tags(**{k: str(v) for k, v in tags.items()})


def main() -> None:
    boundary = read_registered_layer("gayini_boundary_8058")
    prop_ha = boundary.area / 1e4
    OUT_R.mkdir(parents=True, exist_ok=True)
    OUT_T.mkdir(parents=True, exist_ok=True)
    facts: list[dict] = []

    def fact(name, value, units="", note=""):
        facts.append(dict(name=name, value=value, units=units, note=note))

    print("=" * 78)
    print("Gate U1 - common frame")
    print("=" * 78)
    print(f"property (context only)        : {prop_ha:,.1f} ha")
    print(f"R1 seam precedence             : d4 wins, d5 fills, never averaged")
    print(f"R2 height ceiling              : {HEIGHT_CEILING_M:g} m "
          f"(sensitivity {HEIGHT_CEILING_SENSITIVITY})")
    print(f"ladder (both epochs, all tiles): {list(LADDER)}  [bb8 excluded - absent from d5]")
    fact("property_area_ha", round(prop_ha, 3), "ha", "context only, never a denominator")

    # ================================================== 10 m FPC + denominators
    g10 = Grid(FPC_RES_M, union_bounds_8058(
        [src_path(t, "bbh", FPC_RES_M) for t in FOLDERS]))
    on_prop10 = geometry_mask([boundary], out_shape=g10.shape,
                              transform=g10.transform, invert=True)
    print(f"\n10 m grid ({g10}), {g10.px_area_ha:g} ha/px")

    fpc09 = warp(src_path("2009", "bbh", FPC_RES_M), g10,
                 WarpResampling.bilinear, "uint8", NODATA_U8)
    fpc21, seam10 = warp_2021("bbh", g10, WarpResampling.bilinear, "uint8", NODATA_U8)

    v09, v21 = fpc09 != NODATA_U8, fpc21 != NODATA_U8
    both10 = v09 & v21
    prop_px10 = on_prop10.sum()

    print(f"\n{'layer':<24} {'mosaic-extent ha':>18} {'on-property ha':>16}")
    print("-" * 78)
    for key, label, m in (("bbh_2009", "2009 bbh", v09),
                          ("bbh_2021_mosaic", "2021 bbh (mosaic)", fpc21 != NODATA_U8),
                          ("both_valid", "both-valid", both10),
                          ("seam_d4_d5", "seam (d4 & d5)", seam10)):
        me, op = m.sum() * g10.px_area_ha, (m & on_prop10).sum() * g10.px_area_ha
        print(f"{label:<24} {me:>18,.1f} {op:>16,.1f}")
        fact(f"area_mosaic_extent_{key}_ha", round(me, 3), "ha", "8058 10 m frame")
        fact(f"area_on_property_{key}_ha", round(op, 3), "ha", "8058 10 m frame")

    taskU_denom = (both10 & on_prop10).sum() * g10.px_area_ha
    fact("denominator_taskU_both_valid_ha", round(taskU_denom, 3), "ha",
         "on-property, 2009 m5 INTERSECT (2021 d4 UNION d5), 10 m, EPSG:8058, "
         "0.01 ha/px. Denominator for every CHANGE statistic in Task U.")
    print(f"\nTASK U BOTH-VALID DENOMINATOR  : {taskU_denom:,.1f} ha "
          f"({100 * taskU_denom / (prop_px10 * g10.px_area_ha):.2f}% of property)")

    fpc_tags = dict(
        semantics="Foliage Projective Cover, percent, JRSRP bbh, Fisher et al. 2020",
        not_comparable_to=("Landsat total_veg (PV+NPV surface cover) - never on a "
                           "shared axis, never differenced"),
        resampling="bilinear", clip="gayini_boundary_8058", stage_code="bbh")
    write(OUT_R / "taskU_bbh_fpc_2009_8058_10m.tif",
          np.where(on_prop10, fpc09, NODATA_U8).astype("uint8"), g10, NODATA_U8,
          epoch="2009", sensor="Leica ALS-50", source_crs="EPSG:28355",
          mosaic_rule="single tile", **fpc_tags)
    write(OUT_R / "taskU_bbh_fpc_2021_8058_10m.tif",
          np.where(on_prop10, fpc21, NODATA_U8).astype("uint8"), g10, NODATA_U8,
          epoch="2021", sensor="Leica ALS-80",
          source_crs="EPSG:7854 (d4) + EPSG:7855 (d5)",
          mosaic_rule="R1: d4 precedence, d5 fill, never averaged", **fpc_tags)
    write(OUT_R / "taskU_seam_mask_2021_8058_10m.tif",
          (seam10 & on_prop10).astype("uint8"), g10, 0, epoch="2021",
          semantics="1 = both d4 and d5 valid (the R1 seam), for seam-sensitivity "
                    "testing of any later finding")

    # ------------------------------------------------ co-registration (item 6)
    print("\nco-registration - Pearson r on the on-property both-valid intersection,")
    print("shift series in whole 10 m pixels (2021 shifted against a fixed 2009)")
    a = fpc09.astype("float32")
    b = fpc21.astype("float32")
    base = both10 & on_prop10
    rs = {}
    print("          " + "".join(f"dx={d:+d}".rjust(11) for d in (-2, -1, 0, 1, 2)))
    for dy in (-2, -1, 0, 1, 2):
        cells = []
        for dx in (-2, -1, 0, 1, 2):
            bs = np.roll(np.roll(b, dy, axis=0), dx, axis=1)
            vs = np.roll(np.roll(v21, dy, axis=0), dx, axis=1)
            m = base & vs
            r = float(np.corrcoef(a[m], bs[m])[0, 1])
            rs[(dx, dy)] = r
            cells.append(f"{r:.4f}".rjust(11))
        print(f"   dy={dy:+d}  " + "".join(cells))
    peak = max(rs, key=rs.get)
    ok = peak == (0, 0)
    print(f"\n   r at zero offset = {rs[(0, 0)]:.4f};  peak at "
          f"dx={peak[0]:+d}, dy={peak[1]:+d}  ->  "
          f"{'PASS' if ok else 'FAIL - layers misaligned, Gate U3 cannot proceed'}")
    fact("coregistration_r_zero_offset", round(rs[(0, 0)], 6), "pearson_r",
         "2009 vs 2021 FPC, on-property both-valid, 10 m")
    fact("coregistration_peak_offset_px", f"{peak[0]},{peak[1]}", "px", "PASS iff 0,0")
    fact("coregistration_verdict", "PASS" if ok else "FAIL", "", "")
    with (OUT_T / "taskU_gateU1_coregistration.csv").open("w", newline="",
                                                          encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["dx_px", "dy_px", "pearson_r"])
        for (dx, dy), r in sorted(rs.items()):
            w.writerow([dx, dy, round(r, 8)])
    del a, b, bs, vs, fpc09, fpc21, v09, seam10

    # -------------------------------------- Census INTERSECT LiDAR (item 4)
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    cpath, = con.execute("SELECT path FROM raster_asset WHERE "
                         "raster_asset_id='raster_veg_regime_class_8058'").fetchone()
    con.close()
    cp = Path(cpath)
    cp = cp if cp.is_absolute() else ROOT / cp
    with rasterio.open(cp) as cs:
        c_valid = cs.read(1) != cs.nodata
        c_transform, c_res, c_shape = cs.transform, cs.res, (cs.height, cs.width)
    c_px_ha = c_res[0] * c_res[1] / 1e4       # DERIVED

    # Aggregate the LiDAR both-valid mask UP to the census grid by area-weighted
    # mean - never interpolate the census down (spec U-Q4b).
    cover = np.zeros(c_shape, dtype="float32")
    reproject(source=base.astype("float32"), destination=cover,
              src_transform=g10.transform, src_crs=g10.crs,
              dst_transform=c_transform, dst_crs=g10.crs,
              resampling=WarpResampling.average)
    cover = np.clip(cover, 0.0, 1.0)

    census_ha = c_valid.sum() * c_px_ha
    inter_aw = float(cover[c_valid].sum()) * c_px_ha
    print(f"\ncensus valid                   : {c_valid.sum():,} px = {census_ha:,.1f} ha")
    print(f"CENSUS n LIDAR DENOMINATOR     : {inter_aw:,.1f} ha "
          f"(area-weighted, threshold-free)")
    for thr in (0.5, 0.99, 1.0):
        n = int((c_valid & (cover >= thr)).sum())
        print(f"   census px, coverage >= {thr:<5}: {n:>9,} = {n * c_px_ha:>10,.1f} ha")
        fact(f"census_lidar_px_coverage_ge_{str(thr).replace('.', 'p')}", n, "px",
             "context for pinning U-Q4b's binary rule")
    fact("denominator_census_intersect_lidar_ha", round(inter_aw, 3), "ha",
         "area-weighted, threshold-free. Census grid 24.970268 m EPSG:8058 INTERSECT "
         "LiDAR both-valid on-property. Denominator for U-Q4b concordance.")
    fact("census_mapped_area_ha", round(census_ha, 3), "ha", "context")
    del cover, c_valid, base, both10, on_prop10, v21

    # ================================================ 5 m height ladder + R2
    g5 = Grid(LADDER_RES_M, boundary.bounds)     # property bbox; all R2 is on-property
    on_prop5 = geometry_mask([boundary], out_shape=g5.shape,
                             transform=g5.transform, invert=True)
    prop_ha5 = on_prop5.sum() * g5.px_area_ha
    print(f"\n5 m grid ({g5}), {g5.px_area_ha:g} ha/px, property {prop_ha5:,.1f} ha")
    print("PASS 1 - build the R2 exclusion masks by streaming the whole stack")

    masks = {e: {c: np.zeros(g5.shape, dtype=bool) for c in HEIGHT_CEILING_SENSITIVITY}
             for e in ("2009", "2021")}
    seam5 = None
    for stage in LADDER:
        for epoch in ("2009", "2021"):
            if epoch == "2009":
                arr = warp(src_path("2009", stage, LADDER_RES_M), g5,
                           WarpResampling.bilinear, "float32", NAN)
            else:
                arr, s5 = warp_2021(stage, g5, WarpResampling.bilinear, "float32", NAN)
                seam5 = s5 if seam5 is None else seam5
            fin = ~np.isnan(arr)
            for c in HEIGHT_CEILING_SENSITIVITY:
                masks[epoch][c] |= fin & (arr > c)
            del arr, fin
        print(f"   {stage} ({LADDER[stage]}) screened")

    print(f"\nR2 - physical-plausibility ceiling, pre-registered at {HEIGHT_CEILING_M:g} m,")
    print("applied identically at both epochs across the WHOLE height stack")
    print(f"{'epoch':<8} {'ceiling':>9} {'excluded px':>14} {'excluded ha':>14} "
          f"{'% property':>12}")
    print("-" * 78)
    r2_rows, excl, pct = [], {}, {}
    for epoch in ("2009", "2021"):
        for c in HEIGHT_CEILING_SENSITIVITY:
            m = masks[epoch][c] & on_prop5
            ha = m.sum() * g5.px_area_ha
            p = 100.0 * ha / prop_ha5
            tag = "   <- PRIMARY" if c == HEIGHT_CEILING_M else ""
            print(f"{epoch:<8} {c:>8.0f}m {m.sum():>14,} {ha:>14,.3f} {p:>11.4f}%{tag}")
            r2_rows.append(dict(epoch=epoch, ceiling_m=c, excluded_px=int(m.sum()),
                                excluded_ha=round(ha, 4), pct_of_property=round(p, 6),
                                is_primary=int(c == HEIGHT_CEILING_M)))
            if c == HEIGHT_CEILING_M:
                excl[epoch], pct[epoch] = m, p
                fact(f"r2_excluded_ha_{epoch}", round(ha, 4), "ha",
                     f"ceiling {c:g} m, on-property, 5 m grid")
    del masks
    with (OUT_T / "taskU_gateU1_r2_screen.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(r2_rows[0].keys()))
        w.writeheader()
        w.writerows(r2_rows)

    lo, hi = min(pct.values()), max(pct.values())
    ratio = hi / lo if lo > 0 else float("inf")
    over_1pct, over_3x = hi > 1.0, ratio > 3.0
    print("\nR2 STOP conditions:")
    print(f"   > 1% of property at either epoch : "
          f"{'TRIGGERED' if over_1pct else 'not triggered'}"
          f"   (2009 {pct['2009']:.4f}%, 2021 {pct['2021']:.4f}%)")
    print(f"   epochs differ by more than ~3x   : "
          f"{'TRIGGERED' if over_3x else 'not triggered'}   (ratio {ratio:.2f})")
    fact("r2_stop_over_1pct", int(over_1pct), "bool", "")
    fact("r2_stop_over_3x", int(over_3x), "bool", f"ratio {ratio:.3f}")

    print("\nPASS 2 - re-warp, apply the primary screen across the whole stack, write")
    for stage, plab in LADDER.items():
        for epoch in ("2009", "2021"):
            if epoch == "2009":
                arr = warp(src_path("2009", stage, LADDER_RES_M), g5,
                           WarpResampling.bilinear, "float32", NAN)
                mrule, crs_note, sensor = "single tile", "EPSG:28355", "Leica ALS-50"
            else:
                arr, _ = warp_2021(stage, g5, WarpResampling.bilinear, "float32", NAN)
                mrule = "R1: d4 precedence, d5 fill, never averaged"
                crs_note, sensor = "EPSG:7854 (d4) + EPSG:7855 (d5)", "Leica ALS-80"
            arr[excl[epoch]] = np.nan
            arr[~on_prop5] = np.nan
            write(OUT_R / f"taskU_{stage}_{plab}_height_{epoch}_8058_5m.tif",
                  arr, g5, np.nan, stage_code=stage, epoch=epoch, sensor=sensor,
                  source_crs=crs_note, resampling="bilinear",
                  clip="gayini_boundary_8058", mosaic_rule=mrule,
                  semantics=f"JRSRP {stage} - {plab[1:]}th percentile of return heights "
                            f"above ground within a pixel, metres",
                  r2_ceiling_m=HEIGHT_CEILING_M,
                  r2_note="Height stack screened at the pre-registered ceiling; excluded "
                          "pixels are NA across the whole stack for this epoch")
            del arr
        print(f"   {stage} ({plab}) written for both epochs")

    for epoch in ("2009", "2021"):
        write(OUT_R / f"taskU_r2_excluded_{epoch}_8058_5m.tif",
              excl[epoch].astype("uint8"), g5, 0, epoch=epoch,
              semantics=f"1 = excluded by the R2 {HEIGHT_CEILING_M:g} m height ceiling")
    write(OUT_R / "taskU_seam_mask_2021_8058_5m.tif",
          (seam5 & on_prop5).astype("uint8"), g5, 0, epoch="2021",
          semantics="1 = both d4 and d5 valid (the R1 seam), 5 m grid")

    # ---------------------- bb5 return-density diagnostic for R2 (NOT a filter)
    print("\nR2 diagnostic - do excluded pixels sit on low first-return density?")
    print("A DIAGNOSTIC on whether this is a sparse-return artefact. NOT a second filter.")
    dens_rows = []
    for epoch in ("2009", "2021"):
        if epoch == "2009":
            d = warp(src_path("2009", "bb5", 0.5), g5, WarpResampling.average,
                     "float32", NAN)
        else:
            d, _ = warp_2021("bb5", g5, WarpResampling.average, "float32", NAN,
                             src_res=0.5)
        ok_m = ~np.isnan(d) & on_prop5
        e, k = ok_m & excl[epoch], ok_m & ~excl[epoch]
        row = dict(epoch=epoch, n_excluded=int(e.sum()), n_kept=int(k.sum()),
                   median_density_excluded=round(float(np.median(d[e])), 4) if e.sum() else "",
                   median_density_kept=round(float(np.median(d[k])), 4) if k.sum() else "")
        dens_rows.append(row)
        print(f"   {epoch}: median first-return density  excluded "
              f"{row['median_density_excluded']}  vs kept {row['median_density_kept']}"
              f"   (n {row['n_excluded']:,} vs {row['n_kept']:,})")
        del d, ok_m, e, k
    with (OUT_T / "taskU_gateU1_r2_density_diagnostic.csv").open(
            "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(dens_rows[0].keys()))
        w.writeheader()
        w.writerows(dens_rows)

    fact("resampling_call", RESAMPLING_CALL, "", "recorded verbatim, spec Gate U1 item 1")
    with (OUT_T / "taskU_gateU1_facts.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["name", "value", "units", "note"])
        w.writeheader()
        w.writerows(facts)
    print(f"\nwritten: {(OUT_T / 'taskU_gateU1_facts.csv').relative_to(ROOT)}")
    print(f"rasters: {OUT_R.relative_to(ROOT)} "
          f"({len(list(OUT_R.glob('*.tif')))} files)")


if __name__ == "__main__":
    main()
