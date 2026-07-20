# Tier 2 · Task I — deck stocktake & review bundle

*Design-seat spec, 16 July 2026. Follows Task H (Track A + Track B complete). Reference deck: `docs/Gayini_Veg_samples.pptx` (26 slides).*

**Workflow: branch-and-PR, held. Do not merge. STOP at Gate I.1.**

---

## 0. What this task is — and is not

**Is:** a per-slide audit of what the all-pixel census changes in the shipped deck, plus a packaged bundle for Adrian.

**Is NOT:** a figure rebuild. **Do not rebuild any figure in this task.** Three reasons, all hard:

1. **F6 is unratified.** The census says **9/0/0**; the deck says **8/1/0**. That change is Adrian's to ratify — it is the *purpose* of the bundle, not an input to it.
2. **F4's numbers are correct.** 9/22/50/44 is right *at plot support*. It needs a **label**, not a census rebuild. Rebuilding it would swap a correct number for a different-support one under the same claim — **exactly the C10 error already made once in this project.**
3. **H5 is blocked** on Adrian's density/CI examples (#18). Building a census figure now means inventing a convention he already has.

**And the frame itself may not survive.** Floodplain Woodland is the **wettest unit on the property** (21.1% frequently flooded); "Other / minor units" is **50.8% regularly + 40.4% occasionally**. Both sit greyed out as unbanded context, invisible in the 9-cell matrix. The staircase says the bands aren't cross-comparable at all. **Rebuilding figures inside a frame Adrian may be about to change is work done twice.**

Figure rebuild is **Task J**, after ratification.

## 1. Read first — do not re-derive

**`docs/Gayini_established_data_facts.md`** is the reference. **§10 is a settled table — do not re-open it.** Every number below comes from there and is already measured.

Also: `docs/change_reports/tier2H_all_pixel_census_20260715.md`, `tier2H_gate1_verified_20260715.md`.

---

## 2. Gate I.1 · Deck stocktake — **REPORT AND STOP**

For **every one of the 26 slides**, classify and evidence. The table below is the design seat's read of the deck — **verify it, correct it, and complete it.** It is a starting point, not an answer. Where it's wrong, say so.

**Classification:**

| Code | Meaning |
|---|---|
| **OK** | census changes nothing |
| **LABEL** | number is correct; needs a support/scope label |
| **RESTATE** | number or claim changes |
| **DEAD** | slide describes cancelled work |
| **SUPERSEDED** | better evidence now exists |
| **FRAME** | depends on a structural decision Adrian may change |

### The design seat's read — verify and extend

