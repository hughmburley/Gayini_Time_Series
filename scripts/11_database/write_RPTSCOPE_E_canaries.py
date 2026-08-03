#!/usr/bin/env python
"""RPT-SCOPE Ruling E — parameterised contract states, executable SQL, and canary pins.

E1  number_id becomes PARAMETERISED:/TEXT_CONSTANT:. Zero UNPINNED.
E2  every parameterised row carries the EXACT SQL the builder must read, not a description.
E3  canaries. EXISTENCE TEST FIRST (I-39): 3 of the 5 already exist and are NAMED, not duplicated.
    Only 2 are registered.
E4  Bala 29ca is the canary paddock; the reason is recorded on every canary row.
"""
import sqlite3, csv, os, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
CONTRACT = ROOT / "Output" / "tables" / "RPTSCOPE_number_contract.csv"
RUN = "RPTSCOPE_E_20260803"
SENTINEL = "n/a - no pixel-to-area conversion in this quantity"
NT = "treed_context_flag = 0 AND regime_band <> 'context'"

CANARY_REASON = (
    "CANARY PADDOCK = Bala 29ca. Reason: it carries every reference-state result the project has, "
    "it is already the most heavily pinned zone in the registry (24 rows), and if a parameterised "
    "query drifts it is the paddock where the drift will be noticed first.")

# ---- the five parameterised quantities: EXACT SQL, canary number_id, existing or new
PARAM = {
 (1, "cover headline"): dict(
    q="the paddock cover floor",
    sql="SELECT AVG(veg_p05_spatial) FROM fact_zone_veg_annual "
        "WHERE zone_fid = :zone_fid AND series_variant = 'mean_of_seasons' "
        "AND water_year BETWEEN 1988 AND 2022",
    canary="rptscope_canary_p1_paddock_floor_bala29ca", exists=False, value=40.52),
 (2, "flood frequency"): dict(
    q="the paddock mean annual flood frequency",
    sql="SELECT AVG(flood_frac_pct) FROM fact_zone_veg_annual "
        "WHERE zone_fid = :zone_fid AND series_variant = 'mean_of_seasons' "
        "AND water_year BETWEEN 1988 AND 2022",
    canary="bala29ca_mean_flood_freq", exists=True, value=8.5),
 (3, "community composition"): dict(
    q="the paddock's community shares, denominator A",
    sql="SELECT community, share_a FROM v_zone_community_composition "
        "WHERE zone_fid = :zone_fid ORDER BY share_a DESC",
    canary="t10_refset_inland_share_bala29ca", exists=True, value=34.6),
 (4, "this paddock's residual"): dict(
    q="the paddock residual from the registered flood expectation line",
    sql="SELECT residual, rank FROM v_zone_floor_flood_residual WHERE zone_fid = :zone_fid",
    canary="t10_bala29ca_xsec_residual", exists=True, value=-16.8),
 (5, "part states"): dict(
    q="the paddock's part states at the registered cut",
    sql="SELECT community, state_registered, pp_split, assert_state "
        "FROM fact_zone_community_part_classification WHERE zone_fid = :zone_fid ORDER BY community",
    canary="rptscope_canary_p5_recovering_parts_bala29ca", exists=False, value=2),
}

def probe(lbl):
    c = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); c.execute("PRAGMA query_only=1")
    o = {t: c.cursor().execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
         for t in ("dim_headline_number", "figure_asset", "raster_asset", "table_asset", "report_asset")}
    c.close(); print(f"  PROBE {lbl}: " + " · ".join(f"{k}={v}" for k, v in o.items())); return o

print("=== E3 EXISTENCE TEST (I-39: existence before merit) ===")
for (pg, panel), d in PARAM.items():
    print(f"  page {pg} {panel:26} canary {d['canary']:46} {'EXISTS - named, not duplicated' if d['exists'] else 'MISSING - to register'}")
new = [d for d in PARAM.values() if not d["exists"]]
print(f"  -> {len(new)} to register, {len(PARAM)-len(new)} named from existing\n")

pre = probe("before")
con = sqlite3.connect(DB); c = con.cursor()
have = {r[0] for r in c.execute("SELECT number_id FROM dim_headline_number")}
for d in PARAM.values():
    if d["exists"] and d["canary"] not in have:
        con.close(); raise SystemExit(f"ABORT: named canary {d['canary']} does not exist")
    if not d["exists"] and d["canary"] in have:
        con.close(); raise SystemExit(f"ABORT: {d['canary']} already exists - would duplicate")

