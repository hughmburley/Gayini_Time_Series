# Task M · Gate A — deck evidence audit, recon report

*Spec: `docs/Tier2_TaskM_deck_evidence_audit_v2.md`. Branch `tier2m-deck-evidence`, cut from
`origin/main` @ `71ac44d`. **Read-only gate — nothing was written except the four Gate A files
listed in §0.3.** No merge. Stop at the acceptance gate.*

## 0. Run context

### 0.1 Machine and paths, as resolved (not assumed)

| Item | Value |
|---|---|
| Hostname | `DESKTOP-K2CLIB0` |
| Repo root | `d:\Github_repos\Gayini` |
| Deck, absolute path as resolved | `d:\Github_repos\Gayini\docs\Gayini_Veg_samples.pptx` |
| Deck size / mtime | 10,537,992 bytes · 2026-07-15 09:56 local |
| Deck SHA-256 (full file) | `94a0870307938a5c463d812ed8628a0bfded9e53074b51189d3c8a1a55fb7b8d` |
| Deck slides / notes slides | 36 / 36 |
| Database | `Output/database/Gayini_Results.sqlite` · 76,058,624 bytes |
| DB SHA-256 (full file, before **and** after this gate — no DB write occurred) | `a8a92fb5d53324d9fa2dcce19ea59784ad2ba20046a4085475363156b24f42f7` |
| Date of run | 2026-07-24 |

The deck was opened read-only (zip + XML parse). It was not edited, re-saved, or rebuilt.

### 0.2 Two spec path corrections

- The spec's *"docs/taskI_deck_stocktake_20260717.md"* does not exist at that path. The file is at
  **`docs/change_reports/taskI_deck_stocktake_20260717.md`**. That file was used.
- The branch was cut from **`origin/main` (`71ac44d`)**, deliberately **not** from
  `fix-refugia-changelog`, so this branch does not carry the disputed commit `e87bd1a` (D9).
  Consequence for §A.7: on this branch `docs/Gayini_established_data_facts.md:34` still reads
  "~4,300 ha"; on `fix-refugia-changelog` the same line reads "~6,460 ha". Both states are
  reported below.

### 0.3 Files written by this gate

| File | Rows |
|---|---:|
| `docs/change_reports/taskM_gateA_output_inventory.csv` | 1,894 |
| `docs/change_reports/taskM_gateA_floor_claims_inventory.csv` | 68 |
| `docs/change_reports/taskM_gateA_stale_input_risk.csv` | 414 |
| `docs/change_reports/taskM_gateA_report.md` | this file |

Plus `docs/Tier2_TaskM_deck_evidence_audit_v2.md`, committed as part of this gate.

---

## 1. §A.6 — the artefact behind Claim B (~6,460 ha)

### 1.1 Chain resolution: **PARTIAL**

An artefact exists. It is on disk, it reproduces the number exactly, and its definition is
recoverable from committed source code. The chain breaks at two links: **no committed script
performs the counting step**, and **no link in the chain is a registered asset** (nor is any of it
tracked in git).

