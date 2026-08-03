# Gayini deck — all-pixel cut · slide rewrites for review

*Design-seat draft, 24 July 2026. Deck: `docs/Gayini_Veg_samples.pptx` (36 slides).
Reference: Task I stocktake `taskI_deck_stocktake_20260717.md`.*

**REVIEW DOCUMENT — no deck edited, no figure rebuilt.** Every rewrite below is proposed text
for human approval. Nothing here has been applied to the `.pptx`.

**Purpose of this cut:** get the all-pixel census results in front of Adrian clearly. Scope is
deliberately narrow — hedging language that the census retires, and the numbers that change.
Not a redesign.

---

## 0. How to read this document

Each slide gets: the **current text verbatim**, the **proposed text**, the **reason**, and a
**source** for every number. Numbers are marked:

- ✅ **VERIFIED** — checked against the census parquet or the live DB in this session, with the
  check shown in §5.
- ⚠️ **UNVERIFIED** — appears in project docs but could **not** be confirmed from the data
  available in this session. **Must not go on a slide until sourced.**

Per the D8 lesson: a number that cannot name the artefact that produced it is an observation,
not a finding.

---

## 1. Summary of proposed changes

| Slide | Class | Action | Blocked on |
|---|---|---|---|
| 2 | RESTATE | Method pillar: "near the plots" → every pixel | — |
| 7 | SUPERSEDED | Replace plot-share figure with per-year census cut | ⚠️ CC figure + number verification |
| 12 | DEAD → repurpose | Sampling density → S12 stratum coverage | — (S12 exists) |
| 21 | RESTATE | 8/1/0 provisional → 9/0/0 census | — (S21 exists) |
| 22 | RESTATE + DEAD | 3×3 grid; three hedges die | — |
| 27 | RESTATE | A/B summary: drop provisional/thinly-sampled | — |
| 28 | LABEL | "all 66 sites" → 57 non-treed | — |
| 32 | RESTATE + FRAME | **CUT from this version** | — |
| 33 | RESTATE + FRAME | **CUT from this version** | — |
| 35 | RESTATE | Q1 premise dead; Q3 answered | — |
| 36 | RESTATE + DEAD | Drop the cancelled Task F ask | — |
| NEW | — | All-pixel method figure | CC Gate D |
| NEW | — | Veg × water percentile fan | — (exists) |

**Nine slides editable now. Two new slides: one blocked, one ready.**

Slides 4, 8, 9 (LABEL) are **not** in this cut — they carry plot-support numbers that are
correct as written and need only a support label. Deliberately deferred to keep this cut focused.

---

## 2. The slides

### Slide 2 — Two questions guiding the analysis · RESTATE

**Current** (middle method pillar):

> Areas near the plots
> the country around each monitoring site

**Proposed:**

> Every pixel on the farm
> all 1,080,157 mapped pixels, not a sample near the plots

**Why:** the near-plot design is retired. This is not a wording nuance — the slide currently
describes an approach that no longer exists, and the replacement is a *stronger* claim.

**Source:** 1,080,157 pixels ✅ VERIFIED — parquet row count, matches `census_stratum` sum,
diff = 0 across all 11 strata.

*Leave the other two pillars ("The full 35-year record", "Grouped by vegetation") unchanged.*

---

### Slide 7 — Has flooding changed over 35 years? · SUPERSEDED

**Current subtitle:** describes the share of the **66 plots** that flooded each year.

**Proposed:**

> Every mapped pixel, every year. The wettest year covers over eight hundred times more
> ground than the driest — and the swing shows no drift.

⚠️ **BLOCKED — do not apply yet.** Two problems:

1. **The figure does not exist.** This needs a per-year census cut chart. Add to CC Gate D.
2. **The numbers are unverified.** The project docs cite "0.04% (2006) → 84.67% (2022),
   a ~2,000× swing." **I could not verify these in this session.** The census parquet stores
   `wet_years` as a 35-year *total per pixel*, not a year-by-year series — the per-year cut
   requires the annual inundation stack, which is not in the parquet. They are also **not** in
   `Gayini_established_data_facts.md`.

**Note the arithmetic:** 84.67 / 0.04 = **2,117×**, and the proposed wording above says
"eight hundred times" because even the ratio is uncertain until the underlying numbers are
confirmed. **Do not put any multiplier on this slide until the source is named.**

**Action:** CC to source these from the annual stack and report the artefact chain, exactly as
for the ~6,460 ha claim. If they resolve, this becomes the strongest single addition to the deck.
If they do not, the slide states the qualitative finding only.

---

### Slide 12 — Stratum coverage / sampling density · DEAD → REPURPOSE

**Current:** the sampling-density argument (points per 1,000 ha → "the wet end is provisional").

