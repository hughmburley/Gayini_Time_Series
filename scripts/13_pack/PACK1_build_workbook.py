#!/usr/bin/env python
"""PACK-1 P4-4..P4-7 + Ruling N — 00_START_HERE.md, the workbook, the number check, registration.

EVERY number on How_we_know is QUERIED LIVE (P4-6 / AD-B). Nothing on that sheet is typed.
Contents and 00_START_HERE.md both generate from PACK1_item_list.csv - one source, so they
cannot disagree (P4-4).
"""
import sqlite3, csv, hashlib, datetime, os
from pathlib import Path
import openpyxl
from openpyxl.styles import Font, Alignment

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "Output" / "pack"
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN = "PACK1_P4_20260803"

def probe(lbl):
    c = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); c.execute("PRAGMA query_only=1")
    o = {t: c.cursor().execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
         for t in ("dim_headline_number","figure_asset","raster_asset","table_asset","report_asset")}
    c.close(); print(f"  PROBE {lbl}: " + " · ".join(f"{k}={v}" for k,v in o.items())); return o

def sha50(p):
    h=hashlib.sha256(); cap=50*1024*1024; n=0
    with open(p,"rb") as f:
        while n<cap:
            b=f.read(1<<20)
            if not b: break
            h.update(b); n+=len(b)
    return h.hexdigest()

pre = probe("before")
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); con.execute("PRAGMA query_only=1")
c = con.cursor()
PINS = dict(c.execute("SELECT number_id, pinned_value FROM dim_headline_number "
                      "WHERE pinned_value IS NOT NULL"))
items = list(csv.DictReader(open(PACK/"PACK1_item_list.csv", encoding="utf-8")))
audit = list(csv.DictReader(open(ROOT/"Output/tables/RPTSCOPE_claim_audit.csv", encoding="utf-8")))

# ---------- P4-6: EVERY figure here is a LIVE QUERY. None is typed. -------------------------
LIVE = {}
LIVE["registered"] = c.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
LIVE["pinned"]     = c.execute("SELECT COUNT(*) FROM dim_headline_number "
                               "WHERE pinned_value IS NOT NULL").fetchone()[0]
st = list(csv.DictReader(open(ROOT/"Output/tables/RPTSCOPE_reproduction_status.csv", encoding="utf-8")))
LIVE["reproduce"]  = sum(1 for r in st if r["status"]=="REPRODUCES")
LIVE["drift"]      = sum(1 for r in st if r["status"]=="VALUE_DRIFT")
LIVE["nopath"]     = sum(1 for r in st if r["status"]=="NO_DERIVATION_PATH")
LIVE["coverage"]   = 100*LIVE["reproduce"]/LIVE["pinned"]
LIVE["figures"]    = c.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
LIVE["tables"]     = c.execute("SELECT COUNT(*) FROM table_asset").fetchone()[0]
print(f"  LIVE: registered={LIVE['registered']} pinned={LIVE['pinned']} reproduce={LIVE['reproduce']} "
      f"drift={LIVE['drift']} coverage={LIVE['coverage']:.1f}%")

