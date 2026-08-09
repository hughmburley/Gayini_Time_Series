# Gayini — what has been built

**An account of the work as it stands, 9 August 2026.**

*Internal review · culturally sensitive — review with the Nari Nari Tribal Council before any
external sharing.*

---

Every number in this document was read from the project database or counted on disk on 9 August
2026, and checked in both directions: where the register says a thing exists, the file was opened;
where a file exists, the register was searched for it. Six counts did not reconcile on the first
query. All six are resolved, and all six are listed at the end rather than quietly fixed, because a
document like this is only worth as much as its worst number.

The sections below are organised around the questions that were actually asked, not around the way
the work is filed.

---

## 1 · Figures showing inundation and vegetation cover over time

> *"I think you have made figures showing inundation and vegetation cover over time. For certain
> sites, or maybe for paddocks or vegetation community types."*

Yes — at four different grains. There are **341 registered figures** in total, of which **202 are
current** and 139 are earlier versions kept for the record. The ones that show cover and water
against time are these.

**Nine exemplar figures — one page each, three per vegetation community.** Ground cover and flooding
over the full 35 years for a single paddock's worth of one community: three in Aeolian Chenopod
country (the dry end), three in Riverine Chenopod, three in Inland Floodplain (the wet end). These
were built specifically to show what different country looks like over time, and they are the most
direct answer to the question.

**Site sheets — 57 of them, one per monitoring site.** A single page carrying a map of the site and
its surrounds, where the site sits among the four communities, river flow, flooding year by year,
cover year by year, and where the site sits on its community's cover-against-water relationship.

There are 66 monitoring sites in total and 57 have a sheet. **The nine without one are the treed
sites, and they are out of scope by design, not by omission** — the satellite measures ground cover,
and under a tree canopy that measurement does not mean what it means in open country. Reporting them
would imply a comparison the instrument cannot make.

**Paddock sheets — 23 paddocks of 64.** The same page design at paddock grain. These exist in two
generations: an original set of 21, and a current set of 23 built on 9 August that measures cover and
water on exactly the same ground cells rather than on two different footprints. The newer set covers
every paddock the older one did, plus two more. The older set is kept unchanged.

**Community sheets — 3 of 9.** One page per vegetation community and wetness band. Three of the nine
possible combinations have been built. **These three are not suitable for showing to anyone yet**:
they carry a "provisional" note that a later result has already settled, and they label total
vegetation as "green cover", which it is not. They are registered so they can be found, and flagged
so they are not used.

**Whole-property series.** Two figures place the whole property on one time axis: one showing
vegetation cover, how much of each community went under water, and river flow across all 35 years;
another showing how much of the property was wet in each year against gauge flow.

**Conserved-against-grazed trajectories.** Cover in the poorest patches of each conserved paddock
plotted year by year against the middle half of the 60 grazed paddocks, one row per community, with
wet years shaded. There is a companion on average cover rather than poorest-patch cover, and a
further pair splitting the property by grazing intensity rather than by conservation status.

---

## 2 · The flood-frequency raster, for example maps

> *"The raster of flood frequency… to use in some example maps."*

**192 registered raster layers, 15.6 GB on disk.** The ones that matter for mapping have been
gathered into a single companion folder with a plain-language guide, and were checked file by file
against their sources by checksum rather than by trusting that the copy succeeded.

**The flood-frequency surface to use.** How often each cell of ground went under water, as a
percentage of the 35 years. Because every cell in the mapped area was observable in every one of
those years, its value is exactly a count out of 35 — so only 35 distinct values occur. **No ground
in the open country flooded in all 35 years.** That is a fact about this place, not a limitation of
the measurement.

**An older flood-frequency surface is also included, and it is not the same.** It was counted on the
original grid and then interpolated onto the analysis grid, where the analysis does the opposite —
it moves the wet and dry marks across first, then counts. The two agree exactly on only a quarter of
cells, and differ by more than one percentage point on 29% of them. Both are in the folder so the
difference can be seen; the counted one is correct for anything quantitative. This is set out in
§8 below.

**The vegetation-and-wetness map** underlies everything else: 11 classes, each a combination of
vegetation community and how wet that ground is relative to others of its kind. Its class codes are
settled and its arithmetic is not gated.

**A five-zone flood map** on fixed thresholds — never, rarely, occasionally, regularly, frequently —
which is a different and simpler scheme from the one inside the vegetation classes. The two answer
different questions and should not be laid over one another as though they were the same.

**The year-by-year flooding record itself**, in two forms: the original as delivered, and the same
data moved onto the analysis grid. Both are included because "the flood frequency data" could
reasonably mean either.

