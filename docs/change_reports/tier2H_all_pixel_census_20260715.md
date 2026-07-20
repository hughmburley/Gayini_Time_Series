# Tier 2 · Task H — all-pixel census · change report

*Claude Code, 15 Jul 2026. Branch `tier2h-track-a-census`, held for review (do not merge). Gate 1 signed off (`docs/tier2H_gate1_VERIFIED_20260715.md`). This report covers **H1 (quick wins)** and **H3.0 (NN reprojection)** only — work STOPS at H3.0 by instruction, pending review of the reconciliation delta before the census (H3.1+) is computed on top.*

---

## H1 · Quick wins

| Item | Status | Notes |
|---|---|---|
| Dashboard label #21 | ✅ done | `R/gayini_dashboard_panels.R` — "Total vegetation (green cover)" → **"Total veg (green + dead)"** (the `green_only` panel title; the total-veg trace is green+dead, so "(green cover)" was wrong). |
| CLAUDE.md dangling ref | ✅ done | `CLAUDE.md:56` now points at `docs/archive/Gayini_subsampling_approach.md`, marked ARCHIVED/superseded. |
| Archive Task F specs | ⚠️ local only | Both files placed on disk at `docs/archive/` with `SUPERSEDED-BY` headers (by Hugh). **`docs/archive/` is gitignored** (`.gitignore:37`), so they stay local — consistent with the "reports stay local" convention, but they will **not** appear in the committed PR. Flagging so it's a decision, not a silent outcome. |
| Reconcile `scripts/_deprecated/` → `scripts/archive/` | 🔴 blocked — tooling conflict | The spine smoke test **hard-fails if `scripts/archive/` exists** (`run_spine_smoke_test.R:104-112`, `folder_scripts/archive_absent`). Moving `_deprecated/01_lag_diagnostics_inundation_gc.R` into `scripts/archive/` would break gate #11 ("spine validation clean"). Left untouched — needs a decision (delete? move outside `scripts/`? relax the smoke rule?). Not guessed. |

Task F **code** on `main` untouched (`gayini_stratum_allocation`, `gayini_draw_monte_carlo`).

---

## H3.0 · NN reprojection of the annual stack onto the canonical 8058 grid

**New script:** `scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R` (additive; nothing existing overwritten).

**What it does:** reprojects the 35-layer binary `annual_{wet,valid}_any_1988_2023.tif` (EPSG:28355, 25 m) onto the exact `veg_regime_class_8058.tif` grid using **`method="near"`**, writes it as a new registered raster product, asserts grid alignment + legal value set, and reports the NN-vs-bilinear reconciliation delta against the existing (bilinear-derived) products.

### Products (all additive; `Output/` gitignored, registered in the DB)
- `Output/rasters/inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif` (35 lyr, NN)
- `Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif` (35 lyr, NN)
- `raster_asset`: 2 new rows, `product='annual_inundation_stack_8058'`, `crs_epsg=8058`, res 24.97 m, checksums populated, `legend_status='confirmed'` (idempotent; post-build mutation).
- `Output/diagnostics/regime_band_breaks_nn.csv`, `tier2H_h30_{nn_vs_bilinear,tercile,community}_delta.csv`, `tier2H_h30_reproject_qa.json`.

**Held (NOT persisted as canonical):** `veg_regime_class_8058.tif`, `census_stratum`, `regime_band_breaks.csv` are **untouched**. The NN terciles/census are reported for review only.

### Assertions — PASS
- **compareGeom() vs `veg_regime_class_8058.tif` = TRUE** for both layers (identical CRS 8058, dims 2422×4037, res 24.970268, origin (5.264715, 0.749231), extent).
- **Legal value set:** `wet_8058 ⊆ {0,1}`, `valid_8058 ⊆ {1}` (presence-only, no zero — confirmed), **255 absent from both** (nodata survived reprojection as NA).
- NN freq range [0.0000, 100.0000].

### Reconciliation delta — NN vs bilinear

| Quantity | Result | Expected (design seat) | Verdict |
|---|---|---|---|
| Footprint (supported px, 8058) | NN 9,754,250 = BL 9,754,250, **diff +0** | +0 | ✅ matches |
| Per-community px (NN vs **committed** `census_stratum`) | **+0 for all 5** (Aeolian 77,544 · Riverine 193,658 · Inland 717,629 · Woodland 86,375 · Other 4,951) | +0 | ✅ matches — and **stronger**: reconciles to the *committed* product at exactly diff=0 |
| Frequency value | mean **−0.0000 pp**, median 0, sd 1.207 pp, 16.9% >1pp, 1.0% >5pp | mean +0.0004, sd 1.22, 17.0% >1pp, 1.0% >5pp | ✅ matches |
| NN tercile breaks | land exactly on n/35 steps: 5.714=2/35, 17.143=6/35, 34.286=12/35, 0.000=0/35 | predicted n/35 signature | ✅ matches |

### 🔴 Divergence to investigate (not absorbed): the per-*band* tercile split moves materially

The design-seat approval expected per-band counts to "stay ~equal regardless" of the mechanism. **They do not.** While per-*community* totals are identical (+0), the within-community **low/mid/high tercile split reshuffles by tens of thousands of pixels**:

