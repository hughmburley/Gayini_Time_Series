#!/usr/bin/env python
"""T8 Gate C — reproduction test for dim_headline_number.

For every pinned row, RE-DERIVE the value from its source_object under the recorded
qualifiers (independent code path from the builder) and assert it equals pinned_value
within tolerance. Blocked rows (pinned_value NULL, PIN 3) are skipped by design.

Drift guard: fails loudly when a figure drifts from the data that produced it.
Run:  python scripts/11_database/test_T8_headline_reproduction.py [db_path]
Exit 0 = all reproduce; exit 1 = at least one drifted.

Proving it can fail (CLAUDE.md 'every check must be able to fail'):
  --break  copies the DB to a temp file, corrupts one pinned_value by +5, and runs the
           test against the copy; the corrupted row MUST report DRIFT. Real DB untouched.
"""
import sqlite3, statistics as st, sys, shutil, tempfile, os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from gayini_params import PIXEL_AREA_HA, MAPPED_AREA_HA, TRUE_FARM_HA
PX, MAPPED, FARM = PIXEL_AREA_HA, MAPPED_AREA_HA, TRUE_FARM_HA

def recompute(c):
    """Return {number_id: recomputed_value} for every reproducible pinned row."""
    grazed=[r[0] for r in c.execute("SELECT zone_fid FROM dim_management_zone WHERE grazing_excluded=0")]
    F={}
    for zf,wy,var,p05,med,ff in c.execute(
        "SELECT zone_fid,water_year,series_variant,veg_p05_spatial,veg_median,flood_frac_pct FROM fact_zone_veg_annual"):
        F.setdefault(var,{})[(zf,wy)]=(p05,med,ff)
    def gap(var,lo,hi,ref):
        r={};g={}
        for (zf,wy),v in F[var].items():
            if lo<=wy<=hi and v[0] is not None:
                (r if zf in ref else (g if zf in grazed else {})).setdefault(wy,[]).append(v[0])
        yrs=sorted(set(r)&set(g))
        return st.mean([st.mean(r[y]) for y in yrs])-st.mean([st.median(g[y]) for y in yrs])
    def pmean(f,col):
        xs=[F['mean_of_seasons'][(f,y)][col] for y in range(1988,2023)
            if F['mean_of_seasons'].get((f,y),(None,None,None))[col] is not None]
        return st.mean(xs) if xs else None
    AREA={(cm,b):ha for cm,b,ha in c.execute(
        "SELECT community,regime_band,sum(area_ha) FROM census_by_zone_stratum "
        "WHERE treed_context_flag=0 AND regime_band IN ('low','mid','high') GROUP BY community,regime_band")}
    def defs(col,arm):
        return {(cm,b):v for cm,b,v in c.execute(
            f"SELECT community,regime_band,{col} FROM v_three_arm_gap_decomposition "
            f"WHERE treatment_arm=? AND window='all' AND regime_band IN ('low','mid','high')",(arm,))}
    def aw(d,keys): return sum(d[k]*AREA[k] for k in keys)/sum(AREA[k] for k in keys)
    SH={'aeolian':'Aeolian Chenopod Shrublands','riverine':'Riverine Chenopod Shrublands','inland':'Inland Floodplain Shrublands / Swamps'}
    def ckeys(cm): return [(cm,b) for b in ('low','mid','high')]
    NINE=[(cm,b) for cm in SH.values() for b in ('low','mid','high')]
    out={}
    out["ref_grazed_floor_gap_4pdk_1988_92"]=round(gap("mean_of_seasons",1988,1992,[1,2,3,4]),2)
    out["bala29ca_ref_plot_share_pct"]=round(100*c.execute("SELECT count(*) FROM plot_paddock WHERE zone_fid=4").fetchone()[0]/
                                             c.execute("SELECT count(*) FROM plot_paddock WHERE grazing_excluded=1").fetchone()[0],2)
    for tag,cm in SH.items():
        out[f"ref_grazed_mean_cover_{tag}"]=round(aw(defs('mean_deficit_pp','not_grazed'),ckeys(cm)),2)
        out[f"ref_grazed_floor_{tag}"]=round(aw(defs('floor_deficit_pp','not_grazed'),ckeys(cm)),2)
    for arm,short in (('not_grazed','not_grazed'),('unzoned_inferred_standard','unzoned_inferred'),('unzoned_plot_confirmed','unzoned_plot')):
        out[f"three_arm_floor_deficit_{short}"]=round(aw(defs('floor_deficit_pp',arm),NINE),2)
    for arm,short in (('unzoned_inferred_standard','unzoned_inferred'),('unzoned_plot_confirmed','unzoned_plot')):
        out[f"three_arm_{short}_above_14day_count"]=float(c.execute(
            "SELECT sum(CASE WHEN floor_deficit_pp>0 THEN 1 ELSE 0 END) FROM v_three_arm_gap_decomposition "
            "WHERE treatment_arm=? AND window='all' AND regime_band<>'ALL'",(arm,)).fetchone()[0])
    out["bala29ca_median_cover"]=round(pmean(4,1),1)
    out["bala29ca_mean_flood_freq"]=round(st.mean([F['mean_of_seasons'][(4,y)][2] for y in range(1988,2023)
        if F['mean_of_seasons'].get((4,y),(None,None,None))[2] is not None]),1)
    for band,delta in c.execute("SELECT regime_band,veg_p05_delta FROM v_zone_stratum_treatment_contrast WHERE community LIKE 'Riverine%'"):
        out[f"t1_riverine_contrast_{band}"]=round(delta,2)
    for band,delta in c.execute("SELECT regime_band,veg_p05_delta_zonesupport FROM v_zone_stratum_contrast_bala_robust WHERE community LIKE 'Riverine%'"):
        out[f"t1_riverine_contrast_bala_{band}"]=round(delta,2)
    inv={v:k for k,v in SH.items()}
    for fc,tag in (("all","all"),("non_flood","non_flood")):
        for cm,v in c.execute("SELECT community,gap_change_pp FROM v_reference_gap_decomposition WHERE window='all' AND flood_class=?",(fc,)):
            out[f"gap_change_{tag}_{inv[cm]}"]=round(v,1)
    X=[];Y=[]
    for f in range(1,65):
        fx=pmean(f,2); fy=pmean(f,0)
        if fx is not None and fy is not None: X.append(fx);Y.append(fy)
    mx=st.mean(X);my=st.mean(Y);sxx=sum((x-mx)**2 for x in X);sxy=sum((x-mx)*(y-my) for x,y in zip(X,Y));syy=sum((y-my)**2 for y in Y)
    out["floor_flood_slope_64pdk"]=round(sxy/sxx,6)   # repinned at 6 dp 2026-07-31 (precision correction)
    out["floor_flood_r_64pdk"]=round(sxy/(sxx*syy)**0.5,3)
    npx=c.execute("SELECT sum(n_pixels) FROM census_by_zone_stratum WHERE zone_fid IS NULL").fetchone()[0]
    out["unzoned_inside_mapped_ha"]=round(npx*PX,1)
    out["property_outside_mapped_ha"]=round(FARM-MAPPED,1)
    out["total_no_management_zone_ha"]=round(npx*PX+(FARM-MAPPED),1)
    return out

