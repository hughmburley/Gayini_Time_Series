#!/usr/bin/env python
"""RPT-SCOPE R2 — the FINAL pin list, emitted for review BEFORE any write. READ-ONLY.

Emits Output/tables/RPTSCOPE_R2_pin_list.csv: number_id, quantity, the five qualifiers,
source_object, derivation route, independent Y/N, and a blocked flag.
"""
import sqlite3, csv, statistics as st, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
TAB = ROOT / "Output" / "tables"
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); con.execute("PRAGMA query_only=1")
c = con.cursor()
P = []
def pin(nid, qty, val, smin, smax, support, scope, pixconst, denom, period, src,
        route, indep, blocked=""):
    P.append(dict(number_id=nid, quantity=qty, pinned_value=val, spread_min=smin, spread_max=smax,
                  support_level=support, scope_filter=scope, pixel_constant=pixconst,
                  denominator=denom, period_label=period, source_object=src,
                  derivation_route=route, independent=indep, blocked=blocked))

NONTREED = "treed_context_flag = 0 AND regime_band <> 'context'"

# ---------------- (a) annual three-paddock reference-grazed gap
ref3, grazed = [1, 2, 3], [z for (z,) in c.execute(
    "SELECT zone_fid FROM dim_management_zone WHERE grazing_excluded = 0")]
S = {}
for zf, wy, p05 in c.execute("SELECT zone_fid,water_year,veg_p05_spatial FROM fact_zone_veg_annual "
                             "WHERE series_variant='mean_of_seasons' AND veg_p05_spatial IS NOT NULL"):
    S.setdefault(wy, {})[zf] = p05
gaps = {}
for wy, d in S.items():
    r = [d[z] for z in ref3 if z in d]; g = [d[z] for z in grazed if z in d]
    if r and g: gaps[wy] = st.mean(r) - st.median(g)
gap_mean = st.mean(gaps.values())
# independent: the separately-built T10 series (different producer, different date)
t10 = [float(r["gap_pp"]) for r in csv.DictReader(open(TAB / "T10_annual_gap_series.csv", encoding="utf-8"))
       if r["series_variant"] == "mean_of_seasons" and r["series"] == "B_excl29ca"]
indep_a = abs(st.mean(t10) - gap_mean) < 0.005
pin("ref_grazed_gap_annual_3pdk_mean", "annual reference-grazed cover-floor gap, 3 conserved "
    "paddocks excluding Bala 29ca, mean over 35 water years",
    round(gap_mean, 3), round(min(gaps.values()), 3), round(max(gaps.values()), 3),
    "zone", f"3 No-grazing paddocks (fids 1,2,3) vs median of {len(grazed)} 14-day; {NONTREED}",
    "", "35 water years", "1988-2022", "fact_zone_veg_annual.veg_p05_spatial",
    f"INDEPENDENT: mean of the separately-built T10_annual_gap_series.csv B_excl29ca series "
    f"({st.mean(t10):.3f}) vs recomputed from the DB ({gap_mean:.3f}) - different artefact, "
    f"different producer, different date; could have disagreed if either drifted",
    "Y" if indep_a else "N-DISAGREES")

# ---------------- (b) Riverine spreads x3  and (c) six-of-seven  -- BLOCKED, spec §6
vw = list(c.execute("SELECT community,regime_band,n_ungrazed_bala,veg_p05_delta_bala_pxwtd,"
                    "ungrazed_p05_min,ungrazed_p05_max FROM v_zone_stratum_contrast_bala_robust"))
BLOCK = ("BLOCKED - spec §6. v_zone_stratum_contrast_bala_robust is built on "
         "census_by_zone_stratum.veg_p05_mean, the census TEMPORAL p05, not veg_p05_spatial. "
         "Reaching for veg_p05_mean for a reference-state purpose is a STOP, not a judgement call.")
for cm, b, n, d, lo, hi in vw:
    if not cm.startswith("Riverine"): continue
    pin(f"ref_set_internal_spread_riverine_{b}",
        f"internal spread of cover floor among the conserved paddocks, Riverine {b} band",
        round(hi - lo, 3), "", "", "zone_stratum",
        f"Bala group, grazing_excluded=1, {NONTREED}, community=Riverine, regime_band={b}",
        "", f"{n} conserved paddocks in stratum", "1988-2023 census",
        "v_zone_stratum_contrast_bala_robust (veg_p05_mean)",
        "n/a - blocked before derivation", "n/a", BLOCK)