| Community | band | NN | old (bilinear) | Δ |
|---|---|---|---|---|
| **Aeolian** | **low** | **0** | 26,786 | **−26,786** |
| Aeolian | mid | 47,225 | 23,720 | +23,505 |
| Aeolian | high | 30,319 | 27,038 | +3,281 |
| Inland | low | 205,332 | 238,328 | −32,996 |
| Inland | high | 271,493 | 239,635 | +31,858 |
| Riverine | low | 59,986 | 65,781 | −5,795 |

**Cause — real, not a bug.** NN preserves the honest discrete measurement: freq lands only on n/35 steps (granularity ~2.86 pp). For the driest community (Aeolian), **≥⅓ of pixels are exactly never-wet (freq = 0)**, so the 1/3 quantile is exactly **0** → the "low" band (freq < 0) is empty and every never-wet pixel falls into "mid". The bilinear surface hid this by smearing exact-zeros into a fake continuum (0.001–0.18), which allowed a clean ⅓ split that was **splitting smoothing noise, not signal**. Elsewhere the reshuffle happens wherever an n/35 step straddles a tercile boundary.

**Scope — this does NOT threaten the headline.** The community-level flood-frequency headline and the annual community series (what F6 tests) are **mechanism-invariant** (per-community +0, per-pixel freq Δ≈0). The divergence is confined to the *within-community wetness-band definitions* — i.e. the 9-cell veg×band matrix granularity and the checkerboard, not the headline or the trend test.

**Decision needed before H3.1 (do not guess):** how to define the within-community wetness bands under honest NN values?
1. **Accept NN bands as-is** — honest, but Aeolian has a degenerate (empty) "low" stratum.
2. **Decouple** — keep the F5 bilinear-derived tercile *definitions* (`regime_band_breaks.csv`) as the band boundaries, but compute all census flood-frequency on the NN stack. Preserves the 3-way split; documents that band edges are bilinear-defined.
3. **Redefine** — tie-aware/absolute thresholds for the driest community.

**Recommendation:** adopt NN for all frequency arithmetic (the headline is clean and better science), and take **option 2** for the band *definitions* in the first cut so the 9-stratum matrix stays populated — while recording that Aeolian's tercile split is only meaningful under smoothing, which is itself a finding worth stating to Adrian (the driest community has no real internal wetness gradient). Hugh's call.

### Watch-items status
- **CRS:** all products EPSG:8058, `method="near"` only, legal value set asserted, originals untouched. ✅
- **Grid alignment:** compareGeom TRUE (asserted, not assumed). ✅
- **F6 expectation:** not yet run (H3.2). The community-level series is mechanism-invariant, so the 8/1/0 verdict is expected to hold — will confirm at H3.2.

### Notes
- Spine smoke test: one **pre-existing** failure unrelated to Task H (`scripts/10_downstream_optional/` directory missing). Script 11 parses cleanly; `scripts/archive/` correctly absent.
- `raster_asset` registration is a post-build mutation (idempotent) — re-run after any full DB rebuild, in the post-build chain.

---

## Track A — H3.1 / H3.2 / H3.3 (v3, option 2)

**New script:** `scripts/03_inundation_products/12_run_census_trend_test.R` (read-only; zonal stats + the reused F6 test). Option 2 (decouple): strata = the committed `veg_regime_class_8058.tif` (F5 edges), all frequency arithmetic on the NN 8058 stack.

### Why option 2 (recorded per instruction — this is the real reason, not "keeps the matrix populated")
NN quantile bands are **not reproducible**. The Inland ⅓ break sits on a tie plateau (n/35 steps: cum% 28.61 → 33.26 → 38.13; the ⅓ break lands inside that jump), so a 0.019% change in the community mask flips the break 6/35 → 7/35 and moves the low band 14%. Aeolian is worse: 41.59% never-wet → the ⅓ quantile *is* 0 → low band empty. Fixed CSV edges are reproducible; quantiles-on-discrete-data are not. Option 2 is also the only choice that keeps the nine strata **identical** to the shut gate, so F6 is a like-for-like comparison (options 1/3 change strata composition → any verdict move is indistinguishable from re-stratification).

### H3.1 — census veg × wetness matrix ✅
Headline `100 × wet-valid-years ÷ valid-years`, every pixel, on the NN stack. Per-community: **Aeolian 6.08 · Riverine 12.91 · Inland 27.99**. Per-stratum monotone within each community (e.g. Inland low/mid/high = 9.2 / 27.3 / 47.3). MIN_VALID_YEARS = 25 sensitivity line emitted (non-binding, 0.025%).

**Correction C10 (HIGH) — support, not a mislabelled metric. (My first diagnosis here was WRONG; recorded for the audit trail.)**

I initially concluded CLAUDE.md's 9 / 22 / 50 was the within-year `annual_occurrence_pct` mislabelled as the headline, and proposed replacing it. **That was wrong and the fix would have replaced a correct number with a census number under the same label.** The within-year means are 4.0 / 11.6 / 31.2 — nowhere near 9/22/50. My error: three between-year computations agreeing at **pixel** support told me nothing about **plot** support, and I never checked the support dimension.

