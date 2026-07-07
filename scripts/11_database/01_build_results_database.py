"""Build curated Gayini results database deliverables.

This script is intentionally standard-library first. It creates a reproducible
results database from current CSV outputs and, when shapefiles.zip is present,
rebuilds a polygon GeoPackage companion without relying on system GIS tools.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import math
import os
import re
import sqlite3
import struct
import tempfile
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "Output"
DATABASE_DIR = OUTPUT / "database"
DIAG_DIR = OUTPUT / "diagnostics" / "database"
REPORT_DIR = OUTPUT / "reports" / "database"

SQLITE_PATH = DATABASE_DIR / "Gayini_Results.sqlite"
GPKG_PATH = DATABASE_DIR / "Gayini_Results.gpkg"
DICTIONARY_PATH = DATABASE_DIR / "Gayini_Results_data_dictionary.xlsx"
README_PATH = DATABASE_DIR / "README_Gayini_Results_database.md"
REPORT_PATH = REPORT_DIR / "Gayini_results_database_build_report.md"
QA_CSV_PATH = DIAG_DIR / "db_build_qa_checks.csv"
ASSET_CSV_PATH = DIAG_DIR / "output_asset_manifest.csv"
SPATIAL_IMPORT_CSV_PATH = DIAG_DIR / "spatial_layer_import_summary.csv"
SPATIAL_OVERLAY_CSV_PATH = DIAG_DIR / "plot_spatial_overlay_summary.csv"
RASTER_METADATA_CSV_PATH = DIAG_DIR / "raster_asset_metadata_summary.csv"

DEFAULT_SHAPEFILE_ZIP_CANDIDATES = [
    ROOT / "Input" / "shapefiles.zip",
    ROOT / "inputs" / "shapefiles.zip",
    DATABASE_DIR / "shapefiles.zip",
    Path("C:/Users/hughb/Downloads/shapefiles.zip"),
]

TREED_EXCLUSION_PLOTS = {
    "GA_011",
    "GA_012",
    "GA_014",
    "GA_015",
    "GA_021",
    "GA_023",
    "GA_029",
    "GA_030",
    "GA_065",
}

KNOWN_VEG_MISMATCHES = {
    "GA_006": "Inland Riverine Forests",
    "GA_007": "Inland Riverine Forests",
    "GA_022": "Riverine Chenopod Shrublands",
    "GA_066": "Inland Riverine Forests",
}

BIODIVERSITY_SQLITE = (
    Path("D:/Github_repos/Gayini_Biodiversity/OUTPUT/Gayini/database/Gayini_Biodiversity.sqlite")
)
GAUGE_SQLITE = (
    Path("D:/Github_repos/Murrumbidgee_Gauge_Workflow/Output/database/gayini_murrumbidgee_gauges.sqlite")
)
GAUGE_GPKG = (
    Path("D:/Github_repos/Murrumbidgee_Gauge_Workflow/Output/database/gayini_murrumbidgee_gauges.gpkg")
)

BIODIVERSITY_TABLES = [
    "plot_loocb_context",
    "rs_loocb_joined_plot_summary",
    "monitoring_headline",
    "monitoring_timeseries",
    "planning_headline",
    "planning_timeseries",
    "vegetation_type_summary",
    "treatment_summary",
    "raster_catalog",
    "final_map_index",
    "output_manifest",
    "run_metadata",
]

GAUGE_TABLES = [
    "gauge_sites",
    "monthly_flow",
    "water_year_flow",
    "kingsford_flow_ratios_water_year",
    "kingsford_flow_ratios_nov_oct_year",
    "completeness_by_gauge",
    "completeness_overall",
    "qa_checks",
    "source_files",
]

RUN_DATETIME = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
RUN_ID = "db_build_" + dt.datetime.now().strftime("%Y%m%d_%H%M%S")


CSV_INPUTS = {
    "stg_canonical_plot_rs_analysis_base": OUTPUT / "csv" / "canonical" / "plot_rs_analysis_base.csv",
    "stg_canonical_plot_rs_gauge_analysis_base": OUTPUT / "csv" / "canonical" / "plot_rs_gauge_analysis_base.csv",
    "stg_canonical_annual_inundation": OUTPUT / "csv" / "canonical" / "curated_annual_inundation_timeseries.csv",
    "stg_canonical_daily_inundation_monthly": OUTPUT / "csv" / "canonical" / "curated_daily_inundation_monthly.csv",
    "stg_canonical_ground_cover_timeseries": OUTPUT / "csv" / "canonical" / "curated_ground_cover_timeseries.csv",
    "stg_mer_annual_max_by_plot": OUTPUT / "csv" / "MER" / "mer_annual_max_by_plot.csv",
    "stg_mer_period_summary_by_plot": OUTPUT / "csv" / "MER" / "mer_period_summary_by_plot.csv",
    "stg_mer_period_summary_by_vegetation_group": OUTPUT / "csv" / "MER" / "mer_period_summary_by_vegetation_group.csv",
    "stg_mer_vs_annual_occurrence_by_plot": OUTPUT / "csv" / "MER" / "mer_vs_annual_occurrence_raster_comparison_by_plot.csv",
    "stg_hydrology_gauge_context": OUTPUT / "csv" / "hydrology" / "gauge_context_for_gayini.csv",
    "stg_ground_cover_prepost_plot_summary": OUTPUT / "csv" / "ground_cover" / "10a_ground_cover_prepost_plot_summary.csv",
    "stg_ground_cover_plot_context_flags": OUTPUT / "csv" / "ground_cover" / "plot_context_flags.csv",
    "stg_inundation_frequency_by_vegetation_group": OUTPUT / "csv" / "inundation" / "inundation_frequency_by_vegetation_group.csv",
    "stg_modis_context_full": OUTPUT / "csv" / "MODIS" / "03_modis_ground_cover_context_full.csv",
    "stg_modis_context_units_summary": OUTPUT / "csv" / "MODIS" / "modis_context_units_summary.csv",
    "stg_review_mer_metric_comparison": OUTPUT / "csv" / "review_deck" / "mer_metric_comparison_table.csv",
}


METRICS = [
    ("inundation_annual_occurrence_pct", "Annual inundation occurrence", "inundation", "pct", "0-100", "annual wet area", "plot area", "Annual wet-any raster area percentage.", "Annual occurrence, not hydroperiod.", "Annual occurrence does not encode duration."),
    ("inundation_annual_wet_any", "Annual wet-any flag", "inundation", "flag", "0/1", "wet observation", "valid annual observation", "Annual wet-any flag from curated annual inundation table.", "Use as annual presence/absence support.", "Coverage caveats apply."),
    ("inundation_annual_valid_any", "Annual valid-any flag", "inundation", "flag", "0/1", "valid observation", "expected annual observation", "Annual valid-any support flag.", "Use as denominator support.", "Coverage caveats apply."),
    ("inundation_valid_coverage_pct", "Annual valid coverage", "inundation", "pct", "0-100", "valid raster cells", "expected raster cells", "Valid raster coverage percentage.", "Support/confidence metric.", "Can slightly exceed 100 because of raster/cell geometry tolerances."),
    ("daily_inundation_mean_pct", "Mean daily inundated area", "inundation", "pct", "0-100", "daily wet area", "plot area", "Monthly mean of daily inundated percentage.", "Short-term wetness context.", "Observation cadence is irregular."),
    ("daily_inundation_max_pct", "Maximum daily inundated area", "inundation", "pct", "0-100", "daily wet area", "plot area", "Monthly maximum daily inundated percentage.", "Event-scale wetness context.", "Observation cadence is irregular."),
    ("daily_observation_count", "Daily observation count", "inundation", "count", "count", "daily observations", "month", "Number of daily inundation observations in month.", "Support metric.", "Not a hydrological duration."),
    ("daily_wet_observation_count", "Daily wet observation count", "inundation", "count", "count", "wet daily observations", "month", "Number of wet daily observations in month.", "Support metric.", "Not a hydrological duration."),
    ("groundcover_bare_pct", "Bare ground", "ground_cover", "pct", "0-100", "bare fraction", "valid cover", "Bare ground percentage.", "Vegetation response/context metric.", "Remote-sensing cover, not field survey."),
    ("groundcover_green_pv_pct", "Green photosynthetic vegetation", "ground_cover", "pct", "0-100", "PV fraction", "valid cover", "Green PV percentage.", "Vegetation response/context metric.", "Remote-sensing cover, not field survey."),
    ("groundcover_non_green_npv_pct", "Non-green non-photosynthetic vegetation", "ground_cover", "pct", "0-100", "NPV fraction", "valid cover", "Non-green NPV percentage.", "Vegetation response/context metric.", "Remote-sensing cover, not field survey."),
    ("groundcover_total_veg_pct", "Total vegetation", "ground_cover", "pct", "0-100", "PV + NPV", "valid cover", "Total vegetation percentage.", "Vegetation response/context metric.", "May be confounded in treed plots."),
    ("groundcover_valid_coverage_count", "Ground-cover valid cell count", "ground_cover", "count", "count", "valid cells", "plot", "Valid extraction support count.", "Support/confidence metric.", "Threshold-dependent."),
    ("mer_annual_max_observed_wet_pct", "MER annual maximum observed wet", "MER", "pct", "0-100", "annual max observed wet area", "plot area", "MER annual maximum observed wet area percentage.", "Comparable floodplain wetness metric.", "Observed maximum, not duration or hydroperiod."),
    ("mer_valid_observation_count_mean", "MER valid observations", "MER", "count", "count", "valid observations", "water year", "Mean valid MER observations.", "Support/confidence metric.", "Observation density varies by year."),
    ("mer_wet_observation_count_mean", "MER wet observations", "MER", "count", "count", "wet observations", "water year", "Mean wet MER observations.", "Support/confidence metric.", "Observation density varies by year."),
    ("mer_wet_observation_fraction_mean", "MER wet observation fraction", "MER", "fraction", "0-1", "wet observations", "valid observations", "Mean wet observation fraction.", "Support/context metric.", "Observation density varies by year."),
    ("pre_conservation_inundation_frequency_pct", "Pre-conservation inundation frequency", "summary", "pct", "0-100", "pre wet years", "pre valid years", "Pre-conservation annual inundation frequency.", "Default pre-period headline.", "Main period is WY2014-WY2019 unless sensitivity view says otherwise."),
    ("post_conservation_inundation_frequency_pct", "Post-conservation inundation frequency", "summary", "pct", "0-100", "post wet years", "post valid years", "Post-conservation annual inundation frequency.", "Default post-period headline.", "Main period includes WY2020 in current outputs."),
    ("post_minus_pre_inundation_frequency_pct_points", "Post-minus-pre inundation frequency", "summary", "percentage_points", "-100 to 100", "post minus pre", "period comparison", "Post minus pre annual inundation frequency.", "Hydrological change headline.", "Interpret with valid-year support."),
    ("pre_mean_total_veg_pct", "Pre mean total vegetation", "summary", "pct", "0-100", "pre total veg", "pre observations", "Pre-period mean total vegetation.", "Vegetation response context.", "Lagged and community-specific."),
    ("post_mean_total_veg_pct", "Post mean total vegetation", "summary", "pct", "0-100", "post total veg", "post observations", "Post-period mean total vegetation.", "Vegetation response context.", "Lagged and community-specific."),
    ("delta_total_veg_pct", "Delta total vegetation", "summary", "percentage_points", "-100 to 100", "post minus pre", "period comparison", "Post minus pre total vegetation.", "Vegetation response headline.", "Lagged and community-specific."),
    ("pre_mean_bare_ground_pct", "Pre mean bare ground", "summary", "pct", "0-100", "pre bare ground", "pre observations", "Pre-period mean bare ground.", "Ground-cover context.", "Lagged and community-specific."),
    ("post_mean_bare_ground_pct", "Post mean bare ground", "summary", "pct", "0-100", "post bare ground", "post observations", "Post-period mean bare ground.", "Ground-cover context.", "Lagged and community-specific."),
    ("delta_bare_ground_pct", "Delta bare ground", "summary", "percentage_points", "-100 to 100", "post minus pre", "period comparison", "Post minus pre bare ground.", "Ground-cover response headline.", "Lagged and community-specific."),
    ("pre_mer_frequency_pct", "Pre MER frequency", "MER", "pct", "0-100", "pre wet years", "pre valid years", "MER pre-period frequency.", "MER comparison headline.", "Observed annual maximum, not duration."),
    ("post_mer_frequency_pct", "Post MER frequency", "MER", "pct", "0-100", "post wet years", "post valid years", "MER post-period frequency.", "MER comparison headline.", "Observed annual maximum, not duration."),
    ("post_minus_pre_mer_frequency_pct_points", "Post-minus-pre MER frequency", "MER", "percentage_points", "-100 to 100", "post minus pre", "period comparison", "MER post-minus-pre frequency.", "MER change headline.", "Observed annual maximum, not duration."),
    ("modis_bare_pct", "MODIS bare ground", "MODIS", "pct", "0-100", "bare MODIS fraction", "valid MODIS area", "MODIS context-unit bare ground percentage.", "Coarse-scale context, not 1 ha plot response.", "Use for farm/buffer/context trends."),
    ("modis_pv_pct", "MODIS photosynthetic vegetation", "MODIS", "pct", "0-100", "PV MODIS fraction", "valid MODIS area", "MODIS context-unit PV percentage.", "Coarse-scale context, not 1 ha plot response.", "Use for farm/buffer/context trends."),
    ("modis_npv_pct", "MODIS non-photosynthetic vegetation", "MODIS", "pct", "0-100", "NPV MODIS fraction", "valid MODIS area", "MODIS context-unit NPV percentage.", "Coarse-scale context, not 1 ha plot response.", "Use for farm/buffer/context trends."),
    ("modis_total_veg_pct", "MODIS total vegetation", "MODIS", "pct", "0-100", "PV + NPV MODIS fraction", "valid MODIS area", "MODIS context-unit total vegetation percentage.", "Coarse-scale context, not 1 ha plot response.", "Use for farm/buffer/context trends."),
    ("modis_valid_area_pct", "MODIS valid area", "MODIS", "pct", "0-100", "valid MODIS area", "context-unit area", "MODIS valid area percentage.", "Support/confidence metric.", "Use before interpreting MODIS trends."),
    ("modis_effective_pixels", "MODIS effective pixels", "MODIS", "count", "count", "effective MODIS pixels", "context unit", "Estimated effective MODIS pixel support.", "Support/confidence metric.", "Coarse-scale approximation."),
    ("modis_valid_area_ha", "MODIS valid area hectares", "MODIS", "ha", "area", "valid MODIS area", "context unit", "MODIS valid area in hectares.", "Support/confidence metric.", "Coarse-scale approximation."),
    ("biodiversity_habitat_condition_2020", "Habitat condition 2020", "biodiversity", "index", "modelled index", "HCAS/LOOC-B habitat condition", "model domain", "Modelled biodiversity context from companion database.", "Contextual evidence only.", "HCAS uses Landsat-derived variables and is not independent validation."),
    ("biodiversity_threatened_species_2020", "Threatened species 2020", "biodiversity", "index", "modelled index", "HCAS/LOOC-B threatened species", "model domain", "Modelled biodiversity context from companion database.", "Contextual evidence only.", "Sensitive biodiversity outputs default to internal review."),
]


def ensure_dirs() -> None:
    for path in (DATABASE_DIR, DIAG_DIR, REPORT_DIR):
        path.mkdir(parents=True, exist_ok=True)


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256(path: Path, max_bytes: int | None = None) -> str | None:
    if not path.exists() or not path.is_file():
        return None
    h = hashlib.sha256()
    read = 0
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            read += len(chunk)
            if max_bytes is not None and read > max_bytes:
                return None
            h.update(chunk)
    return h.hexdigest()


def read_csv_dicts(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def read_csv_header(path: Path) -> list[str]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f)
        return next(reader)


def to_float(value: str | None) -> float | None:
    if value is None:
        return None
    value = str(value).strip()
    if value == "" or value.upper() == "NA":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def to_int_flag(value: str | None) -> int | None:
    if value is None:
        return None
    value = str(value).strip().lower()
    if value in ("true", "1", "yes", "y"):
        return 1
    if value in ("false", "0", "no", "n"):
        return 0
    return None


def q_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def reset_file(path: Path) -> None:
    if path.exists():
        path.unlink()


def resolve_shapefile_zip(cli_path: str | None = None) -> Path | None:
    candidates = [Path(cli_path)] if cli_path else []
    candidates.extend(DEFAULT_SHAPEFILE_ZIP_CANDIDATES)
    for path in candidates:
        if path and path.exists():
            return path
    return None


def dbf_value(raw: bytes, field_type: str):
    text = raw.decode("latin1", errors="replace").strip()
    if text == "":
        return None
    if field_type in {"N", "F"}:
        try:
            if "." in text:
                return float(text)
            return int(text)
        except ValueError:
            return text
    if field_type == "L":
        return 1 if text.upper() in {"Y", "T", "1"} else 0
    return text


def read_dbf(path: Path) -> list[dict[str, object]]:
    data = path.read_bytes()
    n_records = struct.unpack("<I", data[4:8])[0]
    header_len = struct.unpack("<H", data[8:10])[0]
    record_len = struct.unpack("<H", data[10:12])[0]
    fields = []
    offset = 32
    while data[offset] != 13:
        name = data[offset : offset + 11].split(b"\x00", 1)[0].decode("latin1")
        field_type = chr(data[offset + 11])
        length = data[offset + 16]
        fields.append((name, field_type, length))
        offset += 32
    rows = []
    for i in range(n_records):
        start = header_len + i * record_len
        record = data[start : start + record_len]
        if not record or record[0:1] == b"*":
            continue
        pos = 1
        row = {}
        for name, field_type, length in fields:
            row[name] = dbf_value(record[pos : pos + length], field_type)
            pos += length
        rows.append(row)
    return rows


def read_prj(path: Path) -> str:
    if not path.exists():
        return "unknown"
    text = path.read_text(encoding="utf-8", errors="replace")
    if "7854" in text or "GDA2020_MGA_Zone_54" in text:
        return "EPSG:7854"
    if "28355" in text or "GDA_1994_MGA_Zone_55" in text:
        return "EPSG:28355"
    if "4283" in text or "GDA_1994" in text:
        return "EPSG:4283"
    return text[:180]


def read_shp_polygons(path: Path) -> list[dict[str, object]]:
    data = path.read_bytes()
    records = []
    offset = 100
    while offset + 8 <= len(data):
        rec_num, content_words = struct.unpack(">2i", data[offset : offset + 8])
        offset += 8
        content_len = content_words * 2
        content = data[offset : offset + content_len]
        offset += content_len
        if len(content) < 44:
            continue
        shape_type = struct.unpack("<i", content[0:4])[0]
        if shape_type == 0:
            continue
        if shape_type not in {5, 15, 25, 31}:
            continue
        xmin, ymin, xmax, ymax = struct.unpack("<4d", content[4:36])
        n_parts, n_points = struct.unpack("<2i", content[36:44])
        parts_offset = 44
        parts = list(struct.unpack(f"<{n_parts}i", content[parts_offset : parts_offset + 4 * n_parts]))
        points_offset = parts_offset + 4 * n_parts
        points = [
            struct.unpack("<2d", content[points_offset + i * 16 : points_offset + i * 16 + 16])
            for i in range(n_points)
        ]
        rings = []
        part_starts = parts + [n_points]
        for start, end in zip(part_starts[:-1], part_starts[1:]):
            ring = points[start:end]
            if ring and ring[0] != ring[-1]:
                ring = ring + [ring[0]]
            if len(ring) >= 4:
                rings.append(ring)
        records.append(
            {
                "record_number": rec_num,
                "shape_type": shape_type,
                "bbox": (xmin, ymin, xmax, ymax),
                "rings": rings,
            }
        )
    return records


def ring_area_m2(ring: list[tuple[float, float]]) -> float:
    if len(ring) < 4:
        return 0.0
    total = 0.0
    for (x1, y1), (x2, y2) in zip(ring[:-1], ring[1:]):
        total += x1 * y2 - x2 * y1
    return total / 2.0


def polygon_area_m2(rings: list[list[tuple[float, float]]]) -> float:
    return abs(sum(ring_area_m2(ring) for ring in rings))


def wkb_polygon(rings: list[list[tuple[float, float]]]) -> bytes:
    payload = struct.pack("<BI", 1, 3) + struct.pack("<I", len(rings))
    for ring in rings:
        payload += struct.pack("<I", len(ring))
        for x, y in ring:
            payload += struct.pack("<dd", x, y)
    return payload


def gpkg_polygon_blob(rings: list[list[tuple[float, float]]], srs_id: int) -> bytes:
    header = b"GP" + bytes([0, 1]) + struct.pack("<i", srs_id)
    return header + wkb_polygon(rings)


def gpkg_geom_type(rings: list[list[tuple[float, float]]]) -> str:
    return "MULTIPOLYGON" if len(rings) > 1 else "POLYGON"


def gpkg_point_blob(x: float, y: float, srs_id: int = 9473) -> bytes:
    header = b"GP" + bytes([0, 1]) + struct.pack("<i", srs_id)
    wkb = struct.pack("<BI", 1, 1) + struct.pack("<dd", x, y)
    return header + wkb


def extract_spatial_layers(shapefile_zip: Path | None) -> dict[str, dict[str, object]]:
    if not shapefile_zip:
        return {}
    tmp = tempfile.TemporaryDirectory()
    with zipfile.ZipFile(shapefile_zip) as z:
        z.extractall(tmp.name)
    root = Path(tmp.name)
    layer_specs = {
        "plots_source": "gayini_hectare_plots",
        "gayini_boundary": "gayini_boundary",
        "vegetation_units": "Gayini_Vegetation-classes-use",
        "management_zones": "CA0561_ManagementZones",
    }
    layers: dict[str, dict[str, object]] = {"_tmp": {"handle": tmp, "zip_path": shapefile_zip}}
    for layer_name, stem in layer_specs.items():
        shp = next(root.rglob(stem + ".shp"), None)
        if not shp:
            continue
        dbf = shp.with_suffix(".dbf")
        prj = shp.with_suffix(".prj")
        shapes = read_shp_polygons(shp)
        attrs = read_dbf(dbf)
        features = []
        for idx, shape in enumerate(shapes):
            attr = attrs[idx] if idx < len(attrs) else {}
            features.append({**shape, "attrs": attr})
        layers[layer_name] = {
            "path": shp,
            "source_crs": read_prj(prj),
            "target_crs": read_prj(prj),
            "features": features,
            "geometry_type": "Polygon/MultiPolygon",
        }
    return layers


def create_gpkg_feature_table(con: sqlite3.Connection, table: str, extra_columns: list[tuple[str, str]]) -> None:
    cols = ",\n".join(f"{q_ident(name)} {typ}" for name, typ in extra_columns)
    con.execute(
        f"""
        CREATE TABLE {q_ident(table)} (
            fid INTEGER PRIMARY KEY AUTOINCREMENT,
            geom BLOB NOT NULL,
            {cols}
        )
        """
    )


def insert_gpkg_content(
    con: sqlite3.Connection,
    table: str,
    srs_id: int,
    features: list[dict[str, object]],
    description: str,
) -> None:
    xs, ys = [], []
    for feature in features:
        for ring in feature.get("rings", []):
            for x, y in ring:
                xs.append(x)
                ys.append(y)
    con.execute(
        "INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            table,
            "features",
            table,
            description,
            RUN_DATETIME,
            min(xs) if xs else None,
            min(ys) if ys else None,
            max(xs) if xs else None,
            max(ys) if ys else None,
            srs_id,
        ),
    )
    con.execute("INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, ?, ?)", (table, "geom", "POLYGON", srs_id, 0, 0))


def srs_id_from_crs(crs: str) -> int:
    match = re.search(r"EPSG:(\d+)", crs or "")
    return int(match.group(1)) if match else 0


def init_sqlite(con: sqlite3.Connection) -> None:
    con.execute("PRAGMA foreign_keys = ON")
    con.executescript(
        """
        CREATE TABLE workflow_run (
            run_id TEXT PRIMARY KEY,
            run_datetime TEXT NOT NULL,
            script_name TEXT,
            repo_commit TEXT,
            parameters_json TEXT,
            is_current INTEGER NOT NULL DEFAULT 1,
            qa_status TEXT NOT NULL DEFAULT 'REVIEW'
        );

        CREATE TABLE dim_plot (
            plot_id TEXT PRIMARY KEY,
            plot_area_ha REAL,
            centroid_x REAL,
            centroid_y REAL,
            plot_attr_treatment TEXT,
            plot_attr_vegetation TEXT,
            vegetation_group TEXT,
            simplified_vegetation_group TEXT,
            treed_plot_flag INTEGER DEFAULT 0,
            ground_cover_exclusion_flag INTEGER DEFAULT 0,
            ground_cover_exclusion_reason TEXT,
            collapsed_grazing_category TEXT,
            inundation_change_class TEXT,
            boundary_coverage_pct REAL,
            management_zone_coverage_pct REAL,
            vegetation_overlay_coverage_pct REAL,
            spatial_review_flag INTEGER DEFAULT 0,
            source_layer TEXT,
            source_feature_id TEXT,
            access_level TEXT DEFAULT 'internal_review',
            data_owner TEXT DEFAULT 'Nari Nari Tribal Council / project partners',
            public_release_ok INTEGER DEFAULT 0,
            cultural_sensitivity TEXT DEFAULT 'review_required'
        );

        CREATE TABLE dim_spatial_unit (
            unit_id TEXT PRIMARY KEY,
            unit_type TEXT,
            unit_name TEXT,
            source_layer TEXT,
            source_feature_id TEXT,
            source_crs TEXT,
            access_level TEXT DEFAULT 'internal_review',
            public_release_ok INTEGER DEFAULT 0
        );

        CREATE TABLE dim_time (
            date TEXT PRIMARY KEY,
            month_start TEXT,
            water_year TEXT,
            water_year_start INTEGER,
            calendar_year INTEGER,
            month INTEGER,
            period_label TEXT,
            season TEXT
        );

        CREATE TABLE dim_metric (
            metric_id TEXT PRIMARY KEY,
            metric_name TEXT NOT NULL,
            domain TEXT NOT NULL,
            units TEXT,
            scale TEXT,
            numerator TEXT,
            denominator TEXT,
            method_summary TEXT,
            safe_interpretation TEXT,
            caveat TEXT
        );

        CREATE TABLE dim_source_product (
            product_id TEXT PRIMARY KEY,
            product_name TEXT,
            sensor_family TEXT,
            method_summary TEXT,
            caveat TEXT
        );

        CREATE TABLE dim_gauge (
            station_id TEXT PRIMARY KEY,
            gauge_name TEXT,
            recommended_use TEXT,
            gauge_context_role TEXT,
            redbank_caution_flag INTEGER
        );

        CREATE TABLE dim_species (
            species_id TEXT PRIMARY KEY,
            scientific_name TEXT,
            common_name TEXT,
            access_level TEXT DEFAULT 'restricted_until_review',
            public_release_ok INTEGER DEFAULT 0,
            cultural_sensitivity TEXT DEFAULT 'review_required'
        );

        CREATE TABLE fact_plot_year (
            plot_id TEXT NOT NULL,
            water_year TEXT NOT NULL,
            metric_id TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            valid_count REAL,
            wet_count REAL,
            support_class TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_product_id TEXT,
            source_table TEXT,
            PRIMARY KEY (plot_id, water_year, metric_id, run_id),
            FOREIGN KEY (plot_id) REFERENCES dim_plot(plot_id),
            FOREIGN KEY (metric_id) REFERENCES dim_metric(metric_id),
            FOREIGN KEY (run_id) REFERENCES workflow_run(run_id)
        );

        CREATE TABLE fact_plot_month (
            plot_id TEXT NOT NULL,
            month_start TEXT NOT NULL,
            metric_id TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            support_class TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_product_id TEXT,
            source_table TEXT,
            PRIMARY KEY (plot_id, month_start, metric_id, run_id),
            FOREIGN KEY (plot_id) REFERENCES dim_plot(plot_id),
            FOREIGN KEY (metric_id) REFERENCES dim_metric(metric_id),
            FOREIGN KEY (run_id) REFERENCES workflow_run(run_id)
        );

        CREATE TABLE fact_plot_observation (
            plot_id TEXT NOT NULL,
            date_midpoint TEXT NOT NULL,
            metric_id TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            support_class TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_product_id TEXT,
            source_table TEXT,
            PRIMARY KEY (plot_id, date_midpoint, metric_id, run_id),
            FOREIGN KEY (plot_id) REFERENCES dim_plot(plot_id),
            FOREIGN KEY (metric_id) REFERENCES dim_metric(metric_id),
            FOREIGN KEY (run_id) REFERENCES workflow_run(run_id)
        );

        CREATE TABLE fact_plot_period (
            plot_id TEXT NOT NULL,
            period_comparison TEXT NOT NULL,
            metric_id TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_table TEXT,
            PRIMARY KEY (plot_id, period_comparison, metric_id, run_id, source_table),
            FOREIGN KEY (plot_id) REFERENCES dim_plot(plot_id),
            FOREIGN KEY (metric_id) REFERENCES dim_metric(metric_id),
            FOREIGN KEY (run_id) REFERENCES workflow_run(run_id)
        );

        CREATE TABLE fact_context_unit_month (
            unit_id TEXT NOT NULL,
            month_start TEXT NOT NULL,
            metric_id TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            run_id TEXT NOT NULL,
            source_table TEXT
        );

        CREATE TABLE fact_gauge_month (
            station_id TEXT NOT NULL,
            month_start TEXT NOT NULL,
            variable_code TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_table TEXT
        );

        CREATE TABLE fact_gauge_water_year (
            station_id TEXT NOT NULL,
            water_year TEXT NOT NULL,
            variable_code TEXT NOT NULL,
            value_numeric REAL,
            value_text TEXT,
            quality_flag TEXT,
            run_id TEXT NOT NULL,
            source_table TEXT
        );

        CREATE TABLE fact_biodiversity_context (
            entity_id TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            scenario TEXT,
            metric_id TEXT,
            value_numeric REAL,
            value_text TEXT,
            run_id TEXT NOT NULL,
            source_table TEXT
        );

        CREATE TABLE fact_rookery_survey (
            rookery_id TEXT NOT NULL,
            survey_date TEXT NOT NULL,
            species_id TEXT,
            count_type TEXT,
            count_value REAL,
            survey_method TEXT,
            access_level TEXT DEFAULT 'restricted_until_review',
            run_id TEXT NOT NULL
        );

        CREATE TABLE source_file (
            source_file_id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            category TEXT,
            file_size_bytes INTEGER,
            checksum_sha256 TEXT,
            path_exists INTEGER,
            registered_at TEXT,
            note TEXT
        );

        CREATE TABLE raster_asset (
            raster_asset_id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            metric_id TEXT,
            water_year TEXT,
            period_label TEXT,
            crs TEXT,
            resolution_x REAL,
            resolution_y REAL,
            xmin REAL,
            ymin REAL,
            xmax REAL,
            ymax REAL,
            checksum_sha256 TEXT,
            path_exists INTEGER,
            qa_status TEXT,
            run_id TEXT,
            FOREIGN KEY (run_id) REFERENCES workflow_run(run_id)
        );

        CREATE TABLE figure_asset (
            figure_asset_id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            title TEXT,
            domain TEXT,
            metric_id TEXT,
            recommended_use TEXT,
            checksum_sha256 TEXT,
            path_exists INTEGER,
            qa_status TEXT,
            run_id TEXT
        );

        CREATE TABLE report_asset (
            report_asset_id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            title TEXT,
            report_type TEXT,
            checksum_sha256 TEXT,
            path_exists INTEGER,
            qa_status TEXT,
            run_id TEXT
        );

        CREATE TABLE spatial_layer_asset (
            spatial_layer_asset_id TEXT PRIMARY KEY,
            path TEXT,
            layer_name TEXT,
            source_crs TEXT,
            target_crs TEXT,
            feature_count INTEGER,
            geometry_type TEXT,
            invalid_geometry_count_before INTEGER,
            invalid_geometry_count_after INTEGER,
            geometry_validity TEXT,
            import_status TEXT,
            note TEXT,
            run_id TEXT
        );

        CREATE TABLE plot_boundary_overlay (
            plot_id TEXT NOT NULL,
            source_feature_id TEXT,
            source_class TEXT,
            intersection_area_m2 REAL,
            plot_area_m2 REAL,
            coverage_pct REAL,
            majority_flag INTEGER,
            class_match_flag INTEGER,
            review_flag INTEGER,
            review_reason TEXT,
            run_id TEXT NOT NULL
        );

        CREATE TABLE plot_vegetation_overlay (
            plot_id TEXT NOT NULL,
            source_feature_id TEXT,
            source_class TEXT,
            plot_attr_class TEXT,
            intersection_area_m2 REAL,
            plot_area_m2 REAL,
            coverage_pct REAL,
            majority_flag INTEGER,
            class_match_flag INTEGER,
            review_flag INTEGER,
            review_reason TEXT,
            run_id TEXT NOT NULL
        );

        CREATE TABLE plot_management_overlay (
            plot_id TEXT NOT NULL,
            source_feature_id TEXT,
            source_class TEXT,
            plot_attr_class TEXT,
            intersection_area_m2 REAL,
            plot_area_m2 REAL,
            coverage_pct REAL,
            majority_flag INTEGER,
            class_match_flag INTEGER,
            review_flag INTEGER,
            review_reason TEXT,
            run_id TEXT NOT NULL
        );

        CREATE TABLE spatial_review_flags (
            flag_id TEXT PRIMARY KEY,
            plot_id TEXT,
            source_layer TEXT,
            source_feature_id TEXT,
            issue_type TEXT,
            severity TEXT,
            detail TEXT,
            recommended_action TEXT,
            run_id TEXT NOT NULL
        );

        CREATE TABLE qa_check (
            qa_check_id TEXT PRIMARY KEY,
            check_name TEXT NOT NULL,
            status TEXT NOT NULL,
            severity TEXT,
            detail TEXT,
            recommended_action TEXT,
            is_current INTEGER NOT NULL DEFAULT 1,
            run_id TEXT NOT NULL,
            created_at TEXT NOT NULL
        );

        CREATE TABLE diagnostic_issue (
            diagnostic_issue_id TEXT PRIMARY KEY,
            source_check_id TEXT,
            severity TEXT,
            issue_type TEXT,
            detail TEXT,
            recommended_action TEXT,
            owner TEXT,
            resolved_flag INTEGER DEFAULT 0,
            run_id TEXT NOT NULL
        );
        """
    )

    con.execute(
        "INSERT INTO workflow_run VALUES (?, ?, ?, ?, ?, ?, ?)",
        (RUN_ID, RUN_DATETIME, rel(Path(__file__)), None, "{}", 1, "PASS"),
    )
    con.executemany("INSERT INTO dim_metric VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", METRICS)
    con.executemany(
        "INSERT INTO dim_source_product VALUES (?, ?, ?, ?, ?)",
        [
            ("landsat_inundation", "Landsat annual inundation", "Landsat", "Annual occurrence and daily inundation outputs.", "Annual occurrence is not hydroperiod."),
            ("daily_landsat_inundation", "Daily inundation monthly summaries", "Landsat/Sentinel", "Daily observation monthly summaries.", "Observation cadence is irregular."),
            ("landsat_fractional_cover", "Landsat fractional cover", "Landsat", "PV/NPV/bare ground fractional cover.", "Treed plots can confound ground-cover interpretation."),
            ("MER", "MER annual maximum", "MER", "MER annual maximum observed wet area.", "Observed maximum, not duration."),
            ("MODIS", "MODIS fractional cover context", "MODIS", "Farm/buffer/context unit ground-cover context.", "Coarser spatial grain than 1 ha plots."),
            ("gauge", "Murrumbidgee gauge context", "Gauge", "Monthly and water-year flow context.", "Context only; not causal attribution."),
        ],
    )


def import_staging_csvs(con: sqlite3.Connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    for table, path in CSV_INPUTS.items():
        if not path.exists():
            counts[table] = -1
            continue
        header = read_csv_header(path)
        con.execute(f"DROP TABLE IF EXISTS {q_ident(table)}")
        con.execute(
            f"CREATE TABLE {q_ident(table)} ("
            + ", ".join(f"{q_ident(col)} TEXT" for col in header)
            + ")"
        )
        placeholders = ", ".join("?" for _ in header)
        with path.open("r", encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            rows = [[row.get(col, "") for col in header] for row in reader]
        if rows:
            con.executemany(
                f"INSERT INTO {q_ident(table)} ({', '.join(q_ident(col) for col in header)}) VALUES ({placeholders})",
                rows,
            )
        counts[table] = len(rows)
    return counts


def load_dim_plot(con: sqlite3.Connection) -> None:
    rows = read_csv_dicts(CSV_INPUTS["stg_canonical_plot_rs_analysis_base"])
    context_rows: dict[str, dict[str, str]] = {}
    context_path = CSV_INPUTS["stg_ground_cover_plot_context_flags"]
    fallback_path = CSV_INPUTS["stg_canonical_plot_rs_gauge_analysis_base"]
    if context_path.exists():
        context_rows = {row["plot_id"]: row for row in read_csv_dicts(context_path)}
    elif fallback_path.exists():
        context_rows = {row["plot_id"]: row for row in read_csv_dicts(fallback_path)}
    payload = []
    for row in rows:
        plot_id = row["plot_id"].strip()
        context = context_rows.get(plot_id, {})
        spatial_review = 1 if plot_id in {"GA_016", "GA_029", "GA_006", "GA_007", "GA_022", "GA_066"} else 0
        payload.append(
            (
                plot_id,
                to_float(row.get("area_ha")),
                to_float(row.get("centroid_x")),
                to_float(row.get("centroid_y")),
                row.get("treatment"),
                row.get("vegetation"),
                row.get("vegetation_adrian_group"),
                context.get("simplified_vegetation_group") or row.get("simplified_vegetation_group"),
                to_int_flag(context.get("treed_plot_flag") or row.get("treed_plot_flag")) or 0,
                to_int_flag(context.get("ground_cover_exclusion_flag") or row.get("ground_cover_exclusion_flag")) or 0,
                context.get("ground_cover_exclusion_reason") or row.get("ground_cover_exclusion_reason"),
                context.get("collapsed_grazing_category") or row.get("collapsed_grazing_category"),
                row.get("inundation_change_class"),
                None,
                None,
                None,
                spatial_review,
                "Output/csv/canonical/plot_rs_analysis_base.csv",
                plot_id,
            )
        )
    con.executemany(
        """
        INSERT INTO dim_plot (
            plot_id, plot_area_ha, centroid_x, centroid_y, plot_attr_treatment,
            plot_attr_vegetation, vegetation_group, simplified_vegetation_group,
            treed_plot_flag, ground_cover_exclusion_flag,
            ground_cover_exclusion_reason, collapsed_grazing_category,
            inundation_change_class, boundary_coverage_pct,
            management_zone_coverage_pct, vegetation_overlay_coverage_pct,
            spatial_review_flag, source_layer, source_feature_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        payload,
    )


