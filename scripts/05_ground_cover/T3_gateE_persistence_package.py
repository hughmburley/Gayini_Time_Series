"""T3 Gate C surfaces + Gate E component analysis.

Spec: docs/T3_always_green_threshold.md v3, Gates C and E.
Decisions: T3 Gate D design-seat decisions, 3 August 2026.

DECISION 1 CONSEQUENCE - THREE THRESHOLDS, NOT ONE. Gate B1 found a smooth
area-threshold decline with no knee, so refugial extent is a continuum and no single
cut is a measured boundary. The overlay therefore runs at t = 75 (primary, most
stable point in the window), 79 (max components, wetness plateau) and 82 (lower
bound). If the LiDAR result holds at all three it is threshold-independent; if it
holds at only one, the overlay is measuring the cut and not the country.

SCOPE. The boolean surfaces are non_treed (9 strata, treed_context_flag = 0 AND
regime_band <> 'context'). Treed Floodplain Woodland is context and is excluded from
reporting entirely, and the LiDAR shrub-height model is about non-treed structure.

CHANNEL LAYER: ABSENT. Spec Gate E point 3 asks for distance to the nearest mapped
channel "if a channel layer is registered (report absent if not)". No channel or
watercourse layer is registered in spatial_layer_asset (9 rows) or present anywhere
under Input/. The only hydrological geometry available is irrigation_bank_cuts
(1,158 points) which is Task J IRRIGATION INFRASTRUCTURE, not natural channel, and
substituting it would be a category error. Distance-to-channel is therefore recorded
as NULL with the reason, and mean flood frequency is used as the available PROXY -
which is a proxy, not a channel test, and the change report says so.
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

import duckdb
import numpy as np
import rasterio
from rasterio.transform import Affine
from scipy import ndimage

sys.path.insert(0, str(Path("scripts") / "lib"))
import gayini_params as gp  # noqa: E402

DB = Path("Output") / "database" / "Gayini_Results.sqlite"
CENSUS = Path("Output") / "census" / "gayini_pixel_census_8058.parquet"
GRID_TIF = Path("Output") / "rasters" / "veg_regime_class_8058.tif"
GREEN_TIF = Path("Output") / "rasters" / "persistence_8058" / "green_share_at_floor_8058.tif"
OUT_RAS = Path("Output") / "rasters" / "persistence_8058"
OUT_TAB = Path("Output") / "tables"
RUN_ID = "T3_gateE"

MIN_COMPONENT_HA = 5.0
MIN_COMPONENT_PX = int(np.ceil(MIN_COMPONENT_HA / gp.PIXEL_AREA_HA))

SURFACES = [
    ("total_cover_floor", 75, "primary"),
    ("total_cover_floor", 79, "sensitivity_max_components"),
    ("total_cover_floor", 82, "sensitivity_lower_bound"),
    ("green_share_floor", 50, "primary_majority_green"),
]


def sha256_first50(path: Path) -> str:
    d, rem = hashlib.sha256(), 50 * 1024 * 1024
    with open(path, "rb") as f:
        while rem > 0:
            c = f.read(1024 * 1024)
            if not c:
                break
            d.update(c[:rem])
            rem -= len(c)
    return d.hexdigest()


def load():
    df = duckdb.connect().execute(f"""
        SELECT x_8058, y_8058, veg_p05, flood_freq_pct, treed_context_flag, regime_band
        FROM read_parquet('{CENSUS.as_posix()}')
    """).fetchdf()
    with rasterio.open(GRID_TIF) as src:
        tr, H, W, crs = src.transform, src.height, src.width, src.crs
    col = np.floor((df["x_8058"].to_numpy() - tr.c) / abs(tr.a)).astype(np.int32)
    row = np.floor((tr.f - df["y_8058"].to_numpy()) / abs(tr.e)).astype(np.int32)
    with rasterio.open(GREEN_TIF) as src:
        green = src.read(1, masked=True).filled(np.nan)[row, col]
    treed = df["treed_context_flag"].to_numpy(bool)
    band = df["regime_band"].to_numpy(object)
    return dict(row=row, col=col, H=H, W=W, tr=tr, crs=crs,
                p05=df["veg_p05"].to_numpy(np.float64), green=green,
                ff=df["flood_freq_pct"].to_numpy(np.float64),
                non_treed=(~treed) & (band != "context"))


def zone_membership(A):
    """Which census pixels fall inside a reference paddock (reference_set_member = 1)."""
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    fids = [r[0] for r in con.execute(
        "SELECT zone_fid FROM dim_management_zone WHERE reference_set_member = 1")]
    con.close()
    zp = Path("Output") / "census" / "gayini_pixel_zone_assignment.parquet"
    cols = duckdb.connect().execute(
        f"DESCRIBE SELECT * FROM read_parquet('{zp.as_posix()}')").fetchdf()["column_name"].tolist()
    zcol = next(c for c in cols if "zone_fid" in c)
    z = duckdb.connect().execute(
        f"SELECT {zcol} AS zf FROM read_parquet('{zp.as_posix()}')").fetchdf()["zf"].to_numpy()
    return np.isin(z, fids), fids


def main():
    gp.validate()
    A = load()
    in_ref, ref_fids = zone_membership(A)
    print(f"reference paddocks: zone_fid {ref_fids}; "
          f"{int(in_ref.sum()):,} census px inside them")
    OUT_RAS.mkdir(parents=True, exist_ok=True)

    s8 = ndimage.generate_binary_structure(2, 2)
    comp_rows, reg_rows = [], []

    for metric, thr, role in SURFACES:
        vals = A["p05"] if metric == "total_cover_floor" else A["green"]
        sel = A["non_treed"] & np.isfinite(vals) & (vals >= thr)

        mask = np.zeros((A["H"], A["W"]), np.uint8)
        mask[A["row"][sel], A["col"][sel]] = 1
        lab, n = ndimage.label(mask.astype(bool), structure=s8)
        sizes = np.bincount(lab.ravel())
        keep = np.where(sizes[1:] >= MIN_COMPONENT_PX)[0] + 1

        # per-component stats, from the census arrays not the raster
        lab_px = lab[A["row"], A["col"]]
        for cid in keep:
            m = lab_px == cid
            npx = int(m.sum())
            comp_rows.append(dict(
                metric=metric, threshold=thr, role=role, component_id=int(cid),
                n_pixels=npx, area_ha=npx * gp.PIXEL_AREA_HA,
                flood_freq_mean=float(np.mean(A["ff"][m])),
                flood_freq_median=float(np.median(A["ff"][m])),
                pct_in_reference_paddock=float(100.0 * in_ref[m].mean()),
                in_reference_paddock=int(in_ref[m].mean() > 0.5),
                dist_to_nearest_channel_m=None,
                dist_to_channel_status="ABSENT - no channel layer registered",
                pixel_area_ha=gp.PIXEL_AREA_HA, support_level="pixel",
                scope_filter_sql=gp.SCOPE_NON_TREED, grid_epsg=8058, run_id=RUN_ID))

        # write the boolean surface, components >= 5 ha ONLY (that is the product)
        keep_mask = np.isin(lab, keep).astype(np.uint8)
        out = OUT_RAS / f"persistence_{metric}_ge{thr}_8058.tif"
        with rasterio.open(
                out, "w", driver="GTiff", height=A["H"], width=A["W"], count=1,
                dtype="uint8", crs=A["crs"], transform=A["tr"], nodata=255,
                compress="deflate") as dst:
            dst.write(keep_mask, 1)

        # ALSO write the COMPONENT-ID raster. The GeoPackage must be polygonised by
        # this, not by re-splitting the boolean: scipy labels with 8-connectivity
        # (queen), but polygonising a boolean and casting MULTIPOLYGON -> POLYGON
        # splits at every diagonal pinch point (rook), which silently turned 40
        # green-share components into 26 polygons and dropped 219 ha when the
        # sub-parts fell back under the 5 ha filter. Dissolving by component id
        # keeps the vector product identical to the raster and the component table.
        lab_keep = np.where(np.isin(lab, keep), lab, 0).astype(np.int32)
        out_lab = OUT_RAS / f"persistence_{metric}_ge{thr}_components_8058.tif"
        with rasterio.open(
                out_lab, "w", driver="GTiff", height=A["H"], width=A["W"], count=1,
                dtype="int32", crs=A["crs"], transform=A["tr"], nodata=0,
                compress="deflate") as dst:
            dst.write(lab_keep, 1)

        n_keep = int(keep_mask.sum())
        print(f"  {metric} >= {thr:<3} : {int(sel.sum()):>7,} px -> "
              f"{len(keep):>3} components >= 5 ha, {n_keep:>7,} px = "
              f"{n_keep * gp.PIXEL_AREA_HA:>9,.2f} ha  [{role}]")
        reg_rows.append((metric, thr, role, out, len(keep), n_keep))

    import pandas as pd
    comp = pd.DataFrame(comp_rows)
    OUT_TAB.mkdir(parents=True, exist_ok=True)
    comp.to_csv(OUT_TAB / "T3_persistence_vs_hydrology.csv", index=False)
    print(f"\nwrote {OUT_TAB / 'T3_persistence_vs_hydrology.csv'} ({len(comp)} components)")

    # ---- register the boolean surfaces ------------------------------------
    con = sqlite3.connect(DB)
    for metric, thr, role, path, ncomp, npx in reg_rows:
        if metric == "total_cover_floor":
            mdef = ("TOTAL-COVER FLOOR: census veg_p05 >= %d, the across-series 5th percentile "
                    "of total veg (green PV + non-green NPV) per pixel over 140 seasonal FC "
                    "composites WY1988-2023." % thr)
        else:
            mdef = ("GREEN-SHARE FLOOR: 100 * PV / total_veg >= %d, read PAIRED in the season "
                    "that sets each pixel's total-veg 5th-percentile order statistic. "
                    "MEASURED on the native 30 m EPSG:3577 grid (71,755 px = 6,457.95 ha at "
                    "> 50); this 8058 surface is a bilinear reprojection thresholded on the "
                    "8058 grid, which is a DIFFERENT operation - never quote its area as the "
                    "measured area." % thr)
        legend = (
            f"T3 persistence boolean surface, 1 = persistent, 0 = not, 255 = nodata. {mdef} "
            f"THRESHOLD ROLE: {role}. NO HEADLINE THRESHOLD EXISTS. Gate B1 measured a smooth "
            f"area-threshold decline with no knee (elasticity 8.0%/pp at 75 rising monotonically "
            f"to 69.0%/pp at 84), so refugial extent is a CONTINUUM and this cut is a chosen "
            f"operational input for the LiDAR overlay, NOT a measured boundary. The overlay runs "
            f"at t=75/79/82 and a result that holds at only one of them is measuring the cut. "
            f"Scope: {gp.SCOPE_NON_TREED} (9 strata, 988,829 px with finite p05). "
            f"Components < {MIN_COMPONENT_HA} ha are REMOVED from this surface: {ncomp} "
            f"components retained, {npx:,} px = {npx * gp.PIXEL_AREA_HA:,.2f} ha at "
            f"pixel_area_ha = {gp.PIXEL_AREA_HA}. Connectivity 8 (queen); the queen/rook choice "
            f"changes component counts by at most 2 at every candidate cut. "
            f"CAVEAT: FC is natively 30 m, bilinear-resampled onto the 24.97 m census grid - "
            f"polygon edges are finer than the source supports.")
        e = (A["tr"].c, A["tr"].f + A["tr"].e * A["H"],
             A["tr"].c + A["tr"].a * A["W"], A["tr"].f)
        con.execute(
            "INSERT OR REPLACE INTO raster_asset "
            "(raster_asset_id, path, metric_id, water_year, period_label, crs, resolution_x, "
            " resolution_y, xmin, ymin, xmax, ymax, checksum_sha256, path_exists, qa_status, "
            " run_id, crs_epsg, product, legend_status, legend_semantics, superseded_flag) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (f"raster_t3_persistence_{metric}_ge{thr}_8058", path.as_posix(),
             f"persistence_{metric}", None, "WY1988-2023 across-series", "EPSG:8058",
             abs(A["tr"].a), abs(A["tr"].e), e[0], e[1], e[2], e[3],
             sha256_first50(path), 1, "REVIEW", RUN_ID, 8058,
             "persistence_boolean_8058", "confirmed", legend, 0))
    con.commit()
    con.close()

    # ---- summary ----------------------------------------------------------
    print("\n=== components by metric/threshold ===")
    g = comp.groupby(["metric", "threshold"]).agg(
        n_components=("component_id", "count"), total_ha=("area_ha", "sum"),
        ff_mean=("flood_freq_mean", "mean"), largest_ha=("area_ha", "max"),
        n_in_ref=("in_reference_paddock", "sum"))
    print(g.to_string())

    print("\n=== the substantive test: do persistent components sit on wet ground? ===")
    print("  (mean flood frequency is a PROXY - no channel layer is registered)")
    for (m, t), sub in comp.groupby(["metric", "threshold"]):
        w = np.average(sub.flood_freq_mean, weights=sub.area_ha)
        print(f"  {m} >= {t:<3}: area-weighted mean flood freq {w:5.2f}%  "
              f"(range {sub.flood_freq_mean.min():5.2f} - {sub.flood_freq_mean.max():5.2f}), "
              f"n={len(sub)}")
    base_nt = float(np.mean(A["ff"][A["non_treed"]]))
    print(f"  non_treed baseline (all 988,831 px): {base_nt:.2f}%")


if __name__ == "__main__":
    main()