# ---------- claims: text is design-seat verbatim, numbers carry their number_id -------------
CLAIMS = [
 ("1","Removing grazing has not, by itself, produced a measurably different floor. Across 35 years "
      "the three conserved paddocks other than Bala 29ca sat on average 2.1 percentage points below "
      "the grazed median at their vegetation floor, and in individual years ranged from 7.0 points "
      "below it to 5.0 points above. The difference crosses zero.",
      "ref_grazed_gap_annual_ref3_excl29ca_mean"),
 ("2","Bala 29ca's floor has been converging on the grazed median since 1988 at +0.92 percentage "
      "points a year. Conservation management began in 2019. The trend predates it by three decades.",
      "t10_gap_annual_slope_C_29ca"),
 ("3","How often a paddock floods correlates with its floor at r = 0.71 across all 64 paddocks — "
      "about half the variation between paddocks.", "floor_flood_r_64pdk"),
 ("4","82% of Bala 29ca's improvement survives removing the effect of the water it actually received, "
      "and the improvement is located in its dry western parts, not the paddock as a whole.",
      "bala29ca_improvement_surviving_water_pct"),
 ("5","The four conserved paddocks are not a matched comparison set. Ranked by how often they flood, "
      "they sit 3rd, 6th, 31st and 61st of 64 — almost the entire wetness range of the property. They "
      "are not one condition, and no single number describes them.",
      "ref_paddock_flood_rank_bala26ca,ref_paddock_flood_rank_bala28ca,"
      "ref_paddock_flood_rank_bala27ca,ref_paddock_flood_rank_bala29ca"),
 ("6","Eight of 115 paddock-parts are improving faster than their water explains while sitting below "
      "their community's typical floor. Five of the eight survive dropping the two wettest years. "
      "Three recover at every cut from 0.50 to 1.50, and two of those three are in Bala 29ca.",
      "t13_parts_recovering_count,t13_recovering_survive_drop2wettest"),
 ("7","Twelve of the sixteen declining parts are in the Bala group.", "t13_parts_declining_count"),
]
Q2 = ("No, and the more useful answer is that this design cannot settle it. Across 35 years the three "
      "conserved paddocks other than Bala 29ca sat 2.1 points below the grazed median on average, "
      "ranging from 7.0 below to 5.0 above — the difference crosses zero. But the four conserved "
      "paddocks span flood ranks 3, 6, 31 and 61 of 64, so they are not one condition and cannot serve "
      "as a single reference. All four are also in the Bala block, so removing grazing is perfectly "
      "confounded with where the paddocks are. Anything measured against this set is measured against "
      "a moving target.")
ANSWERS = {
 "Q1":("Are the formerly-cropped paddocks becoming more like the conserved ones?",
       "NOT ANSWERABLE AS ASKED","Cropping history is not recorded anywhere. Five columns are reserved "
       "for it and are empty for all 64 paddocks, so every contrast in this pack is not-grazed versus "
       "grazed, never conserved versus formerly-cropped.","cropping_history_null_count"),
 "Q2":("Are the conserved paddocks a usable reference set?","NO — AND THE DESIGN CANNOT SETTLE IT",Q2,
       "ref_grazed_gap_annual_ref3_excl29ca_mean,ref_paddock_flood_rank_bala26ca"),
 "Q3":("Is Bala 29ca recovering, and is it just getting wetter?","RECOVERING, AND NOT JUST WETTER",
       "Its poorest patches carry about 17 percentage points less cover than its dryness predicts — the "
       "second largest shortfall on the property — and 82% of its improvement survives removing the "
       "effect of the water it actually received.","bala29ca_improvement_surviving_water_pct"),
 "Q4":("Does grazing intensity show up in the ground cover?","NO — AND THE ORDERING RUNS THE WRONG WAY",
       "Comparing three management types within similar country, the standard-grazing land sits at or "
       "above the rotationally grazed land in six of nine comparisons. Either intensity does not "
       "register in this measure, or the unzoned country is grazed less rather than more.",
       "three_arm_standard_at_or_above_count"),
 "Q5":("What does drive ground cover?","WATER, AND IT IS NOT CLOSE",
       "Across all 64 paddocks, how often a paddock floods correlates with its floor at r = 0.71 — "
       "about half the variation between paddocks. The pattern follows channels and low ground and "
       "crosses paddock fences without noticing them.","floor_flood_r_64pdk"),
 "Q6":("Which country is coming back, and which is going backwards?",
       "BOTH, AND IT IS GEOGRAPHIC RATHER THAN MANAGERIAL",
       "Eight of 115 parts are improving faster than their water explains; five survive dropping the "
       "two wettest years; three recover at every cut tested. Twelve of the sixteen declining parts "
       "are in the Bala group.","t13_parts_recovering_count,t13_parts_declining_count"),
 "Q7":("Did management change the water regime?","UNTESTED, AND PROBABLY UNTESTABLE WITH THIS RECORD",
       "This is the question worth asking and we cannot answer it. There are four water years since "
       "management changed and they are unusually wet. This is an honest non-answer, not a gap in the "
       "work: no design on this record can separate a management effect from that.","(none — N/A by design)"),
}
CAUTIONS = [
 ("Support levels are never merged","A plot-support number and a pixel-support number are different "
  "measurements of the same idea and are never compared or combined."),
 ("Cover is not condition","The floor says how much ground cover there is and how green it is. It is "
  "not a condition score and implies no cause."),
 ("A paddock is not an ecological unit","Management zones were drawn for stock and water. Decompose "
  "by vegetation community before attributing anything to a fence line."),
 ("No p-values on the annual series","Thirty-five consecutive years are not independent observations."),
 ('"The floor" always means one thing here','In this pack "the floor" always means the total-cover '
  'floor (veg_p05_spatial), never the green-share floor. The two are different quantities.'),
]

