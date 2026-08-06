#!/usr/bin/env python
"""UNZONED Gate 1 - build the units on the standard-grazing country, and prove the
construction reproduces PARTREG before anything is fitted.

Spec: docs/reference_update/Gayini_CC_spec_UNZONED_v2.md sections 1-3, gate 1 in section 8.

WHAT THIS GROUND IS.  Unzoned STANDARD-GRAZING country - set stocking, a designed
treatment arm. It is not a reference set, not a control, and not unmanaged. It is the
57.7%-of-the-property complement: 12,048 ha that carries a community label and 35 years
of cover and water and has never entered any fit.

NO FITTING HERE.  Gate 1 is counts, sizes, contiguity, the plot overlay, and one
assertion. Section 4 is a separate script.

THE ONE CONDITION THAT HALTS THE RUN is a quantity that will not reproduce. The patch
series is built by the same function that is then pointed at a real PARTREG part; if
that part's 35-year series does not match fact_zone_community_veg_annual to
floating-point tolerance the script stops. The check is then shown FIRING on a
deliberately corrupted fixture, because a check that has never failed has only been run.

CONNECTIVITY.  Patches are 8-connected (queen) within a community. Stated because it is
a choice: 4-connectivity would split at every diagonal pinch, and T3-I4 records what
happens when a connectivity assumption is silently changed downstream.
"""
from __future__ import annotations

import csv
import sqlite3
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import rasterio
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
DATA = ROOT / "Output" / "pack" / "DATA"
CENSUS = ROOT / "Output" / "census"
OUT = ROOT / "Output" / "tables"

PX_AREA_HA = 24.970268 ** 2 / 1e4
MIN_CELLS_YEAR, MIN_YEARS = 30, 25          # the rule that selected the 115 parts
V1_CELL_THRESHOLD = 33                      # v1's threshold, reported for contrast
COMM_SHORT = {"Aeolian Chenopod Shrublands": "aeolian",
              "Riverine Chenopod Shrublands": "riverine",
              "Inland Floodplain Shrublands / Swamps": "inland"}
TEST_PART = (4, "Aeolian Chenopod Shrublands")   # Bala 29ca - the assertion fixture

COVER = DATA / "rasters/total_veg_annual_mean_8058.tif"
WET = DATA / "rasters/annual_wet_any_1988_2023_8058.tif"
VALID = DATA / "rasters/annual_valid_any_1988_2023_8058.tif"

print("=" * 78)
print("UNZONED Gate 1 - units, sizes, contiguity, and the reproduction assertion")
print("=" * 78)

# ---------------------------------------------------------------- 2.1 the mask
cen = pq.read_table(CENSUS / "gayini_pixel_census_8058.parquet",
                    columns=["pixel_id", "x_8058", "y_8058", "community",
                             "regime_band", "treed_context_flag"]).to_pydict()
zas = pq.read_table(CENSUS / "gayini_pixel_zone_assignment.parquet").to_pydict()
zone_of = dict(zip(zas["pixel_id"], zas["zone_fid"]))

comm = np.array([str(c) for c in cen["community"]])
band = np.array([str(b) for b in cen["regime_band"]])
treed = np.array(cen["treed_context_flag"], dtype=bool)
zfid = np.array([zone_of.get(p) if zone_of.get(p) is not None else -1
                 for p in cen["pixel_id"]], dtype=np.int32)
x = np.asarray(cen["x_8058"], float)
y = np.asarray(cen["y_8058"], float)

nontreed = (~treed) & (band != "context")
unz = nontreed & (zfid < 0)
zon = nontreed & (zfid >= 0)
print(f"\n[2.1 mask]  census cells {len(comm):,}")
print(f"  non-treed (9 strata)        {nontreed.sum():>9,} px = {nontreed.sum()*PX_AREA_HA:9,.1f} ha")
print(f"  zoned non-treed             {zon.sum():>9,} px = {zon.sum()*PX_AREA_HA:9,.1f} ha")
print(f"  UNZONED non-treed           {unz.sum():>9,} px = {unz.sum()*PX_AREA_HA:9,.1f} ha")
print(f"  reconciliation: {zon.sum()*PX_AREA_HA:,.1f} + {unz.sum()*PX_AREA_HA:,.1f} = "
      f"{nontreed.sum()*PX_AREA_HA:,.1f} ha   "
      f"(SCHEM-1 rung 3 = 61,655.0)  {'CLOSES' if abs(nontreed.sum()*PX_AREA_HA-61655.0)<0.1 else 'DOES NOT CLOSE'}")
