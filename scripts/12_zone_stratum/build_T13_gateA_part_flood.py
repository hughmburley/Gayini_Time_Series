#!/usr/bin/env python
"""T13 Gate A — annual flood at PART grain (paddock x community x water year).
Extracts wet/valid annual counts at the 795,602 in-scope zoned census centroids, same encoding
as T2_gateB_extract.R (valid_any==1, wet_any==1). Writes a NEW additive table
fact_zone_community_flood_annual. Does NOT re-run the builder, does NOT modify
fact_zone_community_veg_annual.

Reconciliation: summing part-grain wet/valid across communities within a paddock-year must
reproduce fact_zone_veg_annual.wet_pixels / valid_pixels. Reports max abs diff (expected 0).
Paths resolved from raster_asset (I-21).
"""
import sqlite3, csv
import numpy as np
from rasterio.transform import rowcol
import rasterio
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; DB=ROOT/"Output"/"database"/"Gayini_Results.sqlite"
RUN="T13_gateA_20260729"
con=sqlite3.connect(DB); c=con.cursor()

WET=c.execute("SELECT path FROM raster_asset WHERE raster_asset_id='raster_08058_wet'").fetchone()[0]
VAL=c.execute("SELECT path FROM raster_asset WHERE raster_asset_id='raster_08058_valid'").fetchone()[0]
PTS=ROOT/"Output"/"tables"/"T2_in_scope_points.csv"

# --- load points, assign a group id per (zone_fid, community) ---
x=[];y=[];zf=[];cm=[]
with open(PTS) as f:
    for row in csv.DictReader(f):
        x.append(float(row["x_8058"]));y.append(float(row["y_8058"]))
        zf.append(int(row["zone_fid"]));cm.append(row["community"])
x=np.array(x);y=np.array(y);zf=np.array(zf,dtype=np.int32)
keys=sorted(set(zip(zf.tolist(),cm)))
kidx={k:i for i,k in enumerate(keys)}
gid=np.array([kidx[(zf[i],cm[i])] for i in range(len(zf))],dtype=np.int32)
G=len(keys)
print(f"points {len(x):,}  parts (zone x community) {G}")

with rasterio.open(str(ROOT/WET)) as d: H,W,T=d.height,d.width,d.transform
rr,cc=rowcol(T,x,y); flat=np.asarray(rr)*W+np.asarray(cc)

dw=rasterio.open(str(ROOT/WET)); dv=rasterio.open(str(ROOT/VAL))
years=[1987+j for j in range(1,36)]
wet=np.zeros((G,35),dtype=np.int64); val=np.zeros((G,35),dtype=np.int64)
for j in range(1,36):
    w=dw.read(j).ravel()[flat]; l=dv.read(j).ravel()[flat]
    vok=(l==1); wok=(w==1)
    val[:,j-1]=np.bincount(gid[vok],minlength=G)
    wet[:,j-1]=np.bincount(gid[wok],minlength=G)
dw.close();dv.close()

# --- write table (rows with valid_pixels>0 OR wet, i.e. observed part-years; full series per part) ---
c.execute("DROP TABLE IF EXISTS fact_zone_community_flood_annual")
c.execute("""CREATE TABLE fact_zone_community_flood_annual(
  zone_fid INTEGER, community TEXT, water_year INTEGER,
  wet_pixels INTEGER, valid_pixels INTEGER, flood_frac_pct REAL,
  support_level TEXT, aggregation_unit TEXT, run_id TEXT)""")
rows=[]
for i,(zfi,cmi) in enumerate(keys):
    for jy,yr in enumerate(years):
        v=int(val[i,jy]); wv=int(wet[i,jy])
        ff=round(100.0*wv/v,4) if v>0 else None
        rows.append((zfi,cmi,yr,wv,v,ff,"pixel","zone_community_year",RUN))
c.executemany("INSERT INTO fact_zone_community_flood_annual VALUES (?,?,?,?,?,?,?,?,?)",rows)
con.commit()
print(f"fact_zone_community_flood_annual: {len(rows)} rows ({G} parts x 35 years)")

# --- reconciliation vs fact_zone_veg_annual (paddock-grain wet/valid) ---
fzva={}
for zfi,yr,wp,vp in c.execute("SELECT zone_fid,water_year,wet_pixels,valid_pixels FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'"):
    fzva[(zfi,yr)]=(wp,vp)
part_sum={}
for zfi,yr,wv,v in c.execute("SELECT zone_fid,water_year,SUM(wet_pixels),SUM(valid_pixels) FROM fact_zone_community_flood_annual GROUP BY zone_fid,water_year"):
    part_sum[(zfi,yr)]=(wv,v)
max_wet_diff=0; max_val_diff=0; nmiss=0
for k,(wp,vp) in fzva.items():
    ps=part_sum.get(k)
    if ps is None: nmiss+=1; continue
    max_wet_diff=max(max_wet_diff,abs((ps[0] or 0)-(wp or 0)))
    max_val_diff=max(max_val_diff,abs((ps[1] or 0)-(vp or 0)))
print(f"reconciliation vs fact_zone_veg_annual: max |wet diff| = {max_wet_diff}, max |valid diff| = {max_val_diff}, unmatched paddock-years = {nmiss}")
print("EXPECTED: 0 / 0 / 0" if (max_wet_diff==0 and max_val_diff==0 and nmiss==0) else "*** DIFFER - report, do not absorb ***")
# quick coverage note: parts with >=25 years of >=30 valid px (Gate B universe)
ge=c.execute("SELECT COUNT(*) FROM (SELECT zone_fid,community FROM fact_zone_community_flood_annual WHERE valid_pixels>=30 GROUP BY zone_fid,community HAVING COUNT(*)>=25)").fetchone()[0]
print(f"parts with >=25 yr of >=30 valid px (Gate B universe, cf fact_zone_community_part_summary=115): {ge}")
con.close(); print("DONE")
