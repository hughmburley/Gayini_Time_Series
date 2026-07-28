#!/usr/bin/env python
"""T10 Gate C (+ amendment A1) — cross-sectional residuals AND the temporal arm.
READ-ONLY: computes, writes CSVs to Output/tables, no DB write (register is Gate D).

Cross-sectional (5.1-5.4): floor vs flood across 64 paddocks; bivariate / +community /
within-Inland; 64-paddock residual table; Bala 29ca residual vs raw -42.3.
Temporal (5.6, A1): per paddock, within-paddock floor~flood (current + 1yr lag), residual
trend on water year = water-adjusted floor trend; raw floor trend; flood variance flag.
No p-values (serial correlation, spec 4.1). Design-seat figures are predictions to CHECK.
"""
import sqlite3, csv, math
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
OUT=ROOT/"Output"/"tables"; OUT.mkdir(parents=True,exist_ok=True)
con=sqlite3.connect(f"file:{DB.as_posix()}?mode=ro",uri=True); c=con.cursor()

REF=[1,2,3,4]; DINAN10=57
name={zf:nm for zf,nm in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}
graz={zf:g for zf,g in c.execute("SELECT zone_fid,grazing_excluded FROM dim_management_zone")}
treat={zf:("No grazing" if graz[zf] else "14-day grazing") for zf in name}
# per-paddock annual series (mean_of_seasons)
P={}  # zf -> {year:(veg_p05, flood_frac)}
for zf,wy,p05,ff in c.execute("SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'"):
    P.setdefault(zf,{})[wy]=(p05,ff)
# dominant community (max non-treed pixels)
from collections import defaultdict
pix=defaultdict(dict)
for zf,cm,n in c.execute("SELECT zone_fid,community,sum(n_pixels) FROM census_by_zone_stratum WHERE treed_context_flag=0 AND zone_fid IS NOT NULL GROUP BY zone_fid,community"):
    pix[zf][cm]=n
dom={zf:(max(d,key=d.get),d[max(d,key=d.get)]/sum(d.values())) for zf,d in pix.items()}

def ols(x,y):
    x=np.asarray(x,float);y=np.asarray(y,float);n=len(x)
    mx=x.mean();my=y.mean();sxx=((x-mx)**2).sum();sxy=((x-mx)*(y-my)).sum();syy=((y-my)**2).sum()
    slope=sxy/sxx; inter=my-slope*mx; r=sxy/math.sqrt(sxx*syy) if sxx*syy>0 else float('nan')
    resid=y-(inter+slope*x); sse=(resid**2).sum()
    se=math.sqrt((sse/(n-2))/sxx) if n>2 and sxx>0 else float('nan')
    return dict(slope=slope,inter=inter,r=r,se=se,n=n,resid=resid)

# paddock-level cross-sectional means
zfs=sorted(P); mfloor={};mflood={}
for zf in zfs:
    v=[a for a,_ in P[zf].values() if a is not None]; f=[b for _,b in P[zf].values() if b is not None]
    mfloor[zf]=np.mean(v); mflood[zf]=np.mean(f)

print("="*80); print("5.1 CROSS-SECTIONAL FITS")
# 1 bivariate
biv=ols([mflood[z] for z in zfs],[mfloor[z] for z in zfs])
print(f"  (1) bivariate floor~flood: slope {biv['slope']:+.3f} r {biv['r']:.3f} n {biv['n']}  (registered +0.548 / 0.710)")
# 2 +community (Inland reference; dummies Aeolian, Riverine)
def comm_short(zf):
    cm=dom[zf][0]
    return 'aeolian' if cm.startswith('Aeolian') else 'riverine' if cm.startswith('Riverine') else 'inland'
X=[];Y=[]
for z in zfs:
    cs=comm_short(z)
    X.append([1.0,mflood[z],1.0 if cs=='aeolian' else 0.0,1.0 if cs=='riverine' else 0.0]);Y.append(mfloor[z])
X=np.array(X);Y=np.array(Y);beta,_,_,_=np.linalg.lstsq(X,Y,rcond=None)
yhat=X@beta;ss_res=((Y-yhat)**2).sum();ss_tot=((Y-Y.mean())**2).sum();R2=1-ss_res/ss_tot
print(f"  (2) +community: flood coef {beta[1]:+.3f}  Aeolian {beta[2]:+.2f}  Riverine {beta[3]:+.2f}  R2 {R2:.3f}")
print(f"      Aeolian term rests on n={sum(1 for z in zfs if comm_short(z)=='aeolian')} paddocks: "
      +", ".join(f"{name[z]}({'grazed' if not graz[z] else 'ungrazed'})" for z in zfs if comm_short(z)=='aeolian'))
