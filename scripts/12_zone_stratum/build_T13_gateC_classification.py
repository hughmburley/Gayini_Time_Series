#!/usr/bin/env python
"""T13 Gate C — the PRE-REGISTERED classification, the sweep, and the robustness run.
COMPUTE + REPORT ONLY. No DB write (the classification table is Gate E), no builder run,
no existing object modified, no p-values.

Rule (spec v1 §5), implemented EXACTLY as written, no threshold moved:
    level_z <= -c  and  trend_z >= +c   -> Recovering
    level_z <= -c  and  trend_z <  +c   -> Persistently poor
    level_z >  -c  and  trend_z <= -c   -> Declining
    level_z >  -c  otherwise            -> Unremarkable
Registered cut c = 1.0. Sweep c in {0.50, 0.75, 1.00, 1.25, 1.50}.

RULING 4 (additive, raised before any classification was computed): the Persistently poor
cell is ALSO reported split by trend_z <= -c ("low and falling") vs -c < trend_z < +c
("low and flat"). A labelling refinement, not a revision — membership of the low group and
every threshold are unchanged.

RULING 3: "two wettest water years" = PROPERTY scope — the two water years with the highest
sum(wet_pixels)/sum(valid_pixels) across all parts in fact_zone_community_flood_annual.
One fixed pair, dropped for every part.

RULING 2: raw-versus-water-adjusted divergence panel for Bala 29ca Inland.
"""
import sqlite3, csv, math
import numpy as np, statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "tables"
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
CUTS = [0.50, 0.75, 1.00, 1.25, 1.50]
REGISTERED_CUT = 1.00
STATES = ["Recovering", "Persistently poor", "Declining", "Unremarkable"]

con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
c = con.cursor()
name = {z: n for z, n in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}


def ols(x, y):
    """Slope, SE, r, residuals, intercept. Same convention as Gate B."""
    x = np.asarray(x, float); y = np.asarray(y, float); n = len(x)
    mx = x.mean(); my = y.mean()
    sxx = ((x - mx) ** 2).sum(); sxy = ((x - mx) * (y - my)).sum(); syy = ((y - my) ** 2).sum()
    slope = sxy / sxx; inter = my - slope * mx
    r = sxy / math.sqrt(sxx * syy) if sxx * syy > 0 else float("nan")
    resid = y - (inter + slope * x); sse = (resid ** 2).sum()
    se = math.sqrt((sse / (n - 2)) / sxx) if n > 2 and sxx > 0 else float("nan")
    return slope, se, r, resid, inter


# ---------------------------------------------------------------- source series
VEG = {}
for zf, cm, wy, p05 in c.execute(
        "SELECT zone_fid,community,water_year,veg_p05_spatial FROM fact_zone_community_veg_annual "
        "WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL"):
    VEG.setdefault((zf, cm), {})[wy] = p05
FL, FLW = {}, {}
for zf, cm, wy, ff, wp, vp in c.execute(
        "SELECT zone_fid,community,water_year,flood_frac_pct,wet_pixels,valid_pixels "
        "FROM fact_zone_community_flood_annual WHERE flood_frac_pct IS NOT NULL"):
    FL.setdefault((zf, cm), {})[wy] = ff
    FLW.setdefault(wy, [0, 0])
    FLW[wy][0] += wp; FLW[wy][1] += vp


def compute(exclude_years=frozenset()):
    """Full Gate B chain -> measures + z. exclude_years drops those water years everywhere."""
    parts = sorted(k for k, v in VEG.items() if len({y for y in v if y not in exclude_years}) >= 25)
    rows = {}
    for k in parts:
        yrs = sorted(y for y in VEG[k] if y in FL.get(k, {}) and y not in exclude_years)
        veg = [VEG[k][y] for y in yrs]; fld = [FL[k][y] for y in yrs]
        tr_raw, tr_raw_se, _, _, _ = ols(yrs, veg)
        ws, ws_se, wr, wres, _ = ols(fld, veg)
        ta, ta_se, _, _, _ = ols(yrs, list(wres))
        fl_tr, _, _, _, _ = ols(yrs, fld)            # the part's OWN flood trend
        rows[k] = dict(zf=k[0], cm=k[1], n=len(yrs), level=st.mean(veg), tr_raw=tr_raw,
                       tr_raw_se=tr_raw_se, ws=ws, ws_se=ws_se, wr=wr, ta=ta, ta_se=ta_se,
                       flood_trend=fl_tr, flood_mean=st.mean(fld),
                       flood_sd=st.pstdev(fld) if len(fld) > 1 else 0.0)
    for cm in sorted({k[1] for k in parts}):
        ks = [k for k in parts if k[1] == cm]
        med_l = st.median([rows[k]["level"] for k in ks])
        med_t = st.median([rows[k]["ta"] for k in ks])
        med_r = st.median([rows[k]["tr_raw"] for k in ks])
        med_f = st.median([rows[k]["flood_trend"] for k in ks])
        med_fm = st.median([rows[k]["flood_mean"] for k in ks])
        sd_l = st.stdev([rows[k]["level"] - med_l for k in ks])
        sd_t = st.stdev([rows[k]["ta"] - med_t for k in ks])
        for k in ks:
            r = rows[k]
            r["level_dev"] = r["level"] - med_l; r["trend_dev"] = r["ta"] - med_t
            r["level_z"] = r["level_dev"] / sd_l; r["trend_z"] = r["trend_dev"] / sd_t
            r["tr_raw_dev"] = r["tr_raw"] - med_r          # RULING 2: raw-scale deviation
            r["comm_med_tr_raw"] = med_r; r["comm_med_ta"] = med_t
            r["comm_med_flood_trend"] = med_f; r["comm_med_flood_mean"] = med_fm
            r["sd_level_dev"] = sd_l; r["sd_trend_dev"] = sd_t
    return parts, rows