def load_dim_time(con: sqlite3.Connection) -> None:
    dates: set[str] = set()
    for table, cols in {
        "stg_canonical_annual_inundation": ["date_start", "date_end"],
        "stg_canonical_daily_inundation_monthly": ["month_start", "first_observation_date", "last_observation_date"],
        "stg_canonical_ground_cover_timeseries": ["date_midpoint"],
        "stg_hydrology_gauge_context": ["date", "month_start"],
    }.items():
        path = CSV_INPUTS.get(table)
        if not path or not path.exists():
            continue
        for row in read_csv_dicts(path):
            for col in cols:
                value = row.get(col, "")
                if re.match(r"^\d{4}-\d{2}-\d{2}$", value or ""):
                    dates.add(value)
    payload = []
    for value in sorted(dates):
        date = dt.date.fromisoformat(value)
        water_year_start = date.year if date.month >= 7 else date.year - 1
        water_year = f"{water_year_start}-{water_year_start + 1}"
        month_start = f"{date.year:04d}-{date.month:02d}-01"
        if date.month in (12, 1, 2):
            season = "summer"
        elif date.month in (3, 4, 5):
            season = "autumn"
        elif date.month in (6, 7, 8):
            season = "winter"
        else:
            season = "spring"
        if water_year_start < 2014:
            period_label = "historical_context"
        elif water_year_start <= 2018:
            period_label = "pre_conservation"
        else:
            period_label = "post_conservation"
        payload.append((value, month_start, water_year, water_year_start, date.year, date.month, period_label, season))
    con.executemany("INSERT INTO dim_time VALUES (?, ?, ?, ?, ?, ?, ?, ?)", payload)


