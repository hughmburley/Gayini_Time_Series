#!/usr/bin/env python
"""SCHEM-1 - the methods schematic: how Figure 25's two axes are built.

Spec: docs/reference_update/Gayini_CC_spec_SCHEM1.md (committed b168d24).
Verification the drawing rests on: Output/audit/SCHEM1_verification_findings.md (2391965).

Rulings applied:
  AM - the Figure 25 chain only. Single line to PADDOCK grain (Figure 25 is one point
       per paddock, not per part). The paddock x community cut is drawn as a greyed
       BRANCH labelled "-> Figures 17-18, part grain" and stops there.
       The four-rung footprint ladder goes on the face.
  AN - the water chain says NEAREST NEIGHBOUR THROUGHOUT and draws the pinned 25 m
       reference grid as its own step. It resamples twice; cover resamples once.
       Asserting "once" where it is twice is a false detail on a precision diagram.

Every number on the face is recomputed here from the database or read off the raster -
none is typed from a document. The inset distribution is real data, and the script
STOPS if the p05 it draws disagrees with the stored veg_p05_spatial.

matplotlib traps (project rules): figsize declared, no bbox_inches='tight' anywhere,
one full-canvas axes so nothing is auto-scaled.
"""
import csv
import sqlite3
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import rasterio
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
DATA = ROOT / "Output" / "pack" / "DATA"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Output" / "figures" / "SCHEM1_figure25_axis_chain.png"

# ---- design tokens (Gayini_presentation_design_system.md section 2) ---------------
INK    = "#0F3947"   # deep petrol-teal - the join
BG     = "#F8F7F2"   # warm cream, never cool white
HEAD   = "#26302E"
BODY   = "#5F6B67"
MUTED  = "#8A8378"
RUST   = "#9C5B2E"   # kicker
GOLD   = "#C79A3B"   # rule accent
WARM_E, WARM_F = "#8A5F1E", "#F3EBDA"   # cover chain - warm palette
BLUE_E, BLUE_F = "#1B4E86", "#EEF5FD"   # water chain - blue
GREY_E, GREY_F = "#9A9C97", "#ECEBE6"   # the branch that is not this figure

PX_AREA_HA = 24.970268 ** 2 / 1e4       # DERIVED, never typed (gayini_params rule)
ZONE_INSET, YEAR_INSET = 4, 2005        # Bala 29ca

# ================================================================================
# 1 - every number on the face, recomputed
# ================================================================================
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
Q = lambda s, *a: con.execute(s, a).fetchall()

census_px = Q("SELECT SUM(n_pixels) FROM census_stratum")[0][0]
nontreed_px = Q("SELECT SUM(n_pixels) FROM census_stratum "
                "WHERE treed_context_flag=0 AND regime_band<>'context'")[0][0]
farm_ha = Q("SELECT farm_area_total_ha FROM census_stratum LIMIT 1")[0][0]
n_paddocks = Q("SELECT COUNT(*) FROM fact_zone_floor_flood_residual")[0][0]
n_parts = Q("SELECT COUNT(*) FROM (SELECT DISTINCT zone_fid, community "
            "FROM fact_zone_community_veg_annual)")[0][0]
n_parts_cls = Q("SELECT COUNT(*) FROM fact_zone_community_part_classification")[0][0]
yr_lo, yr_hi = Q("SELECT MIN(water_year), MAX(water_year) FROM fact_zone_veg_annual")[0]
n_years = Q("SELECT COUNT(DISTINCT water_year) FROM fact_zone_veg_annual")[0][0]
zone_name = Q("SELECT zone_name FROM dim_management_zone WHERE zone_fid=?", ZONE_INSET)[0][0]
stored_p05, stored_n = Q("SELECT veg_p05_spatial, n_pixels_valid FROM fact_zone_veg_annual "
                         "WHERE zone_fid=? AND water_year=? AND series_variant='mean_of_seasons'",
                         ZONE_INSET, YEAR_INSET)[0]
con.close()

zoned_px = sum(int(float(r["zone_nontreed_px"]))
               for r in csv.DictReader(open(DATA / "tables/T2_zone_denominator.csv", encoding="utf-8-sig")))

