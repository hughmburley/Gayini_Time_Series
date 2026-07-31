#!/usr/bin/env python
"""T13 Gate E — register and bundle.

Additive only:
  1. fact_zone_community_part_classification (115 parts: both continuous measures, the state
     at every swept cut, the robustness state, the Ruling-4 split, the marginal flag)
  2. dim_headline_number rows for the four registered counts, sweep range as spread, PLUS the
     two Ruling-4 sub-counts
  3. workflow_run row

INSERT OR REPLACE throughout - never OR IGNORE (that looks idempotent but never updates a
changed value, so "re-run twice, identical" passes while the DB is wrong).

NOT registered, deliberately: the two part-polygon gpkgs. `spatial_layer_asset` is an IMPORT
registry - it records layers read IN from Input/. Both gpkgs are BUILD OUTPUTS derived from the
census, so a row there would be the same category error as registering the Gayini_Results.gpkg
management_zones companion. Flagged in the Gate E report rather than forced.

No builder run. No existing object modified. No p-values.
"""
import sqlite3, csv, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB   = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TAB  = ROOT / "Output" / "tables"
RUN  = "T13_gateE"
CUTS = ["0.50", "0.75", "1.00", "1.25", "1.50"]
STATES = ["Recovering", "Persistently poor", "Declining", "Unremarkable"]

cls = list(csv.DictReader(open(TAB / "T13_gateC_classification.csv", encoding="utf-8")))
rob = {(int(r["zone_fid"]), r["community"]): r
       for r in csv.DictReader(open(TAB / "T13_gateC_robustness.csv", encoding="utf-8"))}
sweep = {r["cut"]: r for r in csv.DictReader(open(TAB / "T13_gateC_sweep.csv", encoding="utf-8"))}
assert len(cls) == 115, len(cls)

BAND, CUT = 0.15, 1.0
def dist_to_cut(lz, tz):
    """Distance to an ACTIVE cut. level_z = +1.0 is NOT a cut (ruled 31 Jul); counting it
    would hatch parts whose state cannot change - a false claim of uncertainty."""
    return min(abs(lz + CUT), abs(tz + CUT), abs(tz - CUT))

con = sqlite3.connect(DB); c = con.cursor()

# ---------------------------------------------------------------- 1. the classification table
c.execute("""CREATE TABLE IF NOT EXISTS fact_zone_community_part_classification(
  zone_fid INTEGER, zone_name TEXT, community TEXT, n_years INTEGER,
  level REAL, level_z REAL, trend_raw REAL, water_slope REAL, trend_adj REAL, trend_z REAL,
  flood_sd REAL,
  state_registered TEXT, pp_split TEXT,
  state_cut_050 TEXT, state_cut_075 TEXT, state_cut_100 TEXT, state_cut_125 TEXT, state_cut_150 TEXT,
  state_drop2wettest TEXT, robustness_changed INTEGER,
  dist_to_nearest_cut REAL, marginal_flag INTEGER,
  assert_state INTEGER,
  cut_registered REAL, marginal_band REAL,
  support_level TEXT, aggregation_unit TEXT, run_id TEXT,
  PRIMARY KEY (zone_fid, community))""")

rows = []
for r in cls:
    k = (int(r["zone_fid"]), r["community"])
    lz, tz = float(r["level_z"]), float(r["trend_z"])
    d = dist_to_cut(lz, tz)
    changed = int(rob[k]["changed"])
    rows.append((int(r["zone_fid"]), r["zone_name"], r["community"], int(r["n_years"]),
                 float(r["level"]), lz, float(r["trend_raw"]), float(r["water_slope"]),
                 float(r["trend_adj"]), tz, float(r["flood_sd"]),
                 r["state_registered"], r["pp_split"] or None,
                 r["state_cut_0.50"], r["state_cut_0.75"], r["state_cut_1.00"],
                 r["state_cut_1.25"], r["state_cut_1.50"],
                 r["state_drop2wettest"], changed,
                 round(d, 4), int(d <= BAND or changed == 1),
                 # assert_state (ruled 31 Jul): the map does not assert a state where a part is
                 # BOTH inside the marginal band AND changes state under the robustness run.
                 # A CRITERION, not a named part - naming one part was the ad-hoc-threshold
                 # problem this task exists to avoid, appearing in a ruling instead of a cut.
                 # This governs what the MAP asserts, NOT what the data says: nothing is
                 # reclassified, state_registered is untouched, the registered counts stand.
                 int(not (d <= BAND and changed == 1)),
                 CUT, BAND, "pixel", "zone_community", RUN))
