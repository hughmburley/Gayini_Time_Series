#!/usr/bin/env python
"""PARTREG Stage 2 - the three residual maps, and the export Adrian maps from.

Parts 4 and 5 of the design-seat ruling, 6 Aug 2026.

MAPS.  One per period. Residuals are against EACH PERIOD'S OWN line, so each map
reads as "who beat their water in this era" and the three are a comparable set.
Colour convention is taken verbatim from the existing paddock-grain residual map
(build_T11_v2_dual_grain.R): a seven-stop red-cream-blue ramp, symmetric about zero,
blue above expectation and red below. One common scale across all three panels, and
one common tick unit, so the panels can be read against each other.

CONSERVED PARTS are outlined the same way here as on the scatters - the eight are
marked identically wherever they appear, so a reader moving between figures sees the
same eight. No line is fitted to them.

TWO GEOMETRY OBJECTS EXIST AND THEY ARE NOT INTERCHANGEABLE:
    T13_part_polygons_epsg8058.gpkg              55 MB  cell-accurate  -> THE EXPORT
    T13_part_polygons_render_only_epsg8058.gpkg 532 KB  simplified     -> DRAWING ONLY
Shipping the render-only geometry as the deliverable would hand over a simplification
under an accurate name. Same family as the three management-zone objects in CLAUDE.md.

EXPORT.  A GeoPackage is the deliverable, not a CSV: a CSV he cannot map is a table.
The CSV ships beside it with the join keys so it can also join many-to-one to the 64
paddock polygons for a paddock view. A one-page data dictionary ships with both.

Read-only on the database. Registration is a separate script.
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import geopandas as gpd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LinearSegmentedColormap, Normalize

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
SP = ROOT / "Output" / "spatial_8058"
FIG = ROOT / "Output" / "figures" / "PARTREG_S2_residual_maps_three_periods.png"
GPKG = SP / "PARTREG_part_residuals.gpkg"
CSV_OUT = T / "PARTREG_part_residuals.csv"
DICT_OUT = T / "PARTREG_part_residuals_DATA_DICTIONARY.md"

INK, BG, HEAD, BODY, MUTED, RUST = "#0F3947", "#F8F7F2", "#26302E", "#5F6B67", "#8A8378", "#9C5B2E"
RAMP = ["#8C3A2B", "#B2182B", "#E8A798", "#F5F0EC", "#A8C6E0", "#2171B5", "#0B3D73"]
CMAP = LinearSegmentedColormap.from_list("gayini_residual", RAMP)

PERIODS = [("cropping_era", "A · cropping era", "1988–2013", "26 water years"),
           ("post_management", "B · post-management", "2018–2022", "5 water years"),
           ("whole_record", "C · whole record", "1988–2022", "35 water years")]

# ------------------------------------------------------------------- inputs
attr = {r["part_id"]: r for r in csv.DictReader(open(
    T / "PARTREG_S2_part_period_attributes.csv", encoding="utf-8-sig"))}
fits = {r["fit_id"]: r for r in csv.DictReader(open(
    T / "PARTREG_S2_regression_coefficients.csv", encoding="utf-8-sig"))}
SD_UNIT = float(fits["S2_whole_record_common"]["resid_sd"])

con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
zname = dict(con.execute("SELECT zone_fid, zone_name FROM dim_management_zone"))
con.close()
COMM_SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
              "Riverine Chenopod Shrublands": "riverine",
              "Inland Floodplain Shrublands / Swamps": "inland"}


def joined(path: Path) -> gpd.GeoDataFrame:
    g = gpd.read_file(path)
    g["part_id"] = [f"{int(z):02d}_{COMM_SHORT[c]}" for z, c in zip(g.zone_fid, g.community)]
    g = g[g.part_id.isin(attr)].copy()
    for col in list(next(iter(attr.values()))):
        if col in ("part_id",):
            continue
        g[col] = [attr[p].get(col) for p in g.part_id]
    for c in g.columns:
        if c == "geometry":
            continue
        try:
            g[c] = [float(v) if v not in (None, "") else np.nan for v in g[c]]
            if all(float(v).is_integer() for v in g[c] if not np.isnan(v)):
                g[c] = g[c].astype("Int64")
        except (TypeError, ValueError):
            pass
    return g


draw = joined(SP / "T13_part_polygons_render_only_epsg8058.gpkg")
print(f"[geometry] drawing set {len(draw)} parts (simplified, render only)")
assert len(draw) == 115, f"expected 115 supported parts, joined {len(draw)}"

zones = gpd.read_file(SP / "management_zones_epsg8058.gpkg")
resid_cols = [f"{c}__residual" for c, *_ in PERIODS]
RLIM = float(np.nanmax(np.abs(draw[resid_cols].to_numpy(dtype=float))))
print(f"[scale] common symmetric scale +/-{RLIM:.2f} pp; tick unit 1 SD = {SD_UNIT:.2f} pp "
      f"(whole record, part grain)")

# ----------------------------------------------------------------- the maps
fig = plt.figure(figsize=(16.0, 7.8), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.015, right=0.905, top=0.760, bottom=0.335, wspace=0.03)
norm = Normalize(-RLIM, RLIM)
for i, (code, title, plabel, ylab) in enumerate(PERIODS):
    ax = fig.add_subplot(1, 3, i + 1)
    ax.set_facecolor("#FFFFFF"); ax.set_axis_off()
    zones.plot(ax=ax, facecolor="#F1EEE6", edgecolor="#D8D2C4", linewidth=0.3, zorder=1)
    draw.plot(ax=ax, column=f"{code}__residual", cmap=CMAP, norm=norm,
              edgecolor="#8A8378", linewidth=0.12, zorder=2)
    cons = draw[draw.conserved == 1]
    cons.boundary.plot(ax=ax, color="#1A1A1A", linewidth=0.9, linestyle=(0, (2, 1.6)), zorder=4)
    ax.set_title(f"{title}   ·   {plabel}", fontsize=12, color=HEAD, weight="bold",
                 loc="left", pad=6)
    f = fits[f"S2_{code}_common"]
    ax.text(0.0, -0.035,
            f"residuals against this period's own line  ·  slope {float(f['slope']):+.3f}  ·  {ylab}",
            transform=ax.transAxes, fontsize=8.4, color=MUTED, va="top")

cax = fig.add_axes([0.918, 0.20, 0.011, 0.50])
cb = fig.colorbar(plt.cm.ScalarMappable(norm=norm, cmap=CMAP), cax=cax)
ticks = [-2 * SD_UNIT, -SD_UNIT, 0, SD_UNIT, 2 * SD_UNIT]
cb.set_ticks(ticks); cb.set_ticklabels([f"{t:+.1f}" for t in ticks])
cb.ax.tick_params(colors=MUTED, labelsize=8.4, length=2)
cb.outline.set_edgecolor("#CFCABA")
cb.set_label("Cover above (blue)\nor below (red)\nexpectation  (pp)", fontsize=8.6,
             color=BODY, labelpad=10)

fig.text(0.015, 0.952, "P A R T   G R A I N   ·   R E S I D U A L   M A P S", fontsize=10.5,
         color=RUST, weight="bold", ha="left")
fig.text(0.015, 0.900, "Which parts hold more or less cover than their water predicts",
         fontsize=18, color=HEAD, weight="bold", ha="left")
fig.text(0.015, 0.856,
         __import__("textwrap").fill(
         "Each panel is measured against its OWN period's fitted line, so the three read as one comparable set. "
         "115 parts — 27 paddocks hold a single community and appear undivided. 2014–2017 is excluded as a "
         "transition. Dashed outline = the eight conserved parts.", 168),
         fontsize=9.2, color=RUST, ha="left", va="top", linespacing=1.5)
# T2: the footer is REPLACED and comes from the caption register, not from this file.
# The task list makes this edit non-optional - the previous wording invited a reader to
# treat 8.08 pp as the typical miss everywhere, overstating dry parts and understating wet.
import sys as _sys, textwrap as _tw
_sys.path.insert(0, str(ROOT / "scripts" / "13_pack"))
from caption_register import blocks as _blocks, strip_md as _strip     # noqa: E402
_y = 0.272
for _para in _blocks("PARTREG_S2_residual_maps_three_periods.png", "Footer"):
    _t = _tw.fill(_strip(_para), 168)
    fig.text(0.015, _y, _t, fontsize=8.2, color=HEAD, ha="left", va="top", linespacing=1.55)
    _y -= 0.0235 * (_t.count(chr(10)) + 1) + 0.016

FIG.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(FIG, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {FIG.name}  ({FIG.stat().st_size/1024:.0f} KB)")

# --------------------------------------------------------------- the export
exp = joined(SP / "T13_part_polygons_epsg8058.gpkg")
assert len(exp) == 115
exp = exp.rename(columns={"zone_name": "paddock_name"})
front = ["part_id", "zone_fid", "paddock_name", "community", "community_short",
         "conserved", "n_pixels_part", "area_ha"]
cols = front + [c for c in exp.columns if c not in front + ["geometry", "n_pixels"]] + ["geometry"]
exp = exp[cols]
if GPKG.exists():
    GPKG.unlink()                      # a GPKG is rewritten whole; this is its own output
exp.to_file(GPKG, layer="part_residuals", driver="GPKG")
print(f"[wrote] {GPKG.name}  ({GPKG.stat().st_size/1024/1024:.1f} MB, {len(exp)} polygons, "
      f"EPSG:{exp.crs.to_epsg()})")

exp.drop(columns="geometry").to_csv(CSV_OUT, index=False, encoding="utf-8")
print(f"[wrote] {CSV_OUT.name}  ({len(exp)} rows, {len(exp.columns)-1} columns)")

# ------------------------------------------------------- the data dictionary
UNITS = {
    "part_id": ("text", "join key: zone_fid and community, e.g. 04_aeolian", "—", "—"),
    "zone_fid": ("integer", "paddock identifier; join key to the 64 paddock polygons", "—", "—"),
    "paddock_name": ("text", "paddock name as used throughout the project", "—", "—"),
    "community": ("text", "vegetation community, 4-class simplified_vegetation_group", "—", "—"),
    "community_short": ("text", "aeolian / riverine / inland", "—", "—"),
    "conserved": ("0 or 1", "1 = inside one of the four conserved paddocks. A management category, not a condition state", "—", "—"),
    "n_pixels_part": ("cells", "non-treed census cells in the part; the regression weight", "pixel", "—"),
    "area_ha": ("hectares", "part area, 0.062351428 ha per cell", "pixel", "—"),
}
PER_UNITS = {
    "n_years": ("years", "water years contributing to this period's summary"),
    "floor_mean": ("percent cover", "mean across years of the within-year 5th percentile of cover across the part's cells"),
    "inund_mean": ("percent", "mean across years of the share of the part's cells seen wet"),
    "predicted_floor": ("percent cover", "what THIS PERIOD'S fitted line predicts from inund_mean"),
    "residual": ("percentage points", "floor_mean minus predicted_floor. Positive = more cover than its water predicts"),
    "residual_rank_1_is_largest_shortfall": ("rank", "1 = most below expectation, 115 = most above. Direction is in the name"),
    "floor_spread_sd": ("percentage points", "across-year SPREAD of the cover floor. Spread, not uncertainty"),
    "floor_spread_iqr": ("percentage points", "across-year interquartile range of the cover floor"),
    "floor_spread_min": ("percent cover", "lowest annual cover floor in the period"),
    "floor_spread_max": ("percent cover", "highest annual cover floor in the period"),
    "floor_spread_p10_p90": ("percentage points", "10th-to-90th percentile range across years"),
    "inund_spread_sd": ("percentage points", "across-year spread of wetness"),
    "inund_spread_iqr": ("percentage points", "across-year interquartile range of wetness"),
    "inund_spread_min": ("percent", "driest year in the period"),
    "inund_spread_max": ("percent", "wettest year in the period"),
    "inund_spread_p10_p90": ("percentage points", "10th-to-90th percentile range across years"),
}
L = ["# PARTREG part residuals — data dictionary", "",
     "**One page. Every column, its units, its support, its period.**", "",
     f"`PARTREG_part_residuals.gpkg` (layer `part_residuals`, **EPSG:8058**, {len(exp)} polygons) and "
     f"`PARTREG_part_residuals.csv` hold the same table. The GeoPackage carries the geometry; the CSV carries "
     f"the join keys so it can also be joined many-to-one to the 64 paddock polygons.", "",
     "---", "", "## What a row is", "",
     "**One paddock × community part** — the ground inside one paddock that belongs to one vegetation community. "
     "115 of the 118 that exist carry enough record to be summarised; the three that do not are Bala 15 · Riverine "
     "(23 cells), Bala 28ca · Aeolian (10) and Mara 3 · Aeolian (1).", "",
     "**Support is pixel, aggregated to part.** Every quantity is computed across the part's 24.970268 m census "
     "cells and then summarised across water years. Cover percentiles are taken **across cells within one year**, "
     "never across years within one cell — those are two different quantities in this project and must never be "
     "compared.", "",
     "## The three periods", "",
     "| prefix | period | water years | note |", "|---|---|---|---|",
     "| `cropping_era__` | 1988–2013 | 26 | before control passed to the Nari Nari Tribal Council |",
     "| `post_management__` | 2018–2022 | **5** | the irrigation bank cuts are dated 2018 |",
     "| `whole_record__` | 1988–2022 | 35 | the full record |", "",
     "**2014–2017 appears in no period.** Control passed in 2013 and the cuts are dated 2018, so the four years "
     "between are excluded as a transition rather than assigned to either side.", "",
     "**Residuals are against each period's OWN fitted line**, never the whole-record line. That is what makes the "
     "three comparable as a set. **Do not compare period levels** — only the fitted relationships. A slope is robust "
     "to how wet a window happened to be because both axes move together; a mean is not.", "",
     "## Identifying columns", "",
     "| column | units | support | meaning |", "|---|---|---|---|"]
for k, (u, m, sup, _) in UNITS.items():
    L.append(f"| `{k}` | {u} | {sup} | {m} |")
L += ["", "## Per-period columns", "",
      "Each appears three times, prefixed `cropping_era__`, `post_management__` and `whole_record__`.", "",
      "| column | units | meaning |", "|---|---|---|"]
for k, (u, m) in PER_UNITS.items():
    L.append(f"| `{k}` | {u} | {m} |")
L += ["", "## Two numbers a reader will difference", "",
      "**Total area here is 49,604.8 ha; the SCHEM-1 footprint ladder says 49,606.9 ha.** Both are right, at "
      "different scopes. The ladder counts **all 795,602** zoned non-treed cells — all 118 parts. This export "
      "counts the **115 supported** parts, 795,568 cells. The 34-cell, 2.1 ha difference is exactly the three "
      "sub-support parts (Bala 15 · Riverine 23 cells, Bala 28ca · Aeolian 10, Mara 3 · Aeolian 1). It is not "
      "a polygon-against-raster discrepancy. **For the analysis footprint, the ladder is authoritative; for this "
      "table, the 115-part total is.**", "",
      "**Residuals do not sum to zero, and should not.** Their unweighted means are about +0.82, +0.23 and +0.70 "
      "percentage points for the cropping era, post-management and whole record. The fit is **pixel-weighted**, so "
      "it is the *weighted* residual mean that is zero — and it is, to within 1e-6 in all three periods. An "
      "unweighted average of a weighted fit's residuals carries no such guarantee.", "",
      "---", "", "## Three things to know before using this", "",
      "**Spread is not uncertainty.** The `*_spread_*` columns describe how much a part moved between years. "
      "No confidence interval is placed on them, because 35 consecutive years are not 35 independent observations.", "",
      "**A residual is a departure from a fitted expectation — not a condition score, and not a management "
      "outcome.** The line is fitted across all three communities pooled, and the three community slopes differ, "
      "so part of any residual is simply which community the part sits in.", "",
      "**The conserved parts are marked, not modelled.** `conserved = 1` flags the eight parts inside the four "
      "conserved paddocks. No separate line is fitted to them: eight parts spanning nearly the whole wetness range "
      "in one block of the property is the reference-state design this project has already shown does not work.", "",
      "*Produced by `scripts/12_zone_stratum/PARTREG_stage2_maps_and_export.py` from "
      "`PARTREG_S2_part_period_attributes.csv` and the cell-accurate part polygons. "
      "6 August 2026.*", ""]
DICT_OUT.write_text("\n".join(L), encoding="utf-8")
print(f"[wrote] {DICT_OUT.name}  ({len(L)} lines)")
print("\nDONE - maps drawn, export written. Registration is a separate script.")
