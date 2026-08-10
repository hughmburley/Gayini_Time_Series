#!/usr/bin/env python
"""MAP-1 - derive the 156 paddock x community area polygons.

Spec: docs/reference_update/Gayini_CC_spec_MAP1.md sections 2-3, with the design-seat
amendment of 10 Aug: section 3's counts are inherited from prose and are verified against
geometry BEFORE any map is drawn.

WHY THIS SCRIPT EXISTS AT ALL. Section 2 lists the 156 areas as coming from
`Gayini_Results.gpkg`. **They are not there.** That geopackage holds `management_zones`
(64) and `vegetation_units` (20). The only paddock x community polygon layers in the repo
are `PARTREG_part_residuals.gpkg` (115, the supported non-treed parts) and
`T13_part_polygons_epsg8058.gpkg` (118, all non-treed parts). **The 38 treed and
minor-unit areas have no polygons anywhere**, so M1's "every area appears" cannot be drawn
from an existing layer.

THE GEOMETRY IS DERIVED FROM THE CENSUS, not from a vector intersection, and that is a
deliberate choice. The scatters' units ARE the census cells grouped by (zone_fid,
community). Polygonising exactly those cells makes the map's shapes the analysis units
rather than a second, slightly different, vector definition of them. Mixing a
census-derived class (the 38) with a vector-derived class (the 118) on one map would put
two unit definitions under one legend. Same technique as UNZONED v3's patch polygons,
which reproduced against the Gate 1 inventory at zero mismatches.

NO NEW METRIC IS COMPUTED AND NO RASTER IS BUILT (section 0). Every value carried here is
a column already behind an existing figure.
"""
from __future__ import annotations

import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd
import rasterio.features
import rasterio.transform
from shapely.geometry import shape as shp

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "maps"
CENSUS = ROOT / "Output/census/gayini_pixel_census_8058.parquet"
ZONES = ROOT / "Output/census/gayini_pixel_zone_assignment.parquet"
DB = ROOT / "Output/database/Gayini_Results.sqlite"

PIXEL_SIDE_M = 24.970268
PIXEL_AREA_HA = PIXEL_SIDE_M ** 2 / 1e4
MIN_CELLS = 500

SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
         "Riverine Chenopod Shrublands": "riverine",
         "Inland Floodplain Shrublands / Swamps": "inland"}

