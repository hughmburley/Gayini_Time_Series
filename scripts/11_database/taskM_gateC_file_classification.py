#!/usr/bin/env python3
"""Tier 2 · Task M · Gate C — file-level Gate B classification, written to Output/.

WHY THIS EXISTS. Gate B classifies *files*; the database carries `framing_label` and
`superseded_flag` on *asset rows*. Most classified files have no asset row — Gate B
Rule 1 (Latest_results), Rule 6 (background rasters) and Rule 7 (_archive,
review_bundles, diagnostics) all say "do not register". Their classification therefore
cannot live in the DB without registering them, which the same rules forbid.

So it lives here, in Output/, as the record — per the CLAUDE.md standing rule that
Output/ is the record and docs/ is never a result. `db_labelled` says, for every row,
whether the DB also carries the classification.

Read-only over the repository. Writes one CSV. Registers nothing, changes nothing.

Usage:  python scripts/11_database/taskM_gateC_file_classification.py
Output: Output/tables/taskM_gateC_file_classification.csv
"""
from __future__ import annotations

import csv
import datetime
import os
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT = ROOT / "Output" / "tables" / "taskM_gateC_file_classification.csv"

RULE8_PATHS = {
    "Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv",
    "Output/diagnostics/tier2H_h2_green_fraction_at_floor.csv",
    "Output/tables/taskM_green_at_floor_area.csv",
    "Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif",
    "Output/rasters/fc_intermediate/fc_pv_3577_wy1988_2023.tif",
}

# Gate B D-1: the docs/ duplicates are superseded. They sit outside Output/, so they
# are added explicitly rather than found by the walk.
DOCS_DUPLICATES = [
    "docs/census_summaries/census_community_flood_freq_means.csv",
    "docs/census_summaries/census_flood_zone_by_community.csv",
    "docs/census_summaries/census_percentile_by_community.csv",
]


def registered_index() -> dict[str, tuple[str, str]]:
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    idx: dict[str, tuple[str, str]] = {}
    for table, idc in [("raster_asset", "raster_asset_id"),
                       ("figure_asset", "figure_asset_id"),
                       ("report_asset", "report_asset_id"),
                       ("census_asset", "census_asset_id")]:
        for aid, path in con.execute(f"SELECT {idc}, path FROM {table}"):
            if path:
                idx.setdefault(path.replace("\\", "/").lower(), (table, aid))
    con.close()
    return idx


def classify(p: str) -> tuple[str, str | None, int | None, str]:
    """-> (gate_b_rule, framing_label, superseded_flag, note)"""
    if p in RULE8_PATHS:
        return ("Rule 8", "census_8058", 0,
                "green-share-at-the-floor provenance chain; registered by Gate C")
    if p.startswith("Output/figures/Latest_results/"):
        return ("Rule 1", None, 1,
                "duplicate export folder; not registered. framing_label left NULL - "
                "Gate B says inherit from the Output/figures/ root twin, but only 15 of "
                "54 have a root twin, so no label is inferred for the rest")
    if p.startswith("Output/rasters/inundation_pre_post/"):
        return ("Rule 4", "conservation_2019", 1, "retired 2019 pre/post framing")
    if p.startswith("Output/rasters/inundation_background/"):
        return ("Rule 6", "context", 0,
                "sensitivity-analysis intermediate; deliberately not registered (D-2)")
    if p.startswith("Output/rasters/task_J/") or p.startswith("Output/figures/maps/task_J/") \
            or (p.startswith("Output/tables/task_J_gate") and p.endswith(".csv")):
        return ("Rule 5", "bank_cut_2018", 0, "Task J 2018 bank-cut; live")
    if p.startswith("Output/figures/plots/task_J/"):
        return ("Rule 5", "bank_cut_2018", 0,
                "Task J figure present on disk but OUT of the Gate C registration set - "
                "spec C.2 names only J-F1 and J-F2 and supplies verbatim captions for "
                "those two only. Flagged for a caption decision, not registered")
    if "/_archive/" in p or p.startswith("Output/_archive/"):
        return ("Rule 7", None, 1, "already archived; left alone")
    if p.startswith("Output/review_bundles/"):
        return ("Rule 7", None, 1, "frozen point-in-time snapshot; the audit record")
    if p.startswith("Output/csv/"):
        return ("D-3", None, None, "deferred by decision; left unclassified")
    if p.startswith("Output/diagnostics/"):
        return ("Rule 7", None, None, "working scratch; left unclassified")
    if p.startswith("Output/figures/dashboards/D1_paddock_") and p.endswith(".png"):
        return ("Rule 3", "plot_support", 0, "registered by Gate C")
    if p.startswith("Output/figures/C1_veg_regime_paddock_") and p.endswith(".png"):
        return ("Rule 3", "census_8058", 0, "registered by Gate C")
    if p.endswith(".pdf") and Path(ROOT / (p[:-4] + ".png")).is_file():
        return ("Rule 2", None, 0,
                "print companion of the canonical PNG; live, deliberately not registered")
    return ("", None, None, "")


def main() -> None:
    reg = registered_index()
    rows = []

    seen: set[str] = set()
    for base in [ROOT / "Output"]:
        for dirpath, _dirnames, filenames in os.walk(base):
            for fn in filenames:
                full = Path(dirpath) / fn
                p = full.relative_to(ROOT).as_posix()
                if p in seen:
                    continue
                seen.add(p)
                rule, label, flag, note = classify(p)
                table, aid = reg.get(p.lower(), ("none", ""))
                st = full.stat()
                rows.append({
                    "path": p,
                    "bytes": st.st_size,
                    "mtime_utc": datetime.datetime.fromtimestamp(
                        st.st_mtime, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "gate_b_rule": rule,
                    "framing_label": label or "",
                    "superseded_flag": "" if flag is None else flag,
                    "registered_in": table,
                    "asset_id": aid,
                    "db_labelled": "Y" if (table != "none" and label) else "N",
                    "note": note,
                })

    for p in DOCS_DUPLICATES:
        full = ROOT / p
        if not full.is_file():
            continue
        st = full.stat()
        rows.append({
            "path": p, "bytes": st.st_size,
            "mtime_utc": datetime.datetime.fromtimestamp(
                st.st_mtime, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "gate_b_rule": "D-1", "framing_label": "census_8058", "superseded_flag": 1,
            "registered_in": "none", "asset_id": "", "db_labelled": "N",
            "note": "superseded duplicate of the canonical Output/census/summaries/ copy. "
                    "Deliberately NOT registered: docs/ is not a product tree",
        })

    rows.sort(key=lambda r: r["path"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    from collections import Counter
    print(f"rows: {len(rows)}")
    print("by rule:", dict(Counter(r["gate_b_rule"] or "(unclassified)" for r in rows)))
    print("db_labelled:", dict(Counter(r["db_labelled"] for r in rows)))
    print("wrote", OUT.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