def classify(r, cut):
    """Spec v1 §5, exactly as written."""
    if r["level_z"] <= -cut:
        return "Recovering" if r["trend_z"] >= cut else "Persistently poor"
    return "Declining" if r["trend_z"] <= -cut else "Unremarkable"


def pp_split(r, cut):
    """RULING 4 sub-division of Persistently poor. Additive; changes no membership."""
    return "low and falling" if r["trend_z"] <= -cut else "low and flat"


parts, M = compute()
print(f"parts: {len(parts)}")

# ---------------------------------------------------------------- SELF-CHECK (must be able to fail)
# The robustness path recomputes the whole chain. Prove it reproduces the frozen Gate B CSV
# at zero exclusions, else the robustness comparison is meaningless.
gb = {(int(r["zone_fid"]), r["community"]): r
      for r in csv.DictReader(open(OUT / "T13_gateB_part_measures.csv", encoding="utf-8"))}
worst = {}
for k in parts:
    for col, key in (("level_z", "level_z"), ("trend_z", "trend_z"), ("level", "level"),
                     ("trend_raw", "tr_raw"), ("water_slope", "ws"), ("trend_adj", "ta")):
        d = abs(float(gb[k][col]) - M[k][key])
        worst[col] = max(worst.get(col, 0.0), d)
print("SELF-CHECK vs frozen Gate B CSV, max |diff|:",
      "  ".join(f"{k}={v:.2e}" for k, v in worst.items()))
assert len(gb) == len(parts), f"part count differs: CSV {len(gb)} vs recompute {len(parts)}"
assert max(worst.values()) < 5e-4, f"recompute does not reproduce Gate B: {worst}"
print("  -> reproduces Gate B within CSV rounding (4 dp). Robustness path is the same method.")

# ---------------------------------------------------------------- 1. registered classification
for k in parts:
    M[k]["state"] = classify(M[k], REGISTERED_CUT)
    M[k]["pp_split"] = pp_split(M[k], REGISTERED_CUT) if M[k]["state"] == "Persistently poor" else ""
reg_counts = {s: sum(1 for k in parts if M[k]["state"] == s) for s in STATES}
print(f"\n=== REGISTERED CLASSIFICATION, pre-registered cut +/-{REGISTERED_CUT:.2f} ===")
for s in STATES:
    print(f"   {s:20} {reg_counts[s]:4d}")
pp = [k for k in parts if M[k]["state"] == "Persistently poor"]
print(f"   -- RULING 4 split of Persistently poor ({len(pp)}) --")
for lab in ("low and flat", "low and falling"):
    print(f"      {lab:18} {sum(1 for k in pp if M[k]['pp_split'] == lab):4d}")

# ---------------------------------------------------------------- 2. sweep
sweep, recov_sets = [], {}
for cut in CUTS:
    st_at = {k: classify(M[k], cut) for k in parts}
    cnt = {s: sum(1 for k in parts if st_at[k] == s) for s in STATES}
    ppk = [k for k in parts if st_at[k] == "Persistently poor"]
    cnt["pp_low_and_flat"] = sum(1 for k in ppk if pp_split(M[k], cut) == "low and flat")
    cnt["pp_low_and_falling"] = sum(1 for k in ppk if pp_split(M[k], cut) == "low and falling")
    cnt["cut"] = cut
    sweep.append(cnt)
    recov_sets[cut] = {k for k in parts if st_at[k] == "Recovering"}
print(f"\n=== SWEEP ===\n{'cut':>5} {'Recov':>6} {'PersPoor':>9} {'(flat':>6} {'fall)':>6} {'Declin':>7} {'Unrem':>7}")
for r in sweep:
    print(f"{r['cut']:5.2f} {r['Recovering']:6d} {r['Persistently poor']:9d} "
          f"{r['pp_low_and_flat']:6d} {r['pp_low_and_falling']:6d} {r['Declining']:7d} {r['Unremarkable']:7d}")

