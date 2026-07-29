#!/usr/bin/env python
"""T13 Gate B — the two continuous measures per part (115 parts). COMPUTE + REPORT ONLY.
No classification, no state counts (pre-registration: the cut is applied at Gate C).

Per part (mean_of_seasons, >=25 yr, veg n_pixels_valid>=30):
  level, level_dev (vs community median level), level_z (/ community SD of level_dev)
  trend_raw (OLS veg_p05~year), water_slope (OLS veg_p05~own flood_frac),
  trend_adj (residuals of water_slope regressed on year), trend_dev, trend_z
SE on the slopes; NO p-values. Flood-variance flag reported FIRST. Current-year primary,
lagged reported. Writes CSVs only (DB table + states are Gate E)."""
import sqlite3, csv, math
import numpy as np, statistics as st
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/"Output"/"tables"
c=sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",uri=True).cursor()
name={z:n for z,n in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}
graz={z:g for z,g in c.execute("SELECT zone_fid,grazing_excluded FROM dim_management_zone")}
treat={z:("No grazing" if graz[z] else "14-day grazing") for z in name}

def ols(x,y):
    x=np.asarray(x,float);y=np.asarray(y,float);n=len(x)
    mx=x.mean();my=y.mean();sxx=((x-mx)**2).sum();sxy=((x-mx)*(y-my)).sum();syy=((y-my)**2).sum()
    slope=sxy/sxx;inter=my-slope*mx;r=sxy/math.sqrt(sxx*syy) if sxx*syy>0 else float('nan')
    resid=y-(inter+slope*x);sse=(resid**2).sum()
    se=math.sqrt((sse/(n-2))/sxx) if n>2 and sxx>0 else float('nan')
    return slope,se,r,resid,inter

# veg annual per part (>=30 px)
VEG={}
for zf,cm,wy,p05 in c.execute("SELECT zone_fid,community,water_year,veg_p05_spatial FROM fact_zone_community_veg_annual WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL"):
    VEG.setdefault((zf,cm),{})[wy]=p05
# flood annual per part
FL={}
for zf,cm,wy,ff in c.execute("SELECT zone_fid,community,water_year,flood_frac_pct FROM fact_zone_community_flood_annual WHERE flood_frac_pct IS NOT NULL"):
    FL.setdefault((zf,cm),{})[wy]=ff
parts=sorted(k for k,v in VEG.items() if len(v)>=25)
print(f"parts (>=25 yr, >=30 px): {len(parts)}")

rows={}; resid_rows=[]; lag_better=0; lag_valid=0
for k in parts:
    zf,cm=k
    yrs=sorted(y for y in VEG[k] if y in FL[k])          # years with both veg & flood
    veg=[VEG[k][y] for y in yrs]; fld=[FL[k][y] for y in yrs]
    level=st.mean(veg)
    tr_raw,tr_raw_se,_,_,_=ols(yrs,veg)
    ws,ws_se,wr,wres,wint=ols(fld,veg)                   # water_slope (current year)
    ta,ta_se,_,tares,_=ols(yrs,list(wres))               # trend_adj = residuals-on-year
    flood_sd=st.pstdev(fld) if len(fld)>1 else 0.0       # within-part SD of flood_frac
    # lagged water: veg(t) ~ flood(t-1)
    lp=[(VEG[k][y],FL[k][y-1],y) for y in yrs if (y-1) in FL[k]]
    lag_r=float('nan')
    if len(lp)>2:
        _,_,lag_r,_,_=ols([p[1] for p in lp],[p[0] for p in lp]); lag_valid+=1
        if abs(lag_r)>abs(wr): lag_better+=1
    rows[k]=dict(zf=zf,cm=cm,treat=treat[zf],n=len(yrs),level=level,tr_raw=tr_raw,tr_raw_se=tr_raw_se,
                 ws=ws,ws_se=ws_se,wr=wr,ta=ta,ta_se=ta_se,flood_sd=flood_sd,lag_r=lag_r)
    for y,e in zip(yrs,tares): resid_rows.append((zf,name[zf],cm,y,round(e,3)))

