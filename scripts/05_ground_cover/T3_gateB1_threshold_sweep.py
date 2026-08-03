"""T3 Gate B1 - full always-green threshold sweep and break characterisation.

Spec: docs/T3_always_green_threshold.md v3, Gate B1.

Sweeps the total-cover floor (census veg_p05) from 40 to 90 in steps of 1, for the
non_treed and all_pixel scopes SEPARATELY, and characterises the shape of the decline.

Read-only against the DB. Writes CSVs under Output/tables/ only; no DB object is
created or modified here (that is Gate C, after the Gate D sign-off).

THE NULL PREDICATE (T3 Gate A finding F2). The census percentile columns encode
missing as float NaN, NOT SQL NULL: `veg_p05 IS NULL` matches 0 of 1,080,157 rows and
would silently admit all 155 NaN pixels. Every filter here uses `NOT isnan(...)`, and
numpy comparisons against NaN are False, so the pixel masks exclude them either way.

CONNECTIVITY. Components are labelled with 8-connectivity (queen) as the primary
figure, because a diagonal touch is a real ecological connection at 25 m. The
4-connectivity (rook) count is reported alongside as a sensitivity column so the
choice is visible rather than buried - it is a real degree of freedom in any
"how many refugia patches" number.

Areas come from gayini_params.PIXEL_AREA_HA (derived). No area constant is typed here.
"""
from __future__ import annotations

import sys
from pathlib import Path

import duckdb
import numpy as np
import rasterio
from scipy import ndimage

sys.path.insert(0, str(Path("scripts") / "lib"))
import gayini_params as gp  # noqa: E402

CENSUS_PARQUET = Path("Output") / "census" / "gayini_pixel_census_8058.parquet"
GRID_TIF = Path("Output") / "rasters" / "veg_regime_class_8058.tif"
OUT_DIR = Path("Output") / "tables"
RUN_ID = "T3_gateB1"

THRESHOLDS = list(range(40, 91))          # 40..90 inclusive, step 1
MIN_COMPONENT_HA = 5.0
CANDIDATES = [70, 75, 78, 80, 85]         # where the sensitivity columns are reported

SCOPES = {
    # label:            (numpy mask builder, the literal SQL that defines it)
    "non_treed": gp.SCOPE_NON_TREED,
    "all_pixel": gp.SCOPE_ALL_PIXEL,
}

MIN_COMPONENT_PX = int(np.ceil(MIN_COMPONENT_HA / gp.PIXEL_AREA_HA))


def load_census():
    """Census columns plus the row/col of each pixel on the canonical 8058 grid."""
    con = duckdb.connect()
    df = con.execute(f"""
        SELECT x_8058, y_8058, veg_p05, flood_freq_pct, veg_regime_class,
               treed_context_flag, regime_band
        FROM read_parquet('{CENSUS_PARQUET.as_posix()}')
    """).fetchdf()

    with rasterio.open(GRID_TIF) as src:
        transform, height, width = src.transform, src.height, src.width
    res_x, res_y = abs(transform.a), abs(transform.e)
    col = np.floor((df["x_8058"].to_numpy() - transform.c) / res_x).astype(np.int32)
    row = np.floor((transform.f - df["y_8058"].to_numpy()) / res_y).astype(np.int32)

    assert col.min() >= 0 and col.max() < width, "census x falls outside the grid"
    assert row.min() >= 0 and row.max() < height, "census y falls outside the grid"
    # every census pixel must land on its own cell - a collision means the row/col
    # arithmetic is wrong, and every component count downstream would be wrong with it
    flat = row.astype(np.int64) * width + col.astype(np.int64)
    assert np.unique(flat).size == flat.size, "census pixels collide on the grid"

    return df, row, col, height, width


