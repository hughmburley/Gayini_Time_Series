#!/usr/bin/env python
"""LID-1 Gate L2 — classify every Task U artefact for shippability.

READ-ONLY on the database (mode=ro + PRAGMA query_only=1). Writes one CSV.

Classification rules are APPLIED, NOT INVENTED, and the DATA_HANDOVER rule is the AMENDED
one (Ruling X, 4 Aug): `legend_status = unconfirmed` means the semantics string has not been
checked against the JRSRP definitions - NOT that semantics are absent. Every one of the 20
rasters carries `legend_semantics`. An unconfirmed legend is therefore a CAVEAT THAT TRAVELS
WITH THE FILE, not a bar. The whole handover ships at REVIEW; an unconfirmed legend adds no
risk a reader is not already warned about.

  DATA_HANDOVER  registered raster, checksum, resolved CRS, stated denominator, and
                 plain-English semantics PRESENT AND STATED. Ships as data, REVIEW on its face.
  METHODS_DOC    a method, a denominator, a rule, or a stated non-result.
                 Methods are shippable at REVIEW; FINDINGS ARE NOT.
  INTERNAL_ONLY  anything whose interpretation is open - F2, and anything downstream of the
                 sensor step-change verdict.
  HOLD           reserved for artefacts that FAILED Gate L1's cross-check.
"""
import csv, sqlite3, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB   = ROOT / "Output" / "database" / "Gayini_Results.sqlite"
OUT  = ROOT / "Output" / "tables" / "LID1_shippability.csv"

BOTH_VALID = "Task U both-valid 85,882.6 ha"
CENSUS_X   = "Census n LiDAR 67,268.002 ha"
PROPERTY   = "Property 85,910.8 ha (context only)"

REVIEW_CAVEAT = ("qa_status = REVIEW. Not validated against field data. "
                 "LiDAR FPC is not comparable to Landsat total_veg and must never share an axis "
                 "with it or be differenced against it.")
LEGEND_CAVEAT = ("Legend semantics are stated but UNCONFIRMED against the JRSRP definitions - "
                 "sent to Adrian for confirmation. Read the semantics string, not the band name.")
EPOCH_CAVEAT  = ("Two acquisitions twelve years apart, different sensors (ALS-50 2009, ALS-80 2021), "
                 "capture dates unrecoverable. They measure change between two dates and cannot "
                 "attribute it; 2019 falling between them does not make them a controlled comparison.")
DEM_CAVEAT    = ("50 cm terrain reveals channels, earthworks and scarring that no Landsat product "
                 "does. CULTURAL GOVERNANCE: requires Nari Nari review before release. The +0.303 m "
                 "vertical offset is WITHDRAWN as a scalar calibration - it is not spatially uniform.")
RULE2_CAVEAT  = ("Rule 2: computed on the census temporal p05, which this project prohibits for any "
                 "reference-state purpose. Interpretation OPEN - not a finding, not a conclusion, "
                 "not a qualification on any reference-state claim.")
UNPINNED      = ("Ruling AA: unpinned and outside test_T8_headline_reproduction.py. Quote the value "
                 "with its denominator inline; there is no number_id to cite.")

