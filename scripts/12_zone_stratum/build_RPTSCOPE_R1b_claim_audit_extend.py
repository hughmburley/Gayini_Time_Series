#!/usr/bin/env python
"""RPT-SCOPE R1b — extend the claim audit to FULL coverage. READ-ONLY, APPEND ONLY.

Adds the claims absent from R1: register v3 §1 C2, C4, C5, and By_question Q1, Q3, Q4, Q5, Q6, Q7.
Does NOT re-audit the ten rows already present. Prints coverage as claim-count vs row-count so
completeness is checkable rather than asserted.
"""
import sqlite3, csv, statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
AUDIT = ROOT / "Output" / "tables" / "RPTSCOPE_claim_audit.csv"
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); con.execute("PRAGMA query_only=1")
c = con.cursor()

existing = list(csv.DictReader(open(AUDIT, encoding="utf-8")))
FIELDS = list(existing[0].keys())
have = {r["claim_id"] for r in existing}
new = []

def q1(sql, *p):
    r = c.execute(sql, p).fetchone()
    return None if r is None else r[0]

def add(cid, text, state, nid, src, query, computed, stated, item, note=""):
    assert cid not in have, f"{cid} already audited - append only"
    agrees = ""
    if computed is not None and stated not in ("", None):
        try: agrees = int(abs(float(computed) - float(stated)) <= 0.051)
        except (TypeError, ValueError): agrees = ""
    new.append(dict(claim_id=cid, claim_text=text[:300], state=state, number_id=nid or "",
                    source_object=src or "", query=(query or "").replace("\n", " ")[:400],
                    computed_value="" if computed is None else computed, stated_value=stated,
                    agrees=agrees, pack_item_carrying_it=item, note=note))

# ---------- REG-C2 : Bala 29ca's difference and improvement predate management by ~30 years
slope29 = q1("SELECT pinned_value FROM dim_headline_number WHERE number_id='t10_gap_annual_slope_C_29ca'")
add("REG-C2a", "Bala 29ca's improvement predates conservation management by thirty years "
    "(monotonic convergence from 1988; management changed 2019)", "SOURCED", "",
    "Output/tables/T10_annual_gap_series.csv + t10_gap_annual_slope_C_29ca",
    "SELECT pinned_value ... 't10_gap_annual_slope_C_29ca'; series C_29ca runs 1988-2022",
    slope29, "+0.919 pp/yr from 1988", "F3",
    "the SLOPE is pinned and reproduces; 'predates by thirty years' is an INTERPRETATION of the "
    "series start, not a computed quantity")
add("REG-C2b", "Bala 29ca produces every reference-state result the project has", "DERIVED", "",
    "multiple (T10 gap decomposition, T13 part states, v_zone_floor_flood_residual)",
    "no single query; asserted across T10/T13 outputs",
    None, "(qualitative)", "F3, M4, T1",
    "TRUE but not reducible to one number; rests on C1 (no trend without 29ca) plus 29ca's rank-2 residual")

# ---------- REG-C4 / BYQ-Q3 : low and improving after water; 82% survives; dry western parts
import csv as _csv
tmp = {r["zone_name"]: r for r in _csv.DictReader(
    open(ROOT / "Output" / "tables" / "T10_gateC_temporal_table.csv", encoding="utf-8"))}
b29 = tmp["Bala 29ca"]
pct = 100 * float(b29["water_adjusted_floor_trend"]) / float(b29["raw_floor_trend"])
add("REG-C4a", "82% of Bala 29ca's improvement survives removing the effect of the water it "
    "actually received", "SOURCED", "", "Output/tables/T10_gateC_temporal_table.csv",
    "water_adjusted_floor_trend / raw_floor_trend for Bala 29ca",
    round(pct, 1), 82, "F5, M4", "0.5563 / 0.6821; NOT pinned - candidate for R2")
resid29, rank29 = c.execute(
    "SELECT residual, rank FROM v_zone_floor_flood_residual WHERE zone_name='Bala 29ca'").fetchone()
