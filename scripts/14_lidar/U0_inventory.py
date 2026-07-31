#!/usr/bin/env python3
"""Task U · Gate U0.2-U0.7 — decode, metadata, tiered distributions, checksums.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.1.md, Gate U0.

Read-only against Input/gayini_lidar. Writes two CSVs to Output/tables/ and nothing
else. Registers nothing - registration is Gate U1.

U0.2  decode every GeoTIFF against the JRSRP QVF convention
U0.3  exact headers for every GeoTIFF (rasterio; there is no GDAL CLI here)
U0.4  value distributions, TIERED:
        exact      - 10 m `bbh` and the 5 m height percentiles
        decimated  - the 50 cm products, by systematic STRIDED subsampling
      Strided, never averaged: these distributions are zero-spiked and an averaged
      overview smears the spike, which on a floodplain is the one statistic that
      matters. Overview presence is recorded but stats are NEVER read from them.
      Every decimated row is marked recon_only=1 and may not reach a deliverable.
U0.5  sha256_first50() + file size
U0.6  capture-date metadata hunt (sidecars, readmes, TIFF tags)
U0.7  product -> question mapping (emitted in the change report, not here)

Usage:  python scripts/14_lidar/U0_inventory.py
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
from pathlib import Path

import numpy as np
import rasterio

ROOT = Path(__file__).resolve().parents[2]
LIDAR = ROOT / "Input" / "gayini_lidar"
OUT_INV = ROOT / "Output" / "tables" / "taskU_gateU0_inventory.csv"
OUT_DIST = ROOT / "Output" / "tables" / "taskU_gateU0_distributions.csv"

# --- systematic decimation for the 50 cm tier ------------------------------
# Sampled on a 2-D BLOCK stride so coverage stays spatially uniform across the
# whole mosaic (sampling every Nth block in one direction only would skip whole
# regions of floodplain), then strided again inside each sampled block.
BLOCK_STRIDE = 8      # take 1 block in 8, in x AND y  -> 1/64 of blocks
PIXEL_STRIDE = 4      # inside a sampled block, 1 px in 4, in x AND y -> 1/16
SAMPLING_FRACTION = 1 / (BLOCK_STRIDE ** 2 * PIXEL_STRIDE ** 2)   # 1/1024

# --- JRSRP QVF code tables, transcribed verbatim from ----------------------
# https://jrsrp.gitlab.io/sys/meta_info/lidar_filename_codes/
PLATFORM = {"ap": "airborne platform", "gp": "ground platform",
            "sb": "spaceborne", "is": "IceSAT"}
INSTRUMENT = {"l1": "Leica ALS-50", "l4": "Leica ALS-80"}
PRODUCT = {"dr": "time-of-flight discrete return lidar",
           "wf": "time-of-flight waveform lidar",
           "cw": "continuous wave (phase-shift) lidar"}
STAGE = {
    "bb0": "Raster DEM product, natural neighbour interpolation of classified ground points",
    "bb1": "Gridded maximum height of returns above ground within a pixel (NN interpolated)",
    "bb2": "Gridded intensity of the return corresponding to the maximum height in that pixel",
    "bb3": "Mask of pixels which have at least one ground return",
    "bb4": "Classification of non-ground returns",
    "bb5": "First return density",
    "bb8": "1st percentile of return heights above ground surface within a pixel",
    "bb9": "5th percentile of return heights above ground surface within a pixel",
    "bba": "25th percentile of return heights above ground surface within a pixel",
    "bbb": "50th percentile of return heights above ground surface within a pixel",
    "bbc": "75th percentile of return heights above ground surface within a pixel",
    "bbd": "95th percentile of return heights above ground surface within a pixel",
    "bbe": "99th percentile of return heights above ground surface within a pixel",
    "bbh": "Foliage Projective Cover (%); refer Fisher et al. 2020",
    "bbi": "GDALDEM hillshade of bb0 (azimuth 315, altitude 45)",
    "bbm": "Canopy Surface Model (CSM) - interpolated ALL non-ground returns, DEM subtracted",
    "bbn": "Canopy Height Model (CHM), pit-free algorithm of Khosravipour et al. 2014",
}
# Projection codes: the JRSRP filename_codes page does not publish this table in
# fetchable form, so these are RESOLVED FROM EACH FILE'S OWN CRS and cross-checked
# against the code. The file is the authority; a mismatch aborts.
PROJECTION = {"m5": 28355, "d4": 7854, "d5": 7855}

# 47-char QVF stem: ss ii pp _ rREGION _ YYYY _ SSSPP _ rRES
STEM_RE = re.compile(
    r"^(?P<platform>[a-z]{2})(?P<instrument>[a-z0-9]{2})(?P<product>[a-z]{2})"
    r"_r(?P<region>[a-z]+)_(?P<epoch>\d{4})_(?P<stage>bb[0-9a-z])(?P<proj>[a-z0-9]{2})"
    r"_r(?P<res>\d+)(?P<res_unit>cm|m)$")

CLASSIFIED_STAGES = {"bb3", "bb4"}   # nearest-neighbour on reprojection


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - the project's one convention."""
    h = hashlib.sha256()
    read, cap = 0, 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            read += len(chunk)
    return h.hexdigest()


