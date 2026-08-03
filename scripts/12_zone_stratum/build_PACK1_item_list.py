#!/usr/bin/env python
"""PACK-1 Gate P1 — the corrected item list. READ-ONLY, NO DB WRITES.

17 items -> 15 distinct files. M4b is in the list from the start (design-seat ruling D1/A3).
ship_flag reads from the FROZEN delta except the three DECIDE rows (P1-3).
T1 = the .csv; the .png ships alongside as T1_render, not an eighteenth item (P1-4).
Every file_path verified against disk AND the registry (P1-5).
"""
import sqlite3, csv, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
PACK = ROOT / "Output" / "pack"
FROZEN = PACK / "PACK1_input_delta_FROZEN.csv"
con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True); con.execute("PRAGMA query_only=1")
c = con.cursor()

delta = {r["pack_item_id"]: r for r in csv.DictReader(open(FROZEN, encoding="utf-8-sig"))}
reg_fig = {r[0]: r[1] for r in c.execute("SELECT path, figure_asset_id FROM figure_asset")}
reg_tab = {r[0]: r[1] for r in c.execute("SELECT path, table_asset_id FROM table_asset")}

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""): h.update(b)
    return h.hexdigest()

# item_id, type, path, claim, ship source
# PATHS RESOLVED FROM Output/pack/PACK1_input_manifest_FROZEN.csv and register v3 §3 item headers.
# An earlier draft guessed four of them and all four failed the disk check - which is what P1-5 is for.
ITEMS = [
 ("M1", "map",   "Output/figures/diagnostics/T1_A_zone_map_named.png",              "1", "not_in_delta"),
 ("M2", "map",   "Output/figures/diagnostics/T2_G_plot_paddock_coverage.png",       "5", "not_in_delta"),
 ("M3", "map",   "Output/figures/diagnostics/T2_B2_duration_map.png",             "3", "delta"),
 ("M4", "map",   "Output/figures/T13_D1_part_state_map_and_scatter.png",          "6", "not_in_delta"),
 ("M4b","map",   "Output/figures/T13_D2_part_state_map_sensitivity.png",          "6", "not_in_delta"),
 ("M5", "map",   "Output/figures/M5_dual_grain_floor_and_flood.png",              "3", "delta"),
 ("M5b","map",   "Output/figures/M5b_paddock_residual_from_expectation.png",      "3", "delta"),
 ("F1", "figure","Output/figures/diagnostics/T2_E_paddock_trajectories.png",      "1", "delta"),
 ("F2", "figure","Output/figures/diagnostics/T2_E_paddock_trajectories_mean.png",    "5", "delta"),
 ("F3", "figure","Output/figures/F3_annual_gap_series.png",                       "1", "not_in_delta"),
 ("F4", "figure","Output/figures/diagnostics/T2_F_gap_decomposition.png",         "2", "delta"),
 ("F5", "figure","Output/figures/F5_cover_vs_water_64_paddocks.png",              "3", "delta"),
 ("F6", "figure","Output/figures/diagnostics/T6_A_three_arm_grid.png",            "4", "delta"),
 ("F7", "figure","Output/figures/T13_D1_part_state_map_and_scatter.png",          "6", "not_in_delta"),
 ("T1", "table", "Output/tables/T1_conserved_paddock_comparison.csv",             "5", "ruling"),
 ("T2", "table", "Output/tables/T13_gateC_classification.csv",                    "6", "delta"),
 ("T3", "table", None,                                                            "7", "no_file"),
]
RENDER = ("T1_render", "render", "Output/figures/T1_conserved_paddock_comparison.png", "5")

rows, stops = [], []
for item_id, typ, path, claim, src in ITEMS:
    if path is None:
        rows.append(dict(item_id=item_id, type=typ, file_path="", sha256="", registered_in="",
                         claim_supported=claim, ship_flag="SHIP",
                         caption_status="TEXT_ONLY - no file; the item is a table rendered in the workbook"))
        continue
    p = ROOT / path
    if not p.exists(): stops.append(f"{item_id}: {path} NOT ON DISK"); continue
    reg = reg_fig.get(path) or reg_tab.get(path)
    if not reg: stops.append(f"{item_id}: {path} NOT IN THE REGISTRY")
    if src == "delta":
        sf = delta[item_id]["ship_flag_after"]
    elif src == "ruling":
        sf = "SHIP"          # P1-3/P1-4: T1_csv takes SHIP as item T1 per the 2 Aug ruling
    else:
        sf = "SHIP"
    rows.append(dict(item_id=item_id, type=typ, file_path=path, sha256=sha(p),
                     registered_in=reg or "UNREGISTERED", claim_supported=claim, ship_flag=sf,
                     caption_status="PENDING_P3"))
p = ROOT / RENDER[2]
rows.append(dict(item_id=RENDER[0], type=RENDER[1], file_path=RENDER[2], sha256=sha(p),
                 registered_in=reg_fig.get(RENDER[2], "UNREGISTERED"), claim_supported=RENDER[3],
                 ship_flag="SHIP",
                 caption_status="RENDERING OF T1 - listed as the rendering, NOT an eighteenth item"))

PACK.mkdir(parents=True, exist_ok=True)
out = PACK / "PACK1_item_list.csv"
with open(out, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

items = [r for r in rows if r["item_id"] != "T1_render"]
paths = [r["file_path"] for r in items if r["file_path"]]
print(f"items: {len(items)} (expect 17)")
print(f"distinct non-null paths: {len(set(paths))} (expect 15)")
print(f"rows in file incl T1_render: {len(rows)}")
print(f"paths under docs/: {sum(1 for x in paths if x.startswith('docs/'))} (expect 0)")
print(f"unregistered: {[r['item_id'] for r in rows if r['registered_in']=='UNREGISTERED']}")
print(f"ship_flag: " + str({s: sum(1 for r in rows if r['ship_flag'] == s) for s in {r['ship_flag'] for r in rows}}))
print(f"\nF7 shares M4's file: {rows[13]['file_path']==rows[3]['file_path']}")
if stops:
    print("\n*** STOP - disagreements ***")
    for s in stops: print("   ", s)
else:
    print("\nevery path exists on disk AND resolves in the registry")
assert len(items) == 17 and len(set(paths)) == 15 and not stops
print(f"\nwrote {out}")
con.close()
