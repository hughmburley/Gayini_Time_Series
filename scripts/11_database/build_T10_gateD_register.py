#!/usr/bin/env python
"""T10 Gate D — register the annual trends, cross-sectional residuals, the temporal arm,
the per-community decomposition, and the reference-set composition into dim_headline_number.
Annotate the three PIN 3 rows as superseded (pinned_value stays NULL).

ADDITIVE: INSERT OR REPLACE keyed on number_id (idempotent-convergent); the two existing
floor_flood_* rows are re-registered per T8's recorded intent ("T10 Gate B re-registers");
the three PIN 3 rows get decision_note only, pinned_value untouched (NULL). No builder run,
no row deleted, no rename. All pinned values computed LIVE.
"""
import sqlite3, math, statistics as st
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
import sys; sys.path.insert(0,str(ROOT/"scripts"/"lib"))
from gayini_params import PIXEL_AREA_HA  # noqa
con=sqlite3.connect(DB); c=con.cursor()
name={z:n for z,n in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}
graz={z:g for z,g in c.execute("SELECT zone_fid,grazing_excluded FROM dim_management_zone")}
grazed=[z for z in name if not graz[z]]; REF=[1,2,3,4]
def ols(x,y):
    x=np.asarray(x,float);y=np.asarray(y,float);n=len(x)
    mx=x.mean();my=y.mean();sxx=((x-mx)**2).sum();sxy=((x-mx)*(y-my)).sum();syy=((y-my)**2).sum()
    slope=sxy/sxx;inter=my-slope*mx;r=sxy/math.sqrt(sxx*syy) if sxx*syy>0 else float('nan')
    resid=y-(inter+slope*x);se=math.sqrt(((resid**2).sum()/(n-2))/sxx) if n>2 and sxx>0 else float('nan')
    return dict(slope=slope,inter=inter,r=r,se=se,n=n,resid=resid)
def median(xs): return float(np.median(xs))

# ---- load series ----
P={}
for var in ('mean_of_seasons','jja_son'):
    P[var]={}
    for zf,wy,p05,ff in c.execute("SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct FROM fact_zone_veg_annual WHERE series_variant=?",(var,)):
        P[var][(zf,wy)]=(p05,ff)
YEARS=list(range(1988,2023))
def annual_gap(var,ref):
    out={}
    for y in YEARS:
        rv=[P[var][(f,y)][0] for f in ref if (f,y) in P[var] and P[var][(f,y)][0] is not None]
        gv=[P[var][(f,y)][0] for f in grazed if (f,y) in P[var] and P[var][(f,y)][0] is not None]
        if rv and gv: out[y]=sum(rv)/len(rv)-median(gv)
    return out
def trend(gapd): xs=sorted(gapd); return ols(xs,[gapd[x] for x in xs])
SETS={"A_all4":REF,"B_excl29ca":[1,2,3],"C_29ca":[4]}
gapfit={v:{k:trend(annual_gap(v,r)) for k,r in SETS.items()} for v in ('mean_of_seasons','jja_son')}

# ---- cross-sectional ----
zfs=sorted({z for (z,_) in P['mean_of_seasons']})
mfloor={z:st.mean([P['mean_of_seasons'][(z,y)][0] for y in YEARS if (z,y) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y)][0] is not None]) for z in zfs}
mflood={z:st.mean([P['mean_of_seasons'][(z,y)][1] for y in YEARS if (z,y) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y)][1] is not None]) for z in zfs}
biv=ols([mflood[z] for z in zfs],[mfloor[z] for z in zfs])
xres={z:mfloor[z]-(biv['inter']+biv['slope']*mflood[z]) for z in zfs}
# community-adjusted residual (fit2) for spread on 29ca
pix={}
for zf,cm,n in c.execute("SELECT zone_fid,community,sum(n_pixels) FROM census_by_zone_stratum WHERE treed_context_flag=0 AND zone_fid IS NOT NULL GROUP BY zone_fid,community"):
    pix.setdefault(zf,{})[cm]=n
def comm_short(z):
    cm=max(pix[z],key=pix[z].get); return 'aeolian' if cm.startswith('Aeolian') else 'riverine' if cm.startswith('Riverine') else 'inland'
X=np.array([[1.0,mflood[z],1.0 if comm_short(z)=='aeolian' else 0.0,1.0 if comm_short(z)=='riverine' else 0.0] for z in zfs])
Y=np.array([mfloor[z] for z in zfs]); beta,_,_,_=np.linalg.lstsq(X,Y,rcond=None)
i=zfs.index(4); res29_comm=Y[i]-X[i]@beta
inl=[z for z in zfs if comm_short(z)=='inland']; wi=ols([mflood[z] for z in inl],[mfloor[z] for z in inl])

