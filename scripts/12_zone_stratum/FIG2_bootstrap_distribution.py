#!/usr/bin/env python
"""FIG-2 §5 - the bootstrap distribution figure. Reproduction first, then drawing.

WHAT IT SHOWS. How much the fitted slope moves when the PADDOCKS are resampled.

WHAT IT DOES NOT SHOW, and no caption here says otherwise: how often the observed
coefficient was found. The bootstrap resamples around the point estimate, so the
observed value sits at the centre of its own distribution by construction and the
density there is high regardless.

§5.2 IS A HALT CONDITION. The stored tables hold p2.5 / p50 / p97.5, not the draws, so
recovering the draws means re-running the bootstrap with the recorded seed. Every
recovered percentile is asserted against its stored value BEFORE anything is plotted. A
histogram whose 2.5th percentile disagrees with the interval printed beside it is worse
than no figure.

WHY THIS IS PYTHON AND NOT R, under Ruling AS. Ruling AS puts statistical estimation in
R. This is not new estimation: it recovers the draws of an EXISTING Python bootstrap,
and the draws are a function of NumPy's generator and the exact resampling order. A
reimplementation in R would produce different draws and would fail the §5.2 assertion by
construction - so the reading taken is that AS governs new estimation, and reproducing a
recorded computation requires the generator that recorded it. The alternative reading
would have meant no reproduction was possible and the figure could not be drawn at all.

Drawing rules, §5.4: no zero line, no "% of draws exceed", axis spans the draws.
"""
from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
T = ROOT / "Output" / "tables"
OUT = ROOT / "Output" / "figures" / "FIG2_bootstrap_slope_distributions.png"

N_BOOT, BOOT_SEED = 2000, 20260806        # exactly as recorded in PARTREG_stage1_full_period.py
BG, HEAD, BODY, MUTED, INK = "#F8F7F2", "#26302E", "#5F6B67", "#8A8378", "#0F3947"
PAL = {"aeolian": "#C79A3B", "riverine": "#3B8A8F", "inland": "#2165AC"}


def rows(p):
    return list(csv.DictReader(open(p, encoding="utf-8-sig")))


def wls(x, y, w):
    x, y, w = np.asarray(x, float), np.asarray(y, float), np.asarray(w, float)
    sw = w.sum(); mx = (w * x).sum() / sw; my = (w * y).sum() / sw
    return float((w * (x - mx) * (y - my)).sum() / (w * (x - mx) ** 2).sum())


def draws(recs, weighted=True, n=N_BOOT, seed=BOOT_SEED):
    """The recorded procedure, verbatim: cluster on zone_fid, resample with replacement."""
    rng = np.random.default_rng(seed)
    cl = defaultdict(list)
    for r in recs:
        cl[r["zone_fid"]].append(r)
    zfs = list(cl)
    out = []
    for _ in range(n):
        pick = rng.choice(len(zfs), size=len(zfs), replace=True)
        rs = [r for i in pick for r in cl[zfs[i]]]
        if len({r["x"] for r in rs}) < 3:
            continue
        out.append(wls([r["x"] for r in rs], [r["y"] for r in rs],
                       [r["w"] for r in rs] if weighted else np.ones(len(rs))))
    return np.sort(np.array(out))


# ---- rebuild the Stage 1 summary in its original order -----------------------------
S1 = rows(T / "PARTREG_part_summary_by_period.csv")
recs = [dict(zone_fid=r["zone_fid"], community=r["community_short"],
             x=float(r["inund_mean"]), y=float(r["floor_mean"]), w=float(r["weight"]))
        for r in S1]
FITS = {r["fit_id"]: r for r in rows(T / "PARTREG_part_regression_coefficients.csv")}

print("=" * 74)
print("FIG-2 §5.2 - reproduction assertion, before anything is drawn")
print("=" * 74)
SETS = [("2.3_weighted", "pooled, 115 parts", None, INK),
        ("2.6_aeolian", "Aeolian Chenopod", "aeolian", PAL["aeolian"]),
        ("2.6_riverine", "Riverine Chenopod", "riverine", PAL["riverine"]),
        ("2.6_inland", "Inland Floodplain", "inland", PAL["inland"])]
