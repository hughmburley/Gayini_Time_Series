#!/usr/bin/env python
"""Pack v1.3 T4 - assemble, manifest, checksum both sides.

PACK1_assemble.py pattern. v1.3 SUPERSEDES v1.2 BY MANIFEST: v1.2 is neither edited nor
deleted, and the manifest records its seal so anything already circulating stays traceable.

EVERY TABLE A CAPTION OR A METADATA DOCUMENT ASSERTS FROM IS IN THE MANIFEST - including
PARTREG_part_regression_coefficients.csv, which carries the community-slope fits
(2.6_aeolian / 2.6_riverine / 2.6_inland). v1.2 asserted its community counter-finding
from that table and did not ship it. That is the specific gap this pack closes.

Two checksums per file: full SHA-256 for the copy check, because the GeoPackage is
53.8 MB and a first-50-MB hash cannot see corruption past 50 MB; and the project's
first-50-MB convention so rows reconcile with figure_asset / table_asset.
"""
import csv, hashlib, shutil, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "Output" / "pack" / "v1_3"
V12_ZIP = ROOT / "Output" / "Gayini_Adrian_pack_v1.2_20260805.zip"

FILES = [
 ("figures", "Output/figures/PARTREG_S2_three_periods_115_parts.png",
  "Does the cover-and-water relationship change between eras? Rebuilt for v1.3: panel order C/A/B, "
  "community lines on panel C, chenopod lines dotted because their intervals span zero."),
 ("figures", "Output/figures/PARTREG_S2_residual_maps_three_periods.png",
  "Which parts hold more or less cover than their water predicts. Panels unchanged from v1.2; "
  "FOOTER REPLACED - 8.08 pp is the average miss, not the typical miss anywhere."),
 ("geodata", "Output/spatial_8058/PARTREG_part_residuals.gpkg",
  "THE FILE TO MAP FROM. 115 paddock x community parts, EPSG:8058, CELL-ACCURATE geometry - not the "
  "simplified render-only set. Colour by whole_record__residual."),
 ("geodata", "Output/spatial_8058/PARTREG_part_residuals.qml",
  "QGIS style, graduated on whole_record__residual, same seven-stop ramp as the printed maps."),
 ("geodata", "Output/tables/PARTREG_part_residuals.csv",
  "The same table flat, with join keys part_id / zone_fid / paddock_name / community."),
 ("geodata", "Output/tables/PARTREG_part_residuals_DATA_DICTIONARY.md",
  "Every column: units, support, period. Read before using either table."),
 ("metadata", "Output/metadata/Gayini_metadata_ground_cover.md",
  "Ground-cover provenance record. SEED-shaped, not a lodgement."),
 ("metadata", "Output/metadata/Gayini_metadata_inundation.md",
  "Inundation provenance record. SEED-shaped, not a lodgement."),
 ("tables", "Output/tables/PARTREG_part_regression_coefficients.csv",
  "ASSERTED FROM by the three-periods caption: the pooled fit 2.3_weighted and the three community "
  "fits 2.6_*. v1.2 asserted from this table and did not ship it."),
 ("tables", "Output/tables/PARTREG_S2_regression_coefficients.csv",
  "ASSERTED FROM by both figures: the period fits S2_cropping_era_common, S2_post_management_common, "
  "S2_whole_record_common."),
 ("tables", "Output/tables/PACKv13_T0_caption_numbers.csv",
  "ASSERTED FROM by both captions: the Inland wetness fifths and the residual SD by water quartile, "
  "reproduced in R and registered as cap_* number_ids."),
 ("tables", "Output/tables/PARTREG_S2_part_summary_by_period.csv",
  "The per-part per-period summary the figures are drawn from."),
]

def sha_full(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(4 << 20), b""): h.update(c)
    return h.hexdigest()

def sha50(p):
    h, n = hashlib.sha256(), 0
    with open(p, "rb") as f:
        while n < 50 * 1024 * 1024:
            b = f.read(1024 * 1024)
            if not b: break
            h.update(b); n += len(b)
    return h.hexdigest()

