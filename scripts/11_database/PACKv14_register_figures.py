#!/usr/bin/env python3
"""Pack v1.4 - register the four figures that newly ship. AUTHORISED 7 Aug 2026.

Three single-page residual maps, plus the bootstrap distribution figure - which stays
unregistered unless it ships in a pack, and in v1.4 it does.

The manifest must distinguish the single pages from the three-panel figure, so each row
says which it is and every caption names its support level. INSERT OR REPLACE.
"""
import hashlib, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
F = ROOT / "Output" / "figures"
RUN = "packv14_20260807"

MAPCAP = ("Support: pixel, aggregated to part. ONE PERIOD PER PAGE - the single-page companion to "
          "the three-panel figure, which is legible as a set and illegible one panel at a time. "
          "Residual from the fitted cover-and-water expectation on the 115 paddock x community "
          "parts, measured against THIS period's own fitted line. Identical colour scale and ticks "
          "to the three-panel figure and to the other two single pages, read from one constant so "
          "they cannot diverge. Per-part residuals are labelled in percentage points, legible at "
          "full page. 8.08 pp is the average miss across all parts, not the typical miss anywhere: "
          "scatter is about three times larger on the driest quarter than the wettest. Compare a "
          "part to others at similar wetness, not to the whole map. No cause is attributed.")
BOOTCAP = ("Support: pixel, aggregated to part. How much the fitted slope moves when the PADDOCKS "
           "are resampled - not how often the observed slope was found, since the resampling is "
           "centred on it by construction. Panel A: the pooled 115-part line against the three "
           "community fits; both chenopod distributions are wide and include zero, and Aeolian is "
           "badly skewed - observed -0.309 against a bootstrap median of -0.625. Panel B: paddock "
           "grain against part grain, almost entirely superimposed. 2,000 draws clustered on "
           "zone_fid, seed recorded; 64 clusters, not 115 observations, bound the precision. "
           "Recovered draws reproduce the registered percentiles exactly. Panel A is clipped and "
           "out-of-range draws are dropped, not stacked. No p-values.")

ROWS = [(f"figure_partreg_s2_residual_map_{c}",
         F / f"PARTREG_S2_residual_map_{c}.png",
         f"Which parts hold more or less cover than their water predicts - {t}, single page",
         MAPCAP, "diagnostics",
         "Producer scripts/12_zone_stratum/PARTREG_stage2_maps_and_export.py, the same loop and the "
         "same RLIM/CMAP/tick constants as the three-panel figure. SINGLE-PAGE companion, not a "
         "replacement: the three-panel figure remains the set view.")
        for c, t in (("whole_record", "whole record 1988-2022"),
                     ("cropping_era", "cropping era 1988-2013"),
                     ("post_management", "post-management 2018-2022"))]
ROWS.append(("figure_fig2_bootstrap_slope_distributions",
             F / "FIG2_bootstrap_slope_distributions.png",
             "How much the fitted slope moves when the paddocks are resampled",
             BOOTCAP, "diagnostics",
             "Producer scripts/12_zone_stratum/FIG2_bootstrap_distribution.py. Re-runs the recorded "
             "bootstrap with its seed to recover the draws and ASSERTS the recovered 2.5/50/97.5 "
             "percentiles against the stored values before plotting; it halts rather than draw a "
             "histogram whose bounds disagree with the interval printed beside it. Registered "
             "because it ships in pack v1.4."))


def sha50(p):
    h, n = hashlib.sha256(), 0
    with open(p, "rb") as f:
        while n < 50 * 1024 * 1024:
            b = f.read(1024 * 1024)
            if not b: break
            h.update(b); n += len(b)
    return h.hexdigest()


mode = sys.argv[1] if len(sys.argv) > 1 else "check"
for fid, p, *_ in ROWS:
    if not p.exists(): print(f"FAIL missing {p}"); raise SystemExit(1)
for *_, cap, _, _ in [(r[0], r[1], r[2], r[3], r[4], r[5]) for r in ROWS]:
    pass
con = sqlite3.connect(DB); cur = con.cursor()
before = cur.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
print(f"  figure_asset before: {before}")
for fid, p, title, cap, lvl, prov in ROWS:
    assert "support" in cap.lower(), fid
    print(f"    {fid:<48s} {p.stat().st_size/1024:>6.0f} KB")
if mode != "execute":
    print("\ncheck only - no write.")
else:
    cur.executemany("""INSERT OR REPLACE INTO figure_asset
        (figure_asset_id, path, title, domain, metric_id, recommended_use, checksum_sha256,
         path_exists, qa_status, run_id, superseded_flag, framing_label, provenance_note,
         caption, support_level, figure_level) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        [(fid, p.relative_to(ROOT).as_posix(), title, "zone_diagnostics", None, "deliverable",
          sha50(p), 1, "REVIEW", RUN, 0, "census_8058", prov, cap, "pixel", lvl)
         for fid, p, title, cap, lvl, prov in ROWS])
    con.commit()
    after = cur.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
    print(f"\n  figure_asset {before} -> {after}  ({after-before:+d})")
con.close()
