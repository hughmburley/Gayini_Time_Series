#!/usr/bin/env python
"""UNZONED Stage A1 - the Python/R boundary. Assemble the analysis CSV, checksum it.

Ruling AS: Python retains the spatial machinery and table assembly and writes a
CHECKSUMMED analysis CSV at the boundary. All estimation is in R
(UNZONED_stageA1_within.R). No new extraction - this reads the Gate 1 series.
"""
import csv
import hashlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
MIN_CELLS_YEAR = 30

inv = {r["patch_id"]: r for r in csv.DictReader(
    open(T / "UNZONED_gate1_patch_inventory.csv", encoding="utf-8-sig"))}
sup = {k for k, r in inv.items() if r["meets_support_rule"] == "1"}
arr = np.load(T / "UNZONED_gate1_patch_series.npy")
print(f"[in] {arr.shape[0]:,} patch-years over {len(inv):,} patches; {len(sup)} supported")

rows, dropped = [], 0
for g, wy, nval, p05, wet, val, ffp in arr:
    pid = f"U{int(g):04d}"
    if pid not in sup:
        continue
    if nval < MIN_CELLS_YEAR or not np.isfinite(p05) or not np.isfinite(ffp):
        dropped += 1
        continue
    m = inv[pid]
    rows.append(dict(patch_id=pid, community=m["community"],
                     community_short=m["community_short"],
                     n_cells=int(m["n_cells"]), area_ha=float(m["area_ha"]),
                     water_year=int(wy), n_valid=int(nval),
                     veg_p05_spatial=float(p05), inund_pct=float(ffp),
                     wet_pixels=int(wet), valid_pixels=int(val),
                     unit_construction="8-connected component within one community, "
                                       "outside every management zone",
                     land_use_label="unzoned standard-grazing country",
                     support_level="pixel", aggregation_unit="patch_year",
                     cluster_note="no paddock exists here; the cluster is the PATCH, which "
                                  "differs from the real-part estimate clustering on zone_fid",
                     period_label="1988-2022"))
rows.sort(key=lambda r: (r["patch_id"], r["water_year"]))
out = T / "UNZONED_stageA1_patch_year.csv"
with out.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)

h, n, cap = hashlib.sha256(), 0, 50 * 1024 * 1024
with out.open("rb") as f:
    while n < cap:
        b = f.read(1024 * 1024)
        if not b:
            break
        h.update(b); n += len(b)
(T / "UNZONED_stageA1_patch_year.sha256").write_text(
    f"{h.hexdigest()}  {out.name}  first-50MB SHA-256\n", encoding="utf-8")

npatch = len({r["patch_id"] for r in rows})
print(f"[out] {out.name}: {len(rows):,} patch-years over {npatch} patches "
      f"({len(sup)*35 - len(rows)} of {len(sup)*35} dropped below {MIN_CELLS_YEAR} valid cells)")
for cs in ("aeolian", "riverine", "inland"):
    k = {r["patch_id"] for r in rows if r["community_short"] == cs}
    print(f"      {cs:<9s} {len(k):>3} patches")
print(f"[sha256-first50] {h.hexdigest()}")