# ---- temporal arm (29ca) ----
def series(z,var='mean_of_seasons'):
    ys=sorted(y for y in YEARS if (z,y) in P[var] and P[var][(z,y)][0] is not None and P[var][(z,y)][1] is not None)
    return ys,[P[var][(z,y)][0] for y in ys],[P[var][(z,y)][1] for y in ys]
def adj_trend(z,lag=0):
    ys,veg,fld=series(z)
    if lag:
        pairs=[(P['mean_of_seasons'][(z,y)][0],P['mean_of_seasons'][(z,y-1)][1],y) for y in ys if (z,y-1) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y-1)][1] is not None]
        wr=ols([p[1] for p in pairs],[p[0] for p in pairs]); yy=[p[2] for p in pairs]
        return ols(yy,list(wr['resid']))['slope']
    wr=ols(fld,veg); return ols(ys,list(wr['resid']))
ys4,veg4,fld4=series(4)
raw29=ols(ys4,veg4); wr29=ols(fld4,veg4); adj29=adj_trend(4); adj29_lag=adj_trend(4,lag=1)
flood29=ols(ys4,fld4)
# group medians of adjusted trend
adj_all={z:adj_trend(z)['slope'] for z in zfs}
ung_med=median([adj_all[z] for z in zfs if graz[z]]); grz_med=median([adj_all[z] for z in zfs if not graz[z]])

# ---- per-community decomposition (29ca) ----
CV={}
for zf,cm,wy,p05,npx in c.execute("SELECT zone_fid,community,water_year,veg_p05_spatial,n_pixels_valid FROM fact_zone_community_veg_annual WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL"):
    CV.setdefault((zf,cm),{})[wy]=p05
COMM={'Aeolian Chenopod Shrublands':'aeolian','Riverine Chenopod Shrublands':'riverine','Inland Floodplain Shrublands / Swamps':'inland'}
comm_dec={}
for cm,short in COMM.items():
    pad={z for (z,c2) in CV if c2==cm}
    lvl={z:st.mean(list(CV[(z,cm)].values())) for z in pad}
    trd={z:ols(sorted(CV[(z,cm)]),[CV[(z,cm)][y] for y in sorted(CV[(z,cm)])])['slope'] for z in pad if len(CV[(z,cm)])>=3}
    comm_dec[short]=dict(level_deficit=lvl[4]-median(list(lvl.values())),trend=trd[4],
                         rank=sorted(lvl,key=lambda z:lvl[z]).index(4)+1,npad=len(lvl))
# composition shares (Inland %)
comp={z:100*pix[z].get('Inland Floodplain Shrublands / Swamps',0)/sum(pix[z].values()) for z in REF}

# ---------------- assemble rows ----------------
DEC="T10 v2 Gate D (Gayini_T10_v2_spec.md + A1); CC 2026-07-28; design-seat predictions independently reproduced"
rows=[]
def R(nid,label,src,grain,order,var,scope,period,pinned,smin,smax,support,caveat,note):
    rows.append((nid,label,src,grain,order,var,scope,period,None,None,pinned,smin,smax,support,caveat,DEC,note))
def sp(a,b): return (min(a,b),max(a,b))
# annual trends
for k,setlab in (("A_all4","4 reference paddocks"),("B_excl29ca","3 reference (excl 29ca)"),("C_29ca","Bala 29ca alone")):
    m=gapfit['mean_of_seasons'][k]; j=gapfit['jja_son'][k]
    lo,hi=sp(m['slope'],j['slope'])
    R(f"t10_gap_annual_slope_{k}",f"Annual reference-grazed gap trend slope, {setlab}","fact_zone_veg_annual",
      "zone/annual","OLS gap on water year","mean_of_seasons","reference vs 60 grazed","1988-2022",
      round(m['slope'],3),round(lo,3),round(hi,3),"zone",f"SE {m['se']:.3f}, n {m['n']}, r {m['r']:.3f}; jja_son {j['slope']:+.3f}. No p-value (serial corr).",
      "T10 Gate B annual series; supersedes the scriptless five-period table (I-29).")
    rlo,rhi=sp(m['r'],j['r'])
    R(f"t10_gap_annual_r_{k}",f"Annual reference-grazed gap trend r, {setlab}","fact_zone_veg_annual",
      "zone/annual","Pearson r of gap on year","mean_of_seasons","reference vs 60 grazed","1988-2022",
      round(m['r'],3),round(rlo,3),round(rhi,3),"zone",f"jja_son r {j['r']:.3f}.",
      "B is flat (r 0.222): the convergence is a single-paddock artefact.")
