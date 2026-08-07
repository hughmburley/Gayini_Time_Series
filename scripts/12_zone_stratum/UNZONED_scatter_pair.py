#!/usr/bin/env python
"""UNZONED scatter pair - the two sets side by side, and the within result.

Design-seat instruction, 7 August 2026. INTERNAL, not for distribution: neither
figure has been through a caption pass. Nothing is registered in figure_asset.

WHAT THESE ARE NOT. The unzoned patches are units that fall outside the
management-zone layer. They are NOT a reference set, NOT a control, and NOT
unmanaged ground; all fifteen standard-grazing monitoring plots sit on them, and set
stocking is a designed treatment arm. No management claim and no condition claim is
made: a slope is a response, not a state.

NOTHING IS ESTIMATED HERE. Every slope drawn is read from the R-side outputs
(Ruling AS) - UNZONED_stageA1_fits.csv and WITHIN1_fits.csv - or from
dim_headline_number. Figure 1 draws the registered 64-paddock line as a reference and
fits NOTHING to the patches; A2 has not run and no residual is computed anywhere.
The only transforms performed here are the per-unit mean and the within-demeaning,
both for display.

Output: Output/unzoned/figures/ - a folder the design seat named explicitly. The
output-structure contract's "no new top-level folder" rule is noted as a deviation
taken on instruction.
"""
from __future__ import annotations

import csv
import sqlite3
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = ROOT / "Output" / "unzoned" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

INK, BG, HEAD, BODY, MUTED = "#0F3947", "#F8F7F2", "#26302E", "#5F6B67", "#8A8378"
RUST, GOLD = "#9C5B2E", "#C79A3B"
PAL = {"aeolian": ("#8A5F1E", "#C79A3B", "Aeolian Chenopod"),
       "riverine": ("#2A6560", "#3B8A8F", "Riverine Chenopod"),
       "inland": ("#1B4E86", "#2165AC", "Inland Floodplain")}
# FIG-2 section 3: these go to Adrian as a separate attachment, OUTSIDE the pack, so the
# covering note's sentence stays true while a collaborator who should see them does.
STAMP = ("P R O V I S I O N A L   ·   unregistered   ·   for reference, "
         "not for onward circulation")
FOOT1 = ("Support level: pixel, aggregated to the unit.  Unit construction: unzoned = 8-connected "
         "component within one community, outside every management zone; real parts = paddock × "
         "community.  Period 1988–2022, 35 water years.")
FOOT2 = ("Weighting: pixel-weighted by cell count.  Label: unzoned standard-grazing country — units "
         "outside the management-zone layer, nothing more.  No management claim, no condition claim: "
         "a slope is a response, not a state.")


def rows(p):
    return list(csv.DictReader(open(p, encoding="utf-8-sig")))


def means(recs, key, y, x, w):
    g = defaultdict(list)
    for r in recs:
        g[r[key]].append(r)
    out = []
    for k, v in g.items():
        out.append(dict(unit=k, community_short=v[0]["community_short"],
                        cells=float(v[0][w]),
                        y=float(np.mean([float(r[y]) for r in v])),
                        x=float(np.mean([float(r[x]) for r in v]))))
    return out


def demean(recs, key, y, x, w):
    g = defaultdict(list)
    for r in recs:
        g[r[key]].append(r)
    dy, dx = [], []
    for v in g.values():
        ww = np.array([float(r[w]) for r in v], float)
        yy = np.array([float(r[y]) for r in v], float)
        xx = np.array([float(r[x]) for r in v], float)
        dy.append(yy - (ww * yy).sum() / ww.sum())
        dx.append(xx - (ww * xx).sum() / ww.sum())
    return np.concatenate(dx), np.concatenate(dy)


UZ = rows(T / "UNZONED_stageA1_patch_year.csv")
RP = rows(T / "PARTREG_part_year_floor_inund.csv")
uz_m = means(UZ, "patch_id", "veg_p05_spatial", "inund_pct", "n_cells")
rp_m = means(RP, "part_id", "veg_p05_spatial", "inund_pct", "n_pixels_part")
FITS = {r["label"]: r for r in rows(T / "UNZONED_stageA1_fits.csv") + rows(T / "WITHIN1_fits.csv")}
S_UZ = float(FITS["UNZONED A1 within, 2k draws"]["slope"])
S_RP = float(FITS["WITHIN-1 pooled within"]["slope"])

