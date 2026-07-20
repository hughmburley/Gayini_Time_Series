# Gayini — sequential task list (from Adrian, 15 Jul 2026)

Built from `Gayini_Adrian_comments_20260715.xlsx`. Item numbers below (#n) refer to that table.

## Framing

**Target = two deliverables.** (1) Updated database(s). (2) Reports for all sites. The science story is important but **secondary right now** — it follows the deliverables, it doesn't lead them.

**Additive only.** Nothing already built is removed. The sub-sampling approach (Task F: proportional allocation + Monte Carlo) is **archived, not deleted** — it may be used in future, and the mechanics are already merged to `main` where they sit harmlessly uncalled. What changes is **order and emphasis**, not the content of the repo.

**Out of scope.** The gauge × RS mixed-effects / residual model (#12) is research-only — parked, not scheduled. (The reference chase for it is closed; see P0.3.)

---

## The key sequencing fact

**The all-pixel work splits into two tracks, and one of them needs no new data.**

- **Track A — inundation-only (#1, #2, #24).** Census flood frequency per veg × wetness class needs the annual stack (`annual_wet_any/valid_any_1988_2023.tif`, 35 layers) intersected with `veg_regime_class_8058.tif`. **Both already exist.** This is a zonal statistic, not a new build — it can start immediately and is cheap.
- **Track B — anything involving vegetation (#3, #4, #8, #9, #22).** Blocked on the veg percentile raster (#6), which does not exist. Confirmed: every raster-builder in `scripts/03_inundation_products/` makes *inundation* rasters; the fractional-cover pipeline is a **plot extraction**, not a farm-wide raster.

So the census headline — "flood frequency per class, all pixels, caveat gone" — is reachable **before** the big raster build. That's the order below.

---

## Phase 0 — Quick wins (days, nothing gated)

| ID | Task | Item | Effort |
|---|---|---|---|
| P0.1 | Dashboard label fix: "Total vegetation (green cover)" → **"Total veg (green + dead)"**. It includes dead veg. | #21 | S |
| P0.2 | Archive the Task F spec: move to `docs/archive/`, add a `SUPERSEDED-BY` header pointing at this plan. **Do not delete.** Code stays on `main` untouched. | — | S |
| P0.3 | Send Adrian the Jason Evans answer: it's RESTREND — Evans & Geerken (2004), Burrell/Evans/Liu (2017) TSS-RESTREND, Burrell et al. (2020); code on CRAN (`TSS.RESTREND`) + GitHub. No inquiry needed. Closes his action even though the analysis is parked. | #13 | S |
| P0.4 | **Recon (gates Phase 3):** do we hold farm-wide fractional-cover source rasters, or only plot-window extracts? Determines whether #6 is a processing job or a data-acquisition job. | #6 | S |
| P0.5 | Add a census concept figure **alongside** (not replacing) the F5 sampling concept — the F5 figure now documents an archived method, so it stays as provenance and gains a sibling. | #1 | M |

## Phase 1 — Infrastructure decision (early; everything downstream inherits it)

| ID | Task | Item | Effort |
|---|---|---|---|
| P1.1 | **Decide the census store.** ~240k pixels × 35 yrs × N variables will not fit the results-DB pattern. Separate SQLite vs parquet vs CSV. Decide before extraction, not after. | #11 | M |
| P1.2 | **Settle `MIN_VALID_COVERAGE` (old Q3a).** Still live and now *more* important — a census has pixels with widely varying valid-year counts. Default 40; confirm with Adrian. | — | S |
| P1.3 | Register the new products in the DB / asset registry as they land (this is Deliverable 1). | #11 | M |

## Phase 2 — Track A: all-pixel inundation (no new raster needed)

| ID | Task | Item | Effort |
|---|---|---|---|
| P2.1 | **Census veg × wetness matrix (p18):** flood frequency per class using every pixel, per year. Zonal stats on existing rasters. | #1 | M |
| P2.2 | **F6 on census (p21):** systematic vs stochastic, all pixels. Removes the "thinly sampled / provisional" caveat *by construction*. | #2 | M |
| P2.3 | **Per-year cut:** analyse each year rather than only whole-record aggregates. Cheap, and likely informative given the episodic signal. | #24 | M |

> **Expectation management for P2.2.** A census removes *spatial* sampling uncertainty; it adds **no temporal power**. Systematic-vs-stochastic is a question about 35 annual observations and stays one no matter how many pixels are measured per year. Expect the verdict to **harden to the same answer** (episodic, climate-paced) with the caveat gone — that's a real gain, but it is not a new answer. Worth stating to Adrian before the run, not after.

## Phase 3 — Display convention (blocks every census figure)

| ID | Task | Item | Effort |
|---|---|---|---|
| P3.1 | All-pixel figures must **not** draw thousands of points: grey CI band around a trend, and/or heat-map / kernel-density. Ask Adrian for the examples from his own work. | #18 | M |

> Our existing sqrt-x scatter (α 0.1 + binned mean ± 95% CI) is already **halfway there** — the binned-mean-and-band layer is exactly what he's describing. What it needs is a census variant: swap the point layer for hexbin/2-D density at ~240k points. Additive: keep the plot-scale version, add the census version.

## Phase 4 — Track B: veg percentile rasters (the big build)

| ID | Task | Item | Effort |
|---|---|---|---|
| P4.1 | **Build total-veg (green + dead) percentile rasters** — 5th / 10th / 20th / 30th / 50th. Prerequisite for all of Track B. | #6 | L |
| P4.2 | **Pick one percentile and use it everywhere.** Adrian said 5/10/30 in one place and 5/10/20 in another — read as "the low percentiles, test which works". Compute several, pick the strongest relationship with inundation, then use that **one** consistently. | #9 | M |
| P4.3 | All-pixel veg vs inundation per veg × wetness class. | #8 | M |
| P4.4 | **Lag-correlation matrix on census (p25)** — our strongest result (~3-month lag) becomes a 9-cell matrix instead of per-plot medians. Answers "does the lag vary along the gradient". | #3 | L |
| P4.5 | Response-strength matrix on census (p26). | #4 | M |
| P4.6 | Dashboard scatter → chosen percentile. | #22 | S |
| P4.7 | Annualised veg series on dashboards. **Likely free** — if P4.1 produces *annual* percentile rasters, the veg series is already annual and aligns to the inundation axis by construction. | #23 | S |

**Rationale to record (#7, #10):** lower percentiles are the *floor* of the system — "when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem". This is resilience, not average condition — a genuinely different question from mean cover.

## Phase 5 — CSIRO strand (new analysis)

| ID | Task | Item | Effort |
|---|---|---|---|
| P5.1 | Acquire **HCAS 3.3** (DOI `10.25919/zhfq-1x80`) — 1988–2024, 90 m, annual. Matches our Landsat span; 2.8× finer than the ~250 m / 2004–2020 vintage behind our current LOOC-B numbers; CSIRO specifically improved riparian/wetland condition estimates, which is exactly Gayini. | #5 | M |
| P5.2 | CSIRO condition **vs inundation**, all valid pixels. | #5 | M |

> **Circularity rule (hard constraint).** Never regress LOOC-B/HCAS on ground cover — both derive from the same reflectance. Inundation is derived from a water index and is the independent axis. State this explicitly in any write-up.

## Phase 6 — Site reports (Deliverable 2)

| ID | Task | Item | Effort |
|---|---|---|---|
| P6.1 | **Build the report generator now**, with what we already have: per-site `.md`/`.html` = narrative context + dashboard. Scaffold the format and generate across all sites; leave the narrative sections as slots. | #20, #19 | L |
| P6.2 | Scale dashboards from the current 13 to **all sites** (66 plots in the spine). | #19 | M |
| P6.3 | Slot in Earnest's nearmap attribute table + NSW land-management layers when they land. **Gated — not ours.** | #14, #15, #20 | — |
| P6.4 | Change-classification layer joined to management history. **Gated on Earnest; exploratory.** | #16 | — |

> P6.1 is the deliverable and it is **mostly un-gated** — the format, the generator, and the dashboards are all ours. Only the narrative *content* waits on Earnest. Build the vessel now; fill it when the data arrives.

## Phase 7 — Writing (feeds both deliverables and the paper)

| ID | Task | Item |
|---|---|---|
| P7.1 | **Structure vs condition — the critical caveat.** The same total-veg value can mean irrigated cotton in 1995 and chenopod in 2020. A trend in cover may be a trend in *land use*, not condition. Must appear in interpretation and Limitations — and it may partly *explain* our weak/mixed veg results. | #25 |
| P7.2 | **Null-result reframe.** Adrian has pre-authorised a null as publishable and named the fallback (LiDAR/nearmap for structure). Likely paper: *"Landsat fractional cover cannot resolve management effects at this site — here's the evidence, and here's what would be needed."* Permission, not defeat. | #26 |

> Scope note on #25: it threatens **trend-in-cover** interpretations far more than it threatens the **~3-month lag**. An event-scale green-up response is much more robust to slow land-use change than a 35-year trend in cover magnitude. Our headline finding is the more defensible one — say so explicitly rather than letting the caveat swallow everything.

---

## Parked / not ours

| Item | Status |
|---|---|
| #12 Gauge × RS mixed-effects residual model (RESTREND-shaped) | **Out of scope — research only.** If ever revived: the method transfers, but rainfall is exogenous forcing whereas gauge→inundation is closer to routing, so the residual could reflect channel works, antecedent conditions, or detection error as much as management. Interpretation needs care. |
| #14, #15, #16 Earnest / nearmap / NSW land-management layers | Adrian owns — await |
| #17 LiDAR difference DEM (2009 vs 2021) | Adrian owns — may be the only direct physical evidence of intervention; we may have to build it ourselves |
| Task F sub-sampling (Scheme A, Monte Carlo) | **Archived, not deleted.** Code on `main`, uncalled. Available if a future question needs a sample rather than a census. |

## Open questions (flag — do not guess)

1. **Percentile semantics (#6 vs #9).** Is the percentile a *within-year* summary per pixel (giving an annual series — needed for the lag analysis), or an *across-series* summary per pixel (giving one value)? #9's "rather than median cover across the series" implies within-year → annual series. Confirm before building.
2. **P0.4** — do farm-wide fractional-cover source rasters exist, or only plot windows?
3. **`MIN_VALID_COVERAGE`** for the census (old Q3a).
4. **#18** — Adrian's own examples of the density/CI display convention.
5. **Scale of "all sites"** — 66 plots in the spine; is a "site" one plot, or a cluster?

## Deadline reality

The Gayini presentation is roughly a month out. Phases 0–2 and 6 are achievable in that window. Phase 4 (the veg raster build) is the long pole and may not land in time — if it doesn't, the presentation shows the **Track A census result** (which is the headline anyway: caveat gone) with the veg census flagged as in progress. Phase 5 is likewise post-presentation unless acquisition is trivial.

**Recommended order: P0 → P1 → P2 → P6.1 → P3 → P4 → P5.** Phase 6 sits early because it is the deliverable and is mostly un-gated.
