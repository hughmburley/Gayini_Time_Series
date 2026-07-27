# Gayini — issues log

**Started:** 27 July 2026 · **Deadline:** 10 August 2026
**Purpose:** capture build and process issues without letting them stop delivery.
**Scope:** build, process, tooling and paper-trail defects. **Scientific limitations belong in `Gayini_limitations_register_*.xlsx`** (currently v10, 43 rows). A row here graduates to that register if it turns out to constrain what the science can claim.

---

## The triage rule

At any gate, one question decides whether an issue stops work:

> **Does this change a number that reaches a deliverable?**

- **Yes → resolve before the gate closes.** A wrong number is more expensive later than the delay is now.
- **No → log it, state the disposition, proceed.**

That is the whole rule. It is deliberately mechanical so it can be applied in seconds without debate.

Two corollaries, both learned the hard way:

- **"Would be better" is not "is wrong."** Improvements raised at a STOP point read as urgent because of where they appear. They are not. Log them as `IMPROVE` and move on.
- **A number reaching a deliverable includes the paper trail for that number.** A figure nobody can reproduce is a number that doesn't reach anything.

### Severity

| | Meaning | Action |
|---|---|---|
| **BLOCK** | Wrong output if ignored | Resolve now |
| **DEFECT** | Real, but current output is correct | Log, fix when cheap |
| **IMPROVE** | Would be better | Log, revisit post-deadline |
| **EXTERNAL** | Waiting on someone else | Log, chase, work around |

### Review cadence

At each task boundary (not each gate): scan `BLOCK` and `EXTERNAL` only. Full review once weekly and once post-deadline.

---

## Open

