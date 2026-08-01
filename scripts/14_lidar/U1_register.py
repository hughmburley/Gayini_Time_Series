#!/usr/bin/env python3
"""Task U · Gate U1 item 7 — register the reprojected products and the denominators.

Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U1 item 7.

ADDITIVE ONLY. Never rebuilds, never deletes, never drops a view, never touches a
row outside the sets named below. `INSERT OR REPLACE` throughout - the
register_taskM_gateC template's `INSERT OR IGNORE` is NOT propagated (U-I2): it
never updates a changed checksum, so a "re-run twice, identical checksums" test
passes while the DB is wrong.

Scope, exhaustively:
  1. ALTER TABLE ADD COLUMN on raster_asset (nullable, default NULL):
     file_bytes, source_crs, epoch_label, stage_code. These are the spec's
     acceptance criterion "every registered row records source CRS, stage code,
     semantics and checksum" - stored as COLUMNS, never as prose (CLAUDE.md).
  2. INSERT OR REPLACE the Gate U1 run-A rasters into raster_asset.
  3. INSERT OR REPLACE the two Task U denominators into dim_headline_number.
  4. One workflow_run row.

Products NOT registered here, deliberately:
  bb0 / bbm at 50 cm - Gate U1 run B, registered by U1b_dem_warp.py
  bb3 / bb4          - never warped; d5's are quarantined under R4 (D-U3) and
                       2009's carries no class information (D-U2)
  bbi hillshade      - serves no question

Usage:
  python scripts/14_lidar/U1_register.py check     # no DB write (default)
  python scripts/14_lidar/U1_register.py execute
"""
from __future__ import annotations

import csv
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

import rasterio

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
RAST = ROOT / "Output" / "rasters" / "task_U"
FACTS = ROOT / "Output" / "tables" / "taskU_gateU1_facts.csv"
DRYRUN = ROOT / "Output" / "tables" / "taskU_gateU1_registration_dryrun.csv"

RUN_ID = "taskU_gateU1"
RUN_DT = "2026-08-01T00:00:00+00:00"
SPEC = "docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md"

NEW_COLUMNS = [("raster_asset", "file_bytes", "INTEGER"),
               ("raster_asset", "source_crs", "TEXT"),
               ("raster_asset", "epoch_label", "TEXT"),
               ("raster_asset", "stage_code", "TEXT")]

FPC_NOT_TOTAL_VEG = (
    "LiDAR FPC is projected foliage cover above the model's height threshold - "
    "effectively woody. Landsat total_veg = PV + NPV is surface cover including "
    "grass and litter. NOT COMPARABLE: never on a shared axis, never differenced (T-4)."
)
R1_NOTE = ("R1 seam precedence: d4 takes precedence throughout the 3,633.3 ha seam "
           "(1,486.3 ha on-property); d5 fills only where d4 is absent; NEVER averaged. "
           "Seam written out as taskU_seam_mask_2021_8058_{10m,5m}.tif.")
R2_NOTE = ("R2 pre-registered physical-plausibility ceiling: 50 m above ground, set from "
           "vegetation ecology (river red gum reaches 40-45 m here), not from the observed "
           "distribution. Applied identically at both epochs across the WHOLE height "
           "stack. Excluded 218 px / 0.545 ha in 2009 and 0 px in 2021, on-property. "
           "Sensitivity at 30/50/80 m in Output/tables/taskU_gateU1_r2_screen.csv.")

PCT_LABEL = {"bb9": "5th", "bba": "25th", "bbb": "50th", "bbc": "75th",
             "bbd": "95th", "bbe": "99th"}
SENSOR = {"2009": "Leica ALS-50 (l1)", "2021": "Leica ALS-80 (l4)"}
SRC_CRS = {"2009": "EPSG:28355", "2021": "EPSG:7854 (d4) + EPSG:7855 (d5)"}