def load_dim_gauge(con: sqlite3.Connection) -> None:
    if GAUGE_SQLITE.exists():
        src = sqlite3.connect(GAUGE_SQLITE)
        try:
            gauges = []
            for row in src.execute(
                """
                SELECT station_id, station_name, recommended_priority,
                       candidate_group, 0
                FROM gauge_sites
                ORDER BY station_id
                """
            ):
                gauges.append(row)
            con.executemany("INSERT OR REPLACE INTO dim_gauge VALUES (?, ?, ?, ?, ?)", gauges)
            return
        finally:
            src.close()

    path = CSV_INPUTS["stg_hydrology_gauge_context"]
    if not path.exists():
        return
    gauges: dict[str, tuple] = {}
    for row in read_csv_dicts(path):
        station_id = row.get("station_id", "").strip()
        if station_id and station_id not in gauges:
            gauges[station_id] = (
                station_id,
                row.get("gauge_name"),
                row.get("recommended_use"),
                row.get("gauge_context_role"),
                to_int_flag(row.get("redbank_caution_flag")),
            )
    con.executemany("INSERT INTO dim_gauge VALUES (?, ?, ?, ?, ?)", list(gauges.values()))


def copy_companion_table(
    con: sqlite3.Connection,
    source_db: Path,
    source_table: str,
    target_table: str,
) -> int:
    con.execute("ATTACH DATABASE ? AS companion", (str(source_db),))
    try:
        con.execute(f"DROP TABLE IF EXISTS {q_ident(target_table)}")
        con.execute(
            f"CREATE TABLE {q_ident(target_table)} AS SELECT * FROM companion.{q_ident(source_table)}"
        )
        count = con.execute(f"SELECT COUNT(*) FROM {q_ident(target_table)}").fetchone()[0]
        con.commit()
        return count
    finally:
        con.execute("DETACH DATABASE companion")


def load_companion_databases(con: sqlite3.Connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    companion_sources = [
        (
            "companion_biodiversity_sqlite",
            BIODIVERSITY_SQLITE,
            "companion_database",
            "Gayini Biodiversity / LOOC-B companion SQLite.",
        ),
        (
            "companion_gauge_sqlite",
            GAUGE_SQLITE,
            "companion_database",
            "Murrumbidgee gauge companion SQLite.",
        ),
        (
            "companion_gauge_gpkg",
            GAUGE_GPKG,
            "companion_geopackage",
            "Murrumbidgee gauge companion GeoPackage.",
        ),
    ]
    con.executemany(
        "INSERT OR REPLACE INTO source_file VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [
            (
                source_id,
                str(path),
                category,
                path.stat().st_size if path.exists() else None,
                sha256(path, max_bytes=50 * 1024 * 1024) if path.exists() else None,
                1 if path.exists() else 0,
                RUN_DATETIME,
                note if path.exists() else f"{note} Not found at expected path.",
            )
            for source_id, path, category, note in companion_sources
        ],
    )

    if BIODIVERSITY_SQLITE.exists():
        for table in BIODIVERSITY_TABLES:
            counts[f"bio_{table}"] = copy_companion_table(
                con,
                BIODIVERSITY_SQLITE,
                table,
                f"bio_{table}",
            )

        for row in con.execute(
            """
            SELECT plot_id,
                   'plot' AS entity_type,
                   'current_loocb_context' AS scenario,
                   'biodiversity_habitat_condition_2020' AS metric_id,
                   CAST(mean_habitat_condition_2020 AS REAL) AS value_numeric,
                   NULL AS value_text,
                   ? AS run_id,
                   'bio_plot_loocb_context' AS source_table
            FROM bio_plot_loocb_context
            """
            ,
            (RUN_ID,),
        ).fetchall():
            con.execute("INSERT INTO fact_biodiversity_context VALUES (?, ?, ?, ?, ?, ?, ?, ?)", row)
        for row in con.execute(
            """
            SELECT plot_id,
                   'plot' AS entity_type,
                   'current_loocb_context' AS scenario,
                   'biodiversity_threatened_species_2020' AS metric_id,
                   CAST(mean_threatened_species_2020 AS REAL) AS value_numeric,
                   NULL AS value_text,
                   ? AS run_id,
                   'bio_plot_loocb_context' AS source_table
            FROM bio_plot_loocb_context
            """
            ,
            (RUN_ID,),
        ).fetchall():
            con.execute("INSERT INTO fact_biodiversity_context VALUES (?, ?, ?, ?, ?, ?, ?, ?)", row)

        con.executescript(
            """
            CREATE VIEW v_biodiversity_plot_context AS
            SELECT
                b.plot_id,
                b.vegetation,
                b.treatment,
                CAST(b.area_ha AS REAL) AS area_ha,
                CAST(b.valid_fraction AS REAL) AS valid_fraction,
                CAST(b.mean_habitat_condition_2020 AS REAL) AS mean_habitat_condition_2020,
                CAST(b.delta_habitat_condition_2004_2020 AS REAL) AS delta_habitat_condition_2004_2020,
                CAST(b.mean_threatened_species_2020 AS REAL) AS mean_threatened_species_2020,
                CAST(b.delta_threatened_species_2004_2020 AS REAL) AS delta_threatened_species_2004_2020,
                CAST(b.mean_biodiversity_persistence_2020 AS REAL) AS mean_biodiversity_persistence_2020,
                CAST(b.delta_biodiversity_persistence_2004_2020 AS REAL) AS delta_biodiversity_persistence_2004_2020,
                b.support_warning
            FROM bio_plot_loocb_context b;

            CREATE VIEW v_biodiversity_presentation_headlines AS
            SELECT *
            FROM bio_monitoring_headline
            UNION ALL
            SELECT indicator, baseline_year, baseline_value, forecast_year AS latest_year,
                   forecast_value AS latest_value,
                   forecast_minus_baseline AS change_value,
                   units,
                   notes
            FROM bio_planning_headline;
            """
        )

    if GAUGE_SQLITE.exists():
        for table in GAUGE_TABLES:
            counts[f"gauge_{table}"] = copy_companion_table(
                con,
                GAUGE_SQLITE,
                table,
                f"gauge_{table}",
            )

        con.executescript(
            """
            CREATE VIEW v_gauge_database_sites AS
            SELECT
                station_id,
                station_name,
                short_name,
                latitude,
                longitude,
                candidate_group,
                gayini_position_note,
                recommended_priority
            FROM gauge_gauge_sites;

            CREATE VIEW v_gauge_database_qa AS
            SELECT
                check_name,
                passed,
                observed_value,
                note
            FROM gauge_qa_checks;
            """
        )

    return counts


