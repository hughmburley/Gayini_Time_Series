<!--
SUPERSEDED-BY: Gayini_sequential_task_list_20260715.md
               Tier2_TaskH_all_pixel_census_v2.md (the work that replaced this)
STATUS:        ARCHIVED — design note for a method that was retired before production.
ARCHIVED:      2026-07-15
-->

# ARCHIVED — the sub-sampling design was retired in favour of an all-pixel census

> **Read this header before using anything below.**
>
> **What this document is.** The design note for the stratified Monte Carlo resampling approach —
> the reasoning behind replacing F5's flat 40-points-per-stratum with a proportional-with-floor,
> ~100-draw design. It is the *argument*; `Tier1_TaskF_spatial_resampling_spec_v2.md` (also archived)
> was the *build instruction*.
>
> **Why it is archived.** Adrian's review of **15 July 2026** (`Gayini_Adrian_comments_20260715.xlsx`,
> item #1) pivoted the project from sampling to an **all-pixel census**. §1's problem statement —
> that the wet Inland Floodplain, ~66% of the farm, is sampled ~9× more thinly than the dry Aeolian
> at ~2.7 points per 1,000 ha — was **real and correctly diagnosed**. The census simply solves it by
> a different route: measure all 1,080,157 pixels and the density gradient ceases to exist.
> **Retired, not refuted.**
>
> **What survived the pivot — this is the part worth re-reading.** §3's discipline carried straight
> into Task H:
>
> - *"It does NOT buy trend-detection power. F6's test is bounded by the 35-year record."* — restated
>   verbatim in Task H H3.2. A census removes **spatial** sampling uncertainty and adds **zero**
>   temporal power. Expect F6 to **harden** to 8 no-trend / 1 non-stationary / 0 directional, not
>   change. If it changes, that is a bug.
> - *"Do not report a naive n = 1,000 confidence interval"* — the autocorrelation argument applies
>   with **more** force to a census, not less. 1,080,157 pixels are emphatically not 1,080,157
>   independent observations. This is the reasoning behind Task H's H5 display convention (#18):
>   density/hexbin surfaces and CI bands, never raw points at scale, and never a naive large-N CI.
> - §6's literature (Olofsson, Stehman; block-bootstrap Mann–Kendall / `modifiedmk`; Matalas &
>   Langbein, Yue & Wang, Hamed & Rao) remains in the reference workbook and still supports the
>   F6 temporal robustness work.
>
> **What is superseded:**
>
> | Claim here | Current status |
> |---|---|
> | §2 allocation (50 / 100–500 / 500–1,000 per draw) | **Retired.** No draws. Code lives on `main`, uncalled — see the archived Task F spec. |
> | §4 allocation trade-off (proportional vs equal large-N) | **Moot.** A census has no allocation to trade off. |
> | §7 gated on Adrian Q1 + Q3a | **Bypassed.** Q1 has no meaning without a draw universe; Q3a was reframed — the census knob is `MIN_VALID_YEARS = 25/35`, verified **non-binding** (drops 0.025%). |
> | §1 density table | Counts still correct. But see Task H correction **C1**: `census_stratum.farm_area_ha` holds the *mapped* 67,349.332 ha, **not** the farm's true **85,910.8 ha**. "~66% of the farm" for Inland Floodplain is computed against the mapped denominator. |
>
> **The approach may be used again.** If a future question needs a sample rather than a census, this
> note is the reasoning and the Task F spec is the build. Neither is deleted. Additive-only.
>
> ---
>
> *Everything below is the original document, preserved verbatim for provenance.*

---

# Gayini Sub-sampling Approach — stratified Monte Carlo resampling

*Design note for the next round of the vegetation × wetness stratified sampling (a revision of F5, feeding a re-run of F6). Purpose: replace the provisional flat-40 sample with an adequately sized, honestly quantified design, and lift the "wettest, largest areas are thinly sampled — provisional" caveat currently on the Adrian deck.*

## 1. The problem this fixes

F5 drew a flat `N_PER_STRATUM = 40` points in each of the 9 vegetation × wetness strata. Because the strata differ ~10× in area, equal allocation produced a ~9× gradient in **sampling density**, worst exactly where the area (and management relevance) is greatest:

| Community | Pixels / band | Area / band | Points (current) | Density (pts / 1,000 ha) |
|---|---|---|---|---|
| Aeolian Chenopod (dry) | ~24–27k | ~1,500–1,700 ha | 40 | ~24–27 |
| Riverine Chenopod | ~64–66k | ~4,000 ha | 40 | ~10 |
| Inland Floodplain (wet) | ~238–240k | ~14,900 ha | 40 | **~2.7** |

*(Source: `v_pixel_census_by_veg_regime` / `census_stratum`.)* The wet Inland Floodplain — ~66% of the farm — is sampled ~9× more thinly than the dry Aeolian. This is the quantified form of the deck's own caveat.

## 2. The design — repeated stratified draws (Monte Carlo)

The goal is **not** one bigger sample. It is many repeated draws, so we can *measure* how much a conclusion depends on which points happened to be drawn. Two axes:

**A. Per-draw allocation (proportional, with a floor).** Draw size scales with stratum extent, using the census pixel counts, with a minimum so small strata are not starved:

- Aeolian bands (small): **~50** points/draw
- Riverine bands (mid): **~100–500** points/draw
- Inland bands (large): **~500–1,000** points/draw

