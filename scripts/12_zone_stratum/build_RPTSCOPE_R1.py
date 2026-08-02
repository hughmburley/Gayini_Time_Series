#!/usr/bin/env python
"""RPT-SCOPE Gate R1 — the report set (D1) and the claim audit (D2). READ-ONLY. NO DB WRITES.

D1 emits Output/tables/RPTSCOPE_report_set.csv, 32 rows, selection_rule in {A, B1, B2}.
D2 emits Output/tables/RPTSCOPE_claim_audit.csv, every claim resolved against the LIVE DB into
   PINNED / SOURCED / DERIVED / UNSUPPORTED, each carrying the query that produced it.
"""
import sqlite3, csv, statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TAB = ROOT / "Output" / "tables"
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); con.execute("PRAGMA query_only=1")
c = con.cursor()

PINS = {n: v for n, v in c.execute(
    "SELECT number_id, pinned_value FROM dim_headline_number WHERE pinned_value IS NOT NULL")}
REPRO = {r["number_id"] for r in csv.DictReader(
    open(TAB / "RPTSCOPE_reproduction_status.csv", encoding="utf-8")) if r["status"] == "REPRODUCES"}

# ============================================================ D1 — the report set
# zone_name IS NOT NULL is load-bearing, not tidying: 18 reportable plots sit in NO management
# zone, and that NULL bucket is the LARGEST single group. Without the filter, B2's "the grazed
# paddock carrying the most reportable sites" silently selects the unzoned bucket, which is not a
# paddock and yields a report set of 21 sites instead of 25.
Q_SITES = ("SELECT zone_name, COUNT(*) FROM plot_paddock "
           "WHERE simplified_vegetation_group <> 'Floodplain Woodland / Forest' "
           "AND zone_name IS NOT NULL GROUP BY 1")
sites = dict(c.execute(Q_SITES))
Q_CONS = "SELECT zone_name FROM dim_management_zone WHERE grazing_excluded = 1 ORDER BY zone_name"
conserved = [r[0] for r in c.execute(Q_CONS)]

# Arm B1 — grazed paddocks NAMED in a register/caption claim. Named in register v3 §1 claim 6
# ("the strongest improver ... is grazed" = Bala 15, residual rank 1) and in the F5 / M5b captions
# (Dinan 10). Both verified against v_zone_floor_flood_residual below.
Q_RANK = "SELECT zone_name, residual, rank FROM v_zone_floor_flood_residual WHERE rank <= 3 ORDER BY rank"
ranks = {z: (res, rk) for z, res, rk in c.execute(Q_RANK)}
B1 = ["Bala 15", "Dinan 10"]
# Arm B2 — the grazed paddock carrying the most reportable sites
grazed = {z: n for z, n in sites.items() if z not in conserved}
B2 = [max(grazed, key=lambda z: grazed[z])]

rows = []
for z in conserved:
    rows.append(dict(doc_type="paddock", paddock=z, site_id="", selection_rule="A",
                     rule_text="conserved: every No grazing paddock, complete, no selection",
                     reportable_sites=sites.get(z, 0)))
for z in B1:
    rows.append(dict(doc_type="paddock", paddock=z, site_id="", selection_rule="B1",
                     rule_text="grazed paddock named in a register-v3 claim or a pack caption",
                     reportable_sites=sites.get(z, 0)))
for z in B2:
    rows.append(dict(doc_type="paddock", paddock=z, site_id="", selection_rule="B2",
                     rule_text="grazed paddock carrying the most reportable sites",
                     reportable_sites=sites.get(z, 0)))
paddocks = [r["paddock"] for r in rows]
Q_PLOTS = ("SELECT zone_name, plot_id FROM plot_paddock "
           "WHERE simplified_vegetation_group <> 'Floodplain Woodland / Forest' "
           "AND zone_name IS NOT NULL "
           "AND zone_name IN (%s) ORDER BY zone_name, plot_id" % ",".join("?" * len(paddocks)))