| Link | State | Evidence |
|---|---|---|
| 1. Method (function) | **FOUND, committed** | `scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R:293-310` defines `green_at_floor()` and applies it over the farm on the native grid. Tracked in git. |
| 2. Substrate rasters | **FOUND on disk, UNREGISTERED, untracked** | `Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif` (370 MB) and `fc_pv_3577_wy1988_2023.tif` (400 MB). No `raster_asset` row references `fc_intermediate` or CRS 3577 — `raster_asset` holds **0** rows with `crs_epsg = 3577`. |
| 3. Substrate summary CSV | **FOUND on disk, UNREGISTERED, untracked** | `Output/diagnostics/tier2H_h2_green_fraction_at_floor.csv`, emitted by link 1. Carries `n_farm_px = 959,833`; green-fraction median 3.03, mean 11.773, p95 55.556. |
| 4. **The counting step** | **BREAK — no script** | Nothing in `scripts/`, `R/`, `tools/` or `tests/` performs the `> 50` threshold count or the hectare conversion. `docs/Tier2_TaskH_ondisk_census_groundcover_review.md:116` shows why: it *instructs* an interactive session to compute it and write the result to a scratch path, explicitly "additive scratch, **not a registered product**". |
| 5. Output file | **FOUND on disk, UNREGISTERED, untracked** | `Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv`, 201 bytes, mtime 2026-07-21 02:39 UTC. `registered_in = none` in the Gate A inventory. `git ls-files Output/diagnostics/` returns nothing — the entire directory is untracked. |
| 6. Registered asset | **BREAK — none** | No `raster_asset` / `figure_asset` / `report_asset` / `census_asset` row points at any file in links 2, 3 or 5. |
| 7. The number in prose | **FOUND** | `Output/diagnostics/ondisk_review_20260720/gate_C_reproduction.md:34` → `docs/Tier2_TaskH_ondisk_census_groundcover_review.md:24` (D8 row, "~6,458 ha") → `docs/Gayini_established_data_facts.md:273` ("~6,460 ha") → `CLAUDE.md:40` → commit `e87bd1a` amending `Gayini_established_data_facts.md:34`. |

### 1.2 Contents of the artefact, verbatim

`Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv`:

```
"quantity","value"
"n_valid_floor_px",959833
"n_majority_green_px_gt50",71755
"pct_of_valid",7.476
"area_ha_native_30m_3577",6457.95
"area_ha_2497_cnote",4474.027
"implied_farm_ha_30m",86384.97
```

`6457.95` rounds to the "~6,460 ha" of Claim B. `4474.027` is the same pixel count converted with
the 24.97 m census pixel.

### 1.3 The definition, read from the committed source

Recovered from `green_at_floor()` (`03_h2_seasonal_gate_and_diagnostics.R:293-310`) and its call site:

| Element | Value |
|---|---|
| Variable | `green_frac_pct` = `100 × PV ÷ total_veg`, evaluated **paired** — PV is read in the *same season* that sets that pixel's total-vegetation 5th-percentile order statistic. Not a percentile of PV, and not a percentile subtraction. |
| Threshold | `green_frac_pct > 50` |
| Mask | Farm boundary (`bv3577`), crop + mask, applied on the native grid; support rule `m >= 50` valid paired seasons (`MIN_SEASONS`) |
| Grid | **EPSG:3577, 30 m** (the FC source grid) |
| Pixel area | 0.09 ha |
| Denominator | `n_valid_floor_px = 959,833` (pixels passing the support rule) |
| Result | 71,755 px = 7.476% of valid = 6,457.95 ha at 0.09 ha/px |

### 1.4 Arithmetic bearing on §1.5.2 of the spec

Reported as arithmetic. **No interpretation offered — human review required.**

- 71,755 × 0.09 = 6,457.95. 71,755 × 0.0623514 = 4,474.03. Ratio 1.443 = (30 ÷ 24.970268)².
  The two numbers in the artefact are the **same pixel count under two pixel areas**; the grid
  qualifier fully accounts for the difference *between them*.
- The spec's §1.5.2 computes "majority-green floor" as **`veg_p05 >= 50`** — total cover at the
  floor ≥ 50% — giving 40,935.8 ha on the census. The artefact's variable is **the green share of
  whatever cover remains at the floor season**, `100 × PV ÷ total_veg > 50`. These are two
  different variables measured on two different rasters. 40,935.8 ÷ 6,457.95 = 6.34.
- The companion "~97% dead at the median" traces to the same artefact family, not to `veg_p50`:
  `tier2H_h2_green_fraction_at_floor.csv` gives a green-fraction **median of 3.03%** over
  n = 959,833, i.e. 100 − 3.03 ≈ 97. The spec's §1.5.1 test (`veg_p50 < 50` over focus pixels =
  0.9%) is a different variable again.
- `implied_farm_ha_30m` = 959,833 × 0.09 = 86,384.97 ha, against a true farm of 85,910.8 ha
  (difference +474.2 ha, +0.55%).

### 1.5 What this does and does not settle

- It **does** identify a real artefact that reproduces ~6,460 ha exactly, and recovers its full
  definition from committed code.
