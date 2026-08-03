#!/usr/bin/env python
"""RPT-SCOPE — per-row reproduction status for every dim_headline_number row.

WHY THIS EXISTS. `test_T8_headline_reproduction.py` prints "14 DRIFTED of 71 checked", which
admits two readings: either the test iterates 71 of which 14 fail (=> 57 reproduce), or it
iterates 85 of which 71 reproduce and 14 have no derivation path. Those are 67% and 84%, and the
number goes on the pack's How_we_know sheet under a client cover. This settles it from the data
rather than from the string.

Read-only. Emits Output/tables/RPTSCOPE_reproduction_status.csv, one line per registered row.
"""
import sqlite3, csv, importlib.util, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT = ROOT / "Output" / "tables" / "RPTSCOPE_reproduction_status.csv"

# import the test module so the SAME recompute paths are used - not a reimplementation
spec = importlib.util.spec_from_file_location(
    "t8", ROOT / "scripts" / "11_database" / "test_T8_headline_reproduction.py")
t8 = importlib.util.module_from_spec(spec); spec.loader.exec_module(t8)

con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
c = con.cursor()

registered = list(c.execute(
    "SELECT number_id, pinned_value, label FROM dim_headline_number ORDER BY number_id"))

# exactly what run() builds
rc = t8.recompute(c)
rc.update(t8.recompute_t10(c)); rc.update(t8.recompute_reg1(c))
rc.update(t8.recompute_reg2(c)); rc.update(t8.recompute_t13(c)); rc.update(t8.recompute_rptscope_r2(c))

rows = []
for nid, pv, label in registered:
    iterated = pv is not None                      # the test's WHERE clause
    has_path = nid in rc
    recomputed = rc.get(nid)
    if not iterated:
        status, agrees = "NOT_PINNED_deliberate", ""
    elif not has_path:
        status, agrees = "NO_DERIVATION_PATH", ""
    else:
        ok = abs(recomputed - pv) <= t8.unit_tol(nid)
        status = "REPRODUCES" if ok else "VALUE_DRIFT"
        agrees = int(ok)
    rows.append(dict(number_id=nid, label=(label or "")[:90],
                     iterated_by_test=int(iterated),
                     recompute_path_exists=int(has_path),
                     status=status,
                     stated_value="" if pv is None else pv,
                     recomputed_value="" if recomputed is None else round(recomputed, 6),
                     agrees=agrees,
                     tolerance="" if not iterated else t8.unit_tol(nid)))

OUT.parent.mkdir(parents=True, exist_ok=True)
with open(OUT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

n_reg = len(rows)
n_pin = sum(r["iterated_by_test"] for r in rows)
n_path = sum(r["recompute_path_exists"] and r["iterated_by_test"] for r in rows)
n_ok = sum(1 for r in rows if r["status"] == "REPRODUCES")
n_drift = sum(1 for r in rows if r["status"] == "VALUE_DRIFT")
n_nopath = sum(1 for r in rows if r["status"] == "NO_DERIVATION_PATH")
n_unpin = sum(1 for r in rows if r["status"] == "NOT_PINNED_deliberate")

print("=== THE FOUR COUNTS, stated explicitly ===")
print(f"  rows registered in dim_headline_number      : {n_reg}")
print(f"  rows carrying a pinned value                : {n_pin}")
print(f"  rows the test ITERATES (= pinned)           : {n_pin}")
print(f"  rows that recompute AND agree               : {n_ok}")
print()
print(f"  of the pinned rows: {n_path} have a derivation path, {n_nopath} do not")
print(f"  of those {n_path}: {n_ok} agree, {n_drift} drift in VALUE")
print(f"  deliberately unpinned (excluded by the WHERE): {n_unpin}")
print()
print("=== the test's own summary string, decoded ===")
print(f'  "{n_nopath + n_drift} DRIFTED of {n_path} checked"')
print(f"  `checked` counts ONLY rows with a derivation path ({n_path}), but `fails` counts")
print(f"  BOTH value drifts ({n_drift}) AND missing paths ({n_nopath}) - so the {n_nopath + n_drift}")
print(f"  is NOT a subset of the {n_path}. {n_nopath + n_drift} + {n_path} = {n_nopath + n_drift + n_path} = the pinned rows.")
print()
print(f"  COVERAGE = {n_ok}/{n_pin} = {100*n_ok/n_pin:.0f}% of pinned rows"
      f"  ({n_ok}/{n_reg} = {100*n_ok/n_reg:.0f}% of registered rows)")
print(f"  VALUE DRIFTS = {n_drift}")
print(f"\nwrote {OUT}")
con.close()