def sweep():
    df, row, col, height, width = load_census()

    p05 = df["veg_p05"].to_numpy(dtype=np.float64)
    ff = df["flood_freq_pct"].to_numpy(dtype=np.float64)
    treed = df["treed_context_flag"].to_numpy(dtype=bool)
    band = df["regime_band"].to_numpy(dtype=object)

    finite = ~np.isnan(p05)                                  # the NaN predicate, F2
    scope_mask = {
        "non_treed": (~treed) & (band != "context") & finite,
        "all_pixel": finite,
    }
    print(f"scope sizes (finite p05 only): "
          f"non_treed={scope_mask['non_treed'].sum():,} "
          f"all_pixel={scope_mask['all_pixel'].sum():,}")
    print(f"MIN_COMPONENT_PX = {MIN_COMPONENT_PX} "
          f"(>= {MIN_COMPONENT_HA} ha at {gp.PIXEL_AREA_HA:.9f} ha/px)")

    grid = np.zeros((height, width), dtype=bool)
    s8 = ndimage.generate_binary_structure(2, 2)             # queen
    s4 = ndimage.generate_binary_structure(2, 1)             # rook

    def n_components(sel, structure):
        grid[:] = False
        grid[row[sel], col[sel]] = True
        lab, n = ndimage.label(grid, structure=structure)
        if n == 0:
            return 0
        sizes = np.bincount(lab.ravel())[1:]
        return int((sizes >= MIN_COMPONENT_PX).sum())

    rows_out = []
    for scope, sql in SCOPES.items():
        base = scope_mask[scope]
        for t in THRESHOLDS:
            sel = base & (p05 >= t)                          # NaN >= t is False
            n = int(sel.sum())
            ffv = ff[sel]
            rows_out.append({
                "threshold": t,
                "scope": scope,
                "metric": "total_cover_floor",
                "n_pixels": n,
                "area_ha": n * gp.PIXEL_AREA_HA,
                "pct_of_mapped": 100.0 * n * gp.PIXEL_AREA_HA / gp.MAPPED_AREA_HA,
                "pct_of_farm_total": 100.0 * n * gp.PIXEL_AREA_HA / gp.TRUE_FARM_HA,
                "flood_freq_mean": float(np.mean(ffv)) if n else np.nan,
                "flood_freq_median": float(np.median(ffv)) if n else np.nan,
                "n_components_ge_5ha": n_components(sel, s8),
                "n_components_ge_5ha_rook": (n_components(sel, s4)
                                             if t in CANDIDATES else None),
                "pixel_area_ha": gp.PIXEL_AREA_HA,
                "scope_filter_sql": sql,
                "support_level": "pixel",
                "aggregation_unit": "pixel",
                "connectivity": "8 (queen)",
                "run_id": RUN_ID,
            })
        print(f"  {scope}: swept {len(THRESHOLDS)} thresholds")

    import pandas as pd
    out = pd.DataFrame(rows_out)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out.to_csv(OUT_DIR / "T3_gateB1_threshold_sweep.csv", index=False)
    print(f"wrote {OUT_DIR / 'T3_gateB1_threshold_sweep.csv'} ({len(out)} rows)")

    # ---- upper-tail histogram, bin width 1, for the 80->85 collapse -------------
    tail_rows = []
    for scope in SCOPES:
        v = p05[scope_mask[scope]]
        for lo in range(75, 100):
            n = int(((v >= lo) & (v < lo + 1)).sum())
            tail_rows.append({"scope": scope, "bin_lo": lo, "bin_hi": lo + 1,
                              "n_pixels": n, "area_ha": n * gp.PIXEL_AREA_HA})
    pd.DataFrame(tail_rows).to_csv(OUT_DIR / "T3_gateB1_p05_upper_tail.csv", index=False)
    print(f"wrote {OUT_DIR / 'T3_gateB1_p05_upper_tail.csv'}")

    # ---- elasticity: d ln(area) / d threshold, central difference --------------
    el_rows = []
    for scope in SCOPES:
        sub = out[out["scope"] == scope].sort_values("threshold").reset_index(drop=True)
        ln_a = np.log(sub["area_ha"].to_numpy())
        for i, t in enumerate(sub["threshold"]):
            if i == 0 or i == len(sub) - 1 or not np.isfinite(ln_a[i]):
                continue
            d = (ln_a[i + 1] - ln_a[i - 1]) / 2.0
            el_rows.append({
                "scope": scope, "threshold": int(t),
                "area_ha": float(sub["area_ha"][i]),
                "dln_area_per_pp": float(d),
                "pct_area_lost_per_pp": float(100.0 * (1 - np.exp(d))),
            })
    pd.DataFrame(el_rows).to_csv(OUT_DIR / "T3_gateB1_elasticity.csv", index=False)
    print(f"wrote {OUT_DIR / 'T3_gateB1_elasticity.csv'}")

    return out, pd.DataFrame(el_rows), pd.DataFrame(tail_rows)


if __name__ == "__main__":
    gp.validate()
    sweep_df, el_df, tail_df = sweep()

    print("\n=== non_treed, the spec's Context rows ===")
    nt = sweep_df[sweep_df["scope"] == "non_treed"].set_index("threshold")
    for t in (50, 55, 60, 65, 70, 75, 78, 80, 85):
        r = nt.loc[t]
        print(f"  p05>={t:>2}  n={r['n_pixels']:>7,}  area={r['area_ha']:>12,.2f} ha  "
              f"mapped={r['pct_of_mapped']:>6.2f}%  farm={r['pct_of_farm_total']:>6.2f}%  "
              f"ff_mean={r['flood_freq_mean']:>5.2f}  ff_med={r['flood_freq_median']:>5.2f}  "
              f"comp>=5ha={r['n_components_ge_5ha']:>4}")

    print("\n=== where does mean flood frequency peak? ===")
    for scope in ("non_treed", "all_pixel"):
        s = sweep_df[sweep_df["scope"] == scope]
        i = s["flood_freq_mean"].idxmax()
        print(f"  {scope}: peak {s.loc[i, 'flood_freq_mean']:.2f}% at threshold "
              f"{int(s.loc[i, 'threshold'])}, n = {int(s.loc[i, 'n_pixels']):,} px "
              f"({s.loc[i, 'area_ha']:,.1f} ha)")

    print("\n=== elasticity around the candidate cuts (non_treed) ===")
    e = el_df[el_df["scope"] == "non_treed"].set_index("threshold")
    for t in (70, 75, 78, 80, 82, 84):
        if t in e.index:
            print(f"  t={t}: {e.loc[t, 'pct_area_lost_per_pp']:.1f}% of area lost "
                  f"per +1 pp of threshold  (area {e.loc[t, 'area_ha']:,.0f} ha)")

    print("\n=== upper tail, non_treed, bin width 1 ===")
    tt = tail_df[(tail_df["scope"] == "non_treed") & (tail_df["bin_lo"] >= 75)]
    for _, r in tt.iterrows():
        if r["n_pixels"] or r["bin_lo"] < 92:
            print(f"  [{int(r['bin_lo'])}, {int(r['bin_hi'])})  "
                  f"n={int(r['n_pixels']):>7,}  {r['area_ha']:>10,.1f} ha")
