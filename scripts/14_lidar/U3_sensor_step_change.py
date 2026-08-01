#!/usr/bin/env python3
"""Task U · Gate U3 — sensor step-change test on stable ground.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U3 (items 1-6, U3.6 added
by amendment 1 August 2026).

MANDATORY GATE. No change number may be reported before this passes.

-----------------------------------------------------------------------------------
THE SPEC'S SUGGESTED DERIVATION IS CIRCULAR FOR THE FPC TEST, AND IS NOT USED FOR IT
-----------------------------------------------------------------------------------
Gate U3 item 1 offers "otherwise derive from persistently-zero FPC in both epochs".
Selecting pixels where FPC = 0 at BOTH epochs forces the FPC difference to zero BY
CONSTRUCTION, so it would return a perfect "no sensor offset" verdict that means
nothing. The same objection applies to defining stable ground on LiDAR height and
then measuring a height offset.

Stable ground is therefore derived from LANDSAT and from the vegetation class map -
sources entirely independent of the LiDAR under test:

  S1 "bare stable"  flood_zone in {0,1} (never / rarely flooded) AND census
                    total_veg p50 < 30%. Thirty-five Landsat years of persistently
                    low ground cover on ground that does not flood: formed tracks,
                    hardstand, scald, pads. Threshold set from the MEANING of the
                    variable - total_veg = PV + NPV includes litter and dry grass, so
                    the property median is ~82% and genuinely hard ground sits far
                    below it - and NOT from any LiDAR value. Sensitivity at 25/30/40.

  S2 "treed stable" veg_regime_class == 40 (Floodplain Woodland / Forest) AND at
                    least 250 m from any 2018 irrigation bank cut. Mature black box
                    well away from earthworks, per spec item 3. Defined on the class
                    map alone; no LiDAR value enters the definition.

-----------------------------------------------------------------------------------
WHAT THE VERDICT MEANS
-----------------------------------------------------------------------------------
  offset = MEDIAN of (2021 - 2009) on stable ground, per pixel. Median, not mean:
           the difference distribution has tails from residual real change.
  floor  = 95th percentile of |block-mean difference| over 500 m blocks of stable
           ground. It answers the question a reader actually asks - "how big a
           difference can an area of this size show when nothing changed?" - which a
           per-pixel spread does not.

A correction derived at U3.6 is NEVER applied here. It returns to the design seat.

Reads the registered Gate U1 outputs; warps bb5 fresh. Writes CSVs only; the figure
is R (U3_stable_ground_figure.R).

Usage:  python scripts/14_lidar/U3_sensor_step_change.py
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np
import rasterio
from affine import Affine
from rasterio.crs import CRS
from rasterio.features import geometry_mask
from rasterio.warp import Resampling as WR
from rasterio.warp import reproject
from shapely import wkb
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
LIDAR = ROOT / "Input" / "gayini_lidar"
TU = ROOT / "Output" / "rasters" / "task_U"
OUT_T = ROOT / "Output" / "tables"
VEC = ROOT / "Input" / "gayini_vectors_8058.gpkg"

CENSUS_CLS = ROOT / "Output" / "rasters" / "veg_regime_class_8058.tif"
FLOOD_ZONE = ROOT / "Output" / "rasters" / "flood_zone_8058.tif"
VEG_P50 = ROOT / "Output" / "rasters" / "veg_percentiles_8058" / "total_veg_p50_8058.tif"

# --- pre-registered stable-ground definition, set before any LiDAR value was read ---
P50_PRIMARY = 30.0
P50_SENSITIVITY = (25.0, 30.0, 40.0)
DRY_ZONES = (0, 1)                 # flood_zone: never / rarely
TREED_CLASS = 40                   # Floodplain Woodland / Forest
CUT_BUFFER_M = 250.0

BLOCK_M = 500.0                    # block size for the floor and for U3.6
DEM_DECIMATE = 20                  # 50 cm -> 10 m sample for the vertical offset

LADDER = {"bb9": "p05", "bba": "p25", "bbb": "p50", "bbc": "p75",
          "bbd": "p95", "bbe": "p99"}
FOLDERS = {"2009": ("Gayini_2009_GDA1994_z55", "apl1dr_rgayini_2009", "m5"),
           "2021_d4": ("Gayini_2021_GDA2020_z54", "apl4dr_rgayini_2021", "d4"),
           "2021_d5": ("Gayini_2021_GDA2020_z55", "apl4dr_rgayini_2021", "d5")}


def _gpkg_geom(blob: bytes):
    env = {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[(blob[3] >> 1) & 0x07]
    return wkb.loads(blob[8 + env:])


def gpkg_layer(path: Path, layer: str):
    g = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        gcol, srs = g.execute("SELECT column_name, srs_id FROM gpkg_geometry_columns "
                              "WHERE table_name = ?", (layer,)).fetchone()
        if int(srs) != 8058:
            raise SystemExit(f"ABORT: {layer} is EPSG:{srs}, not 8058")
        blobs = [r[0] for r in g.execute(f'SELECT "{gcol}" FROM "{layer}"')]
    finally:
        g.close()
    return unary_union([_gpkg_geom(b) for b in blobs])


def read_like(path: Path, ref_transform, ref_shape, ref_crs, method, dtype, nodata):
    """Reproject any raster onto a reference grid."""
    out = np.full(ref_shape, nodata, dtype=dtype)
    with rasterio.open(path) as s:
        reproject(source=rasterio.band(s, 1), destination=out,
                  src_transform=s.transform, src_crs=s.crs, src_nodata=s.nodata,
                  dst_transform=ref_transform, dst_crs=ref_crs, dst_nodata=nodata,
                  resampling=method)
    return out


def blockify(mask, values, block_px):
    """Mean of `values` over `block_px` x `block_px` blocks, where `mask` holds.
    Returns (block_means, block_counts) for blocks with any masked pixel."""
    h, w = mask.shape
    bh, bw = h // block_px, w // block_px
    m = mask[:bh * block_px, :bw * block_px].reshape(bh, block_px, bw, block_px)
    v = np.where(mask, values, 0.0)[:bh * block_px, :bw * block_px].reshape(
        bh, block_px, bw, block_px)
    cnt = m.sum(axis=(1, 3))
    tot = v.sum(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        means = np.where(cnt > 0, tot / np.maximum(cnt, 1), np.nan)
    return means, cnt


def robust(d):
    d = d[np.isfinite(d)]
    if d.size == 0:
        return dict(n=0, mean="", median="", sd="", iqr="", p05="", p95="", mad="")
    q1, q3 = np.percentile(d, [25, 75])
    return dict(n=int(d.size), mean=round(float(d.mean()), 4),
                median=round(float(np.median(d)), 4), sd=round(float(d.std(ddof=1)), 4),
                iqr=round(float(q3 - q1), 4),
                p05=round(float(np.percentile(d, 5)), 4),
                p95=round(float(np.percentile(d, 95)), 4),
                mad=round(float(np.median(np.abs(d - np.median(d)))), 4))


def main() -> None:
    OUT_T.mkdir(parents=True, exist_ok=True)
    rows, facts = [], []

    def fact(name, value, units="", note=""):
        facts.append(dict(name=name, value=value, units=units, note=note))

    print("=" * 78)
    print("Gate U3 - sensor step-change test on stable ground")
    print("=" * 78)
    print("Stable ground is derived from LANDSAT and the class map, NOT from LiDAR.")
    print("The spec's 'persistently-zero FPC in both epochs' would force the FPC")
    print("difference to zero by construction; see the module docstring.\n")

    # ---------------------------------------------------- stable ground (census grid)
    with rasterio.open(FLOOD_ZONE) as s:
        fz = s.read(1)
        c_tr, c_shape, c_crs, c_res = s.transform, (s.height, s.width), s.crs, s.res
    with rasterio.open(VEG_P50) as s:
        p50 = s.read(1)
    with rasterio.open(CENSUS_CLS) as s:
        cls = s.read(1)
    c_px_ha = c_res[0] * c_res[1] / 1e4

    cuts = gpkg_layer(VEC, "irrigation_bank_cuts")
    near_cuts = geometry_mask([cuts.buffer(CUT_BUFFER_M)], out_shape=c_shape,
                              transform=c_tr, invert=True)

    census = fz != 255
    s1 = {t: census & np.isin(fz, DRY_ZONES) & np.isfinite(p50) & (p50 < t)
          for t in P50_SENSITIVITY}
    s2 = census & (cls == TREED_CLASS) & ~near_cuts

    print(f"{'stable set':<34}{'census px':>12}{'ha':>12}")
    print("-" * 78)
    for t in P50_SENSITIVITY:
        tag = "  <- PRIMARY" if t == P50_PRIMARY else ""
        print(f"S1 bare-stable, p50 < {t:<11.0f}{s1[t].sum():>12,}"
              f"{s1[t].sum() * c_px_ha:>12,.1f}{tag}")
    print(f"{'S2 treed-stable (class 40, >250 m from cuts)':<34}"[:34] +
          f"{s2.sum():>12,}{s2.sum() * c_px_ha:>12,.1f}")
    print(f"{'  (class 40 before the cut buffer)':<34}{(census & (cls == TREED_CLASS)).sum():>12,}"
          f"{(census & (cls == TREED_CLASS)).sum() * c_px_ha:>12,.1f}")
    for t in P50_SENSITIVITY:
        fact(f"s1_bare_stable_ha_p50lt{t:.0f}", round(s1[t].sum() * c_px_ha, 3), "ha",
             "primary" if t == P50_PRIMARY else "sensitivity")
    fact("s2_treed_stable_ha", round(s2.sum() * c_px_ha, 3), "ha",
         f"class {TREED_CLASS}, >= {CUT_BUFFER_M:g} m from any 2018 bank cut")

    SETS = {"S1_bare_stable": s1[P50_PRIMARY], "S2_treed_stable": s2}

    # ============================================================ FPC, 10 m grid
    with rasterio.open(TU / "taskU_bbh_fpc_2009_8058_10m.tif") as s:
        g10_tr, g10_shape, g10_crs, g10_res = s.transform, (s.height, s.width), s.crs, s.res
        fpc09 = s.read(1).astype("float32")
        fpc09[s.read(1) == 255] = np.nan
    with rasterio.open(TU / "taskU_bbh_fpc_2021_8058_10m.tif") as s:
        raw = s.read(1)
        fpc21 = raw.astype("float32")
        fpc21[raw == 255] = np.nan
    g10_px_ha = g10_res[0] * g10_res[1] / 1e4
    block10 = int(round(BLOCK_M / g10_res[0]))

    masks10 = {}
    for name, m in SETS.items():
        a = np.zeros(g10_shape, dtype="float32")
        reproject(source=m.astype("float32"), destination=a, src_transform=c_tr,
                  src_crs=c_crs, dst_transform=g10_tr, dst_crs=g10_crs,
                  resampling=WR.nearest)
        masks10[name] = (a > 0.5) & np.isfinite(fpc09) & np.isfinite(fpc21)

    dfpc = fpc21 - fpc09
    print(f"\n--- item 2/3 · FPC (bbh, 10 m, percent) on stable ground ---")
    print(f"{'set':<18}{'n px':>10}{'ha':>10}{'2009 med':>10}{'2021 med':>10}"
          f"{'diff med':>10}{'diff mean':>11}{'diff IQR':>10}")
    print("-" * 78)
    for name, m in masks10.items():
        a, b, d = robust(fpc09[m]), robust(fpc21[m]), robust(dfpc[m])
        print(f"{name:<18}{d['n']:>10,}{d['n'] * g10_px_ha:>10,.1f}"
              f"{a['median']:>10.3f}{b['median']:>10.3f}{d['median']:>10.3f}"
              f"{d['mean']:>11.3f}{d['iqr']:>10.3f}")
        for label, st, ep in (("fpc_2009", a, "2009"), ("fpc_2021", b, "2021"),
                              ("fpc_diff", d, "2021-2009")):
            rows.append(dict(stable_set=name, product="bbh_fpc", units="percent",
                             grain="pixel_10m", epoch=ep, **st))

    # ---------------------------------------------------- the floor (block scale)
    print(f"\n--- item 4 · block-scale behaviour, {BLOCK_M:g} m blocks ---")
    print(f"{'set':<18}{'blocks':>9}{'blk med':>10}{'blk p05':>10}{'blk p95':>10}"
          f"{'|blk| p95':>11}")
    print("-" * 78)
    floors = {}
    for name, m in masks10.items():
        bm, cnt = blockify(m, np.nan_to_num(dfpc), block10)
        keep = cnt >= (block10 * block10 * 0.02)   # >= 2% of the block is stable ground
        v = bm[keep]
        v = v[np.isfinite(v)]
        f95 = float(np.percentile(np.abs(v), 95)) if v.size else float("nan")
        floors[name] = f95
        print(f"{name:<18}{v.size:>9,}{np.median(v):>10.3f}"
              f"{np.percentile(v, 5):>10.3f}{np.percentile(v, 95):>10.3f}{f95:>11.3f}")
        rows.append(dict(stable_set=name, product="bbh_fpc", units="percent",
                         grain=f"block_{BLOCK_M:.0f}m", epoch="2021-2009", **robust(v)))
        fact(f"fpc_block_abs_p95_{name}", round(f95, 4), "FPC pp",
             f"95th percentile of |block-mean difference|, {BLOCK_M:g} m blocks")

    off_bare = float(np.median(dfpc[masks10["S1_bare_stable"]]))
    off_treed = float(np.median(dfpc[masks10["S2_treed_stable"]]))

    # --- dynamic range of S1: a control that is zero at both epochs cannot detect a
    # multiplicative or vegetation-dependent sensor difference, only an additive one
    # at zero. Quantify that limitation rather than leaving it as a caveat in prose.
    s1m = masks10["S1_bare_stable"]
    nz = ((fpc09[s1m] > 0) | (fpc21[s1m] > 0)).mean() * 100
    print(f"\nS1 dynamic-range check: {nz:.2f}% of S1 pixels are non-zero FPC at either "
          f"epoch.\n  A control that reads zero at both epochs bounds an ADDITIVE offset "
          f"at zero only.\n  It cannot bound a vegetation-dependent or multiplicative "
          f"sensor difference.")
    fact("s1_pct_nonzero_fpc_either_epoch", round(float(nz), 4), "percent",
         "dynamic-range limitation of the bare-stable control")

    # --- item 4 needs the OBSERVED change to compare the floor against -----------
    both = np.isfinite(fpc09) & np.isfinite(fpc21)
    obs = robust(dfpc[both])
    bm_all, cnt_all = blockify(both, np.nan_to_num(dfpc), block10)
    keep_all = (cnt_all >= block10 * block10 * 0.02) & np.isfinite(bm_all)
    obs_blocks = bm_all[keep_all]
    print(f"\n--- item 4 · OBSERVED whole-of-property FPC change, for comparison ---")
    print(f"  denominator: Task U both-valid, on-property, 10 m")
    print(f"  per pixel : median {obs['median']:+.3f}  mean {obs['mean']:+.3f}  "
          f"IQR {obs['iqr']:.3f}  (n {obs['n']:,})")
    print(f"  {BLOCK_M:g} m blocks: median {np.median(obs_blocks):+.3f}  "
          f"p05 {np.percentile(obs_blocks, 5):+.3f}  "
          f"p95 {np.percentile(obs_blocks, 95):+.3f}  (n {obs_blocks.size:,})")
    rows.append(dict(stable_set="ALL_on_property_both_valid", product="bbh_fpc",
                     units="percent", grain="pixel_10m", epoch="2021-2009", **obs))
    rows.append(dict(stable_set="ALL_on_property_both_valid", product="bbh_fpc",
                     units="percent", grain=f"block_{BLOCK_M:.0f}m", epoch="2021-2009",
                     **robust(obs_blocks)))
    fact("fpc_observed_change_median_all", obs["median"], "FPC pp",
         "on-property both-valid, per pixel")
    fact("fpc_observed_change_mean_all", obs["mean"], "FPC pp",
         "on-property both-valid, per pixel")

    # --- does bbh carry any signal here at all? ---------------------------------
    # FPC is a WOODY cover product and Gayini is largely treeless chenopod
    # shrubland. If most of the property reads zero at both epochs, the
    # whole-of-property difference statistic is dominated by ground where the
    # instrument has no dynamic range, and the mean above is diluted rather than
    # informative. Quantify it instead of arguing about it.
    woody = both & ((fpc09 > 0) | (fpc21 > 0))
    pct_woody = 100.0 * woody.sum() / both.sum()
    obs_w = robust(dfpc[woody])
    print(f"\n--- bbh dynamic range on the property ---")
    print(f"  pixels with FPC > 0 at either epoch : {woody.sum():,} of {both.sum():,} "
          f"= {pct_woody:.2f}% ({woody.sum() * g10_px_ha:,.1f} ha)")
    print(f"  change on THAT subset only          : median {obs_w['median']:+.3f}  "
          f"mean {obs_w['mean']:+.3f}  IQR {obs_w['iqr']:.3f}  p05 {obs_w['p05']:+.3f}  "
          f"p95 {obs_w['p95']:+.3f}")
    rows.append(dict(stable_set="ALL_on_property_woody_either_epoch", product="bbh_fpc",
                     units="percent", grain="pixel_10m", epoch="2021-2009", **obs_w))
    fact("fpc_pct_nonzero_either_epoch_on_property", round(float(pct_woody), 4),
         "percent", "dynamic range of bbh on the property")
    fact("fpc_woody_area_ha", round(float(woody.sum() * g10_px_ha), 3), "ha",
         "FPC > 0 at either epoch, on-property both-valid")
    fact("fpc_offset_median_S1_bare", round(off_bare, 4), "FPC pp", "per pixel")
    fact("fpc_offset_median_S2_treed", round(off_treed, 4), "FPC pp", "per pixel")

    # ================================================== height ladder, 5 m grid
    with rasterio.open(TU / "taskU_bbd_p95_height_2009_8058_5m.tif") as s:
        g5_tr, g5_shape, g5_crs, g5_res = s.transform, (s.height, s.width), s.crs, s.res
    masks5 = {}
    for name, m in SETS.items():
        a = np.zeros(g5_shape, dtype="float32")
        reproject(source=m.astype("float32"), destination=a, src_transform=c_tr,
                  src_crs=c_crs, dst_transform=g5_tr, dst_crs=g5_crs,
                  resampling=WR.nearest)
        masks5[name] = a > 0.5

    print(f"\n--- item 2/3 · height ladder (5 m, metres) on stable ground ---")
    print(f"{'set':<18}{'stage':<7}{'n px':>10}{'2009 med':>10}{'2021 med':>10}"
          f"{'diff med':>10}{'diff mean':>11}{'diff IQR':>10}")
    print("-" * 78)
    for stage, plab in LADDER.items():
        h09 = rasterio.open(TU / f"taskU_{stage}_{plab}_height_2009_8058_5m.tif").read(1)
        h21 = rasterio.open(TU / f"taskU_{stage}_{plab}_height_2021_8058_5m.tif").read(1)
        d = h21 - h09
        for name, m in masks5.items():
            mm = m & np.isfinite(h09) & np.isfinite(h21)
            a, b, dd = robust(h09[mm]), robust(h21[mm]), robust(d[mm])
            if stage in ("bbd", "bbb"):
                print(f"{name:<18}{stage:<7}{dd['n']:>10,}{a['median']:>10.3f}"
                      f"{b['median']:>10.3f}{dd['median']:>10.3f}{dd['mean']:>11.3f}"
                      f"{dd['iqr']:>10.3f}")
            for st, ep in ((a, "2009"), (b, "2021"), (dd, "2021-2009")):
                rows.append(dict(stable_set=name, product=f"{stage}_{plab}_height",
                                 units="metres", grain="pixel_5m", epoch=ep, **st))
            if stage == "bbd":
                fact(f"height_p95_offset_median_{name}", dd["median"], "m",
                     "bbd 95th-percentile height, per pixel")
        del h09, h21, d
    print("   (bbb / bbd shown; all six stages are in the CSV)")

    # ================================== item 5 · bb0 stable-ground vertical offset
    print(f"\n--- item 5 · bb0 vertical offset on stable ground "
          f"(50 cm decimated 1/{DEM_DECIMATE}) ---")
    dems = {}
    for epoch in ("2009", "2021"):
        with rasterio.open(TU / f"taskU_bb0_dem_{epoch}_8058_50cm.tif") as s:
            oh, ow = s.height // DEM_DECIMATE, s.width // DEM_DECIMATE
            a = s.read(1, out_shape=(oh, ow), resampling=WR.average)
            tr = s.transform * Affine.scale(DEM_DECIMATE, DEM_DECIMATE)
        dems[epoch] = (a, tr, (oh, ow), s.crs)
    a09, tr_d, sh_d, crs_d = dems["2009"]
    a21 = np.full(sh_d, np.nan, dtype="float32")
    reproject(source=dems["2021"][0], destination=a21, src_transform=dems["2021"][1],
              src_crs=dems["2021"][3], src_nodata=np.nan, dst_transform=tr_d,
              dst_crs=crs_d, dst_nodata=np.nan, resampling=WR.bilinear)
    ddem = a21 - a09
    print(f"{'set':<18}{'n px':>10}{'med diff':>11}{'mean diff':>11}{'IQR':>9}"
          f"{'MAD':>9}{'p05':>9}{'p95':>9}")
    print("-" * 78)
    for name, m in SETS.items():
        mk = np.zeros(sh_d, dtype="float32")
        reproject(source=m.astype("float32"), destination=mk, src_transform=c_tr,
                  src_crs=c_crs, dst_transform=tr_d, dst_crs=crs_d, resampling=WR.nearest)
        mm = (mk > 0.5) & np.isfinite(ddem)
        st = robust(ddem[mm])
        print(f"{name:<18}{st['n']:>10,}{st['median']:>11.4f}{st['mean']:>11.4f}"
              f"{st['iqr']:>9.4f}{st['mad']:>9.4f}{st['p05']:>9.4f}{st['p95']:>9.4f}")
        rows.append(dict(stable_set=name, product="bb0_dem", units="metres",
                         grain=f"pixel_{0.5 * DEM_DECIMATE:g}m_decimated",
                         epoch="2021-2009", **st))
        fact(f"dem_vertical_offset_median_{name}", st["median"], "m",
             f"stable-ground vertical offset, 50 cm decimated 1/{DEM_DECIMATE}")
    del a09, a21, dems

    # ============================================== U3.6 · density-scaling test
    print(f"\n--- U3.6 · does the FPC offset scale with the bb5 density difference? ---")
    dens = {}
    for epoch, tiles in (("2009", ["2009"]), ("2021", ["2021_d4", "2021_d5"])):
        arrs = []
        for t in tiles:
            folder, prefix, proj = FOLDERS[t]
            arrs.append(read_like(LIDAR / folder / f"{prefix}_bb5{proj}_r50cm.tif",
                                  g10_tr, g10_shape, g10_crs, WR.average,
                                  "float32", np.nan))
        if len(arrs) == 1:
            dens[epoch] = arrs[0]
        else:                                   # R1: d4 precedence, d5 fill
            a4, a5 = arrs
            gap = np.isnan(a4)
            a4[gap] = a5[gap]
            dens[epoch] = a4
        del arrs
    ddens = dens["2021"] - dens["2009"]

    u36, blocks_out = [], []
    for name, m in masks10.items():
        mm = m & np.isfinite(ddens) & np.isfinite(dfpc)
        bf, cf = blockify(mm, np.nan_to_num(dfpc), block10)
        bd, _ = blockify(mm, np.nan_to_num(ddens), block10)
        keep = (cf >= block10 * block10 * 0.02) & np.isfinite(bf) & np.isfinite(bd)
        x, y = bd[keep], bf[keep]
        if x.size < 10:
            print(f"   {name}: too few blocks ({x.size}) - not testable")
            continue
        slope, intercept = np.polyfit(x, y, 1)
        pred = slope * x + intercept
        ss_res = float(((y - pred) ** 2).sum())
        ss_tot = float(((y - y.mean()) ** 2).sum())
        r2 = 1 - ss_res / ss_tot if ss_tot else float("nan")
        resid_sd = float(np.std(y - pred, ddof=2))
        r = float(np.corrcoef(x, y)[0, 1])
        print(f"   {name}: n_blocks={x.size:,}  slope={slope:.4f} FPC pp per "
              f"return/m2  intercept={intercept:.4f}  r={r:.4f}  R2={r2:.4f}  "
              f"resid SD={resid_sd:.4f}")
        print(f"      mean density difference on this set = {x.mean():+.4f} "
              f"(2009 {np.nanmedian(dens['2009'][m]):.4f} -> 2021 "
              f"{np.nanmedian(dens['2021'][m]):.4f})")
        blocks_out.extend(dict(stable_set=name, density_diff=round(float(xi), 5),
                               fpc_diff=round(float(yi), 5))
                          for xi, yi in zip(x, y))
        u36.append(dict(stable_set=name, n_blocks=int(x.size),
                        slope_fpc_pp_per_density=round(float(slope), 6),
                        intercept_fpc_pp=round(float(intercept), 6),
                        pearson_r=round(r, 6), r_squared=round(float(r2), 6),
                        residual_sd_fpc_pp=round(resid_sd, 6),
                        mean_density_diff=round(float(x.mean()), 6),
                        median_density_2009=round(float(np.nanmedian(dens["2009"][m])), 6),
                        median_density_2021=round(float(np.nanmedian(dens["2021"][m])), 6),
                        block_m=BLOCK_M))
        fact(f"u36_slope_{name}", round(float(slope), 6), "FPC pp per return/m2", "")
        fact(f"u36_r2_{name}", round(float(r2), 6), "", "")

    # ------------------------------------------------------------------ outputs
    with (OUT_T / "taskU_gateU3_stable_ground.csv").open("w", newline="",
                                                         encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    if u36:
        with (OUT_T / "taskU_gateU3_density_scaling.csv").open("w", newline="",
                                                               encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(u36[0].keys()))
            w.writeheader()
            w.writerows(u36)
    if blocks_out:
        with (OUT_T / "taskU_gateU3_u36_blocks.csv").open("w", newline="",
                                                          encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(blocks_out[0].keys()))
            w.writeheader()
            w.writerows(blocks_out)
    with (OUT_T / "taskU_gateU3_facts.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["name", "value", "units", "note"])
        w.writeheader()
        w.writerows(facts)

    print(f"\n{'=' * 78}\nVERDICT INPUTS (the verdict itself is a design-seat decision)")
    print(f"{'=' * 78}")
    print(f"  FPC offset, bare stable   : {off_bare:+.3f} FPC pp (median, per pixel)")
    print(f"  FPC offset, treed stable  : {off_treed:+.3f} FPC pp (median, per pixel)")
    for k, v in floors.items():
        print(f"  |block-mean| p95, {k:<16}: {v:.3f} FPC pp  ({BLOCK_M:g} m blocks)")
    print(f"\nwritten: Output/tables/taskU_gateU3_{{stable_ground,density_scaling,facts}}.csv")


if __name__ == "__main__":
    main()
