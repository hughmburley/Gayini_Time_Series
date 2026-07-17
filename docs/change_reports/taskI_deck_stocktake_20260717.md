# Task I · Gate I.1 — deck stocktake

*Design-seat audit, 17 July 2026. Deck: `docs/Gayini_Veg_samples.pptx`. Reference: `docs/Gayini_established_data_facts.md` (§9, §10 settled). Branch `tier2i-deck-stocktake` off `main`. **Report-and-stop — no figure rebuilt, no deck edited.***

---

## Headline correction: the deck is **36 slides, not 26**

Both the task message and the spec say "26 slides." The file is genuinely **36** — verified three ways: 36 `slide*.xml` files, 36 `notesSlide*.xml`, 36 `<p:sldId>` entries in `presentation.xml`, and the display order matches file order 1→36.

The design seat's read (spec §2) maps **exactly and correctly onto slides 1–26** — every title matches. **Slides 27–36 were not classified at all** because the deck was thought to end at 26. Those ten are not filler: they carry the A/B summary hedge, the dashboards (held at the gate per CLAUDE.md), the "set-aside" logic, the open-questions ask, and the closing "run the rebalanced sampling" ask — several of which change under the census.

---

## Full classification — all 36 slides

Classes: **OK** (census changes nothing) · **LABEL** (number correct, needs support/scope label) · **RESTATE** (number/claim changes) · **DEAD** (cancelled work) · **SUPERSEDED** (better evidence exists) · **FRAME** (depends on a structural decision Adrian may change).

