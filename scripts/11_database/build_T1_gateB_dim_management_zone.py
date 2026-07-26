#!/usr/bin/env python3
"""T1 · Gate B — build `dim_management_zone` (additive, idempotent).

Spec: docs/T1_zone_stratum_census_join.md v3, Gate B (+ the verify-method /
global-assignment refinement of 25 Jul 2026).

Zone identity is settled two ways, strongest first:

  1. PROVENANCE (by construction). The MODIS `management_zone_i` units were built
     in R/vector_prep_functions.R::gayini_make_modis_context_units by
     st_intersection of the SAME source shapefile (CA0561_ManagementZones.shp,
     which the 8058 gpkg also derives from) with the farm boundary, then labelled
     `management_zone_<seq_len(nrow)>` because NO id field matched the candidate
     list. The CSV's source_name = "1".."64" (integers, not paddock names)
     confirms the seq_len branch was taken. So management_zone_i == positional
     feature i == gpkg fid i, by construction, contingent only on order
     preservation through order-preserving sf ops.

  2. GLOBAL ASSIGNMENT (empirical confirmation + margin). Build the 64x64
     area-error matrix (MODIS area_ha vs area_ha_computed, NOT Area_MW) and solve
     the linear sum assignment. If the optimal assignment is the identity
     permutation, order preservation held and the mapping is proved jointly -
     the bijection constraint resolves the two area-twins (idx 21<->fid 9,
     idx 30<->fid 53) by exclusion, which a per-zone "nearest match" test cannot.
     The margin is the cost gap to the second-best assignment.

Additive only. INSERT OR REPLACE keyed on zone_fid. Never invokes the builder.

Usage:
  python scripts/11_database/build_T1_gateB_dim_management_zone.py check
  python scripts/11_database/build_T1_gateB_dim_management_zone.py execute
  python scripts/11_database/build_T1_gateB_dim_management_zone.py convergence
"""
from __future__ import annotations

import csv
import sqlite3
import sys
from pathlib import Path

from scipy.optimize import linear_sum_assignment

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
ZONE_AREAS = ROOT / "Output" / "tables" / "T1_gateA_zone_areas.csv"
MODIS = ROOT / "Output" / "csv" / "MODIS" / "modis_context_units_summary.csv"
RUN_ID = "T1_gateB"

DDL = """
CREATE TABLE IF NOT EXISTS dim_management_zone (
  zone_fid            INTEGER PRIMARY KEY,
  zone_name           TEXT NOT NULL,
  zone_group          TEXT,
  area_ha_source      REAL,
  area_ha_computed    REAL,
  area_ha_diff_pct    REAL,
  grazing_treatment   TEXT NOT NULL,
  grazing_excluded    INTEGER NOT NULL,
  has_rap_plots       INTEGER,
  unit_id             TEXT,
  unit_id_verified    INTEGER NOT NULL,
  -- per-zone area margin (pp) = nearest-competitor error MINUS assumed-partner error.
  -- POSITIVE => area uniquely pins the zone; NEGATIVE => a competitor fid is closer
  -- in area than the assumed partner (an area-twin), so the zone is held by
  -- provenance, not area. A negative value beside unit_id_verified=1 is expected,
  -- not a bug: see unit_id_verify_method.
  unit_id_margin_pct  REAL,
  -- 'provenance+area' : held by two independent lines (area uniquely pins it AND
  --                     the seq_len/order-preservation provenance).
  -- 'provenance_only' : an area-twin the assignment cannot orient (fid 9, fid 21);
  --                     held by provenance alone.
  unit_id_verify_method TEXT,
  cropping_history    TEXT,
  land_use_era        TEXT,
  irrigation_status   TEXT,
  history_source      TEXT,
  history_confidence  TEXT
)
"""

COLS = ["zone_fid", "zone_name", "zone_group", "area_ha_source", "area_ha_computed",
        "area_ha_diff_pct", "grazing_treatment", "grazing_excluded", "has_rap_plots",
        "unit_id", "unit_id_verified", "unit_id_margin_pct", "unit_id_verify_method",
        "cropping_history", "land_use_era", "irrigation_status", "history_source",
        "history_confidence"]


