#!/usr/bin/env python
"""PARTREG Stage 2 figure - three periods, three fitted relationships.

Reads only the Stage 2 CSVs; computes no new quantity.

Design-seat rulings carried onto the face of the figure:
  - the four transition years are stated, not left to read as an artefact
  - period LEVELS are never compared; only the fitted relationships
  - post-management is five water years and the figure says so
  - across-year spread on the cover axis is encoded as marker OPACITY rather than
    115 crossing whiskers: solid = steady, faint = swings between years
  - the water axis carries no spread marks at all, because year-to-year movement is
    2.2x the differences between parts and every point would become a bar wider than
    the plot's meaningful range

matplotlib rules: figsize declared, subplots_adjust explicit, no bbox_inches='tight'.
"""
import csv
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Output" / "figures" / "PARTREG_S2_three_periods_115_parts.png"

INK, BG, HEAD, BODY, MUTED = "#0F3947", "#F8F7F2", "#26302E", "#5F6B67", "#8A8378"
RUST, GOLD = "#9C5B2E", "#C79A3B"
PAL = {"aeolian": ("#8A5F1E", "#C79A3B", "Aeolian Chenopod"),
       "riverine": ("#2A6560", "#3B8A8F", "Riverine Chenopod"),
       "inland": ("#1B4E86", "#2165AC", "Inland Floodplain")}

S = list(csv.DictReader(open(T / "PARTREG_S2_part_summary_by_period.csv", encoding="utf-8-sig")))
F = {r["fit_id"]: r for r in csv.DictReader(
    open(T / "PARTREG_S2_regression_coefficients.csv", encoding="utf-8-sig"))}
RATIO = list(csv.DictReader(open(T / "PARTREG_S2_spread_ratio.csv", encoding="utf-8-sig")))[0]

PANELS = [("cropping_era", "A · cropping era", "1988–2013", "26 water years"),
          ("post_management", "B · post-management", "2018–2022", "5 water years"),
          ("whole_record", "C · whole record", "1988–2022", "35 water years")]

rows = {c: [r for r in S if r["period"] == c and r["meets_support"] == "1"] for c, *_ in PANELS}
iqr_all = np.array([float(r["floor_spread_iqr"]) for r in S])
IQ_LO, IQ_HI = np.quantile(iqr_all, 0.05), np.quantile(iqr_all, 0.95)


def alpha_of(v):
    t = np.clip((float(v) - IQ_LO) / (IQ_HI - IQ_LO), 0, 1)
    return 0.95 - 0.65 * t


fig = plt.figure(figsize=(16.0, 7.6), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.045, right=0.988, top=0.815, bottom=0.275, wspace=0.16)
axes = [fig.add_subplot(1, 3, i + 1) for i in range(3)]

for ax, (code, title, plabel, ylab) in zip(axes, PANELS):
    ax.set_facecolor("#FFFFFF")
    for sp in ("top", "right"): ax.spines[sp].set_visible(False)
    for sp in ("left", "bottom"): ax.spines[sp].set_color("#CFCABA")
    ax.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    ax.grid(True, color="#EFEBE0", lw=0.8, zorder=0); ax.set_axisbelow(True)

    R = rows[code]
    f = F[f"S2_{code}_common"]
    sl, it = float(f["slope"]), float(f["intercept"])
    for r in R:
        deep, mark, _ = PAL[r["community_short"]]
        ax.scatter(float(r["inund_mean"]), float(r["floor_mean"]),
                   s=8 + 90 * np.sqrt(float(r["n_pixels_part"]) / 32399),
                   facecolor=mark, edgecolor=deep, lw=0.5,
                   alpha=alpha_of(r["floor_spread_iqr"]), zorder=3)
    xs = np.linspace(0, 62, 40)
    ax.plot(xs, it + sl * xs, color=INK, lw=2.8, zorder=5)
    ax.set_xlim(0, 62); ax.set_ylim(0, 100)
    ax.set_title(f"{title}   ·   {plabel}", fontsize=12, color=HEAD, weight="bold",
                 loc="left", pad=7)
    ax.text(0.03, 0.965,
            f"slope {sl:+.3f}   ·   r {float(f['r']):.3f}\n"
            f"95% [{float(f['boot_slope_p2_5']):+.3f}, {float(f['boot_slope_p97_5']):+.3f}]\n"
            f"{ylab}   ·   n = {f['n']} parts",
            transform=ax.transAxes, fontsize=9.0, color=HEAD, va="top", linespacing=1.6)
    ax.set_xlabel("share of the part's cells seen wet, mean over the period  (%)",
                  fontsize=9.5, color=BODY)
    if code == "cropping_era":
        ax.set_ylabel("cover in the poorest patches, mean over the period  (%)",
                      fontsize=9.5, color=BODY)