reg_rec = recov_sets[REGISTERED_CUT]
print("\n--- recovering-set COMPOSITION across the sweep (is the set nested / stable?) ---")
for cut in CUTS:
    s = recov_sets[cut]
    kept = len(s & reg_rec)
    print(f"   cut {cut:4.2f}: n={len(s):2d}  shares {kept:2d} with the registered set  "
          f"added={sorted(name[k[0]]+' '+k[1][:8] for k in s-reg_rec)}  "
          f"dropped={sorted(name[k[0]]+' '+k[1][:8] for k in reg_rec-s)}")
allc = set.union(*recov_sets.values()) if recov_sets else set()
core = set.intersection(*recov_sets.values()) if recov_sets else set()
print(f"   ever-recovering across any cut: {len(allc)};  recovering at EVERY cut (core): {len(core)}")
for k in sorted(core, key=lambda k: (k[1], name[k[0]])):
    print(f"      core: {name[k[0]]:12} {k[1][:34]:34} level_z={M[k]['level_z']:+6.2f} trend_z={M[k]['trend_z']:+6.2f}")

# ---------------------------------------------------------------- 3. robustness: drop 2 wettest (property scope)
wet_rank = sorted(FLW.items(), key=lambda kv: -(kv[1][0] / kv[1][1] if kv[1][1] else 0))
print("\n=== ROBUSTNESS: two wettest water years, PROPERTY scope (Ruling 3) ===")
print("   property-scope flood fraction = sum(wet_pixels)/sum(valid_pixels) over ALL parts, per water year")
for wy, (w, v) in wet_rank[:5]:
    print(f"      WY{wy}  {100*w/v:6.2f}%  {'<-- DROPPED' if wy in {wet_rank[0][0], wet_rank[1][0]} else ''}")
DROP = frozenset({wet_rank[0][0], wet_rank[1][0]})
parts_r, R = compute(DROP)
for k in parts_r:
    R[k]["state"] = classify(R[k], REGISTERED_CUT)
rob_counts = {s: sum(1 for k in parts_r if R[k]["state"] == s) for s in STATES}
print(f"   dropped: {sorted(DROP)};  parts retained: {len(parts_r)} of {len(parts)}")
print(f"   {'state':20} {'full':>6} {'drop2':>6}")
for s in STATES:
    print(f"   {s:20} {reg_counts[s]:6d} {rob_counts[s]:6d}")
changed = [k for k in parts_r if k in M and R[k]["state"] != M[k]["state"]]
print(f"\n   parts CHANGING STATE: {len(changed)} of {len(parts_r)}")
for k in sorted(changed, key=lambda k: (k[1], name[k[0]])):
    print(f"      {name[k[0]]:12} {k[1][:34]:34} {M[k]['state']:18} -> {R[k]['state']:18} "
          f"(level_z {M[k]['level_z']:+6.2f}->{R[k]['level_z']:+6.2f}  trend_z {M[k]['trend_z']:+6.2f}->{R[k]['trend_z']:+6.2f})")
if not changed:
    print("      none — the classification is unchanged by dropping the two biggest floods.")
rec_kept = len(recov_sets[REGISTERED_CUT] & {k for k in parts_r if R[k]["state"] == "Recovering"})
print(f"   recovering set: {len(reg_rec)} full -> {rob_counts['Recovering']} drop2, {rec_kept} in common")

# ---------------------------------------------------------------- 4. RULING 2 panel: Bala 29ca Inland
print("\n=== RULING 2 — Bala 29ca Inland: raw versus water-adjusted, side by side ===")
BALA = [k for k in parts if name[k[0]] == "Bala 29ca"]
tgt = [k for k in BALA if k[1].startswith("Inland")]
panel_rows = []
for k in tgt + [k for k in BALA if k not in tgt]:
    r = M[k]
    panel_rows.append([name[k[0]], k[1], round(r["level"], 3), round(r["level_z"], 3),
                       round(r["tr_raw"], 4), round(r["comm_med_tr_raw"], 4), round(r["tr_raw_dev"], 4),
                       round(r["ws"], 4), round(r["ws_se"], 4), round(r["flood_trend"], 4),
                       round(r["comm_med_flood_trend"], 4), round(r["flood_mean"], 2),
                       round(r["comm_med_flood_mean"], 2), round(r["ta"], 4),
                       round(r["comm_med_ta"], 4), round(r["trend_dev"], 4), round(r["trend_z"], 3),
                       r["state"], r["pp_split"]])