| # | Slide | Class | Why |
|---|---|---|---|
| 1–3 | Title · Two questions · Monitoring setup | **OK?** | Framing/concept. Check for "provisional" or sampling language. |
| **4** | Four communities, driest to wettest | **LABEL** | **"SHARE OF YEARS FLOODED · 9% / 22% / 50% / 44%"** — correct at **plot support**, unlabelled. Census is 6.08 / 12.91 / 27.99 per 25 m pixel. **C10.** |
| 5 | How we tell if a pixel is under water | OK? | Method. But "years with too little coverage are set aside" — for the census, **every pixel has 35/35**. Check whether the caveat still reads true. |
| 6 | Definition of flood frequency | OK? | Concept. |
| **7** | Has flooding changed over 35 years? (F2) | **SUPERSEDED** | "the share of the **66 plots** that flooded that year". The census per-year cut runs **0.04% (2006) → 84.67% (2022)** across 988,831 pixels — a ~2,000× swing. Stronger, and not in the deck. |
| **8** | The whole record at a glance (F3) | **LABEL** | 66 plots × 35 years. Plot support. |
| **9** | Flooding differs strongly with vegetation type (F4) | **LABEL** | White diamonds = **9% / 22% / 50%**, Woodland 44%. `R/gayini_descriptive_figures.R:472`. **The shipped slide. C10.** |
| **10** | Comparing like with like (F5 concept) | **DEAD** | Describes the sampling design. Task F cancelled 15 Jul. |
| **11** | The sampling laid over the flood map | **DEAD** | Sample points. The flood-frequency *surface* is still valid — the dots are not. |
| **12** | How much each stratum covers / how densely we sample | **DEAD** | The density argument ("2.7 points per 1,000 ha … why the wet-end result is provisional") is **the problem the census dissolves**. *Note "two-thirds of the mapped farm" is correct as written — it says **mapped**. Do not "fix" it.* |
| **13** | **Proposed fix: sample in proportion to area, and repeat** | **DEAD** | *"The ask — this is what we'd like your approval to run."* **Adrian answered on 15 Jul: census instead.** This slide is the superseded ask. |
| 14–17 | Per-paddock flood frequency ×4 | **LABEL** | Surface valid; **sample dots dead**. Slide 15's *"deep blue blob is a lake bed"* is now characterised: **346.9 ha, 91.4% inundation** (facts §9). |
| 18–19 | Checkerboard concept + farm map | **FRAME** | The **staircase**: Aeolian's wettest band (~5 yrs/35) is wetter than Inland's driest (~3 yrs/35). "Darker = wetter" is true *within* a community, **false across the map**. Grey "woodland and minor units" are the **wettest ground on the property**. |
| 20 | Three kinds of trend (F6 concept) | OK? | Concept. |
| **21** | Is the amount of flooding trending? (F6 data) | **RESTATE** | *"8 of 9 … only the driest Riverine spots show an episodic jump … the wettest, largest areas are the most thinly sampled, so we treat this as provisional."* → **9/0/0, census, caveat gone.** |
| **22** | No clear trend — so far…? | **RESTATE + DEAD** | The 3×3 verdict grid says **Riverine drier = "Episodic jump"** → now **No trend**. And *"The proposed rebalanced sampling is designed to test it properly"* is **dead**. The whole hedge goes. |
| 23 | Where recent years sit vs the long-run average | OK? | Concept, no data figure. Check. |
| 24–26 | F7 response · lag profile · strata panel | **OK** | Per-plot lag analysis. **Explicitly stays on the per-plot method** (Task H spec §2) — the static percentile raster cannot feed it. Unaffected. |

### Also report: what is NOT in the deck but should be

New since it was built, and several are stronger than what's there:

- **Per-year cut**: 0.04% → 84.67%, ~2,000× swing, no drift. The clearest flood-pulse evidence in the project.
- **41.59% of Aeolian never flooded once in 35 years.** The driest community has no internal wetness gradient at the low end — and **Aeolian low's "no trend" is trivially true** (flat zero series).
- **Absolute flood zones** (never / <1:10 / 1:10–1:4 / 1:4–1:2 / >1:2) — comparable across communities, unlike the terciles.
- **The floor is ~97% dead** at the median — and **~4,300 ha (≈5% of the farm) has a majority-green floor**. A refugia map.
- **The 40-point false-positive rate: 54.1%.** The evidence that retires sampling.

### Deliverable

`docs/change_reports/taskI_deck_stocktake_<date>.md` — the completed table, plus the not-in-deck list, plus **a count by class**. **Then STOP.** Do not touch the deck.

---

## 3. Gate I.2 · The bundle (after I.1 is reviewed)

`Output/review_bundles/tier2H_all_pixel_census/`, zipped. **Assembly only — no new analysis.**

**Contents:**

| Group | Files |
|---|---|
| Verdict | `tier2H_trackA_qa.json`, `tier2H_h2_qa.json`, `tier2H_h2_gate_verdict.json`, `tier2H_h6_qa.json` |
| Track A | census matrix · stratum annual series · F6 verdicts · F6 delta vs sample · per-year cut |
| Track B | water-year pool · valid-season distribution · nodata by scene · seasonal bias test · balanced subsample · farm-masked diagnostics · monotonicity · blob probe |
| H6 | flood-zone crosstab |
| Figures | `H2_veg_percentiles_{common_scale,stretch}_data.png` · `H6_flood_zone_data.png` · `H2_gate_season_mix_data.png` |
| Docs | this stocktake · the Task H change report · `Gayini_established_data_facts.md` |