**The real cause is support.** `annual_wet_any ⟺ occurrence_pct > 0` (verified: 1,590 dry plot-years all occ = 0; 720 wet all occ > 0) — a plot is wet if **any** of its ~16 pixels is wet. `P(any of 16) ≫ P(one pixel)`, which is exactly the 1.5× / 1.7× / 1.8× gap. **Both numbers are correct; they measure different things:**

| Support | Means (Aeolian / Riverine / Inland) | Question answered |
|---|---|---|
| **Plot** (~1 ha, any-pixel rule, 66 plots) | **9 / 22 / 50** (+ Woodland 44) | "how often does a 1-ha site see any water" |
| **Pixel** (24.97 m census) | **6.1 / 12.9 / 28.0** | "how often is a 25 m pixel wet" |

`dim_metric` had **no support dimension**, so plot-support and pixel-support between-year frequency were indistinguishable by name — a **second name trap, distinct from C8** (which is within-year vs between-year).

**Actioned (add, never replace):**
- New post-build script `scripts/01_prepare_inputs/05_populate_metric_support.R`: adds `dim_metric.support`; labels 6 pixel-support rows (`census_stratum_*`, `veg_regime_class`) and 2 plot-support rows (`inundation_annual_wet_any`, `inundation_annual_occurrence_pct`); registers the new `census_flood_frequency_pct` metric (pixel support) whose caveat states it is **not** comparable to 9/22/50.
- CLAUDE.md: 9/22/50 **annotated as plot support** (any-pixel rule, 66 plots) and the census 6.1/12.9/28.0 **added alongside** as pixel support. The 9/22/50 numbers are unchanged.
- CLAUDE.md post-build chain extended (`11_reproject_annual_stack_8058_nn` → `05_populate_metric_support`) — a rebuild wipes both.