| ID | Area | Sev | Issue | Affects a deliverable number? | Disposition |
|---|---|---|---|---|---|
| **I-02** | Spine / T2 | **BLOCK** | Within-stratum `veg_p05` spread across the reference paddocks (fids 1–4) **exceeds the reference-vs-grazed contrast in 6 of 9 strata** — every Riverine and every Inland Floodplain band. Riverine-high: 36.5 pp within-reference (29.83→66.33) vs +8.25 pp pixel-weighted contrast (zone-support even smaller, +3.6/+0.1/−2.1). **A fixed distance-to-reference target is undefined in those strata.** Quantified at T2 Gate A (`v_zone_stratum_treatment_contrast` × per-fid `v_census_by_zone_stratum`). | **Yes** — T2 is the substrate for that metric | **Spine decision, not a build one.** The substrate is still correct to build (T2 proceeds). Then a spine-chat decision: narrow reference / per-stratum target / environmentally-defined (HCAS 3.3) / report heterogeneity as the finding. Do not work around it in the build |
| **I-03** | Task J | **EXTERNAL** | Jana email unsent — cut-date provenance (L07) and bank geometry (L10). Sole remaining blocker on Task J. | No — analysis complete | Send one email and proceed regardless, per `Gayini_path_to_Aug10.md`. Outstanding since ~18 July |
| **I-04** | T2 / S5 | **EXTERNAL** | `dim_management_zone.cropping_history` and four other RESERVED columns NULL pending Ernest's land-use table. So conserved-vs-**grazed** is available; conserved-vs-**formerly-cropped** is not. | Constrains the claim, not a number | Build what the data supports; name the gap in every caption. Graduate to limitations register |
| **I-05** | T3 | **EXTERNAL** | Adrian's LiDAR shrub-height model has not arrived. | No | T3 Gate E produces the overlay package so the overlay is a five-minute job on arrival |
| **I-06** | Spine §5 | DEFECT | S2 labels the plot-support 9 / 22 / 50 / 44 gradient "Support: stratum, pixel". The numbers are right; the label is wrong. `dim_metric.support` already stores both rules verbatim. | No — numbers correct | Spine-chat text fix. Also flagged for T4 Gate A |
| **I-07** | Spine §5 | DEFECT | C-3 states census `veg_p05` range as `[1.19, 97.00]`. 97.00 is the **`veg_p50`** max; p05 is `[1.19, 91.85]` all-pixel, `[1.19, 88.66]` non-treed. Conclusion (percent, no offset) stands. | No | Spine-chat text fix |
| **I-08** | T1 Gate D | DEFECT | `min_cell_n` flags on **pixel** count and is actively misleading. It flagged Aeolian-high (2,501 px) and Riverine-high (2,223 px) while **passing Riverine-low at 7,877 px — 93% one paddock.** The flag cleared the cell that produced the false headline. | No — the finding is now correct | The view still carries it and someone will trust it. Add a treatment-unit-count flag alongside, or annotate. Cheap |
| **I-09** | T1 Gate D | DEFECT | Aeolian Bala-only contrast is **1 paddock vs 1 paddock** (+21–24 pp). Must be reported as a paddock description, never as a contrast. | Yes if written up wrong | Wording constraint, recorded. Do not present as a treatment effect |
| **I-10** | Tooling (B5) | DEFECT | `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) **hard-fails if `scripts/archive/` exists** — inverted against the archive convention it appears to enforce. A check that cannot fail. | No | Unresolved, Adrian's call. **Do not modify the smoke test to force it.** Use `lint_guardrails.py` exit 0 as the acceptance signal instead |
| **I-11** | Tooling | DEFECT | `run_spine_smoke_test.R` exits 1 on `structure/folder_scripts/10_downstream_optional` = missing, plus three `outputs` warnings. Pre-existing. **A permanently-red test gets ignored exactly like a permanently-green one.** | No | Same bucket as I-10. Post-deadline |
| **I-12** | Docs | DEFECT | Shipped data dictionary is behind the DB — `census_stratum` and `census_asset` absent from the `fields` sheet; `raster_assets` sheet has no `product` column. Recurrence of correction C5. | No | Regenerate from live DB. Post-deadline unless T4 runs |
| **I-13** | DB | DEFECT | `dim_metric.support` NULL on **36 of 45 rows** (populated for 7 pixel + 2 plot metrics). C10 leans on this column. | No | Treat unpopulated as unknown, never as either. Backfill where derivable — T5 Gate 4 |
| **I-14** | DB | DEFECT | `figure_asset` pre-Gate-E rows are an old-generation snapshot, unreconciled against disk. The 11 Gate E + 4 T1 + 2 Gate C rows are current. | No | Do not backfill. Reconcile post-deadline |
| **I-15** | Repo | DEFECT | `scripts/_deprecated/` violates the `scripts/archive/` convention — but cannot be reconciled without tripping I-10. | No | Blocked on I-10. Leave untouched |
| **I-16** | Output folder | DEFECT | 16 migration blockers remain (8 hard via `builder_csv_input`, 8 soft via `path_module_resolved` only). Two shadow figure registries feed nothing. | No | Explicitly parked before Aug 10 per `Gayini_path_to_Aug10.md` |
| **I-17** | Repo hygiene | DEFECT | Three dated contract snapshots in `docs/` (25, 26, 27 July). **Multiple dated copies of one artefact is discrepancy class #1** and has already misled four readers. | Yes, indirectly | Keep only the newest. Fold into the snapshot generator: delete predecessors on write |
| **I-18** | Process | IMPROVE | `T1_A_identity_margin.png` upper panel runs 0–0.15, compressing the band it exists to show into a thin strip. | No | Post-deadline, if the figure is ever regenerated |
| **I-19** | T5 | IMPROVE | Gates 2–4 deferred: QA verdicts → live views, `computed_at` / `v_qa_freshness`, `read_registered_layer()`, closed-ladder trigger, mixed-support detector. | No | Post-deadline. Gate 1 is done and has already caught a live violation |
| **I-20** | T4 | IMPROVE | Whole task deferred — `claim_register` and the spine evidence workbook. It is the durability artefact that stops C-1 recurring. | No | Post-deadline. Genuinely valuable; not an Aug 10 deliverable |
| **I-21** | T5 / tooling | IMPROVE | Add a `hardcoded_path` lint alongside `magic_number` / `or_ignore` / `whole_digest`. T2's Gate B/C scripts shipped session-scoped temp paths (UUID dir) that the numeric-only lint could not see; caught in review, not by the guard. A path lint (flag absolute paths / temp dirs / UUIDs in `scripts/` and `R/`) would have. | No | Post-deadline. Log now; do not build during T2 |

## Closed

| ID | Issue | Resolution |
|---|---|---|
| **C-01** | `plot_rs_analysis_base.csv` reported missing, blocking script `05` | **Present** at `Output/csv/canonical/` — gitignored, not missing. Script 05 can run |
| **C-02** | Reference set — three or four conserved paddocks? | **Four.** Fids 1–4 (Bala 26ca/27ca/28ca/29ca), all `zone_group = 'Bala'`, `grazing_excluded = 1`. The "three" was a miscount, confirmed from the DB |
| **C-03** | `raster_asset` extents unpopulated ("98 of 98") | **Stale QA row dated 2026-07-01.** All 126 rows populated. Misled four readers including the spec author, twice |
| **C-04** | `Area_MW` / `ManagmentZ` do not exist | **They do** — in `management_zones_epsg8058.gpkg`, capitalised ESRI names. The spec had inspected the wrong layer. Three management-zone objects exist, not two |
| **C-05** | Zone identity unverifiable (27 of 64) | **All 64 verified.** Provenance + 62/64 assignment closure. `{9,21}` are area-twins held by provenance alone — recorded as `provenance_only` |
| **C-06** | Refugia "~4,300 ha" — three competing lineages | **Withdrawn** by Task M (D8). `green_at_floor()` measures green *share*, not total cover. The grid mismatch explained only the 6,458 ↔ 4,474 pair |
| **C-07** | Composite `support_level` | Split into closed-ladder `support_level` + free-text `aggregation_unit`. **Specced four times before it was caught** — logged as a method trap in lineage §9 |
| **C-08** | The 0.0625 pixel-area error | `gayini_params.PIXEL_AREA_HA` derived, never typed; magic-number lint fails on a bare literal. Caught a stray literal in its own author's script within hours |
| **C-09** | `OR IGNORE` passing a stability test while the DB is wrong | `INSERT OR REPLACE` enforced by lint; idempotence now tested by **convergence** |
| **C-10** | FC values >100 in the annual veg stacks (max 108 mean / 110 jja_son) — unmixing overshoot or water contamination? (was I-01) | **Bilinear-resampling overshoot**, traced to `legend_semantics` ("bilinear" to the 8058 grid). Only **24 over-100 pixel-years of 143.1M valid (0.00002%)** in the primary, 622/133.95M (0.0005%) in jja_son. The 3.5× wet-enrichment is on n=24 — noise; real water contamination would be thousands-to-millions of wet-year pixels. **Keep raw, no mask, no clamp**; add `n_px_over_100`/`pct_px_over_100` counters; tolerance stated from the FC product domain [0,100], not the observed range |

---

## Notes on discipline

**What I will stop doing** (design seat): raising `IMPROVE` items at STOP points. They arrive looking as urgent as blockers because of where they appear. From here they go straight to this log without interrupting a gate.

**What CC should keep doing:** flagging rather than choosing. Every significant error in this project was caught at a STOP — the wrong gpkg, the twin degeneracy, the Bala confound, the >100 values. The flagging is not the drag; the drag was treating every flag as equally urgent.

**Cadence:** review `BLOCK` and `EXTERNAL` at each task boundary. Everything else weekly.