# resolutions and CRSs read off the files, not typed
def grid_of(p):
    with rasterio.open(p) as s:
        return s.crs.to_epsg(), s.res[0], s.count

FC_EPSG, FC_RES, FC_BANDS = grid_of(ROOT / "Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif")
WA_EPSG, WA_RES, WA_BANDS = grid_of(ROOT / "Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif")
CG_EPSG, CG_RES, CG_BANDS = grid_of(DATA / "rasters/total_veg_annual_mean_8058.tif")

LADDER = [
    (farm_ha,                  "the property",                     None),
    (census_px * PX_AREA_HA,   "mapped to a vegetation community", "no community mapped"),
    (nontreed_px * PX_AREA_HA, "non-treed ground",                 "treed woodland / forest, and minor units"),
    (zoned_px * PX_AREA_HA,    "inside a management paddock",      "non-treed ground in no paddock"),
]

# the inset distribution - real cells, and it must agree with the registered value
with rasterio.open(DATA / "rasters/total_veg_annual_mean_8058.tif") as s:
    band_j = [int(n[:4]) for n in s.descriptions].index(YEAR_INSET) + 1
    arr, inv = s.read(band_j), ~s.transform
pts = [r for r in csv.DictReader(open(DATA / "tables/T2_in_scope_points.csv", encoding="utf-8-sig"))
       if r["zone_fid"] == str(ZONE_INSET)]
cc, rr = inv * (np.array([float(p["x_8058"]) for p in pts]),
                np.array([float(p["y_8058"]) for p in pts]))
vals = arr[rr.astype(int), cc.astype(int)].astype(float)
vals = vals[~np.isnan(vals)]
p05 = float(np.quantile(vals, 0.05))

# a check that can fail: the drawn percentile against the registered one
assert len(vals) == stored_n, f"inset cell count {len(vals)} != stored {stored_n}"
assert abs(p05 - stored_p05) < 1e-4, f"inset p05 {p05} != stored {stored_p05}"
print(f"[check] {zone_name} WY{YEAR_INSET}: {len(vals):,} cells, p05 {p05:.4f} == stored {stored_p05:.4f}")

# ================================================================================
# 2 - the drawing
# ================================================================================
W, H = 16.0, 9.0
fig = plt.figure(figsize=(W, H), dpi=200, facecolor=BG)
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, W); ax.set_ylim(0, H)
ax.axis("off"); ax.set_facecolor(BG)


def box(x, y, w, h, fc, ec, lw=1.2, ls="-", z=2):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=0.08",
                                fc=fc, ec=ec, lw=lw, ls=ls, zorder=z))


def t(x, y, s, size=9.6, color=BODY, weight="normal", ha="center", va="center",
      style="normal", ls_=1.30, z=4):
    ax.text(x, y, s, fontsize=size, color=color, weight=weight, ha=ha, va=va,
            style=style, linespacing=ls_, zorder=z)


def arrow(x0, y0, x1, y1, color=MUTED, lw=1.5, ls="-", z=3, mut=10):
    ax.add_patch(FancyArrowPatch((x0, y0), (x1, y1), arrowstyle="-|>", mutation_scale=mut,
                                 color=color, lw=lw, ls=ls, zorder=z, shrinkA=0, shrinkB=0))


# ---- header ---------------------------------------------------------------------
t(0.42, 8.68, "M E T H O D S   ·   T H E   T W O   A X E S", 10.5, RUST, "bold", ha="left")
t(0.42, 8.30, "How each axis of the cover-and-water figure is built", 23, HEAD, "bold", ha="left")
ax.add_line(plt.Line2D([0.42, 15.60], [8.03, 8.03], color=GOLD, lw=1.1, zorder=1))

# ---- geometry -------------------------------------------------------------------
BW = 3.90
CX_C, CX_W = 2.45, 6.75
LC, LWx = CX_C - BW / 2, CX_W - BW / 2
CHAIN_L, CHAIN_R = LC, LWx + BW
MID = (CHAIN_L + CHAIN_R) / 2
CX_BR, BWB = 9.90, 2.10
RAIL_L, RAIL_W = 11.45, 4.15