**Blast radius — reported, NOT fixed** (per the C1 rule). All of these quote 9/22/50/44 and are **correct** (all derive from the plot-year spine = plot support); none are wrong, they simply don't state the support:
- **`F4` data figure** — [gayini_descriptive_figures.R:472](R/gayini_descriptive_figures.R#L472) `gayini_build_f4_data()` annotates each community with its mean (~9/22/50/44%). **This is the shipped slide.**
- [gayini_db_validation.R:15,141](R/gayini_db_validation.R#L141) — release check asserts the spine reproduces 9/22/50/44.
- [demo_spine.R:29](demo_spine.R#L29) — expects 9.1 / 22.3 / 49.6 / 44.1.
- [CLAUDE.md:56](CLAUDE.md#L56) — Q2 Adrian gate, "use the headline 9/22/50".
- `docs/repo_audit_pre_subsampling_stocktake.md:111,188`.

### H3.2 — F6 on the census: **9 no-trend / 0 non-stationary / 0 directional — RATIFIED**

The census returns **9/0/0**, not the F5-sample gate's 8/1/0. The single change: **Riverine low: `non_stationary` (sample) → `no_trend` (census)**. All eight other strata are unchanged. **Ratified by Hugh, 15 Jul 2026.**

| Riverine low | MK τ | MK p | verdict |
|---|--:|--:|---|
| F5 sample (40 pts) | 0.398 | **0.0039** | non_stationary |
| Census (65,781 px) | 0.128 | **0.29** | no_trend |

**Why the change is accepted — it is a sampling artefact, not a signal.** The sample series is exactly 0 in **28 of 35 years**; 40 points in a sparse, zero-inflated stratum report zero regardless of the truth (~0.04 expected wet points/year in the early period), so the record looks like clean zeros then late-flood spikes, which MK reads as a significant monotonic rise. The census shows those "dry" years actually carried ~0.1–0.7% scattered wetness (1989 ≈ 210 wet px of 65,781). No wet pixels were invented — NN maps existing 28355 wets; the 40 points simply could not see the early baseline.

**The decisive evidence (Hugh's independent test, not mine):** 1,000 random 40-point draws from this *same census stratum* return **p < 0.05 in 541 of them — a 54% false-positive rate against a nominal 5%**. Median 29/35 zero-years per draw, so the F5 sample's 28 is a **typical draw, not an unlucky one**. Mean τ across draws **+0.258 vs census +0.126** — sparsity biases τ upward. Same mechanism, same stack: sparsity alone. (A single-draw reproduction was considered and rejected as strictly weaker than the full distribution.)

**The stop rule was wrong and is corrected — record this.** "A census adds zero temporal power" is true, but it does **not** imply the verdict cannot change. A trend test operates on the **values** of the 35 annual observations, and the census removes **measurement error within each year**. Where the sample is systematically distorted — as it is for a sparse, zero-inflated stratum — the census **corrects rather than hardens**. The original expectation ("verdict must reproduce 8/1/0, divergence = bug") conflated "no new temporal information" with "no change in the estimated values", which are different claims.

**Task F asked exactly the right question; the census answered it.** The archived sub-sampling note (`docs/archive/Gayini_subsampling_approach.md` §5) explicitly named **Riverine low** as the stratum whose non-stationary flag needed testing for stability across draws. That is precisely the stratum the census overturned — a vindication of the archived design's diagnosis, reached by a different route.

**Net result:** the census *strengthens* the headline. The system is flood-pulse driven with **no trend in any of the nine strata**, and the "thinly sampled / provisional" caveat is gone by construction.

The script's gate now asserts the ratified expectation (9/0/0 **with Riverine low as the only permitted change**); any other stratum moving still stops the run as unexplained.

### Aeolian low — vacuous verdict (confirmed)
Under option 2, Aeolian low is populated (26,786 px) but its NN series is **exactly flat zero** (max annual freq = 0.0000%): every pixel the bilinear surface called "driest" has 0 wet years. Its `no_trend` is **trivially/vacuously true** — a flat series cannot trend. Report to Adrian as a finding (42% of Aeolian never floods; no internal wetness gradient at the low end), not as evidence.

### H3.3 — per-year cut ✅ (Track A complete)

The episodic signal is unmistakable and the per-year cut earns its place: focus-area annual flood extent ranges **0.04% (2006) → 84.67% (2022)**, a ~2,000× swing with no drift.

| | Years |
|---|---|
| **Top 5 flood years** | **2022 (84.7%)** · 2016 (65.8%) · 2010 (59.6%) · 1992 (53.9%) · 1990 (53.1%) |
| **Driest** | 2006 (0.04%) · 2003 (0.37%) · 2008 (0.40%) · 2007 (0.56%) · 1994 (1.11%) |

The Millennium Drought (2001–2009) is stark — eight of nine years below 8% except 2005 (21.5%) — and the wet phases (1988–93, 2010–11, 2016, 2021–22) are climate-paced, not trending. This is the picture that makes "no trend / flood-pulse driven" legible on a slide, and it is exactly why a trend test over 35 observations returns no-trend across all nine strata.

**Bonus finding — `MIN_VALID_YEARS` is not merely non-binding, it is *inert* for the census.** `n_valid_px` is **constant at 988,831 in every one of the 35 years**: every focus-stratum pixel has 35/35 valid years. The 22–34 valid-count pixels the design seat measured all sit outside the mapped communities. So the sensitivity line understates the case — within the census the threshold removes nothing at all.

### Outputs (local; `Output/` gitignored)
`tier2H_h31_census_matrix.csv`, `tier2H_h31_census_stratum_annual_series.csv`, `tier2H_h32_census_f6_verdicts.csv`, `tier2H_h32_f6_verdict_delta_vs_sample.csv`, `tier2H_h33_per_year_cut.csv`, `tier2H_trackA_qa.json`.

---

## H2 · Total-veg percentile rasters (Track B) — built, STOPPED at the valid-season gate

**New script:** `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R`.

Five across-series percentile rasters (5/10/20/30/50th of total veg = green+dead), one value per pixel, pooled over 140 seasonal composites, computed at native 30 m / EPSG:3577 and reprojected **once** to the 8058 census grid (**bilinear** — continuous cover %, the opposite of H3.0's binary `near` rule; the two rules are kept distinct).

### Pool — 140 of 153, asserted before any raster work
Water year = **Jul 1 – Jun 30**, assigned by **season midpoint**. WY1988-1989 … WY2022-2023 = 35 WYs × 4 seasons = **140 retained**; 13 dropped (**2 before** — exactly DJF 1987-88 and MAM 1988 as specified — **11 after**). Matches the expected number exactly.

> **Bug my own dry-run caught:** the MAM midpoint computes to **31 Mar**, not 1 Apr (Mar 1 + 30 days; March has 31), so labelling the season off the midpoint month returned NA for all 35 MAM composites and would have falsely tripped my own guard. The **water-year assignment is unaffected** (months 3 and 4 fall the same side of the July boundary). Season labels now derive from the **start** month (12/3/6/9), which is unambiguous. Fixed before the build.

### 🔴 The uint8 nodata trap — closed, and separated from source data quality
The `[0, ~110]` range check **fired** (max **147**) — so I diagnosed rather than widened the bound. It is **not** the wrap:

| Discriminator | Observed | A wrap would show |
|---|---|---|
| `== 254` (the 255+255 signature) | **0** | a pile-up at 254 |
| Out of envelope | **15 of 349,648,690 = 0.0000043%** | ~0.56–1.08% (the nodata fraction) |
| At the offenders | `b1_bare = 0`, b2/b3 ordinary, **no 255 present** | 255 present |
| Source `band1+band2+band3` | **already 147 itself** | our arithmetic only |

The wrap is **closed by construction** — `subst(255 → NA)` precedes every sum, so nodata cannot reach the arithmetic regardless of whether the source ships nodata set (terra does honour it: probe shows 255 absent as a value, band2 max 102). The 15 stragglers are **genuine JRSRP unmixing overshoot**; a cover % cannot exceed ~100, so they are set to **NA** (not clamped — don't invent data) and counted. Immaterial by construction: 15 values in 350M, all *high*, so the 5th–30th percentiles cannot move and a pixel's p50 is unaffected by 1–2 of its 140 seasons.

> **⚠️ Corrects `Gayini_established_data_facts.md` §4:** "PV+NPV+BS max 111" / "band2+band3 ≤ ~110" was measured on **four** files. Across the full 140-composite pool the tail reaches **147**. The envelope claim is an n=4 sampling artefact.

### 🟡 GATE — valid seasons per pixel: MEASURED, threshold NOT chosen

| scope | n_pixels | min | p01 | p05 | median | max | <10 | <20 | <50 | %<50 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| full FC grid (3577, 30 m) | 2,846,756 | 0 | 97 | 111 | **121** | 140 | 1,028 | 7,012 | 9,248 | 0.325% |
| **farm footprint only** | **959,944** | 5 | 99 | 107 | **118** | 140 | **14** | **38** | **111** | **0.0116%** |

**`MIN_SEASONS = 50` — applied, signed off 16 Jul 2026.** Drops **111 of 959,944 farm pixels (0.0116%)** — near-inert, the same shape as `MIN_VALID_YEARS`.

**The justification, recorded (not just the number)** — this is the **third** member of the `MIN_VALID` family (`MIN_VALID_YEARS`=25, `MIN_VALID_COVERAGE`=40) and the other two were never formally signed off:
- For `p05` to be a **percentile** rather than simply the minimum you need **n > 20** (at n=20 the 5th percentile *is* the smallest observation).
- For one bad scene not to set the floor alone, the 5% tail must hold ≥2 observations: **0.05n ≥ 2 → n ≥ 40**.
- At **n = 50**, `p05` is the **2nd–3rd smallest** — a statistic, not an artefact of one anomalous season.

Measured *before* it was chosen (facts §12), not after.

**Why the median pixel is missing ~22 of 140 seasons — and it is not per-pixel noise.** Per-scene nodata within the farm (all 140 measured, new table `tier2H_h2_nodata_by_scene.csv`): min 0.000% · **median 2.255%** · **mean 14.34%** · max **96.578%**. **70 of 140 scenes are <2% nodata; 43 exceed 10%; 22 exceed 30%.** Mean 14.34% × 140 = **20.1 implied missing seasons**, which reconciles with the observed median of 22.

> **⚠️ Second n=4 artefact in facts §4:** "nodata 0.56–1.08% per scene" is accurate for the *clean majority* — the doc's own two in-pool sample files measure 1.03% and 0.08% — but the mean is **14.3%** and one scene (DJF 1989-90) is **96.6% obscured**, effectively absent. The distribution is skewed, not ~1%.

**Consequences for the threshold decision:**
1. Loss is driven by **whole obscured scenes**, not per-pixel noise, so every pixel loses roughly the *same* seasons → the valid-season distribution is **tight, not long-tailed**. A minimum-seasons threshold is therefore **nearly inert**: at 50 it drops **111 farm pixels (0.0116%)**; at 20, 38 (0.004%). Same shape as `MIN_VALID_YEARS`.
2. **The real issue is seasonal imbalance, not count.** JJA (mean 20.70%) and SON (21.34%) lose ~**3×** more than DJF (8.44%) and MAM (6.89%). The surviving pool is weighted toward summer/autumn, so an across-series percentile is not seasonally balanced. For a *floor* statistic this is the substantive question — worth a decision, whereas the count threshold looks moot. **Tested below.**

### 🔴 Seasonal-composition test — the result contradicts the prediction, in both direction and shape

Test as specified: `p05` and `p50` on a **DJF+MAM-only** pool vs a **JJA+SON-only** pool, on farm pixels with ≥25 valid seasons in **both** (like-for-like, same pixel set). **The pool was NOT rebalanced** — that would change what the statistic means.

**delta = (JJA+SON) − (DJF+MAM), cover %, n = 959,674 farm pixels:**

| statistic | mean Δ | median Δ | sd | q05 | q95 |
|---|--:|--:|--:|--:|--:|
| **p05** | **+10.852** | +10.2 | 7.781 | −0.5 | +24.5 |
| **p50** | **+5.617** | +5.0 | 3.749 | 0.0 | +13.0 |

**The correction (precise — not "both inverted"): direction was right, magnitude ranking and mechanism were wrong.**
1. **Direction was correct.** "Losing high values shifts p50 down" predicts exactly the positive delta observed — the under-observed season *is* the high one, so its loss biases the pooled percentile downward.
2. **Mechanism was wrong, and the correct one is stronger than first stated.** The delta is **not flood green-up**. The +10.85 pp holds across **959,674 pixels — essentially the whole farm** — and flooding touches only a fraction of pixels in any year, so **a farm-wide delta cannot be flood-driven**. It is the **winter–spring growing season** (JJA/SON) vs the summer dry-down (DJF/MAM). The seasons go missing *because it was wet/cloudy*, but the cover consequence is ordinary phenology, not inundation.
3. **Magnitude ranking was wrong.** `p05` moves ~2× MORE than `p50` (+10.9 vs +5.6 pp) — the whole seasonal *distribution* shifts, not just its tail, so the **floor is the more seasonally-sensitive statistic**, not the less. The caveat is therefore quantified but **not closed for the floor by this test alone** — which is why the spatial-uniformity gate below is the real gate on H4.

**But the headline delta is an upper bound, and the realised bias is far smaller.** The table is the **100-point** composition swing (all-cool vs all-warm). The *actual* imbalance is mild — effective seasons per pixel, from the measured per-season nodata:

| | DJF | MAM | JJA | SON | cool (DJF+MAM) | warm (JJA+SON) |
|---|--:|--:|--:|--:|--:|--:|
| effective seasons (35 × (1−nodata)) | 32.05 | 32.59 | 27.76 | 27.53 | **64.64** | **55.29** |

Total ≈ 119.9, which reconciles with the observed median of 118 ✓. So the pool is **53.9 : 46.1** cool:warm against a balanced 50:50 — a **~3.9-point** shift, not 100. Scaling the p05 delta by that shift gives an order-of-magnitude estimate of **≈0.4 pp** of realised bias on the product, and the true value is likely *lower* still, because the pooled bottom-5% is dominated by the low-cover (cool) season regardless of mixing weight — so p05 responds sub-linearly to composition.

> **This ≈0.4 pp is an inference, not a measurement** — clearly flagged as such. If you want it measured rather than estimated, the direct test is a balanced-subsample diagnostic (take `min(n_DJF, n_MAM, n_JJA, n_SON)` per pixel, recompute p05, compare to the product). That measures the bias without rebalancing the product. Say the word.

**Feeds the percentile-choice decision (#9):** if `p05` is the most seasonally-sensitive of the five, that is an argument against it being the canonical one on stability grounds — worth weighing against its resilience rationale.

### 🔴 JJA water-year boundary — zero margin, fixed

`end_date` parsed as the **1st** of the end month gave JJA a 61-day span whose midpoint was **exactly 07-01** — the water-year boundary — for **all 35** JJA composites. The pool was right **only by luck**: JJA is the only season that straddles the boundary, so a `>` instead of `>=` on the boundary test would have moved all 35 JJA composites into the previous water year while still producing a plausible-looking count.

Fixed by parsing `end_date` as the **last day of the end month**. Midpoints are now DJF **15 Jan** · MAM **15 Apr** · JJA **16 Jul** · SON **16 Oct** — the JJA margin is **15 days**, and the **minimum distance from *any* midpoint to a July-1 boundary across all 153 composites is 15 days**. `n_retained = 140` **still holds** (35 WYs × 4 seasons; 2 before / 11 after unchanged).

### Raster diagnostics — "blank" was framing, not a bug

| raster | n_data | NA fraction | data extent | grid extent | min | median | max |
|---|--:|--:|---|---|--:|--:|--:|
| p05 | 4,089,889 | 0.5817 | 68.67 × 47.34 km | 100.8 × 60.48 km | 1.186 | 58.206 | 95.994 |
| p10 | 4,089,889 | 0.5817 | 68.67 × 47.34 km | 100.8 × 60.48 km | 1.263 | 64.611 | 96.711 |
| p20 | 4,089,889 | 0.5817 | 68.67 × 47.34 km | 100.8 × 60.48 km | 1.841 | 71.252 | 97.000 |
| p30 | 4,089,889 | 0.5817 | 68.67 × 47.34 km | 100.8 × 60.48 km | 1.929 | 75.745 | 97.340 |
| p50 | 4,089,889 | 0.5817 | 68.67 × 47.34 km | 100.8 × 60.48 km | 3.561 | 82.000 | 98.000 |

**58.2% NA is legitimate and explained:** the FC footprint (68.67 × 47.34 km) is smaller than the 8058 grid (100.8 × 60.48 km) *and* is rotated within it (Albers → Lambert), so the corners are necessarily empty. Note this is **lower** than the ~86% expected for a *boundary-masked* raster — these products are FC-extent-limited, not farm-masked, because H4 joins by `pixel_id` and only census pixels are consumed.

PNGs (`Output/figures/H2_veg_percentiles_{common_scale,stretch}_data.png`) are zoomed to the **data** extent, NA explicit in grey, farm boundary overlaid, value range in each title — one at a common 0–100 scale, one per-raster stretch. They show real spatial structure (channels, paddocks, the boundary), and the p05→p50 progression is visibly monotonic.

### QA json path leak (minor, same family as C12) — fixed
The `outputs` block was keyed by absolute `D:/…` paths. Cause: `gayini_relative_path()` uses `vapply()`, which auto-names its result from the input **values** (the absolute paths), so `as.list()` inherited them as keys even though `unname()` was called on the input. Now `unname()`d and keyed by percentile label with relative-path values (a relpath→relpath map would be self-referential). `figures` added the same way. **Only H2 was affected** — scripts 11/12 pass scalar paths, which take a different branch.

### Assertions — all pass
- **`compareGeom()` vs `veg_regime_class_8058.tif` = TRUE** (CRS 8058, 2422×4037, res 24.970268, origin (5.264715, 0.749231), identical extent).
- **Monotonicity p05 ≤ p10 ≤ p20 ≤ p30 ≤ p50: 0 violations** on all four pairs.
- Final percentile value range **[1.186, 98.000]**.

### Registration (C2 actioned)
`raster_asset` now holds **8 EPSG:8058 rows** — the 5 percentile rasters (`total_veg_percentile_8058`), the 2 NN stack layers, and **`veg_regime_class_8058` itself (C2)**, all with crs/extent/res/checksum populated. C2 was load-bearing: the census `pixel_id` is meaningless without a registered grid definition (data contract §2).

### Resolution caveat (recorded)
FC is natively **30 m**; these products are reported on the **24.97 m** census grid. The extra apparent detail is a resampling artefact — **do not over-interpret fine spatial detail in the veg layer**. Recorded in the code header, the `raster_asset.legend_semantics`, and the QA json.

### Rationale recorded (#7)
Low percentiles are the **floor** of the system — *"when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem"*. **Resilience, not average condition.** The 50th is the reference the floor is read against, not the headline.

---

---

## H2 gate + diagnostics, and H6 (16 Jul)

**New scripts:** `scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R` (read-only), `scripts/03_inundation_products/14_build_flood_zone_raster.R`.

### 🔴 GATE ON H4 — spatial uniformity of the seasonal mixture: **PASS** (on magnitude)

The farm-wide seasonal delta and the ≈0.4 pp realised bias do **not** close H4. The real risk: the *signal* is uniform ecology (~11 pp growing season), but the *mixture each pixel gets* depends on which scenes it lost — and that is **cloud, which is spatial**. If the mixture correlates with flood frequency, `p05`-vs-inundation (H4's central relationship) is partly measuring cloud.

**Measured** — per-pixel fraction of retained seasons that are JJA+SON, over 1,080,002 census pixels:

| quantity | value |
|---|---|
| mixture median · sd | 0.457 · **0.0231** (tight) |
| **correlation with flood freq** | Pearson **r = −0.213**, r² = 0.045 · Spearman −0.235 — **real but weak** |
| mixture change across the flood gradient | 0.466 (never) → 0.456 (>50%) |

The correlation is real (wet pixels lose more winter/spring cloud), so a bare `|r|` threshold is the wrong instrument. **Converted to the unit that decides H4** — pp of the `p05`-vs-flood relationship injected by the mixture–flood link:

- `p05` sensitivity to the mixture (from the balanced-subsample slope): **~10.9 pp per unit** `f_warm`.
- mixture change across the whole flood gradient: **~0.011**.
- → **induced `p05` bias = 0.126 pp**, against a **real `p05` signal of 40.7 pp** across the flood gradient = **0.3% of the signal**.

**Verdict: PASS.** The mixture is tight and, in `p05` units, injects 0.13 pp of cloud into a 41 pp ecological signal. H4's `p05`-vs-inundation is not materially confounded — **state the caveat, proceed**. *(H4 waits for your call regardless.)* Verdict written to `tier2H_h2_gate_verdict.json`; map `H2_gate_season_mix_data.png` (uniform pale blue ≈ 0.45, faint SE gradient).

### Balanced-subsample diagnostic — the ≈0.4 pp, now **measured** not inferred
`min(n_DJF,n_MAM,n_JJA,n_SON)` per pixel → recompute `p05`/`p50` on the balanced pool → compare to the product (23,070 farm pixels; **product NOT rebalanced**):

| statistic | product mean | balanced mean | **mean bias** | median bias | sd |
|---|--:|--:|--:|--:|--:|
| p05 | 57.64 | 58.11 | **+0.467 pp** | 0 | 1.93 |
| p50 | 80.70 | 80.90 | **+0.196 pp** | 0 | 0.64 |

Two agreeing inferences (yours and mine, both ≈0.4 pp) are now one measurement: **+0.47 pp** on the product `p05`, median 0. **But this is a LOWER bound, not the farm figure:** requiring all four seasons keeps only the best-observed pixels, which are the least imbalanced and therefore the least biased, so the farm-wide bias is ≥ this. The tight mixture (sd 0.023) caps how far off it can be; the framing matters more than the number.

The mixture–flood relationship is a **step, not a gradient** (flat ≈ 0.467 up to 25% flood freq, then ≈ 0.455 above — see the binned table), so using the full range in the induced-bias calc overstates it: the 0.3% verdict is conservative.

### Diagnostics (3a–3c)

**3a — farm-masked columns added** (the shipped grid medians would be cited as farm figures). They're close, not two-thirds different — but now explicit:

| raster | grid median | **farm median** | farm − grid |
|---|--:|--:|--:|
| p05 | 58.21 | **59.35** | +1.14 |
| p10 | 64.61 | 65.46 | +0.84 |
| p50 | 82.00 | 81.99 | −0.01 |

**3b — the floor is dead. 🔴 Second slide for Adrian — now measured PAIRED (my first version was invalid arithmetic).**

`p05(total)` and `p05(PV)` are **marginal percentiles on different orderings** — the season that sets a pixel's total-veg floor is not necessarily the one that sets its PV floor, and percentiles do not subtract, so `median(PV_p05)/median(total_p05)` was meaningless. Measured **paired** instead: for each farm pixel, PV in the *same season* that sets its total-veg `p05` (complete farm apply, 959,833 px, not sampled):

| quantity at the floor season | farm median | mean | p95 |
|---|--:|--:|--:|
| total veg | 58.0 | 56.8 | 81.0 |
| PV / green | **1.0** | 7.7 | 42.0 |
| **green fraction of the floor** | **3.0%** | 11.8% | 55.6% |

**At the season that sets its total-veg floor, the median farm pixel is 3.0% green → ~97% of the floor is dead material** (NPV / litter / standing dead). The invalid marginal method would have read ~1% green; the correct paired figure is 3.0% at the median. The conclusion holds and is now defensible: in the driest 5% of seasons the persistent cover protecting the soil is dead biomass, not living plants — the distribution is skewed (mean 11.8%, p95 56%), so the *median* is the honest headline.

**3c — the pale blob is a LAKE (re-probed at the actual centroid; the CSV I first shipped was the rim).** My first `blob_probe.csv` was the vegetated **rim** (n_NA = 0, flood 25.7%, class 23/40) — the wrong feature. Re-probed at the NA-hole centroid:

| | |
|---|---|
| area | **346.9 ha** (5,564 cells) |
| centroid (8058) | **(8,999,545, 4,349,484)** — ~5 km west of my first probe |
| inundation frequency | **91.4%** (min 51.4%) — near-permanent water |
| FC valid seasons | median **13** (5–49) — below `MIN_SEASONS` = 50 |
| veg_regime_class | **NA in all 5,564 cells** — outside the veg map |

**Verdict: a lake.** Water is persistent FC nodata → too few valid seasons → correctly NA. Not a claypan (would be dry, low inundation), not an artefact (coherent 347 ha feature). **The `MIN_SEASONS` threshold has a second job**, now recorded in the code: beyond making `p05` a percentile (n ≥ 40), it **stops the product fabricating a veg floor over open water**. Table shipped as `tier2H_h2_blob_probe.csv`.

### On p05 as canonical (#9) — logged as a consideration, not a strike
Its seasonal sensitivity is **real ecology**: because summer (DJF/MAM) is the lower-cover season, the across-series `p05` already ≈ the summer floor — the true worst case, which is exactly the resilience rationale. Being seasonally sensitive is what makes it a **floor** rather than an average. Recorded for the #9 decision.

### H6 · Absolute flood-zone raster — built, registered, reconciled

`Output/rasters/flood_zone_8058.tif` — five fixed zones (never / rarely <1:10 / occasionally 1:10–1:4 / regularly 1:4–1:2 / frequently >1:2), from the NN census frequency (no bilinear smoothing). **Fixed breaks, deliberately not quantiles**: terciles aren't comparable across communities and are unstable on tie plateaus, whereas 10/25/50% are stable and comparable everywhere.

- **PROOF asserted:** 0 census pixels land on any break — `freq = k/35` can never equal 3.5/35, 8.75/35 or 17.5/35, so the open/closed convention is immaterial (a proof, not an observation).
- **Reconciles to the independently-measured facts §9 cross-tab at max |Δ| = 0.05 pp** across all 20 community×zone cells.
- Registered `raster_flood_zone_8058` + `dim_metric.flood_zone` (pixel support). Map `H6_flood_zone_data.png` — the channel network reads correctly as "frequently," floodplain "regularly," margins "rarely," and the lake as a frequently-flooded blob. Feeds the `flood_zone` column of the H4 census parquet (data contract §3).

> **For Adrian:** "Other / minor units" — the context stratum nobody's looked at — is **50.8% regularly-flooded + 40.4% occasionally**, making it some of the *wettest* ground on the property (behind only Floodplain Woodland). Worth a line; it's currently unbanded context.

---

## H4 · Pixel census parquet — built, registered, all contract §7 assertions pass

**New script:** `scripts/03_inundation_products/15_build_pixel_census_parquet.R`.

`Output/census/gayini_pixel_census_8058.parquet` — **26.7 MB (zstd), 1,080,157 rows × 16 columns**, one row per valid census pixel, built strictly to `docs/Gayini_pixel_census_data_contract.md`. External asset, **never committed** (`Output/` gitignored). Read back verified with the exact contract schema:

`pixel_id` int32 · `x_8058`/`y_8058` float64 · `veg_regime_class` int8 · `community`/`regime_band` dictionary · `treed_context_flag` bool · `wet_years`/`valid_years` int8 · `flood_freq_pct` float32 · `flood_zone` int8 · `veg_p05…p50` float32.

**Acceptance (contract §7) — every assertion passed:**

| check | result |
|---|---|
| row count | **1,080,157** (= expected) |
| `pixel_id` unique, non-NA, ≤ 9,777,614 | ✅ (max 7,408,646) |
| **reconciles to `census_stratum` at diff = 0, all 11 strata** | ✅ (max \|diff\| = 0) — the *real* check (independent path), not the vacuous `veg_regime_class ↔ census_stratum` one |
| `valid_years == 35` for every focus row | ✅ |
| `flood_freq_pct` ∈ [0,100] and `== 100·wet/valid` | ✅ |
| `pixel_id → x/y` round-trip within ½ pixel | ✅ (max dx = dy = **0 m**) |
| monotone `p05 ≤ … ≤ p50` per row | ✅ (0 violations of 1,080,002 complete rows) |
| null counts per `veg_p*` | **155** each (consistent — the lake + heavy-cloud census pixels; not dropped, not filled) |

Registered `census_asset.census_pixel_8058` (new table, following the `raster_asset` pattern) with `grid_reference → raster_veg_regime_class_8058` populated — the `pixel_id` is meaningless without it (C2, why that registration was load-bearing).

> **Resolves a facts §12 open item:** all **91,326 context pixels are also 35/35 valid** (Woodland + Other were previously unverified). Every census pixel, focus and context, has full 35-year support.

QA + reconciliation: `tier2H_h4_qa.json`, `tier2H_h4_census_reconciliation.csv`.

---

### C9 / archive (done)
`.gitignore` un-ignores the two superseded Task F docs under `docs/archive/` (rest of archive still ignored); `docs/` root duplicates flagged for removal (user-placed). B5 tooling contradiction (`scripts/archive/` vs smoke test) logged in CLAUDE.md under "Known tooling conflicts"; `scripts/_deprecated/` left untouched.
