#!/usr/bin/env python3
"""Targeted, additive registrar for the 3 existing D3 stratum-dashboard PNGs -> figure_asset.

Ruling BN (8 August 2026): register the 3 stratum dashboards that exist. Do NOT build
the remaining 6. They are correctly excluded from the Adrian share folder on two
independent grounds, both recorded in the caption below.

WHY THIS EXISTS (not the builder): the DB builder is destructive (unlink + full rebuild
from an unfiltered rglob) and would wipe the manually-registered Task H rows and
reinstate the stale 1-July figure snapshot. This registrar performs a narrow additive
write of exactly 3 rows and nothing else.

Deliberate divergence from register_d2_site_dashboards.py: that script uses
INSERT OR IGNORE, which never updates a changed checksum and so makes the
"re-run twice, identical checksums" test pass while the DB is wrong (CLAUDE.md,
Registration). This uses INSERT OR REPLACE. Idempotence is tested by CONVERGENCE:
mutate an input, re-run, confirm the row moves to the new checksum.

Scope / guarantees:
  * Touches only figure_asset_id LIKE 'figure_d3_stratum_%' -- the 3 rows it builds.
  * Verifies each PNG exists and recomputes the first-50-MB checksum BEFORE any write.
  * PDFs are intentionally NOT registered (PNG canonical; the PDF sibling is a print
    artefact of the same figure -- taskM Gate B Rule 2).
  * Nothing is rendered, rebuilt or re-run.

Usage:
  python scripts/11_database/register_D3_stratum_dashboards.py check     # no DB write (default)
  python scripts/11_database/register_D3_stratum_dashboards.py execute   # performs the 3 upserts
"""
from __future__ import annotations
import sys, hashlib, sqlite3
from pathlib import Path

ROOT   = Path(__file__).resolve().parents[2]
DB     = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
FIGDIR = ROOT / "Output" / "figures"
RUN_ID = "figfind1_D3_registration_20260808"
DOMAIN = "stratum_dashboard"
EXPECT_N = 3

# Support is genuinely MIXED and must be labelled so, never merged (CLAUDE.md):
#   flooding panel  -> census-derived stratum series (f6)
#   cover panel     -> mean over the stratum's monitoring PLOTS (plot support)
#   response panel  -> pixel census cloud + marker (pixel support)
SUPPORT_LEVEL = "mixed"
FIGURE_LEVEL  = "diagnostic"

MIXED_NOTE = (
    "MIXED SUPPORT - do not compare panels numerically. Flooding panel: census stratum "
    "series. Cover panel: mean over the stratum's monitoring plots (plot support). "
    "Vegetation-response panel: pixel census (24.97 m). Plot and pixel support can invert."
)

# Two independent, live defects on the rendered face. Recorded here so the row cannot be
# consumed as clean. Both are grounds for exclusion from any client-facing pack.
DEFECT_NOTE = (
    "NOT CLIENT-FACING. Two live defects on the rendered face, neither fixed: "
    "(1) subtitle carries '(provisional)' against the SETTLED F6 census verdict "
    "(9 no-trend / 0 non-stationary / 0 directional); "
    "(2) the cover panel is headed 'Total vegetation (green cover)' but plots TOTAL veg "
    "(green + dead) - the D1/D2 sheets head the same quantity 'Total veg (green + dead)'. "
    "Also carries the Ruling BE/BL flooding-panel label defect: the panel is titled "
    "'Annual flooding', y-axis 'Flood freq. (%)', parenthetical '(wet / valid years)', but "
    "plots WITHIN-YEAR wet extent. Per Ruling BL the rendered set is knowingly unfixed "
    "before 10 August. No VALUE is wrong (Ruling BE)."
)

CAPTION = (
    "Support: mixed (see provenance). Stratum dashboard for one community x wetness band: "
    "whole-farm map with the class highlighted, where the stratum sits among the four "
    "communities, within-year wet extent and total-vegetation cover over 1988-2023, and the "
    "stratum's plots against the community's pixel-census cover-versus-water cloud. "
    "3 of the 9 strata exist; the remaining 6 are not built and are not scheduled. "
    "Cover is how much and how green, not a condition score, and no cause is attributed. "
    + DEFECT_NOTE
)

