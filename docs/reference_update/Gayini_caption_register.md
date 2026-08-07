# Gayini — caption register

**Started 7 August 2026.** One place for finished caption text.

**Why this file exists.** Captions are prose and QA2 pass 3 records that they have never been
checked as a class. They are also the part of a figure most likely to be quoted and least likely to
be re-derived. Holding them in one file means a number that changes can be traced to every sentence
that carries it.

**Scope.** Deliverable captions now. Article figure legends later — the two differ in audience and
length but not in discipline, and a caption that survives the deliverable is the right starting
point for a legend.

---

## How to use this file

**One section per figure.** Each carries: the figure's registered filename, its status, the caption
text as it should appear, and the source of every number in it.

**Every number in a caption cites where it came from** — a `fit_id`, a `number_id`, or the table it
was computed from. A caption number with no source is treated as unverified and does not ship.

**Status values:** `DRAFT` · `APPROVED` · `RENDERED` · `SUPERSEDED`. A superseded caption is struck
through and kept, never deleted, so a figure circulating in an old deck can be traced to the text it
carried.

**House voice.** Short declaratives. Bolded lead claim, then the support. Plain nouns. A stated limit
rather than a hedge. Numbers with their interval where one exists. No p-values. The test from the
deliverables register applies: one claim, one sentence a non-specialist can follow.

---

# Figure · Does the cover-and-water relationship change between eras?

**File:** `PARTREG_S2_three_periods_115_parts.png`
**Status:** `DRAFT` · 7 August 2026
**Panel order:** C, A, B — whole record first, then the two eras.
**Supersedes:** the as-rendered caption of 6 August, and the standalone
`PARTREG_S1_floor_vs_flood_115_parts.png`, whose panel A duplicated panel C and whose percentile
sweep moves to the methods document.

## Title

> **Does the cover-and-water relationship change between eras?**
> **Not distinguishably.** All three slope intervals overlap. The post-management window rests on
> five water years.

## Subtitle

> 2014–2017 is excluded. Control passed to the Nari Nari Tribal Council in 2013 and the irrigation
> bank cuts are dated 2018. The four years between belong to neither window.

## Panel C · whole record · 1988–2022

> One point per paddock × community part. 115 parts, each averaged over 35 water years. Slope
> +0.547, r 0.687, 95% [+0.360, +0.750].
>
> The same line was fitted at paddock grain and registered. The two differ by 0.0005. Cutting to the
> ecological unit does not move the expectation line.
>
> **The three communities do not behave alike.** Inland Floodplain rises with water at every step,
> from 66.7% cover in its driest fifth to 75.0% in its wettest. Its slope is +0.285, interval +0.18
> to +0.40. Riverine Chenopod is flat across four fifths of its range and lifts only in the wettest.
> Aeolian Chenopod carries its highest cover in its driest parts. Both chenopod slopes span zero.
> Their wetness ranges are too narrow to establish a pattern.
>
> **The pooled slope is steeper than any of the three.** It is lifted by differences between
> communities as much as by response to water within them. Part of any distance from the line is
> which community a part sits in.

## Panel A · cropping era · 1988–2013

> 26 water years. Slope +0.592, r 0.684, 95% [+0.394, +0.811].

## Panel B · post-management · 2018–2022

> Five water years. Slope +0.324, r 0.579, 95% [+0.192, +0.462]. The cropping-era line is drawn
> dashed for comparison.
>
> The relationship is flatter here. The interval overlaps both others. This is reported, not claimed.

## Footer

> **Only the fitted relationships are compared.** Period levels are not. A slope is robust to how wet
> a window happened to be, because both axes move together. A mean is not.
>
> **The whole record contains both eras.** Panels C and A share 26 years. They are not independent.
>
> **These slopes describe how places differ from one another over the long run.** They are not what
> an extra point of inundation buys a paddock. That is a different quantity and it is smaller.
>
> **The eight conserved parts are ringed. No line is fitted to them.** Eight parts in one block of
> the property is not a comparison set.
>
> Support: pixel, aggregated to part. Pixel-weighted by part cell count; unweighted slope +0.521.
> Intervals are 2,000 bootstrap draws resampling paddocks, clustered on `zone_fid`. 115 parts sit in
> 64 paddocks. No p-values. **Every interval here is conditional on the inputs being correct**: it
> carries sampling variation only, not the classification error of the satellite products themselves.

