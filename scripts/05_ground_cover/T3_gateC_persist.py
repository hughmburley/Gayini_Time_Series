"""T3 Gate C - persist the sweep as v_always_green_sweep, both metrics, and pin the
reference set on dim_management_zone.

Spec: docs/T3_always_green_threshold.md v3, Gate C.
Decisions: docs/decisions/T3_gateD_decisions.md (design seat, 3 Aug 2026).

ADDITIVE ONLY. Creates one table + one view and adds three columns to
dim_management_zone. Nothing is dropped; no existing table or view is modified.
INSERT OR REPLACE keyed on (threshold, scope, metric) - never OR IGNORE, which
passes a stability test while the DB is wrong.

--------------------------------------------------------------------------------
DECISION 1 - NO HEADLINE THRESHOLD. The spec's falsification condition fired: Gate
B1 measured a smooth decline with no knee, so refugial extent is a continuum and any
single area figure is a chosen cut. is_selected_threshold is therefore set ONLY as
an operational LiDAR input, and selection_role records that. It is NEVER a headline.
--------------------------------------------------------------------------------

THREE SCHEMA ADDITIONS BEYOND THE SPEC, each for a reason the project has already
paid for once:

  grid_epsg           - the spec gives pixel_area_ha and scope_filter_sql because
                        v1's failures were an unstated constant and an unstated
                        scope. D8 was an unstated GRID. Same class, same fix.
  measurement_basis   - 'measured' vs 'reprojected_for_overlay'. The green-share
                        rows on the 8058 grid are a REPROJECTION, not a
                        re-measurement; without this column someone quotes 3,744 ha
                        as the green-share area and re-opens D8.
  selection_role      - so is_selected_threshold can be 'operational_lidar_input'
                        rather than silently reading as a headline.

And one enum extension: scope also takes 'farm_boundary_native' for the two rows
that carry the MEASURED green-share numbers on their native 30 m EPSG:3577 grid.
Without those rows the view would contain only reprojected green-share areas.
The native farm mask (86,384.97 ha implied) is NOT the census mapped footprint
(67,349.332 ha) - different scopes, which is exactly why it needs its own label.
"""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import duckdb
import numpy as np
import rasterio
from scipy import ndimage

sys.path.insert(0, str(Path("scripts") / "lib"))
import gayini_params as gp  # noqa: E402

DB = Path("Output") / "database" / "Gayini_Results.sqlite"
CENSUS = Path("Output") / "census" / "gayini_pixel_census_8058.parquet"
GRID_TIF = Path("Output") / "rasters" / "veg_regime_class_8058.tif"
GREEN_TIF = Path("Output") / "rasters" / "persistence_8058" / "green_share_at_floor_8058.tif"
TASKM_CSV = Path("Output") / "tables" / "taskM_green_at_floor_area.csv"
RUN_ID = "T3_gateC"

THRESHOLDS = list(range(40, 91))
MIN_COMPONENT_PX = int(np.ceil(5.0 / gp.PIXEL_AREA_HA))

# Decision 1: the operational LiDAR cut. 75 primary; 79 and 82 are the sensitivity
# arms and are NOT flagged in is_selected_threshold (exactly one row per scope+metric).
OPERATIONAL_CUT = {"total_cover_floor": 75, "green_share_floor": 50}
SELECTION_ROLE = "operational_lidar_input"

NOT_MEASURED = (
    "reprojected_for_overlay - NOT the measured area. The green-share floor is "
    "measured on its native 30 m EPSG:3577 grid (71,755 px = 6,457.95 ha at "
    "green_frac_pct > 50); this 8058 row is a bilinear reprojection thresholded on "
    "the 8058 grid and is a different operation. Never quote it as the area.")


def build_arrays():
    con = duckdb.connect()
    df = con.execute(f"""
        SELECT x_8058, y_8058, veg_p05, flood_freq_pct, treed_context_flag, regime_band
        FROM read_parquet('{CENSUS.as_posix()}')
    """).fetchdf()
    with rasterio.open(GRID_TIF) as src:
        tr, H, W = src.transform, src.height, src.width
    col = np.floor((df["x_8058"].to_numpy() - tr.c) / abs(tr.a)).astype(np.int32)
    row = np.floor((tr.f - df["y_8058"].to_numpy()) / abs(tr.e)).astype(np.int32)

    with rasterio.open(GREEN_TIF) as src:
        assert (src.height, src.width) == (H, W), "green-share raster is off-grid"
        green_grid = src.read(1, masked=True).filled(np.nan)
    green = green_grid[row, col]

    p05 = df["veg_p05"].to_numpy(np.float64)
    ff = df["flood_freq_pct"].to_numpy(np.float64)
    treed = df["treed_context_flag"].to_numpy(bool)
    band = df["regime_band"].to_numpy(object)
    non_treed = (~treed) & (band != "context")
    return dict(row=row, col=col, H=H, W=W, p05=p05, green=green, ff=ff,
                non_treed=non_treed)