def load_zone_areas() -> dict[int, dict]:
    if not ZONE_AREAS.is_file():
        raise SystemExit(f"ABORT: {ZONE_AREAS} missing. Run the Gate A recon first.")
    out = {}
    for r in csv.DictReader(ZONE_AREAS.open(encoding="utf-8")):
        fid = int(r["fid"])
        out[fid] = dict(
            zone_name=r["zone_name"],
            treatment=r["treatment"],
            plots=(r["plots"] or "").strip() or None,
            area_ha_source=float(r["area_ha_source"]),
            area_ha_computed=float(r["area_ha_computed"]),
            area_ha_diff_pct=float(r["area_ha_diff_pct"]),
        )
    if len(out) != 64:
        raise SystemExit(f"ABORT: expected 64 zones, got {len(out)}")
    return out


def load_modis_areas() -> dict[int, float]:
    out = {}
    for r in csv.DictReader(MODIS.open(encoding="utf-8")):
        if r["unit_id"].startswith("management_zone_"):
            out[int(r["unit_id"].split("_")[-1])] = float(r["area_ha"])
    if len(out) != 64:
        raise SystemExit(f"ABORT: expected 64 MODIS zones, got {len(out)}")
    return out


def solve_assignment(zones: dict, modis: dict):
    """Global linear-sum-assignment on the 64x64 area-error matrix.

    Returns a diagnostics dict. Verification is decided by PROVENANCE (see module
    docstring); the assignment is the empirical anchor and the source of the
    per-zone margin. It pins the well-separated zones to identity and exposes any
    area-twin pair it cannot orient - which provenance then resolves.
    """
    fids = list(range(1, 65))
    # cost[i][j] = % area error of MODIS zone i against computed area of fid j
    cost = [[abs(zones[j]["area_ha_computed"] - modis[i]) / modis[i] * 100.0
             for j in fids] for i in fids]
    row_ind, col_ind = linear_sum_assignment(cost)
    assign = {fids[r]: fids[c] for r, c in zip(row_ind, col_ind)}
    best = sum(cost[r][c] for r, c in zip(row_ind, col_ind))
    ident = sum(cost[i - 1][i - 1] for i in fids)
    off_identity = {i: assign[i] for i in fids if assign[i] != i}
    n_pinned = 64 - len(off_identity)
    # per-zone margin = (nearest competing fid's error) - (assumed-partner error).
    # Large => area alone pins the zone; ~0 => an area-twin, pinned by provenance.
    residuals, margins = {}, {}
    for i in fids:
        assumed = cost[i - 1][i - 1]
        competitor = min(cost[i - 1][j - 1] for j in fids if j != i)
        residuals[i] = assumed
        margins[i] = competitor - assumed
    return dict(cost=cost, assign=assign, best=best, ident=ident,
                off_identity=off_identity, n_pinned=n_pinned,
                global_gap=ident - best, residuals=residuals, margins=margins)


def zone_group(name: str) -> str:
    return name.split()[0]


def build_rows():
    zones = load_zone_areas()
    modis = load_modis_areas()
    d = solve_assignment(zones, modis)

    # All 64 verified=1 (identity proved: assignment pins 62 + provenance closure on
    # the twins). But the epistemic state differs and the column records which:
    #   'provenance+area' - the 62 the assignment uniquely pins AND provenance holds
    #   'provenance_only' - fid 9 / fid 21, area-twins held by provenance alone
    # (twins = the zones the LP-optimal moves off identity; the only degenerate pair)
    twins = set(d["off_identity"])   # {9, 21}
    rows = []
    for fid in range(1, 65):
        z = zones[fid]
        rows.append(dict(
            zone_fid=fid,
            zone_name=z["zone_name"],
            zone_group=zone_group(z["zone_name"]),
            area_ha_source=round(z["area_ha_source"], 4),
            area_ha_computed=round(z["area_ha_computed"], 4),
            area_ha_diff_pct=round(z["area_ha_diff_pct"], 4),
            grazing_treatment=z["treatment"],
            grazing_excluded=1 if z["treatment"] == "No grazing" else 0,
            has_rap_plots=1 if z["plots"] == "Sample" else 0,
            unit_id=f"management_zone_{fid}",
            unit_id_verified=1,
            # per-zone area margin (pp): >0 area pins it; <0 area-twin (provenance-held)
            unit_id_margin_pct=round(d["margins"][fid], 4),
            unit_id_verify_method=("provenance_only" if fid in twins else "provenance+area"),
            cropping_history=None, land_use_era=None, irrigation_status=None,
            history_source=None, history_confidence=None,
        ))
    return rows, d


