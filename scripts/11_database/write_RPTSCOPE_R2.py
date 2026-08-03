#!/usr/bin/env python
"""RPT-SCOPE Gate R2 — THE WRITE. One transaction.

10 pins (the 4 veg_p05_mean rows withdrawn per Ruling A, route 3) + 2 table_asset rows.
Probes immediately before and after; ABORTS on any movement in the two target tables.
Ruling C: pixel_constant carries a sentinel, never a blank.
"""
import sqlite3, csv, os, datetime, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TAB = ROOT / "Output" / "tables"
RUN = "RPTSCOPE_R2_20260803"
SENTINEL = "n/a - no pixel-to-area conversion in this quantity"
EXPECT = {"dim_headline_number": 88, "table_asset": 2}

def probe(label):
    c = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); c.execute("PRAGMA query_only=1")
    cur = c.cursor()
    out = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
           for t in ("dim_headline_number", "figure_asset", "raster_asset", "table_asset", "report_asset")}
    out["db_mtime"] = str(datetime.datetime.fromtimestamp(os.path.getmtime(DB)))
    c.close()
    print(f"  PROBE {label}: " + " · ".join(f"{k}={v}" for k, v in out.items()))
    return out

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

print("=== PRE-WRITE PROBE ===")
pre = probe("before")
for t, e in EXPECT.items():
    if pre[t] != e:
        raise SystemExit(f"ABORT: {t} is {pre[t]}, expected {e}. Another writer has moved it.")
print("  target tables at 88 and 2 as expected - proceeding\n")

# ---------------------------------------------------------------- the pins
pins = [r for r in csv.DictReader(open(TAB / "RPTSCOPE_R2_pin_list.csv", encoding="utf-8"))
        if not r["blocked"]]
assert len(pins) == 10, len(pins)

DECIDED = ("RPT-SCOPE Gate R2, design seat 3 Aug 2026; built by CC. "
           "docs/change_reports/RPTSCOPE_R2_pinlist_STOP.md")

con = sqlite3.connect(DB); c = con.cursor()
existing = {r[0] for r in c.execute("SELECT number_id FROM dim_headline_number")}
dupes = [p["number_id"] for p in pins if p["number_id"] in existing]
if dupes:
    con.close(); raise SystemExit(f"ABORT: would duplicate existing number_id(s): {dupes}")

