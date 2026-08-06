#!/usr/bin/env python
"""PARTREG Stage 1 figure - the full-period fit at part grain, against the registered line.

Spec section 2.3 and 2.5. Reads only the Stage 1 CSVs and dim_headline_number; computes
no new quantity. Panel A is the scatter with every fitted line the stage produced;
panel B is the percentile sweep, which is what closes the "which percentile is canonical"
question with evidence rather than preference.

matplotlib rules: figsize declared, subplots_adjust explicit, no bbox_inches='tight'.
"""
import csv
import sqlite3
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Output" / "figures" / "PARTREG_S1_floor_vs_flood_115_parts.png"

INK, BG, HEAD, BODY, MUTED = "#0F3947", "#F8F7F2", "#26302E", "#5F6B67", "#8A8378"
RUST, GOLD = "#9C5B2E", "#C79A3B"
PAL = {"aeolian": ("#8A5F1E", "#C79A3B", "Aeolian Chenopod"),
       "riverine": ("#2A6560", "#3B8A8F", "Riverine Chenopod"),
       "inland": ("#1B4E86", "#2165AC", "Inland Floodplain")}

S = list(csv.DictReader(open(T / "PARTREG_part_summary_by_period.csv", encoding="utf-8-sig")))
F = {r["fit_id"]: r for r in csv.DictReader(
    open(T / "PARTREG_part_regression_coefficients.csv", encoding="utf-8-sig"))}
fl = lambda fid, k: float(F[fid][k])

con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
REG = {k: con.execute("SELECT pinned_value FROM dim_headline_number WHERE number_id=?",
                      (k,)).fetchone()[0]
       for k in ("floor_flood_slope_64pdk", "floor_flood_intercept_64pdk",
                 "floor_flood_r_64pdk", "floor_flood_residual_sd_64pdk")}
con.close()
R_SL, R_IN = REG["floor_flood_slope_64pdk"], REG["floor_flood_intercept_64pdk"]

fig = plt.figure(figsize=(15.0, 7.4), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.052, right=0.945, top=0.845, bottom=0.150, wspace=0.26)
axA = fig.add_subplot(1, 2, 1); axB = fig.add_subplot(1, 2, 2)
for a in (axA, axB):
    a.set_facecolor("#FFFFFF")
    for sp in ("top", "right"): a.spines[sp].set_visible(False)
    for sp in ("left", "bottom"): a.spines[sp].set_color("#CFCABA")
    a.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    a.grid(True, color="#EFEBE0", lw=0.8, zorder=0)
    a.set_axisbelow(True)

# ---------------- panel A - the scatter -----------------------------------------
x = np.array([float(r["inund_mean"]) for r in S])
y = np.array([float(r["floor_mean"]) for r in S])
w = np.array([float(r["weight"]) for r in S])
cs = [r["community_short"] for r in S]
for k, (deep, mark, lab) in PAL.items():
    m = [i for i, c in enumerate(cs) if c == k]
    axA.scatter(x[m], y[m], s=8 + 90 * np.sqrt(w[m] / w.max()), facecolor=mark, edgecolor=deep,
                lw=0.6, alpha=0.85, zorder=3, label=f"{lab}  (n={len(m)})")
xs = np.linspace(0, max(x) * 1.04, 50)
for k, (deep, _, _) in PAL.items():
    axA.plot(xs, fl(f"2.6_{k}", "intercept") + fl(f"2.6_{k}", "slope") * xs,
             color=deep, lw=1.3, ls=(0, (5, 3)), zorder=4, alpha=0.9)
axA.plot(xs, fl("2.3_weighted", "intercept") + fl("2.3_weighted", "slope") * xs,
         color=INK, lw=3.4, zorder=5, label=f"115 parts, pixel-weighted   {fl('2.3_weighted','slope'):+.3f}")
axA.plot(xs, R_IN + R_SL * xs, color=RUST, lw=1.8, ls=(0, (6, 4)), zorder=6,
         label=f"registered 64-paddock line   {R_SL:+.3f}")
axA.set_xlim(0, max(x) * 1.04); axA.set_ylim(0, 100)
axA.set_xlabel("share of the part's cells seen wet, averaged over 35 years  (%)", fontsize=10, color=BODY)
axA.set_ylabel("cover in the poorest patches, averaged over 35 years  (%)", fontsize=10, color=BODY)
axA.set_title("A · one point per paddock × community part", fontsize=11.5, color=HEAD,
              weight="bold", loc="left", pad=8)
leg = axA.legend(loc="lower right", fontsize=8.4, frameon=True, facecolor="#FFFFFF",
                 edgecolor="#DDD8CC", labelcolor=BODY)