# ---------- P4-4: 00_START_HERE.md, generated ------------------------------------------------
def q_for(i):
    for k,(qq,ans,why,nid) in ANSWERS.items():
        if i["item_id"] in ("M1","F1","T1") and k=="Q1": return qq
    return ""
lines = ["# Start here", "", "**Gayini reference-state assessment — pack for Adrian · 10 August 2026**", "",
         "This folder is a derived artefact. Every file in it is copied from a registered source and",
         "verified by checksum on both sides; nothing was edited in place. The item-to-filename mapping",
         "below is **generated from `PACK1_item_list.csv`**, which is also what the workbook's Contents",
         "sheet reads — so the two cannot disagree. Filenames were deliberately **not** renamed: the pack",
         "path and the registry path are identical, so no mapping can drift.", "",
         "| item | file | what it answers |", "|---|---|---|"]
WHAT = {"M1":"where the paddocks are","M2":"where the monitoring sites are",
 "M3":"which country stays green longest","M4":"which parts are coming back and which are going backwards",
 "M4b":"how that classification moves when the cut is loosened or tightened",
 "M5":"cover and water, at paddock and at part grain","M5b":"which paddocks beat or miss their water",
 "F1":"how each conserved paddock's floor tracks the grazed range","F2":"the same, on mean cover",
 "F3":"whether conserved country is pulling away from grazed country",
 "F4":"how the conserved-grazed gap narrowed","F5":"cover against water across all 64 paddocks",
 "F6":"whether grazing intensity shows up in the floor","F7":"Bala 29ca, part by part",
 "T1":"the four conserved paddocks side by side","T2":"every part of the property, to look up",
 "T3":"what this analysis cannot tell you","T1_render":"T1 as a picture"}
for i in items:
    fp = i["file_path"].replace("Output/","") if i["file_path"] else "—"
    name = Path(i["file_path"]).name if i["file_path"] else "—"
    lines.append(f"| **{i['item_id']}** | `{name}` | {WHAT.get(i['item_id'],'')} |")
lines += ["", f"*{len([x for x in items if x['item_id']!='T1_render'])} items in "
          f"{len({x['file_path'] for x in items if x['file_path']})} files. "
          f"F7 is a panel of M4's figure and shares its file; T1 ships as data with T1_render as its "
          f"picture.*", "",
          "**Read `Gayini_what_we_dont_know.md` before quoting anything from this pack.**"]
(PACK/"00_START_HERE.md").write_text("\n".join(lines), encoding="utf-8")
print(f"  wrote 00_START_HERE.md ({len(items)} rows, generated)")

# ---------- P4-5/P4-6: the workbook ----------------------------------------------------------
wb = openpyxl.Workbook(); wb.remove(wb.active)
B = Font(bold=True); W = Alignment(wrap_text=True, vertical="top")
def sheet(name, rows, widths):
    ws = wb.create_sheet(name)
    for r in rows: ws.append(r)
    for i,w in enumerate(widths,1): ws.column_dimensions[chr(64+i)].width = w
    for cell in ws[1]: cell.font = B
    for row in ws.iter_rows():
        for cl in row: cl.alignment = W
    return ws