def sha256_first50(path: Path) -> str:
    """SHA-256 of the first 50 MB, 1 MB chunks - the project's one convention."""
    h, read, cap = hashlib.sha256(), 0, 50 * 1024 * 1024
    with path.open("rb") as f:
        while read < cap:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
            read += len(chunk)
    return h.hexdigest()


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def load_facts() -> dict[str, str]:
    if not FACTS.is_file():
        raise SystemExit(f"ABORT: {rel(FACTS)} missing. Run U1_common_frame.py first.")
    return {r["name"]: r["value"] for r in csv.DictReader(FACTS.open(encoding="utf-8"))}


def classify(p: Path) -> dict:
    """Derive the registration semantics from the filename, which the producing
    script controls. Anything unrecognised aborts rather than being registered blind."""
    n = p.stem
    if n.startswith("taskU_bbh_fpc_"):
        epoch = n.split("_")[3]
        return dict(stage_code="bbh", epoch=epoch, product="taskU_lidar_fpc_8058",
                    legend_status="unconfirmed",
                    semantics=("Foliage Projective Cover, percent, JRSRP bbh, Fisher et "
                               f"al. 2020. {SENSOR[epoch]}, discrete return. 10 m, "
                               f"EPSG:8058, bilinear, clipped to gayini_boundary_8058. "
                               f"{FPC_NOT_TOTAL_VEG}"
                               + (f" {R1_NOTE}" if epoch == "2021" else "")))
    if n.startswith("taskU_seam_mask_"):
        return dict(stage_code=None, epoch="2021", product="taskU_lidar_seam_mask",
                    legend_status="confirmed",
                    semantics=("1 = both the d4 and d5 2021 tiles are valid (the R1 seam); "
                               "0 = elsewhere. Provided so any later finding can be tested "
                               f"for seam sensitivity. {R1_NOTE}"))
    if n.startswith("taskU_r2_excluded_"):
        epoch = n.split("_")[3]
        return dict(stage_code=None, epoch=epoch, product="taskU_lidar_r2_exclusion",
                    legend_status="confirmed",
                    semantics=f"1 = excluded by the R2 height ceiling. {R2_NOTE}")
    parts = n.split("_")           # taskU_<stage>_<plab>_height_<epoch>_8058_5m
    if len(parts) >= 6 and parts[3] == "height":
        stage, epoch = parts[1], parts[4]
        return dict(stage_code=stage, epoch=epoch,
                    product="taskU_lidar_height_percentile_8058",
                    legend_status="unconfirmed",
                    semantics=(f"JRSRP {stage} - {PCT_LABEL[stage]} percentile of return "
                               f"heights above ground within a 5 m pixel, metres. "
                               f"{SENSOR[epoch]}, discrete return. EPSG:8058, bilinear, "
                               f"clipped to gayini_boundary_8058. {R2_NOTE}"
                               + (f" {R1_NOTE}" if epoch == "2021" else "")))
    raise SystemExit(f"ABORT: cannot classify {p.name} - refusing to register it blind")


def build_raster_rows() -> list[dict]:
    tifs = sorted(RAST.glob("*.tif"))
    if not tifs:
        raise SystemExit(f"ABORT: no rasters in {rel(RAST)}. Run U1_common_frame.py first.")
    rows = []
    for p in tifs:
        c = classify(p)
        with rasterio.open(p) as s:
            if s.crs.to_epsg() != 8058:
                raise SystemExit(f"ABORT: {p.name} is EPSG:{s.crs.to_epsg()}, not 8058")
            rows.append(dict(
                raster_asset_id=f"raster_{p.stem}", path=rel(p), metric_id=None,
                water_year=None, period_label=f"lidar_epoch_{c['epoch']}",
                crs=str(s.crs), crs_epsg=8058,
                resolution_x=s.res[0], resolution_y=s.res[1],
                xmin=s.bounds.left, ymin=s.bounds.bottom,
                xmax=s.bounds.right, ymax=s.bounds.top,
                checksum_sha256=sha256_first50(p), path_exists=1, qa_status="REVIEW",
                run_id=RUN_ID, product=c["product"],
                legend_status=c["legend_status"], legend_semantics=c["semantics"],
                superseded_flag=0, framing_label="context",
                provenance_note=(f"Task U Gate U1 run A. Spec {SPEC}. Produced by "
                                 "scripts/14_lidar/U1_common_frame.py. Denominators: "
                                 "Task U both-valid 85,882.6 ha; Census n LiDAR "
                                 "67,268.0 ha. See Output/tables/taskU_gateU1_facts.csv."),
                file_bytes=p.stat().st_size, source_crs=SRC_CRS[c["epoch"]],
                epoch_label=c["epoch"], stage_code=c["stage_code"]))
    return rows