Headroom is not a constraint: even 1,000 points is <0.5% of the ~240k pixels available in an Inland band, and 50 is ~0.2% of an Aeolian band. The binding constraint is the **2 km near-plot neighbourhood** (Adrian Q1): it caps the drawable pixels in the *small, fragmented* Aeolian/Riverine patches, not in the large wet strata. So "1,000 in the big veg type" is easy; the cap risk is at the dry end — relaxing the neighbourhood radius toward community-wide sampling (a Q1 decision) removes it.

**B. Repeats (Monte Carlo).** Repeat the whole stratified draw **~100 times** (a documented `SEED`). For each stratum, recompute the per-year areal flood frequency and the F6 trend statistic on every draw, then summarise the statistic **across draws** with the median and a percentile band (10 / 25 / 50 / 75 / 90).

## 3. What this buys — and what it does not (read this before interpreting)

- **It buys an honest measure of spatial-sampling uncertainty.** The spread of a stratum's verdict across the ~100 draws directly answers "would we conclude the same thing with a different sample?" This is the concern that motivated the round, and repeated draws are the right way to answer it — the empirical spread *already embodies* spatial autocorrelation, so it needs no separate effective-sample-size correction.
- **It buys precision and representativeness**, especially in the large wet strata that flat-40 under-represented.
- **It does NOT buy trend-detection power.** F6's test is bounded by the **35-year record**, not by the number of spatial points. Expect the rebalance to *harden* the existing verdicts (8 no-trend · 1 non-stationary · 0 directional), not overturn them. More points did not hide a trend at N = 40; they risked an unreliable estimate. A trend either lives in the 35 years or it does not.
- **It does nothing for F7.** The ground-cover response is plot-limited (16 / 19 / 22 plots); sample points carry no cover. F7 is untouched by this round.
- **Do not report a naive n = 1,000 confidence interval.** Because the surface is spatially autocorrelated, 1,000 points are not 1,000 independent observations; the effective sample size is much smaller. The mean / median / percentiles of a single large draw **describe the within-stratum spatial spread** (use median + percentiles — flood frequency is skewed); the *uncertainty* statement comes from the across-draw spread, not from treating one draw as n = 1,000.

## 4. Allocation trade-off (a real choice to make explicit)

Proportional-with-floor (above) represents each stratum's spatial heterogeneity in proportion to its extent, but it makes **cross-stratum precision unequal** — the small dry strata will show wider across-draw bands than the large wet ones. That is honest (we genuinely know less about the small dry patches), but F6 *compares* strata, so annotate every cross-stratum comparison with its per-stratum Monte Carlo band rather than comparing point verdicts of unequal reliability. If clean cross-stratum comparability is preferred over area-representativeness, the alternative is **equal large-N** (e.g., ~500 each). Recommendation: proportional-with-floor for representativeness, carrying the census area/pixel weights for any farm-wide roll-up, with the per-stratum band always shown.

## 5. Reporting

Per stratum: the median per-year areal flood-frequency series and its across-draw percentile band; the F6 verdict computed per draw, reported as the **modal verdict + the fraction of draws supporting it** (verdict stability); Theil–Sen slope and Mann–Kendall τ as across-draw medians with percentile intervals. Farm-wide roll-ups use the census area weights. The one marginal stratum (Riverine · low, episodic) should be sampled and reported carefully enough that its non-stationary flag is shown to be stable (or not) across draws.

## 6. Literature precedents

The design is standard practice, assembled from three well-established lines:

- **Stratified sampling & area/uncertainty estimation in remote sensing.** Olofsson et al. (2013, 2014, *Remote Sensing of Environment*) and Stehman (2009, 2014) are the good-practice references: stratified random sampling with per-stratum allocation, unbiased variance estimators, and stratification precisely where variability differs across conditions. Sample size can be adjusted per stratum without biasing the estimators — which is exactly the proportional-with-floor allocation here.
- **Uncertainty by resampling.** Bootstrap/Monte-Carlo resampling to produce percentile estimates (e.g., 25/50/75) and assess robustness is standard in hydrology; our ~100 repeated spatial draws are the spatial-sampling analogue.
- **Autocorrelation and effective sample size.** A serially/spatially correlated series carries less information than its nominal length (Matalas & Langbein 1962; Yue & Wang 2004; Hamed & Rao 1998). For the *temporal* trend side, the **block bootstrap Mann–Kendall** (Önöz & Bayazit 2012; R package `modifiedmk`) preserves serial dependence and is robust for short/autocorrelated series — a natural complement to F6's existing drop-two-floods robustness check, and to the spatial repeats here.

Underlying products and ecological frame (already in the project register): the DEA Water Observations water-detection lineage (Mueller et al. 2016; Guerschman et al. 2011) for the flood-frequency surface; Kingsford (2000) and the Lowbidgee regulation context; and the flood-pulse concept (Junk et al. 1989) for the lagged, community-specific vegetation response.

## 7. Relationship to the ladder

This is a **revision of F5 (allocation) + a re-run of F6 (trend test on the rebalanced, resampled design)** — it does not change the headline metric, the strata definition, or the gate logic. It adds a spatial-uncertainty layer to complement F6's existing temporal robustness (drop-two-floods), and it is DB-first (census + annual stack). It is gated on two open Adrian questions: **Q1** (near-plot vs community-wide — determines whether the small dry strata can reach their target draw sizes) and **Q3a** (the valid-coverage masking threshold).
