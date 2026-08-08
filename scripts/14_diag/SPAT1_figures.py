#!/usr/bin/env python
"""SPAT-1 panels. Draws only - every quantity comes from the R outputs.

House conventions: never bbox_inches="tight", figsize declared, subplots_adjust
explicit. Nothing here is registered.
"""
from __future__ import annotations

import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DIAG = ROOT / "Output" / "diag"
FIG = DIAG / "figures"

BG, HEAD, BODY, MUTED, INK = "#F8F7F2", "#26302E", "#5F6B67", "#8A8378", "#0F3947"
GRID, SPINE = "#EFEBE0", "#CFCABA"
WARM, COOL = "#90362B", "#0E4379"


def style(a, title=None, xlab=None, ylab=None):
    a.set_facecolor("#FFFFFF")
    for sp in ("top", "right"):
        a.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        a.spines[sp].set_color(SPINE)
    a.tick_params(colors=MUTED, labelsize=8.5, length=3, color=SPINE)
    a.grid(True, color=GRID, lw=0.8, zorder=0)
    a.set_axisbelow(True)
    if title:
        a.set_title(title, color=HEAD, fontsize=10, loc="left", pad=7)
    if xlab:
        a.set_xlabel(xlab, color=BODY, fontsize=9)
    if ylab:
        a.set_ylabel(ylab, color=BODY, fontsize=9)


def save(f, name):
    FIG.mkdir(parents=True, exist_ok=True)
    f.savefig(FIG / name, dpi=200, facecolor=BG)
    plt.close(f)
    print(f"  [wrote] {name}")


MI = pd.read_csv(DIAG / "SPAT1_morans_i.csv")
CG = pd.read_csv(DIAG / "SPAT1_correlogram.csv")
CE = pd.read_csv(DIAG / "analysis" / "SPAT1_part_centroids.csv")
PR = pd.read_csv(DIAG / "analysis" / "SPAT1_pairs.csv")
PW = pd.read_csv(DIAG / "DIAG1_between_pointwise.csv")
WR = PW[PW.period == "whole_record"].set_index("part_id")

# ====================================== F1 - correlogram, permutation, Moran scatter ==
f = plt.figure(figsize=(12.0, 5.2))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.058, right=0.988, top=0.735, bottom=0.235, wspace=0.30)
a1, a2, a3 = (f.add_subplot(1, 3, i) for i in (1, 2, 3))

# --- correlogram
for resp, col, mk in (("residual", INK, "o"), ("residual_z_local", "#8E5572", "s")):
    g = CG[CG.response == resp].sort_values("band_lower_m")
    mid = (g.band_lower_m + g.band_upper_m) / 2000
    a1.plot(mid, g.morans_I, color=col, lw=1.7, marker=mk, ms=5, zorder=4,
            label="raw residual" if resp == "residual" else "residual_z_local")
    a1.fill_between(mid, g.perm_p2_5, g.perm_p97_5, color=col, alpha=0.11, lw=0, zorder=2)
a1.axhline(0, color=MUTED, lw=1.0, zorder=3)
a1.set_xscale("log")
a1.set_xticks([1, 3, 5, 9, 12.5, 25, 45])
a1.set_xticklabels(["1", "3", "5", "9", "12.5", "25", "45"])
a1.legend(frameon=False, fontsize=8, labelcolor=BODY, loc="upper right")
style(a1, "Correlogram, cross-paddock pairs only", "distance between part centroids (km, log)",
      "Moran's I within the band")
a1.annotate("shaded = middle 95% of the\npermutation distribution", (0.03, 0.06),
            xycoords="axes fraction", fontsize=7.4, color=MUTED)

# --- permutation distribution for the sharp test
draws_note = MI[(MI.weights_id == "adjacency_cross_paddock") & (MI.period == "whole_record")]
obs = draws_note[draws_note.response == "residual"].iloc[0]
obsz = draws_note[draws_note.response == "residual_z_local"].iloc[0]
rng = np.random.default_rng(11)
for r, col, lab in ((obs, INK, "raw residual"), (obsz, "#8E5572", "residual_z_local")):
    # the permutation distribution is Gaussian to plotting accuracy; its mean and SD are
    # the reported quantities, and the curve is drawn from them rather than re-simulated
    xs = np.linspace(r.perm_mean - 4 * r.perm_sd, r.perm_mean + 4 * r.perm_sd, 400)
    ys = np.exp(-0.5 * ((xs - r.perm_mean) / r.perm_sd) ** 2)
    a2.fill_between(xs, ys, color=col, alpha=0.13, lw=0, zorder=2)
    a2.plot(xs, ys, color=col, lw=1.3, zorder=3)
    a2.axvline(r.morans_I, color=col, lw=2.0, zorder=5)
    right = col == INK      # the two observed lines are close; push their labels apart
    a2.annotate(f"{lab}\nI = {r.morans_I:+.3f}\n{r.standardised_distance_from_perm_mean:.2f} SD out",
                (r.morans_I, 1.04 if right else 0.55), fontsize=7.6, color=col,
                ha="left" if right else "right", va="bottom",
                xytext=(5 if right else -5, 0), textcoords="offset points")
