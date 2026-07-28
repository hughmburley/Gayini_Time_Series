#!/usr/bin/env python3
"""T12 · v4 numeric correction — dim_source_product.caveat for 'dea_landcover_l3'.

The Gate A caveat (v1 text) said the false-positive floor was "6.7% of property".
v4 corrects this: 6.72% is the paddock-UNWEIGHTED mean of the 64 zone values; the
area-weighted PROPERTY figure is 10.57% (confirmed at Gate B). This is an explicit,
recorded UPDATE to a row THIS TASK created — legitimate under additive-only (nothing
deleted), and reported in the change report with before/after text. Idempotent
(UPDATE to a fixed target).

Only the `caveat` column changes; product_id/name/sensor/method_summary untouched.
No other row touched.

Usage: python scripts/13_dea_landcover/T12_v4_correct_source_product_caveat.py [check|execute]
"""
from __future__ import annotations
import sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
PID = "dea_landcover_l3"

CAVEAT_V4 = (
    "NOT cropping history. Shares parent products with the Gayini census — "
    "cannot independently corroborate census results. CTV is the weakest class "
    "in the product; in semi-arid and floodplain settings, drought dry-down and "
    "flood green-up both mimic the cultivation signature. Measured false-positive "
    "floor at Gayini 2023-2025, when cultivation is known to be zero: 10.57% of "
    "property (area-weighted); 6.72% as an unweighted mean across the 64 "
    "paddocks; 28 of 64 paddocks above 5%. Always state the denominator. "
    "GA use constraint: national scale; local datasets are authoritative."
)


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit("use check|execute")
    con = sqlite3.connect(DB.as_posix() if mode == "execute" else f"file:{DB.as_posix()}?mode=ro", uri=(mode == "check"))
    before = con.execute("SELECT caveat FROM dim_source_product WHERE product_id=?", (PID,)).fetchone()
    if before is None:
        raise SystemExit(f"ABORT: no dim_source_product row for {PID}")
    print("BEFORE:\n ", before[0])
    if mode == "check":
        print("\n[check] would set caveat to:\n ", CAVEAT_V4)
        print("[check] NO DB WRITE."); con.close(); return
    con.execute("UPDATE dim_source_product SET caveat=? WHERE product_id=?", (CAVEAT_V4, PID))
    con.commit()
    after = con.execute("SELECT caveat FROM dim_source_product WHERE product_id=?", (PID,)).fetchone()[0]
    print("\nAFTER:\n ", after)
    print("\nchanged:", before[0] != after, "| matches v4 target:", after == CAVEAT_V4)
    con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
