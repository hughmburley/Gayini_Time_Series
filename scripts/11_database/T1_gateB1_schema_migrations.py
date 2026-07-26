#!/usr/bin/env python3
"""T1 · Gate B1 — additive schema migrations (idempotent).

Spec: docs/T1_zone_stratum_census_join.md v3, Gate B1 + the 25 Jul refinement.

Additive `ALTER TABLE ADD COLUMN` only - the one sanctioned exception to
"no existing table modified". Every step guards on the current schema so a
re-run is a no-op. This script IS the post-build re-application (CLAUDE.md
already records these ALTERs in the post-build chain; a rebuild drops columns).

Steps:
  1. figure_asset      += support_level TEXT, figure_level TEXT
  2. spatial_layer_asset += checksum_sha256 TEXT, path_exists INTEGER, field_list TEXT
  3. Migrate spatial_006 checksum + path_exists OUT of `note` into the real
     columns - RECOMPUTED first-50-MB SHA-256 from the file (not transcribed),
     and report whether it matches the value currently in `note`.
  4. Populate field_list for all six rows from the registered file's ACTUAL
     fields (Output/tables/T1_gateB1_field_lists.csv), file order.
  6. Do NOT backfill the existing 255 figure_asset rows (out of scope).

Usage: python scripts/11_database/T1_gateB1_schema_migrations.py [check|execute|convergence]
"""
from __future__ import annotations

import csv
import hashlib
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
GPKG_006 = ROOT / "Output" / "spatial_8058" / "management_zones_epsg8058.gpkg"
FIELD_CSV = ROOT / "Output" / "tables" / "T1_gateB1_field_lists.csv"
RUN_ID = "T1_gateB1"

NEW_COLUMNS = [
    ("figure_asset", "support_level", "TEXT"),
    ("figure_asset", "figure_level", "TEXT"),
    ("spatial_layer_asset", "checksum_sha256", "TEXT"),
    ("spatial_layer_asset", "path_exists", "INTEGER"),
    ("spatial_layer_asset", "field_list", "TEXT"),
]


def sha256_first50(path: Path) -> str:
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk); read += len(chunk)
    return h.hexdigest()


def existing_columns(con, table) -> set:
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def load_field_lists() -> dict:
    if not FIELD_CSV.is_file():
        raise SystemExit(f"ABORT: {FIELD_CSV} missing. Run "
                         "scripts/12_zone_stratum/T1_gateB1_read_field_lists.R first.")
    out = {}
    for r in csv.DictReader(FIELD_CSV.open(encoding="utf-8")):
        out[r["spatial_layer_asset_id"]] = dict(
            field_list=r["field_list"], readable=(r["readable"].lower() == "true"),
            resolved=r["resolved_file"])
    return out


def missing_alters(con):
    return [(t, c, ty) for t, c, ty in NEW_COLUMNS if c not in existing_columns(con, t)]


def report_checksum(con):
    """Recompute spatial_006 first-50-MB SHA-256; compare to the value in note."""
    note = con.execute(
        "SELECT note FROM spatial_layer_asset WHERE spatial_layer_asset_id='spatial_006'"
    ).fetchone()[0] or ""
    m = re.search(r"([0-9a-f]{64})", note)
    note_val = m.group(1) if m else None
    recomputed = sha256_first50(GPKG_006)
    return note_val, recomputed, (note_val == recomputed)


def main(mode: str) -> None:
    fields = load_field_lists()
    note_val, recomputed, match = report_checksum(
        sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True))
    print(f"[checksum] spatial_006 recomputed first-50-MB = {recomputed}")
    print(f"[checksum] value transcribed in note          = {note_val}")
    print(f"[checksum] recomputed matches note value       : {match}")

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        miss = missing_alters(con)
        print(f"[check] columns to add: {len(miss)} {[(t,c) for t,c,_ in miss]}")
        print("[check] field_list to write (actual registered-file fields):")
        for sid in sorted(fields):
            fl = fields[sid]["field_list"]
            print(f"    {sid}: {fl[:70]}{'…' if len(fl) > 70 else ''}")
        con.close()
        print("[check] NO DB WRITE.")
        return

    if mode == "execute":
        con = sqlite3.connect(DB.as_posix())
        try:
            added = 0
            for t, c, ty in NEW_COLUMNS:
                if c not in existing_columns(con, t):
                    con.execute(f"ALTER TABLE {t} ADD COLUMN {c} {ty}"); added += 1
            con.commit()
            print(f"[execute] columns added: {added}")

            # step 3: spatial_006 checksum + path_exists -> real columns; clean note
            new_note = (
                "T1 Gate A0 additive registration of the EPSG:8058 zone layer "
                "(spec docs/T1_zone_stratum_census_join.md v3). CRS EPSG:8058 read "
                "from gpkg header; feature_count=64. checksum_sha256 and path_exists "
                "migrated to their own columns at Gate B1 (first-50-MB SHA-256 "
                "RECOMPUTED from the file, not transcribed). The EPSG:28355 row "
                "spatial_004 is left untouched.")
            con.execute(
                "UPDATE spatial_layer_asset SET checksum_sha256=?, path_exists=1, note=? "
                "WHERE spatial_layer_asset_id='spatial_006'", (recomputed, new_note))

            # step 4: field_list for all six from actual registered-file fields
            for sid, info in fields.items():
                con.execute("UPDATE spatial_layer_asset SET field_list=? "
                            "WHERE spatial_layer_asset_id=?", (info["field_list"], sid))
            con.commit()

            # verify
            rows = con.execute(
                "SELECT spatial_layer_asset_id, checksum_sha256 IS NOT NULL, path_exists, "
                "field_list IS NOT NULL FROM spatial_layer_asset ORDER BY spatial_layer_asset_id"
            ).fetchall()
            print("[execute] spatial_layer_asset (id, has_checksum, path_exists, has_field_list):")
            for r in rows:
                print("   ", r)
            fa_cols = existing_columns(con, "figure_asset")
            print(f"[execute] figure_asset has support_level/figure_level: "
                  f"{ {'support_level','figure_level'} <= fa_cols }")
            backfilled = con.execute(
                "SELECT COUNT(*) FROM figure_asset WHERE support_level IS NOT NULL "
                "OR figure_level IS NOT NULL").fetchone()[0]
            print(f"[execute] existing figure_asset rows populated (must be 0 - no backfill): {backfilled}")
        finally:
            con.close()
        return

    if mode == "convergence":
        # mutate field_list of spatial_006, re-run population, confirm convergence
        con = sqlite3.connect(DB.as_posix())
        try:
            orig = con.execute("SELECT field_list FROM spatial_layer_asset WHERE spatial_layer_asset_id='spatial_006'").fetchone()[0]
            con.execute("UPDATE spatial_layer_asset SET field_list='MUTATED' WHERE spatial_layer_asset_id='spatial_006'")
            con.commit()
            con.execute("UPDATE spatial_layer_asset SET field_list=? WHERE spatial_layer_asset_id='spatial_006'",
                        (fields["spatial_006"]["field_list"],))
            con.commit()
            restored = con.execute("SELECT field_list FROM spatial_layer_asset WHERE spatial_layer_asset_id='spatial_006'").fetchone()[0]
            print(f"[convergence] mutated 'MUTATED' -> re-run restored='{restored}' "
                  f"(converged: {restored == fields['spatial_006']['field_list'] == orig})")
        finally:
            con.close()
        return

    raise SystemExit(f"unknown mode {mode!r}; use check|execute|convergence")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
