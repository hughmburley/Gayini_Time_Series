#!/usr/bin/env python
"""UNZONED v3 section 6 - the assembly: patch summary, coefficient table, polygons,
manifest.

Every output carries its support level, metric, unit construction, selection rule and
period INSIDE the file, not only in the filename (section 6).

THE PATCH SUMMARY CARRIES BOTH FLOOR METRICS, NAMED DISTINCTLY AND NEVER PAIRED AS ONE
QUANTITY. `veg_p05_spatial_mean_over_years` is Arm B's metric - a percentile across the
patch's cells within a year, averaged over years. `veg_p05_temporal_mean` is Arm A's - each
cell's percentile across the record, averaged over the patch's cells. They sit in one
table because a summary has to carry both, and the table says which is which in a column
and in the dictionary. They are never co-plotted and never differenced.

MANIFEST: every table the findings note asserts from is listed with its checksum. The
PARTREG pack omitted the community-slope coefficients and section 6 says that must not
repeat, so the coefficient table is listed explicitly.

Checksum convention: first-50-MB SHA-256, the project's single convention.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "unzoned"
T = ROOT / "Output" / "tables"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
PERIOD = "1988-2022 (35 water years)"
LAND_USE = "unzoned standard-grazing country"
UNIT_CONSTRUCTION = ("8-connected component within one vegetation community, outside "
                     "every management zone")


def sha256_first50(path: Path) -> str:
    return hashlib.sha256(path.open("rb").read(50 * 1024 * 1024)).hexdigest()


def main() -> int:
    # ---------------------------------------------------------------- patch summary
    allp = pd.read_csv(OUT / "UNZONED_v3_armA_all_patches.csv")
    py = pd.read_csv(OUT / "UNZONED_v3_armB_patch_year.csv")
    sl = pd.read_csv(OUT / "UNZONED_v3_armB_per_patch_slopes.csv")
    off = pd.read_csv(OUT / "UNZONED_v3_armA_per_patch_offsets.csv")

    spatial = (py.groupby("patch_id")
                 .agg(veg_p05_spatial_mean_over_years=("veg_p05_spatial", "mean"),
                      mean_share_cells_wet_armB=("inund_pct", "mean"),
                      n_years_fitted=("water_year", "size")).reset_index())

    s = allp[["patch_id", "community", "community_short", "n_cells", "area_ha",
              "veg_p05_temporal_mean", "veg_p05_within_sd", "mean_share_cells_wet",
              "n_years_ge30_valid", "meets_support_rule", "meets_bare_33_cells",
              "meets_500_cells", "size_matched"]].copy()
    s = s.merge(spatial, on="patch_id", how="left")
    s = s.merge(sl[["patch_id", "slope", "r", "ac1_resid", "fitted"]]
                .rename(columns={"slope": "within_patch_slope",
                                 "r": "within_patch_r",
                                 "ac1_resid": "within_patch_resid_ac1",
                                 "fitted": "within_patch_fitted"}),
                on="patch_id", how="left")
    s = s.merge(off[["patch_id", "descriptive_offset_pp", "offset_note"]],
                on="patch_id", how="left")

    # residuals against BOTH registered spatial lines
    co = pd.read_csv(T / "PARTREG_part_regression_coefficients.csv")
    r115 = co[co.fit_id == "2.3_weighted"].iloc[0]
    a115, b115 = float(r115.intercept), float(r115.slope)
    a64, b64 = 52.652934, 0.547838
    s["residual_vs_registered_115part_line"] = (
        s.veg_p05_spatial_mean_over_years - (a115 + b115 * s.mean_share_cells_wet_armB))
    s["residual_vs_registered_64paddock_line"] = (
        s.veg_p05_spatial_mean_over_years - (a64 + b64 * s.mean_share_cells_wet_armB))

    # each patch IS one 8-connected component by construction - stated, not omitted
    s["n_components"] = 1
    s["n_components_note"] = ("1 by construction: a patch is defined as a single "
                              "8-connected component, unlike a real part which may be "
                              "several")
    s["metric_note"] = ("veg_p05_spatial_mean_over_years and veg_p05_temporal_mean are "
                        "DIFFERENT METRICS and are never co-plotted, differenced or "
                        "captioned with one word. Arm B uses the first, Arm A the second.")
    s["descriptive_offset_note"] = ("offset is against Arm A's zoned DISPLAY SMOOTHER on "
                                    "the temporal metric: not a residual and not a test. "
                                    "NA where the patch is outside the zoned water range.")
    s["registered_lines_note"] = (f"115-part: {a115:.6f} + {b115:.6f} x mean water; "
                                  f"64-paddock: {a64:.6f} + {b64:.6f} x mean water. "
                                  "Both APPLIED, neither refitted.")
    s["unit_construction"] = UNIT_CONSTRUCTION
    s["selection_rule"] = ("meets_support_rule = >=25 water years with >=30 valid cells; "
                           "meets_500_cells = the PARTSCATTER floor used by Arm A; "
                           "meets_bare_33_cells = v1's threshold, for contrast; "
                           "size_matched = inside this community's real-part IQR")
    s["support_level"] = "pixel"
    s["period_label"] = PERIOD
    s["land_use_label"] = LAND_USE
    s["pixel_constant_ha"] = PIXEL_AREA_HA
    s = s.sort_values("patch_id").reset_index(drop=True)
    s.to_csv(OUT / "UNZONED_patch_summary.csv", index=False, lineterminator="\n")
    print(f"[summary] UNZONED_patch_summary.csv  {len(s)} patches, "
          f"{s.meets_support_rule.sum()} supported")

    # ---------------------------------------------------- the coefficient table
    frames = []
    wf = pd.read_csv(OUT / "UNZONED_v3_armB_within_fits.csv")
    for _, r in wf.iterrows():
        frames.append({
            "fit_id": f"UNZONED_v3_within_{r.scope}",
            "description": r.label, "estimator": "WITHIN (patch fixed effects)",
            "metric": "veg_p05_spatial", "y_variable": r.y_variable,
            "x_variable": r.x_variable, "community": r.scope, "subset": "all supported",
            "weighting": r.weighting, "n": r.n_obs, "n_units": r.n_units,
            "slope": r.slope, "intercept": np.nan, "r": r.r, "resid_sd": r.resid_sd,
            "boot_slope_p2_5": r.get("boot2000_p2_5"), "boot_slope_p50": r.get("boot2000_p50"),
            "boot_slope_p97_5": r.get("boot2000_p97_5"), "boot_draws": 2000,
            "boot_cluster": r.cluster})
    ar1 = pd.read_csv(OUT / "UNZONED_v3_armB_ar1_fit.csv").iloc[0]
    frames.append({
        "fit_id": "UNZONED_v3_within_pooled_AR1", "description": ar1.label,
        "estimator": "WITHIN (patch fixed effects), AR(1) errors - SENSITIVITY, not a "
                     "correction", "metric": "veg_p05_spatial",
        "y_variable": "veg_p05_spatial", "x_variable": "inund_pct",
        "community": "all pooled", "subset": "all supported", "weighting": ar1.weighting,
        "n": ar1.n_obs, "n_units": ar1.n_units, "slope": ar1.slope, "intercept": np.nan,
        "r": np.nan, "resid_sd": np.nan, "boot_slope_p2_5": ar1.ci_lo,
        "boot_slope_p50": ar1.slope, "boot_slope_p97_5": ar1.ci_hi, "boot_draws": 0,
        "boot_cluster": "MODEL-BASED interval, not a bootstrap"})
    bf = pd.read_csv(OUT / "UNZONED_v3_armB_between_fits.csv")
    for _, r in bf.iterrows():
        frames.append({
            "fit_id": r.fit_id, "description": r.description, "estimator": r.estimator,
            "metric": r.metric, "y_variable": r.y_variable, "x_variable": r.x_variable,
            "community": r.community, "subset": "all supported", "weighting": r.weighting,
            "n": r.n, "n_units": r.n, "slope": r.slope, "intercept": r.intercept,
            "r": r.r, "resid_sd": r.resid_sd, "boot_slope_p2_5": r.boot_slope_p2_5,
            "boot_slope_p50": r.boot_slope_p50, "boot_slope_p97_5": r.boot_slope_p97_5,
            "boot_draws": r.boot_draws, "boot_cluster": r.boot_cluster})
    cf = pd.DataFrame(frames)
    cf["estimator_warning"] = ("WITHIN and BETWEEN answer different questions and are "
                               "never two estimates of one number (spec section 5). Every "
                               "row names its estimator; no row may be compared to "
                               "another without matching that column.")
    cf["cluster_warning"] = ("the cluster is the PATCH; the real-part comparators cluster "
                             "on zone_fid. There is no paddock on this ground.")
    cf["support_level"] = "pixel"
    cf["period_label"] = PERIOD
    cf["land_use_label"] = LAND_USE
    cf["unit_construction"] = UNIT_CONSTRUCTION
    cf.to_csv(OUT / "UNZONED_regression_coefficients.csv", index=False,
              lineterminator="\n")
    print(f"[coeffs]  UNZONED_regression_coefficients.csv  {len(cf)} fits "
          f"({int((cf.estimator.str.startswith('WITHIN')).sum())} within, "
          f"{int((cf.estimator.str.startswith('BETWEEN')).sum())} between)")

    # ---------------------------------------------------------------- the polygons
    try:
        import geopandas as gpd
        import rasterio.features
        from scipy import ndimage
        from shapely.geometry import shape as shp

        cen = pd.read_parquet(ROOT / "Output/census/gayini_pixel_census_8058.parquet",
                              columns=["pixel_id", "x_8058", "y_8058", "community",
                                       "regime_band", "treed_context_flag"])
        z = pd.read_parquet(ROOT / "Output/census/gayini_pixel_zone_assignment.parquet")
        m = cen.merge(z, on="pixel_id", how="left")
        nt = m[(m.treed_context_flag == 0) & (m.regime_band != "context")]
        u = nt[nt.zone_fid.isna()].copy()
        x, y = u.x_8058.to_numpy(float), u.y_8058.to_numpy(float)
        step = 24.970268
        col = np.rint((x - x.min()) / step).astype(int)
        row = np.rint((y.max() - y) / step).astype(int)
        H, W = row.max() + 1, col.max() + 1
        comm = u.community.to_numpy(str)
        lab_all = np.zeros((H, W), dtype=np.int32)
        nxt = 0
        for cm in sorted(set(comm)):
            sel = comm == cm
            g = np.zeros((H, W), dtype=bool)
            g[row[sel], col[sel]] = True
            lab, n = ndimage.label(g, structure=np.ones((3, 3), dtype=int))
            lab_all[g] = nxt + lab[g]
            nxt += n
        # top-left corner of the lattice, in 8058 metres
        tr = rasterio.transform.from_origin(x.min() - step / 2, y.max() + step / 2,
                                            step, step)
        geoms, vals = [], []
        for geom, val in rasterio.features.shapes(lab_all, mask=lab_all > 0,
                                                  transform=tr, connectivity=8):
            geoms.append(shp(geom))
            vals.append(int(val))
        gdf = gpd.GeoDataFrame({"patch_ord": vals}, geometry=geoms, crs="EPSG:8058")
        gdf = gdf.dissolve(by="patch_ord", as_index=False)
        gdf["patch_id"] = ["U%04d" % v for v in gdf.patch_ord]
        gdf = gdf.merge(s, on="patch_id", how="left")
        gdf["crs_note"] = "EPSG:8058 GDA2020 / NSW Lambert - the canonical analysis grid"
        out_gpkg = OUT / "UNZONED_patches_epsg8058.gpkg"
        if out_gpkg.exists():
            out_gpkg.unlink()
        gdf.to_file(out_gpkg, layer="unzoned_patches", driver="GPKG")
        print(f"[gpkg]    UNZONED_patches_epsg8058.gpkg  {len(gdf)} polygons, "
              f"EPSG:{gdf.crs.to_epsg()}, area check "
              f"{gdf.geometry.area.sum() / 1e4:,.1f} ha vs "
              f"{len(u) * PIXEL_AREA_HA:,.1f} ha from cell counts")
    except Exception as e:
        print(f"[gpkg]    NOT WRITTEN: {type(e).__name__}: {e}")

    # ---------------------------------------------------------------- the manifest
    rows = []
    # .md included: the findings note and the dictionary are artefacts too, and section 6
    # requires everything the note asserts from to be listed.
    for p in sorted(OUT.glob("*.csv")) + sorted(OUT.glob("*.md")) + \
            sorted(OUT.glob("*.gpkg")) + \
            sorted((ROOT / "Output/figures/unzoned").glob("*.png")):
        # the manifest cannot list itself: its own row would carry the checksum of the
        # PREVIOUS version, which is worse than no row at all in a checksum file.
        if p.name == "UNZONED_v3_manifest.csv":
            continue
        rows.append({"path": str(p.relative_to(ROOT)).replace("\\", "/"),
                     "bytes": p.stat().st_size,
                     "checksum_sha256_first50mb": sha256_first50(p)})
    mf = pd.DataFrame(rows)
    mf["task"] = "UNZONED v3"
    mf["period_label"] = PERIOD
    mf["support_level"] = "pixel (except UNZONED_v3_plot_overlay_summary.csv, plot ~1 ha)"
    mf["land_use_label"] = LAND_USE
    mf["checksum_convention"] = "first-50-MB SHA-256, the project's single convention"
    mf["manifest_rule"] = ("every table the findings note asserts from is listed here, "
                           "including the community-slope coefficients - the PARTREG pack "
                           "omitted exactly those and section 6 says it must not repeat")
    mf.to_csv(OUT / "UNZONED_v3_manifest.csv", index=False, lineterminator="\n")
    print(f"[manifest] UNZONED_v3_manifest.csv  {len(mf)} artefacts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