| # | Slide | Class | Why / correction |
|---|---|---|---|
| 1 | Title · two questions | **OK** | No provisional/sampling language. Design-seat "OK?" resolved → OK. |
| 2 | Two questions guiding the analysis | **RESTATE** | The middle of three method pillars — "Areas near the plots / the country around each monitoring site" — **names the retired near-plot design**. Under the census it becomes "every pixel on the farm": a stronger claim, and a different one. Not a wording nuance — the slide describes an approach that no longer exists. |
| 3 | How the monitoring is set up | **OK** | Concept (plots across pixels; each community spans a wetness range). |
| **4** | Four communities, driest→wettest | **LABEL** | Big numbers **9 / 22 / 50 / 44** (plots 16/19/22/9 = 66). Correct at **plot support**; unlabelled. Census is 6.08 / 12.91 / 27.99 per 25 m pixel. **C10** — add "at site scale (1 ha, any-water rule)". Do **not** swap in census numbers. |
| 5 | How we tell if a pixel is under water | **OK** | Method description. The caveat "years with too little coverage are set aside" still reads true (stack-wide `valid_count` runs 22–35). *Strengthening footnote available:* every **mapped** census pixel kept all **35/35** years — none were set aside. |
| 6 | Definition of flood frequency | **OK** | Concept. |
| **7** | Has flooding changed over 35 years? (F2) | **SUPERSEDED** | "share of the **66 plots** that flooded that year." The claim (big swings, no drift) is **correct and confirmed**, but the census **per-year cut runs 0.04% (2006) → 84.67% (2022)** across 988,831 pixels — a ~2,000× swing, far stronger, and **not in the deck**. |
| **8** | The whole record at a glance (F3) | **LABEL** | 66 plots × 35 years heatmap. Plot support — needs the site-scale label. |
| **9** | Flooding differs strongly with veg type (F4) | **LABEL** | White diamonds **9 / 22 / 50**, Woodland 44. The shipped F4. **C10** — label, do not rebuild. Replacing 9/22/50 with census 6/13/28 under the same claim is the exact C10 error already made once. |
| **10** | Comparing like with like (F5 concept) | **DEAD** | Describes the near-plot stratified sampling design. Task F cancelled 15 Jul (census instead). |
| **11** | The sampling laid over the flood map | **DEAD** | Slide is *about* the sample points → dead. (The flood-frequency **surface** underneath is still valid; the dots are not.) |
| **12** | Stratum coverage / sampling density | **DEAD** | The density argument (2.7 pts/1,000 ha → "wet end is provisional") is the problem the census dissolves. **TRAP HELD:** "two-thirds of the mapped farm" is **correct** — 717,629 / 1,080,157 = **66.44% of mapped**. Do not "fix" it. |
| **13** | Proposed fix: proportional sampling, repeated | **DEAD** | *"The ask — this is what we'd like your approval to run."* ~100 Aeolian / 270 Riverine / 1,000 Inland, floor 50, repeat 100+. **Adrian answered 15 Jul: census.** The superseded ask. |
| **14** | Flood frequency — Bala 28ca | **LABEL\*** | \***Rationale corrected:** not a support label — the flood-frequency **surface is valid and its numbers do not change**. What is dead is the **sample-point overlay** (as on slide 11), to be stripped in Task J. |
| **15** | Flood frequency — Bala 29ca | **LABEL\*** | Same. *Plus enrichment:* the "deep blue blob … lake bed" is now characterised — **346.9 ha, 91.4% inundation** (facts §9). |
| **16** | Flood frequency — Dinan 8 | **LABEL\*** | Same — surface valid, dead sample-dot overlay. |
| **17** | Flood frequency — Dinan 10 | **LABEL\*** | Same. |
| **18** | Checkerboard concept (2 colours) | **FRAME** | The staircase: bands are not cross-comparable (Aeolian's wettest ≈ 5 yr/35 > Inland's driest ≈ 3 yr/35); grey "woodland and minor units" are the **wettest ground on the property**. *§7 answered:* the promised per-paddock version **now exists** — see below. |
| **19** | Checkerboard mapped across the farm | **FRAME** | Same frame dependency. Claim "all 21 paddocks in the folder" — **true for the checkerboard** (21 `C1_veg_regime_paddock` figures exist). |
| 20 | Three kinds of trend (F6 concept) | **OK** | Concept. |
| **21** | Is the amount of flooding trending? (F6 data) | **RESTATE** | "8 of 9 … only the driest Riverine shows an episodic jump … thinly sampled, so provisional." → **9/0/0, census; the whole caveat is gone.** |
| **22** | No clear trend — so far…? | **RESTATE + DEAD** | 3×3 grid: Riverine driest = "Episodic jump" → **No trend**. Three hedges die at once ("provisional", "thinly sampled", "the proposed rebalanced sampling … test it properly"). Kingsford/Kreibich "In context" paragraph survives. |
| 23 | Where recent years sit vs long-run average | **OK** | *§7 answered:* **concept-only** — no embedded figure (`<p:pic>`=0), built from text + a blue/red legend. Not a missing figure. Feeds the dashboard gauges; the "snapshot, not a trend" framing is reinforced by the census (F9 retired). |
| 24 | F7 response by community | **OK** | Per-plot lag analysis, stays on the per-plot method by design (Task H §2). r 0.17 / 0.26 / 0.42. |
| 25 | F7 lag profile (~3 months) | **OK** | Per-plot. Unaffected. |
| 26 | F7 strata panel | **OK** | Per-plot correlations. *Minor:* the 3×3 community×wetness **layout** shares the frame; the r-values are plot-based and do not change. |
| **27** | Two clear answers (A/B summary) | **RESTATE** | Carries the same **"provisional … the wettest, largest areas are thinly sampled"** hedge that dies by construction under the census. The finding ("no clear trend") survives — it strengthens to 9/0/0. |
| 28 | Site dashboard — GA_019 (Inland · wet) | **LABEL** | Per-**site** (1 ha) — plot support; gradient panel places it on 9/22/50. *Completeness:* claims "all 66 sites in the folder" — **5 built** (`D2_site_GA_*`). Held at the gate per CLAUDE.md. |
| 29 | Site dashboard — GA_032 (Aeolian · dry) | **LABEL** | Same; completeness as above. |
| **30** | Paddock dashboard — Bala 28ca | **FRAME** | Built on the **checkerboard** (the 9-cell frame). *Completeness:* claims "all 21 paddocks" — **4 built** (`D1_paddock_*`). |
| **31** | Paddock dashboard — Dinan 8 | **FRAME** | Same; completeness as above. |
| **32** | Stratum dashboard — Inland · wettest | **RESTATE + FRAME** | "carrying its **provisional** trend verdict / no trend detected so far (provisional)" → ratified 9/0/0; and the stratum **is** the 9-cell frame. *Completeness:* claims "all nine strata" — **3 built** (`D3_stratum_*`). |
| **33** | Stratum dashboard — Aeolian · driest | **RESTATE + FRAME** | Same. *Note:* this is the **Aeolian low** stratum — its "no trend" is **vacuous** (100% never-flooded, flat-zero series; facts §9). "Provisional" is doubly wrong here. |
| 34 | What we've set aside for now | **OK** | "A flood-prediction map … only worth building if flooding were trending. Since it isn't, we don't force one." The census **confirms and strengthens** this (9/0/0). Claim unchanged. |
| **35** | Open questions (3 to confirm) | **RESTATE** | Q1 "compare each community's driest/middle/wettest spots **near the plots**" — the census already superseded this (whole-farm, not near-plot); its premise is dead. Q2 (veg groups) still live. Q3 (report no-change vs force a prediction map) still live and now answered. |
| **36** | Summary | **RESTATE + DEAD** | "**run the rebalanced sampling** (proportional, floored, repeated 100+ times)" = the cancelled Task F ask → **DEAD**. "no clear trend so far (**provisional**)" → RESTATE (9/0/0, caveat gone). |

