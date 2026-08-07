#!/usr/bin/env python
"""DIAG-1 Stage 0 - data preparation at the Python/R boundary.

Ruling AS (7 August 2026): all statistical estimation lives in R. This script does
none. It reads the three source tables, reshapes them, stamps the five provenance
columns that section 7 of the spec requires ON EVERY OUTPUT - support level, unit,
period, weighting, estimand - and writes checksummed analysis CSVs that R reads.

ESTIMAND IS THE COLUMN THAT MATTERS. A between-unit slope and a within-unit slope
answer different questions and are never two estimates of one number. Section 7 makes
it non-negotiable that they are not distinguishable by filename alone, so the column
travels in the data.

Nothing is registered. The database is not opened. Output/pack/ is not written.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Output" / "diag"
ANA = OUT / "analysis"

SRC_BETWEEN = ROOT / "Output/pack/PARTREG/tables/PARTREG_part_residuals.csv"
SRC_COEF = ROOT / "Output/pack/PARTREG/tables/PARTREG_S2_regression_coefficients.csv"
SRC_PART_YEAR = ROOT / "Output/tables/PARTREG_part_year_floor_inund.csv"
SRC_PATCH_YEAR = ROOT / "Output/tables/UNZONED_stageA1_patch_year.csv"

# period prefix -> (period key, label, expected n_years)
PERIODS = [
    ("whole_record", "1988-2022", 35),
    ("cropping_era", "1988-2013", 26),
    ("post_management", "2018-2022", 5),
]

WEIGHTING = "pixel-weighted by the unit's cell count (n_pixels_part / n_cells)"


def sha256_first50(path: Path) -> str:
    """First-50-MB SHA-256 - the project's one checksum convention."""
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
    inputs = []

    # ---------------------------------------------------------------- between
    d = pd.read_csv(SRC_BETWEEN)
    assert len(d) == 115, f"expected 115 parts, got {len(d)}"
    keep = ["part_id", "zone_fid", "paddock_name", "community", "community_short",
            "conserved", "n_pixels_part", "area_ha"]
    frames = []
    for pref, label, n_years in PERIODS:
        got = sorted(d[f"{pref}__n_years"].unique())
        assert got == [n_years], f"{pref}: expected n_years {n_years}, got {got}"
        f = d[keep].copy()
        f["period"] = pref
        f["period_label"] = label
        f["n_years"] = d[f"{pref}__n_years"].values
        f["floor_mean"] = d[f"{pref}__floor_mean"].values
        f["inund_mean"] = d[f"{pref}__inund_mean"].values
        # the PUBLISHED prediction and residual, carried so R can check itself against
        # what actually shipped rather than against its own refit
        f["published_predicted_floor"] = d[f"{pref}__predicted_floor"].values
        f["published_residual"] = d[f"{pref}__residual"].values
        frames.append(f)
    b = pd.concat(frames, ignore_index=True)
    b["support_level"] = "pixel"
    b["unit"] = "part (paddock x community)"
    b["cluster_column"] = "zone_fid (paddock)"
    b["weighting"] = WEIGHTING
    b["estimand"] = "BETWEEN-UNIT: how the across-year mean floor differs between parts that differ in wetness"
    b["y_variable"] = "floor_mean = mean over years of veg_p05_spatial (%)"
    b["x_variable"] = "inund_mean = mean over years of the share of the part's cells seen wet (%)"
    b = b.sort_values(["period", "part_id"]).reset_index(drop=True)
    assert len(b) == 345, len(b)

    # ------------------------------------------------------------- part-years
    py = pd.read_csv(SRC_PART_YEAR)
    assert len(py) == 4025 and py.part_id.nunique() == 115 and py.zone_fid.nunique() == 64
    p = py[["part_id", "zone_fid", "zone_name", "community_short", "water_year",
            "n_pixels_part", "n_valid", "veg_p05_spatial", "inund_pct"]].copy()
    p["support_level"] = "pixel"
    p["unit"] = "part-year"
    p["period_label"] = "1988-2022"
    p["cluster_column"] = "zone_fid (paddock); part_id for the AR(1) error structure"
    p["weighting"] = WEIGHTING
    p["estimand"] = "WITHIN-UNIT: how one part's floor moves when that same part's own wetness moves"
    p = p.sort_values(["part_id", "water_year"]).reset_index(drop=True)

    # ------------------------------------------------------------ patch-years
    qy = pd.read_csv(SRC_PATCH_YEAR)
    assert len(qy) == 3253 and qy.patch_id.nunique() == 93
    q = qy[["patch_id", "community_short", "n_cells", "area_ha", "water_year",
            "n_valid", "veg_p05_spatial", "inund_pct"]].copy()
    q["support_level"] = "pixel"
    q["unit"] = "patch-year (unzoned; contiguous single-community patch)"
    q["period_label"] = "1988-2022"
    # Section 6: where UNZONED has no paddock, SAY SO on the output rather than
    # substituting a cluster. The patch is not a paddock and is not nested in one.
    q["cluster_column"] = "patch_id - THERE IS NO PADDOCK. Unzoned patches are not nested in management zones and no paddock cluster is substituted"
    q["weighting"] = WEIGHTING
    q["estimand"] = "WITHIN-UNIT: how one patch's floor moves when that same patch's own wetness moves"
    q = q.sort_values(["patch_id", "water_year"]).reset_index(drop=True)

    written = []
    for name, frame in (("DIAG1_between_parts.csv", b),
                        ("DIAG1_part_year.csv", p),
                        ("DIAG1_patch_year.csv", q)):
        path = ANA / name
        frame.to_csv(path, index=False, lineterminator="\n")
        written.append((name, len(frame), sha256_first50(path)))
        print(f"  [wrote] {name:28s} {len(frame):>5} rows  {sha256_first50(path)[:16]}")

    for label, src in (("between source", SRC_BETWEEN), ("coefficients", SRC_COEF),
                       ("part-year source", SRC_PART_YEAR), ("patch-year source", SRC_PATCH_YEAR)):
        inputs.append({"role": "input", "name": src.name,
                       "path": src.relative_to(ROOT).as_posix(),
                       "rows": len(pd.read_csv(src)), "sha256_first50": sha256_first50(src),
                       "note": label})
    for name, n, h in written:
        inputs.append({"role": "boundary CSV written for R", "name": name,
                       "path": (ANA / name).relative_to(ROOT).as_posix(),
                       "rows": n, "sha256_first50": h, "note": "read by R/diag/"})
    pd.DataFrame(inputs).to_csv(OUT / "DIAG1_inputs.csv", index=False, lineterminator="\n")
    print(f"  [wrote] DIAG1_inputs.csv              {len(inputs)} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
