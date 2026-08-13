# Methods document V10 → V11 — consolidated change list

**Design seat · 4 August 2026 · deadline 10 August**
**Target:** the methods-document generator at the design seat. **Not** the `.docx`, which is output.
**Commit this file to `docs/reports/`** so both seats can see what has been applied.

**Source document:** `Gayini_RS_methods_doc_V10.docx`, SHA-256
`f78467fadceb377fe0b4fc8226332c931d01f8e2e3e56e60b5daad83ad9d030a`, 49 pp, 28 figures.

**Provenance of every change:** DOC-3 (`d3d0616`), Ruling U blast radius (`d734caf`), issues log
(`2a6a0e8`), rulings T/V/W/X/Y/Z/AA/U-b, and `Gayini_reference_state_figure_text_FINAL_20260804.md`.

---

## Why this file exists

CC reads the `.docx` and writes findings to the repository. The generator lives at the design seat.
**Nothing carries findings back across that gap, and nothing tests whether the document reflects
them.** Today produced ten changes and the document has none of them.

This file is the carrier. Mark `APPLIED` as each lands. When every row is applied, V11 is built and
its hash recorded at the foot of this file — that hash is the only evidence the translation
happened.

---

## Status key

`OPEN` — not yet applied · `APPLIED` — in the generator · `N/A` — not a document change

---

## Changes in document order

### Front matter

| # | Change | Source | Status |
|---|---|---|:--:|
| 1 | Add to the list of quantities without a producing script: **the two persistence percentages in §7.4 (94.9% and 81.2%)**. They reproduce exactly from the shipped rasters but no producer emits them and neither carries a `number_id`. | Ruling X | APPLIED |
| 2 | Add one sentence: **the dashboard figures (12, 13, 14) predate the current state of their producing code.** All 78 registered dashboard renders precede the last commit to every file that produces them. | I-50 | APPLIED |

### §1 · Study area and scope

| # | Change | Source | Status |
|---|---|---|:--:|
| 3 | Replace *"Percentages are reported against one of these two bases"* with a **four-base table**: property 85,910.8 ha (boundary, EPSG:8058) · mapped census 67,349.3 ha (1,080,157 cells @ 24.97 m) · non-treed census 61,655.0 ha (988,831 cells @ 24.97 m) · property at native 30 m 86,385 ha (959,833 cells @ 30 m, EPSG:3577). | Ruling V | APPLIED |
| 4 | State that the first and fourth are **the same boundary on different grids in different projections, not two properties**, and that `property_outside_mapped_ha` = 18,561.5 reconciles the first two (67,349.3 + 18,561.5 = 85,910.8). | Ruling V | APPLIED |
| 5 | *"Trend statistics and the expectation line…"* → **"Cover trend statistics and the expectation line…"**. The inundation series runs 1988–2023 with the final water year complete; Figure 4's caption is correct as it stands. | Ruling W | APPLIED |

### §3.1 · Stratification

| # | Change | Source | Status |
|---|---|---|:--:|
| 6 | *"three communities — Aeolian Chenopod Shrublands, Riverine Chenopod Shrublands, Inland Floodplain Shrublands and Swamps"* parses as four names. Semicolon-separate: **"Aeolian Chenopod Shrublands; Riverine Chenopod Shrublands; and Inland Floodplain Shrublands and Swamps."** | C10 | APPLIED |

### §4.2 · Inundation — **new subsection**

| # | Change | Source | Status |
|---|---|---|:--:|
| 7 | Add **"Two footprints"**, parallel in form to §4.4's two floors. **Census footprint** — pixel-weighted mean over non-treed strata in `census_by_zone_stratum`; the standing basis, registered, used by Figure 28 and every rank and residual. **Polygon footprint** — every valid raster cell inside the zone boundary regardless of vegetation mapping or treed status; used by the unit dashboards, because a dashboard locates the whole unit rather than its analysable subset. State that the two coincide where a boundary lies wholly inside mapped non-treed country and diverge where it does not: **Bala 29ca reads 8.5% and 10.3%** because its boundary encloses unmapped and context cells wetter than its mapped country; **Bala 23 is identical at 38.6%**. | Ruling T | APPLIED |

### §4.6 · Aggregation order — **new subsection**

| # | Change | Source | Status |
|---|---|---|:--:|
| 8 | Add **§4.6 · How a number is formed**, parallel to §4.4 and §4.5. Three rules under one heading, because three separate defects today were the same defect. **(a) Aggregation order.** Worked case, all three verified: post-management mean inundation reads **43.64% pixel-weighted** (the property), **45.97% as a mean of paddock means** (the average paddock, n = 64), **37.94% as an unweighted mean of stratum means** (the average stratum, n = 118) — a spread of 8.0 points. Every ratio here is pixel-weighted unless stated otherwise. **(b) Rounding order.** Values in this document are rounded **once, from source**. `dim_headline_number` stores pinned values at 2 decimal places; re-rounding a pinned value can shift the last digit. **(c) Counting basis.** A count of units may be taken on **geometry** (parts that exist) or on **support** (parts that clear the ≥30-valid-cell rule). The two differ and both are legitimate; whichever is used is named. | Ruling AA + AB | APPLIED |