Y_SRC, H_SRC = 6.94, 0.98
Y_ANN, H_ANN = 5.88, 0.84
Y_RES, H_RES = 4.28, 1.33
Y_JOIN, H_JOIN = 3.18, 0.82
Y_PU, H_PU = 1.78, 1.15
Y_SER, H_SER = 1.16, 0.40
Y_FIN, H_FIN = 0.30, 0.70

# ---- row 1 - sources ------------------------------------------------------------
box(LC, Y_SRC, BW, H_SRC, WARM_F, WARM_E)
t(CX_C, Y_SRC + 0.73, "Ground cover, seen from space", 12.5, WARM_E, "bold")
t(CX_C, Y_SRC + 0.40, "Landsat 5 / 7 / 8 / 9 — how much of each cell is\n"
                      "green plant, dry plant or bare, every season", 9.5)
t(CX_C, Y_SRC + 0.12, f"fractional cover  ·  {FC_RES:.0f} m  ·  EPSG:{FC_EPSG}  ·  "
                      f"{FC_BANDS} seasonal layers", 7.6, MUTED)

box(LWx, Y_SRC, BW, H_SRC, BLUE_F, BLUE_E)
t(CX_W, Y_SRC + 0.73, "Water, seen from space", 12.5, BLUE_E, "bold")
t(CX_W, Y_SRC + 0.40, "Landsat 5 / 7 / 8 / 9 — whether each cell was\n"
                      "under water, and whether it could be seen", 9.5)
t(CX_W, Y_SRC + 0.12, f"open-water classification  ·  {WA_RES:.1f} m  ·  EPSG:{WA_EPSG}  ·  "
                      f"{WA_BANDS} annual layers", 7.6, MUTED)

arrow(CX_C, Y_SRC, CX_C, Y_ANN + H_ANN, WARM_E)
arrow(CX_W, Y_SRC, CX_W, Y_ANN + H_ANN, BLUE_E)

# ---- row 2 - one layer per year -------------------------------------------------
box(LC, Y_ANN, BW, H_ANN, WARM_F, WARM_E)
t(CX_C, Y_ANN + 0.61, "One cover layer per year", 11.5, WARM_E, "bold")
t(CX_C, Y_ANN + 0.32, f"green and dry added together, then averaged\n"
                      f"over the usable seasons  ·  {n_years} years, {yr_lo}–{yr_hi + 1}", 9.0)

box(LWx, Y_ANN, BW, H_ANN, BLUE_F, BLUE_E)
t(CX_W, Y_ANN + 0.61, "Already one layer per year", 11.5, BLUE_E, "bold")
# Ruling AP: purpose, not operation. The valid stack is presence-only {1} in every
# band of both the 8058 and the native 28355 product - no zeros anywhere - so the
# denominator currently removes nothing. It is a safeguard, not a filter.
t(CX_W, Y_ANN + 0.28, "two of them: seen wet, and seen at all\n"
                      "the second is the denominator, so that cloud\n"
                      "can never be counted as dry ground", 8.6, ls_=1.25)

arrow(CX_C, Y_ANN, CX_C, Y_RES + H_RES, WARM_E)
arrow(CX_W, Y_ANN, CX_W, Y_RES + H_RES, BLUE_E)

# ---- row 3 - onto the census grid.  one step vs two, drawn as such --------------
box(LC, Y_RES, BW, H_RES, WARM_F, WARM_E, lw=1.7)
t(CX_C, Y_RES + 1.12, "Put on the census grid  ·  B I L I N E A R", 12, WARM_E, "bold")
t(CX_C, Y_RES + 0.82, "cover is a continuous surface, so neighbouring\ncells are blended as the grid changes", 9.0)
box(LC + 0.14, Y_RES + 0.16, BW - 0.28, 0.42, "#FFFFFF", WARM_E, lw=0.9)
t(CX_C, Y_RES + 0.37, "one resample, straight from native\n"
                      f"{FC_RES:.0f} m EPSG:{FC_EPSG}   →   {CG_RES:.6f} m EPSG:{CG_EPSG}",
  7.8, WARM_E, "bold", ls_=1.45)