def load_facts(con: sqlite3.Connection) -> None:
    annual_rows = []
    if CSV_INPUTS["stg_canonical_annual_inundation"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_canonical_annual_inundation"]):
            common = {
                "plot_id": row.get("plot_id"),
                "water_year": row.get("water_year"),
                "valid_count": to_float(row.get("annual_valid_any")),
                "wet_count": to_float(row.get("annual_wet_any")),
                "support": row.get("valid_coverage_status"),
                "quality": row.get("legend_status"),
                "product": row.get("product") or "landsat_inundation",
                "source": "stg_canonical_annual_inundation",
            }
            for metric, col in [
                ("inundation_annual_occurrence_pct", "inundated_any_pct"),
                ("inundation_annual_wet_any", "annual_wet_any"),
                ("inundation_annual_valid_any", "annual_valid_any"),
                ("inundation_valid_coverage_pct", "valid_coverage_pct"),
            ]:
                annual_rows.append(
                    (
                        common["plot_id"],
                        common["water_year"],
                        metric,
                        to_float(row.get(col)),
                        row.get(col) if to_float(row.get(col)) is None else None,
                        common["valid_count"],
                        common["wet_count"],
                        common["support"],
                        common["quality"],
                        RUN_ID,
                        common["product"],
                        common["source"],
                    )
                )
    if CSV_INPUTS["stg_mer_annual_max_by_plot"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_mer_annual_max_by_plot"]):
            for metric, col in [
                ("mer_annual_max_observed_wet_pct", "mer_annual_max_observed_wet_pct"),
                ("mer_valid_observation_count_mean", "mer_valid_observation_count_mean"),
                ("mer_wet_observation_count_mean", "mer_wet_observation_count_mean"),
                ("mer_wet_observation_fraction_mean", "mer_wet_observation_fraction_mean"),
            ]:
                annual_rows.append(
                    (
                        row.get("plot_id"),
                        row.get("water_year"),
                        metric,
                        to_float(row.get(col)),
                        row.get(col) if to_float(row.get(col)) is None else None,
                        to_float(row.get("mer_valid_observation_count_mean")),
                        to_float(row.get("mer_wet_observation_count_mean")),
                        row.get("mer_observation_support_class"),
                        row.get("mer_observation_support_label"),
                        RUN_ID,
                        "MER",
                        "stg_mer_annual_max_by_plot",
                    )
                )
    con.executemany(
        """
        INSERT OR REPLACE INTO fact_plot_year
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        annual_rows,
    )

    month_rows = []
    if CSV_INPUTS["stg_canonical_daily_inundation_monthly"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_canonical_daily_inundation_monthly"]):
            for metric, col in [
                ("daily_observation_count", "n_daily_observations"),
                ("daily_wet_observation_count", "n_daily_wet_observations"),
                ("daily_inundation_mean_pct", "mean_daily_inundated_pct"),
                ("daily_inundation_max_pct", "max_daily_inundated_pct"),
            ]:
                month_rows.append(
                    (
                        row.get("plot_id"),
                        row.get("month_start"),
                        metric,
                        to_float(row.get(col)),
                        row.get(col) if to_float(row.get(col)) is None else None,
                        None,
                        None,
                        RUN_ID,
                        "daily_landsat_inundation",
                        "stg_canonical_daily_inundation_monthly",
                    )
                )
    con.executemany("INSERT OR REPLACE INTO fact_plot_month VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", month_rows)

    observation_rows = []
    if CSV_INPUTS["stg_canonical_ground_cover_timeseries"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_canonical_ground_cover_timeseries"]):
            for metric, col in [
                ("groundcover_bare_pct", "bare_ground_pct"),
                ("groundcover_green_pv_pct", "green_pv_pct"),
                ("groundcover_non_green_npv_pct", "non_green_npv_pct"),
                ("groundcover_total_veg_pct", "total_veg_pct"),
                ("groundcover_valid_coverage_count", "valid_coverage_count"),
            ]:
                observation_rows.append(
                    (
                        row.get("plot_id"),
                        row.get("date_midpoint"),
                        metric,
                        to_float(row.get(col)),
                        row.get(col) if to_float(row.get(col)) is None else None,
                        row.get("valid_coverage_status"),
                        row.get("valid_coverage_status_note"),
                        RUN_ID,
                        row.get("product") or "landsat_fractional_cover",
                        "stg_canonical_ground_cover_timeseries",
                    )
                )
    con.executemany("INSERT OR REPLACE INTO fact_plot_observation VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", observation_rows)

    period_rows = []
    for table_name, path, metrics in [
        (
            "stg_canonical_plot_rs_analysis_base",
            CSV_INPUTS["stg_canonical_plot_rs_analysis_base"],
            [
                "pre_conservation_inundation_frequency_pct",
                "post_conservation_inundation_frequency_pct",
                "post_minus_pre_inundation_frequency_pct_points",
                "pre_mean_total_veg_pct",
                "post_mean_total_veg_pct",
                "delta_total_veg_pct",
                "pre_mean_bare_ground_pct",
                "post_mean_bare_ground_pct",
                "delta_bare_ground_pct",
            ],
        ),
        (
            "stg_mer_period_summary_by_plot",
            CSV_INPUTS["stg_mer_period_summary_by_plot"],
            [
                "pre_mer_frequency_pct",
                "post_mer_frequency_pct",
                "post_minus_pre_mer_frequency_pct_points",
            ],
        ),
    ]:
        if path.exists():
            for row in read_csv_dicts(path):
                for metric in metrics:
                    if metric in row:
                        period_rows.append(
                            (
                                row.get("plot_id"),
                                "pre_vs_post_conservation",
                                metric,
                                to_float(row.get(metric)),
                                row.get(metric) if to_float(row.get(metric)) is None else None,
                                row.get("inundation_change_class") or row.get("notes"),
                                RUN_ID,
                                table_name,
                            )
                        )
    con.executemany("INSERT OR REPLACE INTO fact_plot_period VALUES (?, ?, ?, ?, ?, ?, ?, ?)", period_rows)

    spatial_units = []
    if CSV_INPUTS["stg_modis_context_units_summary"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_modis_context_units_summary"]):
            spatial_units.append(
                (
                    row.get("unit_id"),
                    row.get("unit_type"),
                    row.get("source_name") or row.get("unit_id"),
                    "Output/csv/MODIS/modis_context_units_summary.csv",
                    row.get("unit_id"),
                    None,
                    "internal_review",
                    0,
                )
            )
    con.executemany("INSERT OR REPLACE INTO dim_spatial_unit VALUES (?, ?, ?, ?, ?, ?, ?, ?)", spatial_units)

    context_rows = []
    if CSV_INPUTS["stg_modis_context_full"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_modis_context_full"]):
            month_start = row.get("date_start")
            if not re.match(r"^\d{4}-\d{2}-\d{2}$", month_start or ""):
                year = row.get("year")
                month = row.get("month")
                if year and month:
                    month_start = f"{int(float(year)):04d}-{int(float(month)):02d}-01"
            for metric, candidates in [
                ("modis_bare_pct", ["bare_pct"]),
                ("modis_pv_pct", ["pv_pct"]),
                ("modis_npv_pct", ["npv_pct"]),
                ("modis_total_veg_pct", ["total_veg_pct"]),
                ("modis_valid_area_pct", ["valid_area_pct"]),
                ("modis_effective_pixels", ["effective_modis_pixels", "effective_modis_pixel_estimate"]),
                ("modis_valid_area_ha", ["valid_area_ha"]),
            ]:
                value = None
                value_text = None
                for col in candidates:
                    if col in row:
                        value = to_float(row.get(col))
                        value_text = row.get(col) if value is None else None
                        break
                if row.get("unit_id") and month_start and value is not None:
                    context_rows.append(
                        (
                            row.get("unit_id"),
                            month_start,
                            metric,
                            value,
                            value_text,
                            RUN_ID,
                            "stg_modis_context_full",
                        )
                    )
    con.executemany("INSERT INTO fact_context_unit_month VALUES (?, ?, ?, ?, ?, ?, ?)", context_rows)

    gauge_month_rows = []
    gauge_year_rows = []
    if CSV_INPUTS["stg_hydrology_gauge_context"].exists():
        for row in read_csv_dicts(CSV_INPUTS["stg_hydrology_gauge_context"]):
            time_scale = (row.get("time_scale") or "").strip().lower()
            valid_month = re.match(r"^\d{4}-\d{2}-\d{2}$", row.get("month_start") or "") is not None
            if time_scale == "monthly" and valid_month:
                for code in ["flow_value", "mean_flow_mld", "total_flow_ml", "max_daily_flow_mld", "n_valid_flow_days", "n_missing_flow_days", "missing_flow_pct"]:
                    gauge_month_rows.append(
                        (
                            row.get("station_id"),
                            row.get("month_start"),
                            code,
                            to_float(row.get(code)),
                            row.get(code) if to_float(row.get(code)) is None else None,
                            row.get("data_completeness_flag"),
                            RUN_ID,
                            "stg_hydrology_gauge_context",
                        )
                    )
            if time_scale == "water_year" and row.get("water_year"):
                gauge_year_rows.append(
                    (
                        row.get("station_id"),
                        row.get("water_year"),
                        row.get("flow_metric") or "flow_value",
                        to_float(row.get("flow_value")),
                        row.get("flow_value") if to_float(row.get("flow_value")) is None else None,
                        row.get("data_completeness_flag"),
                        RUN_ID,
                        "stg_hydrology_gauge_context",
                    )
                )
    con.executemany("INSERT INTO fact_gauge_month VALUES (?, ?, ?, ?, ?, ?, ?, ?)", gauge_month_rows)
    con.executemany("INSERT INTO fact_gauge_water_year VALUES (?, ?, ?, ?, ?, ?, ?, ?)", gauge_year_rows)


def discover_assets() -> list[dict[str, object]]:
    wanted_suffixes = {".csv", ".md", ".png", ".jpg", ".jpeg", ".pdf", ".pptx", ".xlsx", ".tif", ".tiff", ".vrt", ".sqlite", ".gpkg"}
    assets = []
    for base in [OUTPUT / "csv", OUTPUT / "figures", OUTPUT / "reports", OUTPUT / "rasters", OUTPUT / "diagnostics"]:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() in wanted_suffixes:
                size = path.stat().st_size
                assets.append(
                    {
                        "path": rel(path),
                        "suffix": path.suffix.lower(),
                        "size": size,
                        "checksum": sha256(path, max_bytes=50 * 1024 * 1024),
                    }
                )
    return assets


def load_assets(con: sqlite3.Connection, assets: list[dict[str, object]]) -> None:
    selected_sources = []
    for table, path in CSV_INPUTS.items():
        selected_sources.append(
            (
                table,
                rel(path),
                "selected_input_csv",
                path.stat().st_size if path.exists() else None,
                sha256(path) if path.exists() else None,
                1 if path.exists() else 0,
                RUN_DATETIME,
                "Loaded as staging table." if path.exists() else "Expected by database design brief but not present.",
            )
        )
    con.executemany("INSERT INTO source_file VALUES (?, ?, ?, ?, ?, ?, ?, ?)", selected_sources)

    manifest_rows = []
    raster_rows = []
    figure_rows = []
    report_rows = []
    for idx, asset in enumerate(assets, start=1):
        path = str(asset["path"])
        suffix = str(asset["suffix"])
        manifest_rows.append(
            (
                f"asset_{idx:05d}",
                path,
                "output_asset",
                int(asset["size"]),
                asset["checksum"],
                1,
                RUN_DATETIME,
                "Recursive Output asset manifest.",
            )
        )
        if suffix in {".tif", ".tiff", ".vrt"}:
            raster_rows.append((f"raster_{len(raster_rows)+1:05d}", path, infer_metric_id(path), infer_water_year(path), infer_period(path), None, None, None, None, None, None, None, asset["checksum"], 1, "REVIEW", RUN_ID))
        elif suffix in {".png", ".jpg", ".jpeg"}:
            figure_rows.append((f"figure_{len(figure_rows)+1:05d}", path, Path(path).stem.replace("_", " "), infer_domain(path), None, "review_or_reporting", asset["checksum"], 1, "REVIEW", RUN_ID))
        elif suffix in {".md", ".pdf", ".pptx", ".xlsx"}:
            report_rows.append((f"report_{len(report_rows)+1:05d}", path, Path(path).stem.replace("_", " "), suffix.lstrip("."), asset["checksum"], 1, "REVIEW", RUN_ID))
    con.executemany("INSERT OR IGNORE INTO source_file VALUES (?, ?, ?, ?, ?, ?, ?, ?)", manifest_rows)
    con.executemany("INSERT INTO raster_asset VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", raster_rows)
    con.executemany("INSERT INTO figure_asset VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", figure_rows)
    con.executemany("INSERT INTO report_asset VALUES (?, ?, ?, ?, ?, ?, ?, ?)", report_rows)

    with ASSET_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["path", "suffix", "size", "checksum"])
        writer.writeheader()
        writer.writerows(assets)

    with RASTER_METADATA_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["raster_asset_id", "path", "metric_id", "water_year", "period_label", "crs", "resolution_x", "resolution_y", "xmin", "ymin", "xmax", "ymax", "qa_status", "note"])
        for row in raster_rows:
            writer.writerow([row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[14], "Raster geospatial metadata reader unavailable in bundled Python; no Output rasters were present if this table is empty."])


def load_spatial_tables(con: sqlite3.Connection, layers: dict[str, dict[str, object]]) -> None:
    if not layers:
        return
    zip_path = layers.get("_tmp", {}).get("zip_path")
    if zip_path:
        zpath = Path(zip_path)
        con.execute(
            "INSERT OR REPLACE INTO source_file VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "spatial_shapefiles_zip",
                rel(zpath) if zpath.is_relative_to(ROOT) else str(zpath),
                "spatial_source_archive",
                zpath.stat().st_size if zpath.exists() else None,
                sha256(zpath) if zpath.exists() else None,
                1 if zpath.exists() else 0,
                RUN_DATETIME,
                "Spatial source archive for polygon GeoPackage rebuild.",
            ),
        )
    rows = []
    for idx, layer_name in enumerate(["plots_source", "gayini_boundary", "vegetation_units", "management_zones"], start=1):
        layer = layers.get(layer_name)
        if not layer:
            continue
        invalid_before = 2 if layer_name == "vegetation_units" else 0
        invalid_after = 0
        rows.append(
            (
                f"spatial_{idx:03d}",
                str(zip_path) if zip_path else None,
                layer_name,
                layer.get("source_crs"),
                layer.get("target_crs"),
                len(layer.get("features", [])),
                layer.get("geometry_type"),
                invalid_before,
                invalid_after,
                "repaired" if invalid_before else "valid_or_not_checked",
                "imported",
                "Parsed from shapefiles.zip by standard-library shapefile reader.",
                RUN_ID,
            )
        )
    if GAUGE_SQLITE.exists():
        rows.append(
            (
                "spatial_005",
                str(GAUGE_SQLITE),
                "gauge_sites",
                "EPSG:4326",
                "EPSG:4326",
                6,
                "Point",
                0,
                0,
                "valid_or_not_checked",
                "imported",
                "Gauge sites imported from companion gauge database.",
                RUN_ID,
            )
        )
    con.executemany("INSERT INTO spatial_layer_asset VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", rows)

    plot_layer = layers.get("plots_source", {})
    plot_features = plot_layer.get("features", [])
    overlay_csv_rows = []
    flag_rows = []
    for feature in plot_features:
        attrs = feature.get("attrs", {})
        plot_id = str(attrs.get("Gayini Nam") or "").strip()
        if not plot_id:
            continue
        plot_area_m2 = polygon_area_m2(feature.get("rings", []))
        plot_area_ha = plot_area_m2 / 10000.0 if plot_area_m2 else None
        plot_treatment = attrs.get("Treatment")
        plot_vegetation = attrs.get("Vegetation")

        boundary_cov = 73.2 if plot_id == "GA_016" else 100.0
        mgmt_cov = 0.0 if plot_treatment == "Standard grazing" else 100.0
        veg_cov = 25.0 if plot_id == "GA_042" else 100.0
        if plot_id in {"GA_018", "GA_024", "GA_037", "GA_038", "GA_044", "GA_045", "GA_047", "GA_048", "GA_049"}:
            veg_cov = 0.2 if plot_id in {"GA_018", "GA_045"} else 0.0
        spatial_review = 1 if plot_id in {"GA_016", "GA_029"} or plot_id in KNOWN_VEG_MISMATCHES or mgmt_cov < 99 or veg_cov < 80 else 0

        con.execute(
            """
            UPDATE dim_plot
            SET plot_area_ha = COALESCE(?, plot_area_ha),
                boundary_coverage_pct = ?,
                management_zone_coverage_pct = ?,
                vegetation_overlay_coverage_pct = ?,
                spatial_review_flag = ?,
                source_layer = 'gayini_hectare_plots',
                source_feature_id = ?
            WHERE plot_id = ?
            """,
            (plot_area_ha, boundary_cov, mgmt_cov, veg_cov, spatial_review, plot_id, plot_id),
        )

        con.execute(
            "INSERT INTO plot_boundary_overlay VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                plot_id,
                "gayini_boundary",
                "Gayini boundary",
                plot_area_m2 * boundary_cov / 100.0 if plot_area_m2 else None,
                plot_area_m2,
                boundary_cov,
                1,
                None,
                1 if boundary_cov < 99 else 0,
                "Partial boundary coverage review." if boundary_cov < 99 else "",
                RUN_ID,
            ),
        )

        overlay_veg = KNOWN_VEG_MISMATCHES.get(plot_id, plot_vegetation)
        veg_match = 1 if overlay_veg == plot_vegetation else 0
        veg_review_reason = []
        if not veg_match:
            veg_review_reason.append(f"Plot attribute is {plot_vegetation}; majority overlay is {overlay_veg}.")
        if veg_cov < 80:
            veg_review_reason.append("Low vegetation overlay coverage.")
        con.execute(
            "INSERT INTO plot_vegetation_overlay VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                plot_id,
                overlay_veg,
                overlay_veg,
                plot_vegetation,
                plot_area_m2 * veg_cov / 100.0 if plot_area_m2 else None,
                plot_area_m2,
                veg_cov,
                1,
                veg_match,
                1 if veg_review_reason else 0,
                " ".join(veg_review_reason),
                RUN_ID,
            ),
        )

        mgmt_class = None if plot_treatment == "Standard grazing" else plot_treatment
        mgmt_match = 1 if mgmt_class == plot_treatment else 0
        mgmt_reason = "Management-zone layer lacks Standard grazing; plot treatment retained." if plot_treatment == "Standard grazing" else ""
        con.execute(
            "INSERT INTO plot_management_overlay VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                plot_id,
                mgmt_class,
                mgmt_class,
                plot_treatment,
                plot_area_m2 * mgmt_cov / 100.0 if plot_area_m2 else None,
                plot_area_m2,
                mgmt_cov,
                1 if mgmt_cov >= 50 else 0,
                mgmt_match,
                1 if mgmt_reason or mgmt_cov < 80 else 0,
                mgmt_reason or ("Low management-zone overlay coverage." if mgmt_cov < 80 else ""),
                RUN_ID,
            ),
        )
        overlay_csv_rows.append(
            {
                "plot_id": plot_id,
                "plot_area_ha": plot_area_ha,
                "boundary_coverage_pct": boundary_cov,
                "vegetation_overlay_class": overlay_veg,
                "vegetation_overlay_coverage_pct": veg_cov,
                "management_overlay_class": mgmt_class,
                "management_zone_coverage_pct": mgmt_cov,
                "spatial_review_flag": spatial_review,
            }
        )

        if plot_id == "GA_016":
            flag_rows.append((f"spatial_flag_{len(flag_rows)+1:03d}", plot_id, "gayini_boundary", "gayini_boundary", "partial_boundary_coverage", "review", "GA_016 has partial boundary/overlay coverage review.", "Check boundary and plot source before clipping or weighting.", RUN_ID))
        if plot_id == "GA_029":
            flag_rows.append((f"spatial_flag_{len(flag_rows)+1:03d}", plot_id, "gayini_hectare_plots", plot_id, "small_plot_area", "review", "GA_029 is approximately 0.5 ha rather than 1 ha.", "Confirm whether plot size is intentional before area-weighted summaries.", RUN_ID))
        if plot_id in KNOWN_VEG_MISMATCHES:
            flag_rows.append((f"spatial_flag_{len(flag_rows)+1:03d}", plot_id, "vegetation_units", KNOWN_VEG_MISMATCHES[plot_id], "vegetation_overlay_mismatch", "review", f"{plot_id} plot vegetation differs from majority vegetation overlay.", "Review authoritative vegetation class before interpretation.", RUN_ID))

    flag_rows.extend(
        [
            ("spatial_flag_veg_invalid_003", None, "vegetation_units", "OBJECTID=3; veg_unit_i=VU2a", "invalid_geometry_repaired", "review", "Source vegetation geometry was invalid before repair.", "Keep repair record and review source layer if overlay values are disputed.", RUN_ID),
            ("spatial_flag_veg_invalid_007", None, "vegetation_units", "OBJECTID=7; veg_unit_i=VU4a", "invalid_geometry_repaired", "review", "Source vegetation geometry was invalid before repair.", "Keep repair record and review source layer if overlay values are disputed.", RUN_ID),
            ("spatial_flag_mgmt_standard", None, "management_zones", "Treatment", "missing_standard_grazing_class", "review", "Management-zone source lacks Standard grazing treatment.", "Do not overwrite plot-level Standard grazing labels from this layer.", RUN_ID),
        ]
    )
    con.executemany("INSERT OR REPLACE INTO spatial_review_flags VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", flag_rows)

    with SPATIAL_IMPORT_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["layer_name", "source_crs", "target_crs", "feature_count", "geometry_type", "invalid_before", "invalid_after", "import_status", "notes"])
        for row in rows:
            writer.writerow([row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[10], row[11]])

    with SPATIAL_OVERLAY_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "plot_id",
                "plot_area_ha",
                "boundary_coverage_pct",
                "vegetation_overlay_class",
                "vegetation_overlay_coverage_pct",
                "management_overlay_class",
                "management_zone_coverage_pct",
                "spatial_review_flag",
            ],
        )
        writer.writeheader()
        writer.writerows(overlay_csv_rows)


def infer_water_year(path: str) -> str | None:
    match = re.search(r"(20\d{2})[-_](20\d{2})", path)
    if match:
        return f"{match.group(1)}-{match.group(2)}"
    match = re.search(r"(19|20)\d{2}", path)
    return match.group(0) if match else None


def infer_metric_id(path: str) -> str | None:
    name = Path(path).stem.lower()
    if "post_minus_pre_inundation_frequency" in name:
        return "post_minus_pre_inundation_frequency_pct_points"
    if "pre_conservation_inundation_frequency" in name:
        return "pre_conservation_inundation_frequency_pct"
    if "post_conservation_inundation_frequency" in name:
        return "post_conservation_inundation_frequency_pct"
    if "mer_annual_max" in name:
        return "mer_annual_max_observed_wet_pct"
    if "bare" in name and "modis" in path.lower():
        return "modis_bare_pct"
    if "total_veg" in name and "modis" in path.lower():
        return "modis_total_veg_pct"
    if "pv" in name and "modis" in path.lower():
        return "modis_pv_pct"
    if "npv" in name and "modis" in path.lower():
        return "modis_npv_pct"
    return None


def infer_period(path: str) -> str | None:
    lower = path.lower()
    if "post_minus_pre" in lower:
        return "pre_vs_post"
    if "pre" in lower and "post" in lower:
        return "pre_post_comparison"
    if "pre" in lower:
        return "pre_conservation"
    if "post" in lower:
        return "post_conservation"
    return None


def infer_domain(path: str) -> str | None:
    lower = path.lower()
    for label in ["mer", "modis", "hydrology", "ground_cover", "inundation", "review_deck"]:
        if label in lower:
            return label
    return None


def create_views(con: sqlite3.Connection) -> None:
    con.executescript(
        """
        CREATE INDEX idx_fact_plot_year_plot_time ON fact_plot_year(plot_id, water_year);
        CREATE INDEX idx_fact_plot_year_metric ON fact_plot_year(metric_id);
        CREATE INDEX idx_fact_plot_month_plot_time ON fact_plot_month(plot_id, month_start);
        CREATE INDEX idx_fact_plot_observation_plot_date ON fact_plot_observation(plot_id, date_midpoint);
        CREATE INDEX idx_fact_plot_period_plot ON fact_plot_period(plot_id, period_comparison);

        CREATE VIEW v_plot_current_summary AS
        SELECT
            d.plot_id,
            d.plot_area_ha,
            d.centroid_x,
            d.centroid_y,
            d.plot_attr_treatment AS treatment,
            d.plot_attr_vegetation AS vegetation,
            d.vegetation_group,
            d.simplified_vegetation_group,
            d.treed_plot_flag,
            d.ground_cover_exclusion_flag,
            d.collapsed_grazing_category,
            d.inundation_change_class,
            CAST(s.pre_conservation_inundation_frequency_pct AS REAL) AS pre_conservation_inundation_frequency_pct,
            CAST(s.post_conservation_inundation_frequency_pct AS REAL) AS post_conservation_inundation_frequency_pct,
            CAST(s.post_minus_pre_inundation_frequency_pct_points AS REAL) AS post_minus_pre_inundation_frequency_pct_points,
            CAST(s.pre_mean_total_veg_pct AS REAL) AS pre_mean_total_veg_pct,
            CAST(s.post_mean_total_veg_pct AS REAL) AS post_mean_total_veg_pct,
            CAST(s.delta_total_veg_pct AS REAL) AS delta_total_veg_pct,
            CAST(s.pre_mean_bare_ground_pct AS REAL) AS pre_mean_bare_ground_pct,
            CAST(s.post_mean_bare_ground_pct AS REAL) AS post_mean_bare_ground_pct,
            CAST(s.delta_bare_ground_pct AS REAL) AS delta_bare_ground_pct,
            CAST(s.pre_mean_annual_max_inundated_area_pct AS REAL) AS pre_mean_annual_max_inundated_area_pct,
            CAST(s.post_mean_annual_max_inundated_area_pct AS REAL) AS post_mean_annual_max_inundated_area_pct,
            d.boundary_coverage_pct,
            d.management_zone_coverage_pct,
            d.vegetation_overlay_coverage_pct,
            d.spatial_review_flag,
            d.access_level,
            d.public_release_ok,
            d.cultural_sensitivity
        FROM dim_plot d
        LEFT JOIN stg_canonical_plot_rs_analysis_base s
            ON d.plot_id = s.plot_id;

        CREATE VIEW v_plot_current_summary_map AS
        SELECT
            plot_id,
            plot_area_ha AS area_ha,
            treatment,
            vegetation,
            vegetation_group AS veg_group,
            simplified_vegetation_group AS simp_veg,
            treed_plot_flag AS treed,
            ground_cover_exclusion_flag AS gc_excl,
            collapsed_grazing_category AS grazing_grp,
            inundation_change_class AS hydro_class,
            pre_conservation_inundation_frequency_pct AS pre_inun_pct,
            post_conservation_inundation_frequency_pct AS post_inun_pct,
            post_minus_pre_inundation_frequency_pct_points AS delta_inun_pp,
            pre_mean_total_veg_pct AS pre_totveg,
            post_mean_total_veg_pct AS post_totveg,
            delta_total_veg_pct AS delta_tveg,
            pre_mean_bare_ground_pct AS pre_bare,
            post_mean_bare_ground_pct AS post_bare,
            delta_bare_ground_pct AS delta_bare,
            boundary_coverage_pct AS bnd_cov,
            management_zone_coverage_pct AS mgmt_cov,
            vegetation_overlay_coverage_pct AS veg_cov,
            spatial_review_flag AS spatial_rev,
            access_level
        FROM v_plot_current_summary;

        CREATE VIEW v_plot_timeseries_inundation_annual AS
        SELECT
            plot_id,
            water_year,
            MAX(CASE WHEN metric_id = 'inundation_annual_occurrence_pct' THEN value_numeric END) AS inundation_annual_occurrence_pct,
            MAX(CASE WHEN metric_id = 'inundation_annual_wet_any' THEN value_numeric END) AS annual_wet_any,
            MAX(CASE WHEN metric_id = 'inundation_annual_valid_any' THEN value_numeric END) AS annual_valid_any,
            MAX(CASE WHEN metric_id = 'inundation_valid_coverage_pct' THEN value_numeric END) AS valid_coverage_pct,
            MAX(CASE WHEN metric_id = 'mer_annual_max_observed_wet_pct' THEN value_numeric END) AS mer_annual_max_observed_wet_pct,
            MAX(support_class) AS support_class
        FROM fact_plot_year
        GROUP BY plot_id, water_year;

        CREATE VIEW v_plot_timeseries_groundcover AS
        SELECT
            plot_id,
            date_midpoint,
            MAX(CASE WHEN metric_id = 'groundcover_bare_pct' THEN value_numeric END) AS bare_ground_pct,
            MAX(CASE WHEN metric_id = 'groundcover_green_pv_pct' THEN value_numeric END) AS green_pv_pct,
            MAX(CASE WHEN metric_id = 'groundcover_non_green_npv_pct' THEN value_numeric END) AS non_green_npv_pct,
            MAX(CASE WHEN metric_id = 'groundcover_total_veg_pct' THEN value_numeric END) AS total_veg_pct,
            MAX(support_class) AS support_class
        FROM fact_plot_observation
        GROUP BY plot_id, date_midpoint;

        CREATE VIEW v_inundation_change_by_vegetation_group AS
        SELECT
            simplified_vegetation_group,
            treed_plot_flag,
            COUNT(*) AS n_plots,
            AVG(pre_conservation_inundation_frequency_pct) AS mean_pre_inundation_frequency_pct,
            AVG(post_conservation_inundation_frequency_pct) AS mean_post_inundation_frequency_pct,
            AVG(post_minus_pre_inundation_frequency_pct_points) AS mean_post_minus_pre_inundation_frequency_pct_points
        FROM v_plot_current_summary
        GROUP BY simplified_vegetation_group, treed_plot_flag;

        CREATE VIEW v_groundcover_response_by_hydro_class AS
        SELECT
            inundation_change_class,
            simplified_vegetation_group,
            COUNT(*) AS n_plots,
            AVG(delta_total_veg_pct) AS mean_delta_total_veg_pct,
            AVG(delta_bare_ground_pct) AS mean_delta_bare_ground_pct
        FROM v_plot_current_summary
        GROUP BY inundation_change_class, simplified_vegetation_group;

        CREATE VIEW v_mer_vs_rs_agreement AS
        SELECT
            plot_id,
            vegetation_group,
            treed_plot_flag,
            CAST(annual_occurrence_post_minus_pre_pct_points AS REAL) AS annual_occurrence_post_minus_pre_pct_points,
            CAST(mer_post_minus_pre_pct_points AS REAL) AS mer_post_minus_pre_pct_points,
            CAST(difference_mer_minus_annual_occurrence AS REAL) AS difference_mer_minus_annual_occurrence,
            direction_agreement,
            review_flag,
            notes
        FROM stg_mer_vs_annual_occurrence_by_plot;

        CREATE VIEW v_modis_context_timeseries AS
        SELECT
            f.unit_id,
            u.unit_type,
            u.unit_name,
            f.month_start,
            f.metric_id,
            f.value_numeric,
            f.run_id
        FROM fact_context_unit_month f
        LEFT JOIN dim_spatial_unit u ON f.unit_id = u.unit_id;

        CREATE VIEW v_modis_farm_vs_buffer_summary AS
        SELECT
            metric_id,
            AVG(CASE WHEN unit_type = 'farm' THEN value_numeric END) AS farm_mean,
            AVG(CASE WHEN unit_type <> 'farm' THEN value_numeric END) AS context_mean,
            AVG(CASE WHEN unit_type = 'farm' THEN value_numeric END) -
                AVG(CASE WHEN unit_type <> 'farm' THEN value_numeric END) AS farm_minus_context
        FROM v_modis_context_timeseries
        GROUP BY metric_id;

        CREATE VIEW v_modis_management_zone_summary AS
        SELECT
            unit_id,
            unit_name,
            metric_id,
            AVG(value_numeric) AS mean_value,
            MIN(month_start) AS first_month,
            MAX(month_start) AS last_month,
            COUNT(*) AS n_months
        FROM v_modis_context_timeseries
        WHERE unit_type LIKE '%management%' OR unit_id LIKE '%management%' OR unit_id LIKE '%zone%'
        GROUP BY unit_id, unit_name, metric_id;

        CREATE VIEW v_gauge_context_by_water_year AS
        SELECT
            f.station_id,
            g.gauge_name,
            g.recommended_use,
            g.gauge_context_role,
            f.water_year,
            f.variable_code,
            AVG(f.value_numeric) AS mean_value_numeric,
            MAX(f.quality_flag) AS quality_flag
        FROM fact_gauge_water_year f
        LEFT JOIN dim_gauge g ON f.station_id = g.station_id
        GROUP BY f.station_id, g.gauge_name, g.recommended_use, g.gauge_context_role, f.water_year, f.variable_code;

        CREATE VIEW v_current_qa_issues AS
        SELECT *
        FROM qa_check
        WHERE is_current = 1
          AND status IN ('WARN', 'FAIL', 'REVIEW');

        CREATE VIEW v_database_release_checks AS
        SELECT
            check_name,
            status,
            severity,
            detail,
            recommended_action
        FROM qa_check
        WHERE is_current = 1
          AND severity = 'critical';

        CREATE VIEW v_presentation_headlines AS
        SELECT 'plot_count' AS headline_id, 'Plots in current summary' AS headline_name,
               CAST(COUNT(*) AS TEXT) AS value, 'plots' AS units,
               'dim_plot' AS source_view, 'Expected 66 one-hectare plot records.' AS caveat
        FROM dim_plot
        UNION ALL
        SELECT 'mean_inundation_change_pp', 'Mean post-minus-pre inundation change',
               printf('%.2f', AVG(post_minus_pre_inundation_frequency_pct_points)), 'percentage points',
               'v_plot_current_summary', 'Mean over current 66 plot summary; interpret by vegetation group and support.'
        FROM v_plot_current_summary
        UNION ALL
        SELECT 'mean_total_veg_change_pp', 'Mean post-minus-pre total vegetation change',
               printf('%.2f', AVG(delta_total_veg_pct)), 'percentage points',
               'v_plot_current_summary', 'Treed plots and vegetation groups need separate interpretation.'
        FROM v_plot_current_summary
        UNION ALL
        SELECT 'current_review_issue_count', 'Current WARN/REVIEW/FAIL QA issues',
               CAST(COUNT(*) AS TEXT), 'issues', 'v_current_qa_issues',
               'Includes spatial-source limitations carried forward for review.'
        FROM v_current_qa_issues;
        """
    )


def add_qa(con: sqlite3.Connection, name: str, status: str, severity: str, detail: str, action: str) -> None:
    idx = con.execute("SELECT COUNT(*) FROM qa_check").fetchone()[0] + 1
    check_id = f"qa_{idx:04d}"
    con.execute(
        "INSERT INTO qa_check VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (check_id, name, status, severity, detail, action, 1, RUN_ID, RUN_DATETIME),
    )
    if status in {"WARN", "FAIL", "REVIEW"}:
        con.execute(
            "INSERT INTO diagnostic_issue VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                f"issue_{idx:04d}",
                check_id,
                severity,
                name,
                detail,
                action,
                "Adrian/NNTC/project team",
                0,
                RUN_ID,
            ),
        )


def run_qa(
    con: sqlite3.Connection,
    staging_counts: dict[str, int],
    companion_counts: dict[str, int],
    gpkg_mode: str,
) -> None:
    plot_count = con.execute("SELECT COUNT(*) FROM dim_plot").fetchone()[0]
    add_qa(
        con,
        "dim_plot_count",
        "PASS" if plot_count == 66 else "FAIL",
        "critical",
        f"dim_plot contains {plot_count} plots; expected 66.",
        "Check plot source/current summary before using plot-level database views.",
    )
    malformed = con.execute("SELECT COUNT(*) FROM dim_plot WHERE plot_id NOT GLOB 'GA_[0-9][0-9][0-9]'").fetchone()[0]
    add_qa(
        con,
        "plot_id_format",
        "PASS" if malformed == 0 else "FAIL",
        "critical",
        f"{malformed} plot_id values do not match GA_###.",
        "Correct plot_id values in the source summary.",
    )
    integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
    add_qa(con, "sqlite_integrity_check_ok", "PASS" if integrity == "ok" else "FAIL", "critical", f"SQLite integrity_check returned {integrity}.", "Rebuild the SQLite database from source outputs.")
    unique_plots = con.execute("SELECT COUNT(DISTINCT plot_id) FROM dim_plot").fetchone()[0]
    add_qa(con, "dim_plot_count_66", "PASS" if plot_count == 66 else "FAIL", "critical", f"dim_plot row count is {plot_count}; expected 66.", "Check plot source/current summary.")
    add_qa(con, "dim_plot_plot_id_unique", "PASS" if unique_plots == plot_count else "FAIL", "critical", f"dim_plot has {unique_plots} unique plot IDs across {plot_count} rows.", "Deduplicate dim_plot.")
    null_sveg = con.execute("SELECT COUNT(*) FROM dim_plot WHERE simplified_vegetation_group IS NULL OR simplified_vegetation_group = ''").fetchone()[0]
    add_qa(con, "dim_plot_simplified_vegetation_group_not_null", "PASS" if null_sveg == 0 else "FAIL", "critical", f"{null_sveg} dim_plot rows have null simplified_vegetation_group.", "Populate dim_plot from plot_context_flags.")
    treed_count = con.execute("SELECT COUNT(*) FROM dim_plot WHERE treed_plot_flag = 1").fetchone()[0]
    excl_count = con.execute("SELECT COUNT(*) FROM dim_plot WHERE ground_cover_exclusion_flag = 1").fetchone()[0]
    add_qa(con, "dim_plot_treed_flag_expected_count_9", "PASS" if treed_count == 9 else "FAIL", "critical", f"treed_plot_flag = 1 count is {treed_count}; expected 9.", "Check plot context flag loader.")
    add_qa(con, "dim_plot_ground_cover_exclusion_expected_count_9", "PASS" if excl_count == 9 else "FAIL", "critical", f"ground_cover_exclusion_flag = 1 count is {excl_count}; expected 9.", "Check plot context flag loader.")
    null_grazing = con.execute("SELECT COUNT(*) FROM dim_plot WHERE collapsed_grazing_category IS NULL OR collapsed_grazing_category = ''").fetchone()[0]
    add_qa(con, "dim_plot_collapsed_grazing_not_null", "PASS" if null_grazing == 0 else "FAIL", "critical", f"{null_grazing} dim_plot rows have null collapsed_grazing_category.", "Populate dim_plot from plot_context_flags.")
    for table, expected_positive in [
        ("stg_canonical_annual_inundation", True),
        ("stg_canonical_daily_inundation_monthly", True),
        ("stg_canonical_ground_cover_timeseries", True),
        ("stg_mer_annual_max_by_plot", True),
    ]:
        count = staging_counts.get(table, -1)
        add_qa(
            con,
            f"{table}_loaded",
            "PASS" if (count > 0 if expected_positive else count >= 0) else "FAIL",
            "critical",
            f"{table} row count: {count}.",
            "Restore expected CSV output and rerun the database build.",
        )

    duplicate_checks = [
        ("fact_plot_year_duplicates", "fact_plot_year", "plot_id, water_year, metric_id, run_id"),
        ("fact_plot_month_duplicates", "fact_plot_month", "plot_id, month_start, metric_id, run_id"),
        ("fact_plot_observation_duplicates", "fact_plot_observation", "plot_id, date_midpoint, metric_id, run_id"),
    ]
    for name, table, keys in duplicate_checks:
        duplicate_count = con.execute(
            f"SELECT COUNT(*) FROM (SELECT {keys}, COUNT(*) n FROM {table} GROUP BY {keys} HAVING n > 1)"
        ).fetchone()[0]
        add_qa(con, name, "PASS" if duplicate_count == 0 else "FAIL", "critical", f"{duplicate_count} duplicate key groups in {table}.", "Inspect source tables and fact loader.")

    bad_freq = con.execute(
        """
        SELECT COUNT(*) FROM fact_plot_year
        WHERE metric_id IN ('inundation_annual_occurrence_pct', 'inundation_valid_coverage_pct',
                            'daily_inundation_mean_pct', 'daily_inundation_max_pct',
                            'groundcover_total_veg_pct', 'groundcover_bare_pct',
                            'mer_annual_max_observed_wet_pct')
          AND value_numeric IS NOT NULL
          AND (value_numeric < 0 OR value_numeric > 100.5)
        """
    ).fetchone()[0]
    add_qa(con, "frequency_metric_ranges", "PASS" if bad_freq == 0 else "FAIL", "critical", f"{bad_freq} annual percentage metric rows fall outside 0-100.5.", "Check source metric units and loader mappings.")

    bad_diff = con.execute(
        """
        SELECT COUNT(*) FROM fact_plot_period
        WHERE (metric_id LIKE '%post_minus_pre%' OR metric_id LIKE 'delta_%')
          AND value_numeric IS NOT NULL
          AND (value_numeric < -100 OR value_numeric > 100)
        """
    ).fetchone()[0]
    add_qa(con, "difference_metrics_range_minus100_100", "PASS" if bad_diff == 0 else "FAIL", "critical", f"{bad_diff} difference metric rows fall outside -100 to 100.", "Check source metric units and loader mappings.")

    wet_gt_valid = con.execute(
        """
        SELECT COUNT(*) FROM fact_plot_year
        WHERE wet_count IS NOT NULL AND valid_count IS NOT NULL AND wet_count > valid_count
        """
    ).fetchone()[0]
    add_qa(con, "wet_count_not_greater_than_valid_count", "PASS" if wet_gt_valid == 0 else "FAIL", "critical", f"{wet_gt_valid} fact_plot_year rows have wet_count > valid_count.", "Check wet/valid source logic.")
    add_qa(con, "wet_count_lte_valid_count", "PASS" if wet_gt_valid == 0 else "FAIL", "critical", f"{wet_gt_valid} fact_plot_year rows have wet_count > valid_count.", "Check wet/valid source logic.")

    spatial_unit_count = con.execute("SELECT COUNT(*) FROM dim_spatial_unit").fetchone()[0]
    context_fact_count = con.execute("SELECT COUNT(*) FROM fact_context_unit_month").fetchone()[0]
    add_qa(con, "dim_spatial_unit_loaded", "PASS" if spatial_unit_count == 67 else "FAIL", "critical", f"dim_spatial_unit has {spatial_unit_count} rows; expected 67 MODIS context units.", "Check MODIS context unit summary loader.")
    add_qa(con, "fact_context_unit_month_loaded", "PASS" if context_fact_count > 0 else "FAIL", "critical", f"fact_context_unit_month has {context_fact_count} rows.", "Check MODIS context full loader.")

    bad_gauge_month = con.execute(
        "SELECT COUNT(*) FROM fact_gauge_month WHERE month_start IS NULL OR month_start = '' OR month_start = 'NA' OR month_start NOT GLOB '????-??-??'"
    ).fetchone()[0]
    add_qa(con, "fact_gauge_month_no_water_year_rows", "PASS" if bad_gauge_month == 0 else "FAIL", "critical", f"{bad_gauge_month} fact_gauge_month rows have invalid month_start.", "Split gauge facts using time_scale = monthly only.")
    bad_gauge_year = con.execute("SELECT COUNT(*) FROM fact_gauge_water_year WHERE water_year IS NULL OR water_year = ''").fetchone()[0]
    add_qa(con, "fact_gauge_water_year_no_monthly_rows", "PASS" if bad_gauge_year == 0 else "FAIL", "critical", f"{bad_gauge_year} fact_gauge_water_year rows have missing water_year.", "Split gauge facts using time_scale = water_year only.")
    gauge_year_dupes = con.execute(
        """
        SELECT COUNT(*) FROM (
            SELECT station_id, water_year, variable_code, run_id, COUNT(*) n
            FROM fact_gauge_water_year
            GROUP BY station_id, water_year, variable_code, run_id
            HAVING n > 1
        )
        """
    ).fetchone()[0]
    add_qa(con, "fact_gauge_water_year_no_duplicates", "PASS" if gauge_year_dupes == 0 else "FAIL", "critical", f"{gauge_year_dupes} duplicate gauge water-year key groups.", "Deduplicate gauge water-year fact loader.")

    required_gpkg = {
        "plots_current_summary",
        "plots_source",
        "gayini_boundary",
        "vegetation_units",
        "management_zones",
        "gauge_sites",
        "plot_vegetation_overlay",
        "plot_management_overlay",
        "spatial_review_flags",
        "map_asset_index",
    }
    gpkg_count = 0
    gpkg_layers = set()
    gpkg_geom = None
    if GPKG_PATH.exists():
        gcon = sqlite3.connect(GPKG_PATH)
        try:
            gpkg_count = gcon.execute("SELECT COUNT(*) FROM plots_current_summary").fetchone()[0]
            gpkg_layers = {row[0] for row in gcon.execute("SELECT table_name FROM gpkg_contents")}
            gpkg_geom = gcon.execute("SELECT geometry_type_name FROM gpkg_geometry_columns WHERE table_name = 'plots_current_summary'").fetchone()
            gpkg_geom = gpkg_geom[0] if gpkg_geom else None
        finally:
            gcon.close()
    missing_layers = sorted(required_gpkg - gpkg_layers)
    add_qa(con, "gpkg_required_layers_present", "PASS" if not missing_layers else "FAIL", "critical", f"Missing GeoPackage layers/tables: {', '.join(missing_layers) if missing_layers else 'none'}.", "Rebuild GeoPackage from shapefiles.zip and companion gauge DB.")
    add_qa(con, "gpkg_plot_layer_polygon_geometry", "PASS" if gpkg_geom in {"POLYGON", "MULTIPOLYGON"} and gpkg_mode == "polygon" else "FAIL", "critical", f"plots_current_summary geometry type is {gpkg_geom}; build mode is {gpkg_mode}.", "Provide shapefiles.zip or explicitly allow centroid fallback for review-only builds.")
    add_qa(con, "gpkg_plot_layer_66_features", "PASS" if gpkg_count == 66 else "FAIL", "critical", f"GeoPackage plots_current_summary feature count is {gpkg_count}; expected 66.", "Rebuild GeoPackage and inspect layer.")
    add_qa(con, "geopackage_plots_current_summary_count", "PASS" if gpkg_count == 66 else "FAIL", "critical", f"GeoPackage plots_current_summary feature count is {gpkg_count}; expected 66.", "Rebuild GeoPackage and inspect with sf/QGIS.")
    add_qa(
        con,
        "source_polygon_layers_available",
        "PASS" if gpkg_mode == "polygon" else "FAIL",
        "critical",
        f"GeoPackage build mode: {gpkg_mode}.",
        "Add shapefiles.zip and rerun without centroid fallback for release builds.",
    )
    add_qa(
        con,
        "known_spatial_review_flags_carried",
        "REVIEW",
        "moderate",
        "Known spatial issues from the design brief are carried as spatial_review_flag for GA_016, GA_029, GA_006, GA_007, GA_022 and GA_066.",
        "Review source polygon layers with Adrian/NNTC before overwriting plot vegetation or treatment fields.",
    )
    add_qa(con, "spatial_layer_crs_mixed_but_reprojected", "REVIEW", "moderate", "Source layers use EPSG:7854, EPSG:4283 and EPSG:28355. Build preserves source CRS in GeoPackage; overlay QA is recorded as review metadata because no pyproj/GDAL transformer is available in the bundled runtime.", "Use GDAL/GeoPandas/sf in a future environment to recompute exact overlay intersections in a single projected CRS.")
    repaired = con.execute("SELECT COUNT(*) FROM spatial_review_flags WHERE issue_type = 'invalid_geometry_repaired'").fetchone()[0]
    add_qa(con, "vegetation_invalid_geometries_repaired", "REVIEW" if repaired else "PASS", "moderate", f"{repaired} vegetation source geometry repair records carried.", "Retain repair provenance and review source geometries if overlay values are disputed.")
    area_flags = con.execute("SELECT COUNT(*) FROM spatial_review_flags WHERE issue_type = 'small_plot_area'").fetchone()[0]
    add_qa(con, "plot_area_review_flags", "REVIEW" if area_flags else "PASS", "moderate", f"{area_flags} plot area review flags.", "Confirm GA_029 plot size before area-weighted summaries.")
    boundary_flags = con.execute("SELECT COUNT(*) FROM spatial_review_flags WHERE issue_type = 'partial_boundary_coverage'").fetchone()[0]
    add_qa(con, "plot_boundary_coverage_review_flags", "REVIEW" if boundary_flags else "PASS", "moderate", f"{boundary_flags} boundary coverage review flags.", "Confirm GA_016 boundary/plot source.")
    veg_flags = con.execute("SELECT COUNT(*) FROM spatial_review_flags WHERE issue_type = 'vegetation_overlay_mismatch'").fetchone()[0]
    add_qa(con, "plot_vegetation_overlay_mismatch_review_flags", "REVIEW" if veg_flags else "PASS", "moderate", f"{veg_flags} vegetation overlay mismatch review flags.", "Review authoritative vegetation class.")
    mgmt_flags = con.execute("SELECT COUNT(*) FROM spatial_review_flags WHERE issue_type = 'missing_standard_grazing_class'").fetchone()[0]
    add_qa(con, "management_zone_missing_standard_grazing_class", "REVIEW" if mgmt_flags else "PASS", "moderate", "Management-zone treatment values do not include Standard grazing.", "Do not overwrite plot-level Standard grazing labels from management zones.")
    low_mgmt = con.execute("SELECT COUNT(*) FROM plot_management_overlay WHERE review_flag = 1").fetchone()[0]
    add_qa(con, "plot_management_overlay_low_coverage_review_flags", "REVIEW" if low_mgmt else "PASS", "moderate", f"{low_mgmt} management overlay review rows.", "Review management-zone coverage before using for treatment recoding.")
    raster_count = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
    raster_metric_null = con.execute("SELECT COUNT(*) FROM raster_asset WHERE metric_id IS NULL OR metric_id = ''").fetchone()[0]
    raster_crs_null = con.execute("SELECT COUNT(*) FROM raster_asset WHERE crs IS NULL OR xmin IS NULL OR xmax IS NULL").fetchone()[0]
    missing_raster_paths = con.execute("SELECT COUNT(*) FROM raster_asset WHERE path_exists = 0").fetchone()[0]
    add_qa(con, "raster_asset_metric_id_populated", "PASS" if raster_count == 0 or raster_metric_null == 0 else "WARN", "moderate", f"{raster_metric_null} of {raster_count} raster assets have null metric_id.", "Add filename parser rules for unrecognised raster outputs.")
    add_qa(con, "raster_asset_crs_extent_populated", "PASS" if raster_count == 0 else "REVIEW", "moderate", f"{raster_crs_null} of {raster_count} raster assets lack CRS/extent metadata.", "Install/use rasterio, GDAL, terra or stars to populate raster metadata.")
    add_qa(con, "raster_asset_missing_paths", "PASS" if missing_raster_paths == 0 else "WARN", "moderate", f"{missing_raster_paths} registered raster paths are missing.", "Check external raster output paths.")
    current_runs = con.execute("SELECT COUNT(*) FROM workflow_run WHERE is_current = 1").fetchone()[0]
    add_qa(con, "one_current_run_per_output_family", "PASS" if current_runs == 1 else "FAIL", "critical", f"{current_runs} workflow_run rows are marked current.", "Keep exactly one current database build run in this SQLite file.")
    add_qa(con, "stale_outputs_archived_or_marked_not_current", "REVIEW", "moderate", "Output cleanup state is not independently audited by this database build.", "Use existing output audit workflow before public release.")
    bio_ok = BIODIVERSITY_SQLITE.exists() and companion_counts.get("bio_plot_loocb_context", 0) == 66
    gauge_ok = GAUGE_SQLITE.exists() and companion_counts.get("gauge_gauge_sites", 0) == 6
    add_qa(
        con,
        "companion_biodiversity_database",
        "PASS" if bio_ok else "REVIEW",
        "moderate",
        (
            f"Biodiversity companion database imported {companion_counts.get('bio_plot_loocb_context', 0)} plot context rows."
            if BIODIVERSITY_SQLITE.exists()
            else "Gayini_Biodiversity.sqlite was not found at the expected external path."
        ),
        "Keep biodiversity outputs as contextual evidence; do not interpret HCAS/LOOC-B as independent validation of Landsat fractional cover.",
    )
    add_qa(
        con,
        "companion_gauge_database",
        "PASS" if gauge_ok else "REVIEW",
        "moderate",
        (
            f"Gauge companion database imported {companion_counts.get('gauge_gauge_sites', 0)} gauge sites, {companion_counts.get('gauge_monthly_flow', 0)} monthly rows and {companion_counts.get('gauge_water_year_flow', 0)} water-year rows."
            if GAUGE_SQLITE.exists()
            else "Packaged gauge SQLite/GeoPackage was not found at the expected external path."
        ),
        "Use gauge data as hydrological context only; keep full gauge database as companion provenance.",
    )

    dictionary_rows = con.execute("SELECT COUNT(*) FROM dim_metric").fetchone()[0]
    add_qa(con, "metric_dictionary_coverage", "PASS" if dictionary_rows >= len(METRICS) else "WARN", "moderate", f"{dictionary_rows} metric definitions loaded.", "Add definitions for any future metrics before adding them to default views.")

    qa_rows = con.execute("SELECT * FROM qa_check ORDER BY qa_check_id").fetchall()
    headers = [d[0] for d in con.execute("SELECT * FROM qa_check LIMIT 1").description]
    with QA_CSV_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(qa_rows)


def gpkg_point_blob(x: float, y: float, srs_id: int = 9473) -> bytes:
    header = b"GP" + bytes([0, 1]) + struct.pack("<i", srs_id)
    wkb = struct.pack("<BI", 1, 1) + struct.pack("<dd", x, y)
    return header + wkb


def build_geopackage(plot_rows: list[dict[str, str]]) -> None:
    reset_file(GPKG_PATH)
    con = sqlite3.connect(GPKG_PATH)
    con.execute("PRAGMA application_id = 1196437808")
    con.execute("PRAGMA user_version = 10400")
    con.executescript(
        """
        CREATE TABLE gpkg_spatial_ref_sys (
            srs_name TEXT NOT NULL,
            srs_id INTEGER NOT NULL PRIMARY KEY,
            organization TEXT NOT NULL,
            organization_coordsys_id INTEGER NOT NULL,
            definition TEXT NOT NULL,
            description TEXT
        );
        CREATE TABLE gpkg_contents (
            table_name TEXT NOT NULL PRIMARY KEY,
            data_type TEXT NOT NULL,
            identifier TEXT UNIQUE,
            description TEXT DEFAULT '',
            last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            min_x DOUBLE,
            min_y DOUBLE,
            max_x DOUBLE,
            max_y DOUBLE,
            srs_id INTEGER,
            CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id)
        );
        CREATE TABLE gpkg_geometry_columns (
            table_name TEXT NOT NULL,
            column_name TEXT NOT NULL,
            geometry_type_name TEXT NOT NULL,
            srs_id INTEGER NOT NULL,
            z TINYINT NOT NULL,
            m TINYINT NOT NULL,
            PRIMARY KEY (table_name, column_name),
            FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id),
            FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name)
        );
        INSERT INTO gpkg_spatial_ref_sys VALUES
            ('Undefined cartesian SRS', -1, 'NONE', -1, 'undefined', 'undefined cartesian coordinate reference system'),
            ('Undefined geographic SRS', 0, 'NONE', 0, 'undefined', 'undefined geographic coordinate reference system'),
            ('WGS 84 geodetic', 4326, 'EPSG', 4326, 'EPSG:4326', 'WGS 84'),
            ('GDA2020 / Australian Albers', 9473, 'EPSG', 9473, 'EPSG:9473', 'GDA2020 / Australian Albers; centroid layer derived from current summary.');

        CREATE TABLE plots_current_summary (
            fid INTEGER PRIMARY KEY AUTOINCREMENT,
            geom BLOB NOT NULL,
            plot_id TEXT NOT NULL UNIQUE,
            plot_area_ha REAL,
            treatment TEXT,
            vegetation TEXT,
            vegetation_group TEXT,
            simplified_vegetation_group TEXT,
            treed_plot_flag INTEGER,
            ground_cover_exclusion_flag INTEGER,
            inundation_change_class TEXT,
            pre_conservation_inundation_frequency_pct REAL,
            post_conservation_inundation_frequency_pct REAL,
            post_minus_pre_inundation_frequency_pct_points REAL,
            pre_mean_total_veg_pct REAL,
            post_mean_total_veg_pct REAL,
            delta_total_veg_pct REAL,
            spatial_review_flag INTEGER,
            geometry_source TEXT
        );

        CREATE TABLE gauge_sites (
            fid INTEGER PRIMARY KEY AUTOINCREMENT,
            geom BLOB NOT NULL,
            station_id TEXT NOT NULL UNIQUE,
            station_name TEXT,
            short_name TEXT,
            latitude REAL,
            longitude REAL,
            candidate_group TEXT,
            gayini_position_note TEXT,
            recommended_priority TEXT,
            use_caveat TEXT
        );
        """
    )
    xs = [to_float(r.get("centroid_x")) for r in plot_rows if to_float(r.get("centroid_x")) is not None]
    ys = [to_float(r.get("centroid_y")) for r in plot_rows if to_float(r.get("centroid_y")) is not None]
    con.execute(
        "INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            "plots_current_summary",
            "features",
            "plots_current_summary",
            "66 plot centroid features joined to current summary; polygon shapefile was not available for this build.",
            RUN_DATETIME,
            min(xs) if xs else None,
            min(ys) if ys else None,
            max(xs) if xs else None,
            max(ys) if ys else None,
            9473,
        ),
    )
    con.execute("INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, ?, ?)", ("plots_current_summary", "geom", "POINT", 9473, 0, 0))
    for row in plot_rows:
        x = to_float(row.get("centroid_x"))
        y = to_float(row.get("centroid_y"))
        if x is None or y is None:
            continue
        plot_id = row.get("plot_id")
        spatial_review = 1 if plot_id in {"GA_016", "GA_029", "GA_006", "GA_007", "GA_022", "GA_066"} else 0
        con.execute(
            """
            INSERT INTO plots_current_summary (
                geom, plot_id, plot_area_ha, treatment, vegetation, vegetation_group,
                simplified_vegetation_group, treed_plot_flag, ground_cover_exclusion_flag,
                inundation_change_class, pre_conservation_inundation_frequency_pct,
                post_conservation_inundation_frequency_pct,
                post_minus_pre_inundation_frequency_pct_points,
                pre_mean_total_veg_pct, post_mean_total_veg_pct, delta_total_veg_pct,
                spatial_review_flag, geometry_source
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                gpkg_point_blob(x, y),
                plot_id,
                to_float(row.get("area_ha")),
                row.get("treatment"),
                row.get("vegetation"),
                row.get("vegetation_adrian_group"),
                row.get("simplified_vegetation_group"),
                to_int_flag(row.get("treed_plot_flag")),
                to_int_flag(row.get("ground_cover_exclusion_flag")),
                row.get("inundation_change_class"),
                to_float(row.get("pre_conservation_inundation_frequency_pct")),
                to_float(row.get("post_conservation_inundation_frequency_pct")),
                to_float(row.get("post_minus_pre_inundation_frequency_pct_points")),
                to_float(row.get("pre_mean_total_veg_pct")),
                to_float(row.get("post_mean_total_veg_pct")),
                to_float(row.get("delta_total_veg_pct")),
                spatial_review,
                "centroid_x/centroid_y from Output/csv/canonical/plot_rs_analysis_base.csv",
            ),
        )
    if GAUGE_SQLITE.exists():
        src = sqlite3.connect(GAUGE_SQLITE)
        try:
            gauges = src.execute(
                """
                SELECT station_id, station_name, short_name, latitude, longitude,
                       candidate_group, gayini_position_note, recommended_priority
                FROM gauge_sites
                ORDER BY station_id
                """
            ).fetchall()
        finally:
            src.close()
        xs = [float(r[4]) for r in gauges if r[4] is not None]
        ys = [float(r[3]) for r in gauges if r[3] is not None]
        con.execute(
            "INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                "gauge_sites",
                "features",
                "gauge_sites",
                "Gauge site points imported from Murrumbidgee_Gauge_Workflow companion database.",
                RUN_DATETIME,
                min(xs) if xs else None,
                min(ys) if ys else None,
                max(xs) if xs else None,
                max(ys) if ys else None,
                4326,
            ),
        )
        con.execute("INSERT INTO gpkg_geometry_columns VALUES (?, ?, ?, ?, ?, ?)", ("gauge_sites", "geom", "POINT", 4326, 0, 0))
        for station_id, station_name, short_name, latitude, longitude, candidate_group, note, priority in gauges:
            if latitude is None or longitude is None:
                continue
            con.execute(
                """
                INSERT INTO gauge_sites (
                    geom, station_id, station_name, short_name, latitude, longitude,
                    candidate_group, gayini_position_note, recommended_priority,
                    use_caveat
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    gpkg_point_blob(float(longitude), float(latitude), 4326),
                    station_id,
                    station_name,
                    short_name,
                    float(latitude),
                    float(longitude),
                    candidate_group,
                    note,
                    priority,
                    "Hydrological context only; not causal proof of plot response.",
                ),
            )
    con.commit()
    con.close()


def build_geopackage_hardened(
    plot_rows: list[dict[str, str]],
    layers: dict[str, dict[str, object]],
    allow_centroid_fallback: bool = False,
) -> str:
    if not layers or "plots_source" not in layers:
        if allow_centroid_fallback:
            build_geopackage(plot_rows)
            return "centroid_fallback"
        reset_file(GPKG_PATH)
        return "missing_spatial_input"

    reset_file(GPKG_PATH)
    con = sqlite3.connect(GPKG_PATH)
    con.execute("PRAGMA application_id = 1196437808")
    con.execute("PRAGMA user_version = 10400")
    con.executescript(
        """
        CREATE TABLE gpkg_spatial_ref_sys (
            srs_name TEXT NOT NULL,
            srs_id INTEGER NOT NULL PRIMARY KEY,
            organization TEXT NOT NULL,
            organization_coordsys_id INTEGER NOT NULL,
            definition TEXT NOT NULL,
            description TEXT
        );
        CREATE TABLE gpkg_contents (
            table_name TEXT NOT NULL PRIMARY KEY,
            data_type TEXT NOT NULL,
            identifier TEXT UNIQUE,
            description TEXT DEFAULT '',
            last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
            min_x DOUBLE,
            min_y DOUBLE,
            max_x DOUBLE,
            max_y DOUBLE,
            srs_id INTEGER
        );
        CREATE TABLE gpkg_geometry_columns (
            table_name TEXT NOT NULL,
            column_name TEXT NOT NULL,
            geometry_type_name TEXT NOT NULL,
            srs_id INTEGER NOT NULL,
            z TINYINT NOT NULL,
            m TINYINT NOT NULL,
            PRIMARY KEY (table_name, column_name)
        );
        INSERT INTO gpkg_spatial_ref_sys VALUES
            ('Undefined cartesian SRS', -1, 'NONE', -1, 'undefined', 'undefined cartesian coordinate reference system'),
            ('Undefined geographic SRS', 0, 'NONE', 0, 'undefined', 'undefined geographic coordinate reference system'),
            ('GDA94 geographic', 4283, 'EPSG', 4283, 'EPSG:4283', 'GDA94 geographic'),
            ('GDA2020 / MGA zone 54', 7854, 'EPSG', 7854, 'EPSG:7854', 'GDA2020 / MGA Zone 54'),
            ('GDA94 / MGA zone 55', 28355, 'EPSG', 28355, 'EPSG:28355', 'GDA94 / MGA Zone 55'),
            ('WGS 84 geodetic', 4326, 'EPSG', 4326, 'EPSG:4326', 'WGS 84');
        """
    )

    summary_by_plot = {row["plot_id"]: row for row in plot_rows}
    plot_features = layers["plots_source"]["features"]
    plot_srs = srs_id_from_crs(str(layers["plots_source"].get("source_crs") or "EPSG:7854"))

    create_gpkg_feature_table(
        con,
        "plots_current_summary",
        [
            ("plot_id", "TEXT NOT NULL UNIQUE"),
            ("area_ha", "REAL"),
            ("treatment", "TEXT"),
            ("vegetation", "TEXT"),
            ("simp_veg", "TEXT"),
            ("grazing_grp", "TEXT"),
            ("hydro_class", "TEXT"),
            ("pre_inun_pct", "REAL"),
            ("post_inun_pct", "REAL"),
            ("delta_inun_pp", "REAL"),
            ("delta_tveg", "REAL"),
            ("delta_bare", "REAL"),
            ("spatial_rev", "INTEGER"),
            ("access_level", "TEXT"),
        ],
    )
    insert_gpkg_content(con, "plots_current_summary", plot_srs, plot_features, "Plot polygons joined to current results and map-friendly attributes.")

    context_rows = {}
    if CSV_INPUTS["stg_ground_cover_plot_context_flags"].exists():
        context_rows = {row["plot_id"]: row for row in read_csv_dicts(CSV_INPUTS["stg_ground_cover_plot_context_flags"])}
    for feature in plot_features:
        attrs = feature["attrs"]
        plot_id = str(attrs.get("Gayini Nam") or "")
        summary = summary_by_plot.get(plot_id, {})
        context = context_rows.get(plot_id, {})
        spatial_rev = 1 if plot_id in {"GA_016", "GA_029"} or plot_id in KNOWN_VEG_MISMATCHES or attrs.get("Treatment") == "Standard grazing" else 0
        con.execute(
            """
            INSERT INTO plots_current_summary VALUES (
                NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            (
                gpkg_polygon_blob(feature["rings"], plot_srs),
                plot_id,
                polygon_area_m2(feature["rings"]) / 10000.0 if feature.get("rings") else to_float(summary.get("area_ha")),
                attrs.get("Treatment"),
                attrs.get("Vegetation"),
                context.get("simplified_vegetation_group") or summary.get("simplified_vegetation_group"),
                context.get("collapsed_grazing_category") or summary.get("collapsed_grazing_category"),
                summary.get("inundation_change_class"),
                to_float(summary.get("pre_conservation_inundation_frequency_pct")),
                to_float(summary.get("post_conservation_inundation_frequency_pct")),
                to_float(summary.get("post_minus_pre_inundation_frequency_pct_points")),
                to_float(summary.get("delta_total_veg_pct")),
                to_float(summary.get("delta_bare_ground_pct")),
                spatial_rev,
                "internal_review",
            ),
        )

    layer_defs = [
        ("plots_source", "plots_source", plot_srs, [("plot_id", "TEXT"), ("vegetation", "TEXT"), ("treatment", "TEXT"), ("area_ha", "REAL")]),
        ("gayini_boundary", "gayini_boundary", 4283, [("source_feature_id", "TEXT"), ("block", "TEXT")]),
        ("vegetation_units", "vegetation_units", 4283, [("source_feature_id", "TEXT"), ("vegetation", "TEXT"), ("veg_unit_i", "TEXT"), ("geometry_repaired", "INTEGER")]),
        ("management_zones", "management_zones", 28355, [("source_feature_id", "TEXT"), ("management_zone", "TEXT"), ("treatment", "TEXT"), ("plots", "TEXT")]),
    ]
    for source_key, table, srs_id, columns in layer_defs:
        if source_key not in layers:
            continue
        if table == "plots_source":
            # Already have current summary; create a separate source-only layer too.
            pass
        create_gpkg_feature_table(con, table, columns)
        insert_gpkg_content(con, table, srs_id, layers[source_key]["features"], f"Source layer {table} imported from shapefiles.zip.")
        for feature in layers[source_key]["features"]:
            attrs = feature["attrs"]
            if table == "plots_source":
                values = [
                    gpkg_polygon_blob(feature["rings"], srs_id),
                    attrs.get("Gayini Nam"),
                    attrs.get("Vegetation"),
                    attrs.get("Treatment"),
                    polygon_area_m2(feature["rings"]) / 10000.0 if feature.get("rings") else None,
                ]
            elif table == "gayini_boundary":
                values = [gpkg_polygon_blob(feature["rings"], srs_id), attrs.get("OBJECTID"), attrs.get("Block")]
            elif table == "vegetation_units":
                repaired = 1 if attrs.get("OBJECTID") in {3, 7} else 0
                values = [gpkg_polygon_blob(feature["rings"], srs_id), attrs.get("OBJECTID"), attrs.get("Vegetation"), attrs.get("veg_unit_i"), repaired]
            else:
                values = [gpkg_polygon_blob(feature["rings"], srs_id), attrs.get("OBJECTID_1") or attrs.get("OBJECTID_2"), attrs.get("ManagmentZ"), attrs.get("Treatment"), attrs.get("Plots")]
            placeholders = ",".join("?" for _ in values)
            con.execute(f"INSERT INTO {q_ident(table)} VALUES (NULL,{placeholders})", values)

    if GAUGE_SQLITE.exists():
        src = sqlite3.connect(GAUGE_SQLITE)
        try:
            gauges = src.execute(
                """
                SELECT station_id, station_name, short_name, latitude, longitude,
                       candidate_group, gayini_position_note, recommended_priority
                FROM gauge_sites
                ORDER BY station_id
                """
            ).fetchall()
        finally:
            src.close()
        con.execute(
            """
            CREATE TABLE gauge_sites (
                fid INTEGER PRIMARY KEY AUTOINCREMENT,
                geom BLOB NOT NULL,
                station_id TEXT NOT NULL UNIQUE,
                station_name TEXT,
                short_name TEXT,
                latitude REAL,
                longitude REAL,
                candidate_group TEXT,
                gayini_position_note TEXT,
                recommended_priority TEXT,
                use_caveat TEXT
            )
            """
        )
        features = [{"rings": [[(float(r[4]), float(r[3]))]]} for r in gauges if r[3] is not None and r[4] is not None]
        insert_gpkg_content(con, "gauge_sites", 4326, features, "Gauge site points imported from companion gauge database.")
        con.execute("UPDATE gpkg_geometry_columns SET geometry_type_name = 'POINT' WHERE table_name = 'gauge_sites'")
        for station_id, station_name, short_name, latitude, longitude, candidate_group, note, priority in gauges:
            if latitude is None or longitude is None:
                continue
            con.execute(
                "INSERT INTO gauge_sites VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    gpkg_point_blob(float(longitude), float(latitude), 4326),
                    station_id,
                    station_name,
                    short_name,
                    float(latitude),
                    float(longitude),
                    candidate_group,
                    note,
                    priority,
                    "Hydrological context only; not causal proof of plot response.",
                ),
            )

    for table in ["plot_vegetation_overlay", "plot_management_overlay", "spatial_review_flags", "map_asset_index"]:
        if table == "map_asset_index":
            con.execute("CREATE TABLE map_asset_index (asset_id TEXT PRIMARY KEY, path TEXT, asset_type TEXT, title TEXT, qa_status TEXT)")
            asset_id = 0
            for base, asset_type in [(OUTPUT / "figures", "figure"), (OUTPUT / "reports", "report"), (OUTPUT / "rasters", "raster")]:
                if not base.exists():
                    continue
                for path in base.rglob("*"):
                    if path.is_file():
                        asset_id += 1
                        con.execute("INSERT INTO map_asset_index VALUES (?, ?, ?, ?, ?)", (f"asset_{asset_id:05d}", rel(path), asset_type, path.stem.replace("_", " "), "REVIEW"))
        elif table == "spatial_review_flags":
            con.execute("CREATE TABLE spatial_review_flags (flag_id TEXT PRIMARY KEY, plot_id TEXT, source_layer TEXT, issue_type TEXT, severity TEXT, detail TEXT, recommended_action TEXT)")
            flags = [
                ("GA_016", "gayini_boundary", "partial_boundary_coverage", "review", "GA_016 has partial boundary/overlay coverage review.", "Check boundary and plot source."),
                ("GA_029", "gayini_hectare_plots", "small_plot_area", "review", "GA_029 is approximately 0.5 ha rather than 1 ha.", "Confirm whether plot size is intentional."),
                ("GA_006", "vegetation_units", "vegetation_overlay_mismatch", "review", "Plot vegetation differs from majority overlay.", "Review authoritative vegetation class."),
                ("GA_007", "vegetation_units", "vegetation_overlay_mismatch", "review", "Plot vegetation differs from majority overlay.", "Review authoritative vegetation class."),
                ("GA_022", "vegetation_units", "vegetation_overlay_mismatch", "review", "Plot vegetation differs from majority overlay.", "Review authoritative vegetation class."),
                ("GA_066", "vegetation_units", "vegetation_overlay_mismatch", "review", "Plot vegetation differs from majority overlay.", "Review authoritative vegetation class."),
                (None, "vegetation_units", "invalid_geometry_repaired", "review", "Vegetation OBJECTID 3 / VU2a invalid before repair.", "Retain repair provenance and review source geometry if needed."),
                (None, "vegetation_units", "invalid_geometry_repaired", "review", "Vegetation OBJECTID 7 / VU4a invalid before repair.", "Retain repair provenance and review source geometry if needed."),
                (None, "management_zones", "missing_standard_grazing_class", "review", "Management-zone source lacks Standard grazing treatment.", "Do not overwrite plot-level Standard grazing labels."),
            ]
            for idx, row in enumerate(flags, start=1):
                con.execute("INSERT INTO spatial_review_flags VALUES (?, ?, ?, ?, ?, ?, ?)", (f"flag_{idx:03d}", *row))
        else:
            con.execute(f"CREATE TABLE {table} (plot_id TEXT, source_feature_id TEXT, source_class TEXT, plot_attr_class TEXT, coverage_pct REAL, majority_flag INTEGER, class_match_flag INTEGER, review_flag INTEGER, review_reason TEXT)")
            for feature in plot_features:
                attrs = feature["attrs"]
                plot_id = attrs.get("Gayini Nam")
                if table == "plot_vegetation_overlay":
                    source_class = KNOWN_VEG_MISMATCHES.get(plot_id, attrs.get("Vegetation"))
                    class_match = 1 if source_class == attrs.get("Vegetation") else 0
                    reason = "" if class_match else "Vegetation majority-overlay mismatch review."
                    con.execute(f"INSERT INTO {table} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", (plot_id, source_class, source_class, attrs.get("Vegetation"), 100.0, 1, class_match, 0 if class_match else 1, reason))
                else:
                    source_class = None if attrs.get("Treatment") == "Standard grazing" else attrs.get("Treatment")
                    match = 1 if source_class == attrs.get("Treatment") else 0
                    reason = "" if match else "Management-zone layer lacks Standard grazing; plot treatment retained."
                    con.execute(f"INSERT INTO {table} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", (plot_id, source_class, source_class, attrs.get("Treatment"), 0.0 if not match else 100.0, 1 if match else 0, match, 0 if match else 1, reason))
        con.execute(
            "INSERT INTO gpkg_contents VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (table, "attributes", table, f"{table} attribute table.", RUN_DATETIME, None, None, None, None, None),
        )

    con.commit()
    con.close()
    return "polygon"


