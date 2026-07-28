#!/usr/bin/env python3
"""T12 close-out — register the sensor-era gap figure + two maps in figure_asset.
Additive, INSERT OR REPLACE, first-50-MB SHA-256. Same-session R-write/register.
Usage: python scripts/13_dea_landcover/register_T12_close_figures.py [check|execute]"""
from __future__ import annotations
import hashlib, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN = "T12_close"
CAP = ("DEA Land Cover is a modelled national product, not a record of land use. "
       "Not independent of the Gayini census.")
FIGS = [
    ("T12_DEA_sensor_era_gap", "T12_DEA_sensor_era_gap.png",
     "DEA Land Cover (modelled) — CTV separates cultivated from uncultivated only where observation density is adequate",
     "mixed",
     "T12 close-out METHODS SLIDE. Off-property (irrigation country) minus on-property (Gayini) "
     "mean CTV % by Landsat sensor era: L5-only 1988-99 +0.7; L5+L7 2000-02 -7.2; L5deg+L7 2003-10 "
     "-0.3; L7-only 2011-12 -0.1; L8+L7 2013-21 -2.4; L8+L9 2022-25 +9.2. Distinguishable only in "
     "the last (best-sensor) era. support_level=mixed. " + CAP),
    ("T12_DEA_persistence_map", "T12_DEA_persistence_map.png",
     "DEA Land Cover (modelled) — CTV persistence fraction 1988-2025 (landscape; no cadastre)",
     "mixed",
     "T12 close-out map. Per-pixel CTV persistence fraction, full raster extent. Off-property "
     "disclosure constraint observed: landscape scale, no property/paddock boundaries, no holdings "
     "named. support_level=mixed. " + CAP),
    ("T12_DEA_class_snapshots", "T12_DEA_class_snapshots.png",
     "DEA Land Cover Level 3 (modelled) — class snapshots 1990 / 2005 / 2016 / 2024",
     "mixed",
     "T12 close-out map. Level 3 class, official QML palette (CTV #acbc2d, NTV #0e7912, NS #f3ab69, "
     "Water #4d9fdc), four years. Shows the year-to-year instability of the CTV class. Off-property "
     "disclosure constraint observed: landscape scale, no cadastre, no holdings named. " + CAP),
]
COLS = ["figure_asset_id", "path", "title", "domain", "metric_id", "recommended_use",
        "checksum_sha256", "path_exists", "qa_status", "run_id", "superseded_flag",
        "framing_label", "provenance_note", "caption", "support_level", "figure_level"]


def sha256_first50(p: Path) -> str:
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with p.open("rb") as f:
        while read < cap:
            c = f.read(1024 * 1024)
            if not c:
                break
            h.update(c); read += len(c)
    return h.hexdigest()


def rows():
    out = []
    for fid, fn, title, support, caption in FIGS:
        p = ROOT / "figures" / "diagnostics" / fn
        if not p.is_file():
            raise SystemExit(f"ABORT: {fn} missing; run T12_close_figures.R first.")
        out.append((fid, f"figures/diagnostics/{fn}", title, "dea_landcover", None,
                    "T12 close-out deliverable", sha256_first50(p), 1, "REVIEW", RUN, 0,
                    None, "scripts/13_dea_landcover/T12_close_figures.R", caption, support, "diagnostics"))
    return out


def main(mode):
    rs = rows()
    if mode == "check":
        for r in rs:
            print("[check]", r[0], r[6][:12]); print("[check] NO WRITE."); return
    con = sqlite3.connect(DB.as_posix())
    b = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    con.executemany(f"INSERT OR REPLACE INTO figure_asset ({', '.join(COLS)}) VALUES ({', '.join(['?']*len(COLS))})", rs)
    con.commit()
    a = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    print(f"[execute] figure_asset rows: {b} -> {a}")
    for r in con.execute("SELECT figure_asset_id, support_level FROM figure_asset WHERE run_id='T12_close' ORDER BY 1"):
        print("  ", tuple(r))
    con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
