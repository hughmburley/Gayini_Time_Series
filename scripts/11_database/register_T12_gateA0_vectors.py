#!/usr/bin/env python3
"""T12 · Gate A0 — register the EPSG:8058 vector inputs (additive).

WHY THIS EXISTS (not the builder): the DB builder is destructive (unlink + full
rebuild) and would wipe the manually-registered rows. This registrar does one
narrow, idempotent, additive thing: it adds three spatial_layer_asset rows for the
standalone EPSG:8058 boundary / plots / vegetation-community layers, so that every
later T12 gate can resolve those paths from the DB and satisfy "the input must be
EPSG:8058". Before this, only the zone layer (spatial_006) was registered at 8058;
the boundary/plots/community 8058 layers were registered nowhere (the registered
spatial_001/002/003 rows are EPSG:7854/4283 in shapefiles.zip, and spatial_003 is
the 20-feature vegetation_units layer, not the 5-feature community layer).

Mirrors register_T1_gateA0_zone_layer.py exactly (same checksum convention, same
INSERT OR REPLACE idempotence, same is_current=0 workflow_run provenance row).
The three files already exist as standalone single-layer gpkgs in
Output/spatial_8058/ — siblings of spatial_006's management_zones_epsg8058.gpkg —
so no copy/reproject is performed. Facts (field_list, geometry_type, feature_count,
validity) come from Output/tables/T12_gateA0_vector_facts.csv, emitted by
scripts/13_dea_landcover/T12_gateA0_verify_vectors.R. CRS=8058 and feature count
are additionally re-asserted here from each gpkg header before any write.

Spec: docs/reference_update/T12_dea_landcover_l3_extraction.md v2, Gate A0.

Usage:
  python scripts/11_database/register_T12_gateA0_vectors.py check     # no DB write (default)
  python scripts/11_database/register_T12_gateA0_vectors.py execute   # performs the write
"""
from __future__ import annotations

import csv
import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
FACTS = ROOT / "Output" / "tables" / "T12_gateA0_vector_facts.csv"
RUN_ID = "T12_gateA0"
RUN_DATETIME = "2026-07-28T00:00:00+00:00"  # fixed for idempotence

# (asset_id, relative gpkg path, registry alias, expected feature count)
TARGETS = [
    ("spatial_007", "Output/spatial_8058/gayini_boundary_epsg8058.gpkg",
     "gayini_boundary_8058", 1),
    ("spatial_008", "Output/spatial_8058/gayini_hectare_plots_epsg8058.gpkg",
     "gayini_hectare_plots_8058", 66),
    ("spatial_009", "Output/spatial_8058/vegetation_communities_epsg8058.gpkg",
     "vegetation_communities_8058", 5),
]

