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

# Figure · Wetter country carries more cover in its poorest patches

**File:** `PARTREG_S2_three_periods_115_parts.png`
**Status:** `DRAFT` · 7 August 2026, second pass
**Audience:** Adrian, and the Nari Nari Tribal Council through him. **Nothing on the face is for us.**
**Panel order:** C, A, B — the whole record is the result, the two eras are the sensitivity test.

## Title

> Wetter country carries more cover in its poorest patches — in every period of the record

## Panel C

> C · whole record · 1988–2022

## Panel A

> A · cropping era · 1988–2013

## Panel B

> B · post-management · 2018–2022

## Legend keys

> conserved parts (ringed)
>
> larger circles are larger parts
>
> cropping-era line, for comparison (panel B)

## Legend

> Cover floor against inundation on the paddock × community part, three periods. Each point is one
> paddock × community part, 115 in total, averaged over the water years of its period; larger circles
> are larger parts, from 33 to 32,399 cells. Panel C shows the whole record, 1988–2022, slope +0.547
> (r 0.687, 95% +0.360 to +0.750); panel A the cropping era, 1988–2013, 26 water years, +0.592
> (r 0.684, +0.394 to +0.811); panel B the post-management window, 2018–2022, five water years,
> +0.324 (r 0.579, +0.192 to +0.462), with the cropping-era line dashed for comparison. The four
> years 2014–2017 fall in no period: control passed to the Nari Nari Tribal Council in 2013 and the
> irrigation bank cuts are dated 2018. All three intervals overlap, so the flatter post-management
> relationship is reported rather than claimed, and panels C and A share 26 years and are not
> independent. The same line fitted at paddock grain and registered differs from panel C by 0.0005,
> so cutting to the ecological unit does not move the expectation line. The three communities do not
> behave alike: Inland Floodplain rises with water at every step, from 66.7% cover in its driest
> fifth to 75.0% in its wettest, slope +0.285 (+0.18 to +0.40), while both chenopod slopes span zero
> across wetness ranges too narrow to establish a pattern. The pooled line is steeper than any of the
> three because it is lifted by differences between communities as much as by response to water
> within them, so part of any distance from the line is which community a part sits in. These slopes
> describe how places differ from one another over the long run, not what an extra point of
> inundation would add to a paddock, which is a different and smaller quantity. The eight conserved
> parts are ringed and no line is fitted to them: eight parts in one block of the property is not a
> comparison set.

## Methods

> Support: pixel, aggregated to part. Pixel-weighted by part cell count; unweighted slope +0.521.
> Intervals are 2,000 bootstrap draws resampling paddocks with replacement, clustered on `zone_fid`;
> 115 parts sit in 64 paddocks. No p-values. Every interval is conditional on the inputs being
> correct and carries sampling variation only, not the classification error of the satellite
> products.

## Sources

| number | source |
|---|---|
| +0.547 · r 0.687 · [+0.360, +0.750] | `PARTREG_part_regression_coefficients.csv`, fit `2.3_weighted` |
| +0.592 · r 0.684 · [+0.394, +0.811] | fit `S2_cropping_era_common` |
| +0.324 · r 0.579 · [+0.192, +0.462] | fit `S2_post_management_common` |
| +0.521, unweighted | fit `2.3_unweighted` |
| +0.285 · [+0.18, +0.40] Inland | fit `2.6_inland` |
| chenopod slopes span zero | fits `2.6_riverine` [−0.291, +1.121], `2.6_aeolian` [−6.438, +1.570] |
| 0.0005 against the registered paddock line | `floor_flood_slope_64pdk` against fit `2.3_weighted` |
| 66.7 → 75.0 across Inland wetness fifths | `cap_inland_floor_wetness_fifth_1` … `_5`, registered at pack v1.3 T0 |

## What changed in this pass, and why

**The eyebrow is gone.** `PACK v1.3 · PART GRAIN` is version control; it belongs in the filename and
the manifest, not on a page shown to the Council.

**The question title and its subtitle are gone together.** *"Does the cover-and-water relationship
change between eras?"* asks something the panels appear to answer, and panel B is visibly flatter
under the word *post-management*. The subtitle was the only thing standing between that and
*"management made it worse."* The new title states what the figure shows in every period.