def decode(stem: str) -> dict:
    m = STEM_RE.match(stem)
    if not m:
        raise SystemExit(f"ABORT: {stem!r} does not match the QVF stem convention")
    d = m.groupdict()
    res_m = int(d["res"]) / (100.0 if d["res_unit"] == "cm" else 1.0)
    return dict(
        platform_code=d["platform"], platform=PLATFORM.get(d["platform"], "UNKNOWN"),
        instrument_code=d["instrument"],
        instrument=INSTRUMENT.get(d["instrument"], "UNKNOWN"),
        product_code=d["product"], product=PRODUCT.get(d["product"], "UNKNOWN"),
        region=d["region"], epoch=int(d["epoch"]),
        stage_code=d["stage"], stage_meaning=STAGE.get(d["stage"], "UNKNOWN"),
        projection_code=d["proj"], projection_epsg_from_code=PROJECTION.get(d["proj"]),
        nominal_res_m=res_m)


def exact_stats(src) -> tuple[np.ndarray, int]:
    a = src.read(1)
    if src.nodata is None:
        return a.ravel(), int(a.size)
    v = a[a != src.nodata]
    return v, int(a.size)


def decimated_stats(src) -> tuple[np.ndarray, int, int]:
    """Systematic 2-D block-strided sample. Never averages, never reads overviews."""
    bh, bw = src.block_shapes[0]
    keep = []
    for _, w in src.block_windows(1):
        # block index derived from the window offset, not from enumeration order
        by, bx = w.row_off // bh, w.col_off // bw
        if by % BLOCK_STRIDE == 0 and bx % BLOCK_STRIDE == 0:
            keep.append(w)
    chunks, n_seen = [], 0
    for w in keep:
        a = src.read(1, window=w)[::PIXEL_STRIDE, ::PIXEL_STRIDE]
        n_seen += a.size
        chunks.append(a.ravel() if src.nodata is None else a[a != src.nodata].ravel())
    v = np.concatenate(chunks) if chunks else np.array([], dtype=src.dtypes[0])
    return v, n_seen, len(keep)


def summarise(v: np.ndarray) -> dict:
    """Deciles etc. over the FINITE values only.

    `bbm` (2021 d5) carries NaN inside a float32 CSM, which silently poisons
    min/max/mean/percentile. Non-finite values are excluded and COUNTED, because a
    delivered product containing NaN is itself a finding, not a nuisance.
    """
    blank = {k: "" for k in ("vmin", "vmax", "vmean", "n_zero", "pct_zero",
                             "n_nonfinite", "pct_nonfinite")}
    blank |= {f"d{i}": "" for i in range(1, 10)}
    if v.size == 0:
        return blank
    f = v.astype("float64")
    finite = np.isfinite(f)
    n_nf = int((~finite).sum())
    out = dict(n_nonfinite=n_nf, pct_nonfinite=round(100.0 * n_nf / f.size, 6))
    f = f[finite]
    if f.size == 0:
        return blank | out
    d = np.percentile(f, [10, 20, 30, 40, 50, 60, 70, 80, 90])
    out |= dict(vmin=float(f.min()), vmax=float(f.max()),
                vmean=round(float(f.mean()), 4),
                n_zero=int((f == 0).sum()), pct_zero=round(100.0 * (f == 0).mean(), 4))
    out |= {f"d{i}": round(float(d[i - 1]), 4) for i in range(1, 10)}
    return out


def capture_date_hunt() -> list[dict]:
    """U0.6 - anything carrying a flight date WITHIN the year."""
    hits = []
    for p in sorted(LIDAR.rglob("*")):
        if p.is_dir():
            continue
        if p.suffix.lower() in {".tif", ".tiff"}:
            continue
        hits.append(dict(kind="sidecar_or_doc", path=str(p.relative_to(ROOT)),
                         bytes=p.stat().st_size, detail=""))
    for p in sorted(LIDAR.rglob("*.tif")):
        with rasterio.open(p) as s:
            tags = {k: v for k, v in s.tags().items()}
            tags.update({f"IMAGE_STRUCTURE:{k}": v
                         for k, v in s.tags(ns="IMAGE_STRUCTURE").items()})
        dated = {k: v for k, v in tags.items()
                 if re.search(r"date|time|acqui|flight|captur|survey", k, re.I)
                 or (isinstance(v, str) and re.search(r"\b(19|20)\d{2}[-/ ]\d{1,2}[-/ ]\d{1,2}\b", v))}
        if dated:
            hits.append(dict(kind="tiff_tag", path=str(p.relative_to(ROOT)),
                             bytes=p.stat().st_size, detail=json.dumps(dated)))
    return hits


