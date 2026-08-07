#!/usr/bin/env python
"""Pack v1.3 T2 - rebuild the two shipping figures. Captions come from the register.

THE CAPTION REGISTER IS THE SOURCE. Every word of text on either figure is read from
docs/reference_update/Gayini_caption_register.md at render time. This script holds no
caption copy, so a caption edited in the register changes the figure on the next run
and cannot silently diverge.

Three-periods rebuild, per the task list:
  - panel order C, A, B - whole record first, then the two eras
  - community lines on panel C from registered fits 2.6_aeolian / 2.6_riverine /
    2.6_inland; the TWO CHENOPOD LINES ARE LIGHTER AND DOTTED because both intervals
    span zero and a solid line would assert more than the data carries
  - title answers its own question
  - opacity legend removed - AND SO IS THE OPACITY ENCODING. The task list removes the
    legend; carrying an undocumented visual channel is worse than carrying neither, so
    marker alpha is now constant. Flagged as a judgement call, not an instruction.
  - marker-size note on panel C only
  - footer trimmed to the register's five blocks

Residual maps: panels unchanged, footer replaced from the register.

PARTREG_S1_floor_vs_flood_115_parts.png is NOT rebuilt and is not in v1.3.

Nothing is estimated here. Every slope drawn is read from the R-side fits or from
dim_headline_number.
"""
from __future__ import annotations

import csv
import sqlite3
import sys
import textwrap
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from caption_register import blocks, section_name, strip_md          # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = ROOT / "Output" / "figures"
F3 = "PARTREG_S2_three_periods_115_parts.png"
FM = "PARTREG_S2_residual_maps_three_periods.png"

INK, BG, HEAD, BODY, MUTED = "#0F3947", "#F8F7F2", "#26302E", "#5F6B67", "#8A8378"
RUST, GOLD = "#9C5B2E", "#C79A3B"
PAL = {"aeolian": ("#8A5F1E", "#C79A3B", "Aeolian Chenopod"),
       "riverine": ("#2A6560", "#3B8A8F", "Riverine Chenopod"),
       "inland": ("#1B4E86", "#2165AC", "Inland Floodplain")}
SPANS_ZERO = {"aeolian", "riverine"}      # both chenopod intervals include zero


def rows(p):
    return list(csv.DictReader(open(p, encoding="utf-8-sig")))


S = rows(T / "PARTREG_S2_part_summary_by_period.csv")
FITS = {r["fit_id"]: r for r in rows(T / "PARTREG_S2_regression_coefficients.csv")
        + rows(T / "PARTREG_part_regression_coefficients.csv")}
PANELS = [("whole_record", "C", "Panel C"), ("cropping_era", "A", "Panel A"),
          ("post_management", "B", "Panel B")]


def wrapped(paras, width):
    return "\n".join(textwrap.fill(strip_md(p), width) for p in paras)


# ================================================================= three periods
fig = plt.figure(figsize=(16.0, 10.6), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.048, right=0.988, top=0.775, bottom=0.395, wspace=0.16)
axes = [fig.add_subplot(1, 3, i + 1) for i in range(3)]

