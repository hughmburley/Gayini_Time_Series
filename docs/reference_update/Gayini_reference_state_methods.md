# Gayini reference-state analysis — methods

**Version:** v2 · 28 July 2026
**Supersedes:** v1 (same date). Changes: §6 community and three-arm figures re-pinned per
T8; L-3 closed by measurement; L-4 reframed; three limitations added; 12,179 ha corrected to
12,150 ha; new §9 on pinned numbers.
**Scope:** Tasks T1, T2, T6. Covers the data, the metrics, the comparison design, and the
limits of what the design can support.
**Authority:** `Gayini_Results.sqlite` is the source of truth. Where this document and the
database disagree, the database wins.

---

## 1. The question

The analysis was commissioned to answer a specific question: since management changed, are
the formerly-cropped paddocks moving toward the condition of the conserved paddocks? Are
they on a trajectory of improvement toward a reference state?

The design template is Dawson et al. (2016), which measured restoration on a formerly
cultivated floodplain in the Macquarie Marshes by computing a similarity distance between
each restoring pixel's fractional-cover time series and an intact reference community. That
paper found restoration was inundation-dependent and governed by prior land-use intensity.

A distance-to-reference design needs three things: a reference set that is internally
consistent, a reference set distinguishable from the treated set, and a reference condition
that is a plausible target. Sections 5 and 6 report what the data says about each.

**One substitution had to be made, and it governs everything downstream.** Cropping history
for Gayini is unrecorded. `dim_management_zone` carries five columns reserved for it —
`cropping_history`, `land_use_era`, `irrigation_status`, `history_source`,
`history_confidence` — created deliberately empty at T1 Gate B and still NULL for all 64
paddocks. The analysis therefore substitutes the grazing treatment layer, which does exist,
for the land-use history, which does not. Every contrast reported here is **not-grazed
versus grazed**, not conserved versus formerly-cropped. The four "No grazing" paddocks are a
management category, not a verified undisturbed state.

---

## 2. Study units and data

**The property.** Gayini (Nimmie-Caira), 85,911 ha on the lower Murrumbidgee. The mapped
census covers 67,349 ha; **18,562 ha (21.6%) lies outside the mapped extent** and appears in no
analysis in this document.

Separately, **12,150 ha (18.0% of the mapped census) lies inside the census but outside every
management zone** — 194,865 pixels. These two quantities are disjoint, and both describe
"missing area", so they are easily confused. Together, **30,712 ha — 35.7% of the property — is
in no management zone at all.**

The unzoned figure was previously stated as 12,179 ha. That was wrong: it used the nominal
25 m pixel area (0.0625 ha) rather than the derived constant for the 24.970268 m grid
(0.062351428 ha, `gayini_params.PIXEL_AREA_HA`). Corrected 28 July.

**Paddocks.** 64 management zones from the GeoPackage `management_zones` layer, joined by
`fid`. Sixty are `14-day grazing`; four are `No grazing` (Bala 26ca, 27ca, 28ca, 29ca). A
third category, standard grazing, exists on the ground but has no polygon in the zone layer —
see §7.

**Strata.** Nine non-treed vegetation × wetness strata: three communities (Aeolian Chenopod
Shrublands, Riverine Chenopod Shrublands, Inland Floodplain Shrublands/Swamps) × three
wetness bands (low, mid, high). Treed context pixels are excluded throughout, because canopy
confounds a ground-cover signal. Scope filter: `treed_context_flag = FALSE AND regime_band <>
'context'`.

**Pixels.** The all-pixel census holds 1,080,157 pixels on the canonical EPSG:8058 grid at
24.970268 m. Of these, 795,602 are non-treed and fall inside a management zone; 988,831 are
non-treed in scope including unzoned ground.

**Vegetation.** JRSRP Landsat fractional cover, total vegetation = photosynthetic +
non-photosynthetic. Two annual rasters, 35 layers each, WY1988–89 to WY2022–23:
`total_veg_annual_mean_8058.tif` (mean of available seasons, primary) and
`total_veg_annual_jja_son_8058.tif` (winter/spring mean, robustness). Values are percent with
no JRSRP +100 offset; the legend gate is closed and confirmed in `raster_asset`.

**Inundation.** NSW DCCEEW annual wet/valid stacks, 35 layers each, presence-only encoding
(valid = 1, nodata → NA, no zero). Flood fraction = 100 × wet pixels ÷ valid pixels.

---

## 3. The floor metric — and the one that is easy to confuse it with