**The bands inside these files are named, not just numbered** — `1988-1989` through `2022-2023` — so
an off-by-one error cannot happen silently.

**On "1988–2023".** The filenames say 1988–2023, which reads like 36 years. It is 35. A water year
spans two calendar years, so 35 water years run from 1988-1989 to 2022-2023, giving a calendar span
of 1988 to 2023. The label is ambiguous rather than wrong, and it has deliberately not been changed
mid-delivery.

---

## 3 · Temporal percentiles, averaged by area, plotted against inundation

> *"Calculate temporal percentiles of cover for each pixel. Calculate averages of percentiles for
> each area. Plot percentiles vs inundation. Have you done it this way?"*

**Yes — all three steps, in that order.** They were built before the question was asked, which is why
they were not easy to find.

**Step one — a percentile for every cell of ground.** For each cell, the record of its vegetation
cover across the whole period is sorted, and the low end is taken: the level the cell holds even in
its poorer seasons. Five percentiles were computed and stored as maps. The lowest of them is the one
the project reports on, because it moves with water roughly twice as fast as the middle of the
distribution does — the signal is in the floor, not the average.

**One thing to know about how these were computed.** They are calculated across **140 seasonal
observations** — four per year across 35 years — not across 35 annual values. A written description
sent earlier said otherwise; that description was wrong for these files and has been corrected. The
two are close relatives rather than the same object, and the difference between them has not yet
been measured.

**Step two — averages by area.** Each cell is assigned to the paddock and vegetation community it
falls in, and the cell values are averaged within those groupings. This has been done at three
grains: whole paddock, vegetation community, and the 115 paddock-and-community pieces that have
enough ground to support a number.

**Step three — percentiles against inundation.** Plotted at every one of those grains: 64 paddocks,
115 pieces, and the whole property broken into flooding bands.

**What it shows.** The relationship is clear and rises steadily in Inland Floodplain country, which
carries the bulk of the wet ground. It rises across its supported range in Riverine Chenopod. In
Aeolian Chenopod it is ragged, and its wet end rests on only 60 cells — so the apparent jump there
is not evidence of anything. **Wetter country holds more cover in its barest patches.** That is the
central description, and it holds at every grain tested.

---

## 4 · Maps of the residuals

> *"I'm not sure that maps of the residuals are a good idea, as they are colouring large areas by
> values calculated from the barest areas."*

**Withdrawn, on that reasoning, and the reasoning was right.** The maps were built and are retained
internally, but they are not part of the delivery and are not being shown.

This is recorded here deliberately. It shows the record responding to a good objection, which is a
different thing from something having failed.

---

## 5 · The reference-state question — conserved against grazed

This was the question the work was originally shaped around: does country managed without grazing
hold more cover than country that is grazed?

**The honest answer is that the comparison does not carry the weight it was meant to carry, and the
reason is worth stating plainly.**

Four paddocks are managed without grazing. **Three of them are indistinguishable from grazed ground
across the whole 35-year record.** The fourth, Bala 29ca, produces essentially every reference-state
result — and it is the property's driest paddock, ranking 61st of 64 for how often it floods, where
the other three rank 3rd, 6th and 31st. It also supplies more than half of all the monitoring sites
in the conserved set.

**Where the gap does appear, it opens in the dry country and closes over time.** In Aeolian Chenopod
country the conserved ground sits about ten percentage points below grazed ground on the cover
floor; in Riverine Chenopod about four and a half points below; in Inland Floodplain there is
effectively no difference at all. The gap between conserved and grazed narrows steadily across the
record.

**That narrowing cannot be attributed to the removal of grazing.** It runs continuously from 1988,
roughly thirty years before conservation management began, and it is almost entirely produced by
Bala 29ca on its own. Remove that one paddock and the trend is nearly flat.

**A related null.** Splitting the property by grazing intensity rather than by conservation status
does not produce a signal either.

**And a caution about the unit itself.** Paddock boundaries were drawn for stock rotation and do not
follow vegetation. A number computed for a whole paddock averages across whatever different country
the fence happens to enclose, and where a paddock spans several communities that average describes
no real place. **Bala 29ca is the extreme case** — roughly a third Inland Floodplain, a third
Riverine Chenopod, a third Aeolian Chenopod — and its three parts behave differently from one
another. A "sharpest contrast" between two paddocks, examined closely, turned out to be a difference
in what vegetation they contained rather than a difference in how they behaved.

**The shared finding across this work is that water, not management, organises this country.**

