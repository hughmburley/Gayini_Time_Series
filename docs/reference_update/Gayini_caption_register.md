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
>
> r 0.687   ·   weighted R² 0.47

## Panel A

> A · cropping era · 1988–2013
>
> r 0.684   ·   weighted R² 0.47

## Panel B

> B · post-management · 2018–2022
>
> r 0.579   ·   weighted R² 0.34

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
| weighted R² 0.47 · 0.47 · 0.34 | r² of the stored `r` on fits `2.3_weighted`, `S2_cropping_era_common`, `S2_post_management_common`. Not refitted. **Weighted**, because the fits are pixel-weighted by part cell count and an unqualified R² invites an unweighted recomputation |
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

# Figure · The same country, two ways of looking at it

**File:** `M5_dual_grain_floor_and_flood.png`
**Status:** `DRAFT` · 7 August 2026 — **corrected under Ruling AY, not yet re-rendered**
**Producer:** `scripts/12_zone_stratum/build_T11_v2_dual_grain.R`

## Colour-scale labels

> cover scale: veg_p05_spatial (%)
>
> flood scale: share of cells seen wet (%), mean over years

## Caption clause, corrected

> Top row is how much cover the poorest patches carry; bottom row is what share of its cells were
> seen wet in a year, averaged over the record. That is a within-year extent, not how often the
> ground floods — between-year flood frequency is a different quantity with no time axis.

## Superseded — kept, not deleted

~~Cover scale label: `veg_p05 (%)`. The panels plot `AVG(veg_p05_spatial)`, so this named the census
temporal floor — the pair the ground-cover metadata record calls the most confusable in the project.~~

~~Flood scale label: `flood (% yrs)`. The panels plot `AVG(flood_frac_pct)`, a share of cells within
a year. `% yrs` asserts a denominator of years and names `census_flood_frequency_pct`.~~

~~Caption clause: *"bottom row is how often the ground floods"* — the between-year framing of a
within-year quantity.~~

**Not re-rendered.** The producer registers as it renders, and registration is gated. The registry
row still carries the superseded caption; updating it is proposed, not written. Carried as **C6** in
the V12→V14 change list.

---

# Figure · Cover follows water, and the exceptions are the story

**File:** `F5_cover_vs_water_64_paddocks.png` — methods document Figure 25
**Status:** `RENDERED` · 7 August 2026 — **corrected and re-registered under Ruling AZ**
**Producer:** `scripts/12_zone_stratum/build_adrian_pack_T1_F3_F5.R`

## Axis labels

> x: Share of the paddock's cells seen wet, mean over years (%)
>
> y: Cover floor, veg_p05_spatial (%)

## Caption clause, corrected

> How much cover a paddock holds in its poorest seasons rises with how much of it goes under —
> wetter paddocks sit higher. This is a within-year extent averaged over the record, not how often
> the paddock floods, which is a between-year quantity with no time axis.

## Superseded — kept, not deleted

~~x-axis: `Mean annual flood frequency (% of years wet)`. The axis plots `mean_flood` from
`v_zone_floor_flood_residual` — the mean over 35 years of `flood_frac_pct`, a share of the paddock's
CELLS seen wet within a water year. `(% of years wet)` states a denominator of years and so names
`census_flood_frequency_pct`, a per-cell property with no time axis. **Ruling AY's family, third
instance.**~~

~~Caption: *"largely set by how often it floods"* — the between-year framing of a within-year
quantity.~~

~~`PACK1_build_workbook.py`, three occurrences of *"how often a paddock floods"* on the same fit.
Corrected at source; the pack v1.2 workbook that shipped still carries them.~~

**The y-axis was already correct** and is unchanged. The same `labs()` call named the cover quantity
precisely and got the water quantity's denominator wrong — which is the shape of this whole error
family.

**Not changed, and noted:** the subtitle still reads *"52.7 + 0.548 x flood %"*. `flood %` is
ambiguous rather than wrong, so it is left alone under Ruling AZ's scope.

---

# Figure · Wetter country holds more cover in its poorest seasons

**File:** `PARTSCATTER_part_temporal_p05_vs_water.png`
**Status:** `RENDERED` · 9 August 2026, second pass — amendments A1–A5
**Producer:** `scripts/14_diag/PARTSCATTER_prepare.py` → `R/diag/PARTSCATTER_figure.R`
**Audience:** the client, replacing the 64-paddock figure in his Monday deck. In our own
record the paddock-grain figure stands and is **not** superseded.
**Register:** article. Subtitle says what you are looking at; the footnote answers what a
careful reader will ask, one item per question, in a fixed order.