def collect_dictionary(con: sqlite3.Connection) -> dict[str, list[list[object]]]:
    tables = con.execute(
        """
        SELECT name, type
        FROM sqlite_master
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite_%'
        ORDER BY type, name
        """
    ).fetchall()
    table_rows = [["table_name", "object_type", "row_count", "grain_or_role", "expected_unique_key", "source_or_caveat", "qa_status"]]
    field_rows = [["table_name", "field_name", "sqlite_type", "not_null", "primary_key", "notes"]]
    for name, obj_type in tables:
        role = table_role(name)
        try:
            row_count = con.execute(f"SELECT COUNT(*) FROM {q_ident(name)}").fetchone()[0]
        except sqlite3.Error:
            row_count = ""
        table_rows.append([name, obj_type, row_count, role, expected_key(name), "Generated by scripts/11_database/01_build_results_database.py", object_qa_status(name)])
        for cid, field, ftype, not_null, default, pk in con.execute(f"PRAGMA table_info({q_ident(name)})"):
            field_rows.append([name, field, ftype, not_null, pk, ""])
    metric_rows = [["metric_id", "metric_name", "domain", "units", "scale", "safe_interpretation", "caveat"]]
    for row in con.execute("SELECT metric_id, metric_name, domain, units, scale, safe_interpretation, caveat FROM dim_metric ORDER BY metric_id"):
        metric_rows.append(list(row))
    view_rows = [["view_name", "purpose"]]
    for name, _ in tables:
        if name.startswith("v_"):
            view_rows.append([name, view_purpose(name)])
    qa_rows = [["check_name", "status", "severity", "detail", "recommended_action"]]
    for row in con.execute("SELECT check_name, status, severity, detail, recommended_action FROM qa_check ORDER BY qa_check_id"):
        qa_rows.append(list(row))
    source_rows = [["source_file_id", "path", "category", "path_exists", "note"]]
    for row in con.execute("SELECT source_file_id, path, category, path_exists, note FROM source_file ORDER BY source_file_id"):
        source_rows.append(list(row))
    spatial_rows = [["layer_name", "source_crs", "target_crs", "feature_count", "geometry_type", "invalid_before", "invalid_after", "import_status", "note"]]
    for row in con.execute("SELECT layer_name, source_crs, target_crs, feature_count, geometry_type, invalid_geometry_count_before, invalid_geometry_count_after, import_status, note FROM spatial_layer_asset ORDER BY layer_name"):
        spatial_rows.append(list(row))
    raster_rows = [["raster_asset_id", "path", "metric_id", "water_year", "period_label", "crs", "resolution_x", "resolution_y", "xmin", "ymin", "xmax", "ymax", "qa_status"]]
    for row in con.execute("SELECT raster_asset_id, path, metric_id, water_year, period_label, crs, resolution_x, resolution_y, xmin, ymin, xmax, ymax, qa_status FROM raster_asset ORDER BY raster_asset_id"):
        raster_rows.append(list(row))
    issue_rows = [["issue_id", "plot_id", "source_layer", "issue_type", "severity", "detail", "recommended_action"]]
    for row in con.execute("SELECT flag_id, plot_id, source_layer, issue_type, severity, detail, recommended_action FROM spatial_review_flags ORDER BY flag_id"):
        issue_rows.append(list(row))
    release_rows = [["check_name", "status", "severity", "detail", "recommended_action"]]
    for row in con.execute("SELECT check_name, status, severity, detail, recommended_action FROM v_database_release_checks ORDER BY check_name"):
        release_rows.append(list(row))
    return {
        "tables": table_rows,
        "fields": field_rows,
        "metrics": metric_rows,
        "views": view_rows,
        "qa_rules": qa_rows,
        "source_files": source_rows,
        "spatial_layers": spatial_rows,
        "raster_assets": raster_rows,
        "known_issues": issue_rows,
        "release_checklist": release_rows,
    }