- It **does not** make the chain resolvable in the sense §0.1 of the spec requires: the counting
  step is not in version control, and nothing in the chain is a registered asset. A rebuild of the
  repo from git alone would not reproduce this number.
- It **does not** address whether the artefact's variable is the one the label "majority-green
  floor" was ever meant to denote, or whether either number belongs on a slide.

**No interpretation offered — human review required.** No replacement number has been computed and
no document has been edited.

### 1.6 D9 status

`e87bd1a` ("Fix stale ~4,300 ha refugia figure in changelog row (superseded by ~6,460)") changes one
line of `docs/Gayini_established_data_facts.md`. Per §A.6 the chain resolves **PARTIAL**, not
`RESOLVED`. Per spec §4, the PR is held pending. This gate makes no edit to it.

---

## 2. §A.7 — inventory of hectare claims about the floor variable

Full detail in `docs/change_reports/taskM_gateA_floor_claims_inventory.csv` (68 rows; columns
`path, line, text, hectare_value, label_used, states_definition, supersession_marked, class,
relevance, is_taskM_spec`). Two columns beyond the spec: `relevance` (`floor_claim` /
`incidental`, to separate co-occurring farm-geometry constants on the same line) and
`is_taskM_spec` (rows inside the Task M v1/v2 specs, which quote the claims in order to ban them).

**Report only. Nothing was corrected.**

### 2.1 Counts

| Split | n |
|---|---:|
| Total rows | 68 |
| `class = stale` (asserts as current, unmarked) | 51 |
| `class = marked` (cites only to supersede / flags itself) | 7 |
| `class = definition_complete` | 10 |
| Rows inside the Task M v1/v2 specs | 20 |
| Rows outside the Task M specs | 48 |

### 2.2 Distinct hectare values attached to the floor variable

| Value | Occurrences | Where it comes from |
|---|---:|---|
| 4,300 | 29 | Claim A |
| 6,460 | 14 | Claim B |
| 40,935 / 40,936 | 6 | the spec's `veg_p05 >= 50` census measurement |
| 6,458 | 3 | the artefact value before rounding (§1.2) |
| 4,474 | 3 | the artefact value at the census pixel area (§1.2) |
| 4,179 | 3 | the spec's `veg_p05 >= 80` census measurement |
| 4,084 | 2 | the spec's `veg_p05 >= 50`, Riverine only |

### 2.3 Sites outside the Task M specs, by class

**`stale` — asserts a number as current with no supersession marker (25 sites):**

`CLAUDE.md:44` · `Gayini_Notes.txt:228` (×3 values) ·
`docs/Gayini_census_audit_kickoff.md:65` · `docs/Gayini_established_data_facts.md:34` ·
`docs/Tier2_TaskH_ondisk_audit.md:54`, `:104` ·
`docs/Tier2_TaskH_ondisk_census_groundcover_review.md:106` (×2), `:116` (×2) ·
`docs/Tier2_TaskI_deck_stocktake_and_review_bundle.md:76` ·
`docs/change_reports/taskH_ondisk_audit_2026-07-20.md:11`, `:93`, `:99` ·
`docs/change_reports/taskI_deck_stocktake_20260717.md:83` ·
`Output/diagnostics/ondisk_review_20260720/gate_A_orientation.md:40` ·
`Output/diagnostics/ondisk_review_20260720/gate_C_reproduction.md:43` ·
`Output/diagnostics/ondisk_review_20260720/verdict.md:21` (×3), `:49` ·
`Output/review_bundles/tier2H_all_pixel_census/docs/Gayini_established_data_facts.md:34`, `:271` ·
`Output/review_bundles/tier2H_all_pixel_census/docs/taskI_deck_stocktake_20260717.md:83`

`CLAUDE.md:40` also carries a `stale` row for the 6,460 figure.

**`marked` (4 sites):** `docs/Gayini_taskL_session_learnings.md:39` ·
`docs/Tier2_TaskH_gateE_figure_build.md:16` ·
`docs/Tier2_TaskH_ondisk_census_groundcover_review.md:20`

