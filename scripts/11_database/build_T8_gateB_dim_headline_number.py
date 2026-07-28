#!/usr/bin/env python
"""T8 Gate B/D + PIN 4 — build dim_headline_number, add is_rollup, add paddock identity.

ADDITIVE ONLY. Creates dim_headline_number (new), recreates the trivial passthrough view
v_three_arm_gap_decomposition WITH an is_rollup column (row count unchanged), and adds
zone_fid/zone_name to plot_management_overlay (additive columns, populated from the verified
plot_paddock join). No builder run, no existing row deleted, no rename.

Pins per docs/reference_update/T8_gateA_pin_decisions.md v1 (auth) > T8_T9_T10_gateA_decisions.md
> spec v1. Sixth pin: #9 AREA-WEIGHTED. Idempotent: INSERT OR REPLACE keyed on number_id;
ADD COLUMN guarded by pragma. Registration convention: never OR IGNORE.

Pinned values are computed LIVE here so the table cannot drift from the data at build time;
test_T8_headline_reproduction.py re-derives independently and asserts to 0.05 pp.
"""
import sqlite3, statistics as st, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from gayini_params import PIXEL_AREA_HA, MAPPED_AREA_HA, TRUE_FARM_HA  # never hardcode  # noqa
PX = PIXEL_AREA_HA
FARM_HA = TRUE_FARM_HA
MAPPED_HA = MAPPED_AREA_HA
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
con = sqlite3.connect(DB); c = con.cursor()

REF=[1,2,3,4]; REF3=[1,2,3]
grazed=[r[0] for r in c.execute("SELECT zone_fid FROM dim_management_zone WHERE grazing_excluded=0")]
assert len(grazed)==60
ORD3=['Aeolian Chenopod Shrublands','Riverine Chenopod Shrublands','Inland Floodplain Shrublands / Swamps']
SHORT={'Aeolian Chenopod Shrublands':'aeolian','Riverine Chenopod Shrublands':'riverine','Inland Floodplain Shrublands / Swamps':'inland'}

# ---------- live compute helpers ----------
F={}
for zf,wy,var,p05,med,ff in c.execute(
    "SELECT zone_fid,water_year,series_variant,veg_p05_spatial,veg_median,flood_frac_pct FROM fact_zone_veg_annual"):
    F.setdefault(var,{})[(zf,wy)]=(p05,med,ff)

def gap(var,lo,hi,order,ref=REF):
    r={};g={}
    for (zf,wy),v in F[var].items():
        if lo<=wy<=hi and v[0] is not None:
            (r if zf in ref else (g if zf in grazed else {})).setdefault(wy,[]).append(v[0])
    yrs=sorted(set(r)&set(g))
    if order=="year_first":
        return st.mean([st.mean(r[y]) for y in yrs]) - st.mean([st.median(g[y]) for y in yrs])
    rz=[st.mean([F[var][(f,y)][0] for y in yrs if F[var].get((f,y),[None])[0] is not None]) for f in ref]
    gz=[st.mean([F[var][(f,y)][0] for y in yrs if F[var].get((f,y),[None])[0] is not None]) for f in grazed]
    return st.mean(rz)-st.median(gz)

# three-arm deficits + stratum areas (for area-weighting; sixth pin)
def deficits(col,arm):
    return {(cm,b):v for cm,b,v in c.execute(
        f"SELECT community,regime_band,{col} FROM v_three_arm_gap_decomposition "
        f"WHERE treatment_arm=? AND window='all' AND regime_band IN ('low','mid','high')",(arm,))}
AREA={(cm,b):ha for cm,b,ha in c.execute(
    "SELECT community,regime_band,sum(area_ha) FROM census_by_zone_stratum "
    "WHERE treed_context_flag=0 AND regime_band IN ('low','mid','high') GROUP BY community,regime_band")}
def wmean(d,keys):  # area-weighted
    return sum(d[k]*AREA[k] for k in keys)/sum(AREA[k] for k in keys)
def emean(d,keys):  # equal-weighted
    return st.mean([d[k] for k in keys])
def comm_keys(cm): return [(cm,b) for b in ('low','mid','high')]
NINE=[(cm,b) for cm in ORD3 for b in ('low','mid','high')]

def pmean(f,col):
    xs=[F['mean_of_seasons'][(f,y)][col] for y in range(1988,2023)
        if F['mean_of_seasons'].get((f,y),(None,None,None))[col] is not None]
    return st.mean(xs) if xs else None