con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",
                      uri=True)
con.execute("PRAGMA query_only=1")
REG_SL, REG_IN = (con.execute(
    "SELECT pinned_value FROM dim_headline_number WHERE number_id=?", (k,)).fetchone()[0]
    for k in ("floor_flood_slope_64pdk", "floor_flood_intercept_64pdk"))
con.close()

CELL_MAX = max(max(r["cells"] for r in uz_m), max(r["cells"] for r in rp_m))
size = lambda c: 6 + 150 * np.sqrt(c / CELL_MAX)          # one scale, both sets


def furniture(fig, kicker, title, sub):
    fig.text(0.045, 0.962, kicker, fontsize=10.5, color=RUST, weight="bold", ha="left")
    fig.text(0.045, 0.917, title, fontsize=18, color=HEAD, weight="bold", ha="left")
    fig.text(0.045, 0.877, sub, fontsize=9.2, color=RUST, ha="left")
    fig.text(0.985, 0.962, STAMP, fontsize=8.2, color="#B03A2E", weight="bold", ha="right")


def axstyle(ax):
    ax.set_facecolor("#FFFFFF")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color("#CFCABA")
    ax.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    ax.grid(True, color="#EFEBE0", lw=0.8, zorder=0)
    ax.set_axisbelow(True)


# ================================================================ FIGURE 1
fig = plt.figure(figsize=(13.6, 8.4), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.062, right=0.985, top=0.815, bottom=0.205)
ax = fig.add_subplot(111)
axstyle(ax)

for r in rp_m:                                   # real parts, faint, behind
    d, m, _ = PAL[r["community_short"]]
    ax.scatter(r["x"], r["y"], s=size(r["cells"]), marker="o", facecolor=m,
               edgecolor="none", alpha=0.28, zorder=2)
for r in uz_m:                                   # unzoned patches, in front
    d, m, _ = PAL[r["community_short"]]
    ax.scatter(r["x"], r["y"], s=size(r["cells"]), marker="D", facecolor=m,
               edgecolor=d, lw=0.9, alpha=0.95, zorder=4)

xs = np.linspace(0, 62, 40)
ax.plot(xs, REG_IN + REG_SL * xs, color=RUST, lw=2.2, ls=(0, (7, 3)), zorder=5)
ax.text(61, REG_IN + REG_SL * 61 + 1.2,
        f"registered 64-paddock line   {REG_IN:.3f} + {REG_SL:.3f} × x   —   reference only",
        fontsize=8.6, color=RUST, ha="right")

ax.set_xlim(0, 62); ax.set_ylim(0, 100)
ax.set_xlabel("share of the unit's cells seen wet, mean over the record  (%)", fontsize=10, color=BODY)
ax.set_ylabel("cover in the poorest patches, mean over the record  (%)", fontsize=10, color=BODY)

h = [plt.Line2D([], [], marker="D", ls="", markerfacecolor=m, markeredgecolor=d, markersize=8,
                label=f"unzoned patch — {lab}") for k, (d, m, lab) in PAL.items()]
h += [plt.Line2D([], [], marker="o", ls="", markerfacecolor=m, markeredgecolor="none", alpha=0.45,
                 markersize=9, label=f"real part — {lab}") for k, (d, m, lab) in PAL.items()]
leg = ax.legend(handles=h, loc="lower right", fontsize=8.4, frameon=True, facecolor="#FFFFFF",
                edgecolor="#DDD8CC", labelcolor=BODY, ncol=2)
leg.get_frame().set_linewidth(0.8)

for i, c in enumerate((100, 1000, 10000, 30000)):
    ax.scatter(3.0 + i * 4.4, 12.0, s=size(c), marker="D", facecolor="#CFCABA",
               edgecolor="#8A8378", lw=0.6, zorder=4)
    ax.text(3.0 + i * 4.4, 6.5, f"{c:,}", fontsize=7.4, color=MUTED, ha="center")
ax.text(3.0, 18.5, "marker area ∝ cells, one scale across both sets", fontsize=8.2, color=MUTED)