**`definition_complete` (2 sites, 8 rows):**
`docs/Gayini_established_data_facts.md:273` and
`docs/Tier2_TaskH_ondisk_census_groundcover_review.md:24` — these state variable, threshold, mask
and grid together. They are the D8 rows.

### 2.4 Two observations for the human

1. **`CLAUDE.md` currently states the claim two ways in adjacent lines** — L40 asserts ~6,460 ha as
   the fix, L44 asserts ~4,300 ha as a novel finding. On this branch
   `docs/Gayini_established_data_facts.md` does the same (L34 ~4,300, L273 ~6,460); on
   `fix-refugia-changelog`, L34 reads ~6,460 and L273 reads ~6,460. Per the task instruction,
   `CLAUDE.md:44` was **not** edited.
2. **The claim also lives in three copies under `Output/review_bundles/tier2H_all_pixel_census/docs/`.**
   Review bundles are snapshots; correcting the live docs does not reach them.

---

## 3. §A.8 — deck slide traceability

### 3.1 The explicitly-required flag — result is negative

Every one of the 36 slide XMLs **and** all 36 speaker-notes XMLs (72 parts) was text-extracted and
searched for: `4,?300` · `6,?4\d\d` · `4,?179` · `40,?93` · `71,?755` · `97 ?%` ·
`≈ ?5 ?%` / `5 ?% of the farm` · `refugia` · `majority[- ]green` · `green floor`.

**Total hits: 0.**

Neither withdrawn floor claim, neither companion phrasing, and the word "refugia" itself appear
anywhere in the deck or its notes. The spec's §1.6 expectation ("the number is likely on a live
slide") does not hold. Its source — `taskI_deck_stocktake_20260717.md:83` — lists the claim under
the heading **"What is NOT in the deck but should be"**, i.e. it records the claim's *absence*.

### 3.2 A structural limit on deck traceability

The deck's 27 embedded images were hashed and compared against all 1,317 PNG/JPG/SVG/EMF/PDF files
under `Output/` and `docs/`. **Byte-identical matches: 0 of 27** — PowerPoint re-encoded them on
insert. Slide figures therefore cannot be tied to on-disk artefacts by checksum; the mapping below
rests on slide text, the Task I stocktake's identification, and file naming.

Compounding this: **of 131 ladder-named figure files on disk (`F1`–`F7`, `F5b/c/d`, `C1`, `H6`,
`S*`, `FigA`), only 11 are registered** in `figure_asset` — the Gate E PNGs. Every figure the deck
actually shows is unregistered.

### 3.3 Per-slide classification

Classes per spec §A.8. `retired_framing` is a separate Y/N flag because several slides belong to a
retired framing while printing no number — the four-class scheme alone cannot express that.