add("BYQ-Q3a", "its poorest patches carry 17 percentage points less cover than its dryness "
    "predicts - the second largest shortfall on the property", "SOURCED", "",
    "v_zone_floor_flood_residual",
    "SELECT residual, rank FROM v_zone_floor_flood_residual WHERE zone_name='Bala 29ca'",
    abs(resid29), 17, "F5, M5b",
    f"rank {rank29} of 64 confirms 'second largest'; |residual| 16.80 rounds to 17")
aeo = q1("SELECT trend_z FROM fact_zone_community_part_classification "
         "WHERE zone_name='Bala 29ca' AND community LIKE 'Aeolian%'")
add("REG-C4b", "the improvement is located in its dry western parts, not the paddock as a whole",
    "SOURCED", "", "fact_zone_community_part_classification",
    "SELECT community, state_registered, trend_z ... WHERE zone_name='Bala 29ca'",
    "Aeolian+Riverine Recovering; Inland not", "(qualitative)", "M4, T1",
    f"Aeolian trend_z {aeo}; Inland is Declining and NOT asserted")

# ---------- REG-C5 : three of four sit in the property's easiest country
rk = {z: r for z, r in c.execute(
    "SELECT zone_name, RANK() OVER (ORDER BY mean_flood DESC) FROM v_zone_floor_flood_residual")}
easy = [z for z in ("Bala 26ca", "Bala 27ca", "Bala 28ca") if rk[z] <= 32]
add("REG-C5", "three of four conserved paddocks sit almost entirely in the property's easiest "
    "country; only Bala 29ca spans the range", "SOURCED", "", "v_zone_floor_flood_residual",
    "RANK() OVER (ORDER BY mean_flood DESC) over 64 paddocks",
    f"26ca r{rk['Bala 26ca']}, 27ca r{rk['Bala 27ca']}, 28ca r{rk['Bala 28ca']}, 29ca r{rk['Bala 29ca']}",
    "3 of 4 wettest half", "F1, F2, M2",
    f"{len(easy)} of 3 in the wettest half; 29ca rank {rk['Bala 29ca']} of 64 - the driest end")

# ---------- BYQ-Q1 : cropping history not recorded, five reserved columns empty 64/64
cols = [d[1] for d in c.execute("PRAGMA table_info(dim_management_zone)")]
n_zones = q1("SELECT COUNT(*) FROM dim_management_zone")
n_null = q1("SELECT COUNT(*) FROM dim_management_zone WHERE cropping_history IS NULL")
add("BYQ-Q1", "cropping history is not recorded anywhere; five reserved columns, all empty for "
    "all 64 paddocks", "SOURCED", "", "dim_management_zone",
    "SELECT COUNT(*) FROM dim_management_zone WHERE cropping_history IS NULL",
    f"{n_null} of {n_zones} NULL", "64 of 64 empty", "M1, F1, T1",
    "T12 confirmed DEA cannot fill it; the 'five reserved columns' count is not separately verified here")

# ---------- BYQ-Q4 : standard grazing at or above rotational in six of nine comparisons
try:
    arms = list(c.execute(
        "SELECT community, regime_band, treatment_arm, floor_deficit_pp FROM v_three_arm_gap_decomposition "
        "WHERE window='all' AND regime_band IN ('low','mid','high')"))
    byk = {}
    for cm, b, arm, v in arms: byk.setdefault((cm, b), {})[arm] = v
    n_ok = sum(1 for k, d in byk.items()
               if "unzoned_inferred_standard" in d and d["unzoned_inferred_standard"] >= 0)
    add("BYQ-Q4", "the standard-grazing land sits at or above the rotationally grazed land in six "
        "of nine comparisons", "SOURCED", "", "v_three_arm_gap_decomposition",
        "count strata where unzoned_inferred_standard floor_deficit_pp >= 0 (i.e. at or above 14-day)",
        f"{n_ok} of {len(byk)}", "6 of 9", "F6, M2",
        "third arm is the 15 UNZONED Standard-grazing plots - see the R1b exclusion note")