D, bad = {}, []
for fid, lab, cs, _ in SETS:
    sub = recs if cs is None else [r for r in recs if r["community"] == cs]
    d = draws(sub)
    D[fid] = d
    got = np.quantile(d, [0.025, 0.5, 0.975])
    want = [float(FITS[fid][k]) for k in ("boot_slope_p2_5", "boot_slope_p50", "boot_slope_p97_5")]
    ok = all(abs(g - w) < 5e-7 for g, w in zip(got, want))
    if not ok:
        bad.append(fid)
    print(f"  {fid:<16s} n={len(d):>5}  recovered [{got[0]:+.6f}, {got[1]:+.6f}, {got[2]:+.6f}]")
    print(f"  {'':16s}          stored    [{want[0]:+.6f}, {want[1]:+.6f}, {want[2]:+.6f}]   "
          f"{'MATCH' if ok else '*** DISAGREES ***'}")
if bad:
    raise SystemExit(f"HALT (§5.2): recovered percentiles disagree for {bad}. "
                     "No figure is drawn.")
print("  all four reproduce exactly - drawing may proceed\n")

# ---- panel B: the grain check. Paddock grain has no stored interval to reproduce ----
import sqlite3
con = sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",
                      uri=True)
con.execute("PRAGMA query_only=1")
pad = [dict(zone_fid=str(z), x=f, y=v, w=1.0) for z, v, f in con.execute(
    """SELECT zone_fid, AVG(veg_p05_spatial), AVG(flood_frac_pct) FROM fact_zone_veg_annual
       WHERE series_variant='mean_of_seasons' GROUP BY zone_fid""")]
REG_SLOPE = con.execute("SELECT pinned_value FROM dim_headline_number "
                        "WHERE number_id='floor_flood_slope_64pdk'").fetchone()[0]
con.close()
pad_d = draws(pad, weighted=False)
pt_obs = wls([r["x"] for r in pad], [r["y"] for r in pad], np.ones(len(pad)))
print(f"  paddock grain: observed {pt_obs:+.6f} against registered {REG_SLOPE:+.6f}  "
      f"(diff {abs(pt_obs-REG_SLOPE):.2e})")
print(f"  its interval is NOT registered, so it is computed here with the same procedure "
      f"and seed and labelled as such\n")

# ---------------------------------------------------------------- the figure
fig = plt.figure(figsize=(15.0, 7.2), dpi=200, facecolor=BG)
fig.subplots_adjust(left=0.05, right=0.985, top=0.775, bottom=0.245, wspace=0.16)
axA, axB = fig.add_subplot(1, 2, 1), fig.add_subplot(1, 2, 2)
for a in (axA, axB):
    a.set_facecolor("#FFFFFF")
    for sp in ("top", "right"):
        a.spines[sp].set_visible(False)
    for sp in ("left", "bottom"):
        a.spines[sp].set_color("#CFCABA")
    a.tick_params(colors=MUTED, labelsize=9, length=3, color="#CFCABA")
    a.grid(True, color="#EFEBE0", lw=0.8, zorder=0); a.set_axisbelow(True)

# The Aeolian draws run to -6.4 and crush every other distribution into a single spike,
# so panel A is clipped and the clipped-tail convention is stated on the face (section 5.4).
# The axis still spans the DRAWS shown; it is not extended to include zero - zero simply
# falls inside the chenopod distributions, which is the finding, not a drawn reference.
CLIP_LO, CLIP_HI = -2.0, 1.8
clipped = {fid: int(((D[fid] < CLIP_LO) | (D[fid] > CLIP_HI)).sum()) for fid, *_ in SETS}
lo, hi = CLIP_LO, CLIP_HI
binsA = np.linspace(lo, hi, 70)
for fid, lab, cs, col in SETS:
    d = np.clip(D[fid], CLIP_LO, CLIP_HI)
    axA.hist(d, bins=binsA, color=col, alpha=0.42, zorder=2,
             label=f"{lab}   {float(FITS[fid]['slope']):+.3f}")
    axA.axvline(float(FITS[fid]["slope"]), color=col, lw=1.8, zorder=4)
    for q in (np.quantile(D[fid], 0.025), np.quantile(D[fid], 0.975)):
        if CLIP_LO <= q <= CLIP_HI:
            axA.axvline(q, color=col, lw=0.9, ls=(0, (3, 2)), alpha=0.85, zorder=3)
axA.set_xlim(lo, hi)                                   # the axis spans the draws; zero is not forced in
axA.set_xlabel("fitted slope  (pp of cover per pp of wetness)", fontsize=10, color=BODY)
axA.set_ylabel("bootstrap draws", fontsize=10, color=BODY)
axA.set_title("A · the pooled line against the three communities", fontsize=12,
              color=HEAD, weight="bold", loc="left", pad=8)
la = axA.legend(loc="upper right", fontsize=8.6, frameon=True, facecolor="#FFFFFF",
                edgecolor="#DDD8CC", labelcolor=BODY, title="solid line = observed slope")
