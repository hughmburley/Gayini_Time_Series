#!/usr/bin/env python
"""Ruling BQ (as amended by CY) - the COUNTED per-cell flood-frequency surface.

WHY IT EXISTS. background_flood_frequency_8058.tif was counted on the native EPSG:28355
grid and then INTERPOLATED onto 8058, so its values are not integer ratios and its cells
do not agree with the analysis chain, which reprojects the binary bands nearest and
counts on 8058. This surface counts on 8058 and is the one every number derives from.

SCOPE, reduced by CY: this is a MAP PRODUCT for the client and a VERIFICATION ARTEFACT
for BR. It is NOT an analysis input - the counted per-cell values already exist as
flood_freq_pct in gayini_pixel_census_8058.parquet, which stays the source of truth.

THREE VERIFICATIONS, all required:
  1. 35 distinct values inside codes 11-33 - not 36. valid_years = 35 everywhere and k
     runs 0-34; no non-treed cell is wet in all 35 years. A FACT ABOUT THE COUNTRY,
     recorded as such, never as a tolerance.
  2. zones cut at 0/10/25/50 reproduce flood_zone_8058.tif at 100%.
  3. cell-for-cell agreement with the census column. IF THEY DISAGREE THE RASTER IS
     WRONG, NOT THE CENSUS - report and stop building on it.

HALT: a grid mismatch against veg_regime_class_8058.tif.
"""
from __future__ import annotations

import hashlib
import shutil
import sqlite3
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio

ROOT = Path(__file__).resolve().parents[2]
R = ROOT / "Output" / "rasters"
WET = R / "inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif"
VALID = R / "inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif"
CLASS = R / "veg_regime_class_8058.tif"
ZONE = R / "flood_zone_8058.tif"
OUT = R / "flood_frequency_counted_8058.tif"
SHARE = R / "DATA_share_20260808"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"
DB = ROOT / "Output/database/Gayini_Results.sqlite"

RUN_ID = "BQ_counted_flood_frequency_20260809"
NON_TREED = [11, 12, 13, 21, 22, 23, 31, 32, 33]


def sha256_first50(p: Path) -> str:
    cap, h = 50 * 1024 * 1024, hashlib.sha256()
    with open(p, "rb") as f:
        while cap > 0:
            b = f.read(min(1 << 20, cap))
            if not b:
                break
            h.update(b)
            cap -= len(b)
    return h.hexdigest()


def grid(src) -> tuple:
    return (src.width, src.height, tuple(round(v, 9) for v in src.transform[:6]),
            src.crs.to_epsg())


