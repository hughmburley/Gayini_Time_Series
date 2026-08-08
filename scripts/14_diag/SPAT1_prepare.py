#!/usr/bin/env python
"""SPAT-1 stage 0 - spatial machinery at the Python/R boundary.

Ruling AS: estimation lives in R. This builds the geometry that Moran's I needs and
does no estimation of any kind. It writes three things R reads:

  1. part centroids, so an inverse-distance weight can be built
  2. the full 115 x 115 centroid distance matrix, in metres
  3. polygon adjacency - which parts actually share a boundary

THE PAIR TABLE CARRIES `same_paddock`, AND THAT COLUMN IS THE WHOLE TASK. Two parts of
one paddock are neighbours by construction: they were cut from the same polygon and the
bootstrap already treats them as one unit. The exposure the design seat named is whether
residuals correlate ACROSS paddocks, so every statistic is computed twice - once with
all pairs and once with within-paddock pairs excluded. Only the second answers the
question.

Adjacency uses a small positive buffer rather than exact touching: these polygons come
from a raster-derived dissolve and coordinate noise means shared edges are not always
topologically exact. The tolerance is stated on the output.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import geopandas as gpd
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "diag"
ANA = OUT / "analysis"

GPKG = ROOT / "Output" / "spatial_8058" / "PARTREG_part_residuals.gpkg"
BETWEEN = ANA / "DIAG1_between_parts.csv"

# Shared-edge tolerance. Raster-derived polygons rarely touch exactly; 1 m on a
# 24.970268 m grid is well below one cell and cannot join parts that are truly apart.
ADJ_TOL_M = 1.0


def sha256_first50(path: Path) -> str:
    cap, h = 50 * 1024 * 1024, hashlib.sha256()
    with open(path, "rb") as f:
        while cap > 0:
            b = f.read(min(1 << 20, cap))
            if not b:
                break
            h.update(b)
            cap -= len(b)
    return h.hexdigest()


def main() -> int:
    ANA.mkdir(parents=True, exist_ok=True)

    g = gpd.read_file(GPKG)
    assert len(g) == 115, len(g)
    assert g.crs is not None and g.crs.to_epsg() == 8058, f"expected EPSG:8058, got {g.crs}"

    # the analysis CSV is the authority for the residuals; the gpkg supplies geometry
    b = pd.read_csv(BETWEEN)
    b = b[b.period == "whole_record"]
    assert set(b.part_id) == set(g.part_id), "part_id sets differ between gpkg and CSV"

    g = g.set_index("part_id").loc[list(b.part_id)].reset_index()
    cen = g.geometry.centroid

    parts = pd.DataFrame({
        "part_id": g.part_id, "zone_fid": g.zone_fid, "paddock_name": g.paddock_name,
        "community_short": g.community_short, "n_pixels_part": g.n_pixels_part,
        "area_ha": g.area_ha, "centroid_x_8058": cen.x.values, "centroid_y_8058": cen.y.values,
    })
    parts["support_level"] = "pixel"
    parts["unit"] = "part (paddock x community)"
    parts["period_label"] = "geometry is time-invariant; residuals joined per period"
    parts["weighting"] = "pixel-weighted by the part's cell count where used"
    parts["estimand"] = ("GEOMETRY ONLY - no estimate. Centroids and adjacency for the "
                         "spatial-dependence diagnostic")
    parts["crs"] = "EPSG:8058 (GDA2020 / NSW Lambert), metres"
    parts.to_csv(ANA / "SPAT1_part_centroids.csv", index=False, lineterminator="\n")

    # ---- full pair table ---------------------------------------------------------
    xy = np.c_[cen.x.values, cen.y.values]
    d = np.sqrt(((xy[:, None, :] - xy[None, :, :]) ** 2).sum(-1))

    # adjacency: buffer once, then a spatial join of the buffered set against the raw set
    buf = g.geometry.buffer(ADJ_TOL_M)
    adj = np.zeros((115, 115), dtype=bool)
    sidx = g.sindex
    for i, geom in enumerate(buf):
        for j in sidx.query(geom, predicate="intersects"):
            if i != j:
                adj[i, j] = True
    adj |= adj.T   # force symmetry; a shared edge is shared both ways

    iu = np.triu_indices(115, k=1)
    pid = parts.part_id.values
    zf = parts.zone_fid.values
    pairs = pd.DataFrame({
        "part_i": pid[iu[0]], "part_j": pid[iu[1]],
        "zone_fid_i": zf[iu[0]], "zone_fid_j": zf[iu[1]],
        "distance_m": d[iu],
        "adjacent": adj[iu],
    })
    pairs["same_paddock"] = pairs.zone_fid_i.values == pairs.zone_fid_j.values
    pairs["community_i"] = parts.community_short.values[iu[0]]
    pairs["community_j"] = parts.community_short.values[iu[1]]
    pairs["same_community"] = pairs.community_i == pairs.community_j
    # 0/1 ints, not True/False: R reads a Python boolean column as CHARACTER, and
    # as.numeric() on it returns NA silently rather than erroring where it is used.
    for c in ("adjacent", "same_paddock", "same_community"):
        pairs[c] = pairs[c].astype(int)
    pairs["support_level"] = "pixel"
    pairs["unit"] = "pair of parts"
    pairs["period_label"] = "geometry is time-invariant"
    pairs["weighting"] = "unweighted - this table is geometry, not an estimate"
    pairs["estimand"] = ("GEOMETRY ONLY - no estimate. Neighbour definitions for the "
                         "spatial-dependence diagnostic")
    pairs.to_csv(ANA / "SPAT1_pairs.csv", index=False, lineterminator="\n")

    n_adj = int(pairs.adjacent.sum())
    n_adj_cross = int((pairs.adjacent & ~pairs.same_paddock).sum())
    isolated = [p for p, k in zip(pid, adj.sum(1)) if k == 0]
    isolated_cross = [p for p, k in zip(pid, (adj & (zf[:, None] != zf[None, :])).sum(1)) if k == 0]

    print(f"  parts                     115, EPSG:8058")
    print(f"  centroid separation       min {d[iu].min():,.0f} m  median {np.median(d[iu]):,.0f} m"
          f"  max {d[iu].max():,.0f} m")
    print(f"  adjacent pairs            {n_adj}  ({n_adj_cross} cross-paddock, "
          f"{n_adj - n_adj_cross} within-paddock)")
    print(f"  parts with no neighbour   {len(isolated)}  "
          f"(no CROSS-paddock neighbour: {len(isolated_cross)})")
    if isolated:
        print(f"    isolated: {', '.join(isolated)}")

    rows = [{"role": "input", "name": GPKG.name, "path": GPKG.relative_to(ROOT).as_posix(),
             "rows": 115, "sha256_first50": sha256_first50(GPKG), "note": "part geometry, EPSG:8058"},
            {"role": "input", "name": BETWEEN.name, "path": BETWEEN.relative_to(ROOT).as_posix(),
             "rows": len(pd.read_csv(BETWEEN)), "sha256_first50": sha256_first50(BETWEEN),
             "note": "residuals; the authority, gpkg supplies geometry only"}]
    for n in ("SPAT1_part_centroids.csv", "SPAT1_pairs.csv"):
        p = ANA / n
        rows.append({"role": "boundary file written for R", "name": n,
                     "path": p.relative_to(ROOT).as_posix(), "rows": len(pd.read_csv(p)),
                     "sha256_first50": sha256_first50(p),
                     "note": f"adjacency tolerance {ADJ_TOL_M} m" if "pairs" in n else "centroids"})
    pd.DataFrame(rows).to_csv(OUT / "SPAT1_inputs.csv", index=False, lineterminator="\n")
    print(f"  [wrote] SPAT1_part_centroids.csv, SPAT1_pairs.csv ({len(pairs):,} pairs), SPAT1_inputs.csv")
    return 0


if __name__ == "__main__":
    sys.exit(main())