uzc = np.array([r["cells"] for r in uz_m]); rpc = np.array([r["cells"] for r in rp_m])
ax.text(0.015, 0.975,
        f"median size   real parts {np.median(rpc):,.0f} cells   ·   unzoned patches "
        f"{np.median(uzc):,.0f} cells   ·   a gap of "
        f"{np.log10(np.median(rpc)) - np.log10(np.median(uzc)):.2f} decades",
        transform=ax.transAxes, fontsize=9.0, color=HEAD, va="top", weight="bold")

furniture(fig, "U N Z O N E D   ·   B E T W E E N   U N I T S",
          "The two sets on one panel, and the size gap between them",
          "115 real paddock × community parts behind, 93 unzoned patches in front. "
          "The registered line is drawn as a reference only.")
fig.text(0.045, 0.108,
         "DESCRIPTIVE ONLY — no line is fitted to the unzoned patches, and no residual is computed "
         "anywhere on this figure. Stage A2, which would do both, has not run.",
         fontsize=9.2, color="#B03A2E", ha="left", weight="bold")
fig.text(0.045, 0.072, FOOT1, fontsize=7.7, color=MUTED, ha="left")
fig.text(0.045, 0.046, FOOT2, fontsize=7.7, color=MUTED, ha="left")
fig.text(0.045, 0.016, "Output/unzoned/figures — internal working output, not registered in "
                       "figure_asset. Producer scripts/12_zone_stratum/UNZONED_scatter_pair.py",
         fontsize=7.4, color=MUTED, ha="left")
f1 = OUT / "UNZONED_F1_between_units_two_sets.png"
fig.savefig(f1, dpi=200, facecolor=BG); plt.close(fig)
print(f"[wrote] {f1.name}  ({f1.stat().st_size/1024:.0f} KB)")

# ================================================================ FIGURE 2
fig = plt.figure(figsize=(15.4, 7.6), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.05, right=0.985, top=0.795, bottom=0.215, wspace=0.19)
axA, axB = fig.add_subplot(1, 2, 1), fig.add_subplot(1, 2, 2)
for a in (axA, axB):
    axstyle(a)

rx, ry = demean(RP, "part_id", "veg_p05_spatial", "inund_pct", "n_pixels_part")
ux, uy = demean(UZ, "patch_id", "veg_p05_spatial", "inund_pct", "n_cells")
axA.scatter(rx, ry, s=5, color="#B9C4C0", alpha=0.35, lw=0, zorder=2)
axA.scatter(ux, uy, s=7, color="#2165AC", alpha=0.30, lw=0, zorder=3)
xs = np.linspace(-55, 75, 40)
axA.plot(xs, S_RP * xs, color="#7C837E", lw=2.4, zorder=5)
axA.plot(xs, S_UZ * xs, color=INK, lw=3.0, zorder=6)
axA.axhline(0, color="#CFCABA", lw=0.9, zorder=1); axA.axvline(0, color="#CFCABA", lw=0.9, zorder=1)
axA.set_xlim(-55, 75); axA.set_ylim(-45, 45)
BOX = dict(boxstyle="round,pad=0.28", facecolor="#FFFFFF", edgecolor="none", alpha=0.86)
axA.text(72, S_UZ * 72 + 4.5, f"unzoned patches   +{S_UZ:.4f}   n = 3,253 patch-years, 93 patches",
         fontsize=8.8, color=INK, ha="right", weight="bold", bbox=BOX, zorder=8)
axA.text(72, S_RP * 72 - 7.5, f"real parts   +{S_RP:.4f}   n = 4,025 part-years, 115 parts",
         fontsize=8.8, color="#5F6B67", ha="right", weight="bold", bbox=BOX, zorder=8)
axA.set_xlabel("wetness, demeaned within the unit  (percentage points)", fontsize=10, color=BODY)
axA.set_ylabel("cover floor, demeaned within the unit  (percentage points)", fontsize=10, color=BODY)
axA.set_title("A · the within response — every unit is its own baseline", fontsize=11.5,
              color=HEAD, weight="bold", loc="left", pad=8)
axA.text(0.015, 0.965, "both slopes are within (unit fixed effects), pixel-weighted;\n"
                       "read from the R-side fits, not fitted here",
         transform=axA.transAxes, fontsize=8.4, color=MUTED, va="top", linespacing=1.5)

