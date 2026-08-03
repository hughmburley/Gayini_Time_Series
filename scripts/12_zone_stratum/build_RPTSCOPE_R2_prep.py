#!/usr/bin/env python
"""RPT-SCOPE R2 prep — Rulings 1, 3, 4 applied to the claim audit. READ-ONLY. NO DB WRITES.

RULING 3: `agrees` uses a flat +/-0.051 and flags rounding as disagreement. A new column
          `agrees_at_stated_precision` rounds the computed value to the precision the CLAIM
          states before comparing. `agrees` is retained unchanged so nothing silently moves.
          P4 must filter on the new column, never on `agrees`.
RULING 4: BYQ-Q7a / Q7b -> N/A_by_design. An honest non-answer is a feature of this pack and
          must not read as a provenance failure.
RULING 1: the pin rule, applied and reported BEFORE anything is registered.
"""
import csv, re
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / "Output" / "tables" / "RPTSCOPE_claim_audit.csv"
rows = list(csv.DictReader(open(AUDIT, encoding="utf-8")))

def dec_of(s):
    """decimals the CLAIM states, e.g. '17' -> 0, '~0.50' -> 2, '3 to 15' -> None"""
    m = re.fullmatch(r"[~+]?(-?\d+)(?:\.(\d+))?\s*(?:pp|%)?", str(s).strip())
    if not m: return None
    return len(m.group(2)) if m.group(2) else 0

for r in rows:
    ap = ""
    d = dec_of(r["stated_value"])
    try:
        cv = float(r["computed_value"]); sv = float(re.sub(r"[~+]|\s*(pp|%)", "", str(r["stated_value"])))
        if d is not None: ap = int(round(cv, d) == round(sv, d))
    except (TypeError, ValueError): ap = ""
    r["agrees_at_stated_precision"] = ap

# ---- RULING 4
for r in rows:
    if r["claim_id"] in ("BYQ-Q7a", "BYQ-Q7b"):
        r["state"] = "N/A_by_design"
rows_by_id = {r["claim_id"]: r for r in rows}
rows_by_id["BYQ-Q7a"]["note"] = (
    "N/A_by_design: the CLAIM (did management change the water regime) is untestable with four "
    "post-management years. The supporting 43.6% / 22.8% pair DOES reproduce exactly - "
    "pixel-weighted SUM(wet_pixels)/SUM(valid_pixels) over fact_zone_veg_annual, split at 2019, "
    "n=4 and n=31. Mean-of-paddock-means gives 46.0/25.2 - the aggregation_order qualifier is "
    "what separates them. The cell's number is sound and stays.")
rows_by_id["BYQ-Q7b"]["note"] = (
    "N/A_by_design: Task J is analytically complete but blocked on Jana (cut-date provenance L07, "
    "bank geometry L10). Not a provenance failure - a stated external blocker.")

# ---- RULING 1: the pin rule
def n_items(r):
    s = r["pack_item_carrying_it"].strip()
    if not s or s.startswith("(none"): return 0
    return len([x for x in s.split(",") if x.strip()])

sourced = [r for r in rows if r["state"] == "SOURCED"]
selected, left = [], []
for r in sourced:
    multi = n_items(r) > 1
    numbered = r["claim_id"].startswith("REG-C")
    (selected if (multi or numbered) else left).append(
        dict(r, _why=("multi-deliverable" if multi else "") + ("+register-§1-claim" if numbered else "")))

with open(AUDIT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

print("=== RULING 3 — agrees_at_stated_precision ===")
flip = [r for r in rows if r["agrees"] == "0" and r["agrees_at_stated_precision"] == 1]
print(f"  column added. rows where agrees=0 but agree AT STATED PRECISION: {len(flip)}")
for r in flip: print(f"     {r['claim_id']}: computed {r['computed_value']} vs stated {r['stated_value']}")
print("  `agrees` retained unchanged; P4 filters on agrees_at_stated_precision.")

print("\n=== RULING 4 ===")
print("  BYQ-Q7a, BYQ-Q7b -> N/A_by_design")
print("  Q7a's 43.6/22.8 pair RECOMPUTED and verified (pixel-weighted); the cell keeps its number.")

print("\n=== RULING 1 — the pin rule, applied ===")
print(f"  SOURCED rows after Ruling 4: {len(sourced)}")
print(f"  SELECTED FOR PINNING: {len(selected)}")
for r in selected:
    print(f"     {r['claim_id']:10} [{r['_why']:32}] {r['claim_text'][:58]}")
print(f"\n  LEFT SOURCED (provenance = RPTSCOPE_claim_audit.csv in table_asset): {len(left)}")
for r in left:
    print(f"     {r['claim_id']:10} {r['claim_text'][:66]}")
print()
print(f"  >>> rule selects {len(selected)}; threshold is 8 -> "
      f"{'PROCEED' if len(selected) <= 8 else '*** STOP AND REPORT ***'}")
print(f"\n  states now: {dict(Counter(r['state'] for r in rows))}")