c.executemany("INSERT OR REPLACE INTO fact_zone_community_part_classification VALUES ("
              + ",".join("?" * 28) + ")", rows)
print(f"fact_zone_community_part_classification: {len(rows)} rows")

# ---------------------------------------------------------------- 2. dim_headline_number
DECIDED = ("T13 Gate C/D (docs/reference_update/Gayini_T13_spec.md v1 sections 5-6); "
           "CC 2026-07-30/31; cut PRE-REGISTERED before any result was seen")
NOTE = ("Pre-registered +/-1.0 on both community-scaled z-scores; NO threshold moved after the "
        "result. spread = the 0.50-1.50 sweep range (section 5). The recovering set is strictly "
        "NESTED across the sweep: the cut governs how many parts, not which. Quote with the range, "
        "never bare. The abandoned design-seat pilot (8pp/0.25pp/yr) is not reconciled to.")
CAVEAT = ("Count is cut-dependent; membership is not. z is scaled to each community's own SD, so "
          "z=-1.0 is ~12pp of ground in Aeolian/Riverine but ~6pp in Inland. 12 of 115 parts change "
          "state when the two wettest water years (2022, 2016) are dropped. States are a LABELLING "
          "of continuous measures, not categories in the data. No cause attributed.")

def hn(nid, label, pinned, smin, smax, extra=""):
    c.execute("INSERT OR REPLACE INTO dim_headline_number(number_id,label,source_object,grain,"
              "aggregation_order,series_variant,scope_filter,period_label,denominator,"
              "pixel_constant,pinned_value,spread_min,spread_max,support_level,caveat,"
              "decided_by,decision_note) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
              (nid, label, "fact_zone_community_part_classification", "zone_community",
               "count of parts at the registered cut", "mean_of_seasons",
               "115 supported parts (>=25 yr, n_pixels_valid>=30); non-treed in-scope census pixels",
               "1988-2022", "115 parts", None, float(pinned), float(smin), float(smax),
               "pixel", CAVEAT + (" " + extra if extra else ""), DECIDED, NOTE))

reg = sweep["1.00"]
for s, nid in [("Recovering", "t13_parts_recovering_count"),
               ("Persistently poor", "t13_parts_persistently_poor_count"),
               ("Declining", "t13_parts_declining_count"),
               ("Unremarkable", "t13_parts_unremarkable_count")]:
    vals = [int(sweep[cc][s]) for cc in CUTS]
    hn(nid, f"Paddock parts classified {s} at the pre-registered +/-1.0 cut",
       int(reg[s]), min(vals), max(vals))
    print(f"  {nid:40} {int(reg[s]):3d}  spread {min(vals)}-{max(vals)}")

for col, nid, lab, extra in [
    ("pp_low_and_flat", "t13_parts_low_and_flat_count", "low and flat",
     "Ruling-4 sub-division of Persistently poor: additive labelling, no threshold or membership change."),
    ("pp_low_and_falling", "t13_parts_low_and_falling_count", "low and falling",
     "Ruling-4 sub-division of Persistently poor: additive labelling, no threshold or membership "
     "change. 'Persistently poor' implies static; these parts are not.")]:
    vals = [int(sweep[cc][col]) for cc in CUTS]
    hn(nid, f"Paddock parts {lab} (Persistently poor split by trend_z)",
       int(reg[col]), min(vals), max(vals), extra)
    print(f"  {nid:40} {int(reg[col]):3d}  spread {min(vals)}-{max(vals)}")

