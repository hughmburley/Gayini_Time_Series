#!/usr/bin/env python
"""REG-1 Gate B — register the expectation-line intercept, the descriptive residual SD, and
the regression residual standard error (3 rows, per the design-seat residual-SD ruling).
ADDITIVE: INSERT OR REPLACE keyed on number_id. No builder run, no row deleted, no rename.
All values computed live."""
import sqlite3, math, statistics as st
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
import sys; sys.path.insert(0,str(ROOT/"scripts"/"lib"))
from gayini_params import PIXEL_AREA_HA  # noqa
con=sqlite3.connect(DB); c=con.cursor()

P={}
for zf,wy,p05,ff in c.execute("SELECT zone_fid,water_year,veg_p05_spatial,flood_frac_pct FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'"):
    P.setdefault(zf,{})[wy]=(p05,ff)
zfs=sorted(P)
mfloor={z:st.mean([P[z][y][0] for y in P[z] if P[z][y][0] is not None]) for z in zfs}
mflood={z:st.mean([P[z][y][1] for y in P[z] if P[z][y][1] is not None]) for z in zfs}
X=np.array([mflood[z] for z in zfs]); Y=np.array([mfloor[z] for z in zfs]); n=len(X)
mx=X.mean();my=Y.mean();sxx=((X-mx)**2).sum();sxy=((X-mx)*(Y-my)).sum()
slope=sxy/sxx; intercept=my-slope*mx
resid=Y-(intercept+slope*X); sse=(resid**2).sum()
sd0=resid.std(ddof=0); sd1=resid.std(ddof=1); rse=math.sqrt(sse/(n-2))
# alt-fit intercepts for the spread
pix={}
for zf,cm,nn in c.execute("SELECT zone_fid,community,sum(n_pixels) FROM census_by_zone_stratum WHERE treed_context_flag=0 AND zone_fid IS NOT NULL GROUP BY zone_fid,community"):
    pix.setdefault(zf,{})[cm]=nn
def cshort(z): cm=max(pix[z],key=pix[z].get); return 'aeolian' if cm.startswith('Aeolian') else 'riverine' if cm.startswith('Riverine') else 'inland'
Xc=np.array([[1.0,mflood[z],1.0 if cshort(z)=='aeolian' else 0.0,1.0 if cshort(z)=='riverine' else 0.0] for z in zfs])
beta,_,_,_=np.linalg.lstsq(Xc,Y,rcond=None); int_comm=beta[0]
inl=[z for z in zfs if cshort(z)=='inland']; Xi=np.array([mflood[z] for z in inl]); Yi=np.array([mfloor[z] for z in inl])
si=((Xi-Xi.mean())*(Yi-Yi.mean())).sum()/((Xi-Xi.mean())**2).sum(); int_inl=Yi.mean()-si*Xi.mean()
ints=[intercept,int_comm,int_inl]
# Bala 29ca residual and SD-normalised distances
res29=mfloor[4]-(intercept+slope*mflood[4])
d0,d1,d2=abs(res29)/sd0,abs(res29)/sd1,abs(res29)/rse
print(f"intercept bivariate {intercept:.4f} | +community {int_comm:.4f} | within-Inland {int_inl:.4f}")
print(f"residual SD ddof0 {sd0:.4f}  ddof1 {sd1:.4f}  RSE ddof2 {rse:.4f}")
print(f"Bala 29ca residual {res29:.2f}; SD below expectation: ddof0 {d0:.2f}, ddof1 {d1:.2f}, ddof2 {d2:.2f}")

DEC="REG-1 Gate B (Gayini_REG1_REG2_spec.md); design-seat residual-SD ruling; CC 2026-07-29"
SCOPE="series_variant='mean_of_seasons'; all 64 zones"
rows=[
 ("floor_flood_intercept_64pdk","Expectation-line intercept, paddock floor on mean annual inundation",
  "fact_zone_veg_annual","paddock (64), 35-year means","paddock mean then OLS across paddocks","mean_of_seasons",
  SCOPE,"1988-2022","64 paddocks",PIXEL_AREA_HA,round(intercept,4),round(min(ints),4),round(max(ints),4),"paddock",
  f"alt-fit intercepts: bivariate {intercept:.4f}, +community {int_comm:.4f}, within-Inland {int_inl:.4f}.",DEC,
  "Companion to floor_flood_slope_64pdk. Together they draw the expectation line on paddock report page 4. Predicted floor = intercept + slope * flood_frac_pct."),
 ("floor_flood_residual_sd_64pdk","Descriptive residual SD of the 64-paddock floor~flood fit (population, ddof=0)",
  "fact_zone_veg_annual","paddock (64)","population SD of the 64 residuals","mean_of_seasons",
  SCOPE,"1988-2022","64 paddocks",PIXEL_AREA_HA,round(sd0,4),round(sd0,4),round(sd0,4),"paddock",
  f"ddof=0: the 64 paddocks are every management zone on Gayini (a census), so the population SD honestly describes the spread. Sample SD (ddof=1) = {sd1:.4f} is NOT used: Task J pre-registered ddof=1 ranking because its 24 placebo dates were a genuine sample from a larger set of possible dates; 64 of 64 paddocks are not a sample. Different situation, different convention.",DEC,
  f"Scale for reading an individual residual (e.g. Bala 29ca -16.8). Bala 29ca sits 2.50 to 2.54 SD below expectation under all three conventions (ddof 0/1/2 = {d0:.2f}/{d1:.2f}/{d2:.2f}); the choice is a convention question, not a result question."),
 ("floor_flood_rse_64pdk","Regression residual standard error of the floor~flood fit (ddof=2)",
  "fact_zone_veg_annual","paddock (64)","sqrt(SSE/(n-2))","mean_of_seasons",
  SCOPE,"1988-2022","64 paddocks",PIXEL_AREA_HA,round(rse,4),round(rse,4),round(rse,4),"paddock",
  "The regression's own residual standard error; the quantity that pairs with SE(slope)=0.0691 for a prediction interval on the expectation line. Distinct from the descriptive residual SD; do NOT fold the two together.",DEC,
  "Pair to floor_flood_slope_64pdk SE. Use for prediction intervals, not for describing an individual paddock's distance from the line."),
]
c.executemany("""INSERT OR REPLACE INTO dim_headline_number
 (number_id,label,source_object,grain,aggregation_order,series_variant,scope_filter,period_label,
  denominator,pixel_constant,pinned_value,spread_min,spread_max,support_level,caveat,decided_by,decision_note)
 VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""", rows)
con.commit()
print("\nregistered:",c.execute("SELECT number_id,pinned_value,spread_min,spread_max FROM dim_headline_number WHERE number_id IN ('floor_flood_intercept_64pdk','floor_flood_residual_sd_64pdk','floor_flood_rse_64pdk')").fetchall())
print("dim_headline_number rows now:",c.execute("SELECT count(*) FROM dim_headline_number").fetchone()[0])
con.close(); print("DONE")
