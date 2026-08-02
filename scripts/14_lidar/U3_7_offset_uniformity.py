#!/usr/bin/env python3
"""Task U · U3.7 — is the stable-ground vertical offset spatially uniform?

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U3 item 7 (added by
amendment 1 August 2026, design-seat Gate U3 STOP D3).

WHY THIS EXISTS. Gate U3 measured the S1 stable-ground vertical offset at +0.3032 m
with a MAD of 2.4 cm - but an S1 p05-p95 spread of 13.7 cm. A 30 cm bank cut is
twelve MADs above the noise and only about two spreads above it. If that 13.7 cm
carries SPATIAL STRUCTURE - a tilt, a drift, a step across the d4/d5 boundary - then
a single scalar correction leaves residual topography that could masquerade as
earthworks in exactly the analysis it is meant to enable.

  uniform within its MAD  -> +0.303 m stands as a scalar calibration
  NOT uniform             -> report the structure and STOP. A spatially varying
                             offset is a design-seat decision, not a build step, and
                             no corrected surface is produced in the meantime.

THREE TESTS, and the second is the one the design seat named plus the one it implies:
  1. by 500 m block      - is there block-to-block structure beyond the MAD?
  2. by tile provenance  - d4 region vs d5 region vs the R1 seam. The seam is the
                           narrow overlap, but if the two 2021 tiles carry different
                           vertical calibrations the step appears across the WHOLE
                           d4/d5 boundary, not only where they overlap. Testing the
                           seam alone would miss it.
  3. linear trend in x,y - a tilt or drift across the property.

Reads the registered Gate U1 DEMs, decimated exactly as Gate U3 decimated them so the
numbers are comparable. Writes CSVs only.

Usage:  python scripts/14_lidar/U3_7_offset_uniformity.py
"""
from __future__ import annotations

import csv
import numpy as np
import rasterio
from affine import Affine
from pathlib import Path
from rasterio.warp import Resampling as WR
from rasterio.warp import reproject

ROOT = Path(__file__).resolve().parents[2]
TU = ROOT / "Output" / "rasters" / "task_U"
OUT_T = ROOT / "Output" / "tables"
LIDAR = ROOT / "Input" / "gayini_lidar"

FLOOD_ZONE = ROOT / "Output" / "rasters" / "flood_zone_8058.tif"
VEG_P50 = ROOT / "Output" / "rasters" / "veg_percentiles_8058" / "total_veg_p50_8058.tif"

P50_PRIMARY = 30.0          # identical to Gate U3
DRY_ZONES = (0, 1)
DEM_DECIMATE = 20           # identical to Gate U3: 50 cm -> 10 m
BLOCK_M = 500.0
GATE_U3_OFFSET = 0.3032     # for reference only; recomputed here, never assumed
GATE_U3_MAD = 0.0243

D4 = LIDAR / "Gayini_2021_GDA2020_z54" / "apl4dr_rgayini_2021_bbhd4_r10m.tif"
D5 = LIDAR / "Gayini_2021_GDA2020_z55" / "apl4dr_rgayini_2021_bbhd5_r10m.tif"


def robust(d):
    d = d[np.isfinite(d)]
    if d.size == 0:
        return dict(n=0, median=np.nan, mean=np.nan, mad=np.nan, p05=np.nan,
                    p95=np.nan, spread=np.nan)
    med = float(np.median(d))
    p05, p95 = np.percentile(d, [5, 95])
    return dict(n=int(d.size), median=med, mean=float(d.mean()),
                mad=float(np.median(np.abs(d - med))), p05=float(p05),
                p95=float(p95), spread=float(p95 - p05))