box(LWx, Y_RES, BW, H_RES, BLUE_F, BLUE_E, lw=1.7)
t(CX_W, Y_RES + 1.12, "Put on the census grid  ·  N E A R E S T", 12, BLUE_E, "bold")
box(LWx + 0.14, Y_RES + 0.68, BW - 0.28, 0.34, "#FFFFFF", BLUE_E, lw=0.9)
t(CX_W, Y_RES + 0.85, "1  ·  onto the pinned 25 m reference grid", 8.8, BLUE_E, "bold")
box(LWx + 0.14, Y_RES + 0.28, BW - 0.28, 0.34, "#FFFFFF", BLUE_E, lw=0.9)
t(CX_W, Y_RES + 0.45, f"2  ·  onto the census grid, {CG_RES:.6f} m, EPSG:{CG_EPSG}",
  8.2, BLUE_E, "bold")
t(CX_W, Y_RES + 0.16, "nearest neighbour at both steps — a wet / dry mask is never\n"
                      "blended, because blending invents cells that are half wet", 7.6, BLUE_E, ls_=1.30)

arrow(CX_C, Y_RES, CX_C, Y_JOIN + H_JOIN, WARM_E)
arrow(CX_W, Y_RES, CX_W, Y_JOIN + H_JOIN, BLUE_E)

# ---- the join -------------------------------------------------------------------
box(CHAIN_L, Y_JOIN, CHAIN_R - CHAIN_L, H_JOIN, INK, INK)
t(MID, Y_JOIN + 0.59, "One grid.  The same cells.", 15, BG, "bold")
t(MID, Y_JOIN + 0.34, f"both chains are then read at the same {zoned_px:,} cell centres — "
                      f"{CG_RES:.6f} m, EPSG:{CG_EPSG}", 10, "#CFE0DC")
t(MID, Y_JOIN + 0.12, f"the sources were {FC_RES:.0f} m and {WA_RES:.1f} m — "
                      f"and {WA_RES:.1f} m is not {CG_RES:.6f} m", 9.2, GOLD, "bold")

# ---- the greyed branch: drawn, labelled, stops ----------------------------------
bx, by, bh = CX_BR - BWB / 2, Y_PU + 0.10, 0.96
ax.add_line(plt.Line2D([CHAIN_R, CX_BR], [Y_JOIN + H_JOIN / 2] * 2,
                       color=GREY_E, lw=1.2, ls=(0, (4, 3)), zorder=1))
arrow(CX_BR, Y_JOIN + H_JOIN / 2, CX_BR, by + bh, GREY_E, lw=1.2, ls=(0, (4, 3)), z=1)
box(bx, by, BWB, bh, GREY_F, GREY_E, lw=1.0, ls=(0, (4, 3)))
t(CX_BR, by + 0.76, "→  Figures 17–18", 11, "#6E736E", "bold")
t(CX_BR, by + 0.56, "part grain", 9.4, "#6E736E")
t(CX_BR, by + 0.27, f"the same extraction, cut\nagain by paddock × community\n"
                    f"{n_parts} parts  ·  {n_parts_cls} classified", 7.8, MUTED)
t(CX_BR, by - 0.17, "not this figure", 8.4, MUTED, style="italic")

# ---- row 4 - the two per-unit calculations --------------------------------------
arrow(MID - 0.5, Y_JOIN, CX_C, Y_PU + H_PU, WARM_E)
arrow(MID + 0.5, Y_JOIN, CX_W, Y_PU + H_PU, BLUE_E)

box(LC, Y_PU, BW, H_PU, WARM_F, WARM_E, lw=1.7)
t(CX_C, Y_PU + 0.92, "“the poorest patches, that year”", 13, WARM_E, "bold")
t(CX_C, Y_PU + 0.48, "for each paddock, in each year:\nrank its cells by cover, take the 5th percentile\n"
                     "— the level that 95% of the paddock is above", 9.4)
t(CX_C, Y_PU + 0.13, "veg_p05_spatial  ·  across cells, within one year", 8.0, MUTED)