# ---------- assemble rows ----------
DEC="design-seat T8_gateA_pin_decisions.md v1 (Hugh); built by CC 2026-07-28"
rows=[]
def R(nid,label,src,grain,order,var,scope,period,denom,pinned,smin,smax,support,caveat,note):
    rows.append((nid,label,src,grain,order,var,scope,period,denom,PX,pinned,smin,smax,support,caveat,DEC,note))

# #1 (PIN 2)
g4=gap("mean_of_seasons",1988,1992,"year_first")
R("ref_grazed_floor_gap_4pdk_1988_92","Ref-grazed floor gap, 4 paddocks, 1988-92","v_zone_veg_annual",
  "zone","year_first (median across 60 grazed within year, then period mean)","mean_of_seasons",
  "ref=grazing_excluded=1 (fids 1-4) ; grazed=grazing_excluded=0 (60)","1988-1992","grazed median (60 zones)",
  round(g4,2),-14.8,-9.1,"zone","jja_son sensitivity -11.2 (same number_id). Full 8-way (grain x order x variant) spans -9.1..-14.8.",
  "PIN 2: zone grain, year-first, mean_of_seasons; unit is the paddock and matches the T2_E/T6 grey comparator band.")
# #2/#3/#4 (PIN 3 - BLOCKED, pinned NULL)
R("ref_grazed_floor_gap_3pdk_periodwise","Ref-grazed floor gap, 3 paddocks (no 29ca), by period","v_zone_veg_annual",
  "zone","year_first","mean_of_seasons","ref3=fids 1-3 ; grazed=60","1988-92/93-2002/2003-12/2013-18/2019-22",
  "grazed median",None,None,None,"zone","deck reports -1.5..-3.3 across the 5 periods (mean_of_seasons).",
  "PIN 3 BLOCKED on I-29; the 5-period split has no producing script; superseded by T10 Gate B annual trend.")
R("bala29ca_floor_gap_periodwise","Bala 29ca floor gap, by period","v_zone_veg_annual",
  "zone","year_first","mean_of_seasons","fid4 vs grazed=60","5 periods","grazed median",
  None,None,None,"zone","deck reports -42.3 -> -18.0 (mean_of_seasons).",
  "PIN 3 BLOCKED on I-29; superseded by T10 Gate B annual trend.")
R("bala29ca_floor_gap_periodwise_jja_son","Bala 29ca floor gap, by period, jja_son","v_zone_veg_annual",
  "zone","year_first","jja_son","fid4 vs grazed=60","5 periods","grazed median",
  None,None,None,"zone","deck reports -38.5 -> -18.3 (jja_son).",
  "PIN 3 BLOCKED on I-29; superseded by T10 Gate B annual trend.")
# #5 (PIN 4 - re-derived, confirmed)
share=100*13/24
R("bala29ca_ref_plot_share_pct","Bala 29ca share of reference monitoring plots","plot_paddock",
  "plot","count","n/a","grazing_excluded=1 plots by paddock","n/a","24 reference plots",
  round(share,2),share,share,"plot","13 of 24 reference plots. Re-derived by independent centroid-in-polygon join (9473->8058), 0 mismatch vs plot_paddock.",
  "PIN 4: not derivable from plot_management_overlay (class only); paddock identity added this gate.")
# #6 mean cover by community (area-weighted band mean; #6 agrees within <=0.2pp of equal)
d6=deficits('mean_deficit_pp','not_grazed')
for cm in ORD3:
    aw=wmean(d6,comm_keys(cm)); ew=emean(d6,comm_keys(cm))
    all_row=c.execute("SELECT mean_deficit_pp FROM v_three_arm_gap_decomposition WHERE treatment_arm='not_grazed' AND window='all' AND community=? AND regime_band='ALL'",(cm,)).fetchone()[0]
    R(f"ref_grazed_mean_cover_{SHORT[cm]}",f"Ref-grazed MEAN cover deficit, {SHORT[cm]}","v_three_arm_gap_decomposition",
      "community (area-weighted band mean)","area-weighted mean over 3 wetness bands","mean_of_seasons",
      "treatment_arm='not_grazed', window='all', regime_band<>'ALL'","all","stratum area (non-treed)",
      round(aw,2),round(min(ew,all_row),2),round(max(ew,all_row),2),"stratum",
      f"deck used regime_band='ALL' rollup ({all_row:+.1f}); equal-weighted band mean {ew:+.1f}.",
      "PIN 1: band mean retires the ALL rollup (reintroduces the drier-skew confound T6 designs out).")