# 3 within Inland
inl=[z for z in zfs if comm_short(z)=='inland']
wi=ols([mflood[z] for z in inl],[mfloor[z] for z in inl])
print(f"  (3) within Inland (n={wi['n']}): slope {wi['slope']:+.3f} r {wi['r']:.3f}   (predicted +0.503 / 0.680)")

print("\n5.2 DOMINANT-COMMUNITY ASSIGNMENT QUALITY")
from collections import Counter
cnt=Counter(comm_short(z) for z in zfs)
print(f"  counts: {dict(cnt)}   |  below 60% dominance: {sum(1 for z in zfs if dom[z][1]<0.6)} paddocks")
print(f"  ** DIFFER vs spec 5.2: Bala 29ca dominant = {dom[4][0][:20]} at {100*dom[4][1]:.1f}% "
      f"(Inland 34.6/Riverine 33.1/Aeolian 32.3 - a three-way split, LOWEST dominance of all 64).")
print(f"     Spec assumed Bala 29ca in the Aeolian n=3; by max-pixel it is Inland-plurality. Not tuned to match.")

# 5.3 cross-sectional residual table (CHOSEN MODEL = bivariate, per 5.2 given Aeolian instability)
print("\n5.3 CROSS-SECTIONAL RESIDUAL TABLE (model = bivariate)")
xres={z: mfloor[z]-(biv['inter']+biv['slope']*mflood[z]) for z in zfs}
resid_sd=np.std(list(xres.values()),ddof=1)
ranked=sorted(zfs,key=lambda z:xres[z])
print(f"  residual SD = {resid_sd:.2f} pp")
for z in REF+[DINAN10]:
    rank=ranked.index(z)+1
    print(f"   {name[z]:12} floor {mfloor[z]:5.1f} flood {mflood[z]:5.1f} pred {biv['inter']+biv['slope']*mflood[z]:5.1f} "
          f"resid {xres[z]:+6.1f} rank {rank}/64  ({'ungrazed' if graz[z] else 'grazed'})")

# 5.4a Bala 29ca cross-sectional residual vs raw -42.3
print(f"\n5.4a Bala 29ca cross-sectional residual = {xres[4]:+.1f} pp  vs raw gap -42.3 pp "
      f"-> {100*abs(xres[4])/42.3:.0f}% of the gap survives wetness adjustment")

# ---------------- 5.6 TEMPORAL ARM ----------------
print("\n"+"="*80); print("5.6 TEMPORAL ARM (within-paddock)")
rows=[]
for z in zfs:
    yrs=sorted(k for k in P[z] if P[z][k][0] is not None and P[z][k][1] is not None)
    veg=[P[z][y][0] for y in yrs]; fld=[P[z][y][1] for y in yrs]
    raw=ols(yrs,veg)                                  # raw floor trend
    wr=ols(fld,veg)                                   # within-paddock water response (current)
    adj=ols(yrs,list(wr['resid']))                    # residuals-on-year = water-adjusted trend
    fsd=float(np.std(fld,ddof=1))
    # lag: veg(t) ~ flood(t-1)
    lagpairs=[(P[z][y][0],P[z][y-1][1]) for y in yrs if (y-1) in P[z] and P[z][y-1][1] is not None]
    lr=ols([p[1] for p in lagpairs],[p[0] for p in lagpairs]) if len(lagpairs)>2 else None
    rows.append(dict(zf=z,name=name[z],treat=treat[z],raw=raw['slope'],wslope=wr['slope'],wr=wr['r'],
                     adj=adj['slope'],adjse=adj['se'],fsd=fsd,n=raw['n'],
                     lag_r=(lr['r'] if lr else float('nan')),cur_r=wr['r']))
# rank by adjusted trend
rows.sort(key=lambda d:d['adj'])
for i,d in enumerate(rows,1): d['rank_adj']=i
byzf={d['zf']:d for d in rows}

