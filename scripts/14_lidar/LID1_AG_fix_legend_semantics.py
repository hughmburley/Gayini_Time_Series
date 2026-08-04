#!/usr/bin/env python
"""LID-1 Ruling AG — correct the stale R2 exclusion count in 14 legend_semantics strings.

WHY THIS IS AN AMENDMENT AND NOT A NEW ROW: Ruling F's field class governs. `legend_semantics`
is metadata ABOUT the raster - not a value, not one of the five qualifiers - so it is amendable
in place under explicit design-seat direction, logged. Ruling AG is that direction.

WHAT IS WRONG: 14 height rasters say "Excluded 218 px / 0.545 ha in 2009 and 0 px in 2021".
The artefact `taskU_gateU1_r2_screen.csv` says 2021 excluded 1 px / 0.0025 ha, and U-I15 already
records the 0 -> 1 change after the U-I11 re-run. The issue was logged; the strings were not.

WHY IT MATTERS MORE THAN ONE PIXEL: these are the strings going to Adrian for confirmation under
Ruling AF. SENDING A KNOWN-STALE STRING FOR CONFIRMATION CONVERTS A STALE NUMBER INTO A CONFIRMED
ONE - worse than leaving it unconfirmed, because confirmation is the thing being bought.

UPDATE, never INSERT: the row count must not move, and an UPDATE cannot move it.
"""
import csv, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB   = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
SCREEN = ROOT / "Output" / "tables" / "taskU_gateU1_r2_screen.csv"

STALE = "Excluded 218 px / 0.545 ha in 2009 and 0 px in 2021, on-property."
NOTE  = (" [CORRECTED 4 Aug 2026, LID-1 Ruling AG: this string previously read "
         "'0 px in 2021'. The 2021 exclusion moved 0 -> 1 px after the U-I11 re-run (see U-I15); "
         "the issue was logged and the string was not updated. Corrected before the semantics went "
         "to JRSRP for confirmation - confirming a known-stale string would convert it into a "
         "confirmed one.]")

def probe(con, label):
    o = {t: con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
         for t in ("raster_asset", "dim_headline_number", "figure_asset", "table_asset")}
    print(f"  PROBE {label}: " + " · ".join(f"{k}={v}" for k, v in o.items()))
    return o

def main():
    # the truth comes from the artefact, never from this file
    rows = {(r["epoch"], float(r["ceiling_m"])): r
            for r in csv.DictReader(open(SCREEN, encoding="utf-8")) if r["is_primary"] == "1"}
    px_2021 = int(rows[("2021", 50.0)]["excluded_px"])
    ha_2021 = float(rows[("2021", 50.0)]["excluded_ha"])
    px_2009 = int(rows[("2009", 50.0)]["excluded_px"])
    ha_2009 = float(rows[("2009", 50.0)]["excluded_ha"])
    print(f"  artefact r2_screen.csv, is_primary: 2009 {px_2009} px / {ha_2009} ha · "
          f"2021 {px_2021} px / {ha_2021} ha")
    assert px_2021 == 1, "the artefact no longer says 1 px - stop and re-read before writing"

    CORRECT = (f"Excluded {px_2009} px / {ha_2009} ha in 2009 and {px_2021} px / {ha_2021} ha "
               f"in 2021, on-property.")
    print(f"  replacing: {STALE!r}\n  with:      {CORRECT!r}")

    con = sqlite3.connect(DB)
    pre = probe(con, "before")
    # NB: match the WHOLE stale sentence. A fragment such as "0 px in 2021" also matches the
    # correction note below, which quotes the old value on purpose - so a fragment test reports
    # the corrected rows as still stale. The note is the record; the sentence is the claim.
    allrows = con.execute("SELECT raster_asset_id, legend_semantics FROM raster_asset "
                          "WHERE run_id='taskU_gateU1' ORDER BY 1").fetchall()
    targets = [rid for rid, sem in allrows if STALE in sem]
    done    = [rid for rid, sem in allrows if CORRECT in sem]
    print(f"  {len(targets)} rows assert the stale count · {len(done)} already corrected")
    if not targets and len(done) == 14:
        print("  already applied - nothing to do (converged)"); con.close(); return
    assert len(targets) == 14, f"expected 14, found {len(targets)} - stop"

    try:
        con.execute("BEGIN")
        for rid in targets:
            s = con.execute("SELECT legend_semantics FROM raster_asset WHERE raster_asset_id=?",
                            (rid,)).fetchone()[0]
            assert STALE in s, f"{rid}: the stale string is not where it was expected"
            con.execute("UPDATE raster_asset SET legend_semantics=? WHERE raster_asset_id=?",
                        (s.replace(STALE, CORRECT) + NOTE, rid))
        con.commit(); print("  COMMIT - 14 rows updated")
    except Exception as e:
        con.rollback(); con.close(); raise SystemExit(f"ROLLED BACK: {e}")

    post = probe(con, "after")
    assert pre == post, f"ROW COUNT MOVED: {pre} -> {post}"
    after = con.execute("SELECT legend_semantics FROM raster_asset "
                        "WHERE run_id='taskU_gateU1'").fetchall()
    left  = sum(1 for (sem,) in after if STALE in sem)
    fixed = sum(1 for (sem,) in after if "Ruling AG" in sem)
    assert sum(1 for (sem,) in after if CORRECT in sem) == 14, "the corrected sentence is not on 14 rows"
    print(f"  rows still ASSERTING the stale count: {left} (0 expected)")
    print(f"  rows carrying the visible correction note: {fixed} (14 expected)")
    assert left == 0 and fixed == 14
    print("  row counts unchanged on all four registries")
    con.close()

if __name__ == "__main__":
    main()