print("  by community (expected 13,078 / 50,791 / 129,360):")
for cm in sorted(set(comm[unz])):
    n = int((unz & (comm == cm)).sum())
    print(f"    {cm:<40s} {n:>8,} px  {n*PX_AREA_HA:8,.1f} ha")

# ------------------------------------------------- 2.2 patches: 8-connected, per community
with rasterio.open(COVER) as s:
    inv, H, W = ~s.transform, s.height, s.width
    wys = [int(n[:4]) for n in s.descriptions]
col_all, row_all = inv * (x, y)
col_all = col_all.astype(np.int32); row_all = row_all.astype(np.int32)

patch_id = np.full(len(comm), -1, dtype=np.int64)
patch_meta = {}
nxt = 0
for cm in sorted(set(comm[unz])):
    sel = unz & (comm == cm)
    g = np.zeros((H, W), dtype=bool)
    g[row_all[sel], col_all[sel]] = True
    lab, n = ndimage.label(g, structure=np.ones((3, 3), dtype=int))   # 8-connected
    ids = lab[row_all[sel], col_all[sel]]
    patch_id[sel] = nxt + ids
    for k in range(1, n + 1):
        patch_meta[nxt + k] = dict(community=cm, community_short=COMM_SHORT[cm])
    nxt += n
    print(f"\n[2.2 patches] {cm:<40s} {n:>4} connected components (8-connected)")

pids, pcounts = np.unique(patch_id[patch_id > 0], return_counts=True)
size_of = dict(zip(pids.tolist(), pcounts.tolist()))
print(f"[2.2 patches] total {len(pids):,} patches over {int(unz.sum()):,} cells")

# --------------------------------------- the shared series builder (one code path)
def series_for(rows: np.ndarray, cols: np.ndarray, gid: np.ndarray, cover_path=COVER):
    """Per group, per water year: valid cover cells, spatial p05, wet and valid counts.

    THIS IS THE ONLY PLACE either set's axes are computed. Pointing it at a PARTREG
    part must reproduce fact_zone_community_veg_annual.
    """
    order = np.argsort(gid, kind="stable")
    rows, cols, gid = rows[order], cols[order], gid[order]
    edges = np.flatnonzero(np.r_[True, gid[1:] != gid[:-1], True])
    groups = [(int(gid[a]), a, b) for a, b in zip(edges[:-1], edges[1:])]
    out: dict[tuple, dict] = {}
    with rasterio.open(cover_path) as cs, rasterio.open(WET) as ws, rasterio.open(VALID) as vs:
        years = [int(n[:4]) for n in cs.descriptions]
        for j, wy in enumerate(years, start=1):
            cv = cs.read(j)[rows, cols].astype(float)
            wv = ws.read(j)[rows, cols]
            vv = vs.read(j)[rows, cols]
            for g, a, b in groups:
                c = cv[a:b]; ok = ~np.isnan(c)
                nv = int(ok.sum())
                vok = int(((vv[a:b] == 1)).sum()); wok = int(((wv[a:b] == 1)).sum())
                out[(g, wy)] = dict(
                    n_valid=nv,
                    p05=float(np.quantile(np.sort(c[ok]), 0.05)) if nv else float("nan"),
                    wet_pixels=wok, valid_pixels=vok,
                    flood_frac_pct=(100.0 * wok / vok) if vok else float("nan"))
    return out


# ---------------- section 3 - the assertion, on a real part, through this code path
zf, cmn = TEST_PART
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
con.execute("PRAGMA query_only=1")
stored = {wy: (nv, p05, ffp, wp, vp) for wy, nv, p05, ffp, wp, vp in con.execute(
    """SELECT v.water_year, v.n_pixels_valid, v.veg_p05_spatial, f.flood_frac_pct,
              f.wet_pixels, f.valid_pixels
       FROM fact_zone_community_veg_annual v
       JOIN fact_zone_community_flood_annual f
         ON f.zone_fid=v.zone_fid AND f.community=v.community AND f.water_year=v.water_year
       WHERE v.zone_fid=? AND v.community=? AND v.series_variant='mean_of_seasons'""",
    (zf, cmn))}
zname = dict(con.execute("SELECT zone_fid, zone_name FROM dim_management_zone"))
con.close()