COLS = ["spatial_layer_asset_id", "path", "layer_name", "source_crs", "target_crs",
        "feature_count", "geometry_type", "invalid_geometry_count_before",
        "invalid_geometry_count_after", "geometry_validity", "import_status",
        "note", "run_id", "checksum_sha256", "path_exists", "field_list"]


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - the one project convention."""
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


def read_gpkg_facts(path: Path) -> dict:
    """CRS, single feature-table name, geometry type and count from the gpkg header."""
    con = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        table_name, srs_id = con.execute(
            "SELECT table_name, srs_id FROM gpkg_contents WHERE data_type='features'"
        ).fetchone()
        org, org_id = con.execute(
            "SELECT organization, organization_coordsys_id FROM gpkg_spatial_ref_sys "
            "WHERE srs_id=?", (srs_id,)).fetchone()
        geom_type = con.execute(
            "SELECT geometry_type_name FROM gpkg_geometry_columns WHERE table_name=?",
            (table_name,)).fetchone()[0]
        n = con.execute(f"SELECT COUNT(*) FROM '{table_name}'").fetchone()[0]
    finally:
        con.close()
    return {"table_name": table_name, "epsg": f"{org}:{org_id}",
            "geom_type": geom_type, "feature_count": n}


def load_facts() -> dict:
    if not FACTS.is_file():
        raise SystemExit(
            f"ABORT: {FACTS.relative_to(ROOT).as_posix()} not found. Run "
            "scripts/13_dea_landcover/T12_gateA0_verify_vectors.R first.")
    out = {}
    with FACTS.open(newline="") as f:
        for r in csv.DictReader(f):
            out[r["spatial_layer_asset_id"]] = r
    return out


def build_rows() -> list[dict]:
    facts_csv = load_facts()
    rows = []
    for asset_id, relpath, alias, expect_n in TARGETS:
        gpkg = ROOT / relpath
        if not gpkg.is_file():
            raise SystemExit(f"ABORT: {relpath} not found on disk. STOP.")
        hdr = read_gpkg_facts(gpkg)
        if hdr["epsg"] != "EPSG:8058":
            raise SystemExit(
                f"ABORT: {relpath} header CRS is {hdr['epsg']}, not EPSG:8058. STOP.")
        if hdr["feature_count"] != expect_n:
            raise SystemExit(
                f"ABORT: {relpath} has {hdr['feature_count']} features, expected {expect_n}.")
        fc = facts_csv.get(asset_id)
        if fc is None:
            raise SystemExit(f"ABORT: no facts row for {asset_id} in {FACTS.name}.")
        inv_before = int(fc["invalid_before"])
        checksum = sha256_first50(gpkg)
        note = (
            f"T12 Gate A0 additive registration of the EPSG:8058 {alias} layer "
            "(spec docs/reference_update/T12_dea_landcover_l3_extraction.md v2). "
            "Standalone single-layer gpkg in Output/spatial_8058/, sibling of "
            "spatial_006; the equivalent 8058 layer is also present inside the "
            "unregistered Input/gayini_vectors_8058.gpkg. CRS read from gpkg header = "
            f"EPSG:8058; feature_count={expect_n}; invalid_geometries={inv_before}; "
            f"path_exists=1. SHA-256 (first-50-MB convention) = {checksum}. "
            "No existing row modified; the 4283/7854 shapefile rows are left untouched.")
        rows.append(dict(
            spatial_layer_asset_id=asset_id,
            path=relpath,
            layer_name=alias,
            source_crs="EPSG:8058",
            target_crs="EPSG:8058",
            feature_count=expect_n,
            geometry_type=hdr["geom_type"],
            invalid_geometry_count_before=inv_before,
            invalid_geometry_count_after=inv_before,  # nothing repaired; equal by design
            geometry_validity="valid" if inv_before == 0 else "repaired",
            import_status="registered",
            note=note,
            run_id=RUN_ID,
            checksum_sha256=checksum,
            path_exists=1,
            field_list=fc["field_list"],
        ))
    return rows


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")
    rows = build_rows()

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        try:
            total = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
            for row in rows:
                aid, alias = row["spatial_layer_asset_id"], row["layer_name"]
                clash = con.execute(
                    "SELECT spatial_layer_asset_id FROM spatial_layer_asset "
                    "WHERE spatial_layer_asset_id=? AND layer_name<>?",
                    (aid, alias)).fetchone()
                if clash:
                    raise SystemExit(f"ABORT: {aid} already used by a different layer {clash[0]!r}")
                alias_clash = con.execute(
                    "SELECT spatial_layer_asset_id FROM spatial_layer_asset "
                    "WHERE layer_name=? AND spatial_layer_asset_id<>?",
                    (alias, aid)).fetchone()
                if alias_clash:
                    raise SystemExit(
                        f"ABORT: alias {alias!r} already used by {alias_clash[0]!r}")
        finally:
            con.close()
        print(f"[check] spatial_layer_asset currently has {total} rows -> {total + len(rows)} after.")
        for row in rows:
            print(f"[check] planned {row['spatial_layer_asset_id']} ({row['layer_name']}):")
            for c in COLS:
                v = row[c]
                vs = str(v)
                print(f"           {c:32s} = {vs[:90]}{'...' if len(vs) > 90 else ''}")
        print("[check] NO DB WRITE performed.")
        return

    # ---- execute -----------------------------------------------------------
    con = sqlite3.connect(DB.as_posix())
    try:
        before = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
        con.execute(
            "INSERT OR REPLACE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 0, 'REVIEW')",
            (RUN_ID, RUN_DATETIME,
             "scripts/11_database/register_T12_gateA0_vectors.py",
             '{"gate": "A0", "spec": "docs/reference_update/T12_dea_landcover_l3_extraction.md v2"}'))
        ph = ", ".join(["?"] * len(COLS))
        for row in rows:
            con.execute(
                f"INSERT OR REPLACE INTO spatial_layer_asset ({', '.join(COLS)}) VALUES ({ph})",
                tuple(row[c] for c in COLS))
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM spatial_layer_asset").fetchone()[0]
        print(f"[execute] spatial_layer_asset rows: {before} -> {after}")
        for aid in ("spatial_007", "spatial_008", "spatial_009"):
            got = con.execute(
                "SELECT spatial_layer_asset_id, path, layer_name, source_crs, feature_count, "
                "geometry_type, geometry_validity, path_exists, substr(checksum_sha256,1,12), "
                "field_list FROM spatial_layer_asset WHERE spatial_layer_asset_id=?", (aid,)).fetchone()
            print("          ", got)
        untouched = con.execute(
            "SELECT spatial_layer_asset_id, source_crs FROM spatial_layer_asset "
            "WHERE spatial_layer_asset_id IN ('spatial_001','spatial_002','spatial_003') "
            "ORDER BY spatial_layer_asset_id").fetchall()
        print(f"[execute] pre-existing rows untouched: {untouched}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
