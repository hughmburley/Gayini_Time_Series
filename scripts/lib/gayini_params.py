"""gayini_params.py - the ONE place a Gayini project constant may appear (Python).

Every other file references these; a bare literal from MAGIC_LITERALS anywhere
under scripts/ or R/ (outside this file / its R twin) fails the smoke-test
magic-number lint. PIXEL_AREA_HA is DERIVED, never typed - that one line removes
the 0.0625-vs-0.062351428 class of error.

Spec: docs/T5_guardrails_and_checks.md Gate 1.1. Twin: R/gayini_params.R.
"""
from __future__ import annotations

import sqlite3
import warnings
from pathlib import Path

PIXEL_SIDE_M = 24.970268                 # raster_asset.resolution_x (8058)
PIXEL_AREA_HA = PIXEL_SIDE_M ** 2 / 1e4  # DERIVED, never typed = 0.062351428
MAPPED_AREA_HA = 67349.332               # census_stratum.farm_area_ha
TRUE_FARM_HA = 85910.8                   # census_stratum.farm_area_total_ha
TOTAL_CENSUS_PX = 1080157                # census_asset.n_rows
SCOPE_NON_TREED = "treed_context_flag = 0 AND regime_band <> 'context'"
SCOPE_ALL_PIXEL = "1=1"
CRS_CANONICAL = 8058
CRS_INUNDATION = 28355
CRS_FC_SOURCE = 3577
CRS_PLOT_CENTROID = 9473

# The literals the magic-number lint forbids elsewhere (this file is the only home).
MAGIC_LITERALS = ["0.0625", "0.062351428", "24.970268", "67349", "85910",
                  "1080157", "988831", "993782"]

_DEFAULT_DB = Path("Output") / "database" / "Gayini_Results.sqlite"


def validate(db_path: Path = _DEFAULT_DB, tol: float = 1e-4) -> bool:
    """DB is authoritative: ERROR on disagreement, WARN only if DB unreachable."""
    db_path = Path(db_path)
    if not db_path.is_file():
        warnings.warn(f"gayini_params: DB not found at {db_path} - self-check skipped.")
        return False
    con = sqlite3.connect(f"file:{db_path.as_posix()}?mode=ro", uri=True)
    try:
        res = con.execute("SELECT resolution_x FROM raster_asset WHERE crs_epsg=8058 LIMIT 1").fetchone()
        cs = con.execute("SELECT farm_area_ha, farm_area_total_ha FROM census_stratum LIMIT 1").fetchone()
        nr = con.execute("SELECT n_rows FROM census_asset WHERE census_asset_id='census_pixel_8058'").fetchone()
    finally:
        con.close()
    checks = [
        ("PIXEL_SIDE_M", PIXEL_SIDE_M, res[0], tol),
        ("MAPPED_AREA_HA", MAPPED_AREA_HA, cs[0], 0.01),
        ("TRUE_FARM_HA", TRUE_FARM_HA, cs[1], 0.01),
        ("TOTAL_CENSUS_PX", TOTAL_CENSUS_PX, nr[0], 0.5),
    ]
    for name, want, got, t in checks:
        if got is None:
            raise ValueError(f"gayini_params: DB returned NULL for {name}")
        if abs(float(want) - float(got)) > t:
            raise ValueError(
                f"gayini_params: {name} = {want} disagrees with DB {got} (tol {t}). "
                "Fix the module or the DB, do not diverge.")
    return True


# run on import (non-fatal only when the DB is absent)
try:
    if validate():
        pass
except FileNotFoundError:
    pass


if __name__ == "__main__":
    ok = validate()
    print(f"gayini_params self-check: {'PASS' if ok else 'SKIPPED (no DB)'}")
    print(f"PIXEL_AREA_HA (derived) = {PIXEL_AREA_HA}")