multi = [(cm, b, n, d, lo, hi) for cm, b, n, d, lo, hi in vw if n > 1]
six7 = sum(1 for _, _, n, d, lo, hi in multi if (hi - lo) > abs(d))
pin("ref_set_spread_exceeds_contrast_multi_count",
    "strata where the internal spread among conserved paddocks exceeds the conserved-grazed "
    "difference, restricted to strata with >1 conserved paddock",
    six7, "", len(multi), "zone_stratum", f"Bala group, n_ungrazed_bala > 1, {NONTREED}",
    "", f"{len(multi)} strata with >1 conserved paddock", "1988-2023 census",
    "v_zone_stratum_contrast_bala_robust (veg_p05_mean)",
    "n/a - blocked before derivation", "n/a", BLOCK)

# ---------------- (d) five of eight recovering survive drop-two
surv = c.execute("SELECT COUNT(*) FROM fact_zone_community_part_classification "
                 "WHERE state_registered='Recovering' AND state_drop2wettest='Recovering'").fetchone()[0]
pin("t13_recovering_survive_drop2wettest", "recovering parts that remain Recovering when the two "
    "wettest water years are dropped", surv, "", "", "pixel",
    "115 supported parts, >=25 yr, n_pixels_valid>=30; drop WY2022 and WY2016",
    "0.062351428", "8 parts meeting the recovering criterion", "1988-2022",
    "fact_zone_community_part_classification",
    "NONE - the drop-two states are stored, and recomputing them re-runs the T13 Gate C chain, "
    "which is the same operation sequence that produced them. Declared rather than manufactured.",
    "N")

# ---------------- (e) 82% of Bala 29ca's improvement survives water adjustment
tmp = {r["zone_name"]: r for r in csv.DictReader(open(TAB / "T10_gateC_temporal_table.csv", encoding="utf-8"))}
b29 = tmp["Bala 29ca"]
pct = 100 * float(b29["water_adjusted_floor_trend"]) / float(b29["raw_floor_trend"])
# independent: recompute both trends by OLS from fact_zone_veg_annual
yrs = sorted(wy for wy in S if 4 in S[wy])
veg = [S[wy][4] for wy in yrs]
fl = {wy: f for wy, f in c.execute("SELECT water_year,flood_frac_pct FROM fact_zone_veg_annual "
                                   "WHERE zone_fid=4 AND series_variant='mean_of_seasons'")}
def ols(x, y):
    n = len(x); mx = st.mean(x); my = st.mean(y)
    sxx = sum((a-mx)**2 for a in x); sxy = sum((a-mx)*(b-my) for a, b in zip(x, y))
    s = sxy/sxx; return s, [b-(my-s*mx+s*a) for a, b in zip(x, y)]
raw_s, _ = ols(yrs, veg)
ws, wres = ols([fl[w] for w in yrs], veg)
adj_s, _ = ols(yrs, wres)
pct_i = 100*adj_s/raw_s
pin("bala29ca_improvement_surviving_water_pct", "share of Bala 29ca's cover-floor improvement that "
    "survives removing its own water response", round(pct, 1), "", "", "zone",
    f"zone_fid 4, {NONTREED}", "", "raw floor trend +0.6821 pp/yr", "1988-2022",
    "Output/tables/T10_gateC_temporal_table.csv",
    f"INDEPENDENT: OLS recomputed from fact_zone_veg_annual - raw {raw_s:.4f}, water-adjusted "
    f"{adj_s:.4f}, ratio {pct_i:.1f}% vs stored {pct:.1f}%. Different source object and own arithmetic.",
    "Y" if abs(pct_i - pct) < 0.15 else f"N-DIFFERS({pct_i:.1f})")

# ---------------- (f) conserved paddock flood ranks, FOUR rows (Ruling D3)
rk = {z: (r, mf) for z, r, mf in c.execute(
    "SELECT zone_name, RANK() OVER (ORDER BY mean_flood DESC), mean_flood FROM v_zone_floor_flood_residual")}
mf_ind = {}
for zf, wy, ff in c.execute("SELECT zone_fid,water_year,flood_frac_pct FROM fact_zone_veg_annual "
                            "WHERE series_variant='mean_of_seasons' AND flood_frac_pct IS NOT NULL"):
    mf_ind.setdefault(zf, []).append(ff)
names = dict(c.execute("SELECT zone_fid,zone_name FROM dim_management_zone"))
means = sorted(((names[z], st.mean(v)) for z, v in mf_ind.items()), key=lambda kv: -kv[1])
rank_ind = {n: i+1 for i, (n, _) in enumerate(means)}
for z, key in (("Bala 26ca", "bala26ca"), ("Bala 28ca", "bala28ca"),
               ("Bala 27ca", "bala27ca"), ("Bala 29ca", "bala29ca")):
    r, mf = rk[z]
    pin(f"ref_paddock_flood_rank_{key}", f"{z} rank by mean annual flood frequency among 64 paddocks "
        f"(1 = wettest)", r, "", "", "zone", f"64 management zones, {NONTREED}", "",
        "64 paddocks ranked by mean flood frequency", "1988-2022",
        "v_zone_floor_flood_residual.mean_flood",
        f"INDEPENDENT: rank recomputed from fact_zone_veg_annual by mean-of-years per paddock "
        f"-> rank {rank_ind[z]} (view rank {r}); different aggregation route, could have disagreed",
        "Y" if rank_ind[z] == r else f"N-DIFFERS({rank_ind[z]})")

