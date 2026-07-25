#!/usr/bin/env python3
"""T1 · Gate A0 — register the EPSG:8058 management-zone layer (additive).

WHY THIS EXISTS (not the builder): the DB builder is destructive (unlink + full
rebuild) and would wipe the manually-registered Task H rows. This registrar does
one narrow, idempotent, additive thing: it adds a single spatial_layer_asset row
for management_zones_epsg8058.gpkg so that every later T1 gate can resolve the
zone layer path from the DB *and* satisfy "the input must be EPSG:8058". Before
this row, the only registered zone layer was management_zones at EPSG:28355 behind
an absolute Windows path into shapefiles.zip.

Spec: docs/T1_zone_stratum_census_join.md v3, Gate A0.

SCHEMA NOTE (flagged in the Gate A0 report): spatial_layer_asset has NO
checksum_sha256 and NO path_exists column. The spec names both. Altering this
table is NOT sanctioned (only figure_asset ADD COLUMN is, per Gate B1), so the
SHA-256 (first-50-MB builder convention) and the path_exists=1 confirmation are
recorded in the free-text `note` column instead of new columns.

Usage:
  python scripts/11_database/register_T1_gateA0_zone_layer.py check     # no DB write (default)
  python scripts/11_database/register_T1_gateA0_zone_layer.py execute   # performs the write
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
GPKG = ROOT / "Output" / "spatial_8058" / "management_zones_epsg8058.gpkg"
LAYER = "management_zones_epsg8058"
ASSET_ID = "spatial_006"
LAYER_NAME = "management_zones_8058"
RUN_ID = "T1_gateA0"
RUN_DATETIME = "2026-07-25T00:00:00+00:00"  # fixed for idempotence


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - identical to the builder's method."""
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


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def read_gpkg_facts(path: Path) -> dict:
    """CRS, feature count and geometry type read from the gpkg header itself."""
    con = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        srs_id = con.execute(
            "SELECT srs_id FROM gpkg_contents WHERE table_name=? AND data_type='features'",
            (LAYER,)).fetchone()[0]
        org, org_id = con.execute(
            "SELECT organization, organization_coordsys_id FROM gpkg_spatial_ref_sys "
            "WHERE srs_id=?", (srs_id,)).fetchone()
        geom_type = con.execute(
            "SELECT geometry_type_name FROM gpkg_geometry_columns WHERE table_name=?",
            (LAYER,)).fetchone()[0]
        n = con.execute(f"SELECT COUNT(*) FROM '{LAYER}'").fetchone()[0]
    finally:
        con.close()
    return {"srs_id": srs_id, "epsg": f"{org}:{org_id}", "geom_type": geom_type,
            "feature_count": n}


def build_row() -> dict:
    if not GPKG.is_file():
        raise SystemExit(f"ABORT: {rel(GPKG)} not found on disk. STOP — do not reproject.")
    facts = read_gpkg_facts(GPKG)
    if facts["epsg"] != "EPSG:8058":
        raise SystemExit(
            f"ABORT: {rel(GPKG)} header CRS is {facts['epsg']}, not EPSG:8058. "
            "STOP and report — do not reproject.")
    if facts["feature_count"] != 64:
        raise SystemExit(
            f"ABORT: {rel(GPKG)} has {facts['feature_count']} features, expected 64.")
    checksum = sha256_first50(GPKG)
    note = (
        "T1 Gate A0 additive registration of the EPSG:8058 zone layer "
        "(spec docs/T1_zone_stratum_census_join.md v3). CRS read from gpkg header = "
        "EPSG:8058; feature_count=64; path_exists=1. "
        f"SHA-256 (first-50-MB builder convention) = {checksum}. "
        "SCHEMA NOTE: spatial_layer_asset has no checksum_sha256/path_exists columns; "
        "both are recorded here rather than altering the table (only figure_asset "
        "ADD COLUMN is sanctioned, per Gate B1). The EPSG:28355 row spatial_004 is "
        "left untouched.")
    return dict(
        spatial_layer_asset_id=ASSET_ID,
        path=rel(GPKG),
        layer_name=LAYER_NAME,
        source_crs="EPSG:8058",
        target_crs="EPSG:8058",
        feature_count=64,
        geometry_type=facts["geom_type"],   # 'MULTIPOLYGON'
        invalid_geometry_count_before=None,
        invalid_geometry_count_after=None,
        geometry_validity="valid_or_not_checked",
        import_status="registered",
        note=note,
        run_id=RUN_ID,
    )


COLS = ["spatial_layer_asset_id", "path", "layer_name", "source_crs", "target_crs",
        "feature_count", "geometry_type", "invalid_geometry_count_before",
        "invalid_geometry_count_after", "geometry_validity", "import_status",
        "note", "run_id"]


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")
    row = build_row()

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        try:
            existing = con.execute(
                "SELECT COUNT(*) FROM spatial_layer_asset WHERE spatial_layer_asset_id=?",
                (ASSET_ID,)).fetchone()[0]
            clash = con.execute(
                "SELECT spatial_layer_asset_id FROM spatial_layer_asset "
                "WHERE spatial_layer_asset_id=? AND layer_name<>?",
                (ASSET_ID, LAYER_NAME)).fetchone()
            total = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
        finally:
            con.close()
        if clash:
            raise SystemExit(f"ABORT: {ASSET_ID} already used by a different layer {clash[0]!r}")
        print(f"[check] spatial_layer_asset currently has {total} rows.")
        print(f"[check] row {ASSET_ID} present already: {bool(existing)} "
              f"(INSERT OR REPLACE is idempotent either way).")
        print("[check] planned row:")
        for c in COLS:
            print(f"           {c:32s} = {row[c]!r}")
        print("[check] NO DB WRITE performed.")
        return

    # ---- execute -----------------------------------------------------------
    con = sqlite3.connect(DB.as_posix())
    try:
        before = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
        # provenance run row; is_current=0 so the one-current-run release check is untouched
        con.execute(
            "INSERT OR IGNORE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 0, 'REVIEW')",
            (RUN_ID, RUN_DATETIME,
             "scripts/11_database/register_T1_gateA0_zone_layer.py",
             '{"gate": "A0", "spec": "docs/T1_zone_stratum_census_join.md v3"}'))
        ph = ", ".join(["?"] * len(COLS))
        con.execute(
            f"INSERT OR REPLACE INTO spatial_layer_asset ({', '.join(COLS)}) VALUES ({ph})",
            tuple(row[c] for c in COLS))
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
        print(f"[execute] spatial_layer_asset rows: {before} -> {after}")
        print("[execute] registered row read back:")
        got = con.execute(
            "SELECT spatial_layer_asset_id, path, layer_name, source_crs, target_crs, "
            "feature_count, geometry_type, import_status, run_id "
            "FROM spatial_layer_asset WHERE spatial_layer_asset_id=?", (ASSET_ID,)).fetchone()
        print("          ", got)
        untouched = con.execute(
            "SELECT source_crs, path FROM spatial_layer_asset WHERE spatial_layer_asset_id='spatial_004'"
        ).fetchone()
        print(f"[execute] spatial_004 (28355 row) untouched: {untouched}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
