# DOC-2 — section review, scoring, and reference-state assessment

**Read-only audit. Nothing in the document was changed; no analysis was run; no registry was written.**
Run in an isolated git worktree (`task/doc2-review`), per the rule made mandatory after the fourth commit
collision.

**Audited input.** `docs/reports/Gayini_RS_methods_doc_V8.docx` · 9,827,449 bytes · modified
2026-08-04T16:36:09 · SHA-256 `d4b95bd9ca5a2f1e49d698f0f5bea141997384dac162366c17afd57562fc56b7`.
Hash recorded at Gate 0 and re-checked at Gate D — **unchanged throughout**. No Word lock file at any point.
260 claims extracted; 62 headings; 8,621 words; 25 figures, numbering clean.

**Gate records:** `DOC2_gate0_verify_sweep.md` · `DOC2_section_scores.md` · `DOC2_gateB_reference_state.md` ·
`DOC2_gateC_consistency.md` · claim table `DOC1_claim_check.csv` (260 rows).

---

## What this found, in one paragraph

**This is an accurate document with a structural problem and an editing problem.** Every DOC-1 finding that
could be applied has been, and applied precisely. The consistency sweep found **no quantity stated at two
different values anywhere**. What it did find is that the hinge statistic of the whole reference-state
argument is fitted on a different window from the one the document declares; that the two sections carrying
that argument's evidence contain no argument; and that a language-pass patch mechanism has left two
self-contradictions and one ungrammatical sentence that nothing in the build would catch.

**Nothing here requires new analysis.** All of it is correctable at the design seat.

---

# 1 · The expectation line is fitted on 1988–2022; the document declares 1988–2023

**The single most consequential finding of this task.**

The document states its record as **1988 to 2023** in §1, §2, §4.5, §7.1, §7.4 and §13. Every trend
statistic in `dim_headline_number` carries `period_label = '1988-2022'` — including
**`floor_flood_slope_64pdk`**, which *is* the expectation line: the instrument every residual in Sections 9
and 10 is measured against.

```
floor_flood_slope_64pdk                            1988-2022
t10_bala29ca_raw_floor_trend                       1988-2022
t10_bala29ca_water_adjusted_floor_trend            1988-2022
t10_gap_annual_slope_{A_all4,B_excl29ca,C_29ca}    1988-2022
t10_{grazed,ungrazed}_median_adj_trend             1988-2022
```

**Almost certainly correct** — the final water year is plausibly incomplete for the annual cover series —
**and nowhere stated.** The census and percentile results are 1988–2023; the trend and expectation-line
results are 1988–2022; a reader comparing §7 against §6.1 has no way to know they rest on different windows.

**Needs:** one clause where the record is first declared, naming both windows and why they differ.

---

# 2 · Three defects from one mechanism: patching by string replacement into a generator

The document is generated, and corrections have been applied by string replacement without a check that the
output is well-formed. **Three separate defects share that single cause**, which is why they are grouped.

### 2.1 · A sentence is broken (§7.4)

> *"Plotted on a shared scale, the difference between the panels is the difference between the panels
> indicates where cover falls furthest in poor seasons."*

A partial-string match left a fragment behind. **The instance is trivial; the mechanism is not** — nothing
in the build detects ungrammatical output, and this has run for nine versions.

### 2.2 · A caption contradicts its own body (§7.2) — **the only accuracy error in the document**

| | |
|---|---|
| **Figure 6 caption** | *"Bins containing fewer than 500 cells are dropped"* — per-bin exclusion |
| **§7.2 body, two paragraphs below** | *"Bins are retained only up to the first bin containing fewer than 500 community cells; every bin beyond that point is discarded"* — cumulative truncation |

**These are different rules, and the caption states the one DOC-1 established the code does not implement.**
The correction reached §6.6 and the §7.2 body and missed the caption. Patch coverage failing, same shape as
2.1.

### 2.3 · A VERIFY flag contradicts its own section (§6.5)

The flag reads *"The sign-consistency proportion required for a responding classification is **not stated
here**"* — two paragraphs after the section states *"the required proportion is 0.70 and the lowest observed
across the measurable strata is 0.86"*.

**Flag 4 is closed, not closeable. Remove it.**

**All three are corrections, and the mechanical sweep before v9 — duplicated clauses, doubled words,
sentences without verbs, plus a caption-versus-body check — is the durable fix.**

---

# 3 · Sections 9 and 10 carry the evidence and no argument

**Gate B's central judgement.** The reference-state sequence is correct, complete, and made in exactly two
places — neither of which holds the evidence.

