#!/usr/bin/env python3
"""PARTREG Stage 1 - registration. Additive only.

Spec section 2: "the part x year table and the part summary table, additive, with
number_ids for the headline slope, intercept, r and residual SD. Nothing else until
the design seat has seen the plot."

Scope, exhaustively - and nothing outside it:
  1  fact_part_year_floor_inund          (4,025 rows) - the analysis spine
  2  fact_part_summary_full_period       (115 rows)   - one row per part
  3  table_asset      x3   the two above plus the coefficients CSV
  4  figure_asset     x1   the Stage 1 panel
  5  dim_headline_number x4  slope, intercept, r, residual SD

INSERT OR REPLACE throughout, never OR IGNORE: OR IGNORE looks idempotent while
never updating a changed checksum, so "re-run twice, identical checksums" passes
while the DB is wrong. The two fact tables converge by DELETE-on-run_id then INSERT,
and the script REFUSES to run if an existing table's columns differ from what it is
about to write rather than silently dropping it.

Every registered number carries all five qualifiers as columns - support_level,
scope_filter, pixel_constant, denominator, period_label - plus the spread the value
takes under the defensible alternative (weighted vs unweighted).

Usage:
  python scripts/11_database/PARTREG_stage1_register.py check     # no DB write (default)
  python scripts/11_database/PARTREG_stage1_register.py execute
"""
from __future__ import annotations

import csv
import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
T = ROOT / "Output" / "tables"
FIG = ROOT / "Output" / "figures" / "PARTREG_S1_floor_vs_flood_115_parts.png"
RUN_ID = "partreg_stage1_20260806"
PERIOD = "1988-2022"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4          # DERIVED, never typed

SPINE_CSV = T / "PARTREG_part_year_floor_inund.csv"
SUM_CSV = T / "PARTREG_part_summary_by_period.csv"
COEF_CSV = T / "PARTREG_part_regression_coefficients.csv"

DECIDED_BY = ("PARTREG Stage 1, docs/reference_update/Gayini_CC_spec_PARTREG.md; "
              "design-seat go 6 Aug 2026; built by CC")


def sha256_first50(path: Path) -> str:
    h, read, cap = hashlib.sha256(), 0, 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            read += len(chunk)
    return h.hexdigest()


def load(path: Path):
    return list(csv.DictReader(open(path, encoding="utf-8-sig")))


def ensure_table(cur, name, cols, mode):
    """Create if absent; refuse rather than drop if the shape has moved."""
    got = [r[1] for r in cur.execute(f"PRAGMA table_info({name})")]
    if got and got != cols:
        raise SystemExit(f"REFUSING: {name} exists with different columns.\n"
                         f"  on disk : {got}\n  wanted  : {cols}\n"
                         f"  Resolve deliberately; this script will not drop a table.")
    if not got and mode == "execute":
        cur.execute(f"CREATE TABLE {name} (" + ", ".join(f'"{c}" TEXT' for c in cols) + ")")
    return bool(got)


