#!/usr/bin/env python3
"""FIG-2 section 1.2 - register the three weighted R-squared values. APPROVED 7 Aug 2026.

They appear on a deliverable figure, so the five-qualifier rule applies. Each row states
that it is WEIGHTED and records the estimand as BETWEEN-UNIT, because an unqualified R2
invites a reader to recompute it unweighted and find a different number, and because the
within-unit R2 (0.17) is a different quantity across a different estimand.

NOT REFITTED. Each is r-squared of the STORED r in the coefficient tables, confirmed
equal to four decimals before writing. The stored r is the pinned quantity; this is a
transformation of it, and the row says so.

INSERT OR REPLACE, never OR IGNORE.
"""
import csv, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
T = ROOT / "Output" / "tables"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
DECIDED = ("FIG-2 v2 section 1.2, docs/reference_update/Gayini_CC_spec_FIG2.md; approved at the "
           "design seat 7 Aug 2026; computed and checked in Python by CC, not refitted")
SCOPE = ("115 supported paddock x community parts, the common set; treed_context_flag=0 AND "
         "regime_band<>'context'")

F = {r["fit_id"]: r for r in
     list(csv.DictReader(open(T / "PARTREG_part_regression_coefficients.csv", encoding="utf-8-sig")))
     + list(csv.DictReader(open(T / "PARTREG_S2_regression_coefficients.csv", encoding="utf-8-sig")))}

SPEC = [("cap_weighted_r2_whole_record", "2.3_weighted", "1988-2022", "whole record, 35 water years"),
        ("cap_weighted_r2_cropping_era", "S2_cropping_era_common", "1988-2013", "cropping era, 26 water years"),
        ("cap_weighted_r2_post_management", "S2_post_management_common", "2018-2022",
         "post-management, 5 water years")]

rows = []
for nid, fid, period, what in SPEC:
    r = float(F[fid]["r"]); r2 = r * r
    assert abs(round(r2, 4) - round(r * r, 4)) < 1e-12, fid
    rows.append((
        nid, f"Weighted R-squared, floor vs inundation at part grain, {what}",
        "fact_part_summary_full_period / PARTREG coefficient tables", "part",
        f"r-squared of the stored r on fit {fid}; NOT an independent fit", "mean_of_seasons",
        SCOPE, period, "115 parts in 64 paddocks", PIXEL_AREA_HA, round(r2, 6),
        round(r2, 6), round(r2, 6), "pixel",
        f"WEIGHTED - the fit is pixel-weighted by part cell count, so an unqualified R-squared "
        f"invites an unweighted recomputation and a different number. ESTIMAND: BETWEEN-UNIT - how "
        f"places differ from one another over the long run. It is NOT the within-unit R-squared "
        f"(0.17), which answers what an extra point of wetness buys the same ground and is "
        f"unregistered. Derived from stored r = {r:.6f}; spread_min = spread_max because a "
        f"transformation of a pinned value has no alternative-definition range of its own.",
        DECIDED,
        "Registered because it appears on a deliverable figure. Cite the number_id, never the value."))

mode = sys.argv[1] if len(sys.argv) > 1 else "check"
con = sqlite3.connect(DB); cur = con.cursor()
before = cur.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
print(f"  dim_headline_number before: {before}")
for r in rows:
    print(f"    {r[0]:<34s} {r[10]:>9.6f}   {r[7]}   from r={r[14].split('stored r = ')[1][:8]}")
if mode != "execute":
    print("\ncheck only - no write.")
else:
    cur.executemany("""INSERT OR REPLACE INTO dim_headline_number
        (number_id, label, source_object, grain, aggregation_order, series_variant, scope_filter,
         period_label, denominator, pixel_constant, pinned_value, spread_min, spread_max,
         support_level, caveat, decided_by, decision_note) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
    con.commit()
    after = cur.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
    ok = all(abs(cur.execute("SELECT pinned_value FROM dim_headline_number WHERE number_id=?",
                             (r[0],)).fetchone()[0] - r[10]) < 1e-9 for r in rows)
    print(f"\n  dim_headline_number {before} -> {after}  ({after-before:+d})   "
          f"read-back {'OK' if ok else 'MISMATCH'}")
con.close()
