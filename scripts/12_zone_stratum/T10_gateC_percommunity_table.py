#!/usr/bin/env python
"""T10 Gate C substrate — the full paddock-parts table (L-01 substrate; T13 will build on it).
Every paddock x community with >=25 years and >=30 px/cell (~115 rows). READ-ONLY; writes one
CSV. REPORT/BUNDLE ONLY per the design-seat correction: no classify, no threshold, no register
(thresholds are pre-registered T13 decisions).

Per part: level floor, level vs the community's property-median level + rank, trend, trend vs
the community-median trend, treatment, and the paddock's I/R/A composition shares.
"""
import sqlite3, csv, statistics as st
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
c=sqlite3.connect(f"file:{(ROOT/'Output/database/Gayini_Results.sqlite').as_posix()}?mode=ro",uri=True).cursor()
name={z:n for z,n in c.execute("SELECT zone_fid,zone_name FROM dim_management_zone")}
graz={z:g for z,g in c.execute("SELECT zone_fid,grazing_excluded FROM dim_management_zone")}
treat={z:("No grazing" if graz[z] else "14-day grazing") for z in name}
COMMS=['Aeolian Chenopod Shrublands','Riverine Chenopod Shrublands','Inland Floodplain Shrublands / Swamps']
def slope(x,y):
    x=np.asarray(x,float);y=np.asarray(y,float);mx=x.mean();my=y.mean()
    return ((x-mx)*(y-my)).sum()/((x-mx)**2).sum()

CV={}
for zf,cm,wy,p05 in c.execute("SELECT zone_fid,community,water_year,veg_p05_spatial FROM fact_zone_community_veg_annual WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL"):
    CV.setdefault((zf,cm),{})[wy]=p05
parts={k:v for k,v in CV.items() if len(v)>=25}
lvl={k:st.mean(list(v.values())) for k,v in parts.items()}
trd={k:slope(sorted(v),[v[y] for y in sorted(v)]) for k,v in parts.items()}
cparts={cm:[k for k in parts if k[1]==cm] for cm in COMMS}
cml={cm:st.median([lvl[k] for k in cparts[cm]]) for cm in COMMS}
cmt={cm:st.median([trd[k] for k in cparts[cm]]) for cm in COMMS}
def rank(k): return sorted(cparts[k[1]],key=lambda kk:lvl[kk]).index(k)+1
pix={}
for zf,cm,n in c.execute("SELECT zone_fid,community,sum(n_pixels) FROM census_by_zone_stratum WHERE treed_context_flag=0 AND zone_fid IS NOT NULL GROUP BY zone_fid,community"):
    pix.setdefault(zf,{})[cm]=n
def comp(zf,cm): t=sum(pix[zf].values()); return 100*pix[zf].get(cm,0)/t if t else 0

out=ROOT/"Output/tables/T10_gateC_percommunity.csv"
with open(out,"w",newline="",encoding="utf-8") as f:
    w=csv.writer(f)
    w.writerow(["zone_fid","zone_name","treatment","community","n_years","level_floor","community_median_level","level_dev","level_rank","n_parts_in_community","trend","community_median_trend","trend_dev","comp_inland_pct","comp_riverine_pct","comp_aeolian_pct"])
    for k in sorted(parts,key=lambda k:(k[1],lvl[k])):
        zf,cm=k
        w.writerow([zf,name[zf],treat[zf],cm,len(parts[k]),round(lvl[k],2),round(cml[cm],2),round(lvl[k]-cml[cm],2),
                    rank(k),len(cparts[cm]),round(trd[k],3),round(cmt[cm],3),round(trd[k]-cmt[cm],3),
                    round(comp(zf,COMMS[2]),1),round(comp(zf,COMMS[1]),1),round(comp(zf,COMMS[0]),1)])
print(f"wrote {out.name}: {len(parts)} paddock-parts (Aeolian {len(cparts[COMMS[0]])}, Riverine {len(cparts[COMMS[1]])}, Inland {len(cparts[COMMS[2]])})")
print("Bala 29ca vs Dinan 10 trend-dev by community (verify): "
      +", ".join(f"{c2[:1]} {trd.get((4,c2),float('nan'))-cmt[c2]:+.3f}/{trd.get((57,c2),float('nan'))-cmt[c2]:+.3f}" for c2 in COMMS))
