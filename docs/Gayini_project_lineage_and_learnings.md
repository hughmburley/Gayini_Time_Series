# Gayini — Project Lineage & Learnings

*Provenance record. Captures where the current analysis came from and the durable learnings from the originating "new-direction" investigation, Tier 0, and Adrian's early rulings. **This is not a live authority** — where it and the current docs differ, current wins. §9 (method traps) is the exception: it is live and cumulative, and should be read at session start.*

## 1. The pivot — why the analysis changed direction

The project moved **away from a 2019 pre/post design toward a spatially explicit annual time-series (1988–2023)**. Two reasons, both durable:

- The management-change date was uncertain, so a pre/post split was arbitrary.
- The data showed the **pre/post estimator was throwing the signal away** — averaging two periods hid the episodic flood-pulse behaviour and the within-plot inundation→vegetation relationship.

**Durable learning:** pre/post is retired as the *framing*. The analysis is full-record and spatially explicit; the plots are anchors, the analysis operates on areas/strata.

*Two later qualifications:* the **2018 bank-cut** pre/post (Task J) is a separate, additive, Adrian-requested deliverable and is **not** the retired pre/post. And Adrian's 24 July direction asks that it be retained as **one line of evidence inside the reference-state design**, not discarded.

## 2. Adrian's rulings captured in the lineage

- **The wet-rule (7 Jul 2026 — locked).** The NSW DCCEEW inundation rasters use a four-class legend: `0` dry (valid), `1` inundated = **wet**, `2` off-river storage / irrigation = **wet**, `3` cloud shadow = **mask**. Adrian ruled off-river storage counts as wet — *"those pixels were wet just the same."* Formal rule: `wet = value IN (1,2)`, `valid = value IN (0,1,2)`. The 35 Landsat sources contain `{0,1,2}` only, so the mask is currently a no-op. Durable record: `tier0_legend_decision_record.md`.
- **"Control areas near the plots."** Adrian's idea of comparison areas in the same community, across their inundation range, near the plots but excluding them — this became the **F5 stratified sampling frame** (and is the parent of Q1). *Superseded 15 July by the all-pixel census; Q1 is closed.*

## 3. Tier 0 — the foundation (locked, do not re-derive)

- **Unified annual inundation stack, 1988–2023** — one continuous per-year wet/valid raster stack from the 35 canonical `lo_YYYY_YYYY.img` sources, **EPSG:28355 (GDA94/MGA55), 25 m, 35 layers, no gaps**, wet-cell counts verified against the manifest. (Reprojected to EPSG:8058 downstream; extraction stays in 28355.)
- **Raster metadata resolved** — 100 `raster_asset` rows at the time, 0 null CRS. *(Now 126 rows, 18 at EPSG:8058, all extents populated.)*
- **The modelling spine** — `v_plot_year_analysis_spine`, **2,310 rows (66 plots × 35 years)**, ground-cover join coverage 99.8%. This is the table Tier 1 (and everything since) reads from.
- **The wet-rule** (§2).

## 4. The seed investigation — what it found, and what each became

- **Candidate annual plot-year spine** (2,310 rows, 99.8% cover overlap) → became `v_plot_year_analysis_spine`.
- **Annual inundation coverage table** → confirmed the **episodic** signal (2006-07 drought trough ≈ 0.03%; big floods 2010-11, 2016-17, 2022-23) → became **F2**.
- **Per-plot trend classification** → came out **mixed within every community** — increasing_strong and declining_strong plots side by side in Aeolian, Riverine and Inland. **This inconclusiveness is why F6 moved to a rigorous per-stratum robust test** (Theil–Sen/MK + drop-two-floods), which returned the clean result: no directional trend. *Learning: naive per-plot slopes mislead on episodic data; per-stratum robust testing was necessary.*
- **Inundation ↔ ground-cover correlations** → positive for every plot and **community-structured** (Aeolian ~0.15 → Riverine ~0.30 → Inland ~0.34–0.70) → seeded **F7**, which reproduced the pattern (median r 0.22 → 0.28 → 0.42). The seed already showed the **bare ≈ −veg** near-identity and carried a pre/post-flavoured `inundation_change_class` and a grazing category — both of which current work dropped (change class) or demoted to metadata (grazing).

## 5. Metric evolution (the durable naming lesson)

The seed, Tier 0 and early Tier 1 described the gradient as **"occurrence"** (within-year wet-extent coverage; Aeolian ~4 · Riverine ~12 · Inland ~31%). Mid-Tier-1 the headline was reframed to **between-year annual flood frequency** (`100 × wet-valid-years ÷ valid-years`), and the occurrence numbers were **demoted to a labelled secondary metric**. The DB field `annual_occurrence_pct` is that secondary — the name is a trap, recorded in `CLAUDE.md`.

*Later completion of this lesson (C10):* the headline metric has **two supports**, and both are correct. Plot support with the **any-pixel rule** gives 9 / 22 / 50 / 44; pixel support gives 6.1 / 12.9 / 28.0. `dim_metric.support` stores both rules verbatim. The metric was never wrong; only its *label* in the science spine was.

## 6. Superseded framings — do not revive