def main() -> None:
    tifs = sorted(LIDAR.rglob("*.tif"))
    others = sorted(q for q in LIDAR.rglob("*") if q.is_file() and q.suffix.lower() != ".tif")
    print("=" * 78)
    print("Gate U0.2-U0.6 - inventory")
    print("=" * 78)
    print(f"GeoTIFFs        : {len(tifs)}")
    print(f"non-GeoTIFF files: {len(others)}  "
          f"({sorted({q.suffix.lower() for q in others})})")
    print(f"total bytes     : {sum(q.stat().st_size for q in LIDAR.rglob('*') if q.is_file()):,}")
    print()

    inv_rows, dist_rows = [], []
    for p in tifs:
        st = p.stat()
        d = decode(p.stem)
        with rasterio.open(p) as s:
            epsg = s.crs.to_epsg() if s.crs else None
            if d["projection_epsg_from_code"] != epsg:
                raise SystemExit(
                    f"ABORT: {p.name} projection code {d['projection_code']!r} implies "
                    f"EPSG:{d['projection_epsg_from_code']} but the file carries EPSG:{epsg}. "
                    "The file is the authority - fix the PROJECTION table, do not proceed.")
            ov = s.overviews(1)
            tier = "exact" if d["nominal_res_m"] >= 5.0 else "decimated"
            hdr = dict(
                driver=s.driver, width=s.width, height=s.height, band_count=s.count,
                dtype=s.dtypes[0], nodata=s.nodata, crs=str(s.crs), crs_epsg=epsg,
                res_x=s.res[0], res_y=s.res[1],
                xmin=s.bounds.left, ymin=s.bounds.bottom,
                xmax=s.bounds.right, ymax=s.bounds.top,
                transform=json.dumps([round(v, 6) for v in s.transform[:6]]),
                block_shape=json.dumps(list(s.block_shapes[0])),
                overviews=json.dumps(ov), has_overviews=int(bool(ov)))

            if tier == "exact":
                v, n_total = exact_stats(s)
                n_seen, n_blocks = n_total, ""
            else:
                v, n_seen, n_blocks = decimated_stats(s)
                n_total = s.width * s.height

        px_area_ha = (hdr["res_x"] * hdr["res_y"]) / 1e4   # DERIVED, never typed
        valid_frac = (v.size / n_seen) if n_seen else 0.0
        row = dict(
            file=p.name, folder=p.parent.name,
            path=str(p.relative_to(ROOT)), bytes=st.st_size,
            mb=round(st.st_size / 1024 ** 2, 2),
            checksum_sha256_first50=sha256_first50(p),
            checksum_convention="sha256_first50",
            **d, **hdr,
            stats_tier=tier, recon_only=int(tier == "decimated"),
            decimation_block_stride=BLOCK_STRIDE if tier == "decimated" else "",
            decimation_pixel_stride=PIXEL_STRIDE if tier == "decimated" else "",
            # NOMINAL is what the stride design intends; ACTUAL is what it realised.
            # They diverge whenever a file is striped rather than square-tiled - the
            # d5 delivery is, by up to 50x. Only the actual figure may be quoted.
            sampling_fraction_nominal=round(SAMPLING_FRACTION, 8) if tier == "decimated" else 1.0,
            sampling_fraction_actual=round(n_seen / n_total, 8) if n_total else "",
            block_sampling_uniform=int(tier == "exact"
                                       or abs(n_seen / n_total - SAMPLING_FRACTION)
                                       <= 0.1 * SAMPLING_FRACTION) if n_total else "",
            blocks_sampled=n_blocks,
            n_pixels_total=n_total, n_pixels_inspected=n_seen, n_valid_inspected=int(v.size),
            valid_fraction_inspected=round(valid_frac, 6),
            valid_area_ha=round(valid_frac * n_total * px_area_ha, 3),
            valid_area_basis="exact" if tier == "exact" else "estimated_from_sample",
            resample_on_reproject="nearest" if d["stage_code"] in CLASSIFIED_STAGES else "bilinear",
        )
        inv_rows.append(row)

        dist_rows.append(dict(
            file=p.name, stage_code=d["stage_code"], stage_meaning=d["stage_meaning"],
            epoch=d["epoch"], folder=p.parent.name, dtype=hdr["dtype"],
            nodata=hdr["nodata"], stats_tier=tier, recon_only=int(tier == "decimated"),
            n_valid_inspected=int(v.size), **summarise(v)))

        flag = "" if tier == "exact" else f"  [decimated 1/{int(1/SAMPLING_FRACTION)}]"
        print(f"  {p.name:<42} {d['stage_code']} {d['nominal_res_m']:>6g}m "
              f"EPSG:{epsg}  {row['valid_area_ha']:>12,.1f} ha{flag}")

    for path, rows in ((OUT_INV, inv_rows), (OUT_DIST, dist_rows)):
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
        print(f"\nwritten: {path.relative_to(ROOT)}  ({len(rows)} rows)")

    print("\n" + "=" * 78)
    print("U0.6 - capture-date metadata hunt")
    print("=" * 78)
    hits = capture_date_hunt()
    if not hits:
        print("  NOTHING FOUND - no sidecars, readmes, delivery notes or dated TIFF tags.")
    for h in hits:
        print(f"  {h['kind']:<16} {h['path']}  ({h['bytes']:,} B)  {h['detail'][:90]}")


if __name__ == "__main__":
    main()