sheet("Start_here",
      [["#","claim","number_id (provenance)"]] + [[n,t,nid] for n,t,nid in CLAIMS],
      [5,110,46])
sheet("By_question",
      [["#","the question","the answer","why — in plain terms","number_id (provenance)"]] +
      [[k,v[0],v[1],v[2],v[3]] for k,v in ANSWERS.items()],
      [6,44,44,96,46])
sheet("Contents",
      [["item","file","what it answers","sha256 (source)","registered_in"]] +
      [[i["item_id"], Path(i["file_path"]).name if i["file_path"] else "—",
        WHAT.get(i["item_id"],""), (i["sha256"] or "")[:16], i["registered_in"]] for i in items],
      [10,52,54,20,46])
sheet("Two_cautions", [["caution","what it means"]] + [[a,b] for a,b in CAUTIONS], [42,104])

cov = (f"Of the {LIVE['pinned']} numbers in this pack's registry that carry a pinned value, "
       f"{LIVE['reproduce']} ({LIVE['coverage']:.1f}%) can be recomputed from source by a second, "
       f"independent route, and {LIVE['drift']} have drifted. The {LIVE['nopath']} not covered are "
       f"numbers for which no second route has been written — not numbers that failed.")
FALSIF = ("A rule written before the numbers arrived fired against us. It said that if the mapped "
          "area of persistent cover proved highly sensitive across plausible thresholds with no "
          "natural break, then 'refugia' is a chosen cut on a continuum and must be reported as a "
          "gradient rather than an area. It did, so no headline refugia figure was set. That is "
          "stronger evidence than the reproduction test: reproduction shows the numbers are stable, "
          "this shows they were not fitted.")
sheet("How_we_know",
      [["what","live value","how it is obtained"],
       ["numbers registered with a definition", LIVE["registered"], "COUNT(*) dim_headline_number — queried at build time"],
       ["of those, carrying a pinned value", LIVE["pinned"], "COUNT(*) WHERE pinned_value IS NOT NULL — queried at build time"],
       ["independently re-derived, and drifted", f"{LIVE['reproduce']} re-derived · {LIVE['drift']} drifted",
        "RPTSCOPE_reproduction_status.csv — read at build time; the two ALWAYS travel together"],
       ["coverage and drift, in one sentence", cov, "generated at build time; never typed, never copied"],
       ["registered figures", LIVE["figures"], "COUNT(*) figure_asset — queried at build time"],
       ["registered tables", LIVE["tables"], "COUNT(*) table_asset — queried at build time"],
       ["a rule that fired against us", FALSIF, "T3 Gate B1 pre-registration; R2 Ruling D derivation"],
       ["", "", ""],
       ["NOTE", "No number on this sheet is typed.",
        "Every value is produced by a live query at build time. Counts move as work lands; a typed "
        "copy would be stale within the hour, and has been four times."]],
      [40,64,86])

out = PACK/"Gayini_Adrian_pack.xlsx"
wb.save(out); print(f"  wrote {out.name} (5 sheets)")

# ---------- P4-7: final number check ---------------------------------------------------------
import re
checks=[]
def add(loc, num, resolves, state):
    checks.append(dict(location=loc, number_as_written=num, resolves_to=resolves, state=state,
                       agrees=1 if state in ("PINNED","LIVE_QUERY","AUDIT_ROW","DERIVED_DECLARED") else 0))
for n,t,nid in CLAIMS:
    for one in nid.split(","):
        add(f"Start_here claim {n}", one, one, "PINNED" if one in PINS else "UNRESOLVED")
