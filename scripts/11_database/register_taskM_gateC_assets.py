#!/usr/bin/env python3
"""Tier 2 · Task M · Gate C — additive provenance columns, registrations and labels.

WHY THIS EXISTS (not the builder): the DB builder is destructive (unlink + full
rebuild) and would wipe the manually-registered Task H rows, the 68 figure
registrations, and everything this script adds. This registrar performs narrow,
idempotent, additive work and NOTHING else. It never rebuilds, never deletes,
never drops a view, never updates a row outside the sets named below.

Implements spec Tier2_TaskM_deck_evidence_audit_v2.md sections C.1-C.5 under the
Gate B classification (docs/Tier2_TaskM_gateB_classification.md).

Scope, exhaustively:
  C.1  ALTER TABLE ADD COLUMN (nullable, default NULL) on raster_asset,
       figure_asset, report_asset: superseded_flag, framing_label,
       provenance_note; caption on figure_asset; qa_note on census_asset.
  C.2  Register Task J: 12 rasters, 2 J-F figures (verbatim captions),
       10 gate CSVs.
  C.3  Register the 3 census summary CSVs from Output/census/summaries/
       (Gate B D-1: the Output/ copies are canonical).
  C.4  census_asset.qa_status REVIEW -> PASS for census_pixel_8058, with the
       evidence recorded in qa_note.
  C.5  Create v_presentation_headlines_live, sourced from taskM_headline_source
       (new table) and census_stratum. v_presentation_headlines is NOT touched.
  R8   Gate B Rule 8: register the green-share-at-the-floor provenance chain -
       the two native-3577 FC stacks, the substrate CSV, the 2026-07-20 scratch
       artefact, and the output of the new committed script.
  Labels: Gate B Rules 3 and 4 applied to existing asset rows.

Every value published by this script cites the Output/ artefact it came from
(CLAUDE.md standing rule: Output/ is the record; docs/ is never a result).

Usage:
  python scripts/11_database/register_taskM_gateC_assets.py check     # no DB write (default)
  python scripts/11_database/register_taskM_gateC_assets.py execute   # performs the writes

Prerequisites (both committed, both must be run first):
  Rscript scripts/05_ground_cover/04_taskM_green_at_floor_area.R
  Rscript scripts/11_database/taskM_gateC_raster_metadata.R
"""
from __future__ import annotations

import csv
import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RASTER_META = ROOT / "Output" / "tables" / "taskM_gateC_raster_meta.csv"
DRYRUN_CSV = ROOT / "Output" / "tables" / "taskM_gateC_registration_dryrun.csv"
RUN_ID = "taskM_gateC"

# --- Gate B Rule 8, verbatim. Do not paraphrase. ------------------------------
RULE8_NOTE = (
    "Variable: `100 × PV ÷ total_veg > 50` (green share of remaining cover), read "
    "paired in the season setting each pixel's total-veg 5th percentile. EPSG:3577, 30 m, "
    "0.09 ha/px, support ≥ 50 seasons, n = 959,833. Count 71,755 px = 6,458 ha "
    "native-grid. NOT `veg_p05 >= 50`."
)

# --- spec C.2 captions, verbatim. Do not paraphrase. --------------------------
CAPTION_JF1 = "Pixel support. 2018 bank-cut pre/post. Descriptive only — not causal."
CAPTION_JF2 = (
    "Pixel support. Placebo ladder, 25 dates. 2018 residual rank 2 of 25. Flow law "
    "R² = 0.864; +7.51 pp above law. 86% of the pre/post difference is explained by "
    "window wetness. Suggestive, not causal."
)

FRAMING_VOCAB = {"census_8058", "bank_cut_2018", "conservation_2019", "plot_support", "context"}

