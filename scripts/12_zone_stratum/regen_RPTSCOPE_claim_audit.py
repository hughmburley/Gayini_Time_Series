#!/usr/bin/env python
"""RPT-SCOPE P3-6/P3-7 — REGENERATE the claim audit from the LIVE registry. READ-ONLY.

The file was written at R1b; R2 then pinned six of the quantities it lists as SOURCED, and it is
registered in table_asset as the provenance record for exactly the rows it now misdescribes.
So `state` is re-derived by live lookup, never edited in place (same ruling as AD-B and L7).

P3-7 also fixes two mis-mappings:
  BYQ-Q6  was PINNED to t13_parts_recovering_count = 8 while its claim reads "three to fifteen".
          The pin does not state the claim -> repointed to the sweep spread it actually asserts.
  REG-C3 / BYQ-Q5  quote r-squared 0.50 against a pin holding r = 0.71. Arithmetic right, lookup
          impossible -> derivation noted on both rows.
"""
import sqlite3, csv
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "Output" / "tables" / "RPTSCOPE_claim_audit.csv"
con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",
                      uri=True); con.execute("PRAGMA query_only=1"); c = con.cursor()

PINS = {n: v for n, v in c.execute(
    "SELECT number_id, pinned_value FROM dim_headline_number WHERE pinned_value IS NOT NULL")}
REPRO = {r["number_id"] for r in csv.DictReader(
    open(ROOT / "Output/tables/RPTSCOPE_reproduction_status.csv", encoding="utf-8"))
    if r["status"] == "REPRODUCES"}

# claim_id -> the number_id R2 registered for it (P3-6)
NEWLY_PINNED = {
 "REG-C6b": "t13_recovering_survive_drop2wettest",
 "REG-C6c": "bala15_xsec_residual",
 "REG-C4a": "bala29ca_improvement_surviving_water_pct",
 "REG-C5":  "ref_paddock_flood_rank_bala26ca,ref_paddock_flood_rank_bala27ca,"
            "ref_paddock_flood_rank_bala28ca,ref_paddock_flood_rank_bala29ca",
 "BYQ-Q1":  "cropping_history_null_count",
 "BYQ-Q4":  "three_arm_standard_at_or_above_count",
}

rows = list(csv.DictReader(open(AUDIT, encoding="utf-8")))
before = Counter(r["state"] for r in rows)

for r in rows:
    cid = r["claim_id"]
    # ---- P3-6: live re-derivation of state
    if cid in NEWLY_PINNED:
        r["number_id"] = NEWLY_PINNED[cid]
        ids = NEWLY_PINNED[cid].split(",")
        r["state"] = "PINNED" if all(i in PINS for i in ids) else "SOURCED"
        r["note"] = (f"REGENERATED {('P3-6')}: pinned at R2 (3 Aug); this row read SOURCED when the "
                     f"audit was written at R1b. State re-derived by live lookup against "
                     f"dim_headline_number, not edited. " + r["note"])[:600]
    elif r["state"] in ("PINNED", "SOURCED") and r["number_id"] and "," not in r["number_id"]:
        r["state"] = "PINNED" if r["number_id"] in PINS else r["state"]

    # ---- P3-7 (a): BYQ-Q6 pinned to a number that does not state its claim
    if cid == "BYQ-Q6":
        lo, hi = c.execute("SELECT spread_min, spread_max FROM dim_headline_number "
                           "WHERE number_id='t13_parts_recovering_count'").fetchone()
        r["number_id"] = "t13_parts_recovering_count (SPREAD, not pinned_value)"
        r["state"] = "SOURCED"
        r["note"] = (f"P3-7 MIS-MAPPING FIXED: this row was PINNED to t13_parts_recovering_count, "
                     f"whose pinned_value is {PINS['t13_parts_recovering_count']:g} - but the claim "
                     f"reads 'between three and fifteen parts are improving'. The pin does not state "
                     f"the claim. The claim is the SWEEP RANGE, spread_min {lo:g} to spread_max "
                     f"{hi:g} on that row, which is a spread and not a pinned value - so the claim "
                     f"is SOURCED, not PINNED. " + r["note"])[:600]

    # ---- P3-7 (b): r vs r-squared
    if cid in ("REG-C3", "BYQ-Q5"):
        rr = PINS["floor_flood_r_64pdk"]
        r["note"] = (f"P3-7 DERIVATION NOTED: the claim quotes r-squared ~{rr**2:.3f}; the pin "
                     f"floor_flood_r_64pdk holds r = {rr}. The arithmetic is right "
                     f"({rr} squared = {rr**2:.4f}) but a reader looking up 0.504 will not find it. "
                     f"State the derivation wherever this claim appears. " + r["note"])[:600]

with open(AUDIT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

after = Counter(r["state"] for r in rows)
print("=== P3-6 STATE COUNTS ===")
for k in sorted(set(before) | set(after)):
    print(f"  {k:22} before {before.get(k,0):3}   after {after.get(k,0):3}")
print(f"\n  total rows {len(rows)} (unchanged)")
print("\n=== the six newly-pinned rows ===")
for r in rows:
    if r["claim_id"] in NEWLY_PINNED:
        print(f"  {r['claim_id']:9} {r['state']:9} -> {r['number_id'][:70]}")
print("\n=== P3-7 ===")
for r in rows:
    if r["claim_id"] in ("BYQ-Q6", "REG-C3", "BYQ-Q5"):
        print(f"  {r['claim_id']:9} {r['state']:9} {r['number_id'][:60]}")
con.close()