# ---- the opacity key, drawn rather than described ------------------------------
ax0 = axes[0]
for i, (lab, v) in enumerate((("steady", IQ_LO), ("", (IQ_LO + IQ_HI) / 2), ("swings", IQ_HI))):
    ax0.scatter(3.0 + i * 4.6, 9.0, s=70, facecolor="#7C837E", edgecolor="#4E5450",
                lw=0.5, alpha=alpha_of(v), zorder=4, clip_on=False)
ax0.text(3.0, 15.0, "steady", fontsize=8.0, color=MUTED, ha="center")
ax0.text(12.2, 15.0, "swings", fontsize=8.0, color=MUTED, ha="center")
ax0.text(3.0, 3.0, "opacity = across-year spread of the cover floor (IQR)",
         fontsize=8.0, color=MUTED, ha="left")

# ---- community legend on the last panel ----------------------------------------
h = [plt.Line2D([], [], marker="o", ls="", markerfacecolor=m, markeredgecolor=d,
                markersize=8, label=f"{lab}  (n={sum(1 for r in rows['whole_record'] if r['community_short']==k)})")
     for k, (d, m, lab) in PAL.items()]
leg = axes[2].legend(handles=h, loc="lower right", fontsize=8.6, frameon=True,
                     facecolor="#FFFFFF", edgecolor="#DDD8CC", labelcolor=BODY)
leg.get_frame().set_linewidth(0.8)

# ---- furniture ------------------------------------------------------------------
fig.text(0.045, 0.955, "P A R T   G R A I N   ·   T H R E E   P E R I O D S", fontsize=10.5,
         color=RUST, weight="bold", ha="left")
fig.text(0.045, 0.900, "Does the cover-and-water relationship change between eras?",
         fontsize=18, color=HEAD, weight="bold", ha="left")
fig.text(0.045, 0.855,
         "2014–2017 is excluded as a transition: control passed to the Nari Nari Tribal Council in 2013 and the "
         "irrigation bank cuts are dated 2018, so the four years between belong to neither window.",
         fontsize=9.2, color=RUST, ha="left")

L = [
    (0.205, 8.8, HEAD,
     "WHAT IS COMPARED, AND WHAT IS NOT.  Only the fitted relationships. Period levels are never compared: "
     "a slope is robust to how wet a window happened to be, because both axes move together; a mean is not."),
    (0.170, 8.8, HEAD,
     "All three slope intervals overlap, so the flatter post-management relationship is reported, not claimed — "
     "and it rests on five water years, a far weaker basis than 35 for any summary."),
    (0.130, 8.0, MUTED,
     "Spread, never uncertainty — no interval is placed on it, because consecutive years are not independent "
     "observations.  On the water axis, year-to-year movement within a part is "
     f"{float(RATIO['ratio_within_over_between']):.1f}× the differences in mean wetness between parts"),
    (0.098, 8.0, MUTED,
     f"(median across-year SD {float(RATIO['within_part_across_year_median_sd']):.1f} against a between-part SD of "
     f"{float(RATIO['between_part_sd_of_mean_water']):.1f}), and {RATIO['parts_with_water_iqr_over_92']} parts have a "
     "water IQR above 92 points — so the water axis carries no spread marks at all: drawn raw, every point would be a"),
    (0.066, 8.0, MUTED,
     "bar wider than the plot's meaningful range.  That ratio is the argument for comparing cover at like wetness "
     "rather than between periods."),
    (0.030, 7.6, MUTED,
     "Support: pixel, aggregated to part.  All 115 supported parts meet support in all three periods, so the common-set "
     "restriction drops none and costs nothing.  Pixel-weighted by part cell count.  Residuals in the attribute table "
     "are against each period's OWN line."),
    (0.006, 7.6, MUTED,
     "Intervals are 2,000 bootstrap draws resampling paddocks with replacement, clustered on zone_fid.  No p-values."),
]
for yy, sz, col, txt in L:
    fig.text(0.045, yy, txt, fontsize=sz, color=col, ha="left")

OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {OUT}  ({OUT.stat().st_size/1024:.0f} KB)")
