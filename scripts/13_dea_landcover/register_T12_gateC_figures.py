#!/usr/bin/env python3
"""T12 · Gate C — register the four diagnostic figures in figure_asset (additive).

Same-session registration (figures written by T12_gateC_diagnostics.R this run), so
the R-write / Python-register split that the write_and_register_figure() convention
guards against does not apply. Uses the first-50-MB SHA-256 convention (NOT R's
whole-file digest). INSERT OR REPLACE keyed on figure_asset_id; idempotent.

Usage: python scripts/13_dea_landcover/register_T12_gateC_figures.py [check|execute]
"""
from __future__ import annotations
import hashlib, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RUN = "T12_gateC"
CAP = ("DEA Land Cover is a modelled national product, not a record of land use. "
       "Not independent of the Gayini census.")

FIGS = [
    ("T12_DEA_gateC_persistence_full", "T12_DEA_persistence_fraction_full_1988_2025.png",
     "DEA Land Cover (modelled) — CTV persistence, full record 1988-2025 (on-property)",
     "pixel_within_property_dea_l3",
     "Gate C item 1 (RESULT). Per-pixel CTV persistence fraction = CTV years / valid years, "
     "on-property, 1988-2025. Broad unimodal (peak ~0.5), decays to ~0 above 0.75; "
     "no separated high-persistence mode under the §2.9.3 rule (KDE-smoothed). " + CAP),
    ("T12_DEA_gateC_persistence_pilot", "T12_DEA_persistence_fraction_pilot_8yr.png",
     "DEA Land Cover (modelled) — CTV persistence, 8-year pilot subset (reconciliation only)",
     "pixel_within_property_dea_l3",
     "Gate C item 1 (RECONCILIATION ONLY, not evidence). 8-year pilot; ever-CTV 75.86% "
     "reproduces the design-seat pilot. Discrete k/8 fractions - granularity artifacts expected. " + CAP),
    ("T12_DEA_gateC_farm_ctv_vs_flood_veg", "T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png",
     "DEA Land Cover (modelled) — farm CTV vs flood & veg, 1988-2025",
     "mixed",
     "Gate C item 2. Property CTV% (calendar yr) against area-weighted flood_frac% and "
     "veg_mean (water yr). Adjacent-year CTV swing 7.58x (>3x). support_level=mixed "
     "(DEA property CTV + census property flood/veg). " + CAP),
    ("T12_DEA_gateC_positive_control", "T12_DEA_positive_control.png",
     "DEA Land Cover (modelled) — CTV persistence, on-property vs off-property control (§2.10)",
     "mixed",
     "Gate C item 7 positive control. Off-property = raster extent - property - 500 m buffer "
     "(scope=off_property_control; never a Gayini denominator). Control high-persistence tail "
     "(>=0.75: 5.6%, reaches frac=1.0) vs on-property (1.2%, decays to ~0 by 0.875): the CTV "
     "class registers persistent cultivation where it exists; Gayini lacks it. support_level=mixed. " + CAP),
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
            raise SystemExit(f"ABORT: {fn} not found; run the R diagnostics first.")
        out.append({
            "figure_asset_id": fid, "path": f"figures/diagnostics/{fn}", "title": title,
            "domain": "dea_landcover", "metric_id": None,
            "recommended_use": "T12 Gate C diagnostic pack (STOP gate)",
            "checksum_sha256": sha256_first50(p), "path_exists": 1, "qa_status": "REVIEW",
            "run_id": RUN, "superseded_flag": 0, "framing_label": None,
            "provenance_note": "scripts/13_dea_landcover/T12_gateC_diagnostics.R (spec v4 Gate C)",
            "caption": caption, "support_level": support, "figure_level": "diagnostics"})
    return out


def main(mode):
    rs = rows()
    if mode == "check":
        for r in rs:
            print(f"[check] {r['figure_asset_id']} sha={r['checksum_sha256'][:12]} support={r['support_level']}")
        print("[check] NO DB WRITE."); return
    con = sqlite3.connect(DB.as_posix())
    ph = ", ".join(["?"] * len(COLS))
    before = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    con.executemany(f"INSERT OR REPLACE INTO figure_asset ({', '.join(COLS)}) VALUES ({ph})",
                    [tuple(r[c] for c in COLS) for r in rs])
    con.commit()
    after = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    print(f"[execute] figure_asset rows: {before} -> {after}")
    for r in con.execute("SELECT figure_asset_id, path, support_level, figure_level, substr(checksum_sha256,1,12) "
                         "FROM figure_asset WHERE run_id='T12_gateC' ORDER BY figure_asset_id"):
        print("  ", tuple(r))
    con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
