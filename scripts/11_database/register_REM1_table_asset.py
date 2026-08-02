#!/usr/bin/env python
"""REM-1 Gate C - create table_asset and register the two unregistered pack-item tables.

WHY A NEW REGISTRY. Output/tables/ holds 83 files and had NO registry at all - an entire
output class outside provenance. The two register-v2 pack items among them (T2 and the table
component of T1) are Category C in AUD-1 and are blocked from shipping by REP-6. Putting a
results table into report_asset would be a category error: report_asset is for documents, and
this database is meant to outlive the contract.

table_asset mirrors the existing registry family exactly - same path / product / run_id /
path_exists / checksum_sha256 / qa_status / superseded_flag conventions as raster_asset,
report_asset, census_asset and spatial_layer_asset - so it reads as an obvious member.

ADDITIVE ONLY. CREATE TABLE IF NOT EXISTS; INSERT OR REPLACE keyed on table_asset_id (never
OR IGNORE - CLAUDE.md). Nothing modified, nothing dropped, no builder run.

Checksum convention: first-50-MB SHA-256, identical to sha256_first50() and the R registrar.

TWO KNOWN LIMITS, RECORDED NOT FIXED:
  1. Builder integration is a follow-up. A manually created table would be destroyed by a
     builder re-run. Bounded by the standing rule that the builder is never re-run, but it is
     a real dependency and is logged in the issues register.
  2. Only the two pack items are registered here. The other 81 files in Output/tables/ are a
     post-10-August job and are deliberately NOT bulk-registered.
"""
import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))

DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN_ID = "rem1_rerender_20260801"
CAP = 50 * 1024 * 1024


def sha256_first50(path: Path) -> str:
    h = hashlib.sha256()
    n = 0
    with open(path, "rb") as f:
        while n < CAP:
            b = f.read(1024 * 1024)
            if not b:
                break
            h.update(b)
            n += len(b)
    return h.hexdigest()


def n_rows(path: Path) -> int:
    with open(path, "r", encoding="utf-8-sig") as f:
        return max(sum(1 for _ in f) - 1, 0)   # minus header


ITEMS = [
    dict(table_asset_id="table_t13_gatec_classification",
         rel="Output/tables/T13_gateC_classification.csv",
         title="T13 Gate C paddock-part classification (115 parts)",
         product="paddock_part_classification",
         support_level="stratum",
         provenance_note=("register v2 pack item T2 'The recovering and declining parts'. "
                          "Built by scripts/12_zone_stratum/build_T13_gateC_classification.py under "
                          "run_id T13_gateE; pre-registered +/-1.0 cut, sweep 0.50-1.50. Registered "
                          "by REM-1 Gate C: it was on disk and correct but in NO registry, which "
                          "blocked it under REP-6.")),
    dict(table_asset_id="table_t1_conserved_paddock_comparison",
         rel="Output/tables/T1_conserved_paddock_comparison.csv",
         title="T1 conserved paddock comparison (4 paddocks)",
         product="conserved_paddock_comparison",
         support_level="zone",
         provenance_note=("TABLE COMPONENT of register v2 pack item T1. Register v2 classes T1 as a "
                          "Table but the registered artefact was the .png; this .csv was "
                          "unregistered. Both are now registered - WHICH ONE IS THE PACK ITEM IS A "
                          "DESIGN-SEAT DECISION, deliberately not made here. Built by "
                          "scripts/12_zone_stratum/build_adrian_pack_T1_F3_F5.R under "
                          "run_id adrian_pack_20260731.")),
]

con = sqlite3.connect(DB)
c = con.cursor()

existed = c.execute(
    "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='table_asset'").fetchone()[0]
c.execute("""
CREATE TABLE IF NOT EXISTS table_asset (
    table_asset_id  TEXT PRIMARY KEY,
    path            TEXT NOT NULL,
    title           TEXT,
    product         TEXT,
    n_rows          INTEGER,
    checksum_sha256 TEXT,
    path_exists     INTEGER,
    qa_status       TEXT,
    run_id          TEXT,
    superseded_flag INTEGER,
    framing_label   TEXT,
    provenance_note TEXT,
    support_level   TEXT
)""")
print(f"table_asset: {'already existed' if existed else 'CREATED'}")

rows = []
for it in ITEMS:
    p = ROOT / it["rel"].replace("/", "\\")
    if not p.exists():
        con.close()
        raise SystemExit(f"ABORT: {it['rel']} not on disk; nothing written.")
    rows.append((it["table_asset_id"], it["rel"], it["title"], it["product"], n_rows(p),
                 sha256_first50(p), 1, "REVIEW", RUN_ID, 0, "census_8058",
                 it["provenance_note"], it["support_level"]))

c.executemany(
    "INSERT OR REPLACE INTO table_asset (table_asset_id,path,title,product,n_rows,"
    "checksum_sha256,path_exists,qa_status,run_id,superseded_flag,framing_label,"
    "provenance_note,support_level) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
con.commit()

print(f"\nregistered {len(rows)} rows, run_id={RUN_ID}")
for r in rows:
    print(f"   {r[0]:<40} {r[4]:>4} rows  {r[5][:12]}  {r[1]}")

total_tables = len(list((ROOT / "Output" / "tables").glob("*")))
print(f"\nOutput/tables/ holds {total_tables} files; {len(rows)} now registered, "
      f"{total_tables - len(rows)} still unregistered (post-10-Aug job, NOT bulk-registered here).")
con.close()