### §5 · Why the floor rather than the mean

| # | Change | Source | Status |
|---|---|---|:--:|
| 9 | Section heading and body use the bare word "floor", which §4.4 declares is avoided. Heading → **"Why the poorest patches rather than the mean"**. | C6a | APPLIED |

### §6.2 · Trends over time

| # | Change | Source | Status |
|---|---|---|:--:|
| 10 | *"the floor rising by about half a percentage point"* → **"the cover floor rising…"**. | C6a | APPLIED |

### §6.6 · Smoothed response curves and descriptive tests

| # | Change | Source | Status |
|---|---|---|:--:|
| 11 | Amend the Kruskal–Wallis paragraph, in this order: **the pack ships no p-values**; **the report batch crops this one out and no client report carries it** — the 57 site reports crop the dashboard to the left column, top 60%, and the caption sits at ≈74% of figure height; **it is retained on the dashboards because it is a between-community separation statistic and not an inferential claim about the annual series**; and it is labelled descriptive for that reason. | Ruling U-b | APPLIED |

### §7.2 · Flooding sets the drought floor

| # | Change | Source | Status |
|---|---|---|:--:|
| 12 | Heading *"Flooding sets the drought floor"* and body *"the floor moves roughly 34 points"* → name the metric. This section reports the **temporal** percentile. | C6a | APPLIED |

### §7.4 · Where cover persists

| # | Change | Source | Status |
|---|---|---|:--:|
| 13 | Five bare uses of "floor", plus the Figure 9 and Figure 10 numbered captions. All refer to the **temporal** metric. | C6a | APPLIED |
| 14 | Name the footprint inline where the green-share median and area are quoted: **86,385 ha is the property boundary on the native 30 m EPSG:3577 grid**, producer `scripts/05_ground_cover/04_taskM_green_at_floor_area.R`, field `implied_farm_ha_30m`. Cross-reference §1. | Ruling V | APPLIED |
| 15 | State that **94.9% and 81.2% are measured on the drawn, reprojected, component-filtered EPSG:8058 surfaces** — 406.09 ha both / 7,969.70 ha total-cover; 406.09 / 500.06 ha green-share. | Ruling X | APPLIED |
| 16 | Record the lineage as **four distinct objects, not four estimates of one**: 6,458 ha measured at native 30 m (canonical) · 4,474 ha an arithmetic conversion of a count · 3,744 ha the correct 8058 reprojection · 500 ha that surface after the 5 ha component filter. | Ruling X | APPLIED |

### §8 · Unit dashboards

| # | Change | Source | Status |
|---|---|---|:--:|
| 17 | Panel table: *"the GAM floor curve"* → name the metric. | C6a | APPLIED |
| 18 | Figure 12 and Figure 13 captions name their footprint per §4.2. Figure 12's 10% and 17% are polygon-footprint values. | Ruling T | APPLIED |

### §9 · Management-unit analysis: maps

| # | Change | Source | Status |
|---|---|---|:--:|
| 19 | Roadmap: *"three of the four sit in the wettest country on the property (Figure 15)"* → **two of the four sit in the property's wettest country at ranks 3 and 6; the third is at rank 31, essentially the midpoint; the fourth is at 61.** Citation **Figure 15 → Figure 28** — Figure 15 is the treatment map and carries no hydrological variable. | Ruling W | APPLIED |
| 20 | **M4:** delete *"it is the same parts throughout"* and replace with Figure 18's wording. State the ladder: `1.50 (3) ⊂ 1.25 (4) ⊂ drop2wettest (5) ⊂ registered (8) ⊂ 1.00 (8) ⊂ 0.75 (10) ⊂ 0.50 (15)`. Nesting is strict; no part is present at a stricter cut and absent at a looser one. | Ruling W | APPLIED |
| 20b | **T2 limitation:** *"Three of 118 parts fall below the minimum support rule"* — **name them**: Bala 15 · Riverine (23 px, 1.43 ha), Bala 28ca · Aeolian (10 px, 0.62 ha), Mara 3 · Aeolian (1 px, 0.06 ha). Naming them costs one line and makes the rule auditable. | Ruling AB | APPLIED |
| 21 | **Figure 20 interpretation:** *"Dinan 10 at −15.1"* → **"Dinan 10 and Dinan 13, both grazed, lie 15.1 and 15.0 percentage points below expectation and are separated by two hundredths of a point."** Dinan 13 carries no `number_id`. | Ruling Y | APPLIED |

### §10 · Management-unit analysis: figures

