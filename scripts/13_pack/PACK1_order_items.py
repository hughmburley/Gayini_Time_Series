#!/usr/bin/env python
"""FIG1-T1 — order the pack by argument, not by item code.

Adds `display_order` and `section` to PACK1_item_list.csv and sorts it. Both generated
documents (00_START_HERE.md and the workbook Contents sheet) read the same file and sort by
`display_order`, so they cannot disagree.

Idempotent by convergence, not by stability: re-running rewrites the same values, and mutating
one and re-running restores it. Adds no row and drops none.
"""
import csv, sys
from pathlib import Path

ITEMS = Path(__file__).resolve().parents[2] / "Output" / "pack" / "PACK1_item_list.csv"

# The spec's section table names 16 of the 18 rows. F7 and T1_render are unplaced there: F7 is a
# panel of M4's figure and shares its file, and T1_render is T1 as a picture. Each is placed
# immediately after its partner so the pair reads together. THAT PLACEMENT IS CC'S, NOT THE SPEC'S.
ORDER = [
    ("Read first",        ["T3", "T1", "T1_render", "T2"]),
    ("The argument",      ["M1", "F5", "F3", "M5b", "M4", "F7", "M4b"]),
    ("Supporting detail", ["M5", "F4", "F1", "F2", "F6", "M2", "M3"]),
]

def main():
    rows = list(csv.DictReader(open(ITEMS, encoding="utf-8")))
    cols = [c for c in rows[0].keys() if c not in ("display_order", "section")]

    pos, sec, n = {}, {}, 0
    for s, ids in ORDER:
        for i in ids:
            n += 1; pos[i] = n; sec[i] = s

    have = {r["item_id"] for r in rows}
    unplaced = sorted(have - set(pos))
    unknown  = sorted(set(pos) - have)
    if unplaced or unknown:
        raise SystemExit(f"STOP - every row must be placed exactly once.\n"
                         f"  in the item list, not in ORDER: {unplaced}\n"
                         f"  in ORDER, not in the item list: {unknown}")

    before = [r["item_id"] for r in rows]
    for r in rows:
        r["display_order"] = pos[r["item_id"]]; r["section"] = sec[r["item_id"]]
    rows.sort(key=lambda r: r["display_order"])

    with open(ITEMS, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols + ["display_order", "section"])
        w.writeheader(); w.writerows(rows)

    print(f"  {len(rows)} rows, {n} positions, 0 unplaced - no row added, none dropped "
          f"({sorted(before) == sorted(r['item_id'] for r in rows)})")
    cur = None
    for r in rows:
        if r["section"] != cur: cur = r["section"]; print(f"   {cur}")
        print(f"     {r['display_order']:>2}  {r['item_id']}")

if __name__ == "__main__":
    main()