# ---------------------------------------------------------------- 3. workflow_run
c.execute("INSERT OR REPLACE INTO workflow_run(run_id,run_datetime,script_name,repo_commit,"
          "parameters_json,is_current,qa_status) VALUES (?,?,?,?,?,?,?)",
          (RUN, "2026-07-31T00:00:00+00:00", "scripts/11_database/register_T13_gateE.py", None,
           json.dumps({"gate": "E", "spec": "docs/reference_update/Gayini_T13_spec.md",
                       "cut": CUT, "sweep": CUTS, "marginal_band": BAND,
                       "band_boundary_set": "three active cuts; level_z=+1.0 is NOT a cut",
                       "dropped_wettest_years": [2016, 2022]}), 1, "REVIEW"))

con.commit()

# ---------------------------------------------------------------- verification (independent re-read)
n = c.execute("SELECT COUNT(*) FROM fact_zone_community_part_classification").fetchone()[0]
print(f"\nverify: table {n} rows")
assert n == 115
got = dict(c.execute("SELECT state_registered,COUNT(*) FROM "
                     "fact_zone_community_part_classification GROUP BY 1"))
print("verify: state counts from the TABLE:", got)
assert got == {"Recovering": 8, "Persistently poor": 14, "Declining": 16, "Unremarkable": 77}, got
sp = dict(c.execute("SELECT pp_split,COUNT(*) FROM fact_zone_community_part_classification "
                    "WHERE pp_split IS NOT NULL GROUP BY 1"))
print("verify: Ruling-4 split from the TABLE:", sp)
assert sp == {"low and flat": 10, "low and falling": 4}, sp
mg = c.execute("SELECT COUNT(*) FROM fact_zone_community_part_classification "
               "WHERE marginal_flag=1").fetchone()[0]
print(f"verify: marginal (band {BAND} on the three real cuts, union movers): {mg}")
assert mg == 23, mg
na = c.execute("SELECT COUNT(*) FROM fact_zone_community_part_classification "
               "WHERE assert_state=0").fetchone()[0]
print(f"verify: state NOT asserted (in band AND a mover): {na}")
assert na == 9, na
ra = dict(c.execute("SELECT assert_state,COUNT(*) FROM fact_zone_community_part_classification "
                    "WHERE state_registered='Recovering' GROUP BY 1"))
print(f"verify: Recovering 8 meet the criterion; asserted {ra.get(1,0)}, not asserted {ra.get(0,0)}")
assert ra == {1: 5, 0: 3}, ra
# the 3 parts recovering at EVERY swept cut must all survive the assertion rule
core_na = c.execute(
    "SELECT COUNT(*) FROM fact_zone_community_part_classification WHERE assert_state=0 AND "
    "state_cut_050='Recovering' AND state_cut_075='Recovering' AND state_cut_100='Recovering' "
    "AND state_cut_125='Recovering' AND state_cut_150='Recovering'").fetchone()[0]
print(f"verify: core parts (recovering at every cut) that are NOT asserted: {core_na} (expect 0)")
assert core_na == 0, core_na
print("verify: dim_headline_number T13 rows:",
      c.execute("SELECT COUNT(*) FROM dim_headline_number WHERE number_id LIKE 't13_%'").fetchone()[0])
print("verify: dim_headline_number total:",
      c.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0])
con.close()
print("\nAdditive only: one new table, 6 new dim_headline_number rows, 1 workflow_run row.")
print("No builder run, no existing object modified, no p-values.")
print("Part-polygon gpkgs deliberately NOT in spatial_layer_asset (import registry; these are build outputs).")