---

## 6 · What the data cannot say

Stated plainly, because it will be asked.

**The satellite measures how much ground cover there is and how green it is. It does not measure
ecological condition, and it cannot tell a change in land use from a change in condition.** A
cultivated paddock and a recovering one can look similar from above. Nothing here should be read as
a condition score.

**It measures cover, not structure.** Shrub height, canopy layering and the architecture of
vegetation are invisible to it. That gap is the reason for the airborne laser survey, which has been
processed but whose structural model is not yet available.

**Land-use history before the record is largely unknown.** Whether particular country was cleared or
cropped, and when, is not recorded for any of the 64 paddocks. An attempt to recover this from
satellite land-cover products was made and **failed** — it produced false positives and no usable
signal, and that negative result is documented rather than quietly dropped. This remains an open
question that only local knowledge can answer.

**Where numbers rest on thin ground, they are marked as such.** Several of the numbers above rest on
small counts of cells at one end of a range. The counts travel with the numbers throughout, because
the count is often the reading.

**Statistical caution.** The mapped area holds over a million cells, but they are neighbours and
behave like neighbours. A confidence interval computed as though they were a million independent
observations would be far too narrow, and no such interval is reported anywhere in this work.

**No causal claim is made anywhere.** Where the honest statement is that nothing was found, that is
what is written.

---

## 7 · The work, counted

Every figure below was read from the database or counted on disk on 9 August 2026.

| | count | note |
|---|---:|---|
| Registered figures | **341** | 202 current, 139 superseded and kept for the record |
| Registered raster layers | **192** | 15.6 GB on disk |
| Database tables and views | **95 / 35** | |
| Mapped ground cells | **1,080,157** | 67,349.3 ha |
| — of which open, non-treed country | **988,831** | 61,655.0 ha — the analysis footprint |
| — of which inside a management zone | **795,602** | 49,607 ha |
| Whole property, on the ground | | 85,910.8 ha |
| Water years | **35** | 1988-1989 to 2022-2023 |
| Seasonal observations behind the cover percentiles | **140** | four per water year |
| Monitoring sites | **66** | 57 open country, 9 treed and out of scope |
| — carrying a site sheet | **57** | all 57 open-country sites |
| Paddocks | **64** | 4 managed without grazing |
| — carrying a paddock sheet | **23** | current generation |
| Paddock-and-community pieces with enough ground to support a number | **115** | |
| Vegetation communities | **4** | 3 open, 1 treed, plus a small residual class |
| Wetness bands per community | **3** | giving 9 open-country groupings of 11 classes |
| Analysis scripts | **312** | 192 in R, 119 in Python, 1 shell |
| Registered headline numbers | **142** | 139 fixed, 3 deliberately left open with the reason recorded |

**On the area figures.** Three different areas appear above and they are not interchangeable. The
property is about 85,911 ha. The area the satellite maps into vegetation classes is 67,349 ha. The
open, non-treed country the analysis actually reports on is 61,655 ha. And only 49,607 ha of that
falls inside a mapped management zone — so a paddock-level statement covers about four fifths of the
open country, not all of it. **Whichever of these is used as a denominator changes the answer, so it
is stated every time.**

---

## 8 · What was found wrong, and corrected

Each of these was found internally, before it reached the client or the Council. They are listed
because a record showing the work is being checked is better evidence of care than a record with
nothing in it.

**The interpolated flood-frequency surface** *(corrected 9 August 2026).* An earlier statement that
the older surface's values were "exact inside the mapped area" was withdrawn. That surface was
counted on the original grid and then interpolated onto the analysis grid; the analysis chain moves
the data across first and counts afterwards. The two agree exactly on only 24.95% of cells, differ by
more than one percentage point on 28.89%, and differ by as much as 30 percentage points at the
extreme. It changes the map, not merely the decimals: re-cutting the five flood zones from the
interpolated surface moves 5.62% of cells into a different zone and shrinks the never-flooded class
by roughly a third. A correctly counted surface was built and is now the one to use.

**A mislabelled water axis** *(found 7–8 August 2026).* A label naming a denominator of *years* was
found on a quantity that is a share of *ground within a single year*. The two are different
measurements and one of them is the project's headline metric, so the confusion mattered. Every
producer and every registered caption was then swept for the same pattern; three instances were
found and named, including one on the project's most-shown figure. A fourth instance was found on
9 August in the panel that draws flooding year by year on the site and paddock sheets. **In that
case the underlying values were checked and are correct** — the mistake is in the wording, not the
measurement — and the sheets have deliberately not been re-rendered before delivery, with the
wording flagged for whoever presents them instead.