# section 3's class table, as written in prose. Checked, never assumed.
SPEC_CLASSES = {"plotted": 100, "woodland": 34, "other": 4, "under_floor": 18}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    cen = pd.read_parquet(CENSUS)
    z = pd.read_parquet(ZONES)
    m = cen.merge(z, on="pixel_id", how="left")
    inz = m[m.zone_fid.notna()].copy()
    inz["zone_fid"] = inz.zone_fid.astype(int)
    print(f"[cells] {len(inz):,} census cells inside a management zone "
          f"({len(inz) * PIXEL_AREA_HA:,.1f} ha)")

    # ---- the class of every area, from the census the scatters used -----------------
    inz["is_treed"] = inz.treed_context_flag != 0
    inz["is_other"] = (~inz.is_treed) & (inz.regime_band == "context")
    g = inz.groupby(["zone_fid", "community"])
    p = g.agg(n_cells=("pixel_id", "size"),
              is_treed=("is_treed", "first"), is_other=("is_other", "first"),
              veg_p05_temporal_mean=("veg_p05", "mean"),
              mean_share_cells_wet=("flood_freq_pct", "mean")).reset_index()
    p["area_ha"] = p.n_cells * PIXEL_AREA_HA
    p["community_short"] = p.community.map(SHORT)

    def classify(r):
        if r.is_treed:
            return "woodland"
        if r.is_other:
            return "other"
        return "plotted" if r.n_cells >= MIN_CELLS else "under_floor"

    p["inclusion_class"] = p.apply(classify, axis=1)

    # ---- THE AMENDMENT: verify before drawing ---------------------------------------
    got = p.inclusion_class.value_counts().to_dict()
    print("\n[verify] section 3's class table against the census geometry")
    ok = True
    for k, want in SPEC_CLASSES.items():
        have = int(got.get(k, 0))
        ha = float(p.loc[p.inclusion_class == k, "area_ha"].sum())
        flag = "OK" if have == want else f"MISMATCH - spec says {want}"
        ok &= have == want
        print(f"    {k:<12s} n={have:>3} (spec {want:>3})  {ha:>9,.1f} ha   {flag}")
    print(f"    {'TOTAL':<12s} n={len(p):>3} (spec 156)  {p.area_ha.sum():>9,.1f} ha   "
          f"{'OK' if len(p) == 156 else 'MISMATCH'}")
    ok &= len(p) == 156
    if not ok:
        print("\nHALT: section 3's counts do not reconcile against the geometry. That is "
              "the finding and it reports before rendering.")
        return 1
    print("  PASS - the prose counts reconcile exactly; the maps may be drawn")

    # ---- polygonise the cells of each area ------------------------------------------
    x = inz.x_8058.to_numpy(float)
    y = inz.y_8058.to_numpy(float)
    ux = np.unique(np.round(x, 4))
    step = float(np.median(np.diff(ux)))
    if abs(step - PIXEL_SIDE_M) > 1e-3:
        print(f"HALT: measured grid spacing {step:.6f} != PIXEL_SIDE_M")
        return 1
    col = np.rint((x - x.min()) / step).astype(np.int64)
    row = np.rint((y.max() - y) / step).astype(np.int64)
    H, W = int(row.max()) + 1, int(col.max()) + 1

    p = p.sort_values(["zone_fid", "community"]).reset_index(drop=True)
    p["part_ord"] = np.arange(1, len(p) + 1)
    key = pd.Series(list(zip(inz.zone_fid, inz.community)), index=inz.index)
    lut = {k: o for k, o in zip(zip(p.zone_fid, p.community), p.part_ord)}
    lab = np.zeros((H, W), dtype=np.int32)
    lab[row, col] = key.map(lut).to_numpy()

    tr = rasterio.transform.from_origin(x.min() - step / 2, y.max() + step / 2, step, step)
    geoms, vals = [], []
    for geom, val in rasterio.features.shapes(lab, mask=lab > 0, transform=tr,
                                              connectivity=8):
        geoms.append(shp(geom))
        vals.append(int(val))
    gdf = gpd.GeoDataFrame({"part_ord": vals}, geometry=geoms, crs="EPSG:8058")
    gdf = gdf.dissolve(by="part_ord", as_index=False).merge(p, on="part_ord")

    # ---- geometry must close against the cell counts, or it is not the same unit ----
    poly_ha = gdf.geometry.area / 1e4
    diff = float((poly_ha - gdf.area_ha).abs().max())
    print(f"\n[check] polygon area vs cell-count area: max |diff| {diff:.6f} ha over "
          f"{len(gdf)} areas; totals {poly_ha.sum():,.1f} vs {gdf.area_ha.sum():,.1f} ha")
    if diff > 0.01:
        print("HALT: the polygons do not close against the cells they were built from")
        return 1

    # zone names, for a Council-facing map that uses existing report-stream naming only
    import sqlite3
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    zn = pd.read_sql("SELECT zone_fid, zone_name FROM dim_management_zone", con)
    con.close()
    gdf = gdf.merge(zn, on="zone_fid", how="left")

    gdf["unit_construction"] = ("management zone cut to one vegetation community; "
                               "geometry is the union of that unit's census cells")
    gdf["support_level"] = "pixel"
    gdf["period_label"] = "1988-2022 (35 water years)"
    gdf["pixel_constant_ha"] = PIXEL_AREA_HA
    gdf["min_cells_filter"] = MIN_CELLS
    gdf["crs_note"] = "EPSG:8058 GDA2020 / NSW Lambert - the canonical analysis grid"

    dst = OUT / "MAP1_paddock_community_areas_epsg8058.gpkg"
    if dst.exists():
        dst.unlink()
    gdf.to_file(dst, layer="paddock_community_areas", driver="GPKG")
    print(f"  [wrote] {dst.relative_to(ROOT)}  {len(gdf)} polygons, EPSG:8058")

    summary = (gdf.drop(columns="geometry")
                  .groupby("inclusion_class")
                  .agg(n_areas=("part_ord", "size"), n_cells=("n_cells", "sum"),
                       area_ha=("area_ha", "sum")).reset_index())
    summary["pct_of_all_area"] = 100 * summary.area_ha / gdf.area_ha.sum()
    summary["verified_against"] = "census cells, the source the scatters aggregate"
    summary.to_csv(OUT / "MAP1_inclusion_class_summary.csv", index=False,
                   lineterminator="\n")
    print(summary.to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
