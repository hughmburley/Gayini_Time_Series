#!/usr/bin/env python
"""T10 Gate B — the annual reference-grazed floor-gap series (replaces the scriptless
five-period table, I-29). READ-ONLY: computes, writes CSVs to Output/tables, no DB write.

Pinned definition (dim_headline_number PIN 2): paddock grain, year-first ordering,
mean_of_seasons. Per water year: gap = mean(reference paddocks' veg_p05_spatial)
- median(60 grazing_excluded=0 paddocks' veg_p05_spatial).

Three series: A = 4 reference paddocks; B = 3 (excl Bala 29ca); C = Bala 29ca alone.
OLS on water year -> slope, intercept, r, SE(slope), n. NO p-value (35 serial obs are not
independent; a naive p misleads - spec 4.1). Residual series written so autocorrelation is
visible. Sensitivities: the four periodisations (4.2). jja_son repeat of 4.1.
"""
import sqlite3, csv, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT = ROOT / "Output" / "tables"; OUT.mkdir(parents=True, exist_ok=True)
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); c = con.cursor()

REF_A=[1,2,3,4]; REF_B=[1,2,3]; REF_C=[4]
grazed=[r[0] for r in c.execute("SELECT zone_fid FROM dim_management_zone WHERE grazing_excluded=0")]
assert len(grazed)==60
YEARS=list(range(1988,2023))

def load(variant):
    d={}
    for zf,wy,p05 in c.execute(
        "SELECT zone_fid,water_year,veg_p05_spatial FROM fact_zone_veg_annual WHERE series_variant=? AND veg_p05_spatial IS NOT NULL",(variant,)):
        d[(zf,wy)]=p05
    return d

def median(xs):
    xs=sorted(xs); n=len(xs)
    return (xs[n//2] if n%2 else (xs[n//2-1]+xs[n//2])/2) if n else None

def annual_gap(d, ref):
    """dict year -> gap (mean ref - median grazed), only years with both sides present."""
    out={}
    for y in YEARS:
        rv=[d[(f,y)] for f in ref if (f,y) in d]
        gv=[d[(f,y)] for f in grazed if (f,y) in d]
        if rv and gv:
            out[y]=sum(rv)/len(rv)-median(gv)
    return out

def ols(gap):
    ys=sorted(gap); x=[float(y) for y in ys]; yv=[gap[y] for y in ys]; n=len(x)
    mx=sum(x)/n; my=sum(yv)/n
    sxx=sum((xi-mx)**2 for xi in x); sxy=sum((xi-mx)*(yi-my) for xi,yi in zip(x,yv)); syy=sum((yi-my)**2 for yi in yv)
    slope=sxy/sxx; intercept=my-slope*mx
    r=sxy/math.sqrt(sxx*syy) if syy>0 else float('nan')
    resid=[yi-(intercept+slope*xi) for xi,yi in zip(x,yv)]
    sse=sum(e*e for e in resid)
    se_slope=math.sqrt((sse/(n-2))/sxx) if n>2 else float('nan')
    return dict(slope=slope,intercept=intercept,r=r,se_slope=se_slope,n=n,
                years=ys,gap=yv,resid=resid)

def report_variant(variant, tag):
    d=load(variant)
    series={"A_all4":annual_gap(d,REF_A),"B_excl29ca":annual_gap(d,REF_B),"C_29ca":annual_gap(d,REF_C)}
    fits={k:ols(v) for k,v in series.items()}
    print(f"\n==================== {tag}  ({variant}) ====================")
    print(f"{'series':12} {'slope':>9} {'r':>7} {'SE_slope':>9} {'n':>4}   {'intercept':>10}")
    for k,f in fits.items():
        print(f"{k:12} {f['slope']:+9.3f} {f['r']:7.3f} {f['se_slope']:9.3f} {f['n']:4d}   {f['intercept']:10.1f}")
    return series,fits

# ---- 4.1 primary (mean_of_seasons) + 4.3 predictions ----
seriesM,fitsM=report_variant("mean_of_seasons","PRIMARY 4.1")
print("\n-- 4.3 predictions to check (design-seat, unregistered) --")
PRED={"A_all4":(+0.273,0.770),"B_excl29ca":(+0.057,0.222)}
for k,(ps,pr) in PRED.items():
    f=fitsM[k]
    print(f"  {k:12} predicted slope {ps:+.3f} r {pr:.3f} | computed slope {f['slope']:+.3f} r {f['r']:.3f} "
          f"-> {'AGREE' if abs(f['slope']-ps)<0.02 and abs(f['r']-pr)<0.03 else 'DISAGREE (computed stands)'}")

# ---- 4.2 sensitivities: four periodisations, period gap = mean of annual gaps in the period ----
PERIODS={
 "deck_5period":[(1988,1992),(1993,2002),(2003,2012),(2013,2018),(2019,2022)],
 "equal_decades":[(1988,1996),(1997,2005),(2006,2014),(2015,2022)],
 "equal_thirds":[(1988,1999),(2000,2011),(2012,2022)],
 "two_window":[(1988,1997),(2013,2022)],
}
def period_gap(gap,lo,hi):
    vals=[gap[y] for y in range(lo,hi+1) if y in gap]
    return sum(vals)/len(vals) if vals else None
print("\n-- 4.2 sensitivities (period-mean of the annual gap; mean_of_seasons) --")
for name,pers in PERIODS.items():
    print(f"  {name}:")
    for k in ("A_all4","B_excl29ca","C_29ca"):
        vals=[period_gap(seriesM[k],lo,hi) for lo,hi in pers]
        print(f"    {k:12} "+" / ".join(f"{v:+.1f}" for v in vals))

# ---- 4.1 repeat under jja_son ----
seriesJ,fitsJ=report_variant("jja_son","REPEAT 4.1")

# ---- write CSVs (for the Gate D bundle) ----
def write_series(path, series_map, fits_map, variant):
    with open(path,"w",newline="",encoding="utf-8") as fh:
        w=csv.writer(fh); w.writerow(["series_variant","series","water_year","gap_pp","residual_pp"])
        for k,f in fits_map.items():
            for y,g,e in zip(f["years"],f["gap"],f["resid"]):
                w.writerow([variant,k,y,round(g,3),round(e,3)])
write_series(OUT/"T10_annual_gap_series.csv",seriesM,fitsM,"mean_of_seasons")
with open(OUT/"T10_annual_gap_series_jja_son.csv","w",newline="",encoding="utf-8") as fh:
    w=csv.writer(fh); w.writerow(["series_variant","series","water_year","gap_pp","residual_pp"])
    for k,f in fitsJ.items():
        for y,g,e in zip(f["years"],f["gap"],f["resid"]): w.writerow(["jja_son",k,y,round(g,3),round(e,3)])
with open(OUT/"T10_trend_statistics.csv","w",newline="",encoding="utf-8") as fh:
    w=csv.writer(fh); w.writerow(["series_variant","series","slope_pp_per_yr","intercept_pp","r","se_slope","n"])
    for variant,fits in (("mean_of_seasons",fitsM),("jja_son",fitsJ)):
        for k,f in fits.items():
            w.writerow([variant,k,round(f["slope"],4),round(f["intercept"],2),round(f["r"],4),round(f["se_slope"],4),f["n"]])
print("\nCSVs written: T10_annual_gap_series.csv, _jja_son.csv, T10_trend_statistics.csv")
con.close()