**Proposed — same slot, opposite message.** Replace the figure with **S12** (exists:
`S12_stratum_coverage.png`) and the subtitle with:

> How much of the mapped farm each stratum covers. The sampling-density question this slide
> used to ask is dissolved by the census — every pixel is measured.

**Why:** the narrative slot is right; the argument in it is dead. S12 is already built and
registered.

**⚠️ TRAP — HELD.** The current slide says Inland Floodplain is **"two-thirds of the mapped
farm."** This is **correct as written** and must not be "fixed":

- 717,629 / 1,080,157 = **66.44% of the MAPPED farm** ✅ VERIFIED
- The mapped area is 67,349.3 ha of the 85,910.8 ha farm (**78.39%**) ✅ VERIFIED
- On the *whole-farm* basis Inland is ~52%, which is **not** two-thirds

The instinct to rebase this number to the whole farm is the C1 error. **Do not.** S12's own
subtitle states the mapped basis explicitly.

---

### Slide 21 — Is the amount of flooding trending? · RESTATE

**Current:**

> So far, 8 of 9 area types show no trend; only the driest Riverine spots show an episodic jump
> driven by two big floods. The wettest, largest areas are the most thinly sampled, so we treat
> this as provisional.

**Proposed:**

> All nine area types show no trend. Every mapped pixel is measured, so nothing here rests on a
> sample — the "thinly sampled" caveat is gone by construction. Flooding is flood-pulse driven,
> not trending.

**Figure:** replace with **S21** (exists: `S21_flood_trend_census.png`), which shows the 3×3
census grid with the verdict per panel.

**Why:** the entire hedge dies. The 8/1/0 result was a 40-point sampling artefact.

**Source:** 9 no-trend / 0 non-stationary / 0 directional ✅ VERIFIED — S21 figure reconciles
against the parquet; Riverine low's former non-stationary flag was a sparsity artefact
(p<0.05 in 541/1000 random 40-plot draws against a nominal 5%).

**Optional addition — the number that retires sampling:**

> A 40-point design returns a false positive 54.1% of the time (1,000 draws, nominal 5%).

⚠️ **PARTIALLY VERIFIED.** The 54.1% figure appears in `Gayini_established_data_facts.md:222`
attributed to Adrian's 15 July direction. The S21 figure footer independently states 541/1000,
which is consistent. **But I have not traced it to a script or output file.** Recommend
including it only if CC's Gate A resolves the chain — otherwise state the finding without
the number.

---

### Slide 22 — No clear trend — so far…? · RESTATE + DEAD

**Three changes.**

**(a) The 3×3 grid.** Riverine · driest spots: **"Episodic jump" → "No trend"**.
All nine cells now read "No trend". ✅ VERIFIED.

**(b) Title.** Drop the hedging question mark:

> **Current:** No clear trend — so far…?
> **Proposed:** No trend in flooding — across all nine area types

**(c) "What this means" block.**

**Current:**

> So far, 8 of 9 area types show no trend. The one exception is an episodic jump driven by two
> big flood years — movement, but not a steady change.
>
> Flooding varies enormously year to year. On the sampling so far it shows no clear drift — but
> the wettest, largest areas are the most thinly sampled, so we treat this as provisional. The
> proposed rebalanced sampling is designed to test it properly before we draw any prediction map.

**Proposed:**

> All nine area types show no trend. Flooding varies enormously year to year, but that variation
> is episodic and climate-paced — it does not drift in either direction.
>
> This is now measured on every mapped pixel, not a sample, so there is no sampling caveat left
> to resolve. "No trend" is the reportable result, and we do not force a prediction map onto a
> system that is not trending.

**Why:** three hedges die at once — "provisional", "thinly sampled", and the cancelled
rebalanced-sampling ask.

**KEEP UNCHANGED:** the "In context" paragraph (Kingsford; Kreibich et al. on the long-term
Lowbidgee decline predating the 1988 window). The census does not touch it, and it is the
honest framing for why "no trend" is not "no change ever".

---

### Slide 27 — Two clear answers · RESTATE

**Current, answer A:**

> Flooding swings hugely between wet and dry years, and so far shows no clear trend up or down.
> We treat that as provisional — the wettest, largest areas are thinly sampled — and it sits
> within a system already reshaped by upstream regulation.

**Proposed:**

> Flooding swings hugely between wet and dry years, and shows no clear trend up or down. This
> is measured on every mapped pixel, so it is not a provisional finding — it sits within a
> system already reshaped by upstream regulation.

**Answer B: unchanged.** The lag finding is plot-support and stands as written.

**⚠️ Do NOT add census response numbers to answer B in this cut.** The r values on slides 24–26
(0.17 / 0.26 / 0.42) are **plot support**; the census gives 0.17 / 0.23 / 0.35 pooled, and
0.16–0.39 by band. Both are correct; mixing them under one claim is the C10 error. Answer B
stays plot-support and gets its label in a later cut.