def _ols(x,y):
    import numpy as _np, math as _m
    x=_np.asarray(x,float);y=_np.asarray(y,float);n=len(x)
    mx=x.mean();my=y.mean();sxx=((x-mx)**2).sum();sxy=((x-mx)*(y-my)).sum();syy=((y-my)**2).sum()
    slope=sxy/sxx;inter=my-slope*mx;r=sxy/_m.sqrt(sxx*syy) if sxx*syy>0 else float('nan')
    resid=y-(inter+slope*x)
    return slope,inter,r,resid

def recompute_t10(c):
    """Independent re-derivation of the T10 Gate B/C/D rows (drift guard)."""
    import numpy as np, statistics as st
    graz={z:g for z,g in c.execute("SELECT zone_fid,grazing_excluded FROM dim_management_zone")}
    name={z:n for z,n in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}
    grazed=[z for z in graz if not graz[z]]; REF=[1,2,3,4]; YEARS=list(range(1988,2023))
    P={v:{} for v in ('mean_of_seasons','jja_son')}
    for zf,wy,p05,ff,var in c.execute("SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct,series_variant FROM fact_zone_veg_annual"):
        P[var][(zf,wy)]=(p05,ff)
    med=lambda xs: float(np.median(xs))
    def gaptrend(var,ref):
        g={}
        for y in YEARS:
            rv=[P[var][(f,y)][0] for f in ref if (f,y) in P[var] and P[var][(f,y)][0] is not None]
            gv=[P[var][(f,y)][0] for f in grazed if (f,y) in P[var] and P[var][(f,y)][0] is not None]
            if rv and gv: g[y]=sum(rv)/len(rv)-med(gv)
        xs=sorted(g); s,_,r,_=_ols(xs,[g[x] for x in xs]); return s,r
    out={}
    for k,ref in (("A_all4",REF),("B_excl29ca",[1,2,3]),("C_29ca",[4])):
        s,r=gaptrend('mean_of_seasons',ref)
        out[f"t10_gap_annual_slope_{k}"]=round(s,3); out[f"t10_gap_annual_r_{k}"]=round(r,3)
    zfs=sorted({z for (z,_) in P['mean_of_seasons']})
    mfloor={z:st.mean([P['mean_of_seasons'][(z,y)][0] for y in YEARS if (z,y) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y)][0] is not None]) for z in zfs}
    mflood={z:st.mean([P['mean_of_seasons'][(z,y)][1] for y in YEARS if (z,y) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y)][1] is not None]) for z in zfs}
    bs,bi,_,_=_ols([mflood[z] for z in zfs],[mfloor[z] for z in zfs])
    out["t10_bala29ca_xsec_residual"]=round(mfloor[4]-(bi+bs*mflood[4]),1)
    out["t10_dinan10_xsec_residual"]=round(mfloor[57]-(bi+bs*mflood[57]),1)
    def sers(z):
        ys=sorted(y for y in YEARS if (z,y) in P['mean_of_seasons'] and P['mean_of_seasons'][(z,y)][0] is not None and P['mean_of_seasons'][(z,y)][1] is not None)
        return ys,[P['mean_of_seasons'][(z,y)][0] for y in ys],[P['mean_of_seasons'][(z,y)][1] for y in ys]
    def adjt(z):
        ys,veg,fld=sers(z); _,_,_,res=_ols(fld,veg); s,_,_,_=_ols(ys,list(res)); return s
    ys4,veg4,fld4=sers(4)
    out["t10_bala29ca_raw_floor_trend"]=round(_ols(ys4,veg4)[0],3)
    out["t10_bala29ca_within_paddock_water_slope"]=round(_ols(fld4,veg4)[0],3)
    out["t10_bala29ca_flood_trend"]=round(_ols(ys4,fld4)[0],3)
    out["t10_bala29ca_water_adjusted_floor_trend"]=round(adjt(4),3)
    out["t10_ungrazed_median_adj_trend"]=round(med([adjt(z) for z in zfs if graz[z]]),3)
    out["t10_grazed_median_adj_trend"]=round(med([adjt(z) for z in zfs if not graz[z]]),3)
    CV={}
    for zf,cm,wy,p05,npx in c.execute("SELECT zone_fid,community,water_year,veg_p05_spatial,n_pixels_valid FROM fact_zone_community_veg_annual WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL"):
        CV.setdefault((zf,cm),{})[wy]=p05
    for cm,short in (('Aeolian Chenopod Shrublands','aeolian'),('Riverine Chenopod Shrublands','riverine'),('Inland Floodplain Shrublands / Swamps','inland')):
        pad={z for (z,c2) in CV if c2==cm}
        lvl={z:st.mean(list(CV[(z,cm)].values())) for z in pad}
        trd={z:_ols(sorted(CV[(z,cm)]),[CV[(z,cm)][y] for y in sorted(CV[(z,cm)])])[0] for z in pad if len(CV[(z,cm)])>=3}
        out[f"t10_bala29ca_{short}_floor_trend"]=round(trd[4],3)
        out[f"t10_bala29ca_{short}_level_deficit"]=round(lvl[4]-med(list(lvl.values())),1)
    pix={}
    for zf,cm,n in c.execute("SELECT zone_fid,community,sum(n_pixels) FROM census_by_zone_stratum WHERE treed_context_flag=0 AND zone_fid IN (1,2,3,4) GROUP BY zone_fid,community"):
        pix.setdefault(zf,{})[cm]=n
    for z in REF:
        out[f"t10_refset_inland_share_{name[z].lower().replace(' ','')}"]=round(100*pix[z].get('Inland Floodplain Shrublands / Swamps',0)/sum(pix[z].values()),1)
    return out