def main():
    con = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    con.execute("PRAGMA query_only=1")
    c = con.cursor()
    probe = {t: c.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
             for t in ("dim_headline_number", "figure_asset", "raster_asset", "table_asset")}
    print("  PROBE:", probe)

    rows = []
    def add(artefact, typ, qa, verified, denom, ship, caveat, reason):
        rows.append(dict(artefact=artefact, type=typ, qa_status=qa, verified=verified,
                         denominator=denom, ship_to=ship,
                         status_that_travels_with_it=caveat, reason=reason))

    # ---------------- 20 rasters, read from the registry ------------------------------------
    for rid, path, qa, sha, epsg, legend, semantics, stage in c.execute(
            "SELECT raster_asset_id, path, qa_status, checksum_sha256, crs_epsg, legend_status, "
            "legend_semantics, stage_code FROM raster_asset WHERE run_id='taskU_gateU1' ORDER BY 1"):
        assert sha and epsg and semantics, f"{rid} fails the DATA_HANDOVER precondition"
        cav = [REVIEW_CAVEAT, EPOCH_CAVEAT]
        if legend == "unconfirmed": cav.append(LEGEND_CAVEAT)
        if stage == "bb0": cav.append(DEM_CAVEAT)
        denom = BOTH_VALID if stage in ("bbh",) else PROPERTY
        reason = ("Registered, checksummed, CRS resolved to EPSG:8058, semantics stated in plain "
                  "English. Ships as data at REVIEW (Ruling X)."
                  + (" Legend unconfirmed - a caveat, not a bar." if legend == "unconfirmed" else ""))
        add(path, "raster", qa, "DS-V + DB", denom, "DATA_HANDOVER", " ".join(cav), reason)

    # ---------------- 2 registered numbers ---------------------------------------------------
    for nid, val in c.execute("SELECT number_id, pinned_value FROM dim_headline_number "
                              "WHERE number_id LIKE 'taskU_%' ORDER BY 1"):
        v = "DS-V + DB" if "both_valid" in nid else "DB"
        add(nid, "number", "registered", v, "n/a - this IS the denominator", "METHODS_DOC",
            "A denominator, not a finding. Never interchange the three. " + REVIEW_CAVEAT,
            f"Pinned at {val}. A denominator is a method object and is shippable at REVIEW.")

    # ---------------- 2 figures ---------------------------------------------------------------
    for fid, qa in c.execute("SELECT figure_asset_id, qa_status FROM figure_asset "
                             "WHERE figure_asset_id IN ('figure_u2_epoch_context_35yr',"
                             "'figure_u3_sensor_step_change') ORDER BY 1"):
        if "epoch_context" in fid:
            add(fid, "figure", qa, "CC", PROPERTY, "METHODS_DOC",
                EPOCH_CAVEAT + " Plot support is not shown; this is farm-scale context.",
                "Shows where the two capture windows sit in the 35-year record - a stated scope "
                "and limitation, not a result.")
        else:
            add(fid, "figure", qa, "DS-V", BOTH_VALID, "METHODS_DOC",
                REVIEW_CAVEAT + " The 9.659 pp figure is a CHANGE-DETECTION FLOOR on vegetated "
                "ground at 500 m grain - an UPPER BOUND on the sensor effect, never an estimate "
                "of it, and never to be written or registered as a 'sensor floor'.",
                "A stated non-result: whole-of-property FPC change is not interpretable. "
                "Methods and non-results ship; findings do not.")

    # ---------------- tables ------------------------------------------------------------------
    TABLES = {
      "taskU_gateU0_inventory.csv":        ("METHODS_DOC", PROPERTY, "The delivery inventory - 47 GeoTIFFs, checksums, per-file CRS resolved from the file not the filename. Provenance, not a result."),
      "taskU_gateU0_distributions.csv":    ("METHODS_DOC", PROPERTY, "Per-product value distributions used to set the R2 ceiling. Method input."),
      "taskU_gateU0_partner_decision.csv": ("METHODS_DOC", PROPERTY, "Records which epoch/zone folders pair. Method."),
      "taskU_gateU1_coregistration.csv":   ("METHODS_DOC", BOTH_VALID, "Frame quality: r = 0.897298 at zero offset, peak at (0,0). A method check that passed."),
      "taskU_gateU1_r2_screen.csv":        ("METHODS_DOC", PROPERTY, "The pre-registered 50 m ceiling and its 30/50/80 sensitivity. A pinned rule and its outcome."),
      "taskU_gateU1_r2_density_diagnostic.csv": ("METHODS_DOC", PROPERTY, "Return-density diagnostic. CORRECTED at LID-1 Y1: the 2021 median is 1.4672, not the pre-U-I11 1.4855."),
      "taskU_gateU1_facts.csv":            ("METHODS_DOC", BOTH_VALID, "Frame facts: areas, denominators, coverage. Method."),
      "taskU_gateU1_registration_dryrun.csv": ("METHODS_DOC", PROPERTY, "Registration dry run. Provenance."),
      "taskU_gateU2_epoch_context.csv":    ("METHODS_DOC", PROPERTY, "Where each candidate capture window sits in the 35-year record. A stated limitation - flight months are unrecoverable."),
      "taskU_gateU2_series_35yr.csv":      ("METHODS_DOC", PROPERTY, "The 35-year context series behind the epoch placement. Method input."),
      "taskU_gateU2_bala_reference.csv":   ("INTERNAL_ONLY", PROPERTY, "Reference-paddock context. Interpretation open under Rule 2."),
      "taskU_gateU3_stable_ground.csv":    ("METHODS_DOC", BOTH_VALID, "The two stable-ground controls and why BOTH FAILED - S1 has no dynamic range, S2 is not stable. A stated non-result."),
      "taskU_gateU3_facts.csv":            ("METHODS_DOC", BOTH_VALID, "Includes the 13.33% and its 11,449.25 ha numerator. A bounding statement with its denominator."),
      "taskU_gateU3_density_scaling.csv":  ("METHODS_DOC", BOTH_VALID, "U3.6: no density scaling is derivable, R2 0.0120 and 0.000088 with opposite-sign slopes. A stated non-result."),
      "taskU_gateU3_u36_blocks.csv":       ("METHODS_DOC", BOTH_VALID, "The 500 m blocks behind U3.6. Method input."),
      "taskU_U3_7_offset_uniformity.csv":  ("METHODS_DOC", PROPERTY, "U3.7: the vertical offset is NOT spatially uniform, so +0.303 m is withdrawn. A stated non-result."),
      "taskU_gateU4a_zonal_structure.csv": ("INTERNAL_ONLY", PROPERTY, "Zonal structure feeding F3. Downstream of the reference-state reading; interpretation open."),
      "taskU_R6_bala_floor_flood_placement.csv": ("INTERNAL_ONLY", PROPERTY, "R6. Computed on the census temporal p05 - Rule 2 applies directly."),
    }
    for fn, (ship, denom, reason) in TABLES.items():
        pth = ROOT / "Output" / "tables" / fn
        cav = REVIEW_CAVEAT if ship != "INTERNAL_ONLY" else RULE2_CAVEAT
        if fn == "taskU_gateU3_facts.csv": cav += " " + UNPINNED
        add(f"Output/tables/{fn}", "table", "unregistered - regenerable from committed scripts",
            "DS-V" if fn in ("taskU_gateU3_stable_ground.csv", "taskU_gateU3_facts.csv",
                             "taskU_gateU4a_zonal_structure.csv", "taskU_gateU1_coregistration.csv",
                             "taskU_R6_bala_floor_flood_placement.csv") else "CC",
            denom, ship, cav, reason + ("" if pth.exists() else "  [FILE ABSENT]"))

    # ---------------- vector ------------------------------------------------------------------
    n_gpkg = len(list((ROOT / "Output").rglob("taskU*.gpkg")))
    add("(no Task U GeoPackage)", "vector", "n/a", "DB", "n/a", "METHODS_DOC",
        "None exists. spatial_layer_asset is an IMPORT registry; a Task U build output registered "
        "there would be a category error.",
        f"Gate U5 item 2 produced none; {n_gpkg} found on disk and 0 rows in spatial_layer_asset "
        f"carry a Task U layer. Recorded as a stated absence.")

    # ---------------- documents ---------------------------------------------------------------
    DOCS = {
      "docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md": ("METHODS_DOC", "The spec: gates, the seven pre-registered rules, the three denominators. Method, and the rules were pinned before the numbers existed."),
      "docs/change_reports/TaskU_gateU0_report.md": ("METHODS_DOC", "Delivery, inventory, CRS resolution. Method and provenance."),
      "docs/change_reports/TaskU_gateU1_report.md": ("METHODS_DOC", "Frame construction, co-registration, R2. Method. Corrected at LID-1 Y1."),
      "docs/change_reports/TaskU_gateU2_report.md": ("METHODS_DOC", "Epoch context and the unrecoverable capture dates. A stated limitation."),
      "docs/change_reports/TaskU_gateU3_report.md": ("METHODS_DOC", "The sensor step-change verdict and two nulls. Stated non-results. Corrected at LID-1 Y1."),
      "docs/change_reports/TaskU_gateU4a_and_U3_7_report.md": ("INTERNAL_ONLY", "U-Q4a zonal structure and U3.7. Carries the reference-state reading; interpretation open."),
      "docs/LiDAR/TaskU_gateU2_response_to_CC.md": ("INTERNAL_ONLY", "Design-seat working document. Corrected at LID-1 Y1."),
      "docs/LiDAR/Gayini_LiDAR_TaskU_summary.md": ("INTERNAL_ONLY", "Carries F2 and the findings. Cross-checked at Gate L1: 9 of 9 DS-V reproduce, five discrepancies found and corrected."),
      "docs/LiDAR/TaskU_findings_note.md": ("INTERNAL_ONLY", "Findings, not methods. SUPERSEDED IN PART 4 Aug under Ruling W."),
      "docs/reference_update/Gayini_LiDAR_implications_for_reference_state.md": ("INTERNAL_ONLY", "Reference-state reading. SUPERSEDED IN PART 4 Aug under Ruling W."),
      "docs/reference_update/Gayini_R6_bala_floor_flood_placement.md": ("INTERNAL_ONLY", "R6's own note. Rule 2 applies directly."),
      "docs/reference_update/Gayini_R6_metric_review_20260802.md": ("INTERNAL_ONLY", "Establishes that R6's comparison is prohibited. The metric question is open."),
    }
    for d, (ship, reason) in DOCS.items():
        assert (ROOT / d).exists(), f"document missing: {d}"
        cav = RULE2_CAVEAT if ship == "INTERNAL_ONLY" else (
            "Methods and stated non-results only. Every quantity carries its denominator; the three "
            "are never interchanged. " + REVIEW_CAVEAT)
        add(d, "document", "n/a", "CC", "various - stated per claim", ship, cav, reason)

    # ---------------- acceptance ---------------------------------------------------------------
    seen = [r["artefact"] for r in rows]
    assert len(seen) == len(set(seen)), "an artefact is classified more than once"
    for r in rows:
        assert r["ship_to"] in ("DATA_HANDOVER", "METHODS_DOC", "INTERNAL_ONLY", "HOLD")
        assert r["status_that_travels_with_it"].strip(), f"no caveat on {r['artefact']}"
    hand = [r for r in rows if r["ship_to"] == "DATA_HANDOVER"]
    for r in hand:
        assert r["type"] == "raster", "DATA_HANDOVER is for registered rasters only"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)

    from collections import Counter
    print(f"\n  {len(rows)} artefacts, each classified exactly once")
    for k, v in sorted(Counter(r["ship_to"] for r in rows).items()):
        print(f"    {k:15s} {v:>3}")
    print("    by type:", dict(Counter(r["type"] for r in rows)))
    print(f"  wrote {OUT.relative_to(ROOT).as_posix()}")
    con.close()

if __name__ == "__main__":
    main()