for ax, (code, letter, sec) in zip(axes, PANELS):
    ax.set_facecolor("#FFFFFF")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color("#CFCABA")
    ax.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    ax.grid(True, color="#EFEBE0", lw=0.8, zorder=0)
    ax.set_axisbelow(True)

    R = [r for r in S if r["period"] == code and r["meets_support"] == "1"]
    f = FITS[f"S2_{code}_common"]
    sl, it = float(f["slope"]), float(f["intercept"])
    for r in R:
        deep, mark, _ = PAL[r["community_short"]]
        cons = r["conserved"] == "1"
        ax.scatter(float(r["inund_mean"]), float(r["floor_mean"]),
                   s=8 + 90 * np.sqrt(float(r["n_pixels_part"]) / 32399),
                   facecolor=mark, edgecolor=(INK if cons else deep),
                   lw=(2.0 if cons else 0.5), alpha=0.85, zorder=(4 if cons else 3))
    xs = np.linspace(0, 62, 40)
    if code == "post_management":
        fa = FITS["S2_cropping_era_common"]
        ax.plot(xs, float(fa["intercept"]) + float(fa["slope"]) * xs, color=INK, lw=1.5,
                ls=(0, (5, 4)), alpha=0.45, zorder=4)
    if code == "whole_record":
        for k, (deep, _, lab) in PAL.items():
            fc = FITS[f"2.6_{k}"]
            dotted = k in SPANS_ZERO
            ax.plot(xs, float(fc["intercept"]) + float(fc["slope"]) * xs, color=deep,
                    lw=(1.1 if dotted else 1.9), ls=((0, (1.5, 2.2)) if dotted else (0, (6, 3))),
                    alpha=(0.55 if dotted else 0.95), zorder=5)
    ax.plot(xs, it + sl * xs, color=INK, lw=2.8, zorder=6)
    ax.set_xlim(0, 62); ax.set_ylim(0, 100)
    ax.set_xticks([0, 10, 20, 30, 40, 50, 60]); ax.set_yticks([0, 20, 40, 60, 80, 100])
    ax.set_xlabel("share of the part's cells seen wet, mean over the period  (%)",
                  fontsize=9.5, color=BODY)
    if code == "whole_record":
        ax.set_ylabel("cover in the poorest patches, mean over the period  (%)",
                      fontsize=9.5, color=BODY)
    ax.text(0.03, 0.965, wrapped(blocks(F3, sec)[:1], 46), transform=ax.transAxes,
            fontsize=8.6, color=HEAD, va="top", linespacing=1.5)
    if code == "whole_record":
        # paragraph 2 moves to the caption band: in-panel it crossed the community lines
        ax.text(0.03, 0.045, "marker area ∝ part size  (33 to 32,399 cells)",
                transform=ax.transAxes, fontsize=8.0, color=MUTED, style="italic")

# panel headings, taken verbatim from the register's section names
for ax, (code, letter, sec) in zip(axes, PANELS):
    ax.set_title(section_name(F3, sec).replace("Panel ", ""), fontsize=12,
                 color=HEAD, weight="bold", loc="left", pad=7)

h = [plt.Line2D([], [], marker="o", ls="", markerfacecolor=m, markeredgecolor=d, markersize=8,
                label=lab) for k, (d, m, lab) in PAL.items()]
h.append(plt.Line2D([], [], marker="o", ls="", markerfacecolor="#FFFFFF", markeredgecolor=INK,
                    markeredgewidth=2.0, markersize=8, label="conserved — no line fitted"))
h.append(plt.Line2D([], [], color=PAL["inland"][0], lw=1.9, ls=(0, (6, 3)),
                    label="Inland community line"))
h.append(plt.Line2D([], [], color="#6E736E", lw=1.1, ls=(0, (1.5, 2.2)),
                    label="chenopod lines — interval spans zero"))
leg = axes[2].legend(handles=h, loc="lower right", fontsize=8.2, frameon=True,
                     facecolor="#FFFFFF", edgecolor="#DDD8CC", labelcolor=BODY)
leg.get_frame().set_linewidth(0.8)

title = blocks(F3, "Title")[0]
head, _, rest = strip_md(title).partition("? ")
fig.text(0.048, 0.962, "P A C K   v 1 . 3   ·   P A R T   G R A I N", fontsize=10.5,
         color=RUST, weight="bold", ha="left")
fig.text(0.048, 0.918, head + "?", fontsize=19, color=HEAD, weight="bold", ha="left")
fig.text(0.048, 0.878, rest, fontsize=11, color=RUST, ha="left")
fig.text(0.048, 0.842, textwrap.fill(strip_md(blocks(F3, "Subtitle")[0]), 150),
         fontsize=9.0, color=BODY, ha="left", linespacing=1.5)

y = 0.368
for para in blocks(F3, "Panel C")[1:]:
    t = textwrap.fill(strip_md(para), 168)
    fig.text(0.048, y, t, fontsize=8.6, color=HEAD, ha="left", va="top", linespacing=1.55)
    y -= 0.020 * (t.count("\n") + 1) + 0.012
y -= 0.008
for para in blocks(F3, "Footer"):
    t = textwrap.fill(strip_md(para), 178)
    fig.text(0.048, y, t, fontsize=8.0, color=MUTED, ha="left", va="top", linespacing=1.55)
    y -= 0.019 * (t.count("\n") + 1) + 0.010

OUT.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT / F3, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {F3}  ({(OUT/F3).stat().st_size/1024:.0f} KB)  captions from the register")