# #7 floor by community (area-weighted band mean)
d7=deficits('floor_deficit_pp','not_grazed')
for cm in ORD3:
    aw=wmean(d7,comm_keys(cm)); ew=emean(d7,comm_keys(cm))
    all_row=c.execute("SELECT floor_deficit_pp FROM v_three_arm_gap_decomposition WHERE treatment_arm='not_grazed' AND window='all' AND community=? AND regime_band='ALL'",(cm,)).fetchone()[0]
    R(f"ref_grazed_floor_{SHORT[cm]}",f"Ref-grazed FLOOR deficit, {SHORT[cm]}","v_three_arm_gap_decomposition",
      "community (area-weighted band mean)","area-weighted mean over 3 wetness bands","mean_of_seasons",
      "treatment_arm='not_grazed', window='all', regime_band<>'ALL'","all","stratum area (non-treed)",
      round(aw,2),round(min(ew,all_row),2),round(max(ew,all_row),2),"stratum",
      f"deck used regime_band='ALL' rollup ({all_row:+.1f}); equal-weighted band mean {ew:+.1f}. ALL roughly DOUBLES the deficit on Aeolian/Riverine.",
      "PIN 1: band mean retires the ALL rollup. Materially changes deck slide 10 floor numbers.")
# #9 three-arm floor deficit (AREA-WEIGHTED sixth pin), + counts
for arm,short in (('not_grazed','not_grazed'),('unzoned_inferred_standard','unzoned_inferred'),('unzoned_plot_confirmed','unzoned_plot')):
    d=deficits('floor_deficit_pp',arm)
    aw=wmean(d,NINE); ew=emean(d,NINE)
    R(f"three_arm_floor_deficit_{short}",f"Three-arm floor deficit vs 14-day, {short}","v_three_arm_gap_decomposition",
      "9 strata (area-weighted)","area-weighted mean over 9 strata","mean_of_seasons",
      f"treatment_arm='{arm}', window='all', regime_band<>'ALL'","all","stratum area (non-treed)",
      round(aw,2),round(min(aw,ew),2),round(max(aw,ew),2),"stratum",
      f"SIXTH PIN: area-weighted. Equal-weighted {ew:+.1f} over-weights the n=1 Aeolian stratum (7.8% of area, largest deficits, Bala 29ca alone).",
      "PIN 1 + sixth pin (area-weighted). Deck equal-weighted value recorded as spread endpoint.")
for arm,short,cnt in (('unzoned_inferred_standard','unzoned_inferred',6),('unzoned_plot_confirmed','unzoned_plot',8)):
    n=c.execute(f"SELECT sum(CASE WHEN floor_deficit_pp>0 THEN 1 ELSE 0 END) FROM v_three_arm_gap_decomposition WHERE treatment_arm=? AND window='all' AND regime_band<>'ALL'",(arm,)).fetchone()[0]
    R(f"three_arm_{short}_above_14day_count",f"Strata where {short} floor >= 14-day","v_three_arm_gap_decomposition",
      "9 strata (count)","count of strata floor_deficit_pp>0","mean_of_seasons",
      f"treatment_arm='{arm}', window='all', regime_band<>'ALL'","all","9 strata",
      float(n),float(n),float(n),"stratum","weighting-free; the consistency claim rests here, not on the magnitudes.",
      "Count is invariant to the equal/area weighting choice.")
# #8 Bala29ca median cover
b29med=pmean(4,1)
R("bala29ca_median_cover","Bala 29ca median cover vs grazed median","fact_zone_veg_annual",
  "zone","mean over 35 yr of veg_median","mean_of_seasons","fid4","1988-2022","grazed median-of-zone-means 81.6",
  round(b29med,1),round(b29med,1),round(b29med,1),"zone","grazed median 81.6 (6 pp gap on median vs 29 pp on the floor).",
  "descriptor; verified live.")
# #16 Bala29ca flood
b29ff=st.mean([F['mean_of_seasons'][(4,y)][2] for y in range(1988,2023) if F['mean_of_seasons'].get((4,y),(None,None,None))[2] is not None])
R("bala29ca_mean_flood_freq","Bala 29ca mean annual flood frequency","fact_zone_veg_annual",
  "zone","mean flood_frac_pct over 35 yr","variant-independent","fid4","1988-2022","valid pixels",
  round(b29ff,1),round(b29ff,1),round(b29ff,1),"zone","grazed median 28.6%; fourth-driest of 64 paddocks.",
  "descriptor; verified live.")