box(LWx, Y_PU, BW, H_PU, BLUE_F, BLUE_E, lw=1.7)
t(CX_W, Y_PU + 0.92, "“how much was under water, that year”", 12.2, BLUE_E, "bold")
t(CX_W, Y_PU + 0.48, "for each paddock, in each year:\ncells seen wet ÷ cells the satellite could see\n"
                     "— written as a percentage", 9.4)
t(CX_W, Y_PU + 0.13, "flood_frac_pct  ·  across cells, within one year", 8.0, MUTED)

arrow(CX_C, Y_PU, CX_C, Y_SER + H_SER, WARM_E)
arrow(CX_W, Y_PU, CX_W, Y_SER + H_SER, BLUE_E)

# ---- row 5 - the series ---------------------------------------------------------
box(CHAIN_L, Y_SER, CHAIN_R - CHAIN_L, H_SER, "#FFFFFF", MUTED, lw=1.0)
t(MID, Y_SER + 0.20, f"{n_years} values for every paddock, one for every year — "
                     f"the time axis is kept, on both axes", 11, HEAD, "bold")

arrow(CX_C, Y_SER, MID - 1.0, Y_FIN + H_FIN, WARM_E)
arrow(CX_W, Y_SER, MID + 1.0, Y_FIN + H_FIN, BLUE_E)

# ---- row 6 - one point per paddock ----------------------------------------------
fw = 7.2
box(MID - fw / 2, Y_FIN, fw, H_FIN, "#FFFFFF", INK, lw=2.0)
t(MID, Y_FIN + 0.47, f"average each paddock's {n_years} values    →    "
                     f"ONE POINT PER PADDOCK", 12.5, INK, "bold")
t(MID, Y_FIN + 0.17, f"{n_paddocks} paddocks, {n_paddocks} points — the figure", 9.6, BODY)

# ================================================================================
# right rail
# ================================================================================
ax.add_line(plt.Line2D([RAIL_L - 0.26] * 2, [0.20, 7.92], color="#DDD8CC", lw=1.0, zorder=1))

# ---- footprint ladder -----------------------------------------------------------
t(RAIL_L, 7.86, "How much of the property each step covers", 11.5, HEAD, "bold", ha="left")
BAR_MAX, Y0, STEP, BH = 2.55, 7.22, 0.80, 0.20
for i, (ha_v, label, drop) in enumerate(LADDER):
    y = Y0 - i * STEP
    frac = ha_v / LADDER[0][0]
    ax.add_patch(Rectangle((RAIL_L, y), BAR_MAX, BH, fc="#E9E6DC", ec="none", zorder=2))
    ax.add_patch(Rectangle((RAIL_L, y), BAR_MAX * frac, BH, fc=(INK if i == 3 else GOLD),
                           ec="none", zorder=3))
    t(RAIL_L, y + BH + 0.19, f"{ha_v:,.0f} ha", 11.5, HEAD, "bold", ha="left")
    t(RAIL_L + 1.02, y + BH + 0.19, label, 9.4, BODY, ha="left")
    t(RAIL_L + BAR_MAX + 0.10, y + BH / 2, f"{100 * frac:.1f}%", 9.4, MUTED, "bold", ha="left")
    if drop:
        t(RAIL_L + 0.04, y - 0.17, f"− {LADDER[i-1][0] - ha_v:,.0f} ha    {drop}", 8.2, RUST, ha="left")
t(RAIL_L, 4.32, f"The figure is drawn on the bottom rung:\n"
                f"{LADDER[3][0]:,.0f} ha, {100 * LADDER[3][0] / LADDER[0][0]:.1f}% of the property.",
  9.4, HEAD, "bold", ha="left", ls_=1.45)

# ---- the 5th percentile, drawn from real cells ----------------------------------
t(RAIL_L, 3.96, "The 5th percentile, drawn", 11.5, HEAD, "bold", ha="left")
t(RAIL_L, 3.78, f"every non-treed cell of {zone_name} in one year — {len(vals):,} of them",
  8.6, MUTED, ha="left")