**Never bundle:** the census parquet, any raster, the FC cube. Small tables and figures only.

**A one-page README at the root** — what changed, in Adrian's language, not ours. No F-numbers, no view names, no file paths in the prose. Lead with:

1. **F6 is now 9/0/0.** The one area that looked like it had shifted was a 40-point sampling artefact — **a 40-point design returns a false positive 54.1% of the time** in that stratum, against a nominal 5%. Nothing on the property is trending. **This needs his ratification.**
2. **The "provisional / thinly sampled" caveat is gone** — by construction, not by argument.
3. **Flood extent runs 0.04% to 84.67%** across the record. Flood-pulse driven, legible.

---

## 4. The four questions for Adrian — include in the README

Written for a co-investigator, not a methods reviewer. **Keep them this short.**

> **1. F6 is now 9 no-trend / 0 / 0, not 8/1/0.** The one area that looked like it had shifted was a sampling artefact — with 40 points that test returns a false positive 54% of the time; with every pixel it disappears. Nothing on the property is trending. **Ratify?**
>
> **2. Two correct answers to "how often does it flood."** Per 25 m patch of ground: **6 / 13 / 28** (Aeolian / Riverine / Inland). Per 1-ha monitoring site: **9 / 22 / 50** — a site counts as wet if any part of it is. Both right, different question. **Which goes on the slides?** The deck currently shows 9/22/50.
>
> **3. The wetness bands don't compare across vegetation types.** Aeolian's *wettest* band floods about 5 years in 35; Inland's *driest* floods about 3. So "darker = wetter" is misleading across the map. **Keep the relative bands, or switch to plain flood frequencies** (never / less than 1 year in 10 / 1 in 10–4 / 1 in 4–2 / more than 1 in 2)? The plain version is comparable and checkable against knowledge — probably better for the Nari Nari panels.
>
> **4. Year-by-year or whole-record?** Both are built. The year-by-year series runs **0.04% of the country flooded (2006) to 84.7% (2022)** — a 2,000-fold swing with no drift, and probably the clearest picture of the flood pulse we have. **Lead with it, the whole-record map, or both?**

---

## 5. Acceptance

1. **All 26 slides classified**, with the design-seat read verified or corrected. Corrections evidenced, not asserted.
2. The **not-in-deck list** reported.
3. **No figure rebuilt. No deck edited.** That is Task J.
4. Bundle contains **small tables and figures only** — never the parquet, never a raster.
5. README in **plain language**: no F-numbers, no database view names, no file paths in prose.
6. The **four questions** included verbatim.
7. **F6's 9/0/0 flagged as requiring ratification**, not stated as settled.
8. Every figure caption in the bundle that carries a plot-support number says **"at site scale (1 ha, any-water rule)"**; census numbers say **"per 25 m pixel"**. Never mixed.
9. Branch-and-PR, **held**.

## 6. Handoff

- **STOP after Gate I.1.** Report the table; wait.
- Ship the stocktake to chat as a table, not prose.
- Change report → `docs/change_reports/taskI_<date>.md`.

## 7. Open — do not guess

- **Slide 23** has no data figure in the extract. Is it concept-only, or is a figure missing?
- **Slides 14–17** name four paddocks (Bala 28ca, Bala 29ca, Dinan 8, Dinan 10) of 21. **Report which 21 exist and whether the per-paddock set is complete** — the deck says "Per-paddock versions for all 21 paddocks are in the accompanying folder."
- **Slide 18** promises *"A per-paddock version of this two-colour map is the next figure to build from the pixel data."* **Report whether it exists.** Note the per-paddock coverage/N guard is still an open requirement.