The project uses two different fifth-percentile statistics. They answer different questions
and must never appear in the same figure or be compared numerically.

| | `veg_p05_spatial` (used here) | census `veg_p05` |
|---|---|---|
| Collapses over | pixels, within one year | years, within one pixel |
| Answers | how much cover does the worst-covered 5% of this paddock carry | what cover level does this pixel hold 95% of the time |
| Unit | paddock-year | pixel |
| Meaning | spatial patchiness | temporal drought floor |
| Built by | T2 Gate B | Task H census |

Everything in the reference-state analysis uses **`veg_p05_spatial`** — a within-year spatial
percentile. It is a measure of how much poorly-covered ground a paddock carries in a typical
season. It is *not* a drought floor, and it should not be described as "what survives the
worst season."

The column is named `veg_p05_spatial` specifically so the distinction cannot be lost, per the
T2 spec, and no column called plain `veg_p05` exists in `fact_zone_veg_annual`.

The floor was chosen over the mean on ecological grounds carried over from the census work:
the lower percentile is the part of the distribution where a flood signal is visible, whereas
the mean and median sit high and flat and undersell it. Mean cover is retained throughout as
a companion so the two can be read together — see §6.

---

## 4. Extraction and aggregation

**T2 Gate B — paddock time series.** Both annual veg stacks are extracted at the 795,602
in-scope zoned census centroids. For each paddock × water year × series variant the following
are computed across pixels: `n_pixels_valid`, `veg_mean`, `veg_median`, `veg_p05_spatial`,
`veg_p10_spatial`, `veg_p25_spatial`. Quantile type 7. Values are kept raw — the handful
above 100 are bilinear-resampling overshoot and are flagged, not clamped.

Inundation is extracted in a separate pass and produces zone-year counts only. **Open water
is not masked out of the vegetation percentile.** Water reads as low fractional cover, so a
paddock holding persistent water carries a depressed floor for reasons unrelated to
management. This is a known and unhandled limitation (§7).

**Minimum support.** A paddock-year is dropped where `n_pixels_valid < max(500, 30% of the
paddock's non-treed pixel count)`. The rule is recorded in the table, not hardcoded silently.
A separate, looser floor of 30 pixels per cell applies at the paddock × community grain used
for the trajectory figure.

**Two grains, one extraction.** Grain 1 is paddock × year (`fact_zone_veg_annual`, 4,356
rows). Grain 2 is paddock × community × year (`fact_zone_community_veg_annual`, 8,142 rows),
so a paddock spanning several communities appears in each — a single dominant-community label
would hide that Bala 29ca reads 29 / 67 / 35 across its three.

**T6 — the third arm.** All 15 standard-grazing monitoring plots fall outside the zone layer,
so standard grazing has never been measured. T6 extracts a third arm from the unzoned mapped
area at **stratum grain** (community × wetness band), which controls for wetness by
construction. Three arms result: `not_grazed`, `unzoned_inferred_standard` (the whole unzoned
mapped area), and `unzoned_plot_confirmed` (the subset containing standard-grazing plots).

**Aggregation order matters and is stated.** For the period table in §5, reference values are
each paddock's mean over the period; the grazed comparator is the median across the 60
paddocks taken *within each year*, then averaged over the period. Median does not commute
with mean, and doing it the other way moves the 1993–2002 figure by 1.7 pp.

---

## 5. Result — the reference set is one paddock

Gap to the grazed median on the floor, in percentage points:

| Period | Reference ×4 | gap | Reference ×3 (no 29ca) | gap | Bala 29ca | gap |
|---|---|---|---|---|---|---|
| 1988–1992 | 68.1 | −13.1 | 77.8 | **−3.3** | 38.9 | −42.3 |
| 1993–2002 | 58.8 | −11.4 | 68.0 | **−2.2** | 31.2 | −39.0 |
| 2003–2012 | 57.0 | −7.9 | 63.1 | **−1.8** | 38.8 | −26.2 |
| 2013–2018 | 65.4 | −5.7 | 69.6 | **−1.6** | 53.0 | −18.2 |
| 2019–2022 | 63.9 | −5.6 | 68.0 | **−1.5** | 51.6 | −18.0 |

Without Bala 29ca the reference paddocks track the grazed median within 1.5–3.3 pp for
thirty-five years. The whole reference-versus-grazed difference is one paddock.