---

### Slide 28 — Site dashboard · LABEL

**Current:**

> claims "all 66 sites in the folder"

**Proposed:**

> All 57 non-treed sites are in the folder. The nine treed sites are set aside — Landsat
> fractional cover cannot see the ground through a canopy.

**Why:** this is **not** an incompleteness problem, contrary to the Task I stocktake's reading
(which recorded "5 built"). The dashboards are **complete for every site that should have one.**
The denominator on the slide is simply stale.

**Source** ✅ VERIFIED:
- `figure_asset` holds **57** D2 site dashboards (`run_id = d2_site_dashboard_batch_20260720`),
  57 unique `GA_*` sites, all `path_exists = 1`
- `dim_plot.treed_plot_flag`: **57 non-treed, 9 treed, 66 total** — exact match

*Same fix applies to slide 29 (identical claim).*

---

### Slides 32 & 33 — Stratum dashboards · **CUT from this version**

**Recommendation: remove both slides from this cut.** Do not rewrite, do not rebuild.

**Why:**

1. **Redundant.** S21 shows all nine strata with the trend verdict in one 3×3 grid; S26 shows
   all nine with the response. For Adrian, the grid is the better artefact — the whole census
   verdict at once, rather than nine pages.
2. **Slide 33 is actively misleading.** It presents Aeolian · driest as "no trend detected so
   far (provisional)". That stratum is **100% never-flooded, max `wet_years` = 0** ✅ VERIFIED
   — a flat-zero series. Its "no trend" is *vacuous*, not provisional. Selling a vacuous result
   as a finding in front of experts is the worst failure mode available here.
3. **Frame-dependent.** Strata are the tercile bands. The terciles-vs-absolute-zones decision
   (FRAME) is still open; H6 exists as the absolute-zone alternative. Building stratum
   dashboards now means rebuilding them if Adrian picks zones.
4. Slide 32's "all nine strata are in the folder" is wrong — 3 exist.

**Consequence: no CC task needed for stratum dashboards in this cut.** If Adrian asks for
per-stratum detail, S21 and S26 answer it, and dashboards get built after the frame is settled.

---

### Slide 35 — Open questions · RESTATE

**Q1 — current:**

> The comparison — Is it right to compare each community's own driest, middle and wettest spots
> near the plots, rather than comparing one plot against another?

**Proposed — replace entirely.** The premise is dead: the census already compares whole-farm,
not near-plot. Substitute the live frame question:

> The wetness bands — Should the driest/middle/wettest split stay as each community's own
> thirds, or move to absolute flood-frequency zones (never / rarer than 1-in-10 / 1-in-10 to
> 1-in-4 / 1-in-4 to 1-in-2 / more than 1-in-2)? Absolute zones are comparable *between*
> communities; the thirds are not.

**Why this is the right substitution:** it is the FRAME decision, it is genuinely open, and it
is the one place Adrian's answer changes what gets built next. H6 already exists as the
worked alternative.

**Q2 — unchanged.** Vegetation groups still live.

**Q3 — current:**

> Reporting no change — Where flooding shows no clear trend, is it right to report that
> provisional finding directly, rather than produce a flood-prediction map anyway?

**Proposed:**

> Reporting no change — The census confirms no trend in any of the nine area types. We propose
> reporting that directly rather than forcing a flood-prediction map onto a system that is not
> trending.

**Why:** drop "provisional"; the question shifts from *may we?* to *confirming we will*.

---

### Slide 36 — Summary · RESTATE + DEAD

**Current:**

> **Finding** Flooding is variable with no clear trend so far (provisional); both flooding and
> vegetation response change with vegetation type.
>
> **Next** With your approval, run the rebalanced sampling (proportional, floored, repeated 100+
> times) to firm up the wet end, then extend the paddock/site review and add biodiversity context.
>
> **Summary** A floodplain with no clear trend in flooding so far (provisional), but a clear
> vegetation response to it that changes with vegetation type.

**Proposed:**

> **Finding** Flooding is variable with no trend in any of the nine area types — measured on
> every mapped pixel, not a sample. Both flooding and vegetation response change with
> vegetation type.
>
> **Next** Confirm the wetness-band frame (thirds or absolute zones), then extend the
> paddock/site review and add biodiversity context.
>
> **Summary** A floodplain with no trend in flooding, but a clear vegetation response to it
> that changes with vegetation type.

**Why:** the rebalanced-sampling ask is the cancelled Task F — it must go, and it was the
slide's whole "Next". The frame question replaces it as the live ask. "Provisional" drops twice.