tsel = zon & (comm == cmn) & (zfid == zf)
got = series_for(row_all[tsel], col_all[tsel], np.ones(int(tsel.sum()), dtype=np.int64))
dp = max(abs(got[(1, wy)]["p05"] - stored[wy][1]) for wy in stored)
dn = max(abs(got[(1, wy)]["n_valid"] - stored[wy][0]) for wy in stored)
dw = max(abs(got[(1, wy)]["wet_pixels"] - stored[wy][3]) for wy in stored)
dv = max(abs(got[(1, wy)]["valid_pixels"] - stored[wy][4]) for wy in stored)
df = max(abs(got[(1, wy)]["flood_frac_pct"] - stored[wy][2]) for wy in stored)
# fact_zone_community_flood_annual stores flood_frac_pct ROUNDED TO 4 dp - measured max
# deviation from 100*wet/valid across all 4,130 part-years is 4.999e-05, exactly a 4-dp
# budget. Zone grain (fact_zone_veg_annual) stores the SAME derived quantity at full
# double precision, 5.7e-14. So the assertion is made on the COUNTS, which are integers
# and exact, and the percentage is checked against its storage budget rather than against
# a floating-point tolerance it was never written at. Same shape as T11's residual budget.
FRAC_BUDGET = 5e-5
print(f"\n[3 assertion] {zname[zf]} / {COMM_SHORT[cmn]}, {len(stored)} water years, "
      f"{int(tsel.sum()):,} cells")
print(f"  cover   : p05 max |diff| {dp:.3e}   n_valid max |diff| {dn}    (exact quantities)")
print(f"  water   : wet cells {dw}, valid cells {dv} max |diff|          (exact quantities)")
print(f"  derived : flood_frac_pct max |diff| {df:.3e} against a 4-dp storage budget of "
      f"{FRAC_BUDGET:.0e}")
if not (dp < 1e-9 and dn == 0 and dw == 0 and dv == 0):
    raise SystemExit("HALT: the patch code path does not reproduce the registered series.")
if df >= FRAC_BUDGET:
    raise SystemExit(f"HALT: flood_frac_pct differs by {df:.3e}, beyond its storage budget.")
print("  PASS - counts reproduce exactly; the percentage sits inside its storage rounding")