**The three community lines are deleted.** One fitted line per panel. This also removes an
extrapolation defect: the Aeolian line was drawn to x = 60 on data ending at 19.7.

**The dashed cropping-era line stays in panel B.** It is a period line, not a community line, and
without it the legend's claim that panel B is flatter cannot be checked from the face.

**All lines are grey, thin, semi-transparent and drawn beneath the points.** Z-order matters as much
as colour: a line over the points obscures them however pale it is. Colour-by-community stays on the
markers, so the three clouds remain visible without three lines asserting three slopes.

**One continuous legend block, journal style** — no blank lines, no bold lead-ins, one body size and
one smaller size for the methods sentence.

## Superseded — kept, not deleted

~~Title: *Does the cover-and-water relationship change between eras? Not distinguishably. All three
slope intervals overlap. The post-management window rests on five water years.*~~

~~Subtitle: *2014–2017 is excluded. Control passed to the Nari Nari Tribal Council in 2013 and the
irrigation bank cuts are dated 2018. The four years between belong to neither window.*~~

~~The per-panel blocks and the five-block footer of the first pass, 7 August 2026, and the standalone
`PARTREG_S1_floor_vs_flood_115_parts.png`.~~

---

# Figure · Which parts hold more or less cover than their water predicts

**File:** `PARTREG_S2_residual_maps_three_periods.png`
**Status:** `DRAFT` · 7 August 2026, second pass — caption restyled to match the scatter
**Panel order:** C, A, B, as on the scatter.

## Title

> Which parts hold more or less cover than their water predicts

## Legend

> Residual from the fitted cover-and-water expectation, mapped on the paddock × community part, three
> periods. Each panel is measured against its own period's fitted line, so the three read as one
> comparable set: panel C the whole record 1988–2022, panel A the cropping era 1988–2013, panel B the
> post-management window 2018–2022. The four years 2014–2017 fall in no period. 115 parts are
> mapped; 27 paddocks hold a single community and appear undivided, which is not missing data. Blue
> is more cover than the part's water predicts and red is less, on one common colour scale across
> all three panels with ticks at ±8.1 and ±16.2 pp. 8.08 pp is the average miss across all parts, not
> the typical miss anywhere in particular: distance from the line is about three times larger on the
> driest quarter of the property than on the wettest, near 12.8 pp against 3.8 pp, so dry parts
> appear more extreme and wet parts less extreme than they are relative to their own country.
> Compare a part to others at similar wetness, not to the whole map. No cause is attributed — a
> residual is a departure from a fitted expectation, not condition and not management — and the line
> is fitted across all three communities pooled, so part of any residual is which community the part
> sits in. The eight conserved parts are outlined dashed and no line is fitted to them.

## Methods

> Support: pixel, aggregated to part. 115 parts, whole record 1988–2022. Residuals are measured
> against each period's own fitted line. Every interval behind these numbers is conditional on the
> inputs being correct and carries sampling variation only, not the classification error of the
> satellite products.

## Sources

| number | source |
|---|---|
| 8.08 pp | fit `2.3_weighted`, `resid_sd` |
| 12.8 pp driest quarter · 3.8 pp wettest | `cap_residual_sd_water_quartile_1` … `_4`, registered at pack v1.3 T0 |
| +0.547 · +0.592 · +0.324 panel slopes | fits `S2_whole_record_common`, `S2_cropping_era_common`, `S2_post_management_common` |

## What changed in this pass, and why

**The caption is now one continuous block in two sizes**, matching the scatter. It had three
paragraphs separated by blank lines beneath a rust-coloured subtitle above a grey body — three
treatments where the scatter has two. Two figures in one pack styled differently reads as unfinished.

**The rust subtitle is absorbed into the legend.** It carried the per-period basis and the
single-community note, both of which belong in the legend text rather than in a second heading.

## Superseded — kept, not deleted

~~The rust subtitle and the three-paragraph footer of the first pass, 7 August 2026.~~

~~The original tick note, which let 8.08 pp read as the typical miss everywhere.~~

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