# A1 prediction check: flood trend per paddock
print("A1 flood-trend predictions (flood_frac~year):")
PREDF={4:(+0.304,0.268),1:(-0.301,None),2:(-0.099,None),3:(-0.424,None)}
for z,(ps,pr) in PREDF.items():
    yrs=sorted(k for k in P[z] if P[z][k][1] is not None); ft=ols(yrs,[P[z][y][1] for y in yrs])
    tag=f"predicted {ps:+.3f}"+(f" r {pr:.3f}" if pr else "")
    print(f"   {name[z]:12} computed slope {ft['slope']:+.3f} r {ft['r']:.3f}  | {tag} -> {'AGREE' if abs(ft['slope']-ps)<0.03 else 'DIFFER'}")
# grazed median flood trend
gz=[z for z in zfs if not graz[z]]
yrs=sorted(set.intersection(*[set(k for k in P[z] if P[z][k][1] is not None) for z in gz]))
gmed=[float(np.median([P[z][y][1] for z in gz if y in P[z]])) for y in yrs]
gft=ols(yrs,gmed); print(f"   grazed median   computed slope {gft['slope']:+.3f} r {gft['r']:.3f}  | predicted -0.117")

# 5.6.2 Bala 29ca three numbers
b=byzf[4]
print(f"\n5.6.2 BALA 29ca THREE NUMBERS:")
print(f"   raw floor trend            {b['raw']:+.3f} pp/yr")
print(f"   within-paddock water resp  {b['wslope']:+.3f} pp cover per pp flood (r {b['wr']:.3f})")
print(f"   water-adjusted floor trend {b['adj']:+.3f} pp/yr  (SE {b['adjse']:.3f})")
print(f"   -> {100*abs(b['adj'])/abs(b['raw']):.0f}% of the raw +{b['raw']:.2f} trend survives water adjustment")

# 5.6.4 low-variance flag + lag comparison
lowvar=[d['name'] for d in rows if d['fsd']<2.0]
print(f"\n5.6.4 low flood-variance paddocks (SD<2pp), water response unreliable: {len(lowvar)} -> {lowvar[:8]}{'...' if len(lowvar)>8 else ''}")
better_lag=sum(1 for d in rows if not math.isnan(d['lag_r']) and abs(d['lag_r'])>abs(d['cur_r']))
print(f"   lag fit better than current for {better_lag}/64 paddocks (|r| lag>current)")

# reference paddocks + Dinan 10 in temporal table
print("\n5.6.3 temporal table - reference paddocks + Dinan 10:")
for z in REF+[DINAN10]:
    d=byzf[z]
    print(f"   {d['name']:12} raw {d['raw']:+.3f} wslope {d['wslope']:+.3f} adj {d['adj']:+.3f} floodSD {d['fsd']:4.1f} rank_adj {d['rank_adj']}/64 ({d['treat']})")
adjvals=[d['adj'] for d in rows]
print(f"   adjusted-trend distribution: min {min(adjvals):+.3f}  median {np.median(adjvals):+.3f}  max {max(adjvals):+.3f}")

# ---- CSVs ----
with open(OUT/"T10_gateC_crosssectional_residuals.csv","w",newline="",encoding="utf-8") as fh:
    w=csv.writer(fh); w.writerow(["zone_fid","zone_name","treatment","mean_floor","mean_flood","predicted_floor","residual","rank"])
    for z in ranked: w.writerow([z,name[z],treat[z],round(mfloor[z],2),round(mflood[z],2),round(biv['inter']+biv['slope']*mflood[z],2),round(xres[z],2),ranked.index(z)+1])
with open(OUT/"T10_gateC_temporal_table.csv","w",newline="",encoding="utf-8") as fh:
    w=csv.writer(fh); w.writerow(["zone_fid","zone_name","treatment","raw_floor_trend","within_paddock_water_slope","water_response_r","water_adjusted_floor_trend","adj_se","flood_sd","lag_r","current_r","rank_by_adjusted","n"])
    for d in rows: w.writerow([d['zf'],d['name'],d['treat'],round(d['raw'],4),round(d['wslope'],4),round(d['wr'],3),round(d['adj'],4),round(d['adjse'],4),round(d['fsd'],2),round(d['lag_r'],3),round(d['cur_r'],3),d['rank_adj'],d['n']])
print("\nCSVs written: T10_gateC_crosssectional_residuals.csv, T10_gateC_temporal_table.csv")
con.close()