a2.set_ylim(0, 1.42)
a2.set_yticks([])
style(a2, "The sharp test: adjacent parts in DIFFERENT paddocks",
      "Moran's I", None)
a2.annotate("curves = permutation distribution\n(9,999 reassignments of the same\nresiduals to different places)",
            (0.02, 0.97), xycoords="axes fraction", fontsize=7.4, color=MUTED, va="top")

# --- Moran scatter, cross-paddock adjacency
adj = PR[(PR.adjacent == 1) & (PR.same_paddock == 0)]
res = WR.residual
zbar = res.mean()
lag = {}
for pid in CE.part_id:
    nb = list(adj[adj.part_i == pid].part_j) + list(adj[adj.part_j == pid].part_i)
    if nb:
        lag[pid] = float(np.mean([res[q] for q in nb]))
k = list(lag)
x = np.array([res[q] - zbar for q in k])
y = np.array([lag[q] - zbar for q in k])
cm = {"aeolian": "#C79A3B", "riverine": "#3B8A8F", "inland": "#2165AC"}
cs = [cm[WR.community_short[q]] for q in k]
a3.scatter(x, y, s=30, c=cs, alpha=0.75, lw=0.5, edgecolor="#FFFFFF", zorder=3)
b = np.polyfit(x, y, 1)[0]
xx = np.linspace(x.min(), x.max(), 20)
a3.plot(xx, b * xx, color=INK, lw=1.7, zorder=4)
a3.axhline(0, color=MUTED, lw=1.0, zorder=2)
a3.axvline(0, color=MUTED, lw=1.0, zorder=2)
style(a3, "Moran scatter: a part against its neighbours",
      "part's own residual, centred (pp)", "mean residual of its\ncross-paddock neighbours (pp)")
a3.annotate(f"slope {b:+.3f}\n{len(k)} parts with a\ncross-paddock neighbour",
            (0.03, 0.96), xycoords="axes fraction", fontsize=7.6, color=HEAD, va="top")

f.text(0.045, 0.955, "Residuals are spatially clustered, and it reaches past the paddock",
       color=HEAD, fontsize=15, va="top")
f.text(0.045, 0.895,
       "115 parts, whole record. Two parts of one paddock are neighbours by construction and the bootstrap already treats them as one\n"
       "unit, so every number here excludes within-paddock pairs. What is left is dependence the paddock cluster does not absorb.",
       color=BODY, fontsize=9.3, va="top", linespacing=1.5)
f.text(0.045, 0.03,
       "NO P-VALUE IS COMPUTED. The permutation distribution is reported as a distribution and the observed value's standardised distance from its mean is an\n"
       "effect size, not a test. The remedy for what this shows - a spatial block bootstrap replacing the paddock bootstrap - is a design-seat decision and is\n"
       "not implemented here. Weights: shares a boundary within 1 m; and 1/distance between centroids with a 10 km cutoff. Both agree.",
       color=MUTED, fontsize=7.5, va="bottom", linespacing=1.45)
save(f, "SPAT1_F1_correlogram_and_moran.png")

# ============================================================== F2 - the map ==
# DRAWN AS A CENTROID GRAPH, NOT A CHOROPLETH, and the reason is worth recording: the
# part polygons in PARTREG_part_residuals.gpkg are UNDISSOLVED cell-level geometry -
# 115 parts explode to 503,084 rings. A choropleth of that renders every part in one
# flat tone and takes minutes. The analysis is unaffected (adjacency and centroids come
# out correctly), but the map has to be a graph. It is also the better figure here: the
# claim is about which parts neighbour which, and a graph states exactly that.
f = plt.figure(figsize=(12.6, 6.6))
f.patch.set_facecolor(BG)
# the map gets its own column so the reading notes never sit on top of the data
f.subplots_adjust(left=0.245, right=0.885, top=0.80, bottom=0.10)
ax = f.add_subplot(111)
lim = float(np.abs(res).max())
norm = plt.Normalize(-lim, lim)
cmap = matplotlib.colormaps["RdBu"]