NEW_COLUMNS = [
    ("raster_asset", "superseded_flag", "INTEGER"),
    ("raster_asset", "framing_label", "TEXT"),
    ("raster_asset", "provenance_note", "TEXT"),
    ("figure_asset", "superseded_flag", "INTEGER"),
    ("figure_asset", "framing_label", "TEXT"),
    ("figure_asset", "provenance_note", "TEXT"),
    ("figure_asset", "caption", "TEXT"),
    ("report_asset", "superseded_flag", "INTEGER"),
    ("report_asset", "framing_label", "TEXT"),
    ("report_asset", "provenance_note", "TEXT"),
    ("census_asset", "qa_note", "TEXT"),
]

CENSUS_QA_NOTE = (
    "PASS 2026-07-24 (Task M Gate C, spec C.4). Evidence: full-file SHA-256 matches the "
    "registered value; 1,080,157 rows; 16 contract columns; per-stratum reconciliation "
    "diff = 0 across all 11 strata; five Gate E figure claims reconciled. Verified by "
    "direct parquet read, recorded in docs/change_reports/taskM_gateA_report.md; source "
    "artefact Output/census/gayini_pixel_census_8058.parquet."
)


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - identical to the builder's method."""
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


def load_raster_meta() -> dict[str, dict]:
    if not RASTER_META.is_file():
        raise SystemExit(
            f"ABORT: {rel(RASTER_META)} missing. Run "
            "scripts/11_database/taskM_gateC_raster_metadata.R first."
        )
    return {r["path"]: r for r in csv.DictReader(RASTER_META.open(encoding="utf-8"))}


# ---------------------------------------------------------------- row builders

def build_figure_rows() -> list[dict]:
    rows: list[dict] = []

    # Gate B Rule 3 + Rule 2: D1 paddock dashboards, PNG canonical.
    d1 = sorted((ROOT / "Output" / "figures" / "dashboards").glob("D1_paddock_*.png"))
    if len(d1) != 21:
        raise SystemExit(f"ABORT: expected 21 D1 paddock PNGs, found {len(d1)}")
    for p in d1:
        stem = p.stem
        rows.append(dict(
            figure_asset_id=f"figure_d1_paddock_{stem.replace('D1_paddock_', '')}",
            path=rel(p), title=stem.replace("_", " "), domain="paddock_dashboard",
            metric_id=None, recommended_use="review_or_reporting",
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, superseded_flag=0, framing_label="plot_support",
            provenance_note="Gate B Rule 3. PNG canonical; the PDF sibling is a print "
                            "artefact of the same figure and is not registered (Rule 2).",
            caption=None))

    # Gate B Rule 3 + Rule 2: per-paddock checkerboards, PNG canonical.
    c1 = sorted((ROOT / "Output" / "figures").glob("C1_veg_regime_paddock_*.png"))
    if len(c1) != 21:
        raise SystemExit(f"ABORT: expected 21 C1 paddock PNGs, found {len(c1)}")
    for p in c1:
        name = p.stem.replace("C1_veg_regime_paddock_", "").replace("_data", "")
        rows.append(dict(
            figure_asset_id=f"figure_c1_veg_regime_paddock_{name}",
            path=rel(p), title=p.stem.replace("_", " "), domain="paddock_checkerboard",
            metric_id=None, recommended_use="review_or_reporting",
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, superseded_flag=0, framing_label="census_8058",
            provenance_note="Gate B Rule 3. PNG canonical; the PDF sibling is not "
                            "registered (Rule 2).",
            caption=None))

    # spec C.2: the two Task J figures, captions verbatim.
    tj = ROOT / "Output" / "figures" / "maps" / "task_J"
    for fid, fname, cap in [
        ("figure_taskJ_F1", "J-F1_2018_difference_map.png", CAPTION_JF1),
        ("figure_taskJ_F2", "J-F2_placebo_ladder_six_panel.png", CAPTION_JF2),
    ]:
        p = tj / fname
        if not p.is_file():
            raise SystemExit(f"ABORT: missing {rel(p)}")
        rows.append(dict(
            figure_asset_id=fid, path=rel(p), title=p.stem.replace("_", " "),
            domain="task_J_bank_cut", metric_id=None,
            recommended_use="review_or_reporting", checksum_sha256=sha256_first50(p),
            path_exists=1, qa_status="REVIEW", run_id=RUN_ID, superseded_flag=0,
            framing_label="bank_cut_2018",
            provenance_note="Gate B Rule 5. Caption is verbatim per spec C.2 and must "
                            "not be paraphrased.",
            caption=cap))
    return rows