**Timing rules out the intended explanation.** The gap is present in 1988–92 at −13.1 pp.
Management changed in 2018–19. The narrowing is monotonic from 1988 onward. Both the gap and
its closure predate the intervention by three decades.

**Bala 29ca's role in the wider project.** It holds 13 of the 24 reference monitoring plots
(54%), supplied 93% of the reference pixels behind T1's Riverine-low contrast, and is the
only reference paddock containing any Aeolian country — 32.3% of its pixels, against 0.0% for
each of the other three. Every reference-state number the project has reported traces to it.

**T1's matched contrast collapses the same way.** At all-zone pixel weighting the Riverine
bands show +7.5 to +8.3 pp; restricted to Bala paddocks at zone support they fall to +3.6,
+0.1 and −2.1. The apparent grazing effect was block structure.

**The seasonal window does not change this.** Under `jja_son` the Bala 29ca gap runs −38.5 →
−18.3 against −42.4 → −18.1 for `mean_of_seasons`, and the three-paddock gap stays 1.1–2.2 pp.

---

## 6. Result — mean versus floor, and the third arm

**The reference paddocks match or exceed grazed on mean cover, and sit below on the floor.**
Reference minus grazed, by community, area-weighted across the three wetness bands within each
community: mean cover **−2.3** (Aeolian), **+1.4** (Riverine), **+0.5** (Inland); floor
**−10.5**, **−4.5**, **+1.1**. They are not less vegetated — in two of three communities they
carry *more* average cover than grazed ground — but they carry a longer tail of poorly-covered
ground.

These figures supersede an earlier set (mean −3.0 / −0.8 / +1.8; floor −19.6 / −11.7 / +1.1)
which came from the `regime_band = 'ALL'` rollup row. That row pools across wetness bands,
which undoes the stratification the design exists to provide, and the reference paddocks sit
in drier bands than their comparators — so the pooled figures were inflated by the very
confound the banding removes. The rollup rows are retained in the database and flagged
`is_rollup = 1`; they are not to be used for treatment contrasts.
Bala 29ca's median cover is 75.6% against a grazed median of 81.6%, a 6 pp difference, while
its floor sits 29 pp below. The headline gap is a statement about the worst-covered ~120 ha
of a 2,421 ha paddock.

**Within-reference spread exceeds the treatment contrast in 6 of 9 strata** — every Riverine
band and every Inland Floodplain band. In Riverine-high the four reference paddocks span 29.8
to 66.3% floor while the reference-grazed contrast is −2.1 pp. A fixed distance-to-reference
target is undefined in those strata.

**Grazing intensity does not order the floor.** Area-weighted across the nine strata:
not-grazed **−0.9 pp** against the 14-day comparator, unzoned inferred-standard **+1.2**,
unzoned plot-confirmed **+1.3**. All three arms sit within about two percentage points of each
other. The inferred-standard arm sits at or above 14-day in 6 of 9 strata and the
plot-confirmed subset in 8 of 9.

An earlier equal-weighted version gave −4.8 / +4.3 / +5.9. Equal weighting across nine strata
gives the Aeolian bands a third of the total weight on 7.8% of the area, and Aeolian is the
stratum where the reference set is a single paddock with the largest deficits — so equal
weighting handed Bala 29ca roughly a third of a property-level number. The ordering survives
either weighting; the magnitudes do not. The consistency claim therefore rests on the
weighting-free counts above, not on the mean. Two readings are consistent with this and the data cannot
separate them: either grazing intensity does not register in the floor at all, or the unzoned
land is less grazed rather than more, making the ordering real with the inference inverted.
Resolving it requires talking to Nari Nari, not further computation.

**The gap narrows by different mechanisms in different communities.** Comparing 1988–97 with
2013–22: Aeolian +8.4 pp because the reference side rose (+14.8 against grazed +6.3); Riverine
+13.5 pp because the grazed side fell (−9.0 against reference +4.5); Inland −0.8 pp with both
falling together. The narrowing is not confined to wet years — in non-flood years alone the
figures are +9.7, +12.3 and +0.6.

---

## 7. Limitations

**Cover, not condition.** Landsat fractional cover measures how much cover is present, not
whether it is native or introduced, nor its structure or health. The same value can mean
irrigated cropping early in the record and re-established chenopod later.

**Not grazed is not conserved.** Cropping history is unrecorded. This is not the
conserved-versus-formerly-cropped comparison the design called for.

**Open water inside the floor metric — TESTED AND CLOSED.** Water is not masked before the
percentile is taken, and the concern was that it would read as low cover and depress the floor
in the wetter paddocks. Tested directly on 28 July at the 795,602 in-scope pixels. The premise
is false in both available forms:

- Across all in-scope pixel-years, wet pixels carry **more** cover than dry at every
  percentile, and the gap is largest at the floor: mean +10.3 pp, p05 **+24.4 pp**. The pattern
  holds in all four reference paddocks (p05 +18.8 to +31.3).
- Of the pixels that actually *set* each paddock-year's floor — the bottom 5% — wet pixels are
  **under**-represented relative to the paddock's overall wet share: Bala 26ca 14.7% against
  45.3%, 28ca 8.8 against 43.3, 27ca 16.5 against 29.7, 29ca 2.3 against 7.8.

Inundation greens this floodplain rather than reading as bare water; the deep permanent water
bodies for which the concern is real are largely excluded by the treed and in-scope filters.
Masking water would remove the highest-cover observations and push the floor **down**. The
low-cover tail is dry vegetation. Dawson et al. excluded flooded images for a comparable
concern on a different sensor configuration; it does not apply here.

**The paddock-scale comparison is not wetness-controlled — OPEN, and the wording matters.**
T6 controls wetness by constructing the contrast within stratum. T1 reports flood-frequency
deltas alongside vegetation deltas so the relationship is visible. The §5 period table does
neither: it compares whole paddocks.

Across all 64 paddocks the floor tracks mean annual inundation at r = 0.710, slope +0.548 pp
per pp of flood frequency (independently computed and registered as
`floor_flood_slope_64pdk` / `floor_flood_r_64pdk`). Bala 29ca is the fourth-driest paddock on
the property at 8.5% inundation against a grazed median of 28.6%. Fitting that relationship, a
paddock as dry as Bala 29ca would be predicted at roughly 57% floor against an observed 40.5%.

**This is not a confound in the usual sense, and calling it one was wrong.** The L-3 result
above shows water is not a measurement artefact contaminating the floor — water is the
ecological driver of it. Drier paddocks genuinely carry lower floors because they genuinely
carry less cover in their worst ground. So the between-paddock relationship is the main effect,
not noise to be removed, and the management question is what remains after it. Quantifying
that remainder is Task T10, not started as of this version.

**Aeolian reference is n = 1 — and the grain matters.** At stratum grain Bala 29ca is the only
reference paddock containing any Aeolian country (32.3% of its non-treed pixels; the other three
are 0.0%), which is why `n_ref = 1` on every Aeolian figure. At paddock grain it is *not*
Aeolian-dominant and has no dominant community at all — Inland 34.6%, Riverine 33.1%, Aeolian
32.3%, the lowest dominance of the 64 paddocks. Both statements are true and describe different
things; either without its grain is misleading. No community-level Aeolian claim can rest on
this paddock, and no dominant-community adjustment can be applied to it.

**The third arm is inferred.** "Unzoned mapped area" is inferred to be standard grazing
because 8 of the 15 standard-grazing plots fall on it. It is not confirmed.

**A fifth of the property is absent, and a third is in no paddock.** 18,562 ha (21.6%) lies
outside the mapped census, including 7 of the 15 standard-grazing plots. A further 12,150 ha
sits inside the census but outside every management zone. Together 30,712 ha — 35.7% of
Gayini — is in no management zone.

**Bala 27ca holds no monitoring plots.** The 24 reference plots divide as Bala 29ca 13,
28ca 8, 26ca 3, **27ca 0**. Bala 27ca is one of the three paddocks carrying the central
finding that the reference set is indistinguishable from grazed ground, and there is no
ground observation in it at all. Verified by an independent centroid-in-polygon join,
EPSG:9473 → 8058, zero mismatches across all 66 plots.

**The floor deficit is confined to a small area within a paddock.** Bala 29ca's median cover
is 75.6% against a grazed median of 81.6% — a 6 pp difference — while its floor sits 29 pp
below. Its p25 is only 9 pp below. The headline gap is therefore a statement about roughly the
worst-covered 120 ha of a 2,421 ha paddock, not about the paddock as a whole.

**The reference paddocks are administratively grouped but spatially dispersed.** All four
carry the Bala prefix, so any whole-farm contrast is confounded with property block. But
their centroids span 30 km: Bala 26ca and 27ca sit 3.4 km apart among Bala paddocks, 28ca
abuts Mara 16/17/22, and 29ca abuts Dinan 7/8/9. Whether the shared label reflects shared
management history is a question for Nari Nari.

---

