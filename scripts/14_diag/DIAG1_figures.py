#!/usr/bin/env python
"""DIAG-1 diagnostic panels.

DRAWS ONLY. Every quantity plotted here was estimated in R under Ruling AS and is read
from the Output/diag/ CSVs; this file fits nothing, and the one place it would be
tempting to (a smoothing line) draws the R-fitted curve from R's own coefficients.

House conventions that have cost hours before and are not rediscovered here:
  - never bbox_inches="tight": it silently changes the aspect ratio
  - figsize declared, subplots_adjust explicit
  - 4,025 and 3,253 points are never drawn raw (census display convention H5) - the
    within panels are hexbinned

Nothing is registered. These are diagnostics, not figure_asset rows.
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
PAL = {"aeolian": "#C79A3B", "riverine": "#3B8A8F", "inland": "#2165AC"}
GRID, SPINE = "#EFEBE0", "#CFCABA"

PLABEL = {"whole_record": "whole record, 1988-2022",
          "cropping_era": "cropping era, 1988-2013",
          "post_management": "post-management, 2018-2022"}


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


def foot(f, text, y=0.022):
    f.text(0.045, y, text, color=MUTED, fontsize=7.6, va="bottom", ha="left", wrap=True)


def area(n, lo=8, hi=190):
    n = np.asarray(n, float)
    r = (n - n.min()) / max(n.max() - n.min(), 1e-9)
    return lo + (hi - lo) * np.sqrt(r)


def save(f, name):
    FIG.mkdir(parents=True, exist_ok=True)
    f.savefig(FIG / name, dpi=200, facecolor=BG)
    plt.close(f)
    print(f"  [wrote] {name}")


# ================================================================ the data ========
PW = pd.read_csv(DIAG / "DIAG1_between_pointwise.csv")
QT = pd.read_csv(DIAG / "DIAG1_heteroscedasticity.csv")
LZ = pd.read_csv(DIAG / "DIAG1_local_z.csv")
IN = pd.read_csv(DIAG / "DIAG1_influence.csv")
FC = pd.read_csv(DIAG / "DIAG1_form_comparison.csv")
LG = pd.read_csv(DIAG / "DIAG1_lag_fits.csv")
SER = pd.read_csv(DIAG / "DIAG1_part_series_summary.csv")
WD = pd.read_csv(DIAG / "DIAG1_within_diagnostics.csv")
WP = pd.read_csv(DIAG / "DIAG1_within_pointwise.csv")

SET_PART = [s for s in WP.set.unique() if s.startswith("part")][0]
SET_PATCH = [s for s in WP.set.unique() if s.startswith("patch")][0]


# ============================================== A2 - the standard four, per period ==
def panels_for(period):
    d = PW[PW.period == period]
    f = plt.figure(figsize=(11.4, 8.7))
    f.patch.set_facecolor(BG)
    f.subplots_adjust(left=0.072, right=0.972, top=0.835, bottom=0.115,
                      wspace=0.235, hspace=0.355)
    ax = [f.add_subplot(2, 2, i) for i in (1, 2, 3, 4)]
    sz = area(d.n_pixels_part)

    def scat(a, x, y, **kw):
        for cm, g in d.groupby("community_short"):
            k = d.community_short == cm
            a.scatter(np.asarray(x)[k], np.asarray(y)[k], s=sz[k], c=PAL[cm],
                      alpha=0.62, lw=0.5, edgecolor="#FFFFFF", zorder=3, **kw)

    scat(ax[0], d.fitted, d.residual)
    ax[0].axhline(0, color=MUTED, lw=1.0, zorder=2)
    style(ax[0], "Residual against fitted",
          "fitted cover floor (%)", "residual (pp)")

    scat(ax[1], d.x_inund_mean, d.residual)
    ax[1].axhline(0, color=MUTED, lw=1.0, zorder=2)
    q = QT[(QT.period == period) & (QT.scope == "all communities")]
    for _, r in q.iterrows():
        ax[1].plot([r.x_lower, r.x_upper], [r.residual_sd_sample] * 2, color=INK, lw=1.9, zorder=4)
        ax[1].plot([r.x_lower, r.x_upper], [-r.residual_sd_sample] * 2, color=INK, lw=1.9, zorder=4)
    style(ax[1], "Residual against the water axis, with the quartile SDs drawn",
          "share of the part's cells seen wet, mean over years (%)", "residual (pp)")

    scat(ax[2], d.fitted, d.sqrt_abs_std_residual)
    style(ax[2], "Scale-location", "fitted cover floor (%)",
          "sqrt |standardised residual|")

    scat(ax[3], d.hat_leverage, d.std_residual)
    ax[3].axhline(0, color=MUTED, lw=1.0, zorder=2)
    top = d.nlargest(4, "hat_leverage")
    ax[3].set_xlim(-0.004, d.hat_leverage.max() * 1.28)   # room for the outermost label
    for _, r in top.iterrows():
        ax[3].annotate(f"{r.paddock_name} / {r.community_short}",
                       (r.hat_leverage, r.std_residual), fontsize=7.2, color=BODY,
                       ha="right", xytext=(-6, 5), textcoords="offset points")
    style(ax[3], "Leverage against standardised residual, four highest named",
          "leverage h", "standardised residual")

    hs = [plt.Line2D([], [], marker="o", ls="", color=PAL[c], label=c.capitalize(),
                     markersize=7) for c in ("aeolian", "riverine", "inland")]
    lg = ax[0].legend(handles=hs, frameon=True, fontsize=8, labelcolor=BODY,
                      loc="lower left", facecolor="#FFFFFF", edgecolor=SPINE)
    lg.get_frame().set_linewidth(0.7)

    f.text(0.042, 0.962, "The four standard diagnostics for the between-unit fit",
           color=HEAD, fontsize=14.5, va="top")
    f.text(0.042, 0.921,
           f"115 parts, {PLABEL[period]}, pixel-weighted, clustered on the paddock.\n"
           "Marker area is proportional to the part's cell count.",
           color=BODY, fontsize=9.6, va="top", linespacing=1.5)
    foot(f, "BETWEEN-UNIT estimand: how the across-year mean floor differs between parts that differ in wetness. Support: pixel.\n"
            "A residual is a departure from a fitted expectation, not a condition score and not a management effect. Nothing here is registered.")
    save(f, f"DIAG1_A2_panels_{period}.png")


for p in ("whole_record", "cropping_era", "post_management"):
    panels_for(p)

# ======================================================= A3 - heteroscedasticity ==
d = PW[PW.period == "whole_record"]
f = plt.figure(figsize=(11.0, 5.7))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.068, right=0.978, top=0.745, bottom=0.215, wspace=0.215)
a1, a2 = f.add_subplot(1, 2, 1), f.add_subplot(1, 2, 2)

for cm, g in d.groupby("community_short"):
    a1.scatter(g.x_inund_mean, g.residual.abs(), s=area(d.n_pixels_part)[d.community_short == cm],
               c=PAL[cm], alpha=0.6, lw=0.5, edgecolor="#FFFFFF", zorder=3)
q = QT[(QT.period == "whole_record") & (QT.scope == "all communities")]
for _, r in q.iterrows():
    a1.plot([r.x_lower, r.x_upper], [r.residual_sd_sample] * 2, color=INK, lw=2.6, zorder=5)
    a1.annotate(f"{r.residual_sd_sample:.2f} pp", ((r.x_lower + r.x_upper) / 2, r.residual_sd_sample),
                fontsize=8, color=INK, ha="center", xytext=(0, 6), textcoords="offset points")
style(a1, "Residual spread falls as the country gets wetter",
      "share of the part's cells seen wet, mean over years (%)", "|residual| (pp)")
a1.annotate("cap_residual_sd_water_quartile_1 to _4\n(dim_headline_number)", (0.98, 0.94),
            xycoords="axes fraction", ha="right", va="top", fontsize=7.6, color=MUTED)

a2.plot([0, 116], [0, 116], color=SPINE, lw=1.0, zorder=2)
for cm, g in LZ.groupby("community_short"):
    a2.scatter(g.rank_pooled, g.rank_local, s=26, c=PAL[cm], alpha=0.72, lw=0.5,
               edgecolor="#FFFFFF", zorder=3)
for j, nm in enumerate(("Mara 6", "Dinan 2")):
    r = LZ[(LZ.paddock_name == nm) & (LZ.community_short == "inland")]
    if len(r):
        r = r.iloc[0]
        a2.scatter([r.rank_pooled], [r.rank_local], s=70, facecolor="none", edgecolor=HEAD,
                   lw=1.4, zorder=5)
        a2.annotate(f"{nm} / inland: {int(r.rank_pooled)} to {int(r.rank_local)}",
                    (r.rank_pooled, r.rank_local), fontsize=7.6, color=HEAD,
                    xytext=(-12, (-16, 6)[j]), textcoords="offset points", ha="right")
a2.set_ylim(-6, 128)
style(a2, "Ranking a part against its own wetness moves the wet ones",
      "rank on the raw residual (1 = largest shortfall)", "rank on residual_z_local")

_q = QT[(QT.period == "whole_record") & (QT.scope == "all communities")]
_ratio = 100 * _q.residual_sd_sample.iloc[3] / _q.residual_sd_sample.iloc[0]
f.text(0.045, 0.962, "Heteroscedasticity, and what it does to a ranking",
       color=HEAD, fontsize=14.5, va="top")
f.text(0.045, 0.905,
       f"115 parts, whole record. The wettest quarter carries about {_ratio:.0f}% of the driest quarter's\n"
       "scatter, so a common colour scale overstates dry parts and understates wet ones.",
       color=BODY, fontsize=9.6, va="top", linespacing=1.5)
foot(f, "residual_z_local = residual divided by the SD of residuals in that part's water quartile. It is an ADDITIONAL column in DIAG1_local_z.csv;\n"
        "it replaces no published residual and the shipped GeoPackage and CSV are not edited. Pack v1.4's single-page maps print raw percentage\n"
        "points per part, which is what makes this worth knowing.")
save(f, "DIAG1_A3_heteroscedasticity.png")

# ================================================================ A4 - influence ==
dr = IN[(IN.row_type == "drop_one_cluster") & (IN.period == "whole_record")].sort_values("slope_without")
pt = IN[(IN.row_type == "part_leverage_and_deleted_residual") & (IN.period == "whole_record")]
f = plt.figure(figsize=(11.0, 5.6))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.068, right=0.978, top=0.745, bottom=0.195, wspace=0.215)
a1, a2 = f.add_subplot(1, 2, 1), f.add_subplot(1, 2, 2)

base = dr.slope_all.iloc[0]
cols = [HEAD if n == "Bala 29ca" else SPINE for n in dr.paddock_name]
a1.barh(range(len(dr)), dr.slope_without, color=cols, height=0.78, zorder=3)
a1.axvline(base, color=INK, lw=1.6, zorder=4)
a1.set_yticks([])
a1.set_xlim(0.44, 0.60)
for nm in ("Bala 29ca", "Bala 6"):
    i = list(dr.paddock_name).index(nm)
    a1.annotate(f"{nm}  {dr.slope_without.iloc[i]:.4f}", (dr.slope_without.iloc[i], i),
                fontsize=8, color=HEAD, va="bottom", ha="left",
                xytext=(6, 4), textcoords="offset points")
a1.annotate(f"all 64 paddocks in: {base:.4f}", (base, len(dr) * 0.5), fontsize=8, color=INK,
            rotation=90, ha="right", va="center", xytext=(-4, 0), textcoords="offset points")
style(a1, "Each bar is the slope with one paddock removed",
      "between-unit slope, pixel-weighted", None)

for cm, g in pt.groupby("community_short"):
    a2.scatter(g.residual_in_sample, g.residual_cluster_deleted, s=26, c=PAL[cm],
               alpha=0.72, lw=0.5, edgecolor="#FFFFFF", zorder=3)
lim = [-32, 22]
a2.plot(lim, lim, color=SPINE, lw=1.0, zorder=2)
b = pt[pt.paddock_name == "Bala 29ca"]
for _, r in b.iterrows():
    a2.scatter([r.residual_in_sample], [r.residual_cluster_deleted], s=74, facecolor="none",
               edgecolor=HEAD, lw=1.4, zorder=5)
    a2.annotate(f"Bala 29ca / {r.community_short}\n{r.residual_in_sample:+.2f} to {r.residual_cluster_deleted:+.2f}",
                (r.residual_in_sample, r.residual_cluster_deleted), fontsize=7.4, color=HEAD,
                xytext=(8, -2), textcoords="offset points")
a2.set_xlim(lim)
a2.set_ylim(lim)
style(a2, "In-sample residual against the residual with the part's own paddock removed",
      "in-sample residual (pp)", "residual with the whole paddock removed (pp)")

f.text(0.045, 0.962, "Influence, at the cluster that matters", color=HEAD, fontsize=14.5, va="top")
f.text(0.045, 0.905,
       "Bala 29ca is the most influential unit on the line against which Bala 29ca is then judged.\n"
       "Removing it moves the slope 0.5473 to 0.4692, about twice the next paddock.",
       color=BODY, fontsize=9.6, va="top", linespacing=1.5)
foot(f, "Below the diagonal on the right = the shortfall grows once the part's own paddock stops pulling the line. "
        "Bala 29ca's two shortfalls both grow, so the published figures are the CONSERVATIVE ones. Said here rather than left for a reader to find.")
save(f, "DIAG1_A4_influence.png")

# ============================================================== A5 - the form ==
fs = FC[(FC.row_type == "form_summary") & (FC.period == "whole_record")]
f = plt.figure(figsize=(11.0, 5.3))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.068, right=0.978, top=0.775, bottom=0.19, wspace=0.225)
a1, a2 = f.add_subplot(1, 2, 1), f.add_subplot(1, 2, 2)

pooled = fs[fs.scope == "pooled"].sort_values("cv_rmse_weighted_leave_one_paddock_out",
                                              ascending=False)   # best ends up on top
cv = pooled.cv_rmse_weighted_leave_one_paddock_out
a1.barh(range(len(pooled)), cv, color=[HEAD if f == "sqrt_x" else SPINE for f in pooled.form],
        height=0.66, zorder=3)
a1.set_yticks(range(len(pooled)))
a1.set_yticklabels(pooled.form, color=BODY, fontsize=9)
a1.set_xlim(cv.min() - 0.14, cv.max() + 0.09)
for i, v in enumerate(cv):
    a1.annotate(f"{v:.3f}", (v, i), fontsize=8, color=HEAD, va="center",
                xytext=(4, 0), textcoords="offset points")
style(a1, "Leave-one-paddock-out predictive error, not in-sample fit",
      "CV weighted RMSE (pp)", None)
_rsd = fs[(fs.scope == "pooled") & (fs.form == "linear")].resid_sd.iloc[0]
a1.annotate(f"the spread across all five forms is {cv.max() - cv.min():.2f} pp\n"
            f"on a residual SD of {_rsd:.2f} pp",
            (0.97, 0.87), xycoords="axes fraction", ha="right", va="top",
            fontsize=7.8, color=MUTED)

d = PW[PW.period == "whole_record"]
for cm in ("aeolian", "riverine", "inland"):
    g = d[d.community_short == cm]
    a2.scatter(g.x_inund_mean, g.y_floor_mean, s=area(d.n_pixels_part)[d.community_short == cm],
               c=PAL[cm], alpha=0.5, lw=0.5, edgecolor="#FFFFFF", zorder=3)
    r = fs[(fs.scope == cm) & (fs.form == "quadratic")].iloc[0]
    xx = np.linspace(r.x_min, r.x_max, 120)
    a2.plot(xx, r.term_1 + r.term_2 * xx + r.term_3 * xx ** 2, color=PAL[cm], lw=2.0, zorder=4)
rp = fs[(fs.scope == "pooled") & (fs.form == "linear")].iloc[0]
xx = np.linspace(rp.x_min, rp.x_max, 120)
a2.plot(xx, rp.term_1 + rp.term_2 * xx, color=INK, lw=1.7, ls=(0, (5, 3)), zorder=5)
a2.annotate("pooled linear", (xx[-1], rp.term_1 + rp.term_2 * xx[-1]), fontsize=8, color=INK,
            xytext=(-6, -16), textcoords="offset points", ha="right")
# The Aeolian quadratic leaves the top of the panel on 17 points. The axis is held to
# the DATA's range so the other two curves stay readable; the curve is clipped by the
# view, not dropped from the fit, and its exit is itself the point being made.
_pad = 0.06 * (d.y_floor_mean.max() - d.y_floor_mean.min())
a2.set_ylim(d.y_floor_mean.min() - _pad, d.y_floor_mean.max() + _pad)
a2.annotate("the Aeolian curve leaves the panel:\n17 points over a 19-point-wide span",
            (0.03, 0.05), xycoords="axes fraction", fontsize=7.6, color=PAL["aeolian"])
style(a2, "Each community's quadratic, over its own water range only",
      "share of the part's cells seen wet, mean over years (%)", "cover floor, veg_p05_spatial (%)")

f.text(0.045, 0.955, "Functional form: curvature that is mostly three communities at three levels",
       color=HEAD, fontsize=14.5, va="top")
f.text(0.045, 0.885,
       "Aeolian spans 1.0 to 19.7% wet, Riverine 3.0 to 33.3, Inland 5.9 to 58.9. "
       "Inland alone spans the range and is effectively straight across it.",
       color=BODY, fontsize=9.6, va="top")
foot(f, "Read as a reading to check, not a conclusion: pooled curvature and pooled steepness are consistent with three communities at different "
        "levels occupying different stretches of one axis. WHO is below expectation is robust to form (Spearman 0.984 linear against sqrt); "
        "BY HOW MUCH is sensitive to roughly 3 pp at the dry end. Both halves travel together or neither does.")
save(f, "DIAG1_A5_form.png")

# =========================================================== C1 - lag and series ==
f = plt.figure(figsize=(11.0, 5.6))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.068, right=0.978, top=0.745, bottom=0.195, wspace=0.215)
a1, a2 = f.add_subplot(1, 2, 1), f.add_subplot(1, 2, 2)

l2 = LG[LG.max_lag == 2]
scopes = ["pooled", "aeolian", "riverine", "inland"]
wd = 0.2
for i, sc in enumerate(scopes):
    r = l2[l2.scope == sc].iloc[0]
    vals = [r.lag0, r.lag1, r.lag2]
    c = INK if sc == "pooled" else PAL[sc]
    a1.bar(np.arange(3) + (i - 1.5) * wd, vals, width=wd, color=c, zorder=3,
           label="pooled" if sc == "pooled" else sc.capitalize())
a1.axhline(0, color=MUTED, lw=1.0, zorder=4)
a1.set_xticks(range(3))
a1.set_xticklabels(["same year", "one year back", "two years back"], color=BODY, fontsize=9)
a1.legend(frameon=False, fontsize=8, labelcolor=BODY, ncol=2)
style(a1, "The within response to water, by how far back the water was",
      None, "within-unit slope (pp of floor per pp of wet cells)")

a2.scatter(SER.floor_skew_g1, SER.floor_mean_minus_median,
           s=area(SER.n_pixels_part, 10, 120),
           c=[PAL[c] for c in SER.community_short], alpha=0.66, lw=0.5,
           edgecolor="#FFFFFF", zorder=3)
a2.axhline(0, color=MUTED, lw=1.0, zorder=2)
a2.axvline(0, color=MUTED, lw=1.0, zorder=2)
for j, (_, r) in enumerate(SER.nsmallest(3, "floor_mean_minus_median").iterrows()):
    a2.annotate(f"{r.zone_name} / {r.community_short}", (r.floor_skew_g1, r.floor_mean_minus_median),
                fontsize=7.3, color=HEAD, ha="left",
                xytext=(8, (6, -11, 8)[j]), textcoords="offset points")
style(a2, "Where a part's mean floor sits below its own median",
      "skew of the part's 35 annual floor values", "mean minus median (pp)")

_lr = LG[(LG.max_lag == 1) & (LG.scope == "pooled")].long_run_sum.iloc[0]
_lsk = int((SER.floor_skew_g1 < 0).sum())
f.text(0.045, 0.962, "The annual series: how long the response lasts, and whether the mean is fair",
       color=HEAD, fontsize=14.5, va="top")
f.text(0.045, 0.905,
       f"4,025 part-years, within-unit, pixel-weighted. Long-run sum of same-year and one-year-back is {_lr:+.4f}.\n"
       f"{_lsk} of {len(SER)} parts are left-skewed: dry years pull the mean below the median.",
       color=BODY, fontsize=9.6, va="top", linespacing=1.5)
foot(f, "WITHIN-UNIT estimand throughout: how one part's floor moves when that same part's own wetness moves. Never a version of the "
        "between-unit slope. No management claim and no period comparison is made on this page.")
save(f, "DIAG1_C1_lag_and_series.png")


# ================================================== E1 / E2 - within residuals ==
def within_panels(tag, name, title, sub):
    d = WP[WP.set == tag]
    w = WD[WD.set == tag]
    f = plt.figure(figsize=(11.0, 8.3))
    f.patch.set_facecolor(BG)
    f.subplots_adjust(left=0.075, right=0.975, top=0.835, bottom=0.115,
                      wspace=0.245, hspace=0.365)
    ax = [f.add_subplot(2, 2, i) for i in (1, 2, 3, 4)]

    hb = ax[0].hexbin(d.fitted, d.residual, gridsize=44, mincnt=1, cmap="BuPu",
                      linewidths=0, zorder=3)
    ax[0].axhline(0, color=MUTED, lw=1.0, zorder=4)
    cb = f.colorbar(hb, ax=ax[0], pad=0.015)
    cb.outline.set_visible(False)
    cb.ax.tick_params(colors=MUTED, labelsize=7.5, length=2)
    cb.set_label("unit-years per cell", color=BODY, fontsize=8)
    style(ax[0], "Residual against fitted", "fitted (demeaned floor, pp)", "residual (pp)")

    hb2 = ax[1].hexbin(d.x_demeaned, d.residual, gridsize=44, mincnt=1, cmap="BuPu",
                       linewidths=0, zorder=3)
    ax[1].axhline(0, color=MUTED, lw=1.0, zorder=4)
    q = w[w.row_type == "heteroscedasticity_by_demeaned_water"]
    br = []
    for _, r in q.iterrows():
        lo, hi = [float(v) for v in r.detail.replace("demeaned water ", "").replace(" pp", "").split(" to ")]
        br.append((lo, hi, r.value))
        ax[1].plot([lo, hi], [r.value] * 2, color=INK, lw=2.2, zorder=5)
        ax[1].plot([lo, hi], [-r.value] * 2, color=INK, lw=2.2, zorder=5)
    cb2 = f.colorbar(hb2, ax=ax[1], pad=0.015)
    cb2.outline.set_visible(False)
    cb2.ax.tick_params(colors=MUTED, labelsize=7.5, length=2)
    cb2.set_label("unit-years per cell", color=BODY, fontsize=8)
    style(ax[1], "Residual against demeaned water, with quartile SDs",
          "water in this year minus the unit's own mean (pp)", "residual (pp)")

    fm = w[w.row_type == "form_summary"].sort_values("value", ascending=False)
    _best = fm.value.idxmin()   # highlight whichever form actually wins, never a named one
    ax[2].barh(range(len(fm)), fm.value,
               color=[HEAD if i == _best else SPINE for i in fm.index], height=0.66, zorder=3)
    ax[2].set_yticks(range(len(fm)))
    ax[2].set_yticklabels(fm.form, color=BODY, fontsize=9)
    ax[2].set_xlim(min(fm.value) * 0.988, max(fm.value) * 1.012)
    for i, v in enumerate(fm.value):
        ax[2].annotate(f"{v:.3f}", (v, i), fontsize=8, color=HEAD, va="center",
                       xytext=(4, 0), textcoords="offset points")
    style(ax[2], "Leave-one-cluster-out CV error: the response saturates",
          "CV weighted RMSE (pp)", None)

    cw = w[w.row_type == "within_by_community"]
    ax[3].bar(range(len(cw)), cw.value, color=[PAL[c] for c in cw.scope], width=0.6, zorder=3)
    ax[3].axhline(cw.reference.iloc[0], color=INK, lw=1.5, zorder=4)
    ax[3].annotate(f"pooled {cw.reference.iloc[0]:.4f}", (len(cw) - 0.5, cw.reference.iloc[0]),
                   fontsize=8, color=INK, ha="right", va="bottom",
                   xytext=(0, 3), textcoords="offset points")
    ax[3].set_xticks(range(len(cw)))
    ax[3].set_xticklabels([c.capitalize() for c in cw.scope], color=BODY, fontsize=9)
    ax[3].set_ylim(0, max(cw.value) * 1.14)   # headroom for the value labels
    for i, v in enumerate(cw.value):
        ax[3].annotate(f"{v:+.4f}", (i, v), fontsize=8, color=HEAD, ha="center",
                       xytext=(0, 3), textcoords="offset points")
    style(ax[3], "Within slope by community", None, "within-unit slope")

    f.text(0.045, 0.962, title, color=HEAD, fontsize=14.5, va="top")
    f.text(0.045, 0.921, sub, color=BODY, fontsize=9.6, va="top", linespacing=1.5)
    foot(f, "WITHIN-UNIT estimand: how one unit's floor moves when that same unit's own wetness moves. It is not a version of the between-unit "
            "slope and the two are never presented as two estimates of one number. Points are hexbinned, never drawn raw (display convention H5).")
    save(f, name)


within_panels(SET_PART, "DIAG1_E1_within_parts.png",
              "The within-unit fit, diagnosed for the first time: 115 parts",
              "4,025 part-years, pixel-weighted, clustered on the paddock. These fits are the\n"
              "project's central result and until now had no diagnostics at all.")
within_panels(SET_PATCH, "DIAG1_E2_within_patches.png",
              "The same diagnostics on the unzoned patches: 93 patches",
              "3,253 patch-years, pixel-weighted, clustered on the PATCH - these units are not nested in\n"
              "management zones and no paddock cluster is substituted for the one that does not exist.")

# ============================== E3 - saturation, influence contrast, interval width ==
f = plt.figure(figsize=(11.6, 5.3))
f.patch.set_facecolor(BG)
f.subplots_adjust(left=0.058, right=0.988, top=0.745, bottom=0.225, wspace=0.40)
a1, a2, a3 = (f.add_subplot(1, 3, i) for i in (1, 2, 3))

for tag, col, lab in ((SET_PART, INK, "115 parts"), (SET_PATCH, "#8E5572", "93 unzoned patches")):
    d = WP[WP.set == tag]
    w = WD[(WD.set == tag) & (WD.row_type == "form_summary")]
    xx = np.linspace(max(d.x_raw.min(), 0.01), d.x_raw.max(), 160)
    for form, ls in (("linear", (0, (5, 3))), ("log_x1", "-")):
        r = w[w.form == form].iloc[0]
        b = float(r.detail.split("terms ")[1].split()[0])
        yy = b * xx if form == "linear" else b * np.log(xx + 1)
        yy = yy - yy.mean()
        a1.plot(xx, yy, color=col, lw=2.1 if form == "log_x1" else 1.4, ls=ls, zorder=3,
                label=f"{lab}, {'log(x+1)' if form=='log_x1' else 'linear'}")
style(a1, "The within response saturates",
      "share of the unit's cells seen wet (%)", "floor response, centred (pp)")
a1.legend(frameon=False, fontsize=7.6, labelcolor=BODY, loc="upper left")

dr = IN[(IN.row_type == "drop_one_cluster") & (IN.period == "whole_record")]
wi = WD[(WD.set == SET_PART) & (WD.row_type == "drop_one_cluster")]
for i, (vals, base, lab, col) in enumerate((
        (dr.slope_delta.values, dr.slope_all.iloc[0], "between-unit\n(64 paddocks)", INK),
        (wi.delta.values, wi.reference.iloc[0], "within-unit\n(64 paddocks)", "#8E5572"))):
    rel = 100 * vals / base
    a2.scatter(np.full(len(rel), i) + np.random.default_rng(7).normal(0, 0.055, len(rel)),
               rel, s=20, c=col, alpha=0.55, lw=0, zorder=3)
    a2.plot([i - 0.25, i + 0.25], [rel.min()] * 2, color=col, lw=1.6, zorder=4)
    a2.plot([i - 0.25, i + 0.25], [rel.max()] * 2, color=col, lw=1.6, zorder=4)
a2.axhline(0, color=MUTED, lw=1.0, zorder=2)
a2.set_xticks([0, 1])
a2.set_xticklabels(["between-unit", "within-unit"], color=BODY, fontsize=9)
a2.set_xlim(-0.5, 1.5)
b29 = dr[dr.paddock_name == "Bala 29ca"]
B29_PCT = 100 * b29.slope_delta.iloc[0] / b29.slope_all.iloc[0]
wi29 = wi[wi.scope.astype(str) == str(b29.cluster_value.iloc[0])]
B29_WITHIN_PCT = 100 * wi29.delta.iloc[0] / wi29.reference.iloc[0]
a2.set_ylim(B29_PCT * 1.34, None)
a2.annotate(f"Bala 29ca  {B29_PCT:+.1f}%", (0.0, B29_PCT), fontsize=7.8, color=HEAD,
            ha="center", va="top", xytext=(0, -7), textcoords="offset points")
a2.annotate(f"Bala 29ca  {B29_WITHIN_PCT:+.1f}%", (1.0, B29_WITHIN_PCT), fontsize=7.8,
            color=HEAD, ha="center", va="top", xytext=(0, -22), textcoords="offset points")
style(a2, "Dropping any one paddock, as a share of the slope",
      None, "change in the slope (%)")

bs = WD[WD.row_type == "bootstrap_scheme"]
SCHEME = {"iid_part_years": "rows, independently", "part_id": "whole parts",
          "zone_fid": "whole paddocks", "patch_id": "whole patches"}
labs, vals, cols = [], [], []
for tag, col in ((SET_PART, INK), (SET_PATCH, "#8E5572")):
    for _, r in bs[bs.set == tag].iterrows():
        labs.append(SCHEME[r.scope])
        vals.append(r.value)
        cols.append(col)
a3.barh(range(len(vals)), vals, color=cols, height=0.66, zorder=3)
a3.set_yticks(range(len(vals)))
a3.set_yticklabels(labs, color=BODY, fontsize=8)
for i, v in enumerate(vals):
    a3.annotate(f"{v:.4f}", (v, i), fontsize=7.8, color=HEAD, va="center",
                xytext=(4, 0), textcoords="offset points")
a3.set_xlim(0, max(vals) * 1.22)
style(a3, "Interval width, by what gets resampled", "width of the 95% interval", None)
a3.legend(handles=[plt.Line2D([], [], marker="s", ls="", color=c, label=l, markersize=7)
                   for c, l in ((INK, "115 parts"), ("#8E5572", "93 unzoned patches"))],
          frameon=False, fontsize=7.6, labelcolor=BODY, loc="lower right")

_iid = bs[(bs.set == SET_PART) & (bs.scope == "iid_part_years")].value.iloc[0]
_blk = bs[(bs.set == SET_PART) & (bs.scope == "zone_fid")].value.iloc[0]
f.text(0.045, 0.962, "What the within diagnostics found", color=HEAD, fontsize=14.5, va="top")
f.text(0.045, 0.905,
       "Left: the question the between-unit fit could not answer. Middle: the paddock that dominates the\n"
       "between fit barely touches the within one. Right: the block bootstrap is not ignoring serial correlation.",
       color=BODY, fontsize=9.4, va="top", linespacing=1.5)
foot(f, "Right-hand panel: resampling rows independently DESTROYS the panel structure, so its width is what an interval that ignores serial "
        f"dependence looks like. The published paddock-clustered interval is {100 * (_blk / _iid - 1):.0f}% wider than that, because resampling whole "
        "paddocks keeps each unit's 35-year series intact. Intervals are R-side stability checks, conditional on the inputs being correct "
        "(Ruling AW), and are not registered.", y=0.028)
save(f, "DIAG1_E3_within_findings.png")

print("  done")
sys.exit(0)