def build_raster_rows() -> list[dict]:
    meta = load_raster_meta()
    rows: list[dict] = []

    # Gate B Rule 5: the Task J difference rasters.
    tj = sorted((ROOT / "Output" / "rasters" / "task_J").glob("*.tif"))
    if len(tj) != 12:
        raise SystemExit(f"ABORT: expected 12 Task J rasters, found {len(tj)}")
    for p in tj:
        m = meta[rel(p)]
        rows.append(dict(
            raster_asset_id=f"raster_taskJ_{p.stem}", path=rel(p),
            metric_id=None, water_year=None, period_label="2018_bank_cut_single_date",
            crs=m["crs"], resolution_x=float(m["resolution_x"]),
            resolution_y=float(m["resolution_y"]), xmin=float(m["xmin"]),
            ymin=float(m["ymin"]), xmax=float(m["xmax"]), ymax=float(m["ymax"]),
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, crs_epsg=int(m["crs_epsg"]), product="task_J_difference_pp",
            legend_status="confirmed",
            legend_semantics="post-minus-pre inundation difference, percentage points. "
                             "2018 bank-cut analysis; descriptive only, not causal. "
                             "DISTINCT from the retired 2019 pre/post framing "
                             "(raster_00007).",
            superseded_flag=0, framing_label="bank_cut_2018",
            provenance_note="Gate B Rule 5."))

    # Gate B Rule 8: the two native-3577 FC stacks - the substrate of the floor chain.
    for rid, fname in [
        ("raster_fc_total_veg_3577_stack", "fc_total_veg_3577_wy1988_2023.tif"),
        ("raster_fc_pv_3577_stack", "fc_pv_3577_wy1988_2023.tif"),
    ]:
        p = ROOT / "Output" / "rasters" / "fc_intermediate" / fname
        if not p.is_file():
            raise SystemExit(f"ABORT: missing {rel(p)}")
        m = meta[rel(p)]
        rows.append(dict(
            raster_asset_id=rid, path=rel(p), metric_id=None,
            water_year="WY1988-2023", period_label="seasonal_140_layer",
            crs=m["crs"], resolution_x=float(m["resolution_x"]),
            resolution_y=float(m["resolution_y"]), xmin=float(m["xmin"]),
            ymin=float(m["ymin"]), xmax=float(m["xmax"]), ymax=float(m["ymax"]),
            checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, crs_epsg=int(m["crs_epsg"]),
            product="fc_seasonal_stack_3577",
            legend_status="confirmed",
            legend_semantics="Landsat fractional cover, percent. 140 seasonal layers, "
                             "water years 1988-2023. EPSG code is INFERRED from the "
                             "proj4 parameters (GDA94 Australian Albers); the file "
                             "carries no authority code on its PROJCRS node - see "
                             "Output/tables/taskM_gateC_raster_meta.csv.",
            superseded_flag=0, framing_label="census_8058",
            provenance_note=RULE8_NOTE))
    return rows