hx, hy, hw, hh = RAIL_L + 0.05, 2.92, 3.55, 0.74
axh = fig.add_axes([hx / W, hy / H, hw / W, hh / H]); axh.set_facecolor("#FFFFFF")
cnt, edges = np.histogram(vals, bins=46, range=(0, 100))
lo = edges[:-1]
axh.bar(lo, cnt, width=np.diff(edges), align="edge", color="#DCD3BF", edgecolor="none")
axh.bar(lo[lo < p05], cnt[lo < p05], width=np.diff(edges)[lo < p05], align="edge",
        color=WARM_E, edgecolor="none")
axh.axvline(p05, color=RUST, lw=2.0)
axh.set_xlim(0, 100); axh.set_ylim(0, cnt.max() * 1.32)
axh.set_yticks([]); axh.set_xticks([0, 25, 50, 75, 100])
axh.set_xticklabels(["0", "25", "50", "75", "100%"], fontsize=7.6, color=MUTED)
for sp in ("top", "right", "left"):
    axh.spines[sp].set_visible(False)
axh.spines["bottom"].set_color("#CFCABA")
axh.tick_params(length=2, color="#CFCABA", pad=1.5)
axh.text(p05 + 3, cnt.max() * 1.13, f"5th percentile = {p05:.1f}%", fontsize=9.2,
         color=RUST, weight="bold", ha="left")
axh.text(p05 - 3, cnt.max() * 0.55, "the poorest 5%\nof the paddock", fontsize=7.8,
         color=WARM_E, ha="right", linespacing=1.3)
t(RAIL_L, 2.48, f"{zone_name}, water year {YEAR_INSET}. One value falls out — {p05:.1f}% —\n"
                f"and one like it for every other year.", 8.6, MUTED, ha="left", ls_=1.45)

# ---- two floors, one name -------------------------------------------------------
t(RAIL_L, 2.22, "Two “floors” — not the same number.", 11.5, HEAD, "bold", ha="left")
box(RAIL_L, 1.16, RAIL_W - 0.30, 0.92, WARM_F, WARM_E, lw=1.7)
ax.add_patch(Rectangle((RAIL_L, 1.16), 0.07, 0.92, fc=RUST, ec="none", zorder=3))
t(RAIL_L + 0.20, 1.92, "U S E D   I N   T H I S   F I G U R E", 8.2, RUST, "bold", ha="left")
t(RAIL_L + RAIL_W - 0.42, 1.92, "veg_p05_spatial", 8.0, MUTED, ha="right")
t(RAIL_L + 0.20, 1.68, "“the poorest patches of this paddock, this year”", 10.4, WARM_E, "bold", ha="left")
t(RAIL_L + 0.20, 1.46, "across the paddock's cells, within one year", 9.0, BODY, ha="left")
t(RAIL_L + 0.20, 1.27, f"→ one value per paddock per year — a {n_years}-year series",
  9.0, HEAD, "bold", ha="left")

box(RAIL_L, 0.16, RAIL_W - 0.30, 0.88, GREY_F, GREY_E, lw=1.0)
t(RAIL_L + 0.20, 0.88, "N O T   U S E D   H E R E", 8.2, MUTED, "bold", ha="left")
t(RAIL_L + RAIL_W - 0.42, 0.88, "veg_p05  (the census floor)", 8.0, MUTED, ha="right")
t(RAIL_L + 0.20, 0.64, "“the worst this spot ever got”", 10.4, "#6E736E", "bold", ha="left")
t(RAIL_L + 0.20, 0.42, "across one cell's years, over the whole record", 9.0, MUTED, ha="left")
t(RAIL_L + 0.20, 0.23, "→ one value per cell, for the record — no time axis", 9.0, "#6E736E", ha="left")

# ---- footer ---------------------------------------------------------------------
t(0.42, 0.11, "Gayini remote-sensing assessment  ·  support: pixel, aggregated to paddock  ·  "
              "every quantity on this page is recomputed from the results database and the "
              "source rasters, not copied from a document.", 7.8, MUTED, ha="left")

OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=200, facecolor=BG)     # NO bbox_inches='tight' - project rule
plt.close(fig)
print(f"[wrote] {OUT}  ({OUT.stat().st_size / 1024:.0f} KB)")