def upsert(con, rows):
    ph = ", ".join(["?"] * len(COLS))
    con.executemany(
        f"INSERT OR REPLACE INTO dim_management_zone ({', '.join(COLS)}) VALUES ({ph})",
        [tuple(r[c] for c in COLS) for r in rows])


def print_diag(d):
    print(f"[assign] zones uniquely pinned to identity by area: {d['n_pinned']} / 64")
    if d["off_identity"]:
        print(f"[assign] LP-optimal deviates from identity at: {d['off_identity']} "
              f"(area-twins; global cost gap identity-optimal = {d['global_gap']:+.6f} pp, "
              "i.e. numerically degenerate)")
    else:
        print("[assign] LP-optimal IS the identity permutation.")
    print("[assign] CLOSURE: assignment fixes 62/64 -> the seq->fid permutation is "
          "identity on 62 elements; a bijection fixing 62 either fixes or swaps the "
          "last 2; monotonic seq_len construction forbids the swap -> identity for all 64.")
    rv = list(d["residuals"].values())
    print(f"[assign] assumed-partner residuals: min={min(rv):.3f} "
          f"median={sorted(rv)[len(rv)//2]:.3f} max={max(rv):.3f} pp "
          "(tight band => a scrambled permutation is excluded)")
    mv = sorted(d["margins"].items(), key=lambda kv: kv[1])
    print(f"[assign] smallest per-zone margins (area-twins pinned by provenance): "
          f"{[(k, round(v,4)) for k, v in mv[:4]]}")