def sweep_rows(A):
    grid = np.zeros((A["H"], A["W"]), bool)
    s8 = ndimage.generate_binary_structure(2, 2)

    def ncomp(sel):
        grid[:] = False
        grid[A["row"][sel], A["col"][sel]] = True
        lab, n = ndimage.label(grid, structure=s8)
        if n == 0:
            return 0
        return int((np.bincount(lab.ravel())[1:] >= MIN_COMPONENT_PX).sum())

    metrics = {
        "total_cover_floor": (A["p05"], "measured",
                              "census veg_p05 >= t: across-series 5th percentile of TOTAL VEG "
                              "(green PV + non-green NPV) per pixel over 140 seasonal composites"),
        "green_share_floor": (A["green"], NOT_MEASURED,
                              "green_frac_pct >= t: 100 * PV / total_veg read PAIRED in the season "
                              "that sets each pixel's total-veg 5th-percentile order statistic"),
    }
    scopes = {"non_treed": (A["non_treed"], gp.SCOPE_NON_TREED),
              "all_pixel": (np.ones_like(A["non_treed"]), gp.SCOPE_ALL_PIXEL)}

    out = []
    for mname, (vals, basis, mdef) in metrics.items():
        finite = np.isfinite(vals)
        for sname, (smask, ssql) in scopes.items():
            base = smask & finite
            for t in THRESHOLDS:
                sel = base & (vals >= t)
                n = int(sel.sum())
                ffv = A["ff"][sel]
                out.append((
                    t, sname, mname, n, n * gp.PIXEL_AREA_HA,
                    100.0 * n * gp.PIXEL_AREA_HA / gp.MAPPED_AREA_HA,
                    100.0 * n * gp.PIXEL_AREA_HA / gp.TRUE_FARM_HA,
                    float(np.mean(ffv)) if n else None,
                    float(np.median(ffv)) if n else None,
                    ncomp(sel), gp.PIXEL_AREA_HA, ssql,
                    1 if t == OPERATIONAL_CUT[mname] else 0,
                    SELECTION_ROLE if t == OPERATIONAL_CUT[mname] else None,
                    "pixel", "pixel", 8058, basis, mdef, RUN_ID))
            print(f"  {mname} / {sname}: {len(THRESHOLDS)} thresholds")
    return out


def native_green_rows():
    """The MEASURED green-share numbers, on their own grid, so the view cannot be
    read as if the reprojected 8058 figure were the area."""
    import csv
    tm = {r["quantity"]: float(r["value"]) for r in csv.DictReader(open(TASKM_CSV))}
    n_gt = int(tm["n_majority_green_px_gt50"])
    area = tm["area_ha_native_30m_3577"]
    px_ha = 0.09  # the native 30 m cell; NOT a project constant, it is the FC grid
    basis = ("measured - green_at_floor() on the native 30 m EPSG:3577 FC grid, farm "
             "boundary crop+mask, MIN_SEASONS >= 50 valid paired seasons. Reconciled "
             "exactly with Output/tables/taskM_green_at_floor_area.csv (diff 0 px).")
    mdef = ("green_frac_pct >= t: 100 * PV / total_veg read PAIRED in the season that "
            "sets each pixel's total-veg 5th-percentile order statistic")
    return [(50, "farm_boundary_native", "green_share_floor", n_gt, area,
             None, None, None, None, None, px_ha,
             "farm boundary polygon, crop + mask on the native 3577 grid",
             1, SELECTION_ROLE, "pixel", "pixel", 3577, basis, mdef, RUN_ID)]


DDL = """
CREATE TABLE IF NOT EXISTS t3_always_green_sweep (
  threshold            INTEGER NOT NULL,
  scope                TEXT    NOT NULL,
  metric               TEXT    NOT NULL,
  n_pixels             INTEGER,
  area_ha              REAL,
  pct_of_mapped        REAL,
  pct_of_farm_total    REAL,
  flood_freq_mean      REAL,
  flood_freq_median    REAL,
  n_components_ge_5ha  INTEGER,
  pixel_area_ha        REAL,
  scope_filter_sql     TEXT,
  is_selected_threshold INTEGER DEFAULT 0,
  selection_role       TEXT,
  support_level        TEXT,
  aggregation_unit     TEXT,
  grid_epsg            INTEGER,
  measurement_basis    TEXT,
  metric_definition    TEXT,
  run_id               TEXT,
  PRIMARY KEY (threshold, scope, metric)
);
CREATE VIEW IF NOT EXISTS v_always_green_sweep AS
  SELECT * FROM t3_always_green_sweep;
"""