| # | Slide | Class | `retired_framing` | Numeric claim → resolution | Task I | Agree? |
|---:|---|---|---|---|---|---|
| 1 | Title · two questions | no_numeric_claim | N | record span 1988–2023 only | OK | yes |
| 2 | Two questions guiding the analysis | no_numeric_claim | **Y** | no result number; method pillar names the retired near-plot design | RESTATE | class differs — Task I's defect here is non-numeric |
| 3 | How the monitoring is set up | no_numeric_claim | N | — | OK | yes |
| 4 | Four communities, driest→wettest | **traceable** | N | 9 / 22 / 50 / 44 and 16 / 19 / 22 / 9 → `v_plot_year_analysis_spine` + `dim_plot` give **9.11 / 22.26 / 49.61 / 44.13** and **16 / 19 / 22 / 9**. Plot support; support not stated on the slide | LABEL | yes |
| 5 | How we tell if a pixel is under water | no_numeric_claim | N | — | OK | yes |
| 6 | Definition of flood frequency | no_numeric_claim | N | "1 in 10 / 9 in 10" illustrative | OK | yes |
| 7 | Has flooding changed over 35 years? | **superseded_framing** | N | figure is F2 = share of the 66 plots; wet years 2010–11 / 2016–17 / 2022–23 | SUPERSEDED | yes |
| 8 | The whole record at a glance | **traceable** | N | 66 plots × 35 years → spine is 66 × 35 = 2,310 rows | LABEL | yes |
| 9 | Flooding differs strongly with veg type | **traceable** | N | same triple as slide 4 (F4) | LABEL | yes |
| 10 | Comparing like with like | no_numeric_claim | **Y** | describes the cancelled Task F sampling design | DEAD | yes |
| 11 | The sampling laid over the flood map | no_numeric_claim | **Y** | sample-point overlay; surface underneath is live | DEAD | yes |
| 12 | Stratum coverage / sampling density | **traceable** | **Y** | "two-thirds of the mapped farm" → Inland 717,629 / 1,080,157 = **66.44% of mapped** ✔ (trap held — not a defect) | DEAD | yes |
| 13 | Proposed fix: proportional sampling | **superseded_framing** | **Y** | flat 40/stratum → ~100 / 270 / 1,000, floor 50, 100+ repeats = the cancelled Task F ask | DEAD | yes |
| 14 | Flood frequency — Bala 28ca | no_numeric_claim | **Y** (overlay only) | figure `F5c_paddock_Bala_28ca` exists, unregistered | LABEL\* | yes |
| 15 | Flood frequency — Bala 29ca | no_numeric_claim | **Y** (overlay only) | as above | LABEL\* | yes |
| 16 | Flood frequency — Dinan 8 | no_numeric_claim | **Y** (overlay only) | as above | LABEL\* | yes |
| 17 | Flood frequency — Dinan 10 | no_numeric_claim | **Y** (overlay only) | as above | LABEL\* | yes |
| 18 | Checkerboard concept | **traceable** | N | "nine classes" → `census_stratum` holds 9 focus + 2 context strata ✔ | FRAME | yes |
| 19 | Checkerboard mapped across the farm | **traceable** | N | "all 21 paddocks in the folder" → **21** distinct `C1_veg_regime_paddock_*` stems on disk ✔ (all unregistered) | FRAME | yes |
| 20 | Three kinds of trend | no_numeric_claim | N | — | OK | yes |
| 21 | Is the amount of flooding trending? | **superseded_framing** | **Y** | "8 of 9 … driest Riverine episodic … thinly sampled … provisional" = plot-support F6 **8/1/0**; census verdict is **9/0/0** | RESTATE | yes |
| 22 | No clear trend — so far…? | **superseded_framing** | **Y** | same 8-of-9 grid plus three sampling hedges | RESTATE + DEAD | yes |
| 23 | Recent years vs long-run average | no_numeric_claim | N | concept only, no embedded figure — confirmed, slide has 0 images | OK | yes |
| 24 | Does vegetation respond to flooding? | **traceable** | N | F7, plot support (r 0.17 / 0.26 / 0.42 per `f7_response_by_plot.csv`) | OK | yes |
| 25 | Green-up ~3 months later | **traceable** | N | `f7_lag_profile.csv` peak median r at lag = 3 months | OK | yes |
| 26 | Strongest where it floods most | **traceable** | N | F7 strata panel, plot support | OK | yes |
| 27 | Two clear answers | **superseded_framing** | **Y** | "provisional … wettest, largest areas are thinly sampled" | RESTATE | yes |
| 28 | Site dashboard — GA_019 | **orphan** | N | "All 66 sites are in the folder" → **57** distinct `D2_site_GA_*` on disk (Task I recorded 5) | LABEL | Task I flagged completeness separately; count has moved 5 → 57 |
| 29 | Site dashboard — GA_032 | **orphan** | N | as above | LABEL | as above |
| 30 | Paddock dashboard — Bala 28ca | **traceable** | N | "All 21 paddocks" → **21** distinct `D1_paddock_*` on disk (Task I recorded 4); all unregistered | FRAME | count has moved 4 → 21; claim now holds |
| 31 | Paddock dashboard — Dinan 8 | **traceable** | N | as above | FRAME | as above |
| 32 | Stratum dashboard — Inland wettest | **orphan** | **Y** | "All nine strata" → **3** distinct `D3_stratum_*` on disk; slide also carries the "provisional" hedge | RESTATE + FRAME | yes |
| 33 | Stratum dashboard — Aeolian driest | **orphan** | **Y** | as above; Task I notes Aeolian low is flat-zero (100% never-wet) | RESTATE + FRAME | yes |
| 34 | What we've set aside for now | no_numeric_claim | N | prediction-map logic unchanged by the census | OK | yes |
| 35 | Open questions | no_numeric_claim | **Y** | Q1's premise is the retired near-plot comparison | RESTATE | yes |
| 36 | Summary | **superseded_framing** | **Y** | "run the rebalanced sampling (proportional, floored, repeated 100+ times)" = cancelled Task F | RESTATE + DEAD | yes |

