#!/usr/bin/env python
"""Assemble Output/pack/PARTREG - the part-grain bundle Adrian maps from.

PACK-1 convention: copy from registered sources, verify SHA-256 on BOTH sides, write a
manifest, edit nothing in place.

TWO CHECKSUMS PER FILE, on purpose:
  sha256_full     the whole file - a copy check must be able to see corruption past
                  50 MB, and the GeoPackage is 53.8 MB
  sha256_first50  the project convention, so each row reconciles with table_asset /
                  figure_asset

Source rasters are NOT duplicated here: Output/pack/DATA/ already holds them at 649 MB
and the README points there.

Where a file carries no registry row, the manifest says so - the DATA README's
convention, stated rather than implied.
"""
from __future__ import annotations

import csv
import hashlib
import shutil
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "Output" / "pack" / "PARTREG"

FILES = [
    ("spatial", "Output/spatial_8058/PARTREG_part_residuals.gpkg",
     "THE FILE TO MAP FROM. 115 paddock x community parts, EPSG:8058, the full attribute "
     "table joined. Open in QGIS and colour by whole_record__residual."),
    ("tables", "Output/tables/PARTREG_part_residuals.csv",
     "The same table, flat. Join keys part_id / zone_fid / paddock_name / community, so it "
     "also joins many-to-one to the 64 paddock polygons for a paddock view."),
    ("tables", "Output/tables/PARTREG_part_residuals_DATA_DICTIONARY.md",
     "Every column: units, support, period. Read this before using either table."),
    ("tables", "Output/tables/PARTREG_S2_regression_coefficients.csv",
     "Every fit run at part grain: period, weighting, slope, intercept, r, residual SD, n, "
     "bootstrap interval."),
    ("tables", "Output/tables/PARTREG_S2_spread_ratio.csv",
     "The water-axis spread ratio - year-to-year movement against between-part differences."),
    ("tables", "Output/tables/PARTREG_S2_part_summary_by_period.csv",
     "One row per part per period: means and across-year spread on both axes."),
    ("figures", "Output/figures/PARTREG_S1_floor_vs_flood_115_parts.png",
     "Stage 1. The part-grain fit against the registered 64-paddock line, and the percentile "
     "sweep that closes the which-percentile question."),
    ("figures", "Output/figures/PARTREG_S2_three_periods_115_parts.png",
     "Stage 2. The same fit in three periods."),
    ("figures", "Output/figures/PARTREG_S2_residual_maps_three_periods.png",
     "Stage 2. Residuals mapped, one panel per period, each against its own period's line."),
    ("figures", "Output/figures/SCHEM1_figure25_axis_chain.png",
     "SCHEM-1. How each axis of the cover-and-water figure is built, end to end."),
    ("", "docs/reference_update/Gayini_PARTREG_findings.md",
     "The findings note: what the part grain shows, what it does not, and one hypothesis "
     "marked as a hypothesis."),
]


def sha_full(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda: f.read(4 << 20), b""):
            h.update(c)
    return h.hexdigest()


def sha_first50(p: Path) -> str:
    h, n, cap = hashlib.sha256(), 0, 50 * 1024 * 1024
    with p.open("rb") as f:
        while n < cap:
            b = f.read(1024 * 1024)
            if not b:
                break
            h.update(b); n += len(b)
    return h.hexdigest()


con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",
                      uri=True)
con.execute("PRAGMA query_only=1")
reg: dict[str, tuple[str, str]] = {}
for tbl, idcol in (("figure_asset", "figure_asset_id"), ("table_asset", "table_asset_id")):
    for aid, path, ck in con.execute(f"SELECT {idcol}, path, checksum_sha256 FROM {tbl}"):
        if path:
            reg[path.replace("\\", "/")] = (aid, (ck or "").lower())
con.close()

rows, bad = [], []
for group, rel, what in FILES:
    src = ROOT / rel
    if not src.exists():
        bad.append((rel, "SOURCE MISSING")); continue
    out = (DEST / group / src.name) if group else (DEST / src.name)
    out.parent.mkdir(parents=True, exist_ok=True)
    s_full, s_50, size = sha_full(src), sha_first50(src), src.stat().st_size
    shutil.copy2(src, out)
    d_full, d_50 = sha_full(out), sha_first50(out)
    ok = (s_full == d_full) and (size == out.stat().st_size)
    if not ok:
        bad.append((rel, "COPY MISMATCH"))
    aid, rck = reg.get(rel, ("", ""))
    rows.append(dict(
        group=group or "(root)", file=src.name, source_path=rel,
        pack_path=str(out.relative_to(ROOT)).replace("\\", "/"), bytes=size,
        sha256_full=s_full, sha256_first50=s_50, copy_verified=int(ok),
        registry_id=aid or "NOT REGISTERED",
        registry_checksum=rck or "not registered",
        registry_agrees=("" if not rck else int(rck == s_50)),
        what_it_is=what))
    flag = "OK " if ok else "***"
    print(f"  {flag} {size/1024/1024:8.2f} MB  {(group or 'root'):8s} {src.name}")

cols = ["group", "file", "source_path", "pack_path", "bytes", "sha256_full", "sha256_first50",
        "copy_verified", "registry_id", "registry_checksum", "registry_agrees", "what_it_is"]
man = DEST / "PARTREG_manifest.csv"
with man.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)

total = sum(r["bytes"] for r in rows)
regd = [r for r in rows if r["registry_agrees"] != ""]
unreg = [r for r in rows if r["registry_id"] == "NOT REGISTERED"]
print(f"\n  files {len(rows)}   total {total/1024/1024:.1f} MB")
print(f"  copy verified both sides (full SHA-256): {all(r['copy_verified'] for r in rows)}")
print(f"  registry checksum agrees: {sum(r['registry_agrees'] for r in regd)} of {len(regd)} registered")
print(f"  carrying no registry row: {len(unreg)}" +
      (f" -> {[r['file'] for r in unreg]}" if unreg else ""))
print(f"  problems: {bad or 'none'}")
print(f"  manifest: {man.relative_to(ROOT)}")
