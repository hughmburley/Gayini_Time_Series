#!/usr/bin/env python
"""Pack v1.3 - the three-periods figure. Captions come from the register.

THE CAPTION REGISTER IS THE SOURCE. Every word on the face is read from
docs/reference_update/Gayini_caption_register.md at render time. This script holds no
caption copy, so a caption edited in the register changes the figure on the next run
and cannot silently diverge. That is why the register is edited first.

SECOND PASS, 7 August 2026. The figure is shown by Adrian to the Nari Nari Tribal
Council, so nothing on the face is for us:

  - no version eyebrow. Version control lives in the filename and the manifest
  - the question title and its subtitle are gone together. The question invited the
    reading the subtitle existed to prevent
  - THE THREE COMMUNITY LINES ARE DELETED. One fitted line per panel. This also removes
    an extrapolation defect: the Aeolian line was drawn to x = 60 on data ending at 19.7
  - the dashed cropping-era line STAYS in panel B - it is a period line, not a community
    line, and the legend's claim that panel B is flatter must be checkable from the face
  - all lines grey, thin, semi-transparent, and drawn BENEATH the point layer. Z-order
    matters as much as colour
  - colour-by-community stays on the markers: the three clouds stay visible without
    three lines asserting three slopes
  - one continuous legend block, journal style, full width, one body size plus one
    smaller size for the methods sentence

Panel order C, A, B, matching the residual maps: the whole record is the result and the
two eras are the sensitivity test.

Nothing is estimated here. Every slope drawn is read from the R-side fits.
"""
from __future__ import annotations

import csv
import sys
import textwrap
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from caption_register import blocks, strip_md          # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = ROOT / "Output" / "figures"
F3 = "PARTREG_S2_three_periods_115_parts.png"

BG, HEAD, BODY, MUTED = "#F8F7F2", "#26302E", "#5F6B67", "#8A8378"
INK = "#0F3947"
LINE = "#6E736E"                     # every fitted line: grey, thin, under the points
PAL = {"aeolian": ("#8A5F1E", "#C79A3B", "Aeolian Chenopod"),
       "riverine": ("#2A6560", "#3B8A8F", "Riverine Chenopod"),
       "inland": ("#1B4E86", "#2165AC", "Inland Floodplain")}
PANELS = [("whole_record", "Panel C"), ("cropping_era", "Panel A"),
          ("post_management", "Panel B")]


def rows(p):
    return list(csv.DictReader(open(p, encoding="utf-8-sig")))


S = rows(T / "PARTREG_S2_part_summary_by_period.csv")
FITS = {r["fit_id"]: r for r in rows(T / "PARTREG_S2_regression_coefficients.csv")
        + rows(T / "PARTREG_part_regression_coefficients.csv")}

fig = plt.figure(figsize=(16.0, 9.1), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.052, right=0.986, top=0.835, bottom=0.445, wspace=0.15)
axes = [fig.add_subplot(1, 3, i + 1) for i in range(3)]

for ax, (code, sec) in zip(axes, PANELS):
    ax.set_facecolor("#FFFFFF")
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        ax.spines[sp].set_color("#CFCABA")
    ax.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    ax.grid(True, color="#EFEBE0", lw=0.8, zorder=0)
    ax.set_axisbelow(True)

    f = FITS[f"S2_{code}_common"]
    sl, it = float(f["slope"]), float(f["intercept"])
    xs = np.linspace(0, 62, 40)

    # lines first, so they sit UNDER the points whatever their alpha
    if code == "post_management":
        fa = FITS["S2_cropping_era_common"]
        ax.plot(xs, float(fa["intercept"]) + float(fa["slope"]) * xs, color=LINE, lw=1.4,
                ls=(0, (5, 4)), alpha=0.55, zorder=1)
    ax.plot(xs, it + sl * xs, color=LINE, lw=1.6, alpha=0.75, zorder=1)

    for r in [x for x in S if x["period"] == code and x["meets_support"] == "1"]:
        deep, mark, _ = PAL[r["community_short"]]
        cons = r["conserved"] == "1"
        ax.scatter(float(r["inund_mean"]), float(r["floor_mean"]),
                   s=8 + 90 * np.sqrt(float(r["n_pixels_part"]) / 32399),
                   facecolor=mark, edgecolor=(INK if cons else deep),
                   lw=(1.8 if cons else 0.5), alpha=0.9, zorder=(4 if cons else 3))

    ax.set_xlim(0, 62); ax.set_ylim(0, 100)
    ax.set_xticks([0, 10, 20, 30, 40, 50, 60]); ax.set_yticks([0, 20, 40, 60, 80, 100])
    ax.set_title(strip_md(blocks(F3, sec)[0]), fontsize=12.5, color=HEAD, weight="bold",
                 loc="left", pad=8)
    ax.set_xlabel("share of the part's cells seen wet, mean over the period  (%)",
                  fontsize=9.5, color=BODY)
    if code == "whole_record":
        ax.set_ylabel("cover in the poorest patches, mean over the period  (%)",
                      fontsize=9.5, color=BODY)

keys = blocks(F3, "Legend keys")
h = [plt.Line2D([], [], marker="o", ls="", markerfacecolor=m, markeredgecolor=d, markersize=8,
                label=lab) for k, (d, m, lab) in PAL.items()]
h.append(plt.Line2D([], [], marker="o", ls="", markerfacecolor="#FFFFFF", markeredgecolor=INK,
                    markeredgewidth=1.8, markersize=8, label=strip_md(keys[0])))
h.append(plt.Line2D([], [], marker="o", ls="", markerfacecolor="#CFCABA",
                    markeredgecolor="#8A8378", markersize=11, label=strip_md(keys[1])))
leg = axes[2].legend(handles=h, loc="lower right", fontsize=9.0, frameon=True,
                     facecolor="#FFFFFF", edgecolor="#DDD8CC", labelcolor=BODY)
leg.get_frame().set_linewidth(0.8)

fig.text(0.052, 0.945, "Ground cover and water", fontsize=10.5, color=BODY, ha="left")
fig.text(0.052, 0.900, strip_md(blocks(F3, "Title")[0]), fontsize=19, color=HEAD,
         weight="bold", ha="left")

# one continuous legend block, journal style: no blank lines, no bold, full width
y = 0.378
cap = textwrap.fill(strip_md(blocks(F3, "Legend")[0]), 196)
fig.text(0.052, y, cap, fontsize=9.0, color=HEAD, ha="left", va="top", linespacing=1.62)
y -= 0.0221 * (cap.count("\n") + 1) + 0.020
meth = textwrap.fill(strip_md(blocks(F3, "Methods")[0]), 218)
fig.text(0.052, y, meth, fontsize=8.0, color=MUTED, ha="left", va="top", linespacing=1.62)

OUT.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT / F3, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {F3}  ({(OUT/F3).stat().st_size/1024:.0f} KB)  every word from the register")