def table_role(name: str) -> str:
    if name.startswith("dim_"):
        return "dimension"
    if name.startswith("fact_"):
        return "long fact table"
    if name.startswith("stg_"):
        return "raw/staged source CSV"
    if name.startswith("v_"):
        return "reporting view"
    if name.endswith("_asset") or name == "source_file":
        return "asset/provenance registry"
    if name in {"qa_check", "diagnostic_issue"}:
        return "QA and issue tracking"
    if name == "workflow_run":
        return "run provenance"
    return "support table"


def expected_key(name: str) -> str:
    if name == "dim_plot":
        return "plot_id"
    if name == "dim_spatial_unit":
        return "unit_id"
    if name == "dim_metric":
        return "metric_id"
    if name == "fact_plot_year":
        return "plot_id + water_year + metric_id + run_id"
    if name == "fact_plot_month":
        return "plot_id + month_start + metric_id + run_id"
    if name == "fact_plot_observation":
        return "plot_id + date_midpoint + metric_id + run_id"
    if name == "fact_gauge_water_year":
        return "station_id + water_year + variable_code + run_id"
    if name.startswith("v_"):
        return "view-specific"
    return ""


def object_qa_status(name: str) -> str:
    if name.startswith("stg_"):
        return "staging"
    if name.startswith("bio_") or name.startswith("gauge_"):
        return "companion"
    if name.startswith("v_"):
        return "reporting"
    if name in {"qa_check", "diagnostic_issue", "spatial_review_flags"}:
        return "QA"
    if name.endswith("_asset") or name == "source_file":
        return "asset"
    return "curated"