def main():
    gp.validate()
    A = build_arrays()
    rows = sweep_rows(A) + native_green_rows()

    con = sqlite3.connect(DB)
    try:
        con.executescript(DDL)
        con.executemany(
            "INSERT OR REPLACE INTO t3_always_green_sweep VALUES "
            "(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)

        # ---- Decision 3: pin the reference set on the zone definition ----------
        have = [r[1] for r in con.execute("PRAGMA table_info(dim_management_zone)")]
        for col, typ in (("reference_set_member", "INTEGER"),
                         ("reference_set_rule", "TEXT"),
                         ("reference_set_caveat", "TEXT")):
            if col not in have:
                con.execute(f"ALTER TABLE dim_management_zone ADD COLUMN {col} {typ}")
        rule = ("grazing_excluded = 1. Pinned 3 Aug 2026 (T3 Gate D decision 3). Four zones: "
                "Bala 26ca/27ca/28ca/29ca, zone_fid 1-4, 7,534.86 ha computed. Defined on the "
                "management polygon, NOT on the plot network.")
        caveat = ("TWO CONDITIONS TRAVEL WITH THIS SET. (1) 'Three reference paddocks' is a real "
                  "DEFINITIONAL DIFFERENCE, not an error: three of the four carry RAP plots and "
                  "Bala 27ca has none, so a plot-network count gives 3 and a polygon count gives 4. "
                  "Any document must state which it uses. (2) L-01 APPLIES AND IS NOT DISCHARGED BY "
                  "THIS PIN: the management zone is not an ecological unit. Bala 29ca spans "
                  "Inland 35% / Riverine 33% / Aeolian 32%, and its parts behave oppositely. Every "
                  "reference number must be DECOMPOSED BY COMMUNITY before it means anything. Do "
                  "not pick this set up bare. See docs/reference_update/"
                  "Gayini_learning_L01_unit_of_analysis.md. Treatment is also perfectly nested "
                  "within the Bala block, so a whole-farm contrast is confounded with block.")
        con.execute("UPDATE dim_management_zone SET reference_set_member = "
                    "CASE WHEN grazing_excluded = 1 THEN 1 ELSE 0 END, "
                    "reference_set_rule = ?, reference_set_caveat = ?", (rule, caveat))
        con.commit()
    finally:
        con.close()

    # ---- report -----------------------------------------------------------
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    print(f"\nv_always_green_sweep rows: "
          f"{con.execute('SELECT COUNT(*) FROM v_always_green_sweep').fetchone()[0]}")
    print("\n  by (metric, scope, grid):")
    for r in con.execute("SELECT metric, scope, grid_epsg, COUNT(*) n, "
                         "SUM(is_selected_threshold) sel FROM v_always_green_sweep "
                         "GROUP BY 1,2,3 ORDER BY 1,2"):
        print(f"    {r[0]:<18} {r[1]:<22} epsg {r[2]}  n={r[3]:>3}  selected={r[4]}")

    print("\n  selected rows (operational LiDAR inputs, NOT headlines):")
    for r in con.execute("SELECT metric, scope, threshold, n_pixels, area_ha, grid_epsg, "
                         "selection_role FROM v_always_green_sweep "
                         "WHERE is_selected_threshold = 1 ORDER BY metric, scope"):
        print(f"    {r[0]:<18} {r[1]:<22} t={r[2]:<3} n={r[3]:>7,} "
              f"{r[4]:>10,.2f} ha  epsg {r[5]}  role={r[6]}")

    bad = con.execute("SELECT metric, scope, COUNT(*) FROM v_always_green_sweep "
                      "WHERE is_selected_threshold = 1 GROUP BY 1,2 HAVING COUNT(*) <> 1").fetchall()
    print(f"\n  ACCEPTANCE exactly one selected per (scope, metric): "
          f"{'PASS' if not bad else 'FAIL ' + str(bad)}")
    print(f"  metric populated on every row: "
          f"{con.execute('SELECT COUNT(*) FROM v_always_green_sweep WHERE metric IS NULL').fetchone()[0] == 0}")
    print(f"  scope_filter_sql populated:    "
          f"{con.execute('SELECT COUNT(*) FROM v_always_green_sweep WHERE scope_filter_sql IS NULL').fetchone()[0] == 0}")

    print("\n  reference set pinned:")
    for r in con.execute("SELECT zone_fid, zone_name, reference_set_member, has_rap_plots "
                         "FROM dim_management_zone WHERE reference_set_member = 1 ORDER BY zone_fid"):
        print(f"    fid {r[0]}  {r[1]:<12} member={r[2]}  has_rap_plots={r[3]}")
    print(f"    non-members: "
          f"{con.execute('SELECT COUNT(*) FROM dim_management_zone WHERE reference_set_member = 0').fetchone()[0]}")

    print("\n  total-cover reproduction check against the Context table:")
    for t, want in ((50, 40935.96), (65, 20045.92), (75, 8300.41), (80, 4179.29)):
        got = con.execute("SELECT area_ha FROM v_always_green_sweep WHERE threshold=? AND "
                          "scope='non_treed' AND metric='total_cover_floor'", (t,)).fetchone()[0]
        print(f"    t={t}: {got:,.2f} ha vs {want:,.2f}  {'OK' if abs(got - want) < 0.01 else 'DIFFER'}")
    con.close()


if __name__ == "__main__":
    main()