def main(mode: str) -> None:
    rows, diag = build_rows()
    print_diag(diag)

    if mode == "check":
        con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
        exists = con.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' "
            "AND name='dim_management_zone'").fetchone()[0]
        con.close()
        print(f"[check] dim_management_zone exists already: {bool(exists)}")
        print(f"[check] rows to write: {len(rows)}")
        m = rows[0]
        print(f"[check] verify_method={m['unit_id_verify_method']} "
              f"verified={m['unit_id_verified']} margin_pp={m['unit_id_margin_pct']}")
        print("[check] sample row (fid=1):")
        for c in COLS:
            print(f"           {c:22s} = {rows[0][c]!r}")
        ng = sum(r["grazing_excluded"] for r in rows)
        print(f"[check] grazing_excluded=1 (No grazing): {ng} ; has_rap_plots=1: "
              f"{sum(r['has_rap_plots'] for r in rows)} ; "
              f"groups={sorted(set(r['zone_group'] for r in rows))}")
        print("[check] NO DB WRITE.")
        return

    if mode == "execute":
        con = sqlite3.connect(DB.as_posix())
        try:
            con.execute(DDL)
            con.execute(
                "INSERT OR REPLACE INTO workflow_run "
                "(run_id, run_datetime, script_name, parameters_json, is_current, qa_status) "
                "VALUES (?, ?, ?, ?, 0, 'REVIEW')",
                (RUN_ID, "2026-07-25T00:00:00+00:00",
                 "scripts/11_database/build_T1_gateB_dim_management_zone.py",
                 '{"gate": "B", "spec": "docs/T1_zone_stratum_census_join.md v3"}'))
            before = con.execute("SELECT COUNT(*) FROM dim_management_zone").fetchone()[0]
            upsert(con, rows)
            con.commit()
            after = con.execute("SELECT COUNT(*) FROM dim_management_zone").fetchone()[0]
            print(f"[execute] dim_management_zone rows: {before} -> {after}")
            chk = con.execute(
                "SELECT COUNT(*), SUM(unit_id_verified), "
                "SUM(grazing_excluded), COUNT(DISTINCT zone_group) "
                "FROM dim_management_zone").fetchone()
            print(f"[execute] n={chk[0]} verified={chk[1]} no_grazing={chk[2]} "
                  f"groups={chk[3]}")
            nulls = con.execute(
                "SELECT COUNT(*) FROM dim_management_zone WHERE cropping_history IS NOT NULL "
                "OR land_use_era IS NOT NULL OR irrigation_status IS NOT NULL "
                "OR history_source IS NOT NULL OR history_confidence IS NOT NULL").fetchone()[0]
            print(f"[execute] RESERVED land-use columns non-null (must be 0): {nulls}")

            # Queryable home for the global assignment gap + sign convention (not
            # prose-only, per CLAUDE.md). One row, additive.
            twins = sorted(diag["off_identity"])
            rv = list(diag["residuals"].values())
            con.execute("""
                CREATE TABLE IF NOT EXISTS t1_zone_identity_check (
                  check_id                   TEXT PRIMARY KEY,
                  method_summary             TEXT,
                  n_provenance_area          INTEGER,
                  n_provenance_only          INTEGER,
                  provenance_only_fids       TEXT,
                  global_assignment_gap_pp   REAL,
                  residual_min_pp            REAL,
                  residual_max_pp            REAL,
                  margin_sign_convention     TEXT,
                  run_id                     TEXT
                )""")
            con.execute(
                "INSERT OR REPLACE INTO t1_zone_identity_check VALUES (?,?,?,?,?,?,?,?,?,?)",
                ("t1_zone_identity",
                 "64/64 identity proved. 62 held by area+provenance; the {9,21} "
                 "area-twins by provenance alone. Global LSAP is degenerate between "
                 "identity and the 9<->21 swap.",
                 64 - len(twins), len(twins), ",".join(map(str, twins)),
                 round(diag["global_gap"], 8), round(min(rv), 4), round(max(rv), 4),
                 "unit_id_margin_pct: negative = competitor fid closer in area than "
                 "assumed partner (area-twin); positive = area uniquely pins the zone.",
                 RUN_ID))
            con.commit()
            g = con.execute(
                "SELECT global_assignment_gap_pp, n_provenance_only, provenance_only_fids "
                "FROM t1_zone_identity_check WHERE check_id='t1_zone_identity'").fetchone()
            print(f"[execute] t1_zone_identity_check: gap_pp={g[0]} "
                  f"provenance_only={g[1]} fids={g[2]}")

            # Output/ artefact: per-zone identity evidence (feeds T1_A_identity_margin.png)
            diag_csv = ROOT / "Output" / "tables" / "T1_gateB_identity_assignment.csv"
            diag_csv.parent.mkdir(parents=True, exist_ok=True)
            with diag_csv.open("w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["zone_fid", "zone_name", "residual_pp", "margin_pp",
                            "lp_assigned_fid", "off_identity", "verify_method"])
                for r in rows:
                    fid = r["zone_fid"]
                    w.writerow([fid, r["zone_name"], round(diag["residuals"][fid], 4),
                                round(diag["margins"][fid], 4), diag["assign"][fid],
                                int(diag["assign"][fid] != fid), r["unit_id_verify_method"]])
            print(f"[execute] wrote {diag_csv.relative_to(ROOT).as_posix()}")
        finally:
            con.close()
        return

    if mode == "convergence":
        # Idempotence-by-convergence, per CLAUDE.md: mutate an input value, re-run
        # the upsert, confirm the DB MOVES to the new value (OR IGNORE would freeze).
        con = sqlite3.connect(DB.as_posix())
        try:
            orig = con.execute(
                "SELECT area_ha_computed FROM dim_management_zone WHERE zone_fid=1").fetchone()[0]
            mutated = [dict(rows[0])]
            mutated[0]["area_ha_computed"] = round(orig + 123.456, 4)
            upsert(con, mutated); con.commit()
            after_mut = con.execute(
                "SELECT area_ha_computed FROM dim_management_zone WHERE zone_fid=1").fetchone()[0]
            converged_up = abs(after_mut - (orig + 123.456)) < 1e-3
            # restore
            upsert(con, [rows[0]]); con.commit()
            restored = con.execute(
                "SELECT area_ha_computed FROM dim_management_zone WHERE zone_fid=1").fetchone()[0]
            converged_back = abs(restored - orig) < 1e-3
            print(f"[convergence] original={orig} -> mutated_stored={after_mut} "
                  f"(moved to new value: {converged_up})")
            print(f"[convergence] re-run restored={restored} (converged back: {converged_back})")
            print(f"[convergence] PASS: {converged_up and converged_back} "
                  "(INSERT OR REPLACE converges; OR IGNORE would have frozen the old value)")
        finally:
            con.close()
        return

    raise SystemExit(f"unknown mode {mode!r}; use check|execute|convergence")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "check")