con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
reg = {}
for t, idc in (("figure_asset", "figure_asset_id"), ("table_asset", "table_asset_id")):
    for aid, path, ck in con.execute(f"SELECT {idc}, path, checksum_sha256 FROM {t}"):
        if path: reg[path.replace("\\", "/")] = (aid, (ck or "").lower())
con.close()

rows, bad = [], []
for group, rel, what in FILES:
    src = ROOT / rel
    if not src.exists():
        bad.append((rel, "MISSING")); continue
    out = DEST / group / src.name
    out.parent.mkdir(parents=True, exist_ok=True)
    sf, s5, size = sha_full(src), sha50(src), src.stat().st_size
    shutil.copy2(src, out)
    ok = sha_full(out) == sf and out.stat().st_size == size
    if not ok: bad.append((rel, "COPY MISMATCH"))
    aid, rck = reg.get(rel, ("", ""))
    rows.append(dict(group=group, file=src.name, source_path=rel,
                     pack_path=str(out.relative_to(ROOT)).replace("\\", "/"), bytes=size,
                     sha256_full=sf, sha256_first50=s5, copy_verified=int(ok),
                     registry_id=aid or "NOT REGISTERED",
                     registry_checksum=rck or "not registered",
                     registry_agrees=("" if not rck else int(rck == s5)), what_it_is=what))
    print(f"  {'OK ' if ok else '***'} {size/1024/1024:8.2f} MB  {group:8s} {src.name}")

note = DEST / "00_COVERING_NOTE.md"
rows.append(dict(group="(root)", file=note.name, source_path="(authored in place, not copied)",
                 pack_path=str(note.relative_to(ROOT)).replace("\\", "/"), bytes=note.stat().st_size,
                 sha256_full=sha_full(note), sha256_first50=sha50(note), copy_verified=1,
                 registry_id="NOT REGISTERED", registry_checksum="not registered",
                 registry_agrees="", what_it_is="What changed from v1.2 and why."))

man = DEST / "PACKv13_manifest.csv"
cols = list(rows[0])
with man.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)

# supersession is recorded, not performed: v1.2 is untouched
sup = DEST / "SUPERSESSION.md"
v12 = f"{sha_full(V12_ZIP)}" if V12_ZIP.exists() else "(v1.2 zip not found on disk)"
sup.write_text(
 "# Supersession\n\n"
 "**Pack v1.3 supersedes pack v1.2 by manifest, 7 August 2026.**\n\n"
 "v1.2 is **not edited and not deleted**. It remains sealed at its own checksum so any copy already "
 "circulating can be traced to the pack it came from.\n\n"
 f"| | |\n|---|---|\n| v1.2 seal | `{V12_ZIP.name}` |\n| v1.2 SHA-256 | `{v12}` |\n"
 f"| v1.3 manifest | `PACKv13_manifest.csv`, {len(rows)} files |\n\n"
 "**What v1.3 replaces:** the three-periods figure (rebuilt), the residual maps (footer only).\n"
 "**What v1.3 withdraws:** `PARTREG_S1_floor_vs_flood_115_parts.png` - its panel A duplicated the "
 "whole-record panel and its percentile sweep moves to the methods document.\n"
 "**What v1.3 adds:** two metadata documents, the part-residual geodata with a QGIS style, and the "
 "coefficient tables the captions assert from.\n", encoding="utf-8")

total = sum(r["bytes"] for r in rows)
regd = [r for r in rows if r["registry_agrees"] != ""]
unreg = [r for r in rows if r["registry_id"] == "NOT REGISTERED"]
print(f"\n  files {len(rows)}   total {total/1024/1024:.1f} MB")
print(f"  copy verified both sides (full SHA-256): {all(r['copy_verified'] for r in rows)}")
print(f"  registry checksum agrees: {sum(r['registry_agrees'] for r in regd)} of {len(regd)} registered")
print(f"  carrying no registry row: {len(unreg)} -> {[r['file'] for r in unreg]}")
print(f"  problems: {bad or 'none'}")