## Title

> Wetter country holds more cover in its poorest seasons

## Axis labels

> x: Share of the area's cells seen wet, mean over years (%)
>
> y: 5th-percentile ground cover, mean of cells (%)

## Subtitle

> Each point is one paddock cut to a single vegetation community — 100 areas across 64
> paddocks, sized by the number of cells each holds. In Inland Floodplain country, cover
> rises across areas ranging from 6% to 59% of cells wet; in Riverine Chenopod, from 3%
> to 33%. Aeolian Chenopod areas are all dry — eleven of the twelve sit below 7% — so no
> line is fitted to them.

## Legend keys

> Vegetation community
>
> Inland Floodplain — n 61 · r +0.70
>
> Riverine Chenopod — n 27 · r +0.71
>
> Aeolian Chenopod — n 12 · range too narrow to fit
>
> Cells in the area
>
> Variation within the area / darker areas vary more internally

## Footnote

> Every number on both axes comes from the satellite grid, with no field measurements
> mixed in. Of 156 paddock × vegetation community areas, 34 are woodland or forest and
> are set aside because ground cover beneath a canopy does not mean what it means in the
> open; 4 sit outside the three open communities; 18 hold fewer than 500 cells (171 ha,
> 0.3% of the open ground), too few for an average that stands beside one taken over
> thousands. An earlier version at this grain counted 115 by keeping areas down to 33
> cells. Cover is measured for each cell across all seasons in the record rather than
> once a year; the number of measurements behind a cell ranges from 5 to 140. The lines
> are display smoothers — no slope is read from them and no significance test is
> computed. The Inland band opens above 50% wet because a single area, Bala 22 at 59%,
> carries that end of the range. Areas within one paddock are not independent, but no
> fitted line here holds two areas from the same paddock, so the bands are not
> understating clustering within a line. r is the correlation across areas within a
> vegetation community; each area in a fitted line comes from a different paddock, so
> these are independent units. Opacity carries how much cover varies between cells inside
> an area: the more varied the area, the more solid the point — so the boldest points are
> the least internally uniform, not the most certain. This describes how places differ
> from one another over the record — not what more water would do to any one place.

**"Vegetation community", never "veg community."** The abbreviation is the jargon, and
the client's own slide two before this one writes it out — the deck has to read
consistently across the join.

**The opacity channel runs against convention, so it is said in words twice.** Opacity
normally reads as confidence; here the boldest points are the *least* internally
consistent. The legend title carries the plain sentence and the footnote carries it
again. `veg_p05_within_sd` is a **spatial** spread across an area's own cells — not a
spread over time, not a standard error, and it does not shrink as an area gets larger.

**r is printed only where a line is drawn.** Aeolian's r is −0.161 across a 1–12% water
range. It is retained in `PARTSCATTER_community_support.csv` and the run record, and
suppressed on the face: printed beside two positive values, a Council reader sees dry
country doing worse with more water, which is not something a correlation of that size
across that range can say. **No R², pooled or per-community** — a fit statistic is a
coefficient, deviance explained is not comparable across smoothers that chose different
effective degrees of freedom, and a pooled R² would largely be measuring that Inland
country is both wetter and greener than Aeolian country. That build is PARTSCATTER-2.

## Why the count is 100 and not 115

**The 115 is this project's own number.** It is PARTREG's part count at a 33-cell floor,
over the **same three** non-treed communities. The client's slide pairs it with a legend
of **eight** vegetation communities; that eight comes from a different layer and no
figure at this grain has ever carried it. Stated so the gap is read from the page rather
than discovered in the room. **The count is not adjusted to reach 115.**

## Sources

| number | source |
|---|---|
| 156 → 118 → 100 areas; 171 ha dropped | `Output/temporal/PARTSCATTER_reconciliation_chain.csv` |
| 34 woodland/forest · 4 minor units | `Output/temporal/PARTSCATTER_excluded_communities.csv` |
| per-community n, water range, smoother drawn | `Output/temporal/PARTSCATTER_community_support.csv` |
| r +0.70 Inland · +0.71 Riverine · −0.161 Aeolian (unprinted) | `PARTSCATTER_community_support.csv`, `r_across_areas` |
| opacity ramp, within-area spread 3.4 – 23.2 | `PARTSCATTER_scatter_input.csv`, `veg_p05_within_sd` |
| Bala 22 at 58.9% wet, sole area above 50% | `Output/temporal/PARTSCATTER_scatter_input.csv` |
| 115 areas at a 33-cell floor | `PARTREG_S2_three_periods_115_parts.png` caption, this file |

## Superseded — kept, not deleted