- **Pre/post** (2019 management split) as the framing — retired. *Distinct from Task J's 2018 bank-cut analysis.*
- **`inundation_change_class`** (drier_post / wetter_post / much_wetter_post) — dropped with pre/post.
- **Per-plot trend classification** (declining/increasing_strong/weak) — superseded by F6's per-stratum verdicts.
- **MER** — renamed "annual maximum observed wet footprint," kept supplementary only.
- **"Occurrence" as the headline** — superseded by flood frequency; occurrence is the secondary.
- **Task F** (Monte-Carlo sampling rebalance) — **CANCELLED** at the 15 July review, not gated. Code stays on `main`, uncalled.
- **The ~4,300 ha refugia figure** — **withdrawn** (Task M / D8). A mismatched 8058-pixel conversion of a native-30 m count. Do not reintroduce it from any older doc or deck.

## 7. Process lineage (for reference, not authority)

The `tasks` archive holds the delivery/cleanup history: `codex_context.md`, `current_run_order.md`, the Tier 0 task cards, and the output-cleanup record (`output_cleanup_policy.md`, `output_cleanup_candidates_summary.csv`, the `removed_*` and `script_rename_map` manifests). These document how the repo was built and pruned; consult them when auditing or archiving. **Live conventions are in `CLAUDE.md`.**

## 8. Where current authority lives

*Corrected 27 July 2026 — the previous version of this section named two superseded documents as authorities.*

- **`CLAUDE.md`** — the live conventions, hard rules, and provenance discipline. Read first.
- **`Gayini_Figure_Driven_Project_Ladder.docx`** — authority on figure conventions and the ladder. On *current state*, `CLAUDE.md` is newer.
- **`Gayini_science_spine_v1.docx`** — the scientific authority: S1–S6, the support ladder, the durability rules. All T1–T5 specs are subsidiary to it.
- **`Gayini_project_conversation_history.md` §5** — **Adrian's 24 July direction, the current scientific frame** (reference-state trajectory, refugia × LiDAR, Dawson et al. 2016 as template).
- **`Gayini_Results_database_overview.md`** and **`Gayini_Results_DB_contract_snapshot_*.xlsx`** — the database. The snapshot is authoritative for objects, schema and row counts; **not** for QA verdicts (check its as-of date).
- **`Gayini_number_provenance_audit.md`** — the twelve discrepancies, classified. Read before quoting any headline number.
- **`Gayini_established_data_facts.md`** — settled measured numbers.
- **Current task specs:** `T1_zone_stratum_census_join.md` (complete), `T2_zone_annual_veg_extraction.md`, `T3_always_green_threshold.md`, `T4_spine_evidence_workbook.md`, `T5_guardrails_and_checks.md`. Each carries an amendment log — **read it, because earlier versions were wrong.**

**No longer authorities:** `Gayini_subsampling_approach.md` (Task F, cancelled and archived) and `Tier1_unified_summary.md` (its open Adrian gate Q1/Q2/Q3a/Q3b is resolved — see `CLAUDE.md`).

## 9. Method traps (learned, cross-task — live and cumulative)

- **A bijection does not resolve mutual twins.** Two elements exchangeable at equal cost give the assignment *degenerate optima*, so a literal "verified iff optimal == identity" rule fails on numerical noise (T1 Gate B: the `{9,21}` management-zone area-twins swap for a −0.000033 pp "gain", flipping the whole 64-way assignment off identity). **Constrain with provenance, and record per element which line of evidence carries it** (`dim_management_zone.unit_id_verify_method` = `provenance+area` vs `provenance_only`; global gap in `t1_zone_identity_check`). Evidence: `docs/change_reports/T1_gateB_dim_management_zone.md`.

- **A composite support label defeats its own purpose.** `support_level` must come from the **closed ladder**; what a number was aggregated *to* goes in a separate `aggregation_unit` column. The composite form (`pixel_within_zone_stratum`, `zone_year_pixel`, `zone`) was specced **four separate times** before being caught, and it breaks the mixed-support detector by forcing a hardcoded synonym list. Precision belongs in a second column, not in an enum.

- **`OR IGNORE` passes a stability test while the DB is wrong.** It does not error and does not duplicate, so it looks idempotent — but it never updates a changed checksum. **Test idempotence by convergence:** mutate an input, re-run, confirm the DB *moves to* the new value. A test that only checks stability cannot distinguish converged from frozen.

- **A stored QA verdict cannot notice being wrong.** The 1 July row asserting "98 of 98 raster assets lack CRS/extent" misled four separate readers while all 126 were populated. Derivable verdicts should be **views that compute**, not rows that persist. And check the polarity of any convention test: `folder_scripts/archive_absent` hard-fails if `scripts/archive/` *exists*, inverted against the convention it appears to enforce (B5, unresolved).

- **Treatment can be perfectly nested within block.** All four `No grazing` zones are Bala (Bala 4 / Mara 0 / Dinan 0), so a whole-farm grazed/ungrazed contrast is confounded with property block, not only with wetness. Stratum matching controls wetness; it does **not** control block. And because a zone spans several communities, **all nine rows of a zone×stratum contrast draw their ungrazed side from the same four polygons** — "consistent sign across bands" therefore cannot falsify anything. **Report the treatment-unit n, not only the pixel n.**

- **Two floor metrics exist and are routinely conflated.** The **total-cover floor** (`veg_p05`, across-series temporal percentile per pixel) and the **green-share floor** (`100 × PV ÷ total_veg > 50` at each pixel's p05 season, Task M) answer different questions. A third — **duration count** (years above a fixed level, T2 Gate B2) — is distinct again. And `veg_p05_spatial` (within-zone, within-year) is **not** the census `veg_p05`. Every caption must name which metric it uses.