**A plot-versus-polygon mismatch** *(corrected 9 August 2026).* On the paddock sheets, one marker was
computed over the whole paddock outline on the original grid while the panels around it were
computed on the paddock's mapped ground cells. Two different footprints, presented side by side as
though comparable. The marker did not reconcile, so it was removed rather than explained away.

**A related scope correction found in the same check.** A percentage printed on three sheets divided
by all ground rather than by the open, non-treed ground the sheet is scoped to. It affected only
paddocks that contain treed country — where there is none, the two denominators are identical, which
is why it survived earlier checks. Corrected, and now read from the same file the run record is
written from, so a sheet and its record cannot drift apart.

**The seasonal basis of the cover percentiles** *(corrected 9 August 2026).* A written description
stated these were computed across 35 annual values. They are computed across 140 seasonal
observations. The description was wrong for these files and has been corrected.

**A claim about permanent water, withdrawn** *(9 August 2026).* A threshold used in the percentile
calculation was described as excluding permanent water. Measured inside the analysis footprint, it
removes **2 cells of 988,831**. The mechanism was verified when it was chosen, on a lake of about
347 ha — but that lake lies wholly outside the vegetation footprint, so it was never exercised where
the analysis actually reads. Any claim that these percentiles resolve the open-water limitation is
withdrawn: they inherit it. **No published value is affected** — the 940 cells in question are well
covered rather than water-like, and removing them moves the relevant figure by five hundredths of a
percentage point.

---

## Appendix A · Counts that did not reconcile on first query

All six were resolved before this document was written. None changed a result.

| what | first query | resolution |
|---|---|---|
| Seven registered figures could not be opened at their registered location | register said 341 files present, 334 opened | The seven files exist, in a review bundle rather than the diagnostics folder. **The registered path is stale; nothing is lost.** The register's own "file present" flag reads *yes* on all seven — a stored flag cannot notice it has gone out of date, so it was checked live instead |
| Total raster volume | register reported 13.39 GB | The size field is empty on 171 of the 192 rows, so the registered total came from 21 rows — two of which are large survey products. **Measured on disk instead: 15.64 GB**, which is the figure used in §7 |
| Rasters, current versus superseded | 79 current, 32 superseded | Does not sum to 192 — the flag is empty on 81 rows. **No current-versus-superseded split is claimed for rasters** anywhere in this document, only the total |
| 578 image files on disk are not in the register | looked like a large gap | Not a gap. 336 are component panels that make up the paddock reports, 148 are report figures, 27 are earlier-generation renders, 10 are a duplicate copy of sheets that are registered elsewhere. **Component parts of a registered product are not separately registered, by design** |
| Paddock sheets | two sets, 21 and 23 | The 23 are a superset of the 21, not a separate set. **23 distinct paddocks of 64 have a sheet**, which is the figure used in §7 |
| The project's own summary of the database | 86 tables, 30 views, 166 rasters, 278 figures, 59 headline numbers | All five stale against the live database — 95, 35, 192, 341, 142. **Every count in this document was taken from the database directly, never from that summary.** The summary needs updating; that is noted, not done here |

---

## Appendix B · Where the numbers in §5 come from

Provided so any figure quoted above can be traced. These identifiers are internal.

| statement in §5 | registered identifier | value |
|---|---|---|
| Aeolian conserved-versus-grazed cover floor | `ref_grazed_floor_aeolian` | −10.46 |
| Riverine conserved-versus-grazed cover floor | `ref_grazed_floor_riverine` | −4.49 |
| Inland conserved-versus-grazed cover floor | `ref_grazed_floor_inland` | +1.08 |
| Flood ranking, Bala 26ca / 27ca / 28ca / 29ca of 64 | `ref_paddock_flood_rank_bala26ca` and siblings | 3 / 31 / 6 / 61 |
| Share of conserved monitoring sites in Bala 29ca | `bala29ca_ref_plot_share_pct` | 54.17% |
| Strength of the narrowing, all four conserved paddocks | `t10_gap_annual_r_A_all4` | 0.77 |
| The same, with Bala 29ca removed | `t10_gap_annual_r_B_excl29ca` | 0.222 |
| The same, Bala 29ca alone | `t10_gap_annual_r_C_29ca` | 0.846 |

All values are at paddock or vegetation-community grain over the full record, on open non-treed
ground, as at 9 August 2026.

---

*Prepared 9 August 2026. Internal review · culturally sensitive — review with the Nari Nari Tribal
Council before any external sharing.*
