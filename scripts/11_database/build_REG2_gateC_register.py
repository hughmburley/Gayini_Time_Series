#!/usr/bin/env python
"""REG-2 Gate C — register the dominance counts (denominator A pinned, B/C in the spread) and
the n_parts_supported distribution. ADDITIVE: INSERT OR REPLACE. Ruling 1: dominance registered
LITERALLY (no threshold); the report batch branches page 3 on n_parts_supported, not dominance.
Ruling 2: denom-B <75 count is 16, with the 17th-paddock finding recorded. Values computed live."""
import sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
import sys; sys.path.insert(0,str(ROOT/"scripts"/"lib"))
from gayini_params import PIXEL_AREA_HA  # noqa
con=sqlite3.connect(DB); c=con.cursor()

def dcount(dd,cond):
    return c.execute(f"SELECT COUNT(*) FROM (SELECT zone_fid, MAX(dominance_{dd}) dm, MAX(CASE WHEN dominance_class_{dd}='single' THEN 1 ELSE 0 END) sg FROM v_zone_community_composition GROUP BY zone_fid) WHERE {cond}").fetchone()[0]
lt75={d:dcount(d,"dm<75") for d in ('a','b','c')}
lt60={d:dcount(d,"dm<60") for d in ('a','b','c')}
single={d:dcount(d,"sg=1") for d in ('a','b','c')}
parts=dict(c.execute("SELECT n_parts_supported, COUNT(*) FROM (SELECT zone_fid, MAX(n_parts_supported) n_parts_supported FROM v_zone_community_composition GROUP BY zone_fid) GROUP BY n_parts_supported").fetchall())
print("lt75",lt75,"lt60",lt60,"single",single,"parts",parts)

DEC="REG-2 Gate C (Gayini_REG1_REG2_spec.md); design-seat rulings 1 & 2, 29 Jul; CC"
DENOM_NOTE=("Denominator A (focus-3 non-treed) for ANALYSIS - every RS number is on this scope. "
            "Denominator C (whole paddock) for CLIENT TEXT - shares that sum to the whole paddock "
            "are more honest than shares renormalised onto the analysed subset. Recommendation, not enforced; the view gives all three.")
rows=[
 ("reg2_paddocks_lt75_dominance","Paddocks below 75% single-community dominance","v_zone_community_composition",
  "paddock","count of paddocks with max community share < 75%","n/a","denominator A (treed_context_flag=0 AND regime_band<>'context')","n/a","64 paddocks",PIXEL_AREA_HA,
  float(lt75['a']),float(min(lt75.values())),float(max(lt75.values())),"paddock",
  f"A={lt75['a']}, B (all non-treed)={lt75['b']}, C (whole paddock)={lt75['c']}. "
  f"RECONCILIATION: the report stream reported 17; their two named paddocks (Bala 1, Mara 5a) reconcile our 14 to B={lt75['b']} exactly; the seventeenth could not be reproduced from any denominator or boundary rule. Counts not adjusted.",
  DEC,DENOM_NOTE),
 ("reg2_paddocks_lt60_dominance","Paddocks below 60% single-community dominance","v_zone_community_composition",
  "paddock","count of paddocks with max community share < 60%","n/a","denominator A","n/a","64 paddocks",PIXEL_AREA_HA,
  float(lt60['a']),float(min(lt60.values())),float(max(lt60.values())),"paddock",
  f"A={lt60['a']}, B={lt60['b']}, C={lt60['c']}. The L-01 'genuinely mixed' threshold.",DEC,DENOM_NOTE),
 ("reg2_paddocks_single_community","Single-community paddocks (literal: exactly one focus-3 community)","v_zone_community_composition",
  "paddock","count of paddocks with exactly one community present","n/a","denominator A","n/a","64 paddocks",PIXEL_AREA_HA,
  float(single['a']),float(min(single.values())),float(max(single.values())),"paddock",
  f"A={single['a']}, B={single['b']}, C={single['c']}. LITERAL definition, no threshold (thresholds chosen after seeing data are the project's recurring defect). The sole literal-vs-99.9% disagreement is Mara 3: minor share 0.019% = ONE pixel of Aeolian, a mapping edge effect; no threshold adopted deliberately.",
  DEC,"Descriptive only. The report batch must branch page 3 on n_parts_supported, NOT on dominance."),
]
for np_,cnt in ((1,parts.get(1,0)),(2,parts.get(2,0)),(3,parts.get(3,0))):
    rows.append((f"reg2_paddocks_{np_}part_supported",f"Paddocks with {np_} supported community part(s)","fact_zone_community_part_summary",
      "paddock","count of paddocks with N parts meeting the support rule","mean_of_seasons",
      "n_pixels_valid>=30 in >=25 years","1988-2022","64 paddocks",PIXEL_AREA_HA,
      float(cnt),float(cnt),float(cnt),"paddock",
      f"Distribution 27/23/14 across 64 paddocks, 115 parts total. Already-defined support (not a new cut).",
      DEC,"OPERATIONAL: the report batch branches page 3 on n_parts_supported (1 part = single line; 2-3 = expanded parts). Mara 3 has 1 supported part -> single line, whichever dominance definition is used."))

c.executemany("""INSERT OR REPLACE INTO dim_headline_number
 (number_id,label,source_object,grain,aggregation_order,series_variant,scope_filter,period_label,
  denominator,pixel_constant,pinned_value,spread_min,spread_max,support_level,caveat,decided_by,decision_note)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
con.commit()
print("registered REG-2 rows:",c.execute("SELECT number_id,pinned_value,spread_min,spread_max FROM dim_headline_number WHERE number_id LIKE 'reg2_%' ORDER BY number_id").fetchall())
print("dim_headline_number rows now:",c.execute("SELECT count(*) FROM dim_headline_number").fetchone()[0])
con.close(); print("DONE")