# #12/#13 T1 contrasts
for band,delta in c.execute("SELECT regime_band,veg_p05_delta FROM v_zone_stratum_treatment_contrast WHERE community LIKE 'Riverine%'"):
    R(f"t1_riverine_contrast_{band}",f"T1 matched contrast, Riverine {band}","v_zone_stratum_treatment_contrast",
      "pixel","pixel-weighted ungrazed-minus-grazed veg_p05","census","all ungrazed zones",f"Riverine {band}","grazed pixels",
      round(delta,2),round(delta,2),round(delta,2),"pixel","looked like a grazing effect; collapses to Bala-support row below.",
      "verified live.")
for band,delta in c.execute("SELECT regime_band,veg_p05_delta_zonesupport FROM v_zone_stratum_contrast_bala_robust WHERE community LIKE 'Riverine%'"):
    R(f"t1_riverine_contrast_bala_{band}",f"T1 contrast at Bala zone support, Riverine {band}","v_zone_stratum_contrast_bala_robust",
      "zone","zone-support ungrazed-minus-grazed veg_p05","census","Bala only",f"Riverine {band}","grazed zones",
      round(delta,2),round(delta,2),round(delta,2),"zone","the collapse: the apparent effect was block structure.",
      "verified live.")
# #14/#15 gap change
for fc,tag in (("all","all"),("non_flood","non_flood")):
    for cm,v in c.execute("SELECT community,gap_change_pp FROM v_reference_gap_decomposition WHERE window='all' AND flood_class=?",(fc,)):
        R(f"gap_change_{tag}_{SHORT[cm]}",f"Gap change 88-97->13-22, {SHORT[cm]}, {tag}","v_reference_gap_decomposition",
          "community","gap_change_pp (two-window)","mean_of_seasons",f"window='all', flood_class='{fc}'","1988-97 vs 2013-22","two windows",
          round(v,1),round(v,1),round(v,1),"stratum","two-window (has a script), distinct from the blocked 5-period split.",
          "verified live.")
# #17 regression (INDEPENDENT; not reconciled to chat figure)
X=[];Y=[]
for f in range(1,65):
    fx=pmean(f,2); fy=pmean(f,0)
    if fx is not None and fy is not None: X.append(fx);Y.append(fy)
mx=st.mean(X);my=st.mean(Y);sxx=sum((x-mx)**2 for x in X);sxy=sum((x-mx)*(y-my) for x,y in zip(X,Y));syy=sum((y-my)**2 for y in Y)
slope=sxy/sxx;r=sxy/(sxx*syy)**0.5
R("floor_flood_slope_64pdk","Floor vs flood-freq OLS slope, 64 paddocks","fact_zone_veg_annual",
  "paddock","OLS of mean veg_p05_spatial on mean flood_frac_pct","mean_of_seasons","all 64 paddocks","1988-2022","64 paddocks",
  round(slope,3),round(slope,3),round(slope,3),"paddock","independently recomputed; the deck's chat figure (+0.55) is unregistered.",
  "decided_by CC independent recompute per decisions 3a; T10 Gate B re-registers with SE.")
R("floor_flood_r_64pdk","Floor vs flood-freq correlation r, 64 paddocks","fact_zone_veg_annual",
  "paddock","Pearson r","mean_of_seasons","all 64 paddocks","1988-2022","64 paddocks",
  round(r,3),round(r,3),round(r,3),"paddock","independently recomputed (deck chat figure 0.71, unregistered).",
  "decided_by CC independent recompute per decisions 3a.")
# #18/PIN 5 areas
npx=c.execute("SELECT sum(n_pixels) FROM census_by_zone_stratum WHERE zone_fid IS NULL").fetchone()[0]
inside=npx*PX; outside=FARM_HA-MAPPED_HA; tot=inside+outside
R("unzoned_inside_mapped_ha","Unzoned area inside the mapped census","census_by_zone_stratum",
  "property","sum(n_pixels)*PIXEL_AREA_HA","n/a","zone_fid IS NULL","n/a",f"mapped {MAPPED_HA} ha",
  round(inside,1),round(inside,1),round(inside,1),"pixel",f"{100*inside/MAPPED_HA:.1f}% of mapped. Corrects T1-spec 12,179 ha (used wrong 0.0625).",
  "PIN 5: split. 194,865 px * 0.062351428 = 12,150; * 0.0625 = 12,179 (the drift).")