**Class tally:** `no_numeric_claim` 15 · `traceable` 10 · `superseded_framing` 6 · `orphan` 5.
`retired_framing = Y` on 14 slides.

### 3.4 Where this disagrees with the Task I stocktake

1. **Slides 30/31 (paddock dashboards)** — Task I recorded 4 of 21 built; **21 of 21 exist now**, so
   the slide's "all 21" claim is satisfied on disk. Task I's completeness flag is stale.
2. **Slides 28/29 (site dashboards)** — Task I recorded 5 of 66; **57 of 66 exist now**. Still short
   of the claim, so still classed `orphan`, but the gap is 9, not 61.
3. **Slide 32/33 (stratum dashboards)** — unchanged at **3 of 9**.
4. **Slide 2** — Task I classes it RESTATE; under §A.8's four classes it is `no_numeric_claim`,
   because the defect is a framing description with no number attached. Recorded via the
   `retired_framing` flag rather than by forcing it into a numeric class.
5. **The floor claim is absent from the deck** (§3.1), so no slide can be flagged for it.

No interpretation of what should change on any slide is offered — human review required.

---

## 4. §A.1/A.2 — `Output/` inventory and registration gaps

### 4.1 Inventory

`docs/change_reports/taskM_gateA_output_inventory.csv` — 1,894 files under `Output/`, recursive,
excluding `Output/_archive/`.

| Split | n |
|---|---:|
| `date_class = current` (mtime ≥ 2026-07-17) | 632 |
| `date_class = prior` | 1,262 |
| Registered in `figure_asset` | 207 |
| Registered in `raster_asset` | 112 |
| Registered in `report_asset` | 40 |
| Registered in `census_asset` | 1 |
| Registered in `spatial_layer_asset` | 0 (all 5 rows point into `Input/`, not `Output/`) |
| **Registered nowhere (orphans)** | **1,534** |

Extensions: png 652 · csv 424 · pdf 353 · tif 270 · md 62 · json 22 · txt 17 · zip 17 · ps1 15 ·
svg 14 · gpkg 13.

### 4.2 A.2.1 — orphans

**1,534 of 1,894 files (81.0%)** under `Output/` are registered nowhere. Of these, **557 are
`current`**. By directory:

| Directory | files | registered |
|---|---:|---:|
| `Output/figures/` | 693 | 207 |
| `Output/review_bundles/` | 366 | 0 |
| `Output/diagnostics/` | 309 | 6 |
| `Output/rasters/` | 273 | 112 |
| `Output/tables/` | 18 | 0 |
| `Output/census/` | 4 | 1 |

Ladder-named figures (`F1`–`F7`, `F5b/c/d`, `C1`, `H6`, `S*`, `FigA`): **131 files, 11 registered.**
The 11 are the Gate E PNGs; their PDF siblings are unregistered.

### 4.3 A.2.2 — broken pointers

**0.** Every one of the 365 registered asset paths resolves to a file on disk. All
`path_exists` flags read 1.

### 4.4 A.2.3 — stale-input risk

`docs/change_reports/taskM_gateA_stale_input_risk.csv` — **414 (script, prior-input) pairs**,
across **28 scripts** and **158 distinct prior-class files**.

Method: a script is deemed to have produced a `current` output if it references, in its source, the
filename of any `date_class = current` file under `Output/`; the prior-class filenames it also
references are then listed. This is a filename-reference test, not a data-lineage test — it cannot
distinguish "reads as input" from "writes as output" from "mentions in a comment".