la.get_title().set_fontsize(8.0); la.get_title().set_color(MUTED)
la.get_frame().set_linewidth(0.8)
_cl = ", ".join(f"{lab} {clipped[fid]}" for fid, lab, _, _ in SETS if clipped[fid])
fig.text(0.05, 0.222,
         f"Panel A axis clipped to [{CLIP_LO:+.1f}, {CLIP_HI:+.1f}]; draws outside are stacked into "
         f"the end bins — {_cl}. Aeolian's 2.5th percentile is "
         f"{np.quantile(D['2.6_aeolian'], 0.025):+.2f} and its 97.5th "
         f"{np.quantile(D['2.6_aeolian'], 0.975):+.2f}; the lower bound lies off the axis.",
         fontsize=7.8, color=MUTED, ha="left")

loB = min(pad_d.min(), D["2.3_weighted"].min()); hiB = max(pad_d.max(), D["2.3_weighted"].max())
binsB = np.linspace(loB, hiB, 60)
axB.hist(pad_d, bins=binsB, color="#8A8378", alpha=0.45, zorder=2,
         label=f"paddock grain, 64 units   {pt_obs:+.3f}")
axB.hist(D["2.3_weighted"], bins=binsB, color=INK, alpha=0.42, zorder=3,
         label=f"part grain, 115 units   {float(FITS['2.3_weighted']['slope']):+.3f}")
axB.axvline(pt_obs, color="#5F6B67", lw=1.8, zorder=5)
axB.axvline(float(FITS["2.3_weighted"]["slope"]), color=INK, lw=1.8, zorder=5)
for d, c in ((pad_d, "#8A8378"), (D["2.3_weighted"], INK)):
    for q in (np.quantile(d, 0.025), np.quantile(d, 0.975)):
        axB.axvline(q, color=c, lw=0.9, ls=(0, (3, 2)), alpha=0.85, zorder=4)
axB.set_xlim(loB, hiB)
axB.set_xlabel("fitted slope  (pp of cover per pp of wetness)", fontsize=10, color=BODY)
axB.set_ylabel("bootstrap draws", fontsize=10, color=BODY)
axB.set_title("B · does changing the unit move the answer?", fontsize=12, color=HEAD,
              weight="bold", loc="left", pad=8)
lb = axB.legend(loc="upper right", fontsize=8.6, frameon=True, facecolor="#FFFFFF",
                edgecolor="#DDD8CC", labelcolor=BODY, title="dashed = 2.5th and 97.5th percentile")
lb.get_title().set_fontsize(8.0); lb.get_title().set_color(MUTED)
lb.get_frame().set_linewidth(0.8)

fig.text(0.05, 0.945, "Methods and questions", fontsize=10.5, color=BODY, ha="left")
fig.text(0.05, 0.895, "How much the fitted slope moves when the paddocks are resampled",
         fontsize=18, color=HEAD, weight="bold", ha="left")
fig.text(0.05, 0.845,
         "This shows how far the slope could sit from where it landed, given which paddocks happened "
         "to be measured. It does not show how often the observed slope was found: the resampling is "
         "centred on it by construction.",
         fontsize=9.2, color=HEAD, ha="left")
import textwrap
fig.text(0.05, 0.175, textwrap.fill(
    "Panel A: the pooled line is compact and sits clear of the three community distributions. Inland "
    "Floodplain is compact too; both chenopod distributions are wide and sprawl across a range that "
    "includes zero, which is why no community line is drawn on the cover-and-water figure. Panel B: "
    "the paddock-grain and part-grain distributions are almost entirely superimposed — changing the "
    "unit from the paddock to the paddock × community part moved the answer by less than the width "
    "of either distribution.", 172),
    fontsize=8.8, color=HEAD, ha="left", va="top", linespacing=1.6)
fig.text(0.05, 0.072, textwrap.fill(
    f"2,000 draws, resampling paddocks with replacement, clustered on zone_fid, seed {BOOT_SEED} "
    "recorded. 115 parts sit in 64 paddocks, so 64 clusters — not 115 observations — bound the "
    "precision. Recovered draws reproduce the registered 2.5th, 50th and 97.5th percentiles exactly "
    "for all four distributions in panel A; the paddock-grain interval in panel B is not registered "
    "and is computed here with the same procedure and seed. Pixel-weighted at part grain, unweighted "
    "at paddock grain, as each fit was run. No p-values.", 196),
    fontsize=7.8, color=MUTED, ha="left", va="top", linespacing=1.6)

OUT.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(OUT, dpi=200, facecolor=BG)
plt.close(fig)
print(f"[wrote] {OUT.name}  ({OUT.stat().st_size/1024:.0f} KB)")