## 8. Reproducibility

| Step | Script | Output |
|---|---|---|
| Scope export (zoned) | `T2_gateB_prep.py` | `T2_in_scope_points.csv`, `T2_zone_denominator.csv` |
| Paddock extraction | `T2_gateB_extract.R` | `fact_zone_veg_annual`, `fact_zone_community_veg_annual` |
| Trajectory figure + gap report | `T2_gateE_figures.R` | `T2_E_*`, `T2_B2_duration_map`, `T2_E_gap_report.csv` |
| Gap decomposition | `T2_gateF_figure.R` | `fact_reference_gap_decomposition`, `T2_F_*` |
| Plot-to-paddock join | `T2_plot_paddock_join.R`, `T2_gateG_figure.R` | `T2_G_*` |
| Zone dimension and matched contrast | `T1_gateA/B1/C/D_*.R` | `dim_management_zone`, `v_zone_stratum_treatment_contrast` |
| Scope export (all arms) | `T6_gateB_prep.py` | `T6_in_scope_points.csv`, `T6_zone_arm_map.csv` |
| Three-arm extraction | `T6_gateB_extract.R`, `T6_gateB_components.R` | `fact_three_arm_stratum_veg_annual` |
| Three-arm figures | `T6_gateE_figures.R` | `T6_A_*`, `T6_B_*` |

**Gap in the chain — confirmed by exhaustive search, logged as I-29 (BLOCK).** The
five-period split in §5 is produced by no script in the repository. All 429 tracked text files
were searched for the five boundary years; the only files carrying three or more are Task J
(2018 bank-cut periods) and T12 (DEA sensor eras), both different splits.
`T2_gateE_figures.R` writes a two-window report instead (early ≤1997, late ≥2013, ±2 pp
narrows/widens/holds rule).

The §5 figures therefore have no producing script and must not go into a deliverable in that
form. The narrowing itself is not in doubt — it is monotonic under equal decades, equal thirds
and the two-window split as well — so the boundaries were not doing the work. But undocumented,
unequal boundaries (5, 10, 10, 6 and 4 years) of unknown provenance should be replaced rather
than reconstructed. T10 Gate B replaces them with an annual gap series and a fitted trend,
which removes the boundary decision from the analysis. Not started as of this version.

**Standing rules.** Additive writes only; never re-run the builder; resolve paths from the
database rather than hardcoding; never merge support levels in one figure; every headline
number carries support level, scope filter, pixel constant, denominator and period label.

---

## 9. Pinned numbers

Every number in this document that reaches a deliverable is registered in
`dim_headline_number` (35 rows, built 28 July, T8). Each row carries the source object, grain,
aggregation order, series variant, scope filter, period label, denominator and pixel constant,
together with the pinned value and the **full spread that value takes under defensible
alternatives**.

The table exists because the numbers were under-specified rather than wrong. The
reference-minus-grazed floor gap for 1988–92 takes eight values between −9.1 and −14.8 pp
depending on grain, aggregation order and seasonal variant; all eight are defensible and all
eight come from the same database. Six pin decisions were taken to resolve this class:

| pin | decision |
|---|---|
| 1 | Community contrasts use the band mean, not the `regime_band = 'ALL'` rollup |
| 2 | Paddock grain, year-first ordering, `mean_of_seasons`; `jja_son` as a registered sensitivity |
| 3 | The three periodised numbers stay unpinned (`pinned_value` NULL), blocked on I-29 |
| 4 | The 13-of-24 plot share is re-derived from `plot_paddock`, not `plot_management_overlay` |
| 5 | "Missing area" splits into three disjoint numbers |
| 6 | Multi-stratum means are area-weighted, not equal-weighted |

Pins 1 and 6 together changed ten reported values; the before-and-after table is
`Output/tables/T8_before_after.csv`. Both moved the results toward more conservative
conclusions.

A reproduction test (`test_T8_headline_reproduction.py`) re-derives all 32 pinned values from
their source objects by an independent code path and fails on drift, demonstrated against a
deliberately corrupted fixture. **It is not wired into the smoke test** — the existing suite
carries permanently-red checks (I-10, I-11) and hooking in would buy the appearance of
coverage rather than coverage. It runs standalone and exits non-zero. Wiring is I-19,
post-deadline.

**Standing rule.** Any number produced in a design-seat session is a prediction to be checked,
never a target to reconcile to. Where an independently computed value disagrees with a
design-seat value, the computed value stands and the disagreement is the finding.