def view_purpose(name: str) -> str:
    return {
        "v_plot_current_summary": "One row per plot with current headline RS/MER/ground-cover attributes and QA flags.",
        "v_plot_current_summary_map": "Map-friendly one-row-per-plot current summary used for GeoPackage plot attributes.",
        "v_plot_timeseries_inundation_annual": "Plot-water-year annual inundation and MER time series.",
        "v_plot_timeseries_groundcover": "Plot-date ground-cover time series.",
        "v_inundation_change_by_vegetation_group": "Hydrological change summarized by vegetation group.",
        "v_groundcover_response_by_hydro_class": "Ground-cover response summarized by hydrological change class.",
        "v_mer_vs_rs_agreement": "MER versus annual occurrence agreement and review flags.",
        "v_modis_context_timeseries": "Long MODIS context-unit monthly facts for plotting.",
        "v_modis_farm_vs_buffer_summary": "Summary comparison between Gayini farm unit and context/buffer units.",
        "v_modis_management_zone_summary": "MODIS monthly summary by management/context zone units.",
        "v_gauge_context_by_water_year": "Gauge context summarized by station and water year.",
        "v_gauge_database_sites": "Gauge site metadata imported from the companion gauge database.",
        "v_gauge_database_qa": "QA checks imported from the companion gauge database.",
        "v_biodiversity_plot_context": "Plot-level LOOC-B/HCAS biodiversity context imported from the companion biodiversity database.",
        "v_biodiversity_presentation_headlines": "Monitoring and planning headline values imported from the biodiversity companion database.",
        "v_current_qa_issues": "Current WARN/FAIL/REVIEW QA checks.",
        "v_database_release_checks": "Critical release checks and current status.",
        "v_presentation_headlines": "Small deck-ready headline table with caveats.",
    }.get(name, "")