- **Steps 1 and 2** are the opening two sentences of **§6.1**, a *methods* section: *"Comparing paddocks
  directly on cover confounds management with hydrological position… a direct comparison would substantially
  measure landscape position."*
- **Step 3** is one sentence in **§12.1**: *"Management category does not order the results, while geography
  does."*

Between them sit twelve figures and this:

| section | words of orienting text before its first figure |
|---|---:|
| 7 · Census results | 45 |
| 8 · Unit dashboards | 164 |
| **9 · Management-unit analysis: maps** | **0** |
| **10 · Management-unit analysis: figures** | **0** |

The individual figure texts *do* argue — F2's *"A control rather than a result"*, M5's *"the two rows
resemble one another closely… the two columns do not"*, T1's design note. **Nothing says they are steps in
one argument.** The sections read as a catalogue because structurally they are one.

**Three faults behind it:**

1. **The split is by rendering type, not by claim.** "maps" and "figures" — maps *are* figures. There is no
   proposition that "the maps" jointly establish, so neither section can carry one.
2. **The reader meets residuals five figures before the line.** Figure 18 maps departures from the
   expectation line; Figure 23 *is* that line.
3. **The decisive finding is filed as a caveat.** F1's limitation note carries *"The improvement in Bala 29ca
   begins approximately thirty years before conservation management commenced"* — the sentence that
   forecloses the grazing-exclusion reading — in the same register as *"cultivation history is unavailable"*.

**Needs:** two section-opening paragraphs. The argument already exists and is correct; it never reaches the
evidence.

---

# 4 · Cross-section consistency — the check DOC-1 did not perform

146 distinct numeric tokens; **31 appear in two or more sections**, one in seven.

**No quantity is stated at two different values anywhere in the document.** Eleven load-bearing quantities
agree across every section they appear in: 64 · 1,080,157 · 118/115 · 66 · 85,911 ha · 24.97 m · −16.8 ·
−15.1 · 6.62 · r = 0.71 · gauge 410040. 60 grazed + 4 ungrazed = 64 reconciles across M1, F1 and §4.5.
M4/F7's *"Of the 115 parts carrying sufficient support"* closes DOC-1's denominator mismatch.

**What the sweep found instead were basis mismatches and collisions, not value errors:**

| | |
|---|---|
| **§1 above** | trends on 1988–2022 against a declared 1988–2023 |
| **§4.5 plot period** | **1988–2026 is real** — `fact_plot_observation` runs to 2026-01-01 — **but every plot-support number in the document comes from `v_plot_year_analysis_spine`, which ends 2022-2023.** The row states the raw observation extent while its other columns describe the analysis. Needs a clause naming which record 2026 refers to |
| **`0.556` in three sections** | §6.2 generic worked example → §6.3 Bala 29ca's actual result → T1 range endpoint. All correct; the reader is not told the example becomes a result |
| **`500` in three sections** | the sparse-bin cell threshold (§6.6, Figure 6 caption) against *"approximately 500 ha"* of drawn green-share area (§7.5). Unrelated quantities, numerically identical, three sections apart |

---

# 5 · New verdicts

### CONTRADICTED — none against source

**No claim was found contradicted by source at this task.** The two contradictions in this audit remain the
two DOC-1 found, both since corrected. The defects at §2.2 and §2.3 above are the document contradicting
*itself*, which is a distinct class and is reported there.

### UNVERIFIABLE — one, and deliberately not called a contradiction

**§11.2 — *"mean inundation of 43.6% against 22.8% across the preceding thirty-one years"*.** No pin exists
and the aggregation basis could not be identified. An unweighted zone-community derivation gives 37.94% and
19.36%.

**It is not reported as contradicted, and the reason is a finding in its own right.** Earlier in the same
gate, that identical unweighted basis produced ungrazed flood ranks of 19/21/30/59 against the document's
3/6/31/61 — **four apparent contradictions in the most-quoted rank family in the document.** The document was
right; the derivation was wrong. The pixel-weighted non-treed basis in `census_by_zone_stratum` reproduces
Bala 26ca at 45.29% and Bala 29ca at 8.53%, matching text and registry exactly.

**A wrong derivation produces confident, plausible, wrong contradictions — four at a time.** Same discipline
as DOC-1's refusal to reason from the nearest plausible pin.

### CONFIRMED

