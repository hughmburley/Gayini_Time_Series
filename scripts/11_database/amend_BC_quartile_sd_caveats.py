#!/usr/bin/env python
"""Ruling BC - amend the caveat on cap_residual_sd_water_quartile_1 .. _4.

WHAT THIS IS PERMITTED TO DO. Ruling F, 3 Aug 2026: `caveat` and `decision_note` carry
meaning ABOUT a number, not the number, and are amendable in place under explicit
design-seat direction, logged. `pinned_value`, `spread_min` and `spread_max` are on the
never-amendable list, and this script asserts they are byte-identical before and after.

WHAT CHANGED, AND WHY IT IS A SHARPENING RATHER THAN A CORRECTION. The existing caveat
already said the spread uses the population (n) denominator where the pinned value uses
the sample (n-1) form. What it did not say is the load-bearing part: that this is
therefore NOT a range of defensible alternatives, which is what spread_min/spread_max
means on every other row in this registry. A reader who trusts the column's usual
meaning reads those four rows as carrying +/-2% of definitional uncertainty. There is
none. It is one arithmetic choice, recorded twice.

Run with no argument to preview; run with `execute` to write.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"

IDS = [f"cap_residual_sd_water_quartile_{i}" for i in (1, 2, 3, 4)]

CAVEAT = (
    "Quoted in the residual-maps footer. The residual is measured against the whole-record "
    "fitted line. "
    "SPREAD IS NOT AN ALTERNATIVE-DEFINITION RANGE ON THESE FOUR ROWS (Ruling BC, 7 Aug 2026). "
    "spread_min is the POPULATION (n) denominator and pinned_value is the SAMPLE (n-1) form of "
    "the same quantity on the same 115 parts in the same bins. The interval records one "
    "arithmetic choice recorded twice - it is NOT definitional uncertainty and must not be read "
    "as a defensible range the way spread does on every other row of this registry. "
    "Reproduced independently by DIAG-1 (Output/diag/DIAG1_heteroscedasticity.csv, 7 Aug 2026): "
    "the sample form reproduces pinned_value exactly and the population form reproduces "
    "spread_min exactly. "
    "These four values remain the reason a single typical-miss figure must not be read as "
    "applying everywhere: the wettest quartile carries about 30% of the driest quartile's scatter."
)

NOTE_SUFFIX = (
    " AMENDED 7 Aug 2026 under Ruling BC (caveat only; Ruling F permits caveat and "
    "decision_note in place). pinned_value, spread_min and spread_max are unchanged and were "
    "asserted unchanged by scripts/11_database/amend_BC_quartile_sd_caveats.py."
)


def main() -> int:
    execute = len(sys.argv) > 1 and sys.argv[1] == "execute"
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row

    before = {r["number_id"]: dict(r) for r in con.execute(
        "SELECT number_id, pinned_value, spread_min, spread_max, caveat, decision_note "
        "FROM dim_headline_number WHERE number_id IN (%s)" % ",".join("?" * 4), IDS)}
    if len(before) != 4:
        print(f"  ABORT: expected 4 rows, found {len(before)}")
        return 1

    print(f"  {'PREVIEW' if not execute else 'EXECUTE'} - Ruling BC, 4 rows\n")
    for nid in IDS:
        b = before[nid]
        already = "Ruling BC" in (b["caveat"] or "")
        print(f"  {nid}  pinned {b['pinned_value']}  spread [{b['spread_min']}, {b['spread_max']}]"
              f"   {'already amended' if already else 'to amend'}")

    if not execute:
        print("\n  New caveat text:\n")
        for line in CAVEAT.split(". "):
            print(f"    {line.strip()}.")
        print("\n  Re-run with `execute` to write.")
        return 0

    for nid in IDS:
        note = before[nid]["decision_note"] or ""
        if NOTE_SUFFIX.strip() not in note:
            note = note.rstrip() + NOTE_SUFFIX
        con.execute(
            "UPDATE dim_headline_number SET caveat = ?, decision_note = ? WHERE number_id = ?",
            (CAVEAT, note, nid))
    con.commit()

    after = {r["number_id"]: dict(r) for r in con.execute(
        "SELECT number_id, pinned_value, spread_min, spread_max, caveat, decision_note "
        "FROM dim_headline_number WHERE number_id IN (%s)" % ",".join("?" * 4), IDS)}

    # the never-amendable fields must be byte-identical. This is the whole point of the
    # ruling's distinction and it is asserted, not assumed.
    problems = []
    for nid in IDS:
        for f in ("pinned_value", "spread_min", "spread_max"):
            if before[nid][f] != after[nid][f]:
                problems.append(f"{nid}.{f}: {before[nid][f]} -> {after[nid][f]}")
        if after[nid]["caveat"] != CAVEAT:
            problems.append(f"{nid}.caveat did not take")
    if problems:
        print("\n  FAILED:")
        for p in problems:
            print(f"    {p}")
        return 1

    print(f"\n  4 caveats amended. pinned_value, spread_min, spread_max asserted unchanged "
          f"on all 4 rows.")
    n = con.execute("SELECT count(*) FROM dim_headline_number").fetchone()[0]
    print(f"  dim_headline_number row count {n} (unchanged - no row added, none superseded)")
    con.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