def recompute_reg1(c):
    """REG-1 Gate B rows: expectation-line intercept, descriptive residual SD (ddof=0),
    regression residual standard error (ddof=2), from the 64-paddock floor~flood fit."""
    import numpy as np, statistics as st, math
    P={}
    for zf,wy,p05,ff in c.execute("SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'"):
        P.setdefault(zf,{})[wy]=(p05,ff)
    zfs=sorted(P)
    X=np.array([st.mean([P[z][y][1] for y in P[z] if P[z][y][1] is not None]) for z in zfs])
    Y=np.array([st.mean([P[z][y][0] for y in P[z] if P[z][y][0] is not None]) for z in zfs])
    n=len(X);mx=X.mean();my=Y.mean();sxx=((X-mx)**2).sum();slope=((X-mx)*(Y-my)).sum()/sxx
    inter=my-slope*mx;resid=Y-(inter+slope*X);sse=(resid**2).sum()
    return {"floor_flood_intercept_64pdk":round(inter,6),   # repinned at 6 dp 2026-07-31
            "floor_flood_residual_sd_64pdk":round(resid.std(ddof=0),4),
            "floor_flood_rse_64pdk":round(math.sqrt(sse/(n-2)),4)}

def recompute_reg2(c):
    """REG-2 dominance counts (denom A) + n_parts_supported distribution, re-derived
    independently of v_zone_community_composition (from census_by_zone_stratum and
    fact_zone_community_part_summary)."""
    from collections import defaultdict
    pad=defaultdict(dict)
    for zf,cm,n in c.execute("SELECT zone_fid,community,SUM(n_pixels) FROM census_by_zone_stratum "
                             "WHERE zone_fid IS NOT NULL AND treed_context_flag=0 AND regime_band<>'context' "
                             "GROUP BY zone_fid,community"):
        pad[zf][cm]=n
    dom={zf:100*max(d.values())/sum(d.values()) for zf,d in pad.items() if sum(d.values())>0}
    ncomm={zf:sum(1 for v in d.values() if v>0) for zf,d in pad.items()}
    parts={}
    for zf,cnt in c.execute("SELECT zone_fid,COUNT(*) FROM fact_zone_community_part_summary GROUP BY zone_fid"):
        parts[cnt]=parts.get(cnt,0)+1
    return {
        "reg2_paddocks_lt75_dominance": float(sum(1 for zf in dom if dom[zf]<75)),
        "reg2_paddocks_lt60_dominance": float(sum(1 for zf in dom if dom[zf]<60)),
        "reg2_paddocks_single_community": float(sum(1 for zf in ncomm if ncomm[zf]==1)),
        "reg2_paddocks_1part_supported": float(parts.get(1,0)),
        "reg2_paddocks_2part_supported": float(parts.get(2,0)),
        "reg2_paddocks_3part_supported": float(parts.get(3,0)),
    }