| claim | reproduced |
|---|---|
| **§7.2 · p05 ~45 → 79, p50 ~78 → 91, "34 points against 13"** | **44.95 → 79.82** and **77.75 → 91.24**, moving **34.9** and **13.5** — from the rasters, all four values and both differences |
| T1 · Bala 26ca 45.3% · Bala 29ca 8.5% | 45.29% · 8.53%, pixel-weighted non-treed |
| §8.1 · Bala 23 long-run 39% | 38.60% |
| §6.1 / T1 · ranks 3rd, 6th, 31st, 61st | registered `ref_paddock_flood_rank_*` = 3 / 6 / 31 / 61 |
| F4 · +8.4 / +13.5 / −0.8 | `gap_change_all_{aeolian,riverine,inland}` exactly; non-flood counterparts 9.7 / 12.3 / 0.6 all positive, confirming *"narrowing present in both"* |
| §6.5 · sign proportion 0.70, lowest observed 0.86, coverage floor "59%" | `SIGN_FRAC = 0.70`; Riverine low coverage 58.76% |

---

# 6 · The VERIFY sweep

**Seven distinct passages in v8, against the six DOC-1 established in v6** — the references section was
restructured and partly sourced, splitting one flag into *Data products* and *Software*. **Citations have
halved: six outstanding at DOC-1, three now**, each named with what it supports.

| # | § | Status | Note |
|---|---|---|---|
| 1 | §2 Data sources | **OPEN** | Provider metadata; not obtainable from the repository |
| 2 | §6.1 diagnostics | **OPEN** | Needs the diagnostics run — new analysis |
| 3 | §6.5 A/B seasonal reductions | **CLOSED IN THIS TASK** | Result below |
| 4 | §6.5 sign proportion | **CLOSED** — and the flag is now false about its own document (§2.3) | Remove |
| 5 | §12.3 priorities | **OPEN** | A decision, not a verification |
| 6 | References · Data products | **OPEN**, and **substantially duplicates flag 1** | Make it a pointer |
| 7 | References · Software | **CLOSED IN THIS TASK** | Versions below |

### Flag 3 closed — and it moves a number

From `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`:

**The growing-season cross-check runs lower in 8 of 8 measurable strata, mean gap 0.0415. Five strata reach
0.20 under the base series; four under the cross-check** — Riverine mid moving 0.2259 → 0.1882.

**And the difference is seasonal, not a selection artefact:** the base series recomputed on the cross-check's
own cell set differs by at most **0.003** in every stratum. That is what the `A_on_Bset` column exists to
establish, and it does.

**Consequence:** §7.3's "five" is the base-series answer. Whichever count the text carries should name the
reduction it belongs to.

### Flag 7 closed — with a caveat that should travel

Recorded across the change reports: **R 4.6.1 · `terra` 1.9.34 · `sf` 1.1.1 · Python 3.12.10 · `duckdb`
1.5.4 · `rasterio` 1.5.0 (GDAL 3.12.1)**, plus the pinned DEA stack.

**There is no project-wide environment lock** — no `renv.lock`, and `DESCRIPTION` pins nothing. These are
**per-task toolchain records**, so any statement built from them is *a reconstruction across tasks, not a
captured environment*. **`mgcv` is the gap that matters:** §6.6 names it as the fitting engine for every
dashboard curve and its version is recorded nowhere.

---

# 7 · Section scores

**Means: accuracy 4.7 · expression 4.5.** Scored independently against a clever, engaged non-specialist.