def build_report_rows() -> list[dict]:
    rows: list[dict] = []

    def add(rid, path: Path, title, rtype, framing, note, superseded=0):
        if not path.is_file():
            raise SystemExit(f"ABORT: missing {rel(path)}")
        rows.append(dict(
            report_asset_id=rid, path=rel(path), title=title, report_type=rtype,
            checksum_sha256=sha256_first50(path), path_exists=1, qa_status="REVIEW",
            run_id=RUN_ID, superseded_flag=superseded, framing_label=framing,
            provenance_note=note))

    # spec C.2 / Gate B Rule 5: the ten Task J gate CSVs.
    tj = sorted((ROOT / "Output" / "tables").glob("task_J_gate*.csv"))
    if len(tj) != 10:
        raise SystemExit(f"ABORT: expected 10 Task J gate CSVs, found {len(tj)}")
    for p in tj:
        add(f"report_taskJ_{p.stem.replace('task_J_', '')}", p,
            p.stem.replace("_", " "), "evidence_table", "bank_cut_2018",
            "Gate B Rule 5. Task J 2018 bank-cut evidence table. Suggestive, not causal.")

    # spec C.3 / Gate B D-1: Output/census/summaries/ is canonical.
    cs = sorted((ROOT / "Output" / "census" / "summaries").glob("*.csv"))
    if len(cs) != 3:
        raise SystemExit(f"ABORT: expected 3 census summary CSVs, found {len(cs)}")
    for p in cs:
        add(f"report_census_summary_{p.stem.replace('census_', '')}", p,
            p.stem.replace("_", " "), "census_summary_table", "census_8058",
            "Gate B D-1: the Output/ copy is canonical. The docs/census_summaries/ "
            "duplicate is recorded as superseded in "
            "Output/tables/taskM_gateC_file_classification.csv and is deliberately "
            "NOT registered - docs/ is not a product tree.")

    # C.5 dependency: the F6 census verdicts the live headline view publishes.
    add("report_census_f6_verdicts",
        ROOT / "Output" / "diagnostics" / "tier2H_h32_census_f6_verdicts.csv",
        "tier2H h32 census f6 verdicts", "evidence_table", "census_8058",
        "Registered because v_presentation_headlines_live publishes counts derived "
        "from it; the standing rule requires every published number to cite a "
        "registered Output/ artefact. Scope addition beyond Gate B, flagged in the "
        "Gate C report.")

    # Gate B Rule 8: the floor-chain CSVs, all three carrying the definition.
    add("report_green_at_floor_substrate",
        ROOT / "Output" / "diagnostics" / "tier2H_h2_green_fraction_at_floor.csv",
        "tier2H h2 green fraction at floor", "evidence_table", "census_8058",
        "Gate B Rule 8. Substrate summary emitted by "
        "scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R. " + RULE8_NOTE)
    add("report_green_at_floor_area_scratch",
        ROOT / "Output" / "diagnostics" / "ondisk_review_20260720" / "refugia_area_check.csv",
        # Title states the variable, not the withdrawn label. The filename on disk
        # keeps its original wording; renaming it would not be additive.
        "green share at floor - area check (2026-07-20 on-disk review scratch)",
        "evidence_table",
        "census_8058",
        "Gate B Rule 8. Produced interactively on 2026-07-20; superseded as the "
        "provenance path by Output/tables/taskM_green_at_floor_area.csv, which a "
        "committed script rebuilds. Registered so the traced artefact is visible. "
        + RULE8_NOTE)
    add("report_green_at_floor_area",
        ROOT / "Output" / "tables" / "taskM_green_at_floor_area.csv",
        "taskM green at floor area", "evidence_table", "census_8058",
        "Gate B Rule 8. Emitted by the committed script "
        "scripts/05_ground_cover/04_taskM_green_at_floor_area.R, which reuses "
        "green_at_floor() verbatim and asserts that at run time. This is the link "
        "that was missing from git. " + RULE8_NOTE)
    return rows


# ------------------------------------------------------------------ C.5 source