def main() -> None:
    OUT_T.mkdir(parents=True, exist_ok=True)
    print("=" * 78)
    print("U3.7 - spatial uniformity of the stable-ground vertical offset")
    print("=" * 78)

    # --- the decimated DEM difference, exactly as Gate U3 built it ---------------
    grids = {}
    for epoch in ("2009", "2021"):
        with rasterio.open(TU / f"taskU_bb0_dem_{epoch}_8058_50cm.tif") as s:
            oh, ow = s.height // DEM_DECIMATE, s.width // DEM_DECIMATE
            a = s.read(1, out_shape=(oh, ow), resampling=WR.average)
            grids[epoch] = (a, s.transform * Affine.scale(DEM_DECIMATE, DEM_DECIMATE),
                            (oh, ow), s.crs)
        print(f"  read {epoch} DEM, decimated 1/{DEM_DECIMATE} -> {ow} x {oh}")
    a09, tr, shape, crs = grids["2009"]
    a21 = np.full(shape, np.nan, dtype="float32")
    reproject(source=grids["2021"][0], destination=a21, src_transform=grids["2021"][1],
              src_crs=grids["2021"][3], src_nodata=np.nan, dst_transform=tr,
              dst_crs=crs, dst_nodata=np.nan, resampling=WR.bilinear)
    ddem = a21 - a09
    res_m = tr.a
    del grids, a09, a21

    # --- S1 on this grid, identical definition to Gate U3 -----------------------
    def onto(path, method, dtype, nodata):
        out = np.full(shape, nodata, dtype=dtype)
        with rasterio.open(path) as s:
            reproject(source=rasterio.band(s, 1), destination=out,
                      src_transform=s.transform, src_crs=s.crs, src_nodata=s.nodata,
                      dst_transform=tr, dst_crs=crs, dst_nodata=nodata,
                      resampling=method)
        return out

    fz = onto(FLOOD_ZONE, WR.nearest, "uint8", 255)
    p50 = onto(VEG_P50, WR.bilinear, "float32", np.nan)
    s1 = np.isin(fz, DRY_ZONES) & np.isfinite(p50) & (p50 < P50_PRIMARY) & np.isfinite(ddem)
    base = robust(ddem[s1])
    print(f"\nS1 overall (recomputed, not assumed): n={base['n']:,}  "
          f"median={base['median']:+.4f} m  MAD={base['mad']:.4f}  "
          f"p05-p95 spread={base['spread']:.4f} m")
    print(f"  Gate U3 reported {GATE_U3_OFFSET:+.4f} m, MAD {GATE_U3_MAD:.4f} - "
          f"reproduces: {abs(base['median'] - GATE_U3_OFFSET) < 0.005}")

    rows = []

    def add(scope, label, st, extra=""):
        rows.append(dict(scope=scope, label=label, n=st["n"],
                         median_offset_m=round(st["median"], 5),
                         mean_offset_m=round(st["mean"], 5),
                         mad_m=round(st["mad"], 5), p05_m=round(st["p05"], 5),
                         p95_m=round(st["p95"], 5), spread_m=round(st["spread"], 5),
                         note=extra))

    add("overall", "S1 all", base, "recomputed at U3.7, identical definition to Gate U3")

    # ================================================ TEST 1 · by 500 m block
    bpx = int(round(BLOCK_M / res_m))
    h, w = shape
    bh, bw = h // bpx, w // bpx
    m = s1[:bh * bpx, :bw * bpx].reshape(bh, bpx, bw, bpx)
    v = np.where(s1, np.nan_to_num(ddem), 0.0)[:bh * bpx, :bw * bpx].reshape(
        bh, bpx, bw, bpx)
    cnt = m.sum(axis=(1, 3))
    tot = v.sum(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        bmean = np.where(cnt > 0, tot / np.maximum(cnt, 1), np.nan)
    keep = cnt >= 30
    bo = bmean[keep]
    bst = robust(bo)
    print(f"\n--- TEST 1 · by {BLOCK_M:g} m block (>= 30 stable px each) ---")
    print(f"  blocks={bst['n']}  block-offset median={bst['median']:+.4f} m  "
          f"SD={np.std(bo, ddof=1):.4f}  p05-p95 spread={bst['spread']:.4f} m")
    uniform_block = bst["spread"] <= base["mad"]
    print(f"  block-to-block spread ({bst['spread']:.4f} m) vs pixel MAD "
          f"({base['mad']:.4f} m)  ->  "
          f"{'UNIFORM within the MAD' if uniform_block else 'NOT uniform within the MAD'}")
    add("block_500m", "S1 block means", bst,
        f"block SD {np.std(bo, ddof=1):.5f}; uniform_within_pixel_MAD={int(uniform_block)}")

    # ================================================ TEST 2 · by tile provenance
    v4 = onto(D4, WR.nearest, "uint8", 255) != 255
    v5 = onto(D5, WR.nearest, "uint8", 255) != 255
    seam = v4 & v5
    prov = {"d4_only": v4 & ~v5, "d5_only": v5 & ~v4, "seam_d4_and_d5": seam}
    print(f"\n--- TEST 2 · by 2021 tile provenance ---")
    print(f"  {'region':<18}{'n':>10}{'median':>11}{'MAD':>9}{'spread':>9}"
          f"{'vs d4_only':>12}")
    ref = None
    for name, msk in prov.items():
        st = robust(ddem[s1 & msk])
        if st["n"] == 0:
            print(f"  {name:<18}{'0':>10}   (no S1 pixels in this region)")
            add("tile_provenance", name, st, "no S1 pixels here")
            continue
        if name == "d4_only":
            ref = st["median"]
        delta = "" if ref is None else f"{st['median'] - ref:+.4f}"
        print(f"  {name:<18}{st['n']:>10,}{st['median']:>11.4f}{st['mad']:>9.4f}"
              f"{st['spread']:>9.4f}{delta:>12}")
        add("tile_provenance", name, st,
            "" if ref is None else f"delta vs d4_only = {st['median'] - ref:+.5f} m")
    if ref is not None:
        d5st = robust(ddem[s1 & prov["d5_only"]])
        if d5st["n"] > 0:
            step = abs(d5st["median"] - ref)
            print(f"  d4 -> d5 step = {step:.4f} m   vs pixel MAD {base['mad']:.4f} m  ->  "
                  f"{'within MAD' if step <= base['mad'] else 'EXCEEDS the MAD'}")

    # ================================================ TEST 3 · linear trend in x,y
    yy, xx = np.nonzero(s1)
    X = tr.c + (xx + 0.5) * res_m
    Y = tr.f - (yy + 0.5) * res_m
    z = ddem[s1]
    A = np.column_stack([np.ones_like(X), (X - X.mean()) / 1000.0, (Y - Y.mean()) / 1000.0])
    coef, *_ = np.linalg.lstsq(A, z, rcond=None)
    pred = A @ coef
    ss_res = float(((z - pred) ** 2).sum())
    ss_tot = float(((z - z.mean()) ** 2).sum())
    r2 = 1 - ss_res / ss_tot if ss_tot else np.nan
    ext_x = (X.max() - X.min()) / 1000.0
    ext_y = (Y.max() - Y.min()) / 1000.0
    print(f"\n--- TEST 3 · linear trend across the property ---")
    print(f"  offset(x,y) = {coef[0]:+.4f} {coef[1]:+.5f}*x_km {coef[2]:+.5f}*y_km   "
          f"R2={r2:.4f}")
    print(f"  implied tilt across the S1 extent: "
          f"x {coef[1] * ext_x:+.4f} m over {ext_x:.1f} km, "
          f"y {coef[2] * ext_y:+.4f} m over {ext_y:.1f} km")
    tilt = max(abs(coef[1] * ext_x), abs(coef[2] * ext_y))
    print(f"  largest implied tilt {tilt:.4f} m vs pixel MAD {base['mad']:.4f} m  ->  "
          f"{'within MAD' if tilt <= base['mad'] else 'EXCEEDS the MAD'}")
    rows.append(dict(scope="linear_trend", label="OLS offset ~ x_km + y_km",
                     n=int(z.size), median_offset_m=round(float(coef[0]), 5),
                     mean_offset_m="", mad_m="", p05_m="", p95_m="",
                     spread_m=round(float(tilt), 5),
                     note=(f"slope_x={coef[1]:+.6f} m/km, slope_y={coef[2]:+.6f} m/km, "
                           f"R2={r2:.6f}, extent {ext_x:.2f} x {ext_y:.2f} km; "
                           f"spread_m column holds the largest implied tilt")))

    with (OUT_T / "taskU_U3_7_offset_uniformity.csv").open("w", newline="",
                                                           encoding="utf-8") as f:
        w_ = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w_.writeheader()
        w_.writerows(rows)

    print(f"\n{'=' * 78}\nVERDICT INPUTS (the decision is the design seat's)")
    print(f"{'=' * 78}")
    print(f"  pixel MAD                    : {base['mad']:.4f} m")
    print(f"  block-to-block p05-p95 spread: {bst['spread']:.4f} m")
    print(f"  largest implied linear tilt  : {tilt:.4f} m")
    print(f"  uniform within the MAD?      : "
          f"{'YES on all tests' if (uniform_block and tilt <= base['mad']) else 'NO - see above'}")
    print(f"\nwritten: {(OUT_T / 'taskU_U3_7_offset_uniformity.csv').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
