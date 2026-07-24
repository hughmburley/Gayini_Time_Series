#!/usr/bin/env python3
"""Tier 2 · Task M · Gate D §D.5 — register the two new figures, the two live-but-
uncaptioned Task J figures (with DRAFT captions), and the Gate D evidence tables.

WHY NOT THE BUILDER: the builder is destructive. This registrar is narrow, additive
and idempotent (INSERT OR IGNORE on the primary key). It re-uses the provenance
columns Gate C added; it does not ALTER anything.

Registers into figure_asset:
  M1_veg_percentile_maps_p05_p50.png   framing_label=census_8058
  M2_all_pixel_method.png              framing_label=census_8058
  J-F3_the_law.png                     framing_label=bank_cut_2018  DRAFT caption
  J-F4_annual_series.png               framing_label=bank_cut_2018  DRAFT caption

Registers into report_asset (Gate D evidence tables, census_8058):
  taskM_gateD_veg_p05_distribution.csv
  taskM_gateD_p05_ge80_contiguity.csv

The two J-F captions are DRAFT and flagged for human review (Gate B v2 Rule 5): they
carry the same causal-inference discipline as the C.2 captions — descriptive, not
causal, pixel support labelled — but they are proposals, not settled text.

Usage:
  python scripts/11_database/register_taskM_gateD_assets.py check     # no DB write (default)
  python scripts/11_database/register_taskM_gateD_assets.py execute
"""
from __future__ import annotations

import csv
import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
DRYRUN = ROOT / "Output" / "tables" / "taskM_gateD_registration_dryrun.csv"
RUN_ID = "taskM_gateD"

# Draft captions — flagged for human review (Gate B v2 Rule 5). Not settled.
CAPTION_JF3_DRAFT = (
    "DRAFT — pixel support. 2018 bank-cut pre/post placebo law. Between-year "
    "flood-frequency change against log(post/pre flow ratio) across 25 cut dates; law "
    "fitted on the 24 placebos with 2018 excluded, R² = 0.864. 2018 residual +7.51 pp, "
    "rank 2 of 25. The band is ±1 residual SD (descriptive spread), NOT a confidence "
    "interval — only 5 of 25 dates are independent. Suggestive, not causal."
)
CAPTION_JF4_DRAFT = (
    "DRAFT — pixel support. Whole-farm per-water-year wet extent and gauge 410040 mean "
    "flow, 1988–2022. Wet extent is per-year spatial coverage, NOT the headline "
    "between-year flood frequency. Shaded = the post-2018 window. Descriptive context "
    "only — not causal."
)
CAPTION_M1 = (
    "Two-panel veg-percentile map: p05 (the floor) and p50 (typical), one shared 0–100 "
    "cover scale. All-pixel census, EPSG:8058, 24.97 m. Percentiles plotted as measured "
    "and never differenced. Landsat FC measures cover, not ecological condition."
)
CAPTION_M2 = (
    "Method schematic: the shift from 66 one-hectare plots to the 1,080,157-pixel census, "
    "the 11 strata (3 communities × 3 wetness bands + 2 context), and the 67,349.3 ha "
    "mapped of the 85,910.8 ha farm (78.4%). The census removes sampling uncertainty "
    "only; ~1M pixels are not independent n."
)


def sha256_first50(path: Path) -> str:
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


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def build_figures() -> list[dict]:
    figs = ROOT / "Output" / "figures"
    spec = [
        ("figure_taskM_M1_percentile_maps", figs / "M1_veg_percentile_maps_p05_p50.png",
         "M1 veg percentile maps p05 p50", "census_map", "census_8058", CAPTION_M1,
         "Gate D §D.1. Built by scripts/07_figures_dashboards/"
         "taskM_gateD_M1_percentile_maps.R from raster_vegpct_p05 / raster_vegpct_p50."),
        ("figure_taskM_M2_all_pixel_method", figs / "M2_all_pixel_method.png",
         "M2 all pixel method", "method_schematic", "census_8058", CAPTION_M2,
         "Gate D §D.4. Built by scripts/07_figures_dashboards/taskM_gateD_M2_method.R; "
         "every number read live from census_stratum / dim_plot."),
        ("figure_taskJ_F3", figs / "plots" / "task_J" / "J-F3_the_law.png",
         "J-F3 the flow law", "task_J_bank_cut", "bank_cut_2018", CAPTION_JF3_DRAFT,
         "Gate B v2 Rule 5. DRAFT caption flagged for human review — descriptive, not "
         "causal, pixel support labelled. Evidence: report_taskJ_gate4_law_summary, "
         "report_taskJ_gate4_residual_ranking."),
        ("figure_taskJ_F4", figs / "plots" / "task_J" / "J-F4_annual_series.png",
         "J-F4 annual series", "task_J_bank_cut", "bank_cut_2018", CAPTION_JF4_DRAFT,
         "Gate B v2 Rule 5. DRAFT caption flagged for human review — descriptive, not "
         "causal, pixel support labelled."),
    ]
    rows = []
    for fid, p, title, domain, framing, caption, note in spec:
        if not p.is_file():
            raise SystemExit(f"ABORT: missing {rel(p)}")
        rows.append(dict(
            figure_asset_id=fid, path=rel(p), title=title, domain=domain,
            metric_id=None, recommended_use="review_or_reporting",
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, superseded_flag=0, framing_label=framing,
            provenance_note=note, caption=caption))
    return rows