Largest contributors: `scripts/03_inundation_products/08_run_groundcover_response_f7.R` (15),
`06_build_stratified_sampling_frame_f5.R` (14), `10_build_veg_regime_checkerboard.R` (15),
`11_reproject_annual_stack_8058_nn.R` (14), `09_build_pixel_census_view.R` (13),
`07_run_trend_test_f6.R` (11), `R/gayini_dashboard_compose.R` (11).

Most-referenced prior-class inputs are the stable foundation layers — `annual_wet_any_1988_2023.tif`,
`annual_valid_any_1988_2023.tif`, `veg_regime_class_8058.tif`, `regime_band_breaks.csv`,
`gayini_boundary_epsg8058.gpkg`. **Report only — nothing resolved, and no judgement offered on
which of these are genuinely stale versus legitimately older foundation inputs. Human review
required.**

---

## 5. §A.3 — registry generation split

`figure_asset`, 207 rows:

| `run_id` | rows |
|---|---:|
| `db_build_20260701_114458` | 139 |
| `d2_site_dashboard_batch_20260720` | 57 |
| `gateE_20260721` | 11 |
| any other | 0 |

Observation on the 139 superseded-generation rows: none of them is a ladder figure. By directory
they are `maps/modis_ground_cover` 46 · `review` 14 · `plots/MODIS_ground_cover` 14 ·
`plots/RS_coverage` 13 · `review/redesigned_dashboards` 10 · `maps/inundation` 8 ·
`plots/hydrology` 6 · `plots/ground_cover` 5 · `plots/MER` 5 · `maps/context` 4 · `maps/MER` 4 ·
`review/MER*` 7 · `review_deck` 3.

For completeness, `raster_asset` (112 rows): `db_build_20260701_114458` 98 · `tier2H_h2` 6 ·
`gateE_20260721` 3 · `tier2H_h30` 2 · `tier2H_h6` 1 · NULL 2.

---

## 6. §A.4 — known-unregistered live assets

All 15 are present on disk and **all 15 are registered nowhere**. All are `date_class = current`.

| File | Path found | Registered |
|---|---|---|
| `J-F1_2018_difference_map.png` | `Output/figures/maps/task_J/` | none |
| `J-F2_placebo_ladder_six_panel.png` | `Output/figures/maps/task_J/` | none |
| `task_J_gate2_2018_assertions.csv` | `Output/tables/` | none |
| `task_J_gate2_2018_by_community.csv` | `Output/tables/` | none |
| `task_J_gate2_2018_summary.csv` | `Output/tables/` | none |
| `task_J_gate3_assertions.csv` | `Output/tables/` | none |
| `task_J_gate3_J_T1.csv` | `Output/tables/` | none |
| `task_J_gate3_shape_vs_reference.csv` | `Output/tables/` | none |
| `task_J_gate4_heteroscedasticity.csv` | `Output/tables/` | none |
| `task_J_gate4_law_summary.csv` | `Output/tables/` | none |
| `task_J_gate4_raster_assertions.csv` | `Output/tables/` | none |
| `task_J_gate4_residual_ranking.csv` | `Output/tables/` | none |
| `census_community_flood_freq_means.csv` | `Output/census/summaries/` **and** `docs/census_summaries/` | none |
| `census_flood_zone_by_community.csv` | `Output/census/summaries/` **and** `docs/census_summaries/` | none |
| `census_percentile_by_community.csv` | `Output/census/summaries/` **and** `docs/census_summaries/` | none |

The three census summary CSVs exist in **two locations**. Gate C §C.3 must be told which copy to
register — the pair are not otherwise distinguished in the spec. **Human decision required.**

---

## 7. §A.5 — defect status