leg.get_frame().set_linewidth(0.8)
axA.text(0.015, 0.965,
         f"pooled r {fl('2.3_weighted','r'):.3f}   ·   residual SD {fl('2.3_weighted','resid_sd'):.2f} pp"
         f"\nregistered line: r {REG['floor_flood_r_64pdk']:.2f}   ·   residual SD "
         f"{REG['floor_flood_residual_sd_64pdk']:.2f} pp   ·   64 paddocks",
         transform=axA.transAxes, fontsize=8.6, color=MUTED, va="top", linespacing=1.5)
axA.text(0.015, 0.845, "marker area ∝ part size  (33 to 32,399 cells)",
         transform=axA.transAxes, fontsize=8.0, color=MUTED, va="top", style="italic")

# ---------------- panel B - the percentile sweep --------------------------------
PS = [5, 10, 20, 30, 50]
sl = [fl(f"2.5_p{p:02d}", "slope") for p in PS]
lo = [fl(f"2.5_p{p:02d}", "boot_slope_p2_5") for p in PS]
hi = [fl(f"2.5_p{p:02d}", "boot_slope_p97_5") for p in PS]
rr = [fl(f"2.5_p{p:02d}", "r") for p in PS]
sd = [fl(f"2.5_p{p:02d}", "resid_sd") for p in PS]
xi = np.arange(len(PS))
axB.fill_between(xi, lo, hi, color=GOLD, alpha=0.22, zorder=2, label="slope, 95% bootstrap")
axB.plot(xi, sl, color=RUST, lw=2.4, marker="o", ms=6, zorder=4, label="slope  (pp cover per pp wet)")
axB.axhline(R_SL, color=MUTED, lw=1.1, ls=(0, (4, 3)), zorder=3)
axB.text(len(PS) - 1.02, R_SL + 0.012, f"registered paddock-grain slope {R_SL:+.3f}",
         fontsize=8.0, color=MUTED, ha="right")
axB.set_xticks(xi); axB.set_xticklabels([f"p{p:02d}" for p in PS])
axB.set_ylim(0.25, 0.68)
axB.set_xlabel("cover percentile used as the floor", fontsize=10, color=BODY)
axB.set_ylabel("fitted slope", fontsize=10, color=RUST)
axB.set_title("B · does the choice of percentile change the answer?", fontsize=11.5, color=HEAD,
              weight="bold", loc="left", pad=8)

axC = axB.twinx()
axC.set_facecolor("none")
for sp in ("top", "left"): axC.spines[sp].set_visible(False)
axC.spines["right"].set_color("#CFCABA"); axC.spines["bottom"].set_color("#CFCABA")
axC.plot(xi, rr, color=INK, lw=2.0, marker="s", ms=5, zorder=4, label="r")
axC.plot(xi, np.array(sd) / 10, color="#7C837E", lw=1.6, marker="^", ms=5, zorder=4,
         label="residual SD ÷ 10  (pp)")
axC.set_ylim(0.25, 0.90)
axC.set_ylabel("r   and   residual SD ÷ 10", fontsize=10, color=INK)
axC.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
axB.text(0.30, sl[1] - 0.035, "slope", fontsize=9.4, color=RUST, weight="bold")
axB.text(0.30, lo[1] + 0.020, "95% bootstrap", fontsize=8.2, color="#A98A44")
axC.text(1.28, rr[1] + 0.028, "r", fontsize=9.4, color=INK, weight="bold")
axC.text(2.0, 0.445, "residual SD ÷ 10", fontsize=8.6, color="#7C837E", weight="bold", ha="center")
axB.text(0.02, 0.045,
         "the slope falls and the fit tightens as the percentile rises — the floor is the\n"
         "noisiest and most water-responsive part of the distribution, which is why it is the\n"
         "metric that carries the signal rather than the one that fits best",
         transform=axB.transAxes, fontsize=8.4, color=BODY, va="bottom", linespacing=1.6)

# ---------------- furniture ------------------------------------------------------
fig.text(0.052, 0.955, "P A R T   G R A I N   ·   F U L L   P E R I O D", fontsize=10.5,
         color=RUST, weight="bold", ha="left")
fig.text(0.052, 0.905, "Cover floor against inundation, on the paddock × community part",
         fontsize=17.5, color=HEAD, weight="bold", ha="left")
fig.text(0.052, 0.055,
         "Support: pixel, aggregated to part.  Aggregation order: OLS across parts of across-year means of "
         "within-year across-cell quantities.  Period 1988–2022, 35 water years.  Weighting: pixel-weighted by "
         f"part cell count; the unweighted slope is {fl('2.3_unweighted','slope'):+.3f}.",
         fontsize=7.8, color=MUTED, ha="left")
fig.text(0.052, 0.026,
         "Intervals are 2,000 bootstrap draws resampling paddocks with replacement, clustered on zone_fid — "
         "115 parts nested in 64 paddocks are not 115 independent observations.  No p-values.",
         fontsize=7.8, color=MUTED, ha="left")

OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {OUT}  ({OUT.stat().st_size/1024:.0f} KB)")