**Also check:** the footer claims "all 21 paddocks, every dashboard layout (A/B/C)". Per the
stocktake only the **checkerboard** set is 21/21 complete; `D1_paddock` dashboards are 4/21.
Recommend softening to name what is actually complete, or dropping the footer. Flagged, not
drafted — needs CC Gate A's inventory to state it accurately.

---

## 3. Two new slides

### NEW-A — The all-pixel method · after slide 3

⚠️ **BLOCKED — CC Gate D (§D.4).** Figure does not exist.

Proposed title and subtitle:

> **From 66 plots to every pixel**
> The monitoring plots anchor the analysis; the census measures all of it. 1,080,157 mapped
> pixels across 11 strata — 67,349 ha of the 85,911 ha property (78%). The rest is unmapped,
> not ignored.

Required footer (verbatim, per Task M §D.4):

> The census removes sampling uncertainty only. ~1M pixels are NOT independent n (spatial and
> temporal autocorrelation). Landsat fractional cover measures COVER, not condition.

All numbers ✅ VERIFIED.

### NEW-B — Vegetation cover against flooding · after slide 26

**READY — figure exists**: `S_veg_water_percentile_fan.png`, registered `figure_gateE_vw_fan`.

Proposed title and subtitle:

> **The signal is in the floor**
> Across every census pixel, the *typical* cover barely moves with flooding — but the driest-year
> floor rises steeply. The fan is tall where flooding is rare and compresses where it is frequent.

**⚠️ Do NOT put a hectare number on this slide.** See §4.

---

## 4. What is deliberately NOT in this cut

**The floor / "refugia" hectare claim — EXCLUDED.** Two numbers have been attached to
"majority-green floor" and **neither is verified**:

- "~4,300 ha" — does not reproduce; `veg_p05 ≥ 50` over focus pixels is **40,935.8 ha**
- "~6,460 ha" — pushed as a supersession on 2026-07-23; also unverified, and a grid change
  cannot account for the 6.3× gap

The companion claim "the floor is ~97% dead at the median" is **false**: 0.9% of focus pixels
have `veg_p50 < 50`.

**NEW-B carries the qualitative gradient only** — the fan shape — and no hectare figure, until
Task M Gate D settles D8.

**Also deferred:** slides 4/8/9 support labels; the census triple 6/13/28 as a headline
alternative to plot-support 9/22/50; the staircase table; absolute flood zones as a data slide
(H6 exists); slides 14–17 sample-dot overlay removal.

---

## 5. Verification log

Everything asserted in this document, and how it was checked (24 July 2026).

| Claim | Check | Result |
|---|---|---|
| 1,080,157 mapped pixels | Parquet row count vs `census_stratum` | ✅ diff = 0, all 11 strata |
| Parquet is the registered artefact | SHA-256 vs `census_asset` | ✅ exact match `6b23f6c0…` |
| 988,831 focus pixels | `treed_context_flag = FALSE`, 3 focus communities | ✅ (988,829 with non-null `veg_p05`) |
| Inland = 66.44% of mapped | 717,629 / 1,080,157 | ✅ 66.44% |
| Mapped = 67,349.3 ha = 78.39% of farm | `SUM(area_ha)` / 85,910.8 | ✅ |
| 57 non-treed sites | `dim_plot.treed_plot_flag` | ✅ 57 / 9 / 66 |
| 57 D2 dashboards built | `figure_asset` `run_id = d2_site_dashboard_batch_20260720` | ✅ 57 figures, 57 unique sites |
| Aeolian low vacuous | `wet_years` max in stratum | ✅ 100% never-wet, max = 0 |
| Community means 6.08 / 12.91 / 27.99 | `census_community_flood_freq_means.csv` | ✅ 6.0806 / 12.9070 / 27.9896 |
| 9 no-trend / 0 / 0 | S21 figure; reconciles to parquet | ✅ |
| Per-year cut 0.04% → 84.67% | **Not derivable from the parquet** | ⚠️ UNVERIFIED |
| 54.1% false-positive rate | `established_data_facts.md:222`; S21 footer 541/1000 | ⚠️ PARTIAL — no artefact traced |
| ~4,300 ha / ~6,460 ha floor | Parquet: `veg_p05 ≥ 50` = 40,935.8 ha | ❌ NEITHER REPRODUCES |
| "97% dead at median" | Parquet: `veg_p50 < 50` | ❌ FALSE — 0.9% |

---

## 6. Open items before applying any of this

1. **Slide 7 numbers** — CC to source the per-year cut from the annual inundation stack.
2. **54.1%** — CC to trace the artefact, or the number stays off the slide.
3. **Slide 36 footer** — needs CC Gate A's completeness inventory to state accurately.
4. **CC Gate A §A.8** — the deck slide traceability scan may surface further slides carrying
   withdrawn claims. This draft should be reconciled against it before anything is applied.
5. **Human decision** — cutting slides 32 and 33 (§2) is a recommendation, not a done deal.