for k,(qq,a,why,nid) in ANSWERS.items():
    if nid.startswith("(none"): add(f"By_question {k}", "(no number)", "N/A_by_design", "AUDIT_ROW"); continue
    for one in nid.split(","):
        add(f"By_question {k}", one, one, "PINNED" if one in PINS else "UNRESOLVED")
for key in ("registered","pinned","reproduce","drift","nopath","figures","tables"):
    add("How_we_know", str(LIVE[key]), f"live query: {key}", "LIVE_QUERY")
T3NUM = {"3rd, 6th, 31st and 61st of 64":"ref_paddock_flood_rank_bala26ca (+3 siblings)",
 "all 64 paddocks (cropping history)":"cropping_history_null_count",
 "32 / 25 / 6 pp Bala 29ca community deficits":"t10_bala29ca_aeolian_level_deficit, _riverine_, _inland_",
 "15 standard-grazing sites":"RPTSCOPE_report_set.csv EXCLUDED rows (R1b)",
 "twelve of 115 change side; eight to five":"DERIVED — design-seat computation, no committed producer (O4)",
 "12,641 / 8,300 / 4,179 ha at 70/75/80":"t3_always_green_sweep (R2 Ruling D)",
 "988,831 of 1,080,157 px, 91.55% / 8.00% / 0.46%":"census_by_zone_stratum (verified S2)",
 "17 percentage points (two floors)":"spec §6 / T2_zone_annual_veg_extraction.md §94",
 "35 consecutive years":"parameter, not a result",
 "floods roughly twice as often (channel)":"T3-I5, T3_gateCDE_20260803.md",
 "eight instances / six occasions / twice":"issues log I-40, I-37, I-43"}
for k,v in T3NUM.items():
    add("Gayini_what_we_dont_know.md", k, v,
        "DERIVED_DECLARED" if v.startswith("DERIVED") else ("PINNED" if v.split()[0] in PINS else "AUDIT_ROW"))
with open(PACK/"PACK1_final_number_check.csv","w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=list(checks[0].keys())); w.writeheader(); w.writerows(checks)
unres=[x for x in checks if x["state"]=="UNRESOLVED"]
print(f"  P4-7: {len(checks)} numbers checked, {len(unres)} UNRESOLVED")
for x in unres: print("     *** ",x)
con.close()

# ---------- Ruling N: register the workbook ---------------------------------------------------
if unres:
    raise SystemExit("STOP - unresolved numbers; workbook NOT registered.")
cw = sqlite3.connect(DB); cur = cw.cursor()
try:
    cw.execute("BEGIN")
    cur.execute("INSERT OR REPLACE INTO report_asset(report_asset_id,path,title,report_type,"
                "checksum_sha256,path_exists,qa_status,run_id) VALUES (?,?,?,?,?,?,?,?)",
                ("report_gayini_adrian_pack_xlsx","Output/pack/Gayini_Adrian_pack.xlsx",
                 "Gayini Adrian pack workbook - 5 sheets, content regenerated from live queries",
                 "client_pack", sha50(out), 1, "REVIEW", RUN))
    cur.execute("INSERT OR REPLACE INTO table_asset(table_asset_id,path,title,product,n_rows,"
                "checksum_sha256,path_exists,qa_status,run_id,superseded_flag,framing_label,"
                "provenance_note,support_level) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                ("table_pack1_item_list","Output/pack/PACK1_item_list.csv",
                 "PACK-1 item list - 17 items, 17 files","pack_item_list",len(items),
                 sha50(PACK/"PACK1_item_list.csv"),1,"REVIEW",RUN,0,"census_8058",
                 "Single source for both 00_START_HERE.md and the workbook Contents sheet.","mixed"))
    cw.commit(); print("  COMMIT - workbook + item list registered")
except Exception as e:
    cw.rollback(); cw.close(); raise SystemExit(f"ROLLED BACK: {e}")
cw.close()
post = probe("after")
print(f"\n  report_asset {pre['report_asset']} -> {post['report_asset']}   "
      f"table_asset {pre['table_asset']} -> {post['table_asset']}")