def build_reports() -> list[dict]:
    tables = ROOT / "Output" / "tables"
    spec = [
        ("report_taskM_gateD_p05_distribution",
         tables / "taskM_gateD_veg_p05_distribution.csv",
         "taskM gateD veg p05 distribution (dual grid)",
         "Gate D §D.2. Dual-grid (census 24.97 m + native 30 m) distribution of veg_p05 "
         "(TOTAL COVER at the floor). Reports the distribution; does NOT settle the "
         "green-share hectare figure (that is report_green_at_floor_area). Built by "
         "scripts/11_database/taskM_gateD_p05_distribution.py."),
        ("report_taskM_gateD_p05_ge80_contiguity",
         tables / "taskM_gateD_p05_ge80_contiguity.csv",
         "taskM gateD p05 >= 80 contiguity",
         "Gate D §D.3. 8-connectivity component report for veg_p05 >= 80. Threshold "
         "chosen only to make the 4,179.3 ha figure checkable; carries no ecological "
         "meaning and is not a class. Built by scripts/05_ground_cover/"
         "06_taskM_gateD_p05_ge80_contiguity.R."),
    ]
    rows = []
    for rid, p, title, note in spec:
        if not p.is_file():
            raise SystemExit(f"ABORT: missing {rel(p)}")
        rows.append(dict(
            report_asset_id=rid, path=rel(p), title=title, report_type="evidence_table",
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, superseded_flag=0, framing_label="census_8058",
            provenance_note=note))
    return rows


def insert(con, table, rows) -> int:
    if not rows:
        return 0
    cols = list(rows[0].keys())
    ph = ", ".join(["?"] * len(cols))
    before = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    con.executemany(
        f"INSERT OR IGNORE INTO {table} ({', '.join(cols)}) VALUES ({ph})",
        [tuple(r[c] for c in cols) for r in rows])
    return con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] - before


def write_dryrun(figs, reps) -> None:
    DRYRUN.parent.mkdir(parents=True, exist_ok=True)
    with DRYRUN.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["target_table", "asset_id", "path", "framing_label",
                    "superseded_flag", "checksum_sha256", "run_id"])
        for r in figs:
            w.writerow(["figure_asset", r["figure_asset_id"], r["path"],
                        r["framing_label"], r["superseded_flag"],
                        r["checksum_sha256"], r["run_id"]])
        for r in reps:
            w.writerow(["report_asset", r["report_asset_id"], r["path"],
                        r["framing_label"], r["superseded_flag"],
                        r["checksum_sha256"], r["run_id"]])


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")
    figs = build_figures()
    reps = build_reports()
    write_dryrun(figs, reps)

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        have_cap = "caption" in {r[1] for r in con.execute("PRAGMA table_info(figure_asset)")}
        ef = {r[0] for r in con.execute("SELECT figure_asset_id FROM figure_asset")}
        er = {r[0] for r in con.execute("SELECT report_asset_id FROM report_asset")}
        con.close()
        print(f"[check] figure_asset.caption column present: {have_cap}")
        print(f"[check] figures to insert: {sum(1 for r in figs if r['figure_asset_id'] not in ef)}"
              f" (skip {sum(1 for r in figs if r['figure_asset_id'] in ef)})")
        print(f"[check] reports to insert: {sum(1 for r in reps if r['report_asset_id'] not in er)}"
              f" (skip {sum(1 for r in reps if r['report_asset_id'] in er)})")
        print(f"[check] dry-run: {rel(DRYRUN)}")
        print("[check] NO DB WRITE.")
        return

    con = sqlite3.connect(DB.as_posix())
    try:
        con.execute(
            "INSERT OR IGNORE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 1, 'REVIEW')",
            (RUN_ID, "2026-07-24T00:00:00+00:00",
             "scripts/11_database/register_taskM_gateD_assets.py",
             '{"gate": "D"}'))
        nf = insert(con, "figure_asset", figs)
        nr = insert(con, "report_asset", reps)
        con.commit()
        print(f"[execute] figures inserted={nf}  reports inserted={nr}")
        legacy = con.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='view' "
                             "AND name='v_presentation_headlines'").fetchone()[0]
        print(f"[execute] v_presentation_headlines still present: {legacy == 1}")
        px = con.execute("SELECT COUNT(*), SUM(n_pixels) FROM census_stratum").fetchone()
        print(f"[execute] census_stratum: {px}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
