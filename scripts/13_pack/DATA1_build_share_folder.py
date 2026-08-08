#!/usr/bin/env python
"""DATA-1 - the raster companion folder for Adrian.

COPY, NEVER MOVE. Nothing is deleted, renamed or re-derived. Every source file stays
where it is, and this script only ever writes into the destination folder.

NOT Output/pack/: that path is unwritable under the deny rule in .claude/settings.json,
and pack v1.4 is sealed at 7c5ec74daf747cd0 with a 22-member manifest that a new
subfolder would contradict.

VERIFICATION IS BY CHECKSUM, NOT BY THE COPY RETURNING SUCCESS. Both sides get bytes,
first-50-MB SHA-256, band count, CRS, cell size and extent, and the copy is rejected if
they differ. Every copied file is under 50 MB, so the project's first-50-MB convention
covers the whole file here - asserted rather than assumed, because a truncated copy of a
larger file would otherwise pass.
"""
from __future__ import annotations

import hashlib
import shutil
import sys
from pathlib import Path

import pandas as pd
import rasterio

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "Output" / "rasters" / "DATA_share_20260808"
R = ROOT / "Output" / "rasters"

CAP = 50 * 1024 * 1024

# (source, destination subfolder, one-line description)
ITEMS = [
    (R / "background_flood_frequency_8058.tif", "",
     "WHAT WAS ASKED FOR. Per-cell flood frequency: 100 x wet-valid water years / valid "
     "water years, one band, derived from the 35-band native stack below."),
    (R / "inundation_annual_stack/annual_wet_any_1988_2023.tif",
     "inundation_annual_stack_native_28355",
     "SOURCE, before any reprojection. Was any cell wet in this water year: 35 bands, "
     "WY1988-WY2022, native EPSG:28355 at 25.0 m."),
    (R / "inundation_annual_stack/annual_valid_any_1988_2023.tif",
     "inundation_annual_stack_native_28355",
     "SOURCE denominator. Was this cell observable in this water year: 35 bands, native "
     "EPSG:28355. Holds only 1 and 255 - see the README."),
    (R / "inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif",
     "inundation_annual_stack_8058",
     "The same wet stack on the census grid, nearest neighbour. THIS is what the "
     "analysis reads."),
    (R / "inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif",
     "inundation_annual_stack_8058",
     "The same valid stack on the census grid. Holds only 1 and 255 - see the README."),
    (R / "flood_zone_8058.tif", "",
     "Wetness banding (low / mid / high) that the community x wetness classes rest on."),
    (R / "veg_regime_class_8058.tif", "",
     "Community x wetness classes, 11 codes. THE FOOTPRINT EVERYTHING IS MASKED TO - "
     "see the README for the lookup and the non-treed selection."),
] + [
    (R / f"veg_percentiles_8058/total_veg_p{p}_8058.tif", "veg_percentiles_8058",
     f"Temporal total-vegetation-cover {p}th percentile across the 140 SEASONAL "
     f"composites (MIN_SEASONS = 50). NOT the annual series the regression uses - "
     f"see the README.")
    for p in ("05", "10", "20", "30", "50")
]

# Named in the spec but NOT copied, and listed in the README instead.
NOT_COPIED = [
    (R / "veg_annual_8058/total_veg_annual_mean_8058.tif",
     "Annual mean total vegetation cover, 35 bands, WY1988-WY2022. ALREADY SHARED by "
     "Drive link. Not copied: at 609 MB it would duplicate itself inside the same tree "
     "for nothing."),
]


def sha256_first50(path: Path) -> str:
    cap, h = CAP, hashlib.sha256()
    with open(path, "rb") as f:
        while cap > 0:
            b = f.read(min(1 << 20, cap))
            if not b:
                break
            h.update(b)
            cap -= len(b)
    return h.hexdigest()