cx = dict(zip(CE.part_id, CE.centroid_x_8058))
cy = dict(zip(CE.part_id, CE.centroid_y_8058))
area = dict(zip(CE.part_id, CE.area_ha))
amax = max(area.values())

# A link is drawn by its CONTRIBUTION TO MORAN'S I - the product of the two centred
# residuals - not by whether the two parts agree in sign. Sign agreement here is 53%
# against 52% expected, i.e. nothing: the dependence lives in the magnitudes, and the
# product is exactly the quantity Moran's I sums. Encoding sign would have drawn a
# pattern that is not the one being reported.
zc = res - res.mean()
prod = {(r.part_i, r.part_j): zc[r.part_i] * zc[r.part_j] for _, r in adj.iterrows()}
pmax = max(abs(v) for v in prod.values())
for (pi, pj), v in prod.items():
    s = abs(v) / pmax
    ax.plot([cx[pi], cx[pj]], [cy[pi], cy[pj]],
            color=WARM if v < 0 else INK, lw=0.5 + 2.6 * s ** 0.65,
            alpha=0.25 + 0.55 * s ** 0.5, zorder=3 if v > 0 else 2)

ids = list(CE.part_id)
ax.scatter([cx[p] for p in ids], [cy[p] for p in ids],
           s=[40 + 300 * (area[p] / amax) ** 0.6 for p in ids],
           c=[cmap(norm(res[p])) for p in ids], edgecolor="#5F6B67", linewidth=0.5,
           zorder=5)
ax.set_aspect("equal")
ax.axis("off")

n_same = sum(((res[r.part_i] > 0) == (res[r.part_j] > 0)) for _, r in adj.iterrows())
# Sign agreement is a WEAKER statistic than Moran's I - it throws away magnitude - so it
# is never shown without the rate chance alone would give, which is not 50%: the
# residuals are not evenly split about zero.
p_pos = float((res > 0).mean())
chance = p_pos ** 2 + (1 - p_pos) ** 2
mo = MI[(MI.weights_id == "adjacency_cross_paddock") & (MI.period == "whole_record")
        & (MI.response == "residual")].iloc[0]
f.text(0.028, 0.735,
       f"Moran's I on these links\n{mo.morans_I:+.3f}\n"
       f"{mo.standardised_distance_from_perm_mean:.2f} SD above the permutation mean",
       fontsize=9.2, color=HEAD, va="top", linespacing=1.6)
f.text(0.028, 0.575,
       f"The signal is not in the signs.\n{n_same} of {len(adj)} links agree in sign against\n"
       f"{chance:.0%} expected from the split alone\n({100 * p_pos:.0f}% of parts are positive) "
       f"— almost\nnothing. The dependence is in the\nmagnitudes, which is what Moran's I\n"
       f"weights and what the link widths show.",
       fontsize=8.4, color=BODY, va="top", linespacing=1.6)
f.text(0.028, 0.30,
       "marker area = part area\n\nlink width = that pair's contribution\nto Moran's I\n\n"
       "dark = the pair pulls I up\nred = the pair pulls I down",
       fontsize=8.0, color=MUTED, va="top", linespacing=1.55)

sm = plt.cm.ScalarMappable(cmap="RdBu", norm=norm)
cb = f.colorbar(sm, ax=ax, fraction=0.03, pad=0.015)
cb.outline.set_visible(False)
cb.ax.tick_params(colors=MUTED, labelsize=8, length=2)
cb.set_label("whole-record residual (pp)   blue = more cover than its water predicts",
             color=BODY, fontsize=8.5)

f.text(0.03, 0.965, "Where the clustering is: parts joined to their cross-paddock neighbours",
       color=HEAD, fontsize=15, va="top")
f.text(0.03, 0.905,
       f"{len(adj)} cross-paddock adjacency links, each drawn by how much that pair contributes to Moran's I.\n"
       "Within-paddock links are not drawn - the bootstrap already treats those parts as one unit, so they are not the exposure.",
       color=BODY, fontsize=9.3, va="top", linespacing=1.5)
f.text(0.03, 0.028,
       "Drawn as a graph rather than a choropleth: the part polygons are undissolved cell-level geometry (115 parts, 503,084 rings), which no colour scale "
       "survives. The analysis is unaffected.\nA residual is a departure from a fitted expectation: not condition, and not management. Nothing on this page is registered.",
       color=MUTED, fontsize=7.6, va="bottom", linespacing=1.5)
save(f, "SPAT1_F2_residual_map_with_links.png")

print("  done")
sys.exit(0)