def build_headline_rows(f: dict) -> list[dict]:
    """The two Task U denominators. A denominator that is not registered is a
    denominator that gets re-derived differently next time."""
    common = dict(source_object="Output/rasters/task_U/ (Gate U1 run A)",
                  aggregation_order="n/a - an area, not an aggregate",
                  series_variant="n/a", spread_min=None, spread_max=None,
                  decided_by=f"spec {SPEC} Gate U1 items 3-4; built by CC 2026-08-01",
                  )
    return [
        dict(number_id="taskU_denominator_both_valid_ha",
             label="Task U both-valid area (on-property, both LiDAR epochs)",
             grain="pixel", scope_filter="on-property AND 2009 m5 valid AND (2021 d4 OR d5) valid",
             period_label="2009_and_2021", denominator="n/a - this IS the denominator",
             pixel_constant=0.01, pinned_value=float(f["denominator_taskU_both_valid_ha"]),
             support_level="pixel",
             caveat=("10 m LiDAR grid, EPSG:8058, 0.01 ha/px. 99.97% of the 85,910.8 ha "
                     "property - do NOT round to 'the whole property'; the 28.2 ha gap is "
                     "what makes it a measured figure. Use for EVERY change statistic in "
                     "Task U. NOT interchangeable with the Census n LiDAR denominator."),
             decision_note=("R1 mosaic (d4 precedence, never averaged). Supersedes the "
                            "withdrawn v1 preview figure of 114,631 ha, which was a "
                            "mosaic-extent number against the d4 tile alone."),
             **common),
        dict(number_id="taskU_denominator_census_x_lidar_ha",
             label="Census INTERSECT LiDAR area",
             grain="pixel", scope_filter="census valid AND LiDAR both-valid on-property",
             period_label="2009_and_2021", denominator="n/a - this IS the denominator",
             pixel_constant=0.062351428, pinned_value=float(f["denominator_census_intersect_lidar_ha"]),
             support_level="pixel",
             caveat=("Area-weighted and threshold-free: LiDAR both-valid aggregated UP to "
                     "the 24.970268 m census grid by area-weighted mean, never the census "
                     "interpolated down. 99.88% of the 67,349.3 ha the census maps. Use for "
                     "U-Q4b concordance and anything crossing a census product with a LiDAR "
                     "product. NEVER against the property, never against 85,882.6 ha."),
             decision_note=("The LiDAR reaches 85,882.6 ha; the census maps 67,349.3 ha. "
                            "Crossing them on either parent area would be a rebasing error. "
                            "Thresholded counts (coverage >= 0.5 / 0.99 / 1.0) are in "
                            "Output/tables/taskU_gateU1_facts.csv as context for pinning "
                            "U-Q4b's binary rule; the registered value uses no threshold."),
             **common),
    ]


def existing_columns(con, table) -> set[str]:
    return {r[1] for r in con.execute(f"PRAGMA table_info({table})")}


def upsert(con, table, rows) -> None:
    if not rows:
        return
    cols = list(rows[0].keys())
    ph = ", ".join(["?"] * len(cols))
    con.executemany(
        f"INSERT OR REPLACE INTO {table} ({', '.join(cols)}) VALUES ({ph})",
        [tuple(r[c] for c in cols) for r in rows])


