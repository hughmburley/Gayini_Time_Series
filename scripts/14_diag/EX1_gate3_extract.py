#!/usr/bin/env python
"""EXEMPLAR-1 Gate 3 - extract the per-cell census table the design-seat check needs.

DATA PREPARATION ONLY. Ruling AS: every statistic in this check is computed in R from
the parquet this writes. Nothing here means, bins, correlates or fits.

The check being set up is section 1 of the spec: mean of each cell's temporal cover
percentiles, by community, against between-year flood frequency. Those are DESIGN-SEAT
PREDICTIONS, not facts, and CC's independently computed values take precedence.

FOUR RASTERS, ONE GRID. All are EPSG:8058 at 24.970268 m and are asserted to share an
exact shape and transform before anything is read - a silent half-cell offset between
the class raster and the percentile rasters would misassign every cell near a boundary
and still produce plausible numbers.

SCOPE. Codes 11-33 only: treed_context_flag = 0 AND regime_band <> 'context'. The flag
alone admits code 50 (Other / minor units) and gives ten strata, not nine.
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio

ROOT = Path(__file__).resolve().parents[2]
R = ROOT / "Output" / "rasters"
OUT = ROOT / "Output" / "diag" / "analysis"

SRC = {
    "veg_regime_class": R / "veg_regime_class_8058.tif",
    "flood_freq": R / "background_flood_frequency_8058.tif",
    "p05": R / "veg_percentiles_8058/total_veg_p05_8058.tif",
    "p50": R / "veg_percentiles_8058/total_veg_p50_8058.tif",
}

COMMUNITY = {1: "Aeolian Chenopod Shrublands",
             2: "Riverine Chenopod Shrublands",
             3: "Inland Floodplain Shrublands / Swamps"}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    ref = None
    arrays = {}
    for name, path in SRC.items():
        with rasterio.open(path) as r:
            key = (r.width, r.height, tuple(round(v, 9) for v in r.transform[:6]),
                   r.crs.to_epsg())
            if ref is None:
                ref, ref_name = key, name
            elif key != ref:
                print(f"  GRID MISMATCH between {ref_name} and {name}:")
                print(f"    {ref_name}: {ref}")
                print(f"    {name}: {key}")
                return 1          # halt condition: grid mismatch
            arrays[name] = r.read(1)
            if name != "veg_regime_class":
                nod = r.nodata
                if nod is not None and not np.isnan(nod):
                    arrays[name] = np.where(arrays[name] == nod, np.nan, arrays[name])
    print(f"  4 rasters share one grid: {ref[0]} x {ref[1]}, EPSG:{ref[3]}, "
          f"{abs(ref[2][0]):.6f} m")

    cls = arrays["veg_regime_class"]
    keep = np.isin(cls, [11, 12, 13, 21, 22, 23, 31, 32, 33])
    n_keep = int(keep.sum())
    print(f"  census footprint, codes 11-33: {n_keep:,} cells "
          f"(expected 988,831; {'MATCH' if n_keep == 988831 else 'DIFFERS'})")
    print(f"    treed_context_flag = 0 alone would give "
          f"{int(np.isin(cls, [11,12,13,21,22,23,31,32,33,50]).sum()):,} - the ten-strata trap")

    code = cls[keep].astype(np.int16)
    d = pd.DataFrame({
        "class_code": code,
        "community": pd.Series(code // 10).map(COMMUNITY).values,
        "wetness_band": pd.Series(code % 10).map({1: "low", 2: "mid", 3: "high"}).values,
        "flood_freq_pct": arrays["flood_freq"][keep].astype(np.float32),
        "temporal_p05": arrays["p05"][keep].astype(np.float32),
        "temporal_p50": arrays["p50"][keep].astype(np.float32),
    })

    # MIN_SEASONS = 50 shows up here as NaN percentiles inside the footprint. Ruling BT
    # says the count is 2 of 988,831; it is counted rather than asserted.
    n_nan_p05 = int(d.temporal_p05.isna().sum())
    n_nan_p50 = int(d.temporal_p50.isna().sum())
    n_nan_ff = int(d.flood_freq_pct.isna().sum())
    print(f"  cells with no temporal p05 inside the footprint: {n_nan_p05} "
          f"(Ruling BT predicts 2)")
    print(f"  cells with no temporal p50: {n_nan_p50};  no flood frequency: {n_nan_ff}")
    if n_nan_p05:
        w = d.loc[d.temporal_p05.isna(), "flood_freq_pct"]
        print(f"    their flood frequency: {', '.join(f'{v:.1f}%' for v in w)}")

    # csv.gz, not parquet: R on this machine has no arrow and there is no network to
    # install it. One encoding for one consumer beats writing the same table twice -
    # two copies of one artefact is the project's discrepancy class #1. The registered
    # per-pixel parquet convention applies to the census asset, not to a task-local
    # intermediate like this one.
    out = OUT / "EX1_gate3_census_cells.csv.gz"
    d.to_csv(out, index=False, compression="gzip", lineterminator="\n")
    print(f"  [wrote] {out.name}  {len(d):,} rows, {out.stat().st_size / 1e6:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