for k in tgt:
    r = M[k]
    print(f"   part: Bala 29ca · {k[1]}")
    print(f"     RAW scale     trend_raw          = {r['tr_raw']:+.4f} pp/yr  (SE {r['tr_raw_se']:.4f})")
    print(f"                   community median   = {r['comm_med_tr_raw']:+.4f} pp/yr")
    print(f"                   deviation on RAW   = {r['tr_raw_dev']:+.4f} pp/yr   <-- the 'tracks the median' claim")
    print(f"     water          water_slope       = {r['ws']:+.4f} pp per pp flood (SE {r['ws_se']:.4f}, r={r['wr']:.3f})")
    print(f"                   own flood trend    = {r['flood_trend']:+.4f} pp/yr")
    print(f"                   community median   = {r['comm_med_flood_trend']:+.4f} pp/yr")
    print(f"                   own mean flood     = {r['flood_mean']:.2f}%  vs community median {r['comm_med_flood_mean']:.2f}%")
    print(f"     ADJUSTED      trend_adj          = {r['ta']:+.4f} pp/yr  (SE {r['ta_se']:.4f})")
    print(f"                   community median   = {r['comm_med_ta']:+.4f} pp/yr")
    print(f"                   trend_dev          = {r['trend_dev']:+.4f} pp/yr")
    print(f"                   trend_z            = {r['trend_z']:+.3f}   (SD {r['sd_trend_dev']:.4f})")
    print(f"     STATE at the registered cut: {r['state']}"
          + (f" [{r['pp_split']}]" if r["pp_split"] else ""))
    print(f"     level_z = {r['level_z']:+.3f}; distance to the -1.0 level cut = {abs(-1.0-r['level_z']):.3f}")

# ---------------------------------------------------------------- write
with open(OUT / "T13_gateC_classification.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    # NB: the registered state column is named `state_registered`, NOT `state_cut_1.00`.
    # 1.00 is also in CUTS, so emitting both under the same name produced a DUPLICATE column
    # header (values identical, but readers silently keep only one). Fixed 30 Jul 2026.
    w.writerow(["zone_fid", "zone_name", "community", "n_years", "level", "level_z",
                "trend_raw", "water_slope", "trend_adj", "trend_z",
                "state_registered", "pp_split", "flood_sd"]
               + [f"state_cut_{c:.2f}" for c in CUTS] + ["state_drop2wettest"])
    for k in sorted(parts, key=lambda k: (k[1], M[k]["level_z"])):
        r = M[k]
        w.writerow([k[0], name[k[0]], k[1], r["n"], round(r["level"], 3), round(r["level_z"], 3),
                    round(r["tr_raw"], 4), round(r["ws"], 4), round(r["ta"], 4), round(r["trend_z"], 3),
                    r["state"], r["pp_split"], round(r["flood_sd"], 2)]
                   + [classify(r, cc) for cc in CUTS]
                   + [R[k]["state"] if k in R else "excluded_by_support"])
with open(OUT / "T13_gateC_sweep.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["cut"] + STATES + ["pp_low_and_flat", "pp_low_and_falling",
                                   "n_recovering_shared_with_registered"])
    for r in sweep:
        w.writerow([f"{r['cut']:.2f}"] + [r[s] for s in STATES]
                   + [r["pp_low_and_flat"], r["pp_low_and_falling"],
                      len(recov_sets[r["cut"]] & reg_rec)])
with open(OUT / "T13_gateC_robustness.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["zone_fid", "zone_name", "community", "dropped_water_years",
                "state_full", "state_drop2", "changed",
                "level_z_full", "level_z_drop2", "trend_z_full", "trend_z_drop2"])
    for k in sorted(parts_r, key=lambda k: (k[1], name[k[0]])):
        w.writerow([k[0], name[k[0]], k[1], ";".join(str(y) for y in sorted(DROP)),
                    M[k]["state"], R[k]["state"], int(R[k]["state"] != M[k]["state"]),
                    round(M[k]["level_z"], 3), round(R[k]["level_z"], 3),
                    round(M[k]["trend_z"], 3), round(R[k]["trend_z"], 3)])
with open(OUT / "T13_gateC_bala29ca_raw_vs_adjusted.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["zone_name", "community", "level", "level_z", "trend_raw", "comm_median_trend_raw",
                "trend_raw_dev", "water_slope", "water_slope_se", "own_flood_trend",
                "comm_median_flood_trend", "own_mean_flood_pct", "comm_median_mean_flood_pct",
                "trend_adj", "comm_median_trend_adj", "trend_dev", "trend_z", "state", "pp_split"])
    w.writerows(panel_rows)
print("\nwrote T13_gateC_classification.csv, _sweep.csv, _robustness.csv, _bala29ca_raw_vs_adjusted.csv")
print("NO DB write, NO builder run, no existing object modified, no p-values.")
print("Pilot cuts (8 pp / 0.25 pp/yr) not computed, not compared to, not referenced.")
con.close()