| # | Change | Source | Status |
|---|---|---|:--:|
| 22 | Bala 29ca table: *"supplies most of the signal in Figure 20"* → **Bala 29ca is second-largest; Bala 15 at −17.62 is the largest.** | Ruling Y | APPLIED |
| 23 | **Figure 21 · replace the entire passage** with `Gayini_reference_state_figure_text_FINAL_20260804.md` § F1. Corrects the unit (paddock-community part, not paddock), the panel membership (Riverine carries three conserved lines — 26ca, 28ca, 29ca — not one), adds the two-arms-not-three note, the design-not-evidence paragraph, and the Bala 26ca line-weight note. **Add one clause:** the Aeolian panel carries a single conserved line because Bala 28ca's Aeolian portion is 10 pixels — 0.62 ha, 0.0% of the paddock — and fails the ≥30-valid-cell support rule. The panel's membership is a support outcome, not an absence of geometry. | figure text + AB | APPLIED |
| 23b | **Figure 26 · add a footnote under the nine-value table:** values are rounded once from source, not from the registry's 2-decimal pinned values. Two of today's numbers sit on rounding boundaries — inferred Riverine on the floor (source 7.947 → **+7.9**; the pin stores 7.95, which re-rounds to 8.0) and Aeolian conserved on the mean (source −4.050 → **−4.1** under round-half-away-from-zero). Both texts are correct; the footnote stops a later reader "correcting" them against the registry. | Ruling AB | APPLIED |
| 24 | **Figure 22 · replace the entire passage** with § F2. **The current claim that the separation is absent is false as drawn** — it falls from −32.0 raw / −10.5 adjusted to −4.1 / −2.3, which is a factor of about five, not zero. | figure text | APPLIED |
| 25 | **Figure 23 · replace the entire passage** with § F3, adding the **grain note**: Figures 21 and 22 are part grain, Figure 23 is whole-paddock grain, and the two are not numerically comparable. | figure text | APPLIED |
| 26 | **Figure 25 caption:** Dinan 10's third rank is a tie with Dinan 13 at 0.02 pp. Same wording as change 21. | Ruling Y | APPLIED |
| 27 | **Figure 26 · replace the entire passage** with § F6, including the nine adjusted differences as a table. | figure text | APPLIED |
| 28 | **Figure 28 caption** names the census footprint per §4.2. Its 8.5% is the registered `bala29ca_mean_flood_freq`. | Ruling T | APPLIED |
| 29 | §F6 closing paragraph: *"why the floor was chosen"* → name the metric. | C6a | APPLIED |

### §11 · Limitations

| # | Change | Source | Status |
|---|---|---|:--:|
| 30 | **§11.5:** *"Four paddocks, spatially clustered"* **contradicts M1**, which states they do not form a contiguous block, occur in three separate parts of the property, and the furthest pair are ~30 km apart. Replace with **"spatially dispersed"** or delete the word. | C1 | APPLIED |
| 31 | **§11.2:** state the aggregation order in the same breath as the value — **"43.6% pixel-weighted against 22.8%"**, cross-referencing §4.6. | Ruling AA / I-38 | APPLIED |

### Vocabulary — applies throughout

| # | Change | Source | Status |
|---|---|---|:--:|
| 32 | The document says **"ungrazed"**; the pack, the deliverables register and Figure 23's own title say **"conserved"**. Adrian receives both. **Move the document to "conserved."** The figures still render "reference" and "not grazed" — the four replacement figure passages each state once that the in-figure label is the analysis category, not a finding. | Ruling Z context | APPLIED |

---

## Not document changes

| Item | Where it lives |
|---|---|
| Ruling Z — lines 85, 99, 236 of `T6_gateE_figures.R` change together | producer, unauthorised |
| Figures 21/22 restack and portrait section | producer + generator, unauthorised, **cuttable** |
| `show_kw` | untouched per Ruling U-b |
| I-48, I-49, I-50, I-51 | issues log, `2a6a0e8` |
| **I-52** — `fact_three_arm_gap_decomposition.n_units` counts on geometry (2 for Aeolian conserved) while the part classification counts on support (1). No number moves; the excluded fragment is 0.08% of the arm's Aeolian pixels. **Third instance today of one name covering two counting bases**, after the flood-frequency footprints and the aggregation orders. Disposition: §4.6(c) states the rule; the registry reconciliation is post-deadline | issues log, to write |

---

## Two things to fix on the CC side

**1 · Three untracked notes in the repository root.** CC's last status reports the working tree
clean *"apart from the three untracked root notes."* Untracked means uncommitted, unpushed, and
absent from the laptop checkout. `Output/audit/` carries the gitignore exception; the repository
root does not. **Move them to `Output/audit/` and commit.**

**2 · Every audit output goes to `Output/audit/` and is committed in the same task that produces
it.** A finding that exists only on one machine is not a finding. This is I-48's standing rule
pointed inward: a document produced by a task must be in the repository when the task closes.

---

## Completion

The translation is complete when every row reads `APPLIED`, V11 is built, and its SHA-256 is
recorded here:

> **V11 SHA-256:** `019b32126e4d28956979d92f31430f6fef329ea2a6efbb257926219d60ce7f1f`
>
> Built 4 August 2026 by `build_v11.py` from V10. 31 operations, all applied. 52 pp, 28 figures,
> 575 paragraphs (+25). Schema validation passed. **Figure cuts not applied — no renumbering.**

**That hash is the only evidence any of today's work reached the document.**
