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
    out["floor_flood_slope_64pdk"]=round(sxy/sxx,3)
    out["floor_flood_r_64pdk"]=round(sxy/(sxx*syy)**0.5,3)
    npx=c.execute("SELECT sum(n_pixels) FROM census_by_zone_stratum WHERE zone_fid IS NULL").fetchone()[0]
    out["unzoned_inside_mapped_ha"]=round(npx*PX,1)
    out["property_outside_mapped_ha"]=round(FARM-MAPPED,1)
    out["total_no_management_zone_ha"]=round(npx*PX+(FARM-MAPPED),1)
    return out

def run(db):
    con=sqlite3.connect(f"file:{Path(db).as_posix()}?mode=ro",uri=True); c=con.cursor()
    pinned={nid:(pv,unit_tol(nid)) for nid,pv in c.execute(
        "SELECT number_id,pinned_value FROM dim_headline_number WHERE pinned_value IS NOT NULL")}
    rc=recompute(c)
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