def build_headline_rows(con: sqlite3.Connection) -> list[dict]:
    """Headline values, each carrying the Output/ artefact it was read from."""
    rows: list[dict] = []

    def add(hid, name, value, units, support, artefact, asset_id, caveat):
        rows.append(dict(headline_id=hid, headline_name=name, value=str(value),
                         units=units, support=support, source_artefact=artefact,
                         source_asset_id=asset_id, framing_label="census_8058",
                         caveat=caveat, run_id=RUN_ID))

    parquet = "Output/census/gayini_pixel_census_8058.parquet"

    n_px, mapped_ha, farm_ha = con.execute(
        "SELECT SUM(n_pixels), ROUND(SUM(area_ha), 3), MAX(farm_area_total_ha) "
        "FROM census_stratum").fetchone()
    add("census_pixel_count", "Census pixels", n_px, "pixels", "pixel_census",
        parquet, "census_pixel_8058",
        "All-pixel census, EPSG:8058, 24.97 m. Pixels are NOT independent n "
        "(spatial and temporal autocorrelation).")
    add("census_mapped_area_ha", "Mapped area", mapped_ha, "ha", "pixel_census",
        parquet, "census_pixel_8058",
        "Mapped basis. The farm total is the separate headline below.")
    add("farm_area_total_ha", "Farm area (true total)", farm_ha, "ha", "pixel_census",
        parquet, "census_pixel_8058",
        "True farm area; the mapped basis covers 78.39% of it.")

    means_csv = ROOT / "Output" / "census" / "summaries" / "census_community_flood_freq_means.csv"
    focus = ["Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
             "Inland Floodplain Shrublands / Swamps"]
    got = {r["community"]: r for r in csv.DictReader(means_csv.open(encoding="utf-8"))}
    for community in focus:
        if community not in got:
            raise SystemExit(f"ABORT: {community!r} absent from {rel(means_csv)}")
        slug = community.split()[0].lower()
        add(f"census_flood_freq_mean_{slug}",
            f"Mean between-year flood frequency - {community}",
            round(float(got[community]["mean_flood_freq_pct"]), 4), "percent",
            "pixel_census", rel(means_csv),
            "report_census_summary_community_flood_freq_means",
            "Pixel support (24.97 m census pixel). NEVER compare with the plot-support "
            "figures 9 / 22 / 50, which answer a different question (C10).")

    verdicts_csv = ROOT / "Output" / "diagnostics" / "tier2H_h32_census_f6_verdicts.csv"
    counts: dict[str, int] = {}
    for r in csv.DictReader(verdicts_csv.open(encoding="utf-8")):
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    for verdict, label in [("no_trend", "no trend"),
                           ("non_stationary", "non-stationary"),
                           ("directional", "directional")]:
        add(f"f6_census_verdict_{verdict}", f"F6 census strata - {label}",
            counts.get(verdict, 0), "strata", "pixel_census", rel(verdicts_csv),
            "report_census_f6_verdicts",
            "Census verdict over the 9 focus strata. Supersedes the plot-support "
            "8/1/0; ratification with Adrian is the open I.2 item.")
    return rows


HEADLINE_TABLE_DDL = """
CREATE TABLE IF NOT EXISTS taskM_headline_source (
    headline_id     TEXT PRIMARY KEY,
    headline_name   TEXT NOT NULL,
    value           TEXT NOT NULL,
    units           TEXT,
    support         TEXT NOT NULL CHECK (support IN ('pixel_census', 'plot')),
    source_artefact TEXT NOT NULL,
    source_asset_id TEXT,
    framing_label   TEXT,
    caveat          TEXT,
    run_id          TEXT
)
"""

# Additive: v_presentation_headlines is left in place, untouched (spec C.5).
# conservation_2019 is excluded by an explicit predicate rather than by absence,
# so the exclusion is testable. mean_inundation_change_pp has no row here at all.
LIVE_VIEW_DDL = """
CREATE VIEW v_presentation_headlines_live AS
SELECT headline_id, headline_name, value, units, support,
       source_artefact, source_asset_id, caveat
FROM taskM_headline_source
WHERE COALESCE(framing_label, '') <> 'conservation_2019'
  AND headline_id <> 'mean_inundation_change_pp'
"""


