#!/usr/bin/env python3
"""Pack v1.3 T0 - register the two caption numbers. Additive only.

Task list T0: both are quoted in deliverable captions, so the five-qualifier rule
applies - support_level, scope_filter, pixel_constant, denominator, period_label.

NINE ROWS, NOT TWO. Each is a set of values across bins, and dim_headline_number
holds one value per row. A row per bin means a caption can cite the bin it quotes
rather than a phrase, which is number rule 1 applied to a series.

Both were reproduced in R first (PACKv13_T0_caption_numbers.R). The R run also
computed the plausible alternative definitions - unweighted mean, population SD - and
neither matched, so the definition is established rather than assumed. Those
alternatives go on the row as the spread, because that is exactly what spread_min /
spread_max are for: the range the value takes under a defensible alternative.

INSERT OR REPLACE, never OR IGNORE.

Usage:
  python scripts/11_database/PACKv13_T0_register.py check
  python scripts/11_database/PACKv13_T0_register.py execute
"""
from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
T = ROOT / "Output" / "tables"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
PERIOD = "1988-2022"
DECIDED = ("Pack v1.3 T0, docs/reference_update/Gayini_pack_v1_3_task_list.md; design-seat "
           "figures reproduced in R by CC 7 Aug 2026 (PACKv13_T0_caption_numbers.R)")

# the alternative definitions the R run computed and rejected - carried as the spread
ALT_FIFTH = [65.9, 69.2, 73.0, 75.2, 76.3]     # unweighted mean within bin
ALT_SD = [12.59, 8.34, 6.22, 3.77]             # population (n) denominator

ORD = ["driest", "second", "middle", "fourth", "wettest"]
ORD4 = ["driest", "second", "third", "wettest"]


def main(mode: str) -> int:
    if mode not in {"check", "execute"}:
        print("use: check | execute")
        return 2
    got = list(csv.DictReader(open(T / "PACKv13_T0_caption_numbers.csv", encoding="utf-8-sig")))
    if not all(r["agrees"] == "TRUE" for r in got):
        print("FAIL: the R reproduction did not agree on every bin - nothing is registered")
        return 1

    rows = []
    for r in got:
        k = int(r["bin"].split("_")[1])
        v, n = float(r["got"]), int(r["n_units"])
        if r["number"] == "inland_floor_by_wetness_fifth":
            alt = ALT_FIFTH[k - 1]
            rows.append((
                f"cap_inland_floor_wetness_fifth_{k}",
                f"Inland mean cover floor, wetness fifth {k} of 5 ({ORD[k-1]})",
                "fact_part_summary_full_period / PARTREG_part_residuals.csv", "part",
                "pixel-weighted mean of across-year mean floors, within a wetness fifth",
                "mean_of_seasons",
                "115 supported paddock x community parts, Inland Floodplain only (61); "
                f"fifth {k} of type-7 quintile breaks on whole_record__inund_mean",
                PERIOD, f"{n} Inland parts in the fifth", PIXEL_AREA_HA, round(v, 4),
                round(min(v, alt), 4), round(max(v, alt), 4), "pixel",
                "Quoted in the three-periods figure, panel C. The bins are quintiles of a "
                "35-year mean wetness, not of any single year. SPREAD is the UNWEIGHTED mean "
                "within the same bin - a defensible alternative that does NOT reproduce the "
                "caption, which is how the pixel-weighted definition was established. "
                "Descriptive: no cause is attributed and this is not a fitted relationship.",
                DECIDED,
                "Registered because it is quoted in a deliverable caption; it had no number_id "
                "before Pack v1.3. Cite the number_id, never the value."))
        else:
            alt = ALT_SD[k - 1]
            rows.append((
                f"cap_residual_sd_water_quartile_{k}",
                f"Residual SD, wetness quartile {k} of 4 ({ORD4[k-1]})",
                "fact_part_summary_full_period / PARTREG_part_residuals.csv", "part",
                "sample SD (n-1) of the whole-record residual, within a wetness quartile",
                "mean_of_seasons",
                "115 supported paddock x community parts, all three communities; "
                f"quartile {k} of type-7 quartile breaks on whole_record__inund_mean",
                PERIOD, f"{n} parts in the quartile", PIXEL_AREA_HA, round(v, 4),
                round(min(v, alt), 4), round(max(v, alt), 4), "pixel",
                "Quoted in the residual-maps footer. The residual is measured against the "
                "whole-record fitted line. SPREAD is the POPULATION (n) denominator, which does "
                "not reproduce the caption - the sample (n-1) form does. These four values are "
                "the reason a single typical-miss figure must not be read as applying "
                "everywhere: the wettest quartile carries about 30% of the driest quartile's "
                "scatter.", DECIDED,
                "Registered because it is quoted in a deliverable caption; it had no number_id "
                "before Pack v1.3. Cite the number_id, never the value."))

    con = sqlite3.connect(DB)
    cur = con.cursor()
    before = cur.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
    print(f"  dim_headline_number before: {before}")
    for r in rows:
        print(f"    {r[0]:<38s} {r[10]:>8.3f}   spread [{r[11]}, {r[12]}]   {r[8]}")
    if mode == "check":
        print("\ncheck only - no write.")
        con.close()
        return 0

    cur.executemany(
        """INSERT OR REPLACE INTO dim_headline_number
           (number_id, label, source_object, grain, aggregation_order, series_variant,
            scope_filter, period_label, denominator, pixel_constant, pinned_value,
            spread_min, spread_max, support_level, caveat, decided_by, decision_note)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
    con.commit()
    after = cur.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
    ok = True
    for r in rows:
        v, s = cur.execute("SELECT pinned_value, support_level FROM dim_headline_number "
                           "WHERE number_id=?", (r[0],)).fetchone()
        ok &= abs(v - r[10]) < 1e-9 and s == "pixel"
    con.close()
    print(f"\n  dim_headline_number {before} -> {after}  ({after-before:+d})   "
          f"read-back {'OK' if ok else 'MISMATCH'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "check"))