# ---------------- (g) Bala 15 residual
b15r, b15rank = c.execute("SELECT residual, rank FROM v_zone_floor_flood_residual "
                          "WHERE zone_name='Bala 15'").fetchone()
INT, SLP = [c.execute("SELECT pinned_value FROM dim_headline_number WHERE number_id=?", (n,)).fetchone()[0]
            for n in ("floor_flood_intercept_64pdk", "floor_flood_slope_64pdk")]
f15 = st.mean(mf_ind[[k for k, v in names.items() if v == "Bala 15"][0]])
v15 = st.mean([S[wy][[k for k, v in names.items() if v == "Bala 15"][0]] for wy in S
               if [k for k, v in names.items() if v == "Bala 15"][0] in S[wy]])
r15_i = v15 - (INT + SLP * f15)
pin("bala15_xsec_residual", "Bala 15 cover-floor residual from the registered flood expectation "
    "line - the largest shortfall of 64, and grazed", b15r, "", "", "zone",
    f"zone_fid for Bala 15, 14-day grazing, {NONTREED}", "", "64 paddocks", "1988-2022",
    "v_zone_floor_flood_residual",
    f"INDEPENDENT: recomputed as mean floor - (intercept + slope x mean flood) from "
    f"fact_zone_veg_annual and the pinned constants -> {r15_i:.3f} vs view {b15r}; "
    f"differs only by the view's 2-dp column rounding",
    "Y" if abs(r15_i - b15r) < 0.02 else f"N-DIFFERS({r15_i:.3f})")

# ---------------- (h) cropping history 64 of 64 NULL
nz = c.execute("SELECT COUNT(*) FROM dim_management_zone").fetchone()[0]
nn = c.execute("SELECT COUNT(*) FROM dim_management_zone WHERE cropping_history IS NULL").fetchone()[0]
pin("cropping_history_null_count", "management zones with no recorded cropping history",
    nn, "", "", "zone", "all management zones", "", f"{nz} paddocks", "as at 2026-08-03",
    "dim_management_zone.cropping_history",
    "NONE - a NULL count has no second route within the schema; T12 established that DEA cannot "
    "fill it, which is corroboration of the gap, not an independent derivation of the count.", "N")

# ---------------- (i) standard grazing at or above rotational, 6 of 9
arms = {}
for cm, b, arm, v in c.execute("SELECT community,regime_band,treatment_arm,floor_deficit_pp "
                               "FROM v_three_arm_gap_decomposition WHERE window='all' "
                               "AND regime_band IN ('low','mid','high')"):
    arms.setdefault((cm, b), {})[arm] = v
n_ok = sum(1 for d in arms.values() if d.get("unzoned_inferred_standard", -1) >= 0)
pin("three_arm_standard_at_or_above_count", "strata where the standard-grazing arm sits at or above "
    "the 14-day rotational arm on cover floor", n_ok, "", len(arms), "zone_stratum",
    f"three-arm decomposition, window='all', {NONTREED}", "", f"{len(arms)} strata", "1988-2023 census",
    "v_three_arm_gap_decomposition",
    "NONE - the arm deficits are the view's own output and recomputing them re-runs its logic. "
    "The third arm is the 15 UNZONED Standard-grazing plots (see R1b).", "N")

with open(TAB / "RPTSCOPE_R2_pin_list.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(P[0].keys())); w.writeheader(); w.writerows(P)

blocked = [p for p in P if p["blocked"]]
ok = [p for p in P if not p["blocked"]]
print(f"=== FINAL PIN LIST: {len(P)} rows  ({len(ok)} writable, {len(blocked)} BLOCKED) ===\n")
for p in P:
    flag = "BLOCKED" if p["blocked"] else f"indep={p['independent']}"
    print(f"  {p['number_id']:44} = {str(p['pinned_value']):>8}   {flag}")
print(f"\nindependent derivations among the writable {len(ok)}: "
      f"{sum(1 for p in ok if p['independent']=='Y')} Y / {sum(1 for p in ok if p['independent']=='N')} N")
print(f"\nwrote {TAB/'RPTSCOPE_R2_pin_list.csv'}")
con.close()