def recompute_t13(c):
    """T13 state counts, re-derived by APPLYING THE RULE to the stored continuous measures
    rather than counting the stored state column. Counting state_registered would only prove
    the table agrees with itself; this re-runs spec v1 section 5 over level_z/trend_z, so it
    catches a mislabelled state as well as a drifted count."""
    CUT=1.0
    def classify(lz,tz,cut):
        if lz<=-cut: return "Recovering" if tz>=cut else "Persistently poor"
        return "Declining" if tz<=-cut else "Unremarkable"
    rows=list(c.execute("SELECT level_z,trend_z FROM fact_zone_community_part_classification"))
    if not rows: return {}
    n={s:0 for s in ("Recovering","Persistently poor","Declining","Unremarkable")}
    flat=fall=0
    for lz,tz in rows:
        s=classify(lz,tz,CUT); n[s]+=1
        if s=="Persistently poor":
            if tz<=-CUT: fall+=1
            else: flat+=1
    return {"t13_parts_recovering_count":float(n["Recovering"]),
            "t13_parts_persistently_poor_count":float(n["Persistently poor"]),
            "t13_parts_declining_count":float(n["Declining"]),
            "t13_parts_unremarkable_count":float(n["Unremarkable"]),
            "t13_parts_low_and_flat_count":float(flat),
            "t13_parts_low_and_falling_count":float(fall)}