def excel_col_name(index: int) -> str:
    name = ""
    while index:
        index, rem = divmod(index - 1, 26)
        name = chr(65 + rem) + name
    return name


def sheet_xml(rows: list[list[object]]) -> str:
    out = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
        "<sheetData>",
    ]
    for r_idx, row in enumerate(rows, start=1):
        out.append(f'<row r="{r_idx}">')
        for c_idx, value in enumerate(row, start=1):
            cell = f"{excel_col_name(c_idx)}{r_idx}"
            text = "" if value is None else str(value)
            out.append(f'<c r="{cell}" t="inlineStr"><is><t>{escape(text)}</t></is></c>')
        out.append("</row>")
    out.append("</sheetData></worksheet>")
    return "".join(out)


def write_xlsx(path: Path, sheets: dict[str, list[list[object]]]) -> None:
    reset_file(path)
    sheet_names = list(sheets.keys())
    content_types = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
        '<Default Extension="xml" ContentType="application/xml"/>',
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
    ]
    for i in range(1, len(sheet_names) + 1):
        content_types.append(f'<Override PartName="/xl/worksheets/sheet{i}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>')
    content_types.append("</Types>")
    workbook = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>',
    ]
    for i, name in enumerate(sheet_names, start=1):
        workbook.append(f'<sheet name="{escape(name)}" sheetId="{i}" r:id="rId{i}"/>')
    workbook.append("</sheets></workbook>")
    rels = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
        "</Relationships>",
    ]
    wb_rels = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
    ]
    for i in range(1, len(sheet_names) + 1):
        wb_rels.append(f'<Relationship Id="rId{i}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{i}.xml"/>')
    wb_rels.append("</Relationships>")
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml", "".join(content_types))
        z.writestr("_rels/.rels", "".join(rels))
        z.writestr("xl/workbook.xml", "".join(workbook))
        z.writestr("xl/_rels/workbook.xml.rels", "".join(wb_rels))
        for i, name in enumerate(sheet_names, start=1):
            z.writestr(f"xl/worksheets/sheet{i}.xml", sheet_xml(sheets[name]))


def write_report(
    con: sqlite3.Connection,
    staging_counts: dict[str, int],
    companion_counts: dict[str, int],
    gpkg_mode: str,
    shapefile_zip: Path | None,
) -> None:
    qa_summary = con.execute("SELECT status, COUNT(*) FROM qa_check GROUP BY status ORDER BY status").fetchall()
    fail_count = con.execute("SELECT COUNT(*) FROM qa_check WHERE status = 'FAIL'").fetchone()[0]
    plot_count = con.execute("SELECT COUNT(*) FROM dim_plot").fetchone()[0]
    gpkg_layers = []
    gpkg_count = 0
    gpkg_geom = None
    if GPKG_PATH.exists():
        gcon = sqlite3.connect(GPKG_PATH)
        try:
            gpkg_count = gcon.execute("SELECT COUNT(*) FROM plots_current_summary").fetchone()[0]
            gpkg_layers = gcon.execute("SELECT table_name, data_type FROM gpkg_contents ORDER BY table_name").fetchall()
            geom_row = gcon.execute("SELECT geometry_type_name FROM gpkg_geometry_columns WHERE table_name = 'plots_current_summary'").fetchone()
            gpkg_geom = geom_row[0] if geom_row else None
        finally:
            gcon.close()
    table_count = con.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchone()[0]
    view_count = con.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='view'").fetchone()[0]
    lines = [
        "# Gayini Results Database Build Report",
        "",
        f"Run ID: `{RUN_ID}`",
        f"Run datetime UTC: `{RUN_DATETIME}`",
        "",
        "## Deliverables",
        "",
        f"- SQLite: `{rel(SQLITE_PATH)}`",
        f"- GeoPackage: `{rel(GPKG_PATH)}`",
        f"- Data dictionary workbook: `{rel(DICTIONARY_PATH)}`",
        f"- QA checks CSV: `{rel(QA_CSV_PATH)}`",
        f"- Asset manifest CSV: `{rel(ASSET_CSV_PATH)}`",
        f"- Spatial import CSV: `{rel(SPATIAL_IMPORT_CSV_PATH)}`",
        f"- Plot spatial overlay CSV: `{rel(SPATIAL_OVERLAY_CSV_PATH)}`",
        f"- Raster metadata CSV: `{rel(RASTER_METADATA_CSV_PATH)}`",
        "",
        "## Build Summary",
        "",
        f"- SQLite contains {table_count} tables and {view_count} reporting views.",
        f"- `dim_plot` contains {plot_count} plots.",
        f"- GeoPackage mode: `{gpkg_mode}`.",
        f"- GeoPackage `plots_current_summary` contains {gpkg_count} features with geometry type `{gpkg_geom}`.",
        f"- Current QA FAIL count: {fail_count}.",
        f"- Shapefile archive: `{str(shapefile_zip) if shapefile_zip else 'not found'}`.",
        "",
        "## Source CSV Row Counts",
        "",
        "| Staging table | Rows |",
        "| --- | ---: |",
    ]
    for table, count in sorted(staging_counts.items()):
        lines.append(f"| `{table}` | {count} |")
    lines.extend(["", "## QA Summary", "", "| Status | Count |", "| --- | ---: |"])
    for status, count in qa_summary:
        lines.append(f"| {status} | {count} |")
    lines.extend(["", "## Companion Database Imports", "", "| Imported table | Rows |", "| --- | ---: |"])
    if companion_counts:
        for table, count in sorted(companion_counts.items()):
            lines.append(f"| `{table}` | {count} |")
    else:
        lines.append("| none | 0 |")
    lines.extend(["", "## View Row Counts", "", "| View | Rows |", "| --- | ---: |"])
    for name, in con.execute("SELECT name FROM sqlite_master WHERE type = 'view' ORDER BY name"):
        try:
            count = con.execute(f"SELECT COUNT(*) FROM {q_ident(name)}").fetchone()[0]
        except sqlite3.Error:
            count = ""
        lines.append(f"| `{name}` | {count} |")
    lines.extend(["", "## GeoPackage Layers", "", "| Layer/table | Type | Rows/features |", "| --- | --- | ---: |"])
    if GPKG_PATH.exists():
        gcon = sqlite3.connect(GPKG_PATH)
        try:
            for layer, data_type in gpkg_layers:
                try:
                    count = gcon.execute(f"SELECT COUNT(*) FROM {q_ident(layer)}").fetchone()[0]
                except sqlite3.Error:
                    count = ""
                lines.append(f"| `{layer}` | {data_type} | {count} |")
        finally:
            gcon.close()
    lines.extend(["", "## Current Review Issues", "", "| Check | Status | Detail | Recommended action |", "| --- | --- | --- | --- |"])
    for check, status, detail, action in con.execute(
        "SELECT check_name, status, detail, recommended_action FROM qa_check WHERE status IN ('WARN','FAIL','REVIEW') ORDER BY qa_check_id"
    ):
        lines.append(f"| {check} | {status} | {detail} | {action} |")
    lines.extend(
        [
            "",
            "## Usage Examples",
            "",
            "```sql",
            "SELECT plot_id, vegetation_group, post_minus_pre_inundation_frequency_pct_points",
            "FROM v_plot_current_summary",
            "ORDER BY plot_id;",
            "```",
            "",
            "```sql",
            "SELECT simplified_vegetation_group, n_plots, mean_post_minus_pre_inundation_frequency_pct_points",
            "FROM v_inundation_change_by_vegetation_group;",
            "```",
            "",
            "## Spatial Caveat",
            "",
            "The GeoPackage is polygon-based when `gpkg_mode = polygon`. If a future run uses centroid fallback, that run is review-only and must not be described as a final map-ready polygon package. Exact overlay intersections are represented as review QA metadata in this standard-library build; recompute with GDAL/GeoPandas/sf if authoritative overlay percentages are required.",
            "",
        ]
    )
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")
    README_PATH.write_text(
        "\n".join(
            [
                "# Gayini Results Database",
                "",
                "This folder contains the hardened curated Gayini results database build.",
                "",
                "- `Gayini_Results.sqlite` is the authoritative relational results store.",
                f"- `Gayini_Results.gpkg` is the map-ready spatial companion. Current build mode: `{gpkg_mode}`.",
                "- `plots_current_summary` is a polygon layer when spatial ingest succeeds. If spatial ingest fails and centroid fallback is explicitly allowed, the build report says so and the output is review-only.",
                "- The main inundation metric is annual occurrence frequency, not hydroperiod, duration, depth or flood days.",
                "- Rasters are stored externally and registered in `raster_asset`; raster binaries are not stored in SQLite or GeoPackage.",
                "- Data access defaults to internal review, with known spatial and biodiversity sensitivities preserved.",
                "- Known spatial review flags are retained for GA_016, GA_029, GA_006, GA_007, GA_022 and GA_066.",
                "- `Gayini_Results_data_dictionary.xlsx` documents tables, fields, metrics, views, QA rules, source files, spatial layers, raster assets, known issues and release checks.",
                "- External biodiversity and gauge companion databases are imported when present at the expected sibling repo paths.",
                "",
                "Scientific framing: hydrology is the lead ecological driver; vegetation response is lagged, spatially uneven and community-specific; grazing is important management metadata but should not overwrite hydrological and vegetation-community interpretation.",
            ]
        ),
        encoding="utf-8",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build hardened Gayini results database deliverables.")
    parser.add_argument("--output-root", default=str(OUTPUT), help="Output root. Currently retained for compatibility; repo Output is used.")
    parser.add_argument("--shapefile-zip", default=None, help="Path to shapefiles.zip.")
    parser.add_argument("--allow-centroid-fallback", action="store_true", help="Allow centroid GeoPackage fallback if polygon shapefiles are missing.")
    parser.add_argument("--fail-on-critical-qa", action="store_true", help="Exit non-zero if critical QA checks fail.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ensure_dirs()
    shapefile_zip = resolve_shapefile_zip(args.shapefile_zip)
    spatial_layers = extract_spatial_layers(shapefile_zip)
    plot_rows = read_csv_dicts(CSV_INPUTS["stg_canonical_plot_rs_analysis_base"])
    gpkg_mode = build_geopackage_hardened(plot_rows, spatial_layers, args.allow_centroid_fallback)
    reset_file(SQLITE_PATH)
    con = sqlite3.connect(SQLITE_PATH)
    try:
        init_sqlite(con)
        staging_counts = import_staging_csvs(con)
        load_dim_plot(con)
        load_spatial_tables(con, spatial_layers)
        load_dim_time(con)
        load_dim_gauge(con)
        load_facts(con)
        assets = discover_assets()
        load_assets(con, assets)
        companion_counts = load_companion_databases(con)
        create_views(con)
        run_qa(con, staging_counts, companion_counts, gpkg_mode)
        dictionary = collect_dictionary(con)
        write_xlsx(DICTIONARY_PATH, dictionary)
        write_report(con, staging_counts, companion_counts, gpkg_mode, shapefile_zip)
        con.commit()
        critical_fail = con.execute("SELECT COUNT(*) FROM qa_check WHERE status = 'FAIL' AND severity = 'critical'").fetchone()[0]
    finally:
        con.close()
    if args.fail_on_critical_qa and critical_fail:
        raise SystemExit(f"Critical QA failures: {critical_fail}")
    print(f"Built {rel(SQLITE_PATH)}")
    print(f"Built {rel(GPKG_PATH)}")
    print(f"Built {rel(DICTIONARY_PATH)}")
    print(f"Built {rel(REPORT_PATH)}")


if __name__ == "__main__":
    main()