def main(mode: str) -> int:
    if mode not in {"check", "execute"}:
        print("use: check | execute")
        return 2
    for p in (SPINE_CSV, SUM_CSV, COEF_CSV, FIG):
        if not p.exists():
            print(f"FAIL: missing {p}")
            return 1

    spine, summ, coef = load(SPINE_CSV), load(SUM_CSV), load(COEF_CSV)
    fits = {r["fit_id"]: r for r in coef}
    W, U = fits["2.3_weighted"], fits["2.3_unweighted"]
    n_parts, n_paddocks = len(summ), len({r["zone_fid"] for r in summ})

    print(f"  spine {len(spine):,} rows · summary {n_parts} parts · "
          f"{n_paddocks} paddocks · {len(coef)} fits")
    print(f"  headline (weighted)   slope {float(W['slope']):+.6f}  intercept "
          f"{float(W['intercept']):.6f}  r {float(W['r']):.6f}  residSD {float(W['resid_sd']):.6f}")
    print(f"  alternative (unwtd)   slope {float(U['slope']):+.6f}  intercept "
          f"{float(U['intercept']):.6f}  r {float(U['r']):.6f}  residSD {float(U['resid_sd']):.6f}")

    SCOPE = ("115 supported paddock x community parts (>=25 years of >=30 valid cells); "
             "treed_context_flag=0 AND regime_band<>'context'")
    AGG = ("OLS across parts of across-year means of within-year across-cell quantities; "
           "pixel-weighted by part cell count")
    CAV_COMMON = (f"Bootstrap 2,000 draws resampling paddocks with replacement, clustered on "
                  f"zone_fid. No p-values. Unweighted alternative is the spread bound.")
    SLOPE_CAV = (f"Indistinguishable from the registered 64-paddock slope +0.547838 "
                 f"(difference {abs(float(W['slope']) - 0.547838):.4f}), so the paddock-grain "
                 f"expectation line is NOT an aggregation artefact. BUT all three community "
                 f"slopes are lower ({float(fits['2.6_aeolian']['slope']):+.3f} aeolian, "
                 f"{float(fits['2.6_riverine']['slope']):+.3f} riverine, "
                 f"{float(fits['2.6_inland']['slope']):+.3f} inland) and this pooled slope lies "
                 f"OUTSIDE the inland 95% interval [{float(fits['2.6_inland']['boot_slope_p2_5']):.3f}, "
                 f"{float(fits['2.6_inland']['boot_slope_p97_5']):.3f}] on 61 of 115 parts - a "
                 f"between-community effect, reported not resolved. 95% "
                 f"[{float(W['boot_slope_p2_5']):.4f}, {float(W['boot_slope_p97_5']):.4f}]. "
                 + CAV_COMMON)

    def num(nid, label, val, alt, cav):
        return (nid, label, "fact_part_year_floor_inund", "part", AGG, "mean_of_seasons",
                SCOPE, PERIOD, f"{n_parts} parts in {n_paddocks} paddocks", PIXEL_AREA_HA,
                round(val, 6), round(min(val, alt), 6), round(max(val, alt), 6), "pixel",
                cav, DECIDED_BY,
                "Stage 1 of three. Stages 2 and 3 are gated and unbuilt; no period comparison "
                "is registered.")

    numbers = [
        num("partreg_s1_slope_115parts", "Floor vs inundation OLS slope, 115 parts (pixel-weighted)",
            float(W["slope"]), float(U["slope"]), SLOPE_CAV),
        num("partreg_s1_intercept_115parts", "Expectation-line intercept, 115 parts (pixel-weighted)",
            float(W["intercept"]), float(U["intercept"]),
            f"Registered 64-paddock intercept is 52.652934; this is "
            f"{abs(float(W['intercept']) - 52.652934):.4f} from it. " + CAV_COMMON),
        num("partreg_s1_r_115parts", "Floor vs inundation correlation r, 115 parts (pixel-weighted)",
            float(W["r"]), float(U["r"]),
            f"Lower than the registered paddock-grain 0.71: finer grain, more scatter. " + CAV_COMMON),
        num("partreg_s1_residual_sd_115parts",
            "Descriptive residual SD of the 115-part floor~inundation fit (pixel-weighted)",
            float(W["resid_sd"]), float(U["resid_sd"]),
            f"Registered paddock-grain residual SD is 6.6208 pp; part grain is wider, as expected "
            f"when the unit is smaller. Population SD of residuals, matching the 64-paddock "
            f"convention. " + CAV_COMMON),
    ]

    spine_cols = list(spine[0]) + ["run_id"]
    summ_cols = list(summ[0]) + ["run_id"]

    con = sqlite3.connect(DB)
    cur = con.cursor()
    before = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
              for t in ("figure_asset", "table_asset", "dim_headline_number")}
    ensure_table(cur, "fact_part_year_floor_inund", spine_cols, mode)
    ensure_table(cur, "fact_part_summary_full_period", summ_cols, mode)
    print(f"  before: figure_asset {before['figure_asset']} · table_asset {before['table_asset']} "
          f"· dim_headline_number {before['dim_headline_number']}")

    if mode == "check":
        print("\n  would register:")
        for n in numbers:
            print(f"    {n[0]:<36s} {n[10]:>10.6f}   spread [{n[11]}, {n[12]}]")
        print("\ncheck only - no write. Re-run with 'execute'.")
        con.close()
        return 0

    for name, cols, rows in (("fact_part_year_floor_inund", spine_cols, spine),
                             ("fact_part_summary_full_period", summ_cols, summ)):
        cur.execute(f"DELETE FROM {name} WHERE run_id = ?", (RUN_ID,))
        cur.executemany(
            f'INSERT INTO {name} ({", ".join(chr(34)+c+chr(34) for c in cols)}) '
            f'VALUES ({", ".join("?" * len(cols))})',
            [[r.get(c, "") if c != "run_id" else RUN_ID for c in cols] for r in rows])
        print(f"  loaded {name:34s} {cur.execute(f'SELECT COUNT(*) FROM {name}').fetchone()[0]:>6,} rows")

    for path, tid, title, product, n in (
            (SPINE_CSV, "table_partreg_part_year_floor_inund",
             "PARTREG Stage 1 part x year spine (115 parts x 35 years)", "part_year_floor_inund", len(spine)),
            (SUM_CSV, "table_partreg_part_summary_by_period",
             "PARTREG Stage 1 part summary, full period (115 parts)", "part_summary_by_period", len(summ)),
            (COEF_CSV, "table_partreg_part_regression_coefficients",
             "PARTREG Stage 1 regression coefficients, every fit run", "part_regression_coefficients", len(coef))):
        cur.execute(
            """INSERT OR REPLACE INTO table_asset
               (table_asset_id, path, title, product, n_rows, checksum_sha256, path_exists,
                qa_status, run_id, superseded_flag, framing_label, provenance_note, support_level)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (tid, path.relative_to(ROOT).as_posix(), title, product, n, sha256_first50(path), 1,
             "REVIEW", RUN_ID, 0, "census_8058",
             "Producer scripts/12_zone_stratum/PARTREG_stage1_full_period.py. Part grain is a "
             "parallel output of the T2 Gate B extraction, not a step below paddock grain. "
             "Support, aggregation order, period label and weighting are columns in the file.",
             "pixel"))
    print(f"  table_asset -> {cur.execute('SELECT COUNT(*) FROM table_asset').fetchone()[0]}")

    fig_caption = (
        "Support: pixel, aggregated to part. Cover floor against inundation on the 115 supported "
        "paddock x community parts, full record 1988-2022. Panel A: one point per part, area "
        "proportional to part size (33 to 32,399 cells), with the pixel-weighted pooled line, the "
        "three community lines, and the registered 64-paddock expectation line - the pooled part-grain "
        "line and the registered paddock-grain line coincide. Panel B: the percentile sweep, showing "
        "the slope falling and the fit tightening as the floor percentile rises. Intervals are 2,000 "
        "bootstrap draws clustered on paddock; no p-values.")
    assert "pixel" in fig_caption.lower()
    cur.execute(
        """INSERT OR REPLACE INTO figure_asset
           (figure_asset_id, path, title, domain, metric_id, recommended_use, checksum_sha256,
            path_exists, qa_status, run_id, superseded_flag, framing_label, provenance_note,
            caption, support_level, figure_level)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        ("figure_partreg_s1_floor_vs_flood_115_parts", FIG.relative_to(ROOT).as_posix(),
         "Does the cover-and-water relationship survive being cut to the ecological unit?",
         "zone_diagnostics", None, "review", sha256_first50(FIG), 1, "REVIEW", RUN_ID, 0,
         "census_8058",
         "Producer scripts/12_zone_stratum/PARTREG_stage1_figure.py; reads only the Stage 1 CSVs "
         "and dim_headline_number, computes no new quantity.", fig_caption, "pixel", "diagnostics"))

    cur.executemany(
        """INSERT OR REPLACE INTO dim_headline_number
           (number_id, label, source_object, grain, aggregation_order, series_variant,
            scope_filter, period_label, denominator, pixel_constant, pinned_value,
            spread_min, spread_max, support_level, caveat, decided_by, decision_note)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", numbers)
    con.commit()

    after = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
             for t in ("figure_asset", "table_asset", "dim_headline_number")}
    print("\n  registered numbers, read back:")
    ok = True
    for nid, _, _, _, _, _, _, _, _, _, val, lo, hi, *_ in numbers:
        got = cur.execute("SELECT pinned_value, spread_min, spread_max, support_level "
                          "FROM dim_headline_number WHERE number_id=?", (nid,)).fetchone()
        good = got and abs(got[0] - val) < 1e-9 and got[3] == "pixel"
        ok &= bool(good)
        print(f"    {nid:<36s} {got[0]:>10.6f}  spread [{got[1]}, {got[2]}]  {'OK' if good else 'MISMATCH'}")
    con.close()
    for t in after:
        print(f"  {t:22s} {before[t]} -> {after[t]}   ({after[t]-before[t]:+d})")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "check"))