try:
    con.execute("BEGIN")
    c.execute("INSERT INTO dim_headline_number(number_id,label,source_object,grain,aggregation_order,"
              "series_variant,scope_filter,period_label,denominator,pixel_constant,pinned_value,"
              "spread_min,spread_max,support_level,caveat,decided_by,decision_note) "
              "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
              ("rptscope_canary_p1_paddock_floor_bala29ca",
               "Bala 29ca mean cover floor - CANARY for report page 1 cover headline",
               "fact_zone_veg_annual.veg_p05_spatial", "zone",
               "mean over water years of the annual zone veg_p05_spatial",
               "mean_of_seasons",
               f"zone_fid = 4 (Bala 29ca); {NT}", "1988-2022", "1 paddock", SENTINEL,
               40.52, None, None, "zone",
               "CANARY for a PARAMETERISED contract row: it fixes the DEFINITION, not the 32 "
               "instantiations. If the query drifts this value moves and the test fails.",
               "RPT-SCOPE Ruling E, design seat 3 Aug 2026", CANARY_REASON +
               " Canary for contract row page 1 / cover headline."))
    c.execute("INSERT INTO dim_headline_number(number_id,label,source_object,grain,aggregation_order,"
              "series_variant,scope_filter,period_label,denominator,pixel_constant,pinned_value,"
              "spread_min,spread_max,support_level,caveat,decided_by,decision_note) "
              "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
              ("rptscope_canary_p5_recovering_parts_bala29ca",
               "Bala 29ca parts classified Recovering - CANARY for report page 5 part states",
               "fact_zone_community_part_classification.state_registered", "zone_community",
               "count of parts at the registered +/-1.0 cut", "mean_of_seasons",
               "zone_fid = 4 (Bala 29ca); 115 supported parts, >=25 yr, n_pixels_valid>=30",
               "1988-2022", "3 parts in Bala 29ca", "0.062351428",
               2, None, None, "pixel",
               "CANARY for a PARAMETERISED contract row. Bala 29ca's third part (Inland) is "
               "Declining with assert_state = 0, so this count is 2 of 3, not 3 of 3.",
               "RPT-SCOPE Ruling E, design seat 3 Aug 2026", CANARY_REASON +
               " Canary for contract row page 5 / part states."))
    c.execute("INSERT OR REPLACE INTO workflow_run(run_id,run_datetime,script_name,repo_commit,"
              "parameters_json,is_current,qa_status) VALUES (?,?,?,?,?,?,?)",
              (RUN, "2026-08-03T00:00:00+00:00", "scripts/11_database/write_RPTSCOPE_E_canaries.py",
               None, '{"ruling":"E","canaries_new":2,"canaries_named_existing":3}', 1, "REVIEW"))
    con.commit(); print("  COMMIT - 2 canaries inserted")
except Exception as e:
    con.rollback(); con.close(); raise SystemExit(f"ROLLED BACK: {e}")
con.close()
post = probe("after")

# ---------------------------------------------------------------- E1 + E2 rewrite the contract
rows = list(csv.DictReader(open(CONTRACT, encoding="utf-8")))
fn = list(rows[0].keys())
if "exact_sql" not in fn: fn += ["exact_sql", "canary_number_id"]
for r in rows:
    r.setdefault("exact_sql", ""); r.setdefault("canary_number_id", "")
    key = (int(r["page"]), r["panel"]) if r["page"].isdigit() else None
    if key in PARAM:
        d = PARAM[key]
        r["number_id"] = f"PARAMETERISED: {d['q']}; argument = zone_fid"
        r["exact_sql"] = d["sql"]
        r["canary_number_id"] = d["canary"]
    elif r["panel"] == "scope lock footer":
        r["number_id"] = "TEXT_CONSTANT: not a number"
        r["exact_sql"] = ("(no query) The pinned form is the exact string: "
                          "'non-treed ground, whole paddock, full record'. It is in the contract "
                          "because the string ASSERTS SCOPE and can drift like any number.")
with open(CONTRACT, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fn); w.writeheader(); w.writerows(rows)

data = [r for r in rows if r["page"] != "ALL"]
npin = sum(1 for r in data if not r["number_id"].startswith(("PARAMETERISED", "TEXT_CONSTANT", "UNPINNED")))
npar = sum(1 for r in data if r["number_id"].startswith("PARAMETERISED"))
ntxt = sum(1 for r in data if r["number_id"].startswith("TEXT_CONSTANT"))
nunp = sum(1 for r in data if r["number_id"] == "UNPINNED")
print(f"\n=== E1/E2 CONTRACT ===")
print(f"  {len(data)} rows: {npin} pinned · {npar} parameterised · {ntxt} text constant · {nunp} UNPINNED")
print(f"  parameterised rows carrying executable SQL : {sum(1 for r in data if r['exact_sql'] and 'SELECT' in r['exact_sql'])}")
print(f"  parameterised rows naming a canary          : {sum(1 for r in data if r['canary_number_id'])}")
print(f"\n  dim_headline_number {pre['dim_headline_number']} -> {post['dim_headline_number']} (expected 100)")