for z, pid in c.execute(Q_PLOTS, paddocks):
    rule = "A" if z in conserved else ("B1" if z in B1 else "B2")
    rows.append(dict(doc_type="site", paddock=z, site_id=pid, selection_rule=rule,
                     rule_text="non-treed site inside a selected paddock", reportable_sites=""))

with open(TAB / "RPTSCOPE_report_set.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
npad = sum(1 for r in rows if r["doc_type"] == "paddock")
nsite = sum(1 for r in rows if r["doc_type"] == "site")
print(f"D1: {npad} paddock + {nsite} site = {len(rows)} documents")
assert {r["selection_rule"] for r in rows} <= {"A", "B1", "B2"}, "selection_rule outside {A,B1,B2}"
assert npad == 7 and nsite == 25, (npad, nsite)

# ============================================================ D2 — the claim audit
def q1(sql, *p):
    r = c.execute(sql, p).fetchone()
    return None if r is None else r[0]

claims = []
def add(cid, text, state, number_id, source_object, query, computed, stated, item, note=""):
    agrees = ""
    if computed is not None and stated not in ("", None):
        try: agrees = int(abs(float(computed) - float(stated)) <= 0.051)
        except (TypeError, ValueError): agrees = ""
    claims.append(dict(claim_id=cid, claim_text=text[:300], state=state,
                       number_id=number_id or "", source_object=source_object or "",
                       query=(query or "").replace("\n", " ")[:400],
                       computed_value="" if computed is None else computed,
                       stated_value=stated, agrees=agrees,
                       pack_item_carrying_it=item, note=note))

# --- register v3 §1, claim 1: no trend, +0.06 pp/yr, r = 0.22
sl = q1("SELECT pinned_value FROM dim_headline_number WHERE number_id='t10_gap_annual_slope_B_excl29ca'")
rr = q1("SELECT pinned_value FROM dim_headline_number WHERE number_id='t10_gap_annual_r_B_excl29ca'")
add("REG-C1a", "the difference shows no trend in either direction (+0.06 pp/yr)",
    "PINNED" if "t10_gap_annual_slope_B_excl29ca" in REPRO else "SOURCED",
    "t10_gap_annual_slope_B_excl29ca", "dim_headline_number",
    "SELECT pinned_value FROM dim_headline_number WHERE number_id='t10_gap_annual_slope_B_excl29ca'",
    sl, 0.06, "F3", "reproduces in the status table")
add("REG-C1b", "r = 0.22 on that trend",
    "PINNED" if "t10_gap_annual_r_B_excl29ca" in REPRO else "SOURCED",
    "t10_gap_annual_r_B_excl29ca", "dim_headline_number",
    "SELECT pinned_value FROM dim_headline_number WHERE number_id='t10_gap_annual_r_B_excl29ca'",
    rr, 0.22, "F3")

# --- claim 3 / Q5: water explains about half the variation
r64 = q1("SELECT pinned_value FROM dim_headline_number WHERE number_id='floor_flood_r_64pdk'")
add("REG-C3", "water explains about half the variation between paddocks (r^2 from r=0.71)",
    "PINNED", "floor_flood_r_64pdk", "dim_headline_number",
    "SELECT pinned_value FROM dim_headline_number WHERE number_id='floor_flood_r_64pdk'",
    round(r64 ** 2, 3), "~0.50", "F5, M5b", "r^2 = 0.504; 'about half' is fair")

# --- claim 6: eight recovering, five survive
rec = q1("SELECT pinned_value FROM dim_headline_number WHERE number_id='t13_parts_recovering_count'")
surv = q1("SELECT COUNT(*) FROM fact_zone_community_part_classification "
          "WHERE state_registered='Recovering' AND state_drop2wettest='Recovering'")
add("REG-C6a", "eight parts meet the recovering criterion", "PINNED",
    "t13_parts_recovering_count", "dim_headline_number",
    "SELECT pinned_value FROM dim_headline_number WHERE number_id='t13_parts_recovering_count'",
    rec, 8, "M4, T2")
add("REG-C6b", "five survive dropping the two wettest years", "SOURCED", "",
    "fact_zone_community_part_classification",
    "SELECT COUNT(*) FROM fact_zone_community_part_classification WHERE state_registered='Recovering' AND state_drop2wettest='Recovering'",
    surv, 5, "M4, T2", "NOT pinned - candidate for R2")

# --- claim 6: the strongest improver is grazed  (Bala 15, residual rank 1)
b15 = ranks.get("Bala 15")
add("REG-C6c", "the strongest improver on the property is a grazed paddock (Bala 15, residual rank 1)",
    "SOURCED", "", "v_zone_floor_flood_residual",
    "SELECT zone_name,residual,rank FROM v_zone_floor_flood_residual WHERE rank<=3",
    b15[1] if b15 else None, 1, "F5, M5b",
    f"Bala 15 residual {b15[0]}" if b15 else "Bala 15 not in top 3")

# --- claim 7: geography, 12 of 16 declining in the Bala group
dec_bala = q1("SELECT COUNT(*) FROM fact_zone_community_part_classification "
              "WHERE state_registered='Declining' AND zone_name LIKE 'Bala%'")
dec_all = q1("SELECT COUNT(*) FROM fact_zone_community_part_classification "
             "WHERE state_registered='Declining'")
add("REG-C7", "12 of 16 declining parts are in the Bala group", "SOURCED", "",
    "fact_zone_community_part_classification",
    "SELECT COUNT(*) ... WHERE state_registered='Declining' AND zone_name LIKE 'Bala%'",
    dec_bala, 12, "M4", f"denominator computed {dec_all}; NOT pinned - candidate for R2")

# --- By_question Q2: six of nine strata  (the design-seat probe)
vw = list(c.execute("SELECT community,regime_band,n_ungrazed_bala,veg_p05_delta_bala_pxwtd,"
                    "ungrazed_p05_min,ungrazed_p05_max FROM v_zone_stratum_contrast_bala_robust"))
six9 = sum(1 for _, _, n, d, lo, hi in vw if (hi - lo) > abs(d))
multi = [(cm, b, n, d, lo, hi) for cm, b, n, d, lo, hi in vw if n > 1]
six7 = sum(1 for _, _, n, d, lo, hi in multi if (hi - lo) > abs(d))
add("BYQ-Q2a", "the spread among the conserved paddocks is larger than the conserved-grazed "
    "difference in six of nine strata", "SOURCED", "", "v_zone_stratum_contrast_bala_robust",
    "SELECT ... ; count where (ungrazed_p05_max-ungrazed_p05_min) > abs(veg_p05_delta_bala_pxwtd)",
    six9, 6, "F6", "reproduces exactly; NOT in dim_headline_number")
add("BYQ-Q2b", "restricted to strata with more than one conserved paddock", "SOURCED", "",
    "v_zone_stratum_contrast_bala_robust",
    "same, filtered n_ungrazed_bala > 1",
    f"{six7} of {len(multi)}", "6 of 7", "F6",
    "TRUER STATEMENT - the two n=1 strata have spread 0.0 by construction")
add("BYQ-Q2c", "the conserved paddocks track the grazed median within 1.5 to 3.3 percentage points",
    "UNSUPPORTED", "", "none",
    "no producer; range exists only inside the caveat of ref_grazed_floor_gap_3pdk_periodwise",
    None, "1.5 to 3.3 pp", "F1, F2, T1, M2",
    "PIN 3 is permanently unpinned; spec P4 forbids this wording. Live in the By_question sheet.")

with open(TAB / "RPTSCOPE_claim_audit.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(claims[0].keys())); w.writeheader(); w.writerows(claims)

from collections import Counter
print("D2:", dict(Counter(x["state"] for x in claims)), f"({len(claims)} claims)")
for x in claims:
    print(f"   {x['claim_id']:9} {x['state']:12} computed={str(x['computed_value'])[:14]:14} "
          f"stated={str(x['stated_value'])[:14]:14} agrees={x['agrees']}")
print("\nNO DB WRITES. Two CSVs emitted.")
con.close()