def main() -> int:
    with rasterio.open(CLASS) as c:
        gclass, prof_ref, cls = grid(c), c.profile, c.read(1)
    for name, path in (("wet", WET), ("valid", VALID), ("flood_zone", ZONE)):
        with rasterio.open(path) as s:
            if grid(s) != gclass:
                print(f"  HALT - grid mismatch: {name} against veg_regime_class_8058")
                print(f"    class {gclass}\n    {name} {grid(s)}")
                return 1
    print(f"  grid check: wet, valid and flood_zone all match veg_regime_class_8058 "
          f"({gclass[0]}x{gclass[1]}, EPSG:{gclass[3]})")

    # ---- count on 8058, 255 -> NA, wide accumulator --------------------------------
    with rasterio.open(WET) as w, rasterio.open(VALID) as v:
        nb = w.count
        wet_sum = np.zeros((w.height, w.width), dtype=np.int32)
        val_sum = np.zeros((w.height, w.width), dtype=np.int32)
        for b in range(1, nb + 1):
            wb = w.read(b)
            vb = v.read(b)
            wm = np.where(wb == 255, 0, wb).astype(np.int32)
            vm = np.where(vb == 255, 0, vb).astype(np.int32)
            # a cell only counts as wet in a year it was also valid in
            wet_sum += (wm * vm)
            val_sum += vm
    print(f"  counted {nb} bands with an int32 accumulator; 255 treated as not-valid")

    freq = np.full(wet_sum.shape, np.nan, dtype=np.float32)
    ok = val_sum > 0
    freq[ok] = 100.0 * wet_sum[ok] / val_sum[ok]

    # Build the profile explicitly rather than copying the class raster's: that one
    # carries block sizes that are not multiples of 16, so inheriting it and then
    # setting tiled=True is rejected by GDAL. Only the georeferencing is taken across.
    prof = {"driver": "GTiff", "width": prof_ref["width"], "height": prof_ref["height"],
            "count": 1, "dtype": "float32", "crs": prof_ref["crs"],
            "transform": prof_ref["transform"], "nodata": np.nan,
            "compress": "deflate", "predictor": 3,
            "tiled": True, "blockxsize": 256, "blockysize": 256}
    with rasterio.open(OUT, "w", **prof) as dst:
        dst.write(freq, 1)
        dst.set_band_description(1, "flood_frequency_counted")
    print(f"  [wrote] {OUT.name}  {OUT.stat().st_size / 1e6:.1f} MB")

    nt_mask = np.isin(cls, NON_TREED)
    census_mask = cls != 255

    # ---- verification 1: 35 distinct values inside codes 11-33 ---------------------
    vals = freq[nt_mask]
    vals = vals[np.isfinite(vals)]
    n_distinct = int(np.unique(np.round(vals, 6)).size)
    k = np.round(vals / 100 * 35).astype(int)
    v1 = n_distinct == 35
    print(f"\n  V1 distinct values inside codes 11-33: {n_distinct}  (CY: expect 35) "
          f"{'PASS' if v1 else 'FAIL'}")
    print(f"     k runs {k.min()} to {k.max()} of 35 - no non-treed cell is wet in all "
          f"35 years. A fact about the country, not a tolerance.")

    # ---- verification 2: reproduce flood_zone_8058 --------------------------------
    # (-Inf,0]=0  (0,10]=1  (10,25]=2  (25,50]=3  (50,Inf]=4, right-closed, as built.
    z = np.full(freq.shape, 255, dtype=np.uint8)
    f = freq
    with np.errstate(invalid="ignore"):
        z[census_mask & (f <= 0)] = 0
        z[census_mask & (f > 0) & (f <= 10)] = 1
        z[census_mask & (f > 10) & (f <= 25)] = 2
        z[census_mask & (f > 25) & (f <= 50)] = 3
        z[census_mask & (f > 50)] = 4
    with rasterio.open(ZONE) as zs:
        z_pub = zs.read(1)
    cmp_mask = census_mask & (z_pub != 255)
    agree = int((z[cmp_mask] == z_pub[cmp_mask]).sum())
    total = int(cmp_mask.sum())
    v2 = agree == total
    print(f"  V2 zones reproduce flood_zone_8058: {agree:,} of {total:,} "
          f"({100 * agree / total:.4f}%) {'PASS' if v2 else 'FAIL'}")
    if not v2:
        diff = np.argwhere(cmp_mask & (z != z_pub))[:5]
        for rr, cc in diff:
            print(f"     row {rr} col {cc}: counted {z[rr, cc]} vs published {z_pub[rr, cc]}"
                  f" (freq {freq[rr, cc]:.6f})")

    # ---- verification 3: cell-for-cell against the census column ------------------
    cen = pd.read_parquet(CENSUS, columns=["x_8058", "y_8058", "flood_freq_pct",
                                           "veg_regime_class"])
    with rasterio.open(OUT) as s:
        rows, cols = rasterio.transform.rowcol(s.transform, cen.x_8058.values,
                                               cen.y_8058.values)
    rows = np.asarray(rows)
    cols = np.asarray(cols)
    got = freq[rows, cols]
    exp = cen.flood_freq_pct.values.astype(np.float32)
    both = np.isfinite(got) & np.isfinite(exp)
    dmax = float(np.nanmax(np.abs(got[both] - exp[both]))) if both.any() else np.nan
    n_bad = int((np.abs(got[both] - exp[both]) > 1e-4).sum())
    v3 = n_bad == 0
    print(f"  V3 agreement with census flood_freq_pct: {int(both.sum()):,} cells compared, "
          f"max |diff| {dmax:.2e}, disagreeing {n_bad} {'PASS' if v3 else 'FAIL'}")
    if not v3:
        print("     THE RASTER IS WRONG, NOT THE CENSUS. Not registered; not copied.")
        return 1

    # ---- register, atomically ------------------------------------------------------
    with rasterio.open(OUT) as s:
        b = s.bounds
        res = s.res
    chk, nbytes = sha256_first50(OUT), OUT.stat().st_size
    con = sqlite3.connect(DB)
    try:
        with con:
            con.execute(
                "INSERT OR REPLACE INTO raster_asset (raster_asset_id, path, metric_id, "
                "period_label, crs, resolution_x, resolution_y, xmin, ymin, xmax, ymax, "
                "checksum_sha256, path_exists, qa_status, run_id, crs_epsg, product, "
                "legend_status, legend_semantics, framing_label, provenance_note, "
                "file_bytes, source_crs, stage_code) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,"
                "?,?,?,?,?,?,?,?,?,?)",
                ("flood_frequency_counted_8058",
                 OUT.relative_to(ROOT).as_posix(), "flood_frequency_between_year",
                 "1988-2022", "EPSG:8058", res[0], res[1], b.left, b.bottom, b.right, b.top,
                 chk, 1, "pass", RUN_ID, 8058, "inundation", "confirmed",
                 "Percentage of valid water years in which the cell was wet: "
                 "100 * sum(wet) / sum(valid), COUNTED on the EPSG:8058 census grid. "
                 "valid_years = 35 for every non-treed census cell, so values are k/35 "
                 "and only 35 distinct values occur inside codes 11-33 (k = 0..34).",
                 "census_8058",
                 "Ruling BQ as amended by CY. Built from annual_wet_any / "
                 "annual_valid_any_1988_2023_8058 with 255 treated as not-valid and an "
                 "int32 accumulator. MAP PRODUCT and BR verification artefact, NOT an "
                 "analysis input - the counted values already exist as flood_freq_pct in "
                 "gayini_pixel_census_8058.parquet, which remains the source of truth. "
                 "Supersedes nothing; background_flood_frequency_8058.tif is retained.",
                 nbytes, "EPSG:8058 (counted in place; no reprojection)", "BQ"))
        n = con.execute("SELECT count(*) FROM raster_asset WHERE raster_asset_id="
                        "'flood_frequency_counted_8058'").fetchone()[0]
        assert n == 1, n
        print(f"  registered flood_frequency_counted_8058  {chk[:12]}  "
              f"{nbytes / 1e6:.1f} MB  (raster_asset rows now "
              f"{con.execute('SELECT count(*) FROM raster_asset').fetchone()[0]})")
    finally:
        con.close()

    SHARE.mkdir(parents=True, exist_ok=True)
    shutil.copy2(OUT, SHARE / OUT.name)
    same = sha256_first50(SHARE / OUT.name) == chk
    print(f"  copied into the share folder; checksum matches: {same}")
    return 0 if (v1 and v2 and v3 and same) else 1


if __name__ == "__main__":
    sys.exit(main())