| § | Section | A | E | Δ |
|---|---|:--:|:--:|:--:|
| — | Front matter | 5 | 5 | |
| 1 | Study area and scope | 5 | 5 | |
| 2 | Data sources | 4 | 4 | |
| 3 | The analytical substrate | 5 | 5 | |
| 3.1 | Stratification | 5 | 4 | |
| 4.1 | Ground cover | 5 | 5 | |
| 4.2 | Inundation | 5 | 5 | |
| 4.3 | Percentiles | 5 | 5 | |
| 4.4 | The two floors | 5 | 4 | |
| 4.5 | Support | 4 | 4 | |
| 5 | Why the floor rather than the mean | 5 | 5 | |
| 6 | Statistical methods | 5 | 5 | |
| 6.1 | The expectation line | 5 | 4 | |
| 6.2 | Trends over time | 4 | 4 | |
| **6.3** | **Water-adjusted trend** | **5** | **3** | **Δ2** |
| 6.4 | Community-scaled scores | 5 | 4 | |
| 6.5 | Same-year response | 3 | 4 | |
| **6.6** | **Smoothed response curves** | **5** | **3** | **Δ2** |
| 7 | Census results (intro) | 5 | 5 | |
| 7.1 | Flooding is variable | 5 | 4 | |
| **7.2** | **Flooding sets the drought floor** | **2** | **4** | **Δ2** |
| 7.3 | Response consistency | 4 | 5 | |
| **7.4** | **Where cover persists** | **5** | **2** | **Δ3** |
| 7.5 | Retained cover and living cover | 5 | 4 | |
| 8 | Unit dashboards | 5 | 5 | |
| 8.1 | Paddock dashboards | 5 | 5 | |
| 8.2 | Site dashboards | 5 | 5 | |
| 9·M1 | Management zones | 5 | 5 | |
| 9·M2 | Monitoring network | 5 | 5 | |
| 9·M4/F7 | Paddock parts by state | 5 | 4 | |
| 9·M5 | Cover and water at two grains | 5 | 5 | |
| 9·M5b | Departure from expectation | 5 | 5 | |
| 10·F1 | Paddock floor trajectories | 5 | 5 | |
| 10·F2 | The same record on mean cover | 5 | 5 | |
| 10·F3 | Annual gap to grazed country | 5 | 4 | |
| 10·F4 | Decomposition of gap change | 4 | 3 | |
| 10·F5 | Cover floor against flood frequency | 5 | 5 | |
| 10·F6 | Three-arm comparison | 5 | 4 | |
| 10·T1 | The four ungrazed compared | 5 | 5 | |
| T2 | Part classification listing | 5 | 5 | |
| **T3** | **Statement of limitations** | **5** | **2** | **Δ3** |
| 11.1–11.5 | Limitations (all five) | 5 | 5 | |
| 12.1 | What the results imply | 5 | 5 | |
| 12.2 | Gaps in order of consequence | 5 | 5 | |
| 12.3 | Next steps | 4 | 5 | |
| **13** | **Positioning** | **3** | **5** | **Δ2** |
| R1 | References · Data products | 4 | 5 | |
| R2–R4 | Regional / Vegetation / Not yet sourced | 5 | 5 | |
| R5 | References · Software | 3 | 4 | |

### The six divergent sections, in priority order

1. **§7.4 (Δ3)** — the broken sentence. §2.1 above.
2. **T3 (Δ3)** — a listed deliverable marked *"In preparation"*. A reader cannot tell whether something is
   missing or forthcoming. Say plainly that Section 11 is the statement for this version.
3. **§7.2 (Δ2)** — the caption contradicting its body. §2.2 above; **the only accuracy error in the document.**
4. **§6.3 (Δ2)** — **"residual" means two different objects.** §6.1 spends 420 words teaching that a residual
   is a paddock's departure from the property-wide line; §6.3 then uses it for a year's deviation inside one
   unit's own water fit. One clause distinguishing them.
5. **§6.6 (Δ2)** — a truncation rule given for a figure the text then says does not appear here. Keep it and
   say **why** it is there — that a related figure elsewhere uses a different rule and the two must not be
   conflated — and a digression becomes a warning.
6. **§13 (Δ2)** — the best-written section, resting entirely on the flow-decline literature listed as not yet
   sourced. **The shortest path to closure of anything on this list: one reference.**

### The pattern worth keeping

**Expression fails hardest exactly where the analysis is most careful.** §6.3, §6.6 and §7.5 score 5 on
accuracy and lowest on expression; the care is what makes them dense. The fix is never to simplify the
method — it is to say in one plain sentence what the method does before saying precisely what it is.
**§4.3 already does this with percentiles and is the model.**

---

# 8 · Reference-state figures — substitution and explanation

### B2 · Registered figures that would explain an existing claim better

**Nothing was substituted.** Searched `figure_asset` (297 rows, filtered to the 158 not superseded) and
`table_asset` (5 rows).

| candidate | claim served | why better |
|---|---|---|
| **`T3_B_area_vs_threshold.png`** | §7.5: *"no natural break, plateau or bimodality… 12,641 / 8,300 / 4,179 ha"* | **A claim about the shape of a curve, currently carried by three points on it.** The registered figure is the sweep. Strongest candidate found in either task |
| **`T13_D2_part_state_map_sensitivity.png`** | M4/F7: *"Between three and fifteen parts… it is the same parts throughout"* | A nesting claim; the registered caption states it exactly — *"parts enter and leave as the cut moves but are never swapped"* |
| `D1_paddock_Dinan_10_slide_data.png` | M5b's twin argument | **Reported, not recommended.** Would replace Figure 12 and lose the wet/dry contrast that makes the water-adjustment case visually |
| `S_veg_water_gam_p05.png` | §6.6's GAM description, which has no figure | **Disqualified as-is** — no registered caption, `support_level` NULL |