# ----------------------------------------------------------------------- labels

def label_updates(con: sqlite3.Connection) -> list[tuple[str, str, tuple]]:
    """(description, sql, params) for Gate B Rules 3 and 4. UPDATEs only these sets."""
    ups = []
    ups.append((
        "Rule 3: figure_asset run_id='gateE_20260721' -> census_8058 / live",
        "UPDATE figure_asset SET framing_label='census_8058', superseded_flag=0 "
        "WHERE run_id='gateE_20260721'", ()))
    ups.append((
        "Rule 3: figure_asset run_id='d2_site_dashboard_batch_20260720' -> plot_support / live",
        "UPDATE figure_asset SET framing_label='plot_support', superseded_flag=0 "
        "WHERE run_id='d2_site_dashboard_batch_20260720'", ()))
    ups.append((
        "Rule 3: figure_asset run_id='db_build_20260701_114458' -> context / superseded",
        "UPDATE figure_asset SET framing_label='context', superseded_flag=1 "
        "WHERE run_id='db_build_20260701_114458'", ()))
    ups.append((
        "Rule 4: raster_asset pre_vs_post OR under inundation_pre_post/ -> "
        "conservation_2019 / superseded",
        "UPDATE raster_asset SET framing_label='conservation_2019', superseded_flag=1 "
        "WHERE period_label='pre_vs_post' "
        "   OR path LIKE 'Output/rasters/inundation_pre_post/%'", ()))
    return ups


# ------------------------------------------------------------------------- main

def existing_columns(con: sqlite3.Connection, table: str) -> set[str]:
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def write_dryrun_csv(fig, ras, rep, head) -> None:
    DRYRUN_CSV.parent.mkdir(parents=True, exist_ok=True)
    cols = ["target_table", "asset_id", "path", "framing_label", "superseded_flag",
            "checksum_sha256", "run_id"]
    with DRYRUN_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for table, rows, idc in [("figure_asset", fig, "figure_asset_id"),
                                 ("raster_asset", ras, "raster_asset_id"),
                                 ("report_asset", rep, "report_asset_id")]:
            for r in rows:
                w.writerow({"target_table": table, "asset_id": r[idc],
                            "path": r["path"], "framing_label": r["framing_label"],
                            "superseded_flag": r["superseded_flag"],
                            "checksum_sha256": r["checksum_sha256"],
                            "run_id": r["run_id"]})
        for r in head:
            w.writerow({"target_table": "taskM_headline_source",
                        "asset_id": r["headline_id"], "path": r["source_artefact"],
                        "framing_label": r["framing_label"], "superseded_flag": 0,
                        "checksum_sha256": "", "run_id": r["run_id"]})