def recompute_rptscope_r2(c):
    """RPT-SCOPE R2 pins. Each route is INDEPENDENT of the query that produced the pin -
    different source object, different aggregation, or a separately-built artefact that could
    have drifted. The three R2 pins with no independent route are deliberately absent."""
    import statistics as _st, csv as _csv
    out={}
    S={}
    for zf,wy,p05 in c.execute("SELECT zone_fid,water_year,veg_p05_spatial FROM fact_zone_veg_annual "
                               "WHERE series_variant='mean_of_seasons' AND veg_p05_spatial IS NOT NULL"):
        S.setdefault(wy,{})[zf]=p05
    # (a) via the separately-built T10 series artefact, not the DB
    g=[float(r["gap_pp"]) for r in _csv.DictReader(
        open(ROOT/"Output"/"tables"/"T10_annual_gap_series.csv",encoding="utf-8"))
        if r["series_variant"]=="mean_of_seasons" and r["series"]=="B_excl29ca"]
    if g: out["ref_grazed_gap_annual_ref3_excl29ca_mean"]=round(_st.mean(g),3)
    # (e) OLS re-run from fact_zone_veg_annual rather than the T10 temporal table
    yrs=sorted(wy for wy in S if 4 in S[wy]); veg=[S[wy][4] for wy in yrs]
    fl=dict(c.execute("SELECT water_year,flood_frac_pct FROM fact_zone_veg_annual "
                      "WHERE zone_fid=4 AND series_variant='mean_of_seasons'"))
    def _ols(x,y):
        mx=_st.mean(x); my=_st.mean(y)
        sxx=sum((a-mx)**2 for a in x); sxy=sum((a-mx)*(b-my) for a,b in zip(x,y)); sl=sxy/sxx
        return sl,[b-(my-sl*mx+sl*a) for a,b in zip(x,y)]
    raw,_=_ols(yrs,veg); _,wres=_ols([fl[w] for w in yrs],veg); adj,_=_ols(yrs,wres)
    out["bala29ca_improvement_surviving_water_pct"]=round(100*adj/raw,1)
    # (f) ranks by mean-of-years, not the view's stored mean_flood
    mf={}
    for zf,ff in c.execute("SELECT zone_fid,flood_frac_pct FROM fact_zone_veg_annual "
                           "WHERE series_variant='mean_of_seasons' AND flood_frac_pct IS NOT NULL"):
        mf.setdefault(zf,[]).append(ff)
    nm=dict(c.execute("SELECT zone_fid,zone_name FROM dim_management_zone"))
    order=sorted(((nm[z],_st.mean(v)) for z,v in mf.items()),key=lambda kv:-kv[1])
    rk={n:i+1 for i,(n,_) in enumerate(order)}
    for z,k in (("Bala 26ca","bala26ca"),("Bala 27ca","bala27ca"),
                ("Bala 28ca","bala28ca"),("Bala 29ca","bala29ca")):
        out[f"ref_paddock_flood_rank_{k}"]=float(rk[z])
    # (g) residual from the pinned constants and own means, not the view's stored residual
    I,SL=[c.execute("SELECT pinned_value FROM dim_headline_number WHERE number_id=?",(n,)).fetchone()[0]
          for n in ("floor_flood_intercept_64pdk","floor_flood_slope_64pdk")]
    z15=[k for k,v in nm.items() if v=="Bala 15"][0]
    f15=_st.mean(mf[z15]); v15=_st.mean([S[wy][z15] for wy in S if z15 in S[wy]])
    out["bala15_xsec_residual"]=round(v15-(I+SL*f15),2)
    # ---- Ruling E canaries. These run the EXACT SQL the contract hands the report builder, so a
    # drift in the parameterised DEFINITION fails here rather than silently in 32 documents.
    out["rptscope_canary_p1_paddock_floor_bala29ca"]=round(c.execute(
        "SELECT AVG(veg_p05_spatial) FROM fact_zone_veg_annual WHERE zone_fid = 4 "
        "AND series_variant = 'mean_of_seasons' AND water_year BETWEEN 1988 AND 2022").fetchone()[0],2)
    out["rptscope_canary_p5_recovering_parts_bala29ca"]=float(c.execute(
        "SELECT COUNT(*) FROM fact_zone_community_part_classification "
        "WHERE zone_fid = 4 AND state_registered = 'Recovering'").fetchone()[0])
    return out