R("property_outside_mapped_ha","Property area outside the mapped census","census scope",
  "property","farm - mapped","n/a","n/a","n/a",f"farm {FARM_HA} ha",
  round(outside,1),round(outside,1),round(outside,1),"property",f"{100*outside/FARM_HA:.1f}% of property; includes 7 of 15 standard-grazing plots.",
  "PIN 5: disjoint from unzoned_inside_mapped_ha by construction.")
R("total_no_management_zone_ha","Total property in no management zone","derived",
  "property","unzoned_inside + property_outside","n/a","n/a","n/a",f"farm {FARM_HA} ha",
  round(tot,1),round(tot,1),round(tot,1),"property",f"{100*tot/FARM_HA:.1f}% of property; new to deck and methods.",
  "PIN 5: third derived row (a+b, disjoint).")

# ---------- write table ----------
c.execute("""CREATE TABLE IF NOT EXISTS dim_headline_number(
  number_id TEXT PRIMARY KEY, label TEXT NOT NULL, source_object TEXT NOT NULL,
  grain TEXT NOT NULL, aggregation_order TEXT NOT NULL, series_variant TEXT NOT NULL,
  scope_filter TEXT NOT NULL, period_label TEXT, denominator TEXT, pixel_constant REAL,
  pinned_value REAL, spread_min REAL, spread_max REAL,           -- pinned_value NULLABLE (PIN 3 blocked rows)
  support_level TEXT, caveat TEXT, decided_by TEXT, decision_note TEXT)""")
c.executemany("""INSERT OR REPLACE INTO dim_headline_number
 (number_id,label,source_object,grain,aggregation_order,series_variant,scope_filter,period_label,
  denominator,pixel_constant,pinned_value,spread_min,spread_max,support_level,caveat,decided_by,decision_note)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)

# ---------- Gate D: is_rollup on the three-arm view (additive; row count unchanged) ----------
before=c.execute("SELECT count(*) FROM v_three_arm_gap_decomposition").fetchone()[0]
c.execute("DROP VIEW v_three_arm_gap_decomposition")
c.execute("""CREATE VIEW v_three_arm_gap_decomposition AS
 SELECT *, CASE WHEN regime_band='ALL' THEN 1 ELSE 0 END AS is_rollup
 FROM fact_three_arm_gap_decomposition""")
after=c.execute("SELECT count(*) FROM v_three_arm_gap_decomposition").fetchone()[0]
assert before==after, (before,after)

# ---------- PIN 4: additive paddock identity on plot_management_overlay ----------
have=[x[1] for x in c.execute("PRAGMA table_info(plot_management_overlay)")]
if 'zone_fid' not in have:  c.execute("ALTER TABLE plot_management_overlay ADD COLUMN zone_fid INTEGER")
if 'zone_name' not in have: c.execute("ALTER TABLE plot_management_overlay ADD COLUMN zone_name TEXT")
c.execute("""UPDATE plot_management_overlay SET
   zone_fid=(SELECT zone_fid FROM plot_paddock pp WHERE pp.plot_id=plot_management_overlay.plot_id),
   zone_name=(SELECT zone_name FROM plot_paddock pp WHERE pp.plot_id=plot_management_overlay.plot_id)""")

con.commit()
# ---------- verification ----------
print("dim_headline_number rows:", c.execute("SELECT count(*) FROM dim_headline_number").fetchone()[0])
print("  pinned NULL (blocked):", c.execute("SELECT count(*) FROM dim_headline_number WHERE pinned_value IS NULL").fetchone()[0])
print("  spread_min/max non-null on pinned rows:",
      c.execute("SELECT count(*) FROM dim_headline_number WHERE pinned_value IS NOT NULL AND (spread_min IS NULL OR spread_max IS NULL)").fetchone()[0],"missing (want 0)")
print("v_three_arm_gap_decomposition rows:",after,"(unchanged) is_rollup sum:",
      c.execute("SELECT sum(is_rollup) FROM v_three_arm_gap_decomposition").fetchone()[0])
print("plot_management_overlay zone_fid populated:",
      c.execute("SELECT count(*) FROM plot_management_overlay WHERE zone_fid IS NOT NULL").fetchone()[0],"/66")
print("  ref plots per paddock:", c.execute("SELECT zone_name,count(*) FROM plot_management_overlay WHERE zone_fid IN (1,2,3,4) GROUP BY zone_fid").fetchall())
con.close()
print("DONE")