def insert_rows(con, table, idc, rows) -> int:
    if not rows:
        return 0
    cols = list(rows[0].keys())
    ph = ", ".join(["?"] * len(cols))
    before = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    con.executemany(
        f"INSERT OR IGNORE INTO {table} ({', '.join(cols)}) VALUES ({ph})",
        [tuple(r[c] for c in cols) for r in rows])
    after = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    return after - before


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")

    fig = build_figure_rows()
    ras = build_raster_rows()
    rep = build_report_rows()

    for rows, idc in [(fig, "figure_asset_id"), (ras, "raster_asset_id"),
                      (rep, "report_asset_id")]:
        for r in rows:
            if r["framing_label"] not in FRAMING_VOCAB:
                raise SystemExit(f"ABORT: {r[idc]} has framing_label "
                                 f"{r['framing_label']!r} outside the controlled vocabulary")
            if r["superseded_flag"] not in (0, 1):
                raise SystemExit(f"ABORT: {r[idc]} superseded_flag not 0/1")
            for col in ("path", "checksum_sha256", "path_exists"):
                if r[col] in (None, ""):
                    raise SystemExit(f"ABORT: {r[idc]} empty required column {col!r}")
        ids = [r[idc] for r in rows]
        if len(set(ids)) != len(ids):
            raise SystemExit(f"ABORT: duplicate ids in {idc}")

    uri = f"file:{DB.as_posix()}?mode=ro" if mode == "check" else DB.as_posix()
    con = sqlite3.connect(uri, uri=(mode == "check"))
    try:
        head = build_headline_rows(con)
        write_dryrun_csv(fig, ras, rep, head)

        if mode == "check":
            print(f"[check] figure rows to insert : {len(fig)}")
            print(f"[check] raster rows to insert : {len(ras)}")
            print(f"[check] report rows to insert : {len(rep)}")
            print(f"[check] headline source rows  : {len(head)}")
            missing = [(t, c) for t, c, _ in NEW_COLUMNS
                       if c not in existing_columns(con, t)]
            print(f"[check] columns to add        : {len(missing)} {missing}")
            print("[check] label updates          :")
            for desc, sql, _ in label_updates(con):
                where = sql.split("WHERE", 1)[1]
                tbl = sql.split()[1]
                n = con.execute(f"SELECT COUNT(*) FROM {tbl} WHERE {where}").fetchone()[0]
                print(f"           {n:>4} rows  <- {desc}")
            print(f"[check] dry-run CSV written    : {rel(DRYRUN_CSV)}")
            print("[check] NO DB WRITE performed.")
            return

        # ---- execute -------------------------------------------------------
        added_cols = 0
        for table, col, typ in NEW_COLUMNS:
            if col not in existing_columns(con, table):
                con.execute(f"ALTER TABLE {table} ADD COLUMN {col} {typ}")
                added_cols += 1
        con.commit()
        print(f"[execute] C.1 columns added: {added_cols}")

        con.execute(
            "INSERT OR IGNORE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 1, 'REVIEW')",
            (RUN_ID, "2026-07-24T00:00:00+00:00",
             "scripts/11_database/register_taskM_gateC_assets.py",
             '{"gate": "C", "spec": "docs/Tier2_TaskM_deck_evidence_audit_v2.md"}'))

        n_fig = insert_rows(con, "figure_asset", "figure_asset_id", fig)
        n_ras = insert_rows(con, "raster_asset", "raster_asset_id", ras)
        n_rep = insert_rows(con, "report_asset", "report_asset_id", rep)
        print(f"[execute] C.2/C.3/R8 inserted: figure={n_fig} raster={n_ras} report={n_rep}")

        for desc, sql, params in label_updates(con):
            cur = con.execute(sql, params)
            print(f"[execute] labelled {cur.rowcount:>4} rows  <- {desc}")

        cur = con.execute(
            "UPDATE census_asset SET qa_status='PASS', qa_note=? "
            "WHERE census_asset_id='census_pixel_8058' AND qa_status='REVIEW'",
            (CENSUS_QA_NOTE,))
        print(f"[execute] C.4 census_asset promoted to PASS: {cur.rowcount} row")

        con.execute(HEADLINE_TABLE_DDL)
        cols = list(head[0].keys())
        ph = ", ".join(["?"] * len(cols))
        con.executemany(
            f"INSERT OR IGNORE INTO taskM_headline_source ({', '.join(cols)}) VALUES ({ph})",
            [tuple(r[c] for c in cols) for r in head])
        n_head = con.execute("SELECT COUNT(*) FROM taskM_headline_source").fetchone()[0]
        exists = con.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='view' "
            "AND name='v_presentation_headlines_live'").fetchone()[0]
        if not exists:
            con.execute(LIVE_VIEW_DDL)
        con.commit()
        print(f"[execute] C.5 taskM_headline_source rows={n_head}; "
              f"v_presentation_headlines_live {'already present' if exists else 'created'}")

        legacy = con.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='view' "
            "AND name='v_presentation_headlines'").fetchone()[0]
        print(f"[execute] assertion 8 - v_presentation_headlines still present: {legacy == 1}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
