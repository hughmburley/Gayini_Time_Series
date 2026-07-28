#!/usr/bin/env python3
"""T12 · Gate A — register the 38 DEA Land Cover Level 3 rasters (additive).

Registers Input/landsat_landcover/level3/LLC3_{year}_MGA54.tif (1988-2025) into
raster_asset with product='dea_landcover_l3', crs_epsg=7854, bounds, resolution,
SHA-256 (first-50-MB convention), path_exists, legend_semantics, and a per-row
provenance_note recording the 3577->7854 NN lineage and the producing script/
notebook. Inserts dim_source_product 'dea_landcover_l3' (verbatim caveat, spec S4)
and creates+populates dim_dea_landcover_class (all seven LCCS codes, even the
three absent from our extent, so the dimension is complete).

Additive only. INSERT OR REPLACE keyed on the PKs. Never reset_file, never the
builder. Touches no pre-existing raster_asset row (distinct ids raster_dea_l3_*)
and writes nothing to dim_management_zone.

Spec: docs/reference_update/T12_dea_landcover_l3_extraction.md v2, Gate A.

Usage:
  python scripts/11_database/register_T12_gateA_rasters.py check     # no DB write (default)
  python scripts/11_database/register_T12_gateA_rasters.py execute   # performs the write
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

import rasterio

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RASTER_DIR = ROOT / "Input" / "landsat_landcover" / "level3"
RUN_ID = "T12_gateA"
RUN_DATETIME = "2026-07-28T00:00:00+00:00"  # fixed for idempotence
YEARS = list(range(1988, 2026))  # 38 years, 1988-2025 contiguous


def sha256_first50(path: Path) -> str:
    h = hashlib.sha256()
    read = 0
    cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            read += len(chunk)
    return h.hexdigest()


# --- dim_source_product row (verbatim from spec S4) --------------------------
SOURCE_PRODUCT = dict(
    product_id="dea_landcover_l3",
    product_name="DEA Land Cover Level 3 (ga_ls_landcover_class_cyear_3 v2.0.0)",
    sensor_family="Landsat (DEA derivative)",
    method_summary=(
        "FAO LCCS v2 annual classification, 30 m, calendar year. Derived from "
        "DEA Fractional Cover, FC Percentiles, Water Observations, geomedian/MAD ML."),
    caveat=(
        "NOT cropping history. Shares parent products with the Gayini census — "
        "cannot independently corroborate census results. CTV is the weakest class "
        "in the product; in semi-arid and floodplain settings, drought dry-down and "
        "flood green-up both mimic the cultivation signature. Measured false-positive "
        "floor at Gayini 2023-2025 (cultivation known zero) = 6.7% of property. "
        "GA use constraint: national scale; local datasets are authoritative."),
)

# --- dim_dea_landcover_class (all seven codes) -------------------------------
CLASS_COMMON = (
    " DEA Land Cover emits a class for every pixel regardless of how many usable "
    "observations that pixel had in that year; there is no confidence layer in "
    "v2.0.0, so absence of nodata is NOT evidence of adequate observation. This "
    "matters most for 1988-1999 (Landsat 5 TM only).")

CLASSES = [
    (111, "CTV", "Cultivated terrestrial vegetation", 0,
     "The task's target class and the weakest in the product. In semi-arid/floodplain "
     "settings, drought dry-down and flood green-up both mimic the cultivation "
     "signature. Measured false-positive floor at Gayini 2023-2025 (cultivation known "
     "zero) = 6.7% of property; use excess-over-zone-floor, never a raw share."),
    (112, "NTV", "Natural terrestrial vegetation", 0,
     "Residual natural-vegetation class. Landsat fractional cover measures cover, not "
     "condition - it cannot distinguish native from introduced, or structure from health."),
    (124, "NAV", "Natural aquatic vegetation", 0,
     "Does not occur in the Gayini extent (0 pixels across 1988-2025). Populated for "
     "dimensional completeness so the product is not misread as four-class."),
    (215, "AS", "Artificial surface", 0,
     "Does not occur in the Gayini extent (0 pixels across 1988-2025). Populated for "
     "dimensional completeness so the product is not misread as four-class."),
    (216, "NS", "Natural bare surface", 0,
     "Bare / low-cover surface; overlaps drought and dry-down states and can co-vary "
     "with the CTV false positive."),
    (220, "Water", "Water", 0,
     "Open water (Water Observations lineage) - a parent product of the Gayini census "
     "inundation stack, so not independent of it."),
    (255, "nodata", "No data", 1,
     "v2.0.0 nodata sentinel. Does not occur in the supplied extent (a filled bounding "
     "rectangle; n_pixels_nodata = 0 for every zone-year). Its absence means the clip "
     "is gap-free, not that observation was adequate."),
]

RASTER_COLS = ["raster_asset_id", "path", "metric_id", "water_year", "period_label",
               "crs", "resolution_x", "resolution_y", "xmin", "ymin", "xmax", "ymax",
               "checksum_sha256", "path_exists", "qa_status", "run_id", "crs_epsg",
               "product", "legend_status", "legend_semantics", "superseded_flag",
               "framing_label", "provenance_note"]

PROV_SUPPLY = (
    "DEA native EPSG:3577 -> EPSG:7854, nearest-neighbour, via odc.stac.load from DEA "
    "Explorer STAC (dea-public-data S3). Produced by "
    "scripts/13_dea_landcover/T12_supply_repull_1988_1999.py (T12 supply step, "
    "28 Jul 2026). Identical route to the 2000-2025 block; different producer.")
PROV_NOTEBOOK = (
    "DEA native EPSG:3577 -> EPSG:7854, nearest-neighbour, via odc.stac.load from DEA "
    "Explorer STAC (dea-public-data S3). Produced by "
    "Input/landsat_landcover/gayini_landuse.ipynb. Identical route to the 1988-1999 "
    "supply block; different producer.")


def build_raster_rows() -> list[dict]:
    rows = []
    for y in YEARS:
        tif = RASTER_DIR / f"LLC3_{y}_MGA54.tif"
        if not tif.is_file():
            raise SystemExit(f"ABORT: {tif.name} not found. Supply step incomplete.")
        with rasterio.open(tif) as ds:
            epsg = ds.crs.to_epsg()
            if epsg != 7854:
                raise SystemExit(f"ABORT: {tif.name} CRS is EPSG:{epsg}, expected 7854.")
            b = ds.bounds
            resx = abs(ds.transform.a)
            resy = abs(ds.transform.e)
        rows.append(dict(
            raster_asset_id=f"raster_dea_l3_{y}",
            path=tif.relative_to(ROOT).as_posix(),
            metric_id=None,
            water_year=None,                      # calendar-year product: kept OUT of water_year (spec S6)
            period_label=f"calendar_{y}",
            crs="EPSG:7854",
            resolution_x=resx,
            resolution_y=resy,
            xmin=b.left, ymin=b.bottom, xmax=b.right, ymax=b.top,
            checksum_sha256=sha256_first50(tif),
            path_exists=1,
            qa_status="REVIEW",
            run_id=RUN_ID,
            crs_epsg=7854,
            product="dea_landcover_l3",
            legend_status="confirmed",
            legend_semantics="FAO LCCS v2 Level 3 categorical",
            superseded_flag=0,
            framing_label=None,
            provenance_note=PROV_SUPPLY if 1988 <= y <= 1999 else PROV_NOTEBOOK,
        ))
    return rows


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")
    rows = build_raster_rows()
    class_rows = [(c[0], c[1], c[2], c[3], c[4] + CLASS_COMMON) for c in CLASSES]

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        try:
            clash = con.execute(
                "SELECT COUNT(*) FROM raster_asset WHERE raster_asset_id LIKE 'raster_dea_l3_%' "
                "AND product<>'dea_landcover_l3'").fetchone()[0]
            existing = con.execute(
                "SELECT COUNT(*) FROM raster_asset WHERE product='dea_landcover_l3'").fetchone()[0]
            total = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
        finally:
            con.close()
        if clash:
            raise SystemExit("ABORT: raster_dea_l3_* id already used by another product.")
        print(f"[check] raster_asset total {total}; existing dea rows {existing}; "
              f"planning {len(rows)} (1988-2025).")
        print(f"[check] sample row (first): {rows[0]['raster_asset_id']} "
              f"crs={rows[0]['crs']} res=({rows[0]['resolution_x']},{rows[0]['resolution_y']}) "
              f"bounds=({rows[0]['xmin']},{rows[0]['ymin']},{rows[0]['xmax']},{rows[0]['ymax']}) "
              f"sha={rows[0]['checksum_sha256'][:12]} period={rows[0]['period_label']}")
        print(f"[check] provenance (1988): {rows[0]['provenance_note'][:80]}...")
        print(f"[check] provenance (2000): {rows[12]['provenance_note'][:80]}...")
        print(f"[check] dim_source_product row: {SOURCE_PRODUCT['product_id']}")
        print(f"[check] dim_dea_landcover_class rows: {[c[0] for c in class_rows]}")
        print("[check] NO DB WRITE performed.")
        return

    # ---- execute -----------------------------------------------------------
    con = sqlite3.connect(DB.as_posix())
    try:
        con.execute(
            "INSERT OR REPLACE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 0, 'REVIEW')",
            (RUN_ID, RUN_DATETIME,
             "scripts/11_database/register_T12_gateA_rasters.py",
             '{"gate": "A", "spec": "docs/reference_update/T12_dea_landcover_l3_extraction.md v2"}'))

        con.execute("""
            CREATE TABLE IF NOT EXISTS dim_dea_landcover_class (
                level3_code INTEGER PRIMARY KEY,
                class_code  TEXT,
                class_name  TEXT,
                is_nodata   INTEGER,
                caveat      TEXT
            )""")
        con.executemany(
            "INSERT OR REPLACE INTO dim_dea_landcover_class "
            "(level3_code, class_code, class_name, is_nodata, caveat) VALUES (?,?,?,?,?)",
            class_rows)

        con.execute(
            "INSERT OR REPLACE INTO dim_source_product "
            "(product_id, product_name, sensor_family, method_summary, caveat) "
            "VALUES (:product_id, :product_name, :sensor_family, :method_summary, :caveat)",
            SOURCE_PRODUCT)

        before = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
        ph = ", ".join(["?"] * len(RASTER_COLS))
        con.executemany(
            f"INSERT OR REPLACE INTO raster_asset ({', '.join(RASTER_COLS)}) VALUES ({ph})",
            [tuple(r[c] for c in RASTER_COLS) for r in rows])
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
        print(f"[execute] raster_asset rows: {before} -> {after} (+{after - before})")
        print("[execute] dea raster_asset rows:",
              con.execute("SELECT COUNT(*) FROM raster_asset WHERE product='dea_landcover_l3'").fetchone()[0])
        print("[execute] dim_source_product rows:",
              con.execute("SELECT COUNT(*) FROM dim_source_product").fetchone()[0])
        print("[execute] dim_dea_landcover_class rows:",
              con.execute("SELECT COUNT(*) FROM dim_dea_landcover_class").fetchone()[0])
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
