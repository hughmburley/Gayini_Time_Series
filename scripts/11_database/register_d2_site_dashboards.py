#!/usr/bin/env python3
"""Targeted, additive registrar for the 57 D2 site-dashboard PNGs -> figure_asset.

WHY THIS EXISTS (not the builder): the DB builder is destructive (unlink + full
rebuild from an unfiltered rglob) and would wipe the manually-registered Task H
rows and reinstate the stale 1-July figure snapshot. This registrar performs a
narrow, idempotent additive INSERT of exactly the 57 current D2 site-dashboard
rows and NOTHING else. It never rebuilds, never deletes, never updates other rows.

Scope / guarantees:
  * Touches only figure_asset_id LIKE 'figure_d2_site_%' — the 57 rows it builds.
  * Idempotent: dedup in-logic on figure_asset_id (path is NOT unique-constrained,
    and there are no triggers) + belt-and-suspenders INSERT OR IGNORE on the PK.
    Safe to re-run: a second run inserts 0.
  * Verifies each PNG exists (path_exists=1) and recomputes the first-50-MB
    checksum against the real dashboards/ file BEFORE any write.
  * PDFs are intentionally NOT registered (out of scope; report_asset untouched).

Usage:
  python scripts/11_database/register_d2_site_dashboards.py check     # no DB write (default)
  python scripts/11_database/register_d2_site_dashboards.py execute   # performs the 57 INSERTs
"""
from __future__ import annotations
import sys, os, csv, glob, hashlib, sqlite3
from pathlib import Path

ROOT      = Path(__file__).resolve().parents[2]
DB        = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
DASH_DIR  = ROOT / "Output" / "figures" / "dashboards"
DRYRUN_CSV= ROOT / "Output" / "tables" / "d2_batch_figure_asset_dryrun_20260720.csv"
RUN_ID    = "d2_site_dashboard_batch_20260720"
DOMAIN    = "site_dashboard"
EXPECT_N  = 57
COLUMNS   = ["figure_asset_id", "path", "title", "domain", "metric_id",
            "recommended_use", "checksum_sha256", "path_exists", "qa_status", "run_id"]


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks — identical to the builder's method."""
    h = hashlib.sha256(); read = 0; cap = 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk); read += len(chunk)
    return h.hexdigest()


def build_rows() -> list[dict]:
    """Construct the 57 rows from the real PNGs on disk, verifying as we go."""
    pngs = sorted(DASH_DIR.glob("D2_site_GA_*_slide_data.png"))
    if len(pngs) != EXPECT_N:
        raise SystemExit(f"ABORT: expected {EXPECT_N} dashboards, found {len(pngs)} in {DASH_DIR}")
    rows = []
    for p in pngs:
        stem = p.stem                                   # D2_site_GA_001_slide_data
        parts = stem.split("_")
        pid = f"{parts[2]}_{parts[3]}"                   # GA_001
        if not p.is_file():
            raise SystemExit(f"ABORT: not a file: {p}")
        row = {
            "figure_asset_id": f"figure_d2_site_{pid}",
            "path":            f"Output/figures/dashboards/{p.name}",   # relative, posix
            "title":           stem.replace("_", " "),
            "domain":          DOMAIN,
            "metric_id":       None,
            "recommended_use": "review_or_reporting",
            "checksum_sha256": sha256_first50(p),
            "path_exists":     1,
            "qa_status":       "REVIEW",
            "run_id":          RUN_ID,
        }
        # Guard: every NOT-NULL / required-by-decision column must be populated.
        for col in ("path", "path_exists", "checksum_sha256", "figure_asset_id", "domain"):
            if row[col] in (None, ""):
                raise SystemExit(f"ABORT: empty required column {col!r} for {pid}")
        rows.append(row)
    # Guard: all ids in our namespace, unique, exactly 57.
    ids = [r["figure_asset_id"] for r in rows]
    assert len(set(ids)) == EXPECT_N and all(i.startswith("figure_d2_site_") for i in ids)
    return rows


def write_dryrun_csv(rows: list[dict]) -> None:
    audit = [{**r,
              "metric_id": "" if r["metric_id"] is None else r["metric_id"]}
             for r in rows]
    DRYRUN_CSV.parent.mkdir(parents=True, exist_ok=True)
    with DRYRUN_CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS); w.writeheader(); w.writerows(audit)


def main(mode: str) -> None:
    rows = build_rows()
    write_dryrun_csv(rows)

    if mode == "check":
        # READ-ONLY: report how many are new vs already present. No write.
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        existing = {r[0] for r in con.execute("SELECT figure_asset_id FROM figure_asset")}
        total = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
        con.close()
        new = [r for r in rows if r["figure_asset_id"] not in existing]
        print(f"[check] figure_asset currently has {total} rows.")
        print(f"[check] would INSERT {len(new)} new rows; skip {len(rows) - len(new)} already present.")
        print(f"[check] all {len(rows)} rows verified: path_exists=1, checksum computed, no empty required cols.")
        print(f"[check] dry-run CSV refreshed: {DRYRUN_CSV}")
        print("[check] NO DB WRITE performed.")
        return

    if mode == "execute":
        con = sqlite3.connect(DB.as_posix())
        try:
            before = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
            placeholders = ", ".join(["?"] * len(COLUMNS))
            payload = [tuple(r[c] for c in COLUMNS) for r in rows]
            cur = con.executemany(
                f"INSERT OR IGNORE INTO figure_asset ({', '.join(COLUMNS)}) VALUES ({placeholders})",
                payload)
            con.commit()
            after = con.execute("SELECT COUNT(*) FROM figure_asset").fetchone()[0]
            d2 = con.execute("SELECT COUNT(*) FROM figure_asset "
                             "WHERE figure_asset_id LIKE 'figure_d2_site_%'").fetchone()[0]
            print(f"[execute] before={before} after={after} inserted={after - before} "
                  f"(re-run inserts 0). D2_site rows now = {d2} (expect {EXPECT_N}).")
        finally:
            con.close()
        return

    raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