STRATA = [
    ("aeolian_chenopod_shrublands_low",          "D3_stratum_Aeolian_Chenopod_Shrublands_low_slide_data.png",
     "Aeolian Chenopod Shrublands | low"),
    ("inland_floodplain_shrublands_swamps_high", "D3_stratum_Inland_Floodplain_Shrublands_Swamps_high_slide_data.png",
     "Inland Floodplain Shrublands / Swamps | high"),
    ("riverine_chenopod_shrublands_mid",         "D3_stratum_Riverine_Chenopod_Shrublands_mid_slide_data.png",
     "Riverine Chenopod Shrublands | mid"),
]

COLUMNS = ["figure_asset_id", "path", "title", "domain", "metric_id", "recommended_use",
           "checksum_sha256", "path_exists", "qa_status", "run_id", "superseded_flag",
           "framing_label", "provenance_note", "caption", "support_level", "figure_level"]


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks -- the project's one checksum convention."""
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk); read += len(chunk)
    return h.hexdigest()


def build_rows() -> list[dict]:
    rows = []
    for slug, fname, label in STRATA:
        p = FIGDIR / fname
        if not p.is_file():
            raise SystemExit(f"ABORT: missing or not a file: {p}")
        rows.append({
            "figure_asset_id": f"figure_d3_stratum_{slug}",
            "path":            f"Output/figures/{fname}",          # relative, posix
            "title":           f"Stratum dashboard - {label}",
            "domain":          DOMAIN,
            "metric_id":       None,
            "recommended_use": "review",                            # NOT reporting -- see DEFECT_NOTE
            "checksum_sha256": sha256_first50(p),
            "path_exists":     1,
            "qa_status":       "REVIEW",
            "run_id":          RUN_ID,
            "superseded_flag": 0,
            "framing_label":   None,
            "provenance_note": MIXED_NOTE + " Producer: scripts/07_figures_dashboards/12_build_dashboards.R "
                               "(build_unit(r, 'D3', ...)). Registered under Ruling BN; nothing re-rendered.",
            "caption":         CAPTION,
            "support_level":   SUPPORT_LEVEL,
            "figure_level":    FIGURE_LEVEL,
        })
    if len(rows) != EXPECT_N:
        raise SystemExit(f"ABORT: expected {EXPECT_N} rows, built {len(rows)}")
    ids = [r["figure_asset_id"] for r in rows]
    if len(set(ids)) != len(ids):
        raise SystemExit("ABORT: duplicate figure_asset_id")
    for r in rows:
        for col in ("figure_asset_id", "path", "path_exists", "checksum_sha256", "domain"):
            if r[col] in (None, ""):
                raise SystemExit(f"ABORT: empty required column {col!r} for {r['figure_asset_id']}")
    return rows


def main() -> int:
    mode = (sys.argv[1] if len(sys.argv) > 1 else "check").lower()
    if mode not in {"check", "execute"}:
        raise SystemExit("usage: register_D3_stratum_dashboards.py [check|execute]")
    rows = build_rows()

    con = sqlite3.connect(DB)
    try:
        before = con.execute("select count(*) from figure_asset").fetchone()[0]
        existing = {r[0]: r[1] for r in con.execute(
            "select figure_asset_id, checksum_sha256 from figure_asset "
            "where figure_asset_id like 'figure_d3_stratum_%'")}
        print(f"DB: {DB}")
        print(f"figure_asset rows before: {before}")
        print(f"existing figure_d3_stratum_* rows: {len(existing)}")
        for r in rows:
            prior = existing.get(r["figure_asset_id"])
            state = "NEW" if prior is None else ("UNCHANGED" if prior == r["checksum_sha256"] else "CHECKSUM MOVED")
            print(f"  [{state:14s}] {r['figure_asset_id']}  {r['checksum_sha256'][:16]}...  {r['path']}")

        if mode == "check":
            print("\ncheck only -- no write. Re-run with 'execute' to upsert.")
            return 0

        sql = (f"INSERT OR REPLACE INTO figure_asset ({', '.join(COLUMNS)}) "
               f"VALUES ({', '.join('?' for _ in COLUMNS)})")
        with con:
            con.executemany(sql, [[r[c] for c in COLUMNS] for r in rows])
        after = con.execute("select count(*) from figure_asset").fetchone()[0]
        print(f"\nfigure_asset rows after: {after}  (delta {after - before})")
        for r in con.execute("select figure_asset_id, path_exists, support_level, figure_level, run_id "
                             "from figure_asset where figure_asset_id like 'figure_d3_stratum_%' "
                             "order by figure_asset_id"):
            print("  ", r)
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
