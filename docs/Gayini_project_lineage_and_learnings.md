# Gayini — Project Lineage & Learnings

*Provenance record. Captures where the current analysis came from and the durable learnings from the originating "new-direction" investigation, Tier 0, and Adrian's early rulings. **This is not a live authority** — where it and the current docs (ladder / DB overview / Tier 1 summary / subsampling approach) differ, current wins. Adrian's logic is being updated in person; this is the pre-update lineage it supersedes.*

## 1. The pivot — why the analysis changed direction

The project moved **away from a 2019 pre/post design toward a spatially explicit annual time-series (1988–2023)**. Two reasons, both durable:

- The management-change date was uncertain, so a pre/post split was arbitrary.
- The data showed the **pre/post estimator was throwing the signal away** — averaging two periods hid the episodic flood-pulse behaviour and the within-plot inundation→vegetation relationship.

**Durable learning:** pre/post is retired. The framing is full-record and spatially explicit; the plots are anchors, the analysis operates on areas/strata.

## 2. Adrian's rulings captured in the lineage (in force unless updated Wednesday)

- **The wet-rule (7 Jul 2026 — locked).** The NSW DCCEEW inundation rasters use a four-class legend: `0` dry (valid), `1` inundated = **wet**, `2` off-river storage / irrigation = **wet**, `3` cloud shadow = **mask**. Adrian ruled off-river storage counts as wet — *"those pixels were wet just the same."* Formal rule: `wet = value IN (1,2)`, `valid = value IN (0,1,2)`. The 35 Landsat sources contain `{0,1,2}` only, so the mask is currently a no-op and `annual_occurrence_pct` already reflects this. Durable record: `tier0_legend_decision_record.md`.
- **"Control areas near the plots."** Adrian's idea of comparison areas in the same community, across their inundation range, near the plots but excluding them — this became the **F5 stratified sampling frame** (and is the parent of Q1).

## 3. Tier 0 — the foundation (locked, do not re-derive)

Tier 0 hardened the base so Tier 1 could start from a trustworthy foundation:

- **Unified annual inundation stack, 1988–2023** — one continuous per-year wet/valid raster stack from the 35 canonical `lo_YYYY_YYYY.img` sources, **EPSG:28355 (GDA94/MGA55), 25 m, 35 layers, no gaps**, wet-cell counts verified against the manifest. (Reprojected to EPSG:8058 downstream for mapping; extraction stays in 28355.)
- **Raster metadata resolved** — 100 `raster_asset` rows, 0 null CRS.
- **The modelling spine** — `v_plot_year_analysis_spine`, **2,310 rows (66 plots × 35 years)**, ground-cover join coverage 99.8%. This is the table Tier 1 (and everything since) reads from.
- **The wet-rule** (§2).

## 4. The seed investigation — what it found, and what each became

The new-direction investigation ran the first-pass analyses that motivated the ladder:

- **Candidate annual plot-year spine** (2,310 rows, 99.8% cover overlap) → became `v_plot_year_analysis_spine`.
- **Annual inundation coverage table** → confirmed the **episodic** signal (2006-07 drought trough ≈ 0.03%; big floods 2010-11, 2016-17, 2022-23) → became **F2**.
- **Per-plot trend classification** → came out **mixed within every community** — increasing_strong and declining_strong plots side by side in Aeolian, Riverine, and Inland. **This inconclusiveness is why F6 moved to a rigorous per-stratum robust test** (Theil–Sen/MK + drop-two-floods), which then returned the clean result: no directional trend (gate shut). *Learning: naive per-plot slopes mislead on episodic data; per-stratum robust testing was necessary.*
- **Inundation ↔ ground-cover correlations** → positive for every plot and **community-structured** (Aeolian ~0.15 → Riverine ~0.30 → Inland ~0.34–0.70) → seeded **F7**, which reproduced the pattern (median r 0.22 → 0.28 → 0.42). The seed already showed the **bare ≈ −veg** near-identity and carried a pre/post-flavoured `inundation_change_class` and a grazing category — both of which current work dropped (change class) or demoted to metadata (grazing).

## 5. Metric evolution (the durable naming lesson)

The seed, Tier 0, and early Tier 1 described the gradient as **"occurrence"** (within-year wet-extent coverage; Aeolian ~4 · Riverine ~12 · Inland ~31%). Mid-Tier-1 the headline was reframed to **between-year annual flood frequency** (`100 × wet-valid-years ÷ valid-years`; 9 · 22 · 50%), and the occurrence numbers were **demoted to a labelled secondary metric**. The DB field `annual_occurrence_pct` is that secondary — the name is a trap now recorded in `CLAUDE.md` and the DB overview.

## 6. Superseded framings — do not revive

- **Pre/post** (2019 management split) — retired.
- **`inundation_change_class`** (drier_post / wetter_post / much_wetter_post) — dropped with pre/post.
- **Per-plot trend classification** (declining/increasing_strong/weak) — superseded by F6's per-stratum verdicts.
- **MER** — renamed to "annual maximum observed wet footprint," kept supplementary only.
- **"Occurrence" as the headline** — superseded by flood frequency; occurrence is the secondary.

## 7. Process lineage (for reference, not authority)

The `tasks` archive also holds the delivery/cleanup history: `codex_context.md`, `current_run_order.md`, the Tier 0 task cards, and the output-cleanup record (`output_cleanup_policy.md`, `output_cleanup_candidates_summary.csv`, the `removed_*` and `script_rename_map` manifests). These document how the repo was built and pruned; consult them when auditing or archiving, but the live conventions are in `CLAUDE.md`.

## 8. Where current authority lives

- `Gayini_Figure_Driven_Project_Ladder.docx` — the single source of truth.
- `Gayini_Results_database_overview.md` — the database.
- `Tier1_unified_summary.md` — what Tier 1 built + the open Adrian gate (Q1/Q2/Q3).
- `Gayini_subsampling_approach.md` — the next round (stratified Monte-Carlo resampling).

Adrian's Q1/Q2/Q3 answers update at the Wednesday sync; fold them into the Tier 1 summary, and note here anything that changes a ruling in §2.