## Sources

| number | source |
|---|---|
| +0.547 · r 0.687 · [+0.360, +0.750] | `PARTREG_part_regression_coefficients.csv`, fit `2.3_weighted` |
| +0.592 · r 0.684 · [+0.394, +0.811] | fit `S2_cropping_era_common` |
| +0.324 · r 0.579 · [+0.192, +0.462] | fit `S2_post_management_common` |
| +0.521, unweighted | fit `2.3_unweighted` |
| +0.285 · [+0.179, +0.404] Inland | fit `2.6_inland` |
| Riverine and Aeolian slopes span zero | fits `2.6_riverine` [−0.291, +1.121], `2.6_aeolian` [−6.438, +1.570] |
| 0.0005 against the registered paddock line | `floor_flood_slope_64pdk` against fit `2.3_weighted` |
| 66.7 → 75.0 across Inland wetness fifths | `cap_inland_floor_wetness_fifth_1` … `_5`. Reproduced in R at pack v1.3 T0 and **registered**; pixel-weighted bins of `PARTREG_part_residuals.csv` |

## Notes on what was cut

The spread-ratio paragraph moves to the methods document. It is a strong argument and it was set at
8pt beneath three other paragraphs.

The opacity legend goes. Across-year spread does minor work in this figure and the legend read as a
fourth data series.

"Marker area ∝ part size" appears on panel C only.

---

# Figure · Which parts hold more or less cover than their water predicts

**File:** `PARTREG_S2_residual_maps_three_periods.png`
**Status:** `DRAFT` · 7 August 2026 — footer replacement only, panels unchanged

## Footer, replacing the current tick note

> One common colour scale across all three panels, at ±8.1 and ±16.2 pp. **8.08 pp is the average
> miss across all parts. It is not the typical miss anywhere in particular.** Distance from the line
> is about three times larger on the driest quarter of the property than on the wettest — near 12.8
> pp against 3.8 pp. Dry parts therefore appear more extreme, and wet parts less extreme, than they
> are relative to their own country. Compare a part to others at similar wetness, not to the whole
> map.
>
> No cause is attributed. A residual is a departure from a fitted expectation. It is not condition
> and it is not management. The line is fitted across all three communities pooled, so part of any
> residual is which community the part sits in.
>
> Support: pixel, aggregated to part. 115 parts, whole record 1988–2022. Residuals are measured
> against each period's own fitted line. **Every interval behind these numbers is conditional on the
> inputs being correct** — sampling variation only, not the satellite products' own classification
> error.

## Sources

| number | source |
|---|---|
| 8.08 pp | fit `2.3_weighted`, `resid_sd` |
| 12.8 pp driest quarter · 3.8 pp wettest | `cap_residual_sd_water_quartile_1` … `_4`. Reproduced in R at pack v1.3 T0 and **registered**; sample (n−1) SD within type-7 quartiles |

**This footer change is not optional.** The current wording invites a reader to treat 8.08 pp as a
typical miss everywhere, which overstates dry parts and understates wet ones. Bala 29ca's two dry
thirds are the parts most affected.

---

# Pending

Captions not yet drafted, listed so the gap is visible rather than forgotten.

| figure | note |
|---|---|
| `SCHEM1_figure25_axis_chain.png` | carries its own text; needs a caption for the article |
| `SCHEM2_pictorial.png` | as above |
| UNZONED Stage A scatter | parked with the task |
| DIAG-1 diagnostic panels | parked with the task |
| the 66 paddock and site reports | captions live in the report template, not here yet |