| Item | Status | Evidence |
|---|---|---|
| **D1** — Task H spec v4 committed to `main`? | **YES — RESOLVED** | `git log --oneline origin/main -- docs/Tier2_TaskH_all_pixel_census_v4.md` → `2df23e7` ("docs: Task H v4 spec + v1–v3 superseded banners (D1 fix)…"). Working-tree copy is identical to `origin/main` (empty diff). |
| **D7** — `v_presentation_headlines.mean_inundation_change_pp` still 9.23? | **YES — still published** | View returns `mean_inundation_change_pp = 9.23`. Its DDL is `printf('%.2f', AVG(post_minus_pre_inundation_frequency_pct_points)) FROM v_plot_current_summary`; the direct average is `9.231293112942666`. **Confirmed: it derives from `v_plot_current_summary.post_minus_pre_inundation_frequency_pct_points`.** |
| **`census_asset.qa_status`** | **`REVIEW`** | one row, `census_pixel_8058`, `run_id = tier2H_h4`, `path_exists = 1`, registered SHA-256 `6b23f6c0…46f966`. |
| **`scripts/_deprecated/`** | **EXISTS, 1 file** | `01_lag_diagnostics_inundation_gc.R`. `scripts/archive/` does **not** exist — consistent with the B5 smoke-test conflict recorded in `CLAUDE.md`; not touched. |

---

## 8. Acceptance assertions — Gate A evidence

| # | Assertion | Evidence |
|---:|---|---|
| 1 | No file under `Output/` deleted or overwritten | Gate A wrote only to `docs/change_reports/`. No write, move or delete under `Output/` occurred. |
| 2 | Builder not run; `census_stratum` = 11 rows summing to 1,080,157 | Verified by query: `(11, 1080157)`. No builder invocation in this session. |
| 3 | DB SHA-256 before/after | `a8a92fb5d53324d9fa2dcce19ea59784ad2ba20046a4085475363156b24f42f7` — identical before and after; the DB was opened `mode=ro` throughout. |
| 4 | No product derived from `raster_00007` or any `pre_vs_post` asset | No product was derived at all. Gate A produced no analytical output. |
| 5 | No p50 − p05 difference raster or panel | None produced. |
| 6 | No un-sourced hectare claim about the floor in Gate C/D output | Not applicable to Gate A, which must inventory the claims. Every hectare figure quoted in this report is quoted as the content of a named artefact or a named file:line, with its definition stated at §1.3. The word "refugia" appears here only inside quoted artefact names and quoted document text. |
| 10 | No flagged number replaced by another number | No file was edited. No replacement number was computed. |
| 7 | Every new `figure_asset` row has `framing_label` and `superseded_flag` | Not applicable — Gate A created no rows. |
| 8 | `v_presentation_headlines` unaltered and present | Present; DDL read read-only; unaltered. |
| 9 | Every figure caption citing a number resolves to §1 or a DB view | Not applicable — Gate A produced no figures. |

---

## 9. Items requiring a human decision before Gate B/C

Flagged only. No recommendation is offered on any of them.

1. **D9 / §A.6** — chain is `PARTIAL`. The `fix-refugia-changelog` PR remains held.
2. **The counting step for the floor figure is not in version control** (§1.1, link 4), and its
   substrate (two ~400 MB native-3577 FC stacks, one diagnostics CSV) is neither tracked nor
   registered.
3. **1,534 orphan files under `Output/`**, 557 of them `current`. Gate B's classification list
   needs a scope: all orphans, or a named subset.
4. **The three census summary CSVs exist in two locations** (§6). Gate C §C.3 needs to be told which.
5. **131 ladder figure files, 11 registered.** Every figure in the deck is unregistered; slide→asset
   traceability by checksum is impossible (0 of 27 embedded images match on disk).
6. **`CLAUDE.md` L40 and L44 state the floor claim two different ways.** Both left untouched, per
   instruction.
7. **Deck completeness claims** on slides 28/29 (66 claimed, 57 built) and 32/33 (9 claimed, 3 built).
8. **`scripts/_deprecated/` vs `scripts/archive/`** — the B5 conflict is unchanged and untouched.

---

## ⛔ Gate A acceptance — handing back

Read-only gate complete. Four files written, all under `docs/change_reports/`, plus the v2 spec
committed to `docs/`. Nothing merged. Gate B is the human's classification step; Gate C is not
started.
