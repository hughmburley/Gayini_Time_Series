#!/usr/bin/env python3
"""Task U · Gate U0.1 — settle the 2021 partner (`d4` vs `d5`) on on-property coverage.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.1.md, Gate U0.1.

The 2021 LiDAR is delivered twice, in two MGA zones. v1 of the spec compared 2009
(`m5`, EPSG:28355) against 2021 `d4` (EPSG:7854) without knowing `d5` (EPSG:7855)
existed; those preview numbers are withdrawn. This script settles which 2021
product is the comparison partner for 2009, and states the both-valid intersection
that becomes the denominator for every change statistic in Task U.

THE DECISION RULE IS ON-PROPERTY COVERAGE, NOT PREFERENCE (spec U0.1):
  - if `d4` covers the property fully, use `d4` and keep `d5` as a check, because
    `d5` is likely a JRSRP reprojection of `d4` and stacking a second resampling
    under ours is avoidable;
  - if `d4` leaves property gaps that `d5` fills, `d5` becomes the partner and the
    extra resampling generation is accepted and recorded.

Reads three 10 m `bbh` files (~14 MB total). Writes NO raster - the reprojection is
in memory. Nothing is registered here; registration is Gate U1.

Resampling note: this gate answers a COVERAGE question, not a value question, so
every reprojection here is NEAREST - bilinear would bleed the 255 nodata into the
valid margin and inflate exactly the area we are measuring. Gate U1 does the
value-preserving bilinear reprojection separately.

Usage:  python scripts/14_lidar/U0_1_partner_decision.py
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
OUT_CSV = ROOT / "Output" / "tables" / "taskU_gateU0_partner_decision.csv"

CRS_CANONICAL = 8058
TARGET_RES_M = 10.0          # native resolution of every bbh product
NODATA = 255

CANDIDATES = {
    "2009_m5": LIDAR / "Gayini_2009_GDA1994_z55" / "apl1dr_rgayini_2009_bbhm5_r10m.tif",
    "2021_d4": LIDAR / "Gayini_2021_GDA2020_z54" / "apl4dr_rgayini_2021_bbhd4_r10m.tif",
    "2021_d5": LIDAR / "Gayini_2021_GDA2020_z55" / "apl4dr_rgayini_2021_bbhd5_r10m.tif",
}


# ---------------------------------------------------------------------------
# read_registered_layer()'s contract, implemented inline.
#
# CLAUDE.md mandates reading spatial layers through read_registered_layer() -
# resolve the path from spatial_layer_asset, assert the CRS, compare the file's
# actual fields to the registered field_list. That function is referenced in the
# docs and in three script headers but is NOT DEFINED ANYWHERE IN THE REPO. Rather
# than assume it exists, its three checks are performed here explicitly. Logged as
# an IMPROVE, not a stop.
# ---------------------------------------------------------------------------

def _gpkg_geom_to_shapely(blob: bytes):
    """Strip the GeoPackage binary header and parse the trailing standard WKB."""
    if blob[:2] != b"GP":
        raise ValueError("not a GeoPackage geometry blob")
    flags = blob[3]
    env_code = (flags >> 1) & 0x07
    env_len = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[env_code]
    return wkb.loads(blob[8 + env_len:])


def read_registered_layer(layer_name: str):
    """Resolve from spatial_layer_asset, assert CRS, compare fields. Returns
    (geometry, epsg, registered_field_list, actual_field_list)."""
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    try:
        row = con.execute(
            "SELECT spatial_layer_asset_id, path, target_crs, field_list "
            "FROM spatial_layer_asset WHERE layer_name = ?", (layer_name,)).fetchone()
    finally:
        con.close()
    if row is None:
        raise SystemExit(f"ABORT: layer {layer_name!r} not in spatial_layer_asset")
    asset_id, path, target_crs, field_list = row

    p = Path(path)
    if not p.is_absolute():
        p = ROOT / p
    if not p.is_file():
        raise SystemExit(f"ABORT: {asset_id} registered path does not exist: {p}")

    g = sqlite3.connect(f"file:{p.as_posix()}?mode=ro", uri=True)
    try:
        tbl, geom_col, srs_id = g.execute(
            "SELECT table_name, column_name, srs_id FROM gpkg_geometry_columns "
            "LIMIT 1").fetchone()
        actual_fields = [r[1] for r in g.execute(f'PRAGMA table_info("{tbl}")')]
        blobs = [r[0] for r in g.execute(f'SELECT "{geom_col}" FROM "{tbl}"')]
    finally:
        g.close()

    # assert CRS - registered target_crs, the gpkg srs_id, and the spec must agree
    want = int(str(target_crs).split(":")[-1])
    if want != CRS_CANONICAL or int(srs_id) != CRS_CANONICAL:
        raise SystemExit(
            f"ABORT: {asset_id} CRS mismatch - registered {target_crs}, "
            f"gpkg srs_id {srs_id}, required EPSG:{CRS_CANONICAL}")

    geom = unary_union([_gpkg_geom_to_shapely(b) for b in blobs])
    return geom, want, field_list, actual_fields


# ---------------------------------------------------------------------------
# common EPSG:8058 grid
# ---------------------------------------------------------------------------

def common_grid(paths, boundary_bounds):
    """One 10 m EPSG:8058 grid spanning every candidate plus the property, origin
    snapped to a whole multiple of the resolution so the grid is reproducible."""
    dst = CRS.from_epsg(CRS_CANONICAL)
    xs, ys = [], []
    for p in paths:
        with rasterio.open(p) as s:
            b = transform_bounds(s.crs, dst, *s.bounds, densify_pts=64)
        xs += [b[0], b[2]]
        ys += [b[1], b[3]]
    xs += [boundary_bounds[0], boundary_bounds[2]]
    ys += [boundary_bounds[1], boundary_bounds[3]]

    r = TARGET_RES_M
    xmin = np.floor(min(xs) / r) * r
    ymin = np.floor(min(ys) / r) * r
    xmax = np.ceil(max(xs) / r) * r
    ymax = np.ceil(max(ys) / r) * r
    width = int(round((xmax - xmin) / r))
    height = int(round((ymax - ymin) / r))
    transform = rasterio.transform.from_origin(xmin, ymax, r, r)
    return dst, transform, width, height, (xmin, ymin, xmax, ymax)


def warp_to_grid(path, dst_crs, transform, width, height):
    """NEAREST onto the common grid. Returns the uint8 array with NODATA fill."""
    out = np.full((height, width), NODATA, dtype="uint8")
    with rasterio.open(path) as s:
        reproject(
            source=rasterio.band(s, 1),
            destination=out,
            src_transform=s.transform,
            src_crs=s.crs,
            src_nodata=s.nodata,
            dst_transform=transform,
            dst_crs=dst_crs,
            dst_nodata=NODATA,
            resampling=WarpResampling.nearest,
        )
    return out


def main() -> None:
    px_area_ha = TARGET_RES_M ** 2 / 1e4      # DERIVED, never typed

    geom, epsg, reg_fields, act_fields = read_registered_layer("gayini_boundary_8058")
    prop_area_ha = geom.area / 1e4
    print("=" * 78)
    print("Gate U0.1 - 2021 partner decision")
    print("=" * 78)
    print(f"boundary layer   : gayini_boundary_8058 (spatial_007), EPSG:{epsg}")
    print(f"registered fields: {reg_fields}")
    print(f"actual fields    : {','.join(act_fields)}")
    print(f"property polygon : {prop_area_ha:,.1f} ha  ({geom.geom_type})")
    print(f"LiDAR pixel      : {TARGET_RES_M:g} m -> {px_area_ha:g} ha/px (derived)")
    print()

    dst_crs, transform, width, height, bounds = common_grid(
        CANDIDATES.values(), geom.bounds)
    print(f"common 8058 grid : {width} x {height} @ {TARGET_RES_M:g} m")
    print(f"                   {[round(v, 1) for v in bounds]}")

    on_prop = geometry_mask([geom], out_shape=(height, width), transform=transform,
                            invert=True)
    print(f"property on grid : {on_prop.sum():,} px = "
          f"{on_prop.sum() * px_area_ha:,.1f} ha "
          f"(rasterisation vs polygon: "
          f"{on_prop.sum() * px_area_ha - prop_area_ha:+,.1f} ha)")
    print()

    arrs = {k: warp_to_grid(p, dst_crs, transform, width, height)
            for k, p in CANDIDATES.items()}
    valid = {k: (a != NODATA) for k, a in arrs.items()}

    rows = []
    print(f"{'candidate':<10} {'mosaic ha':>12} {'on-prop ha':>12} "
          f"{'% of prop':>10} {'prop gap ha':>12}")
    print("-" * 78)
    for k in CANDIDATES:
        v = valid[k]
        mos = v.sum() * px_area_ha
        onp = (v & on_prop).sum() * px_area_ha
        pct = 100.0 * (v & on_prop).sum() / on_prop.sum()
        gap = on_prop.sum() * px_area_ha - onp
        print(f"{k:<10} {mos:>12,.1f} {onp:>12,.1f} {pct:>9.2f}% {gap:>12,.1f}")
        rows.append(dict(candidate=k, path=str(CANDIDATES[k].relative_to(ROOT)),
                         mosaic_valid_ha=round(mos, 3),
                         on_property_valid_ha=round(onp, 3),
                         pct_of_property=round(pct, 4),
                         property_gap_ha=round(gap, 3)))
    print()

    # --- are d4 and d5 the same data in two projections? ---------------------
    a4, a5 = arrs["2021_d4"], arrs["2021_d5"]
    both = valid["2021_d4"] & valid["2021_d5"]
    print("d4 vs d5 - same data in two projections, or different coverage?")
    print(f"  d4-valid only        : {(valid['2021_d4'] & ~valid['2021_d5']).sum() * px_area_ha:>12,.1f} ha")
    print(f"  d5-valid only        : {(valid['2021_d5'] & ~valid['2021_d4']).sum() * px_area_ha:>12,.1f} ha")
    print(f"  both valid           : {both.sum() * px_area_ha:>12,.1f} ha")
    if both.sum():
        d = a4[both].astype(np.int16) - a5[both].astype(np.int16)
        ident = float((d == 0).mean() * 100)
        within1 = float((np.abs(d) <= 1).mean() * 100)
        r = float(np.corrcoef(a4[both], a5[both])[0, 1])
        print(f"  identical values     : {ident:>11.2f} %")
        print(f"  within +/-1 FPC pp   : {within1:>11.2f} %")
        print(f"  Pearson r            : {r:>11.4f}")
        print(f"  mean d4-d5           : {d.mean():>11.4f} pp   (median {np.median(d):+.1f})")
    print()

    # --- the union the spec's two-branch rule does not contemplate -----------
    # Neither 2021 product covers the property. If the union does, the partner is
    # a MOSAIC of both, which is a third branch of the U0.1 rule.
    union = valid["2021_d4"] | valid["2021_d5"]
    u_onp = (union & on_prop).sum()
    print("2021 union (d4 | d5):")
    print(f"  mosaic valid         : {union.sum() * px_area_ha:>12,.1f} ha")
    print(f"  on-property valid    : {u_onp * px_area_ha:>12,.1f} ha "
          f"({100.0 * u_onp / on_prop.sum():.2f}% of property)")
    print(f"  remaining prop gap   : "
          f"{(on_prop.sum() - u_onp) * px_area_ha:>12,.1f} ha")
    rows.append(dict(candidate="2021_union_d4_or_d5", path="",
                     mosaic_valid_ha=round(union.sum() * px_area_ha, 3),
                     on_property_valid_ha=round(u_onp * px_area_ha, 3),
                     pct_of_property=round(100.0 * u_onp / on_prop.sum(), 4),
                     property_gap_ha=round((on_prop.sum() - u_onp) * px_area_ha, 3)))
    print()

    # --- both-valid intersection with 2009, per candidate --------------------
    print("both-valid intersection with 2009 (on-property), per candidate:")
    inter_u = valid["2009_m5"] & union & on_prop
    print(f"  2009_m5 ^ union     : {inter_u.sum() * px_area_ha:>12,.1f} ha "
          f"({100.0 * inter_u.sum() / on_prop.sum():.2f}% of property)   <-- candidate denominator")
    rows.append(dict(candidate="intersection_2009_m5__2021_union",
                     path="", mosaic_valid_ha="",
                     on_property_valid_ha=round(inter_u.sum() * px_area_ha, 3),
                     pct_of_property=round(100.0 * inter_u.sum() / on_prop.sum(), 4),
                     property_gap_ha=""))
    for k in ("2021_d4", "2021_d5"):
        inter = valid["2009_m5"] & valid[k] & on_prop
        print(f"  2009_m5 ^ {k:<8}: {inter.sum() * px_area_ha:>12,.1f} ha "
              f"({100.0 * inter.sum() / on_prop.sum():.2f}% of property)")
        rows.append(dict(candidate=f"intersection_2009_m5__{k}",
                         path="", mosaic_valid_ha="",
                         on_property_valid_ha=round(inter.sum() * px_area_ha, 3),
                         pct_of_property=round(100.0 * inter.sum() / on_prop.sum(), 4),
                         property_gap_ha=""))

    rows.append(dict(candidate="property_polygon", path="spatial_007",
                     mosaic_valid_ha="", on_property_valid_ha=round(prop_area_ha, 3),
                     pct_of_property=100.0, property_gap_ha=""))

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"\nwritten: {OUT_CSV.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
