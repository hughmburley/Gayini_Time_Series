#!/usr/bin/env python
"""REG-2 Gate A — v_zone_community_composition: paddock x community share under THREE
denominators (A focus-3 non-treed, B all non-treed, C whole paddock), with per-paddock
dominance and dominance_class at cuts 100/90/75. ADDITIVE: one NEW view, no table, no existing
object modified. Verifies the expected dominance counts (predictions to check)."""
import sqlite3
from pathlib import Path
DB=Path(__file__).resolve().parents[2]/"Output"/"database"/"Gayini_Results.sqlite"
con=sqlite3.connect(DB); c=con.cursor()

SQL="""
CREATE VIEW v_zone_community_composition AS
WITH base AS (
  SELECT zone_fid, community,
    SUM(CASE WHEN treed_context_flag=0 AND regime_band<>'context' THEN n_pixels ELSE 0 END) AS n_pixels_a,
    SUM(CASE WHEN treed_context_flag=0 THEN n_pixels ELSE 0 END)                            AS n_pixels_b,
    SUM(n_pixels)                                                                           AS n_pixels_c
  FROM census_by_zone_stratum WHERE zone_fid IS NOT NULL
  GROUP BY zone_fid, community
),
tot AS (SELECT zone_fid, SUM(n_pixels_a) ta, SUM(n_pixels_b) tb, SUM(n_pixels_c) tc FROM base GROUP BY zone_fid),
shr AS (
  SELECT b.zone_fid, b.community, b.n_pixels_a, b.n_pixels_b, b.n_pixels_c,
    100.0*b.n_pixels_a/NULLIF(t.ta,0) AS share_a,
    100.0*b.n_pixels_b/NULLIF(t.tb,0) AS share_b,
    100.0*b.n_pixels_c/NULLIF(t.tc,0) AS share_c
  FROM base b JOIN tot t USING(zone_fid)
),
dom AS (
  SELECT shr.*,
    MAX(share_a) OVER (PARTITION BY zone_fid) AS dominance_a,
    MAX(share_b) OVER (PARTITION BY zone_fid) AS dominance_b,
    MAX(share_c) OVER (PARTITION BY zone_fid) AS dominance_c,
    SUM(CASE WHEN n_pixels_a>0 THEN 1 ELSE 0 END) OVER (PARTITION BY zone_fid) AS n_comm_a,
    SUM(CASE WHEN n_pixels_b>0 THEN 1 ELSE 0 END) OVER (PARTITION BY zone_fid) AS n_comm_b,
    SUM(CASE WHEN n_pixels_c>0 THEN 1 ELSE 0 END) OVER (PARTITION BY zone_fid) AS n_comm_c
  FROM shr
)
SELECT d.zone_fid, z.zone_name, d.community,
  d.n_pixels_a, d.n_pixels_b, d.n_pixels_c,
  ROUND(d.share_a,2) AS share_a, ROUND(d.share_b,2) AS share_b, ROUND(d.share_c,2) AS share_c,
  ROUND(d.dominance_a,2) AS dominance_a, ROUND(d.dominance_b,2) AS dominance_b, ROUND(d.dominance_c,2) AS dominance_c,
  CASE WHEN d.n_comm_a<=1 THEN 'single' WHEN d.dominance_a>=90 THEN 'high' WHEN d.dominance_a>=75 THEN 'moderate' ELSE 'mixed' END AS dominance_class_a,
  CASE WHEN d.n_comm_b<=1 THEN 'single' WHEN d.dominance_b>=90 THEN 'high' WHEN d.dominance_b>=75 THEN 'moderate' ELSE 'mixed' END AS dominance_class_b,
  CASE WHEN d.n_comm_c<=1 THEN 'single' WHEN d.dominance_c>=90 THEN 'high' WHEN d.dominance_c>=75 THEN 'moderate' ELSE 'mixed' END AS dominance_class_c,
  (SELECT COUNT(*) FROM fact_zone_community_part_summary p WHERE p.zone_fid=d.zone_fid) AS n_parts_supported
FROM dom d JOIN dim_management_zone z USING(zone_fid)
"""
c.execute("DROP VIEW IF EXISTS v_zone_community_composition")
c.execute(SQL); con.commit()

# ---- verify expected counts (dominance per paddock, distinct) ----
print("v_zone_community_composition rows:",c.execute("SELECT COUNT(*) FROM v_zone_community_composition").fetchone()[0],
      " paddocks:",c.execute("SELECT COUNT(DISTINCT zone_fid) FROM v_zone_community_composition").fetchone()[0])
EXP={'A':(14,9,26,795602),'B':(16,9,25,800340),'C':(22,15,19,885292)}
for d,(l75,l60,single,px) in EXP.items():
    dd=d.lower()
    q=lambda cond: c.execute(f"SELECT COUNT(*) FROM (SELECT zone_fid, MAX(dominance_{dd}) dm, MAX(CASE WHEN dominance_class_{dd}='single' THEN 1 ELSE 0 END) sg FROM v_zone_community_composition GROUP BY zone_fid) WHERE {cond}").fetchone()[0]
    n75=q("dm<75"); n60=q("dm<60"); nsg=q("sg=1")
    tpx=c.execute(f"SELECT SUM(n_pixels_{dd}) FROM v_zone_community_composition").fetchone()[0]
    ok=(n75,n60,nsg,tpx)==(l75,l60,single,px)
    print(f"  denom {d}: <75={n75}(exp {l75}) <60={n60}(exp {l60}) single={nsg}(exp {single}) total_px={tpx}(exp {px})  {'OK' if ok else 'DIFFER'}")
con.close()