\* Slides 14–17: kept under **LABEL** for the tally per the design seat, but the needed change is **overlay removal (dead sample dots), not a support label** — the flood-frequency surface and its numbers are unchanged.

### Count by class

| Class | n | Slides |
|---|---:|---|
| **OK** | 10 | 1, 3, 5, 6, 20, 23, 24, 25, 26, 34 |
| **LABEL** | 9 | 4, 8, 9, 14, 15, 16, 17, 28, 29 |
| **RESTATE** | 8 | 2, 21, 22, 27, 32, 33, 35, 36 |
| **FRAME** | 4 | 18, 19, 30, 31 |
| **DEAD** | 4 | 10, 11, 12, 13 |
| **SUPERSEDED** | 1 | 7 |
| **Total** | **36** | |

*Multi-class (secondary in notes): 22 (+DEAD), 32 (+FRAME), 33 (+FRAME), 36 (+DEAD), 15 (+lake enrichment).*

---

## What is NOT in the deck but should be

All five in the spec confirmed present in facts §9 and absent from the deck; two more added.

1. **Per-year cut: 0.04% → 84.67%, ~2,000× swing, no drift** (facts §9). The clearest flood-pulse evidence in the project — and it predates none of the deck. Strongest single addition.
2. **41.59% of Aeolian never flooded once in 35 years** — the driest community has no low-end wetness gradient, and **Aeolian low's "no trend" is trivially true** (flat-zero series). Deck slide 33 currently sells this as a "provisional" finding.
3. **Absolute flood zones** (never / <1:10 / 1:10–1:4 / 1:4–1:2 / >1:2) — comparable **across** communities, unlike the terciles. The candidate answer to Q3.
4. **The floor is ~97% dead at the median**, but **~4,300 ha (≈5% of the farm) has a majority-green floor** — a refugia map, probably better than the median (facts §9).
5. **The 40-point false-positive rate: 54.1%** (1,000 draws, nominal 5%). The single number that retires sampling and converts 8/1/0 → 9/0/0.

Added:
6. **The census pixel-support triple itself — 6 / 13 / 28** (Aeolian / Riverine / Inland) — is nowhere in the deck; only plot support 9/22/50 appears. This is the *other correct answer* Adrian must choose between (README Q2).
7. **The staircase table** (Aeolian wettest band < Inland driest) as data, not just concept — the evidence behind the FRAME decision (README Q3).

---

## §7 — the three "do not guess" items, answered from the filesystem

1. **Slide 23** — **concept-only.** No picture element in the slide XML (`<p:pic>`=0, `<a:blip>`=0); it is a text block plus a drier/wetter/same colour legend. No figure is missing.

2. **The 21 paddocks & per-paddock completeness.** The canonical **21** paddocks are the `C1_veg_regime_paddock_*` set: *Bala 6, 12, 17, 19, 20, 21, 23, 26ca, 28ca, 29ca, 8/11; Dinan 1, 3, 6, 8, 10, 12; Mara 7, 8, 13, 21.* Completeness by deliverable:
   - **Per-paddock checkerboard** (`C1_veg_regime_paddock`): **21/21 — complete.**
   - **Per-paddock flood-frequency** (`F5c_paddock`, what slides 14–17 show): **4/21** — only Bala 28ca, Bala 29ca, Dinan 8, Dinan 10.
   - **Paddock dashboards** (`D1_paddock`): **4/21** — deck slide 30 says "all 21 … in the folder."
   - **Site dashboards** (`D2_site`): **5/66** — deck slide 28 says "all 66."
   - **Stratum dashboards** (`D3_stratum`): **3/9** — deck slide 32 says "all nine."
   - *The dashboards are held at the gate per CLAUDE.md; the deck's "all N in the folder" claims outrun what is built (only the checkerboard set is actually complete). Flagged, not a Task I fix.*

3. **Slide 18's promised per-paddock checkerboard** — **it exists.** Slide 18 says it is "the next figure to build"; since deck authoring, the `C1_veg_regime_paddock_*` set (21 figures) was built, so slide 19's "all 21 paddocks in the folder" is now supported. The per-paddock coverage/N guard remains an open requirement per §7 — not verified here.

---

## Traps held (did not "fix")

- **Slide 12** "two-thirds of the mapped farm" — correct as written (66.44% of **mapped**); the C1 instinct would wrongly edit it.
- **Slide 9** 9/22/50 — correct at plot support; replacing with census 6/13/28 under the same claim is the C10 error. Left alone.

## Status

Gate I.1 complete. **No deck edited, no figure rebuilt.** F6's 9/0/0 remains **unratified** — it is the purpose of the I.2 bundle, not an input. **STOP** — Gate I.2 (bundle assembly) awaits review of this stocktake.