~~The first pass's single-block caption, 9 August 2026: one voice doing the work of a
subtitle and a footnote at once. Accurate, but it made the reader find the answer to
their own question rather than meeting it.~~

~~Subtitle: *"…Cover rises with water in Inland Floodplain from 6% to 59% of its cells
wet…"* — which invites the misreading that **cover** rises from 6% to 59%. The range is
the water axis, across areas.~~

~~Legend title *"Plant community"*, and per-community labels carrying `n` alone.~~

---

# Canonical axis labels (Ruling EC, 9 August 2026)

**One quantity, one wording, across every product.** A label here is the canonical form;
a figure showing that quantity uses it verbatim. Where the full statement will not fit on
an axis, the axis carries the quantity and the subtitle carries population and time step,
in the same words on every figure.

| quantity | canonical axis label | where the population and time step go | products using it |
|---|---|---|---|
| per-cell temporal 5th-percentile total ground cover | **"5th-percentile ground cover, per cell (%)"** | subtitle / footnote: measured for each cell across all seasons in the record rather than once a year, 5 to 140 measurements per cell, 1988–2022 | D1v2 paddock dashboards, response panel |
| the same quantity, averaged over a unit's cells | **"5th-percentile ground cover, mean of cells (%)"** | as above, plus the unit and its cell count | `TEMPORAL1_paddock_temporal_p05_vs_water.png`, `PARTSCATTER_part_temporal_p05_vs_water.png` |
| share of a unit's census cells seen wet within a year | **"Share under water (%)"** | subtitle: share of the paddock's census cells wet that year, with the cell count and coverage share | D1v2 top panel |
| the same, averaged over years | **"Share of cells wet, mean over years (%)"** | Rulings AZ and CX; never called a between-year flood frequency | D1v2 baseline gauge, `figure_f5_cover_vs_water_64_paddocks`, TEMPORAL-1 scatter x-axis |
| the same, over a **paddock cut to one plant community** | **"Share of the area's cells seen wet, mean over years (%)"** | subtitle defines *area*: one paddock x community area, a single paddock cut to one plant community, averaged over its own cells, with the area count. Rulings AZ and CX; never called a between-year flood frequency | `PARTSCATTER_part_temporal_p05_vs_water.png` |
| per-cell between-year flood frequency | **"How often it floods · between-year flood frequency (%)"** | footnote: pixel census, 24.97 m, counted on the 8058 grid | D1v2 response panel |
| within-year median total ground cover, over a unit's cells | **"Median ground cover (%)"** | subtitle: measured across every census cell in the paddock, with the cell count and coverage share. The axis carries the quantity alone because the full form collided with the panel above it | D1v2 middle panel |
| plot-support between-year flood frequency | **"Share of years under water, per plot (%)"** | plot support, named in full. Phrased to echo the top panel's *"Share under water"* for the same idea measured at a different support and over years rather than across cells — deliberately NOT the AZ/CX wording, because this one IS a genuine between-year frequency | D1v2 "Where it sits" boxplot |

**The two water labels differ only in their population, and that is the whole point.**
`"Share of cells wet, mean over years (%)"` is the paddock; `"Share of the area's cells
seen wet, mean over years (%)"` is the paddock cut to one plant community. The tail —
*seen wet, mean over years* — is identical in both because the quantity is identical;
only the denominator moves. A figure that mixed them would be comparing a paddock's
water with a part's under one axis title.

**"Median ground cover" and "5th-percentile ground cover" are different quantities, not
two names for one** (Ruling EE). The middle panel plots the within-year MEDIAN across a
unit's cells; the response panel plots each cell's 5th percentile over time. The word
*"Typical"* was previously doing the median's work in the panel title, which named the
statistic nowhere a reader could check it.

**The two 5th-percentile forms share a stem on purpose.** The underlying quantity is one
thing measured per cell; TEMPORAL-1 shows its mean over a unit's cells and the dashboards
show the cells themselves. Naming the aggregation rather than renaming the quantity is
what keeps them a matched pair.

**Shared sentence, identical on both products** (spec 2.8), defined once in
`GAYINI_SEASONAL_BASIS_SENTENCE`:

> Cover is measured for each cell across all seasons in the record rather than once a
> year; the number of measurements behind a cell ranges from 5 to 140.

**Not permitted on a face** (Ruling EA): issue codes, ruling letters, `number_id`,
`fit_id`, repository paths. **Not permitted anywhere on a client-facing artefact**
(Ruling DT): sentences about project process, correspondence, internal review or a
pending correction — those live in `Output/runs/RUN_<TASK>_<DATE>.md`.

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
