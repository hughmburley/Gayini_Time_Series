"""T3 acceptance - idempotence by CONVERGENCE, not stability.

CLAUDE.md standing rule: "Idempotence is tested by convergence, not stability.
Mutate an input, re-run, confirm the DB moves to the new checksum. A test that only
checks stability cannot distinguish converged from frozen."

A stability test (run twice, compare) passes on a frozen DB and on an OR IGNORE
registrar that never updates anything. This test instead mutates a real input to the
Gate C pipeline, re-runs it, asserts the DB MOVED, then restores the input, re-runs,
and asserts the DB moved BACK to the committed state.

Run standalone. It leaves the DB in its original state; if it fails part-way it says
so loudly, because a half-restored DB is worse than a failed test.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path("scripts") / "05_ground_cover"))
import T3_gateC_persist as gc  # noqa: E402

DB = Path("Output") / "database" / "Gayini_Results.sqlite"


def state():
    """The observable the test asserts on: which threshold is flagged, per key."""
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    try:
        sel = dict(((m, s), t) for m, s, t in con.execute(
            "SELECT metric, scope, threshold FROM v_always_green_sweep "
            "WHERE is_selected_threshold = 1"))
        n = con.execute("SELECT COUNT(*) FROM v_always_green_sweep").fetchone()[0]
        area75 = con.execute(
            "SELECT area_ha FROM v_always_green_sweep WHERE threshold=75 AND "
            "scope='non_treed' AND metric='total_cover_floor'").fetchone()[0]
    finally:
        con.close()
    return sel, n, area75


def show(tag, s):
    sel, n, a = s
    print(f"  {tag}: rows={n} area@75={a:,.2f} ha")
    for k in sorted(sel, key=str):
        print(f"      {k[0]:<18} {k[1]:<22} -> t={sel[k]}")


def main():
    print("=" * 78)
    print("T3 Gate C - idempotence by CONVERGENCE")
    print("=" * 78)

    baseline = state()
    show("BASELINE (committed)", baseline)
    orig_cut = dict(gc.OPERATIONAL_CUT)
    assert orig_cut["total_cover_floor"] == 75, "unexpected committed cut"

    # ---- 1. MUTATE an input and re-run: the DB must MOVE -------------------
    print("\n[1] mutating OPERATIONAL_CUT total_cover_floor 75 -> 76, re-running ...")
    gc.OPERATIONAL_CUT["total_cover_floor"] = 76
    gc.main()
    mutated = state()
    show("AFTER MUTATION", mutated)

    moved = (mutated[0][("total_cover_floor", "non_treed")] == 76
             and mutated[0][("total_cover_floor", "all_pixel")] == 76)
    print(f"\n  DB MOVED to the new input: {'PASS' if moved else 'FAIL'}")
    if not moved:
        print("  !! The DB did NOT converge. This is the OR IGNORE failure mode: the "
              "write path is not updating changed values. DB left MUTATED - restore "
              "before using it.")
        return 1

    unchanged_ok = (mutated[0][("green_share_floor", "non_treed")] == 50
                    and mutated[1] == baseline[1]
                    and abs(mutated[2] - baseline[2]) < 0.01)
    print(f"  untouched keys and values held steady: {'PASS' if unchanged_ok else 'FAIL'}")

    # ---- 2. RESTORE the input and re-run: the DB must move BACK ------------
    print("\n[2] restoring OPERATIONAL_CUT 76 -> 75, re-running ...")
    gc.OPERATIONAL_CUT.update(orig_cut)
    gc.main()
    restored = state()
    show("AFTER RESTORE", restored)

    back = restored == baseline
    print(f"\n  DB converged BACK to the committed state: {'PASS' if back else 'FAIL'}")
    if not back:
        print(f"  !! baseline  {baseline}")
        print(f"  !! restored  {restored}")
        print("  !! DB is NOT in its committed state. Re-run T3_gateC_persist.py.")
        return 1

    # ---- 3. what a stability-only test would have proved -------------------
    print("\n[3] note on what this test adds:")
    print("    A stability test (run twice, compare) would have PASSED at every step")
    print("    above, including on a write path that never updates anything. Step [1]")
    print("    is the one that can actually fail, and it is the reason OR IGNORE is")
    print("    banned: it neither errors nor duplicates, so it looks idempotent while")
    print("    leaving a stale value in place.")

    print("\n" + "=" * 78)
    print("RESULT: PASS - the Gate C write path converges in both directions.")
    print("DB is in its committed state.")
    print("=" * 78)
    return 0


if __name__ == "__main__":
    sys.exit(main())
