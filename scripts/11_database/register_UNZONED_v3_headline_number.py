#!/usr/bin/env python
"""Register UNZONED v3's headline number in dim_headline_number.

Design-seat instruction, 10 Aug 2026: "The headline is +3.39. Take that as the
registered number."

WHY +3.39 AND NOT +5.11. The all-patches figure is +5.11, but Ruling EN - a coefficient
may be applied only within the range over which it was estimated - excludes it as the
headline. The size slope that would have to explain +5.11 was estimated on the REAL
Inland parts, which start at 588 cells, while 28 of the 54 supported unzoned Inland
patches sit below that. Restricted to the 26 patches inside the estimated range, the
residual is +3.39, and Inland's residual declines monotonically across size quartiles
(+8.51, +4.44, +4.27, +3.11) before plateauing. So +5.11 is inflated by patches on which
the controlling coefficient has no support.

THE SPREAD IS THE HONEST REPORT. spread_min is the largest-quartile mean (+3.11), the
most size-conservative defensible value; spread_max is the all-patches figure (+5.11),
which is what the number becomes if the range-of-support restriction is not applied.
A number whose spread is wide is not wrong, it is under-specified, and the spread says so.

INSERT OR REPLACE, never OR IGNORE (project rule): OR IGNORE never updates a changed
value, so the "re-run twice, identical" test would pass while the DB stayed wrong.
Idempotence is tested by CONVERGENCE - the value is re-derived from the source artefact
on every run and written, so mutating the input moves the row.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
SRC = ROOT / "Output" / "unzoned" / "UNZONED_v3_armB_size_range_support.csv"
QRT = ROOT / "Output" / "unzoned" / "UNZONED_v3_armB_inland_size_quartiles.csv"

NUMBER_ID = "unzoned_inland_floor_offset_inrange"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4


def main() -> int:
    # ---- re-derive from the source artefact, never typed ----------------------------
    rs = pd.read_csv(SRC)
    q = pd.read_csv(QRT)
    r = rs[rs.community == "inland"].iloc[0]
    pinned = round(float(r.residual_inside_range), 2)
    smin = round(float(q.mean_residual.min()), 2)
    smax = round(float(r.residual_all), 2)
    n_in = int(r.n_inside_real_size_range)
    n_all = int(r.n_patches)
    print(f"  re-derived: pinned {pinned:+.2f} (n={n_in}); spread {smin:+.2f} to "
          f"{smax:+.2f}; size alone expects {r.residual_expected_from_size_alone:+.2f}")

    row = {
        "number_id": NUMBER_ID,
        "label": ("Unzoned Inland Floodplain ground sits above the registered cover-water "
                  "line, on the spatial floor, restricted to patches inside the size "
                  "range the controlling size coefficient was estimated on"),
        "source_object": "Output/unzoned/UNZONED_v3_armB_size_range_support.csv",
        "grain": "unzoned patch (8-connected component within one vegetation community, "
                 "outside every management zone)",
        "aggregation_order": ("per patch-year, 5th percentile ACROSS the patch's cells; "
                              "then mean over the 35 water years; then residual against "
                              "the registered 115-part line (52.697196 + 0.547274 x mean "
                              "water), the line APPLIED and never refitted; then unweighted "
                              "mean over the patches"),
        "series_variant": "mean_of_seasons",
        "scope_filter": ("treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid "
                         "IS NULL AND meets_support_rule = 1 AND community = 'Inland "
                         "Floodplain Shrublands / Swamps' AND n_cells >= 588"),
        "period_label": "1988-2022 (35 water years)",
        "denominator": f"the {n_in} in-range unzoned Inland patches' own non-treed census cells",
        "pixel_constant": PIXEL_AREA_HA,
        "pinned_value": pinned,
        "spread_min": smin,
        "spread_max": smax,
        "support_level": "pixel",
        "caveat": (
            "PERCENTAGE POINTS of ground cover, on veg_p05_spatial - NOT the temporal "
            "metric, and the two are never paired. RULING EN governs the value: the "
            "all-patches figure is +5.11, but the size coefficient that would have to "
            "explain it was estimated only on real parts of 588 cells and up, while 28 of "
            "54 supported unzoned Inland patches fall below that. spread_max is that "
            "unrestricted figure; spread_min is the largest size quartile. NOT A "
            "CONDITION CLAIM and NOT A MANAGEMENT CLAIM - a residual is a departure from "
            "a fitted expectation. This is unzoned STANDARD-GRAZING country (set "
            "stocking), never a reference, a control or unmanaged. RULING EL: the "
            "between-unit test cannot be size-controlled on this data - no community "
            "survives size matching ten deep - so this number is read against a size "
            "expectation of +0.27 pp, not corrected by it. Nothing is adjusted for size."),
        "decided_by": ("UNZONED v3 section 4.6 "
                       "(docs/reference_update/Gayini_CC_spec_UNZONED_v3.md); design-seat "
                       "Rulings EL and EN, 10 Aug 2026; derived and verified by CC "
                       "2026-08-10"),
        "decision_note": (
            "The design seat's first framing made Inland the interpretable community "
            "because its spatial-floor size slope is -0.23, near zero. That is right "
            "about the slope and incomplete about its support: half the unzoned Inland "
            "patches sit below the smallest real Inland part, so applying the slope there "
            "extrapolates it - the same refusal Arm A already makes on the water axis. "
            "Inland's residual falls +8.51, +4.44, +4.27, +3.11 across size quartiles, "
            "halving and then plateauing rather than vanishing, so the offset is real but "
            "the unrestricted +5.11 is inflated. The registered value is the in-range "
            "figure. Companion reading: on the TEMPORAL metric the same ground sits ON "
            "the paddock relationship (-0.30 pp), so the RESPONSE triangulates across "
            "metrics while the LEVEL does not."),
    }

    con = sqlite3.connect(DB)
    try:
        cols = [r[1] for r in con.execute("PRAGMA table_info(dim_headline_number)")]
        missing = [k for k in row if k not in cols]
        if missing:
            print(f"HALT: dim_headline_number has no column(s) {missing}")
            return 1
        before = con.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
        ks = list(row)
        con.execute(
            f"INSERT OR REPLACE INTO dim_headline_number ({','.join(ks)}) "
            f"VALUES ({','.join('?' * len(ks))})", [row[k] for k in ks])
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM dim_headline_number").fetchone()[0]
        got = con.execute(
            "SELECT pinned_value, spread_min, spread_max, support_level FROM "
            "dim_headline_number WHERE number_id = ?", (NUMBER_ID,)).fetchone()
    finally:
        con.close()

    print(f"  dim_headline_number {before} -> {after} rows")
    print(f"  read back: pinned {got[0]:+.2f}, spread [{got[1]:+.2f}, {got[2]:+.2f}], "
          f"support {got[3]}")
    if abs(got[0] - pinned) > 1e-9:
        print("HALT: the row does not read back as written")
        return 1
    print("  PASS - written and verified by read-back")
    return 0


if __name__ == "__main__":
    sys.exit(main())
