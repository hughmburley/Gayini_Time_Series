#!/usr/bin/env python
"""Gate 3 rerun (CG, DF) and the per-figure water-surface list - the actual deliverable.

Section 1.4 says the list is the deliverable, not the correlation. Every figure in the
record with a water axis is named here with the surface it was computed on, traced from
its producer's inputs rather than inferred from its caption.

FOUR SURFACES ARE IN USE AND THEY ARE NOT INTERCHANGEABLE:

  INTERPOLATED   background_flood_frequency_8058.tif - counted on native EPSG:28355 then
                 resampled onto 8058. Continuous values, not k/35.
  COUNTED-8058   counted from inundation_annual_stack_8058 (binary bands reprojected
                 nearest, then counted). Values are exactly k/35. This is what the census
                 parquet, flood_zone_8058 and flood_frequency_counted_8058 all carry.
  COUNTED-28355  counted straight from the native stack, no reprojection at all.
  WITHIN-YEAR    a share of a unit's cells wet WITHIN one year (inund_pct, mean_flood).
                 A different quantity from any of the above, not a between-year frequency
                 (Rulings AZ and CX).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "diag"

ROWS = [
    ("veg_regime_class_8058.tif", "10_build_veg_regime_checkerboard.R", "INTERPOLATED",
     "The wetness TERCILE BOUNDARIES that define the 11 classes were cut on the "
     "interpolated surface (gayini_background_flood_frequency). The class raster is a "
     "labelling and is not itself a flood-frequency number, but the band ranges quoted "
     "for it - 0.00-0.18, 0.18-5.71 and the rest - are interpolated-surface quantiles."),
    ("v_pixel_census_by_veg_regime (DB view)", "09_build_pixel_census_view.R",
     "INTERPOLATED", "The census VIEW builds its flood frequency by the interpolated "
     "route. The census PARQUET does not - see the next row. Two objects with the same "
     "name in conversation and different surfaces underneath."),
    ("gayini_pixel_census_8058.parquet (flood_freq_pct)",
     "15_build_pixel_census_parquet.R", "COUNTED-8058",
     "Counted from inundation_annual_stack_8058. Verified this run to agree with "
     "flood_frequency_counted_8058.tif to 0.00e+00 on all 1,080,157 census cells. THE "
     "ANALYSIS SOURCE OF TRUTH."),
    ("flood_zone_8058.tif", "14_build_flood_zone_raster.R", "COUNTED-8058",
     "Verified this run: the counted surface reproduces it at 100.0000% over all "
     "1,080,157 census cells."),
    ("flood_frequency_counted_8058.tif", "BQ_build_counted_flood_frequency.py",
     "COUNTED-8058", "New this run under Ruling BQ. Map product and BR verification "
     "artefact; not an analysis input."),
    ("background_flood_frequency_8058.tif", "06_build_stratified_sampling_frame_f5.R",
     "INTERPOLATED", "The older surface. Retained, not deleted."),
    ("F5 background flood-frequency surface figures",
     "06_build_stratified_sampling_frame_f5.R", "INTERPOLATED",
     "Drawn from the interpolated surface it also builds."),
    ("F7 ground-cover response figures", "08_run_groundcover_response_f7.R",
     "INTERPOLATED", "Reads background_flood_frequency_8058.tif."),
    ("FigA_floor_gradient_density.png", "24_build_figA_floor_gradient_density.R",
     "COUNTED-8058", "Counts from inundation_annual_stack_8058."),
    ("S21 census flood-trend figure", "25_build_s21_flood_trend_census_figure.R",
     "COUNTED-8058", "Annual series counted on the 8058 stack."),
    ("D1 paddock / D2 site dashboards, flooding panel",
     "gayini_dashboard_compose.R + _panels.R", "COUNTED-28355 (WITHIN-YEAR)",
     "Extracts the native 28355 stack over the polygon and plots a WITHIN-YEAR share of "
     "the unit's cells, per year. Not a between-year frequency, which is the label defect "
     "Rulings BE/BL/BM record and knowingly leave unfixed."),
    ("EX1_gate3_community_by_floodbin.csv (EXEMPLAR-1)", "EX1_gate3_extract.py",
     "INTERPOLATED", "The reason Gate 3 first returned r(p05) = 0.6811. Superseded by "
     "the counted rerun in this run; the file is retained and labelled."),
    ("TEMPORAL1_community_by_floodbin.csv", "TEMPORAL1_prepare.py", "COUNTED-8058",
     "Binned on the census parquet's counted k, with bin edges in whole years."),
    ("TEMPORAL1 paddock scatter", "TEMPORAL1_figure.R", "WITHIN-YEAR",
     "x = v_zone_floor_flood_residual.mean_flood: the share of the paddock's cells seen "
     "wet, MEAN OVER YEARS (Rulings AZ, CX). Never a between-year frequency."),
    ("figure_f5_cover_vs_water_64_paddocks", "build_adrian_pack_T1_F3_F5.R",
     "WITHIN-YEAR", "Same mean_flood quantity; the axis label was corrected under AZ."),
    ("PARTREG residual maps, three-periods, bootstrap",
     "PARTREG_stage2_*.py / FIG2_bootstrap_distribution.py", "WITHIN-YEAR",
     "Built on inund_pct from PARTREG_part_year_floor_inund.csv - the share of a part's "
     "cells wet within each year, counted on the 8058 stack."),
    ("EXEMPLAR-1 nine exemplar figures", "EXEMPLAR1_build.R", "WITHIN-YEAR",
     "Same inund_pct series, drawn per year rather than averaged."),
    ("DIAG-1 and SPAT-1 panels", "R/diag/*", "WITHIN-YEAR",
     "Diagnose the between-unit fit whose x is the across-year mean of inund_pct."),
    ("T2 Gate E paddock trajectories", "T2_gateE_figures.R", "COUNTED-8058 (WITHIN-YEAR)",
     "Flood-year shading from T2_community_year_flood.csv, extracted from the 8058 stack."),
]


def main() -> int:
    cen = pd.read_parquet(ROOT / "Output/census/gayini_pixel_census_8058.parquet",
                          columns=["treed_context_flag", "regime_band", "community",
                                   "veg_p05", "veg_p50", "flood_freq_pct"])
    nt = cen[(cen.treed_context_flag == 0) & (cen.regime_band != "context")]
    ok = nt.veg_p05.notna() & nt.veg_p50.notna() & nt.flood_freq_pct.notna()
    n = nt[ok]
    r05 = float(np.corrcoef(n.veg_p05, n.flood_freq_pct)[0, 1])
    r50 = float(np.corrcoef(n.veg_p50, n.flood_freq_pct)[0, 1])
    aeo = int((n[n.community == "Aeolian Chenopod Shrublands"].flood_freq_pct > 50).sum())

    print("  GATE 3 RERUN on the counted surface (Rulings CG, DF)")
    print(f"    cells                {len(n):,}")
    print(f"    r(p05, water)        {r05:.4f}   expected 0.676   "
          f"{'MATCH' if abs(r05 - 0.676) < 5e-3 else 'DIFFERS'}")
    print(f"    r(p50, water)        {r50:.4f}   (0.566 on the interpolated surface)")
    print(f"    Aeolian above 50%    {aeo}   expected 571   "
          f"{'MATCH' if aeo == 571 else 'DIFFERS'}")
    print(f"    interpolated gave    r(p05) 0.6811, Aeolian 490")

    df = pd.DataFrame(ROWS, columns=["artefact", "producer", "water_surface", "note"])
    df["support_level"] = "pixel"
    df["unit"] = "varies by artefact; stated in the note"
    df["period_label"] = "1988-2022 (35 water years)"
    df["weighting"] = "n/a - this is a provenance list, not an estimate"
    df["estimand"] = ("WATER-SURFACE PROVENANCE per artefact. Four surfaces are in use and "
                      "they are not interchangeable.")
    OUT.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT / "GATE3_water_surface_by_figure.csv", index=False, lineterminator="\n")
    print(f"\n  surface list: {len(df)} artefacts")
    for s, g in df.groupby("water_surface"):
        print(f"    {s:28s} {len(g)}")
    print(f"  [wrote] Output/diag/GATE3_water_surface_by_figure.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