def main(mode: str) -> None:
    if mode not in ("check", "execute"):
        raise SystemExit(f"unknown mode {mode!r}; use 'check' or 'execute'")

    f = load_facts()
    ras = build_raster_rows()
    head = build_headline_rows(f)

    ids = [r["raster_asset_id"] for r in ras]
    if len(set(ids)) != len(ids):
        raise SystemExit("ABORT: duplicate raster_asset_id")
    for r in ras:
        for col in ("path", "checksum_sha256", "legend_semantics", "source_crs"):
            if not r[col]:
                raise SystemExit(f"ABORT: {r['raster_asset_id']} empty {col!r}")

    DRYRUN.parent.mkdir(parents=True, exist_ok=True)
    with DRYRUN.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["target_table", "id", "path", "stage_code", "epoch_label",
                    "source_crs", "legend_status", "file_bytes", "checksum_sha256"])
        for r in ras:
            w.writerow(["raster_asset", r["raster_asset_id"], r["path"], r["stage_code"],
                        r["epoch_label"], r["source_crs"], r["legend_status"],
                        r["file_bytes"], r["checksum_sha256"]])
        for r in head:
            w.writerow(["dim_headline_number", r["number_id"], r["source_object"], "", "",
                        "", "", "", ""])

    uri = f"file:{DB.as_posix()}?mode=ro" if mode == "check" else DB.as_posix()
    con = sqlite3.connect(uri, uri=(mode == "check"))
    try:
        if mode == "check":
            missing = [(t, c) for t, c, _ in NEW_COLUMNS if c not in existing_columns(con, t)]
            have = {r[0] for r in con.execute(
                "SELECT raster_asset_id FROM raster_asset WHERE run_id = ?", (RUN_ID,))}
            hn = {r[0] for r in con.execute(
                "SELECT number_id FROM dim_headline_number WHERE number_id LIKE 'taskU_%'")}
            print(f"[check] columns to add          : {len(missing)} {missing}")
            print(f"[check] raster rows to upsert   : {len(ras)} "
                  f"({len(have)} already carry run_id={RUN_ID})")
            print(f"[check] headline rows to upsert : {len(head)} "
                  f"({len(hn)} taskU_* already present)")
            print(f"[check] raster_asset total now  : "
                  f"{con.execute('SELECT COUNT(*) FROM raster_asset').fetchone()[0]}")
            print(f"[check] dry-run CSV             : {rel(DRYRUN)}")
            print("[check] NO DB WRITE performed.")
            return

        added = 0
        for table, col, typ in NEW_COLUMNS:
            if col not in existing_columns(con, table):
                con.execute(f"ALTER TABLE {table} ADD COLUMN {col} {typ}")
                added += 1
        con.commit()
        print(f"[execute] columns added: {added}")

        con.execute(
            "INSERT OR REPLACE INTO workflow_run "
            "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
            "VALUES (?, ?, ?, ?, 1, 'REVIEW')",
            (RUN_ID, RUN_DT, "scripts/14_lidar/U1_common_frame.py + U1_register.py",
             json.dumps({"gate": "U1", "spec": SPEC, "run": "A",
                         "denominator_both_valid_ha": f["denominator_taskU_both_valid_ha"],
                         "denominator_census_x_lidar_ha":
                             f["denominator_census_intersect_lidar_ha"],
                         "coregistration_r": f["coregistration_r_zero_offset"],
                         "coregistration_peak_px": f["coregistration_peak_offset_px"]})))

        before = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
        upsert(con, "raster_asset", ras)
        upsert(con, "dim_headline_number", head)
        con.commit()
        after = con.execute("SELECT COUNT(*) FROM raster_asset").fetchone()[0]
        print(f"[execute] raster_asset {before} -> {after} ({len(ras)} rows upserted)")
        print(f"[execute] dim_headline_number now "
              f"{con.execute('SELECT COUNT(*) FROM dim_headline_number').fetchone()[0]} rows")

        # assertions - additive only
        views = con.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='view'").fetchone()[0]
        print(f"[execute] assertion - views present: {views} (none dropped)")
        bad = con.execute("SELECT COUNT(*) FROM raster_asset WHERE run_id=? "
                          "AND (checksum_sha256 IS NULL OR source_crs IS NULL "
                          "OR legend_semantics IS NULL)", (RUN_ID,)).fetchone()[0]
        print(f"[execute] assertion - Task U rows missing required metadata: {bad}")
    finally:
        con.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