# chosen regression (re-register existing floor_flood_* with alt-fit spread; T8 flagged for T10)
def UPD(nid,smin,smax,note_add):
    row=c.execute("SELECT pinned_value,caveat,decision_note FROM dim_headline_number WHERE number_id=?",(nid,)).fetchone()
    c.execute("UPDATE dim_headline_number SET spread_min=?,spread_max=?,decision_note=? WHERE number_id=?",
              (smin,smax,(row[2] or "")+" | "+note_add,nid))
# cross-sectional residuals
R("t10_bala29ca_xsec_residual","Bala 29ca cross-sectional floor residual (bivariate)","fact_zone_veg_annual",
  "paddock","observed - predicted floor (bivariate floor~flood)","mean_of_seasons","64 paddocks","1988-2022",
  round(xres[4],1),round(min(res29_comm,xres[4]),1),round(max(res29_comm,xres[4]),1),"paddock",
  f"rank 2/64; residual SD 6.67. Community-adjusted alt {res29_comm:+.1f}. vs raw -42.3 gap -> {100*abs(xres[4])/42.3:.0f}% survives.",
  "5.4a; bivariate chosen (5.2: Bala 29ca has no dominant community).")
R("t10_dinan10_xsec_residual","Dinan 10 cross-sectional floor residual (bivariate)","fact_zone_veg_annual",
  "paddock","observed - predicted floor","mean_of_seasons","64 paddocks","1988-2022",
  round(xres[57],1),round(xres[57],1),round(xres[57],1),"paddock",
  "rank 3/64; grazed. Bala 29ca's cross-sectional wetness-twin (-16.8 vs -15.1).","5.3.")
# temporal arm
R("t10_bala29ca_water_adjusted_floor_trend","Bala 29ca water-adjusted floor trend","fact_zone_veg_annual",
  "paddock/annual","residuals of floor~flood, regressed on year","mean_of_seasons","Bala 29ca, 35 yr","1988-2022",
  round(adj29['slope'],3),round(min(adj29['slope'],adj29_lag),3),round(max(adj29['slope'],adj29_lag),3),"paddock",
  f"SE {adj29['se']:.3f}; lagged spec {adj29_lag:+.3f}. 82% of raw +{raw29['slope']:.2f} survives. THE number that decides the claim.",
  "A1 5.6.2: recovery is not hydrological -> historical-disturbance reading survives; Ernest decisive.")
R("t10_bala29ca_raw_floor_trend","Bala 29ca raw floor trend","fact_zone_veg_annual","paddock/annual","OLS floor on year",
  "mean_of_seasons","Bala 29ca","1988-2022",round(raw29['slope'],3),round(raw29['slope'],3),round(raw29['slope'],3),"paddock",
  f"SE {raw29['se']:.3f}, r {raw29['r']:.3f}. Paddock's own floor; series-C gap slope +0.919 differs (grazed median floor declines).","context for the adjusted trend.")
R("t10_bala29ca_within_paddock_water_slope","Bala 29ca within-paddock water response","fact_zone_veg_annual","paddock/annual","OLS floor on same-year flood",
  "mean_of_seasons","Bala 29ca","1988-2022",round(wr29['slope'],3),round(wr29['slope'],3),round(wr29['slope'],3),"paddock",
  f"r {wr29['r']:.3f}. Within-paddock, distinct from the 64-paddock cross-sectional +0.548.","context.")
R("t10_bala29ca_flood_trend","Bala 29ca flood-frequency trend","fact_zone_veg_annual","paddock/annual","OLS flood on year",
  "mean_of_seasons","Bala 29ca","1988-2022",round(flood29['slope'],3),round(flood29['slope'],3),round(flood29['slope'],3),"paddock",
  f"r {flood29['r']:.3f}. Only reference paddock getting wetter, but weakly.","A1 prediction reproduced.")