up = np.array([float(r["slope"]) for r in rows(T / "UNZONED_stageA1_per_patch_slopes.csv")])
rp = np.array([float(r["slope"]) for r in rows(T / "WITHIN1_per_part_slopes.csv")])
bins = np.linspace(0, 0.8, 33)
# DENSITIES, not counts: 91 patches against 115 parts, so raw bar heights are not
# comparable and the unzoned distribution's apparent rightward shift is partly an n effect.
axB.hist(np.clip(rp, 0, 0.8), bins=bins, density=True, color="#B9C4C0", edgecolor="#8A8378",
         lw=0.4, zorder=2, label=f"real parts — {int((rp > 0).sum())} of {len(rp)} positive")
axB.hist(np.clip(up, 0, 0.8), bins=bins, density=True, color="#2165AC", edgecolor="#1B4E86",
         lw=0.5, alpha=0.72, zorder=3,
         label=f"unzoned patches — {int((up > 0).sum())} of {len(up)} positive")
axB.axvline(0, color="#B03A2E", lw=2.0, zorder=6)
axB.text(0.006, axB.get_ylim()[1] * 0.96, "zero", fontsize=8.6, color="#B03A2E", weight="bold")
axB.set_xlim(-0.03, 0.8)
axB.set_xlabel("per-unit slope  (pp of cover per pp of wetness)", fontsize=10, color=BODY)
axB.set_ylabel("density  (area sums to 1 in each set)", fontsize=10, color=BODY)
axB.set_title("B · every unit in both sets sits to the right of zero", fontsize=11.5,
              color=HEAD, weight="bold", loc="left", pad=8)
lb = axB.legend(loc="upper right", fontsize=8.8, frameon=True, facecolor="#FFFFFF",
                edgecolor="#DDD8CC", labelcolor=BODY)
lb.get_frame().set_linewidth(0.8)
axB.text(0.98, 0.72, f"{int((up > 0).sum())}/{len(up)}   and   {int((rp > 0).sum())}/{len(rp)}",
         transform=axB.transAxes, fontsize=16, color=HEAD, weight="bold", ha="right")
axB.text(0.98, 0.665, "positive slopes", transform=axB.transAxes, fontsize=8.8,
         color=MUTED, ha="right")
axB.text(0.98, 0.60, f"{int((up > 0.8).sum())} patch and {int((rp > 0.8).sum())} part slopes exceed "
                     f"0.8 and are clipped to the last bin",
         transform=axB.transAxes, fontsize=7.8, color=MUTED, ha="right", style="italic")

furniture(fig, "U N Z O N E D   ·   W I T H I N   U N I T S",
          "What an extra point of wetness buys the same ground",
          "The within slope answers how ground responds over time. It is a different question from "
          "the between-unit line and never corrects it.")
fig.text(0.05, 0.112,
         "Two patches carry only two distinct wetness values across 35 years and get no per-unit fit; "
         "both remain in the pooled estimate. Cluster is the PATCH — there is no paddock on this "
         "ground — while the real-part interval clusters on zone_fid.",
         fontsize=8.4, color=HEAD, ha="left")
fig.text(0.05, 0.075, FOOT1, fontsize=7.7, color=MUTED, ha="left")
fig.text(0.05, 0.049, FOOT2, fontsize=7.7, color=MUTED, ha="left")
fig.text(0.05, 0.018, "Output/unzoned/figures — internal working output, not registered in "
                      "figure_asset. Slopes read from UNZONED_stageA1_fits.csv and WITHIN1_fits.csv; "
                      "nothing is estimated in this producer.", fontsize=7.4, color=MUTED, ha="left")
f2 = OUT / "UNZONED_F2_within_response.png"
fig.savefig(f2, dpi=200, facecolor=BG); plt.close(fig)
print(f"[wrote] {f2.name}  ({f2.stat().st_size/1024:.0f} KB)")
print(f"\nmedian size: real parts {np.median(rpc):,.0f} cells, unzoned {np.median(uzc):,.0f} cells "
      f"({np.log10(np.median(rpc)) - np.log10(np.median(uzc)):.2f} decades)")
print("PROVISIONAL - unregistered, for reference, not for onward circulation. Not in the pack.")