# community deviations, SDs (the z scale), z-scores
COMMS=sorted(set(cm for _,cm in parts))
comm_lvl_sd={};comm_trd_sd={}
for cm in COMMS:
    ks=[k for k in parts if k[1]==cm]
    med_l=st.median([rows[k]['level'] for k in ks]); med_t=st.median([rows[k]['ta'] for k in ks])
    for k in ks: rows[k]['level_dev']=rows[k]['level']-med_l; rows[k]['trend_dev']=rows[k]['ta']-med_t
    comm_lvl_sd[cm]=st.stdev([rows[k]['level_dev'] for k in ks])   # ddof=1
    comm_trd_sd[cm]=st.stdev([rows[k]['trend_dev'] for k in ks])
for k in parts:
    cm=k[1]
    rows[k]['level_z']=rows[k]['level_dev']/comm_lvl_sd[cm]
    rows[k]['trend_z']=rows[k]['trend_dev']/comm_trd_sd[cm]

# ---------- REPORT 1 (FIRST): flood-variance flag ----------
flagged=[k for k in parts if rows[k]['flood_sd']<2.0]
print("\n=== FLOOD-VARIANCE FLAG (reported first) ===")
print(f"parts with within-part SD(flood_frac_pct) < 2 pp: {len(flagged)} of {len(parts)} ({100*len(flagged)/len(parts):.0f}%)")
for k in sorted(flagged,key=lambda k:rows[k]['flood_sd']):
    print(f"   {name[k[0]]:12} {k[1][:8]:8} flood_sd={rows[k]['flood_sd']:.2f}  -> trend_adj UNRELIABLE (water_slope fit on ~no variance)")
if not flagged: print("   none.")

# ---------- REPORT 2: community SD (the z scale) ----------
print("\n=== COMMUNITY SD (the z-score scale) ===")
for cm in COMMS:
    nk=sum(1 for k in parts if k[1]==cm)
    print(f"   {cm[:30]:30} n={nk:3d}  SD(level_dev)={comm_lvl_sd[cm]:5.2f} pp   SD(trend_dev)={comm_trd_sd[cm]:.3f} pp/yr")
print("   -> a z of -1.0 means a different amount of ground in each community; the map caption must say so.")

# ---------- lag comparison ----------
print(f"\n=== water spec: lagged fit better than current for {lag_better}/{lag_valid} parts (current-year remains PRIMARY, declared in advance) ===")

# ---------- write CSVs ----------
cols=["zone_fid","zone_name","community","treatment","n_years","level","level_dev","level_z",
      "trend_raw","trend_raw_se","water_slope","water_slope_se","water_r","trend_adj","trend_adj_se",
      "trend_dev","trend_z","flood_sd","flood_var_flag_lt2pp","lag_water_r"]
with open(OUT/"T13_gateB_part_measures.csv","w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(cols)
    for k in sorted(parts,key=lambda k:(k[1],rows[k]['level_z'])):
        r=rows[k]
        w.writerow([r['zf'],name[r['zf']],r['cm'],r['treat'],r['n'],round(r['level'],3),round(r['level_dev'],3),round(r['level_z'],3),
                    round(r['tr_raw'],4),round(r['tr_raw_se'],4),round(r['ws'],4),round(r['ws_se'],4),round(r['wr'],3),
                    round(r['ta'],4),round(r['ta_se'],4),round(r['trend_dev'],4),round(r['trend_z'],3),
                    round(r['flood_sd'],2),int(r['flood_sd']<2.0),round(r['lag_r'],3)])
with open(OUT/"T13_gateB_trend_adj_residuals.csv","w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["zone_fid","zone_name","community","water_year","trend_adj_residual"]); w.writerows(resid_rows)
print(f"\nwrote T13_gateB_part_measures.csv ({len(parts)} parts) and T13_gateB_trend_adj_residuals.csv ({len(resid_rows)} rows)")
print("NO classification computed (pre-registration; cut applied at Gate C).")