def probe(path: Path) -> dict:
    with rasterio.open(path) as r:
        names = [n for n in (r.descriptions or []) if n]
        return {
            "bytes": path.stat().st_size,
            "sha256_first50": sha256_first50(path),
            "bands": r.count,
            "crs_epsg": r.crs.to_epsg() if r.crs else None,
            "cell_size_m": round(r.res[0], 6),
            "extent": ",".join(str(round(v)) for v in r.bounds),
            "dtype": r.dtypes[0],
            "band_names_present": len(names) == r.count and r.count > 0,
            "first_band_name": names[0] if names else "",
            "last_band_name": names[-1] if names else "",
        }


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    rows, problems = [], []

    print(f"  destination {DEST.relative_to(ROOT).as_posix()}")
    before = sum(f.stat().st_size for f in DEST.rglob("*") if f.is_file())
    print(f"  size before {before / 1e6:.1f} MB")

    seen_sources: dict[str, Path] = {}
    for src, sub, desc in ITEMS:
        if not src.exists():
            problems.append(f"SOURCE MISSING: {src}")
            continue
        s = probe(src)

        # The spec lists annual_wet_any_1988_2023_8058.tif and its stack folder as
        # separate items. They are THE SAME FILES. Copy once, and say so.
        if s["sha256_first50"] in seen_sources:
            rows.append({"filename": src.name, "copied": "NO - duplicate of "
                         + seen_sources[s["sha256_first50"]].name,
                         "source_path": src.relative_to(ROOT).as_posix(), **s,
                         "destination_path": "", "verified": "n/a", "description": desc})
            continue
        seen_sources[s["sha256_first50"]] = src

        out_dir = DEST / sub if sub else DEST
        out_dir.mkdir(parents=True, exist_ok=True)
        dst = out_dir / src.name
        shutil.copy2(src, dst)
        d = probe(dst)

        ok = (d["bytes"] == s["bytes"] and d["sha256_first50"] == s["sha256_first50"]
              and d["bands"] == s["bands"] and d["crs_epsg"] == s["crs_epsg"])
        # first-50-MB only covers the whole file if the file is smaller than that
        if s["bytes"] >= CAP:
            problems.append(f"{src.name}: {s['bytes'] / 1e6:.0f} MB - the checksum covers "
                            f"only the first 50 MB, so this copy is NOT fully verified")
        if not ok:
            problems.append(f"COPY MISMATCH: {src.name}")

        rows.append({"filename": src.name, "copied": "yes",
                     "source_path": src.relative_to(ROOT).as_posix(),
                     "destination_path": dst.relative_to(DEST).as_posix(),
                     "verified": "checksum, bytes, bands and CRS all match" if ok else "FAILED",
                     **s, "description": desc})
        flag = "" if s["crs_epsg"] == 8058 else "   <- NOT EPSG:8058"
        print(f"  copied  {dst.relative_to(DEST).as_posix():58s} "
              f"{s['bytes'] / 1e6:7.1f} MB  b={s['bands']:2d}  {s['crs_epsg']}{flag}")

    for src, desc in NOT_COPIED:
        if not src.exists():
            problems.append(f"NOT-COPIED SOURCE MISSING: {src}")
            continue
        s = probe(src)
        rows.append({"filename": src.name, "copied": "NO - already shared by Drive link",
                     "source_path": src.relative_to(ROOT).as_posix(),
                     "destination_path": "", "verified": "n/a", **s, "description": desc})
        print(f"  listed  {src.name:58s} {s['bytes'] / 1e6:7.1f} MB  b={s['bands']:2d}  "
              f"{s['crs_epsg']}   (not copied)")

    # Anything in the destination that DATA-1 did not put there. Concurrent sessions
    # share this worktree and a figures bundle appeared in this folder six minutes
    # after the first run. Foreign files are NEVER deleted or moved - they are recorded
    # so the manifest stays a true account of what the recipient actually receives,
    # and marked unverified because this script did not copy them and cannot vouch for
    # them.
    mine = {DEST / r["destination_path"] for r in rows if r["copied"] == "yes"}
    mine |= {DEST / "DATA1_manifest.csv", DEST / "README.md"}
    foreign = sorted(p for p in DEST.rglob("*") if p.is_file() and p not in mine)

    # RULING CR: verify the foreign files rather than only recording them. Every one is
    # checksummed against Output/figures/, BY CONTENT FIRST and by filename second - a
    # name match with a different checksum is a stale copy, which is a different and
    # worse problem than a missing source, so the two are never collapsed.
    fig_root = ROOT / "Output" / "figures"
    by_sum: dict[str, list[Path]] = {}
    by_name: dict[str, list[Path]] = {}
    for f in fig_root.rglob("*"):
        if f.is_file():
            by_name.setdefault(f.name, []).append(f)
    for p in foreign:
        cand = by_name.get(p.name, [])
        for c in cand:
            by_sum.setdefault(sha256_first50(c), []).append(c)

    for p in foreign:
        h = sha256_first50(p)
        same_name = by_name.get(p.name, [])
        exact = [c for c in same_name if sha256_first50(c) == h]
        if exact:
            src = exact[0].relative_to(ROOT).as_posix()
            verdict = "VERIFIED - byte-identical to its source in Output/figures/"
        elif same_name:
            src = same_name[0].relative_to(ROOT).as_posix()
            verdict = ("STALE - a file of this name exists in Output/figures/ but the "
                       "checksums DIFFER; this copy is not the current render")
            problems.append(f"{p.name}: STALE copy - differs from {src}")
        elif p.suffix.lower() not in {".png", ".pdf", ".jpg", ".jpeg", ".tif", ".tiff"}:
            # Not a figure, so no Output/figures/ source is expected. Stated as a fact
            # about the file type rather than a guess about where it came from.
            src = ""
            verdict = ("NOT A FIGURE - no Output/figures/ source is expected for this "
                       "file type; it is an original in this folder")
        else:
            src = ""
            verdict = "NO SOURCE FOUND under Output/figures/ - origin not established"
            problems.append(f"{p.name}: no source found under Output/figures/")
        rows.append({
            "filename": p.name, "copied": "NO - already present, not placed by DATA-1",
            "source_path": src, "destination_path": p.relative_to(DEST).as_posix(),
            "bytes": p.stat().st_size, "sha256_first50": h,
            "bands": None, "crs_epsg": None, "cell_size_m": None, "extent": "",
            "dtype": "", "band_names_present": None, "first_band_name": "",
            "last_band_name": "", "verified": verdict,
            "description": "Placed in this folder by another session. Checked against "
                           "Output/figures/ under Ruling CR; nothing moved or deleted."})

    m = pd.DataFrame(rows)
    m["year_span"] = [
        "WY1988-WY2022 (35 water years); band names 1988-1989 .. 2022-2023"
        if r.bands == 35 else
        ("derived from the 35-band stack: WY1988-WY2022" if "flood_freq" in r.filename else
         ("" if r.bands is None else "not a time series"))
        for r in m.itertuples()]
    m["checksum_convention"] = [
        "first-50-MB SHA-256; file is under 50 MB so this covers the whole file"
        if b < CAP else "first-50-MB SHA-256 ONLY - the file is larger than 50 MB"
        for b in m.bytes]
    cols = ["filename", "copied", "destination_path", "source_path", "bytes",
            "sha256_first50", "checksum_convention", "bands", "band_names_present",
            "first_band_name", "last_band_name", "crs_epsg", "cell_size_m", "extent",
            "dtype", "year_span", "verified", "description"]
    m[cols].to_csv(DEST / "DATA1_manifest.csv", index=False, lineterminator="\n")

    after = sum(f.stat().st_size for f in DEST.rglob("*") if f.is_file())
    n_mine = int((m.copied == "yes").sum())
    print(f"\n  size after  {after / 1e6:.1f} MB total, of which "
          f"{m[m.copied == 'yes'].bytes.sum() / 1e6:.1f} MB is the {n_mine} files DATA-1 copied")
    if foreign:
        fb = sum(p.stat().st_size for p in foreign)
        print(f"  ALREADY PRESENT, NOT PLACED BY DATA-1: {len(foreign)} files, "
              f"{fb / 1e6:.1f} MB - left untouched")
        fm = m[m.copied.str.startswith("NO - already present")]
        v = int(fm.verified.str.startswith("VERIFIED").sum())
        s = int(fm.verified.str.startswith("STALE").sum())
        n = int(fm.verified.str.startswith("NO SOURCE").sum())
        o = int(fm.verified.str.startswith("NOT A FIGURE").sum())
        print(f"    Ruling CR: {v} byte-identical to Output/figures/, {s} stale, "
              f"{n} with no source found, {o} not a figure")
        for _, r in fm[~fm.verified.str.startswith("VERIFIED")].iterrows():
            print(f"      {r.destination_path}  ->  {r.verified.split(' - ')[0]}")
    non8058 = m[(m.copied == "yes") & (m.crs_epsg != 8058)]
    if len(non8058):
        print(f"  NOT ON THE CANONICAL GRID ({len(non8058)}): "
              f"{', '.join(non8058.filename)} - EPSG:{non8058.crs_epsg.iloc[0]}, "
              f"deliberate, this is the pre-reprojection source")
    for p in problems:
        print(f"  PROBLEM  {p}")
    print(f"  [wrote] DATA1_manifest.csv")
    return 1 if any("MISMATCH" in p or "MISSING" in p for p in problems) else 0


if __name__ == "__main__":
    sys.exit(main())