def run(db):
    con=sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro",uri=True); c=con.cursor()
    pinned={nid:(pv,unit_tol(nid)) for nid,pv in c.execute(
        "SELECT number_id,pinned_value FROM dim_headline_number WHERE pinned_value IS NOT NULL")}
    rc=recompute(c); rc.update(recompute_t10(c)); rc.update(recompute_reg1(c)); rc.update(recompute_reg2(c)); rc.update(recompute_t13(c)); rc.update(recompute_rptscope_r2(c))
    fails=[]; checked=0
    for nid,(pv,tol) in pinned.items():
        if nid not in rc:
            fails.append((nid,pv,"NOT RECOMPUTED")); continue
        checked+=1
        if abs(rc[nid]-pv)>tol:
            fails.append((nid,pv,rc[nid]))
    con.close()
    return checked,fails

def unit_tol(nid):
    if nid.endswith("_ha"): return 1.0          # area in ha
    if nid.endswith("_count"): return 0.0       # exact
    # these two are pinned at 6 dp (precision correction 2026-07-31), so the tolerance that was
    # tuned to the rounded values would no longer test the precision it now stores
    if nid in ("floor_flood_slope_64pdk","floor_flood_intercept_64pdk"): return 5e-6
    if nid.startswith("floor_flood_"): return 0.005
    return 0.05                                  # pp / percent

if __name__=="__main__":
    args=sys.argv[1:]
    if "--break" in args:
        real=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
        tmp=Path(tempfile.mkdtemp())/"broken.sqlite"; shutil.copy2(real,tmp)
        b=sqlite3.connect(tmp); b.execute("UPDATE dim_headline_number SET pinned_value=pinned_value+5 WHERE number_id='ref_grazed_floor_gap_4pdk_1988_92'"); b.commit(); b.close()
        n,fails=run(tmp)
        print(f"[--break fixture] checked {n}; DRIFT rows: {len(fails)}")
        for nid,pv,got in fails: print(f"   DRIFT  {nid}: pinned={pv} recomputed={got}")
        os.remove(tmp)
        sys.exit(0 if fails else 2)   # we EXPECT a failure here; exit 2 if the check failed to fire
    db=args[0] if args else ROOT/"Output"/"database"/"Gayini_Results.sqlite"
    n,fails=run(db)
    if fails:
        print(f"T8 reproduction: {len(fails)} DRIFTED of {n} checked")
        for nid,pv,got in fails: print(f"   DRIFT  {nid}: pinned={pv} recomputed={got}")
        sys.exit(1)
    print(f"T8 reproduction: PASS - all {n} pinned numbers reproduce within tolerance")
    sys.exit(0)