# ... and now show the same check FAILING on a deliberately corrupted fixture
bad_rows = row_all[tsel].copy()
bad_rows[: max(1, int(tsel.sum()) // 20)] += 3          # nudge 5% of cells off their true row
badgot = series_for(bad_rows, col_all[tsel], np.ones(int(tsel.sum()), dtype=np.int64))
bdp = max(abs(badgot[(1, wy)]["p05"] - stored[wy][1]) for wy in stored)
print(f"  FIXTURE: 5% of cells displaced by 3 rows -> max |p05 diff| {bdp:.4f} "
      f"({'REJECTED as required' if bdp > 1e-9 else 'NOT REJECTED - the check is blind'})")
if bdp <= 1e-9:
    raise SystemExit("HALT: the reproduction check cannot fail, so it is not a check.")

# --------------------------------------- 2.2 support rule, applied to the patches
sel = patch_id > 0
ser = series_for(row_all[sel], col_all[sel], patch_id[sel])
years_ok, first = {}, {}
for (g, wy), v in ser.items():
    years_ok[g] = years_ok.get(g, 0) + (1 if v["n_valid"] >= MIN_CELLS_YEAR else 0)
supported = sorted(g for g in size_of if years_ok.get(g, 0) >= MIN_YEARS)
by33 = sorted(g for g in size_of if size_of[g] >= V1_CELL_THRESHOLD)
print(f"\n[2.2 support] the RULE (>= {MIN_YEARS} yrs of >= {MIN_CELLS_YEAR} valid cells): "
      f"{len(supported)} patches kept of {len(pids)}")
print(f"              a bare >= {V1_CELL_THRESHOLD}-cell threshold would keep: {len(by33)}")
print(f"              v1's prediction was 93 (13 / 25 / 55) under the cell-count rule")
for cs_ in ("aeolian", "riverine", "inland"):
    a = [g for g in supported if patch_meta[g]["community_short"] == cs_]
    b = [g for g in by33 if patch_meta[g]["community_short"] == cs_]
    ha = sum(size_of[g] for g in a) * PX_AREA_HA
    print(f"    {cs_:<9s} rule {len(a):>4}   >=33 cells {len(b):>4}   "
          f"supported area {ha:8,.1f} ha of "
          f"{sum(size_of[g] for g in size_of if patch_meta[g]['community_short']==cs_)*PX_AREA_HA:8,.1f}")

# ---------------------------------------------------- 2.3 the two size distributions
real = list(csv.DictReader(open(OUT / "PARTREG_S2_part_summary_by_period.csv", encoding="utf-8-sig")))
real = [r for r in real if r["period"] == "whole_record"]


def dist(v):
    v = np.asarray(sorted(v), float)
    return dict(n=len(v), min=int(v.min()), q1=int(np.quantile(v, .25)),
                med=int(np.median(v)), q3=int(np.quantile(v, .75)), max=int(v.max()))


print("\n[2.3 size]  cells per unit")
print(f"  {'set':<28s}{'n':>5}{'min':>8}{'Q1':>9}{'median':>9}{'Q3':>9}{'max':>9}")
rows_out = []
for lab, vals in [("real parts, all", [int(r["n_pixels_part"]) for r in real])] + \
        [(f"real parts, {cs_}", [int(r["n_pixels_part"]) for r in real if r["community_short"] == cs_])
         for cs_ in ("aeolian", "riverine", "inland")] + \
        [("unzoned patches, all", [size_of[g] for g in supported])] + \
        [(f"unzoned patches, {cs_}", [size_of[g] for g in supported
                                      if patch_meta[g]["community_short"] == cs_])
         for cs_ in ("aeolian", "riverine", "inland")]:
    if not vals:
        print(f"  {lab:<28s}    0   (none supported)"); continue
    d = dist(vals)
    print(f"  {lab:<28s}{d['n']:>5}{d['min']:>8,}{d['q1']:>9,}{d['med']:>9,}{d['q3']:>9,}{d['max']:>9,}")
    rows_out.append(dict(set=lab, **d))

# ------------------------------------------- 2.4 contiguity of the REAL parts
multi = 0
comp_counts = []
for r in real:
    zf_, cm_ = int(r["zone_fid"]), r["community"]
    m = zon & (comm == cm_) & (zfid == zf_)
    g = np.zeros((H, W), dtype=bool)
    g[row_all[m], col_all[m]] = True
    _, n = ndimage.label(g, structure=np.ones((3, 3), dtype=int))
    comp_counts.append(n)
    multi += (n > 1)
cc = np.array(comp_counts)
print(f"\n[2.4 contiguity] connected components per REAL part (8-connected)")
print(f"  single-component {int((cc == 1).sum())} of {len(cc)}   multi-component {multi} "
      f"({100*multi/len(cc):.0f}%)   max {cc.max()}")
print(f"  -> baseline: {'the SINGLE-COMPONENT real parts, and both are reported' if multi/len(cc) > 0.2 else 'the full 115 - contiguity is not a material unit difference'}")

# --------------------------------------------------------------- outputs
inv = []
for g in sorted(size_of):
    inv.append(dict(patch_id=f"U{g:04d}", community=patch_meta[g]["community"],
                    community_short=patch_meta[g]["community_short"],
                    n_cells=size_of[g], area_ha=round(size_of[g] * PX_AREA_HA, 4),
                    n_years_ge30_valid=years_ok.get(g, 0),
                    meets_support_rule=int(g in set(supported)),
                    meets_bare_33_cells=int(size_of[g] >= V1_CELL_THRESHOLD),
                    unit_construction="8-connected component within one community, outside every "
                                      "management zone",
                    selection_rule=f">={MIN_YEARS} water years with >={MIN_CELLS_YEAR} valid cells",
                    support_level="pixel", period_label="1988-2022",
                    land_use_label="unzoned standard-grazing country"))
with (OUT / "UNZONED_gate1_patch_inventory.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(inv[0])); w.writeheader(); w.writerows(inv)
with (OUT / "UNZONED_gate1_size_distributions.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows_out[0])); w.writeheader(); w.writerows(rows_out)
np.save(ROOT / "Output" / "tables" / "UNZONED_gate1_patch_series.npy",
        np.array([(g, wy, v["n_valid"], v["p05"], v["wet_pixels"], v["valid_pixels"],
                   v["flood_frac_pct"]) for (g, wy), v in sorted(ser.items())]))
print(f"\n[outputs] UNZONED_gate1_patch_inventory.csv     {len(inv):,} patches")
print(f"          UNZONED_gate1_size_distributions.csv  {len(rows_out)} rows")
print(f"          UNZONED_gate1_patch_series.npy        {len(ser):,} patch-years (Stage A input)")
print("\nGATE 1 COMPLETE - no fitting performed.")