**One near-miss, recorded so it is not repeated.** `T3_A1_two_metrics.png` — *"the two floor metrics side by
side"* — looks exactly like the figure §4.4 lacks. **It is not:** it shows the green-share against
total-cover pair (§7.5), not the spatial against temporal pair (§4.4). **This project has two distinct "two
floors" pairs and one figure title that does not say which.** Matching by title would have put the wrong
figure under the section CLAUDE.md calls the most-confused pair of numbers in the project. Logged **D1-I7**,
alongside the `FigA` trap (**D1-I5**).

**Named in one line, not developed:** §4.4's spatial-versus-temporal pair has **no registered figure
anywhere.**

**Registration re-check:** 15 of v8's 25 embedded images are byte-identical to a registered asset — the same
15 as v6. `M1_veg_percentile_maps_p05_p50.png` is not among them; DOC-1 Gate D's Figure 8 swap was not
applied, which the design seat has confirmed and will record in the figure provenance table.

### B3 · The three figures where explanation gains most

1. **Figure 23 (F5) — the expectation line itself.** The hinge of the entire argument, explained in 97 words,
   placed five figures after the map of departures from it. The text never says that this line is the
   instrument every residual in the document is measured against.
2. **Figure 19 (F1) — the decisive finding is filed as a caveat.** The thirty-years-before sentence is the
   result, not a limitation of it.
3. **Figure 22 (F4) — readable as its own opposite.** The sign convention for "gap" is stated under Figure 21
   and not repeated, so *"+8.4 percentage points"* followed by *"the narrowing"* appears self-contradictory
   unless the reader recalls the gap is negative.

---

# 9 · Coverage, stated plainly

**v8 holds 260 claims: 111 value · 90 structural · 51 method · 8 interpretive. Value + structural = 201.**

The document grew: v6 had **175** value and structural claims, v8 has **201** — §4.5 Support and the
restructured references added 26.

| | |
|---|---|
| checked at DOC-1 (priority list, against v6's 175) | **48** |
| newly checked at DOC-2 Gate C | **12 distinct claims**, plus consistency verified across **31 repeated quantities** |
| **checked in substance, against v8's 201** | **~60** |
| **never checked** | **~141** |
| carrying a machine-readable verdict in `DOC1_claim_check.csv` | 26 value/structural (31 verdicts including method rows) |
| method claims | **43 of 43 examined at DOC-1**; v8 now holds 51, so **8 are new and unexamined** |

**Roughly 141 of 201 value and structural claims have never been checked, and nothing establishes that no
further contradiction sits among them.**

### The front-matter self-report is stale, and structurally so

It reads *"checked 48 of the 175 value and structural claims in this document"*. **Both numbers were correct
for v6 and neither is correct for v8.** Nothing updates that sentence on rebuild, so it drifts every
version — and it is the one place the document reports its own audit coverage, which makes it the sentence
most likely to be quoted back. **Generate it, or drop the counts and keep the qualitative statement.**

---

# 10 · What cannot be closed in this task

| item | what it would need |
|---|---|
| **Regression diagnostics** (§6.1) | Running them — new analysis. Established unclosable at DOC-1 |
| **Provider metadata** (§2, Data products) | The FC and water-observation providers' product metadata. Not in this repository |
| **Three citations** | External sourcing. **§13's is the highest-value:** it supports that section's whole argument and is one reference |
| **§12.3 priorities** (flag 5) | A design-seat decision, not a verification |
| **§11.2's 43.6% / 22.8%** | The correct aggregation basis, or a pin. Not reproducible from the objects available |
| **~141 unchecked claims** | More checking. The consistency sweep is now done; what remains is claim-by-claim against source |
| **`mgcv` version** | Recorded nowhere in the repository |
| **§4.4's figure** | No registered candidate exists |

---

## Registry re-probe at Gate D

**Audit window: 4 August 2026, 16:36 to 17:35.**

| object | now | at DOC-1 Gate E | delta |
|---|---:|---:|---:|
| tables / views | 93 / 35 | 93 / 35 | 0 |
| `raster_asset` | 191 | 191 | 0 |
| `figure_asset` | 297 | 297 | 0 |
| `dim_headline_number` | 101 | 101 | 0 |
| `report_asset` · `table_asset` · `spatial_layer_asset` | 60 · 5 · 9 | unchanged | 0 |

**No registry movement during DOC-2** — the database has not been written since 15:30, before this task
began. Every value in this report rests on the same registry state DOC-1 Gate E reported, and the document
hash is unchanged from Gate 0 to Gate D.

**CLAUDE.md's recorded DB shape remains stale** — it states 86 tables / 30 views / `figure_asset` 278 /
`dim_headline_number` 59 against a live 93 / 35 / 297 / 101.