# per-community decomposition
for short,d in comm_dec.items():
    R(f"t10_bala29ca_{short}_floor_trend",f"Bala 29ca floor trend within {short}","fact_zone_community_veg_annual",
      "paddock-community/annual","OLS floor on year (min 30 px/cell)","mean_of_seasons",f"Bala 29ca {short} cells","1988-2022",
      round(d['trend'],3),round(d['trend'],3),round(d['trend'],3),"stratum",f"rank {d['rank']}/{d['npad']} on level.","A1 5.6: recovery located in the dry (Aeolian/Riverine) thirds.")
    R(f"t10_bala29ca_{short}_level_deficit",f"Bala 29ca floor level vs {short} community median","fact_zone_community_veg_annual",
      "paddock-community","mean floor minus community median","mean_of_seasons",f"Bala 29ca {short}","1988-2022",
      round(d['level_deficit'],1),round(d['level_deficit'],1),round(d['level_deficit'],1),"stratum",f"rank {d['rank']}/{d['npad']}.","A1 5.6.")
# group medians + composition
R("t10_ungrazed_median_adj_trend","Ungrazed median water-adjusted floor trend","fact_zone_veg_annual","paddock/annual","median of per-paddock adjusted trends",
  "mean_of_seasons","4 ungrazed","1988-2022",round(ung_med,3),round(ung_med,3),round(ung_med,3),"paddock",
  f"within-ungrazed range -0.337..+0.556; read the -0.14 between-group gap against this spread.","addition 3.")
R("t10_grazed_median_adj_trend","Grazed median water-adjusted floor trend","fact_zone_veg_annual","paddock/annual","median of per-paddock adjusted trends",
  "mean_of_seasons","60 grazed","1988-2022",round(grz_med,3),round(grz_med,3),round(grz_med,3),"paddock",
  "strongest improver-beyond-water is Bala 15 (grazed, +0.646), not a reference paddock.","addition 2/3.")
for z in REF:
    R(f"t10_refset_inland_share_{name[z].lower().replace(' ','')}",f"{name[z]} Inland-community pixel share","census_by_zone_stratum",
      "paddock","sum(n_pixels) Inland / total non-treed","n/a",f"{name[z]} non-treed","n/a",
      round(comp[z],1),round(comp[z],1),round(comp[z],1),"pixel",
      f"3 of 4 reference paddocks are ~entirely Inland (highest-floor community, median 73.1); only Bala 29ca (34.6%) spans the range.","reference-set composition.")

# ---- write ----
c.executemany("""INSERT OR REPLACE INTO dim_headline_number
 (number_id,label,source_object,grain,aggregation_order,series_variant,scope_filter,period_label,
  denominator,pixel_constant,pinned_value,spread_min,spread_max,support_level,caveat,decided_by,decision_note)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
# re-register chosen regression with alt-fit spread
UPD("floor_flood_slope_64pdk",round(min(biv['slope'],beta[1],wi['slope']),3),round(max(biv['slope'],beta[1],wi['slope']),3),
    "T10 Gate C: chosen bivariate; alts +community flood coef %.3f, within-Inland %.3f."%(beta[1],wi['slope']))
UPD("floor_flood_r_64pdk",round(min(biv['r'],wi['r']),3),round(max(biv['r'],wi['r']),3),
    "T10 Gate C: within-Inland r %.3f."%wi['r'])
# annotate PIN 3 rows (pinned_value stays NULL)
PIN3={"bala29ca_floor_gap_periodwise":"t10_gap_annual_slope_C_29ca",
      "bala29ca_floor_gap_periodwise_jja_son":"t10_gap_annual_slope_C_29ca",
      "ref_grazed_floor_gap_3pdk_periodwise":"t10_gap_annual_slope_B_excl29ca"}
for nid,sup in PIN3.items():
    c.execute("UPDATE dim_headline_number SET decision_note=? WHERE number_id=? AND pinned_value IS NULL",
              (f"BLOCKED on I-29; SUPERSEDED by T10 Gate B annual trend {sup}. Not to be revived.",nid))
con.commit()
# ---- verify ----
print("dim_headline_number rows now:",c.execute("SELECT count(*) FROM dim_headline_number").fetchone()[0])
print("  T10 rows added:",c.execute("SELECT count(*) FROM dim_headline_number WHERE number_id LIKE 't10_%'").fetchone()[0])
print("  PIN3 still NULL & annotated:",c.execute("SELECT count(*) FROM dim_headline_number WHERE pinned_value IS NULL AND decision_note LIKE '%SUPERSEDED%'").fetchone()[0],"/3")
print("  floor_flood spreads:",c.execute("SELECT number_id,pinned_value,spread_min,spread_max FROM dim_headline_number WHERE number_id LIKE 'floor_flood%'").fetchall())
print("  key row:",c.execute("SELECT number_id,pinned_value,spread_min,spread_max FROM dim_headline_number WHERE number_id='t10_bala29ca_water_adjusted_floor_trend'").fetchone())
con.close(); print("DONE")