except Exception as e:
    add("BYQ-Q4", "standard grazing at or above rotational in six of nine", "UNSUPPORTED", "",
        "v_three_arm_gap_decomposition", f"query failed: {e}", None, "6 of 9", "F6, M2")

# ---------- BYQ-Q5 : duplicate of REG-C3
add("BYQ-Q5", "how often a paddock floods explains about half the variation in cover",
    "PINNED", "floor_flood_r_64pdk", "dim_headline_number",
    "same as REG-C3; r^2 = 0.504", 0.504, "~0.50", "M3, M5, F5",
    "DUPLICATE of REG-C3 - one quantity stated in two places")

# ---------- BYQ-Q6 : between three and fifteen parts improving, same parts throughout
lo = q1("SELECT spread_min FROM dim_headline_number WHERE number_id='t13_parts_recovering_count'")
hi = q1("SELECT spread_max FROM dim_headline_number WHERE number_id='t13_parts_recovering_count'")
add("BYQ-Q6", "between three and fifteen parts are improving depending on how strictly the line "
    "is drawn, and it is the same parts throughout", "PINNED", "t13_parts_recovering_count",
    "dim_headline_number",
    "SELECT spread_min, spread_max FROM dim_headline_number WHERE number_id='t13_parts_recovering_count'",
    f"{lo:g} to {hi:g}", "3 to 15", "M4, F7, T2", "the sweep spread; nesting verified at T13 Gate C")

# ---------- BYQ-Q7 : four water years, two largest floods, 24 placebo dates
add("BYQ-Q7a", "four water years since management changed, two containing the largest natural "
    "floods in the record", "SOURCED", "", "fact_zone_veg_annual / register v3 §1 closing note",
    "register v3 states mean inundation 43.6% post vs 22.8% across the preceding 31 years",
    None, "4 years; 2 largest", "(none - caveat text)",
    "NOT independently recomputed at R1b; the 43.6/22.8 pair is a register statement without a number_id")
add("BYQ-Q7b", "the 2018 bank cuts were tested with a flow law fitted on 24 placebo dates",
    "SOURCED", "", "Task J outputs",
    "Task J placebo ladder; 24 placebo dates",
    None, "24 placebo dates", "(none - caveat text)",
    "Task J is complete but BLOCKED on Jana (cut-date provenance L07, bank geometry L10)")

with open(AUDIT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=FIELDS); w.writeheader()
    w.writerows(existing); w.writerows(new)

allrows = existing + new
from collections import Counter
print(f"appended {len(new)} rows; audit now {len(allrows)} rows")
print("states:", dict(Counter(r["state"] for r in allrows)))
print()
REG = {"REG-C1", "REG-C2", "REG-C3", "REG-C4", "REG-C5", "REG-C6", "REG-C7"}
BYQ = {f"BYQ-Q{i}" for i in range(1, 8)}
covered = {r["claim_id"].rstrip("abc") for r in allrows}
print("=== COVERAGE, checkable ===")
print(f"  register v3 §1 claims : {len(REG)} declared, {len(REG & covered)} covered  -> {sorted(REG - covered) or 'COMPLETE'}")
print(f"  By_question cells     : {len(BYQ)} declared, {len(BYQ & covered)} covered  -> {sorted(BYQ - covered) or 'COMPLETE'}")
print(f"  total claims {len(REG)+len(BYQ)} -> {len(allrows)} audit rows "
      f"(some claims decompose into >1 checkable assertion)")
uns = [r for r in allrows if r["state"] == "UNSUPPORTED"]
print(f"\n  UNSUPPORTED: {len(uns)}  {'<= 4, continue' if len(uns) <= 4 else '*** > 4 - STOP AND REPORT ***'}")
for r in uns: print(f"     {r['claim_id']}: {r['claim_text'][:80]}")
con.close()
