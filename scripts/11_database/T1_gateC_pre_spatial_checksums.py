#!/usr/bin/env python3
"""T1 Gate C pre-step - complete content integrity on spatial_layer_asset.

Gate B1 populated checksum_sha256 + path_exists for spatial_006 only, so
read_registered_layer() can check fields+CRS on all six but content integrity on
one. This fills the other five (first-50-MB SHA-256, the one convention):
  spatial_001..004 all resolve to Input/shapefiles.zip -> ONE hash covers four;
  spatial_005 is the gauge sqlite -> one hash.
Additive UPDATE, idempotent. Run before Gate C consumes spatial_006 at scale.

Usage: python scripts/11_database/T1_gateC_pre_spatial_checksums.py [check|execute]
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"


def sha256_first50(path: Path) -> str:
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk); read += len(chunk)
    return h.hexdigest()


def resolve(reg_path: str) -> Path:
    """Registered paths are absolute Windows paths; normalise separators."""
    return Path(reg_path.replace("\\", "/"))


def main(mode: str) -> None:
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    rows = con.execute(
        "SELECT spatial_layer_asset_id, path, checksum_sha256, path_exists "
        "FROM spatial_layer_asset WHERE spatial_layer_asset_id <> 'spatial_006' "
        "ORDER BY spatial_layer_asset_id").fetchall()
    con.close()

    cache: dict[str, tuple[str | None, int]] = {}
    plan = []
    for sid, reg_path, cur_ck, cur_pe in rows:
        if reg_path not in cache:
            f = resolve(reg_path)
            if f.is_file():
                cache[reg_path] = (sha256_first50(f), 1)
            else:
                cache[reg_path] = (None, 0)
        ck, pe = cache[reg_path]
        plan.append((sid, reg_path, ck, pe))

    print(f"[{mode}] two source files hashed for five rows:")
    for src, (ck, pe) in cache.items():
        print(f"    path_exists={pe}  sha256_first50={ck}  <- {src}")
    for sid, reg_path, ck, pe in plan:
        print(f"    {sid}: checksum={'set' if ck else 'NULL(missing)'} path_exists={pe}")

    if mode == "check":
        print("[check] NO DB WRITE.")
        return

    con = sqlite3.connect(DB.as_posix())
    try:
        for sid, reg_path, ck, pe in plan:
            con.execute(
                "UPDATE spatial_layer_asset SET checksum_sha256=?, path_exists=? "
                "WHERE spatial_layer_asset_id=?", (ck, pe, sid))
        con.commit()
        done = con.execute(
            "SELECT COUNT(*) FROM spatial_layer_asset "
            "WHERE checksum_sha256 IS NOT NULL AND path_exists IS NOT NULL").fetchone()[0]
        print(f"[execute] spatial_layer_asset rows with checksum+path_exists: {done}/6")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
