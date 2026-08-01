#!/usr/bin/env python
"""REM-1 Gate B — register the six per-community three-arm FLOOR deficits for the two unzoned arms.

WHY THIS IS NOT A NEW ANALYTICAL DECISION. PIN 1 (T8 Gate B) already chose the aggregation:
area-weighted band mean over low/mid/high, weights = non-treed stratum area from
census_by_zone_stratum, with the regime_band='ALL' rollup RETIRED for the drier-skew confound and
the equal-weighted band mean recorded as the spread endpoint. Three of the nine arm x community
cells were pinned then (the not_grazed row, ref_grazed_floor_*). This script applies the SAME
method to the remaining six cells so that F6 (T6_A_three_arm_grid) does not display six
unregistered numbers alongside three pinned ones.

ADDITIVE ONLY. INSERT OR REPLACE keyed on number_id (never OR IGNORE - see CLAUDE.md). No existing
row deleted, no rename, no builder run. New run_id.

SELF-CHECK: the method is re-derived here for the three ALREADY-PINNED not_grazed cells and
asserted against their stored pinned_value. If the method did not reproduce the existing pins it
would not be the pinned method, and this script aborts before writing anything.
"""
import sqlite3, statistics as st, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from gayini_params import PIXEL_AREA_HA  # never hardcode  # noqa

PX = PIXEL_AREA_HA
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN_ID = "rem1_rerender_20260801"
DEC = ("PIN 1 method (T8 Gate B, build_T8_gateB_dim_headline_number.py) applied to the two unzoned "
       "arms; REM-1 Gate B; CC 2026-08-01")
NOTE = ("PIN 1: band mean retires the regime_band='ALL' rollup (drier-skew confound). Completes the "
        "3x3 arm x community grids drawn by T6_A_three_arm_grid (pack item F6, floor) and "
        "T6_B_three_arm_mean (mean cover); the three not_grazed cells of each were pinned at T8 "
        "Gate B and are reproduced EXACTLY by this method (asserted at build).")

ORD3 = ['Aeolian Chenopod Shrublands', 'Riverine Chenopod Shrublands',
        'Inland Floodplain Shrublands / Swamps']
SHORT = {'Aeolian Chenopod Shrublands': 'aeolian', 'Riverine Chenopod Shrublands': 'riverine',
         'Inland Floodplain Shrublands / Swamps': 'inland'}
ARMS = [('unzoned_inferred_standard', 'unzoned_inferred'), ('unzoned_plot_confirmed', 'unzoned_plot')]
BANDS = ('low', 'mid', 'high')

con = sqlite3.connect(DB)
c = con.cursor()

AREA = {(cm, b): ha for cm, b, ha in c.execute(
    "SELECT community, regime_band, sum(area_ha) FROM census_by_zone_stratum "
    "WHERE treed_context_flag=0 AND regime_band IN ('low','mid','high') GROUP BY community, regime_band")}


def deficits(arm, col):
    return {(cm, b): v for cm, b, v in c.execute(
        f"SELECT community, regime_band, {col} FROM v_three_arm_gap_decomposition "
        "WHERE treatment_arm=? AND window='all' AND regime_band IN ('low','mid','high')", (arm,))}


def allrow(arm, cm, col):
    return c.execute(f"SELECT {col} FROM v_three_arm_gap_decomposition "
                     "WHERE treatment_arm=? AND window='all' AND regime_band='ALL' AND community=?",
                     (arm, cm)).fetchone()[0]


# (label column, new number_id stem, the ALREADY-PINNED not_grazed id stem, wording)
QUANTS = [("floor_deficit_pp", "three_arm_floor_deficit", "ref_grazed_floor", "floor"),
          ("mean_deficit_pp",  "three_arm_mean_deficit",  "ref_grazed_mean_cover", "MEAN cover")]


def keys(cm):
    return [(cm, b) for b in BANDS]


def wmean(d, ks):   # area-weighted - the PIN 1 aggregation
    return sum(d[k] * AREA[k] for k in ks) / sum(AREA[k] for k in ks)


def emean(d, ks):   # equal-weighted - the spread endpoint
    return st.mean([d[k] for k in ks])


# ---- SELF-CHECK: reproduce the six existing pins by the same method, or abort ----
print("self-check: re-deriving the ALREADY-PINNED not_grazed cells by this method")
bad = []
for col, _stem, pin_stem, word in QUANTS:
    d_ng = deficits('not_grazed', col)
    for cm in ORD3:
        got = round(wmean(d_ng, keys(cm)), 2)
        pinned = c.execute("SELECT pinned_value FROM dim_headline_number WHERE number_id=?",
                           (f"{pin_stem}_{SHORT[cm]}",)).fetchone()[0]
        ok = abs(got - pinned) < 0.005
        print(f"   {pin_stem}_{SHORT[cm]:<9} method={got:+7.2f}  pinned={pinned:+7.2f}  "
              f"{'MATCH' if ok else 'MISMATCH'}")
        if not ok:
            bad.append(f"{pin_stem}_{SHORT[cm]}")
if bad:
    con.close()
    raise SystemExit(f"ABORT: method does not reproduce existing pins for {bad}; nothing written.")

# ---- build the twelve new rows (6 floor for T6_A/F6, 6 mean for T6_B) ----
rows = []
for col, stem, _pin_stem, word in QUANTS:
  for arm, short in ARMS:
    d = deficits(arm, col)
    for cm in ORD3:
        ks = keys(cm)
        aw, ew, ar = wmean(d, ks), emean(d, ks), allrow(arm, cm, col)
        rows.append((
            f"{stem}_{short}_{SHORT[cm]}",
            f"Three-arm {word} deficit vs 14-day, {short}, {SHORT[cm]}",
            "v_three_arm_gap_decomposition",
            "community (area-weighted band mean)",
            "area-weighted mean over 3 wetness bands",
            "mean_of_seasons",
            f"treatment_arm='{arm}', window='all', regime_band<>'ALL'",
            "all",
            "stratum area (non-treed)",
            PX,
            round(aw, 2), round(min(ew, ar), 2), round(max(ew, ar), 2),
            "stratum",
            f"deck used regime_band='ALL' rollup ({ar:+.1f}); equal-weighted band mean {ew:+.1f}.",
            DEC, NOTE))

c.executemany(
    "INSERT OR REPLACE INTO dim_headline_number (number_id,label,source_object,grain,"
    "aggregation_order,series_variant,scope_filter,period_label,denominator,pixel_constant,"
    "pinned_value,spread_min,spread_max,support_level,caveat,decided_by,decision_note) "
    "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)

c.execute("INSERT OR REPLACE INTO workflow_run (run_id,run_datetime,script_name,parameters_json,"
          "is_current,qa_status) VALUES (?,?,?,?,?,?)",
          (RUN_ID, "2026-08-01T00:00:00+00:00",
           "scripts/11_database/register_REM1_three_arm_community_pins.py",
           '{"gate": "REM-1 Gate B", "method": "PIN1 area-weighted band mean", '
           '"self_check": "three not_grazed pins reproduced exactly"}', 1, "REVIEW"))
con.commit()

print(f"\nregistered {len(rows)} rows, run_id={RUN_ID}")
for r in rows:
    print(f"   {r[0]:<52} pinned={r[10]:+7.2f}  spread=[{r[11]:+.2f},{r[12]:+.2f}]")
print("\ndim_headline_number total:",
      c.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0])
con.close()