try:
    con.execute("BEGIN")
    for p in pins:
        pixconst = p["pixel_constant"].strip() or SENTINEL
        note = (f"Derivation: {p['derivation_route']} | independent={p['independent']} | "
                f"aggregation_order stated in scope_filter. Registered at R2 with all five "
                f"qualifiers populated; absent qualifiers carry a sentinel, never a blank.")
        c.execute(
            "INSERT INTO dim_headline_number(number_id,label,source_object,grain,aggregation_order,"
            "series_variant,scope_filter,period_label,denominator,pixel_constant,pinned_value,"
            "spread_min,spread_max,support_level,caveat,decided_by,decision_note) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (p["number_id"], p["quantity"][:200], p["source_object"], p["support_level"],
             "stated in scope_filter (I-38: aggregation order is not recoverable from the value)",
             "mean_of_seasons", p["scope_filter"], p["period_label"], p["denominator"],
             pixconst,
             float(p["pinned_value"]),
             float(p["spread_min"]) if p["spread_min"] else None,
             float(p["spread_max"]) if p["spread_max"] else None,
             p["support_level"],
             ("NO INDEPENDENT DERIVATION - counts as NO_DERIVATION_PATH in the reproduction test; "
              "declared rather than manufactured (Ruling D2)." if p["independent"] == "N"
              else "Independent derivation recorded in decision_note."),
             DECIDED, note))
    print(f"  inserted {len(pins)} pins")

    # ------------------------------------------------------------ number contract
    contract = []
    def add(page, panel, nid, src, scope, denom, pixconst, support, period):
        contract.append(dict(page=page, panel=panel, number_id=nid, source_object=src,
                             scope_filter=scope, denominator=denom, pixel_constant=pixconst,
                             support_level=support, period_label=period))
    NT = "treed_context_flag = 0 AND regime_band <> 'context'"
    add(1, "cover headline", "UNPINNED", "fact_zone_veg_annual.veg_p05_spatial",
        f"the report's own paddock; {NT}", "1 paddock", SENTINEL, "zone", "1988-2022")
    add(1, "scope lock footer", "UNPINNED", "(text constant)", "non-treed, whole paddock, full record",
        "n/a", SENTINEL, "n/a", "1988-2022")
    add(2, "flood frequency", "UNPINNED", "fact_zone_veg_annual.flood_frac_pct",
        f"the report's own paddock; {NT}", "35 water years", SENTINEL, "zone", "1988-2022")
    add(3, "community composition", "UNPINNED", "v_zone_community_composition.share_a",
        "denominator A, all classes", "paddock pixel count", "0.062351428", "pixel", "1988-2023 census")
    add(4, "expectation line intercept", "floor_flood_intercept_64pdk", "dim_headline_number",
        f"64 paddocks; {NT}", "64 paddocks", SENTINEL, "zone", "1988-2022")
    add(4, "expectation line slope", "floor_flood_slope_64pdk", "dim_headline_number",
        f"64 paddocks; {NT}", "64 paddocks", SENTINEL, "zone", "1988-2022")
    add(4, "typical miss band", "floor_flood_residual_sd_64pdk", "dim_headline_number",
        f"64 paddocks; {NT}", "64 paddocks", SENTINEL, "zone", "1988-2022")
    add(4, "this paddock's residual", "UNPINNED", "v_zone_floor_flood_residual.residual",
        "the report's own paddock", "64 paddocks", SENTINEL, "zone", "1988-2022")
    add(4, "reference context - the gap", "ref_grazed_gap_annual_ref3_excl29ca_mean",
        "dim_headline_number", "26ca/27ca/28ca vs median of 60 grazed; NOT the plot-network three",
        "35 water years", SENTINEL, "zone", "1988-2022")
    add(5, "part states", "UNPINNED", "fact_zone_community_part_classification.state_registered",
        "the report's own paddock's parts", "115 supported parts", "0.062351428", "pixel", "1988-2022")
    add(5, "recovering count context", "t13_parts_recovering_count", "dim_headline_number",
        "115 supported parts", "115 parts", "0.062351428", "pixel", "1988-2022")
    add(5, "survives drop-two", "t13_recovering_survive_drop2wettest", "dim_headline_number",
        "115 supported parts; drop WY2022 and WY2016", "8 recovering parts", "0.062351428",
        "pixel", "1988-2022")
    cpath = TAB / "RPTSCOPE_number_contract.csv"
    with open(cpath, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(contract[0].keys())); w.writeheader(); w.writerows(contract)
    n_unpinned = sum(1 for r in contract if r["number_id"] == "UNPINNED")
    print(f"  number contract: {len(contract)} rows, {n_unpinned} UNPINNED (the design-seat handoff)")

    # ------------------------------------------------------------ table_asset
    for tid, path, title, prod, nrows in (
            ("table_rptscope_claim_audit", "Output/tables/RPTSCOPE_claim_audit.csv",
             "RPT-SCOPE claim audit - every register-v3 claim and By_question cell resolved", "claim_audit", 22),
            ("table_rptscope_number_contract", "Output/tables/RPTSCOPE_number_contract.csv",
             "RPT-SCOPE number contract - every number report pages 1-5 may draw", "number_contract", len(contract))):
        p = ROOT / path
        c.execute("INSERT OR REPLACE INTO table_asset(table_asset_id,path,title,product,n_rows,"
                  "checksum_sha256,path_exists,qa_status,run_id,superseded_flag,framing_label,"
                  "provenance_note,support_level) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                  (tid, path, title, prod, nrows, sha(p), 1, "REVIEW", RUN, 0, "census_8058",
                   "RPT-SCOPE Gate R2. The claim audit is the provenance record for every SOURCED "
                   "claim not pinned, including the four withdrawn under Ruling A route 3.", "mixed"))
    print("  registered 2 table_asset rows")

    c.execute("INSERT OR REPLACE INTO workflow_run(run_id,run_datetime,script_name,repo_commit,"
              "parameters_json,is_current,qa_status) VALUES (?,?,?,?,?,?,?)",
              (RUN, "2026-08-03T00:00:00+00:00", "scripts/11_database/write_RPTSCOPE_R2.py", None,
               '{"gate":"R2","pins":10,"withdrawn":4,"rule":"Ruling A route 3"}', 1, "REVIEW"))
    con.commit()
    print("  COMMIT")
except Exception as e:
    con.rollback(); con.close(); raise SystemExit(f"ROLLED BACK: {e}")

# ---------------------------------------------------------------- verify
n_hn = c.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
n_ta = c.execute("SELECT COUNT(*) FROM table_asset").fetchone()[0]
nulls = c.execute("SELECT COUNT(*) FROM dim_headline_number WHERE run_id IS NULL AND 1=0").fetchone()[0]
blanks = c.execute("SELECT COUNT(*) FROM dim_headline_number WHERE decided_by=? AND ("
                   "support_level IS NULL OR support_level='' OR scope_filter IS NULL OR scope_filter='' "
                   "OR pixel_constant IS NULL OR pixel_constant='' OR denominator IS NULL OR denominator='' "
                   "OR period_label IS NULL OR period_label='')", (DECIDED,)).fetchone()[0]
con.close()
print(f"\n=== VERIFY ===")
print(f"  dim_headline_number {pre['dim_headline_number']} -> {n_hn}  (expected 98)  {'OK' if n_hn==98 else '*** FAIL ***'}")
print(f"  table_asset         {pre['table_asset']} -> {n_ta}  (expected 4)   {'OK' if n_ta==4 else '*** FAIL ***'}")
print(f"  new rows with a NULL or blank in the five qualifiers: {blanks}  {'OK' if blanks==0 else '*** FAIL ***'}")
print("\n=== POST-WRITE PROBE ===")
post = probe("after")
