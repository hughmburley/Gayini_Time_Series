#!/usr/bin/env python3
"""PARTREG Stage 2 - registration. Additive only. Authorised 6 Aug 2026, Part 3.

Same pattern as PARTREG_stage1_register.py: narrow, additive, idempotent,
INSERT OR REPLACE throughout, first-50-MB SHA-256.

Scope, exhaustively:
  1  table_asset          x5   the four Stage 2 CSVs plus the export CSV
  2  table_asset          x1   the GeoPackage - see the note below
  3  figure_asset         x2   the three-period scatter and the three residual maps
  4  dim_headline_number  x3   the two ERA slopes and the water-spread ratio

WHY THE GEOPACKAGE IS IN table_asset AND NOT spatial_layer_asset.  CLAUDE.md is
explicit that spatial_layer_asset is an IMPORT registry and that a build-output row
there is a category error - the reason Gayini_Results.gpkg's management_zones layer
is correctly registered nowhere. PARTREG_part_residuals.gpkg is a build output, so it
goes where other build outputs go, with the reason recorded on the row. Flagged for
the design seat rather than decided quietly.

WHAT IS DELIBERATELY *NOT* REGISTERED.  The whole-record part-grain slope. It is
numerically identical to partreg_s1_slope_115parts because it is the same fit on the
same 115 parts - the common-set restriction drops nothing. Minting a second id for
one quantity is how [[I-59]] happens; the Stage 2 coefficients CSV carries the fit
under S2_whole_record_common and cites the Stage 1 id.

Usage:
  python scripts/11_database/PARTREG_stage2_register.py check     # no DB write (default)
  python scripts/11_database/PARTREG_stage2_register.py execute
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
F = ROOT / "Output" / "figures"
SP = ROOT / "Output" / "spatial_8058"
RUN_ID = "partreg_stage2_20260806"
PIXEL_AREA_HA = 24.970268 ** 2 / 1e4
DECIDED_BY = ("PARTREG Stage 2, docs/reference_update/Gayini_CC_spec_PARTREG.md section 5 as "
              "amended by the design seat 6 Aug 2026 (Parts 3-5); built by CC")

SCOPE = ("115 supported paddock x community parts, the common set (all 115 meet support in all "
         "three periods); treed_context_flag=0 AND regime_band<>'context'")
AGG = ("OLS across parts of across-year means of within-year across-cell quantities; "
       "pixel-weighted by part cell count")
CAV = ("Bootstrap 2,000 draws resampling paddocks with replacement, clustered on zone_fid. "
       "No p-values. Unweighted alternative is the spread bound. RELATIONSHIPS only - period "
       "LEVELS are never compared.")


def sha256_first50(p: Path) -> str:
    h, read, cap = hashlib.sha256(), 0, 50 * 1024 * 1024
    with p.open("rb") as f:
        while read < cap:
            c = f.read(1024 * 1024)
            if not c:
                break
            h.update(c); read += len(c)
    return h.hexdigest()


def rows(p: Path):
    return list(csv.DictReader(open(p, encoding="utf-8-sig")))


def main(mode: str) -> int:
    if mode not in {"check", "execute"}:
        print("use: check | execute"); return 2

    fits = {r["fit_id"]: r for r in rows(T / "PARTREG_S2_regression_coefficients.csv")}
    ratio = rows(T / "PARTREG_S2_spread_ratio.csv")[0]

    TABLES = [
        (T / "PARTREG_S2_part_summary_by_period.csv", "table_partreg_s2_part_summary_by_period",
         "PARTREG Stage 2 part summary by period (115 parts x 3 periods)", "part_summary_by_period"),
        (T / "PARTREG_S2_regression_coefficients.csv", "table_partreg_s2_regression_coefficients",
         "PARTREG Stage 2 regression coefficients, every fit run", "part_regression_coefficients"),
        (T / "PARTREG_S2_part_period_attributes.csv", "table_partreg_s2_part_period_attributes",
         "PARTREG Stage 2 part attributes, all three periods wide", "part_period_attributes"),
        (T / "PARTREG_S2_spread_ratio.csv", "table_partreg_s2_spread_ratio",
         "PARTREG Stage 2 water-axis spread ratio (within-part vs between-part)", "spread_ratio"),
        (T / "PARTREG_part_residuals.csv", "table_partreg_part_residuals_csv",
         "PARTREG part residuals, flat export with join keys (115 parts)", "part_residuals_export"),
        (SP / "PARTREG_part_residuals.gpkg", "table_partreg_part_residuals_gpkg",
         "PARTREG part residuals GeoPackage, layer part_residuals (115 polygons, EPSG:8058)",
         "part_residuals_export_gpkg"),
    ]
    FIGURES = [
        (F / "PARTREG_S2_three_periods_115_parts.png", "figure_partreg_s2_three_periods",
         "Does the cover-and-water relationship change between eras?",
         "Support: pixel, aggregated to part. Cover floor against inundation on the 115 supported "
         "paddock x community parts, fitted separately in the cropping era (1988-2013, 26 water "
         "years), post-management (2018-2022, 5 water years) and over the whole record. 2014-2017 "
         "is excluded as a transition. Only the fitted relationships are compared, never the "
         "period levels. All three slope intervals overlap, so the flatter post-management "
         "relationship is reported and not claimed. Marker opacity is the across-year spread of "
         "the cover floor; the water axis carries no spread marks because year-to-year movement "
         "within a part is 2.2x the differences between parts. The eight conserved parts are "
         "ringed and no line is fitted to them.",
         "scripts/12_zone_stratum/PARTREG_stage2_figure.py"),
        (F / "PARTREG_S2_residual_maps_three_periods.png", "figure_partreg_s2_residual_maps",
         "Which parts hold more or less cover than their water predicts, by era",
         "Support: pixel, aggregated to part. Residual from the fitted cover-water expectation, "
         "mapped on the 115 paddock x community parts, one panel per period. Each panel is "
         "measured against its OWN period's line, so the three read as one comparable set. One "
         "common colour scale and one common tick unit across all three; blue is more cover than "
         "the part's water predicts, red is less. Dashed outline = the eight conserved parts. No "
         "cause is attributed: a residual is a departure from a fitted expectation, not a "
         "condition score, and the pooled line spans three communities whose slopes differ.",
         "scripts/12_zone_stratum/PARTREG_stage2_maps_and_export.py"),
    ]

    def num(nid, label, wid, uid, cav):
        w, u = fits[wid], fits[uid]
        v, alt = float(w["slope"]), float(u["slope"])
        return (nid, label, "fact_part_year_floor_inund", "part", AGG, "mean_of_seasons", SCOPE,
                w["period_label"], f"{w['n']} parts in 64 paddocks", PIXEL_AREA_HA,
                round(v, 6), round(min(v, alt), 6), round(max(v, alt), 6), "pixel", cav,
                DECIDED_BY,
                "Stage 2 of three. The whole-record slope is NOT re-registered here - it is "
                "partreg_s1_slope_115parts, the same fit on the same parts.")

    numbers = [
        num("partreg_s2_slope_cropping_era",
            "Floor vs inundation OLS slope, 115 parts, cropping era 1988-2013",
            "S2_cropping_era_common", "S2_cropping_era_common_unweighted",
            f"95% [{float(fits['S2_cropping_era_common']['boot_slope_p2_5']):.4f}, "
            f"{float(fits['S2_cropping_era_common']['boot_slope_p97_5']):.4f}] on 26 water years. "
            f"Overlaps the post-management interval. " + CAV),
        num("partreg_s2_slope_post_management",
            "Floor vs inundation OLS slope, 115 parts, post-management 2018-2022",
            "S2_post_management_common", "S2_post_management_common_unweighted",
            f"95% [{float(fits['S2_post_management_common']['boot_slope_p2_5']):.4f}, "
            f"{float(fits['S2_post_management_common']['boot_slope_p97_5']):.4f}] on FIVE water "
            f"years, not the six sometimes stated - a far weaker basis than 35 for any summary. "
            f"Flatter than the cropping era but the intervals overlap, so this is reported and "
            f"NOT claimed as a change. " + CAV),
        ("partreg_s2_water_spread_ratio",
         "Water-axis spread ratio: within-part across-year vs between-part",
         "fact_zone_community_flood_annual", "part",
         "median across-part of the across-year SD, divided by the SD of part mean inundation",
         "variant-independent", "all 118 paddock x community parts", "1988-2022", "118 parts",
         PIXEL_AREA_HA, round(float(ratio["ratio_within_over_between"]), 4), None, None, "pixel",
         f"SPREAD, not uncertainty - no interval is placed on it, because consecutive years are "
         f"not independent observations. Median across-year SD "
         f"{float(ratio['within_part_across_year_median_sd']):.1f} points against a between-part "
         f"SD of {float(ratio['between_part_sd_of_mean_water']):.1f}. "
         f"{ratio['parts_with_water_iqr_over_92']} parts have a water IQR above 92 points, all "
         f"Inland. This is the argument for comparing cover at like wetness rather than between "
         f"periods.", DECIDED_BY,
         "Computed on all 118 parts, not the supported 115, because it describes the water series "
         "and does not depend on cover support."),
    ]

    for p, *_ in TABLES:
        if not p.exists():
            print(f"FAIL missing {p}"); return 1
    for p, *_ in FIGURES:
        if not p.exists():
            print(f"FAIL missing {p}"); return 1
    for _, _, _, cap, _ in FIGURES:
        assert "pixel" in cap.lower(), "caption must state the support level"

    con = sqlite3.connect(DB); cur = con.cursor()
    before = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
              for t in ("figure_asset", "table_asset", "dim_headline_number")}
    print(f"  before: figure_asset {before['figure_asset']} · table_asset {before['table_asset']} "
          f"· dim_headline_number {before['dim_headline_number']}")
    if mode == "check":
        print("\n  would register:")
        for p, tid, *_ in TABLES:
            print(f"    table   {tid:<44s} {p.stat().st_size/1024:>9,.0f} KB")
        for p, fid, *_ in FIGURES:
            print(f"    figure  {fid:<44s} {p.stat().st_size/1024:>9,.0f} KB")
        for n in numbers:
            print(f"    number  {n[0]:<44s} {n[10]:>9.4f}")
        print("\ncheck only - no write."); con.close(); return 0

    for p, tid, title, product in TABLES:
        n = (len(rows(p)) if p.suffix == ".csv" else 115)
        cur.execute("""INSERT OR REPLACE INTO table_asset
            (table_asset_id, path, title, product, n_rows, checksum_sha256, path_exists,
             qa_status, run_id, superseded_flag, framing_label, provenance_note, support_level)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (tid, p.relative_to(ROOT).as_posix(), title, product, n, sha256_first50(p), 1,
             "REVIEW", RUN_ID, 0, "census_8058",
             ("Build output of PARTREG Stage 2. GeoPackage registered HERE and not in "
              "spatial_layer_asset, which is an import registry - a build-output row there is a "
              "category error (CLAUDE.md). Cell-accurate part polygons, not the render-only set."
              if p.suffix == ".gpkg" else
              "Producers scripts/12_zone_stratum/PARTREG_stage2_periods.py and "
              "PARTREG_stage2_maps_and_export.py. Support, aggregation order, period label, "
              "weighting and the residual basis are columns in the file."), "pixel"))

    for p, fid, title, cap, producer in FIGURES:
        cur.execute("""INSERT OR REPLACE INTO figure_asset
            (figure_asset_id, path, title, domain, metric_id, recommended_use, checksum_sha256,
             path_exists, qa_status, run_id, superseded_flag, framing_label, provenance_note,
             caption, support_level, figure_level)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (fid, p.relative_to(ROOT).as_posix(), title, "zone_diagnostics", None, "review",
             sha256_first50(p), 1, "REVIEW", RUN_ID, 0, "census_8058",
             f"Producer {producer}; reads only the Stage 2 CSVs and computes no new quantity.",
             cap, "pixel", "diagnostics"))

    cur.executemany("""INSERT OR REPLACE INTO dim_headline_number
        (number_id, label, source_object, grain, aggregation_order, series_variant, scope_filter,
         period_label, denominator, pixel_constant, pinned_value, spread_min, spread_max,
         support_level, caveat, decided_by, decision_note)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", numbers)
    con.commit()

    after = {t: cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
             for t in ("figure_asset", "table_asset", "dim_headline_number")}
    ok = True
    print("\n  registered numbers, read back:")
    for n in numbers:
        got = cur.execute("SELECT pinned_value, support_level FROM dim_headline_number "
                          "WHERE number_id=?", (n[0],)).fetchone()
        good = got and abs(got[0] - n[10]) < 1e-9 and got[1] == "pixel"
        ok &= bool(good)
        print(f"    {n[0]:<40s} {got[0]:>10.4f}  {'OK' if good else 'MISMATCH'}")
    con.close()
    for t in after:
        print(f"  {t:22s} {before[t]} -> {after[t]}   ({after[t]-before[t]:+d})")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "check"))
