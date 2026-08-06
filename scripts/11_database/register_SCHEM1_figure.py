#!/usr/bin/env python3
"""SCHEM-1 - register the methods schematic in figure_asset.

WHY A PYTHON REGISTRAR. Figures normally register through R's
gayini_write_and_register_figure(), which takes a ggplot object and calls ggsave.
SCHEM-1 is drawn in matplotlib, so that path cannot accept it. This registrar
follows register_taskM_gateC_assets.py's pattern instead: narrow, additive,
idempotent, and it touches exactly one row.

INSERT OR REPLACE, never INSERT OR IGNORE. OR IGNORE does not error and does not
duplicate, so it looks idempotent while never updating a changed checksum - which
makes "re-run twice, identical checksums" pass while the DB is wrong. Idempotence
here is tested by CONVERGENCE: re-running after the PNG changes must move the
stored checksum to the new value.

Checksum convention: first-50-MB SHA-256, 1 MB chunks - the project's one
convention, identical to sha256_first50() in the Task M registrar. NOT the R
registrars' whole-file digest::digest (see T3-I3).

Title and caption are Ruling AP, verbatim. The caption must name the support
level; that is asserted here so the rule survives the move out of R.

Usage:
  python scripts/11_database/register_SCHEM1_figure.py check     # no DB write (default)
  python scripts/11_database/register_SCHEM1_figure.py execute   # performs the write
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
PNG = ROOT / "Output" / "figures" / "SCHEM1_figure25_axis_chain.png"
RUN_ID = "schem1_20260806"

FIGURE_ID = "figure_schem1_figure25_axis_chain"

# --- Ruling AP, 6 August 2026. Verbatim. Do not paraphrase. -------------------
TITLE = "How each axis of the cover-and-water figure is built"

CAPTION = (
    "The two measurements behind the cover-and-water figure, from satellite record to one "
    "point per paddock. Cover and water are recorded independently, at 30 m and 25.0 m in "
    "different projections, and resampled onto one 24.970268 m grid - cover bilinearly "
    "because it is a continuous surface, water by nearest neighbour at both steps because a "
    "wet-or-dry mask must never be blended. Both are then read at the same 795,602 cell "
    "centres. For each paddock in each water year, cover gives the level 95% of the paddock "
    "exceeds and water gives the share of cells seen wet, so both axes are within-year, "
    "across-space quantities and both keep a 35-year time axis. Pixel support, aggregated to "
    "paddock. The ladder at right gives the footprint of each step: the figure is drawn on "
    "49,607 ha, 57.7% of the property."
)

SUPPORT_LEVEL = "pixel"
FIGURE_LEVEL = "deliverable"
DOMAIN = "methods_schematic"
RECOMMENDED_USE = "deliverable"
FRAMING_LABEL = "census_8058"
PROVENANCE_NOTE = (
    "Producer scripts/14_doc_audit/SCHEM1_methods_schematic.py. Rulings AM (Figure 25 chain "
    "only; the paddock x community cut is drawn as a terminated grey branch to Figures 17-18) "
    "and AN (nearest neighbour throughout on the water side, with the pinned 25 m reference "
    "grid drawn as its own step). Every quantity is recomputed at render from "
    "Gayini_Results.sqlite and read off the source rasters; none is typed. The producer "
    "asserts its drawn 5th percentile against fact_zone_veg_annual.veg_p05_spatial and stops "
    "on disagreement. Verification: Output/audit/SCHEM1_verification_findings.md. Destined "
    "for methods document section 4, where the two floors are defined."
)


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - the project's one convention."""
    h = hashlib.sha256()
    read = 0
    cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            read += len(chunk)
    return h.hexdigest()


def main(mode: str) -> int:
    if mode not in {"check", "execute"}:
        print(f"unknown mode {mode!r}; use check or execute")
        return 2
    if not PNG.exists():
        print(f"FAIL: {PNG} does not exist - render it before registering")
        return 1

    # the R registrar's rule, carried across languages: the caption must state
    # the support level, by the token itself and not merely the word "support".
    if SUPPORT_LEVEL.lower() not in CAPTION.lower():
        print(f"FAIL: caption must state the support level {SUPPORT_LEVEL!r}")
        return 1

    checksum = sha256_first50(PNG)
    rel = PNG.relative_to(ROOT).as_posix()

    con = sqlite3.connect(DB)
    cur = con.cursor()
    before = cur.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    existing = cur.execute(
        "SELECT checksum_sha256, title FROM figure_asset WHERE figure_asset_id = ?",
        (FIGURE_ID,),
    ).fetchone()

    print(f"  figure_asset_id : {FIGURE_ID}")
    print(f"  path            : {rel}")
    print(f"  bytes           : {PNG.stat().st_size:,}")
    print(f"  checksum(50MB)  : {checksum}")
    print(f"  rows before     : {before}")
    if existing is None:
        print("  existing row    : none - this is an INSERT")
    elif existing[0] == checksum:
        print("  existing row    : present, checksum UNCHANGED - REPLACE is a no-op")
    else:
        print(f"  existing row    : present, checksum CHANGED\n"
              f"                    was {existing[0]}\n"
              f"                    now {checksum}   <- convergence, the reason for OR REPLACE")

    if mode == "check":
        print("\ncheck only - no write. Re-run with 'execute' to register.")
        con.close()
        return 0

    cur.execute(
        """INSERT OR REPLACE INTO figure_asset
             (figure_asset_id, path, title, domain, metric_id, recommended_use,
              checksum_sha256, path_exists, qa_status, run_id, superseded_flag,
              framing_label, provenance_note, caption, support_level, figure_level)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (FIGURE_ID, rel, TITLE, DOMAIN, None, RECOMMENDED_USE, checksum, 1, "REVIEW",
         RUN_ID, 0, FRAMING_LABEL, PROVENANCE_NOTE, CAPTION, SUPPORT_LEVEL, FIGURE_LEVEL),
    )
    con.commit()

    after = cur.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    got = cur.execute(
        "SELECT checksum_sha256, title, support_level, path_exists "
        "FROM figure_asset WHERE figure_asset_id = ?", (FIGURE_ID,)).fetchone()
    con.close()

    ok = got[0] == checksum and got[1] == TITLE and got[2] == SUPPORT_LEVEL and got[3] == 1
    print(f"\n  rows after      : {after}   (delta {after - before:+d})")
    print(f"  read-back       : {'MATCHES what was written' if ok else 'MISMATCH'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "check"))
