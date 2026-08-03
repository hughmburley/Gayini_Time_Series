# Deliverables register — what goes to Adrian, and what it says in plain language

**Version:** v3 · 2 August 2026 · 8 working days to 10 August
**Changes in v3:** four statements corrected against the evidence, from REM-1 Gates D/E and AUD-1 Gate A. **No finding changes** — each amendment narrows a claim to what is supported, or corrects a count. (1) Claim 1 split: the unpinned "1.5 to 3.3 pp" range removed and replaced by a positional claim plus the pinned trend. (2) M3 caption rewritten to describe the figure as rendered; status SPECIFIED → EXISTS. (3) §5 counts updated to 88 rows / 57 of 71 independently re-derived, and the reproduction sentence qualified. (4) §6 item arithmetic corrected: sixteen items, not eighteen.
**Changes in v2:** six items moved to EXISTS (M4, M5, F3, F5, F7, T1) plus M5b added. The T13 geography and the recovering-count qualification folded into §1. Flood-year claim corrected. Internal counts updated to 74 registered numbers / 71 reproduced.
**Purpose:** consolidation, not pivot. Every item below either exists or is specified. Nothing
new is proposed.
**Test applied:** each item must state one claim in one sentence a non-specialist can follow. An
item that needs two sentences to say what it shows is doing two jobs and gets split or dropped.

---

## 1. The through-line — the whole thing in six sentences

If Adrian remembers nothing else, this is the argument. Everything in §3 supports one of these.

1. **Three of the four conserved paddocks sit within the spread of the sixty grazed paddocks
   throughout the thirty-five-year record**, and the difference between them shows no trend in
   either direction (+0.06 percentage points per year, r = 0.22).
2. **The fourth, Bala 29ca, produces every reference-state result the project has**, and both its
   difference and its improvement predate conservation management by thirty years.
3. **Water drives ground cover.** Drier country carries less cover in its worst patches, and this
   explains about half of the variation between paddocks.
4. **Bala 29ca is genuinely low and genuinely improving even after accounting for water** — and
   the improvement is located in its dry western parts, not the paddock as a whole.
5. **The conserved paddocks are not a fair comparison set.** Three of four sit almost entirely in
   the property's easiest country; only Bala 29ca spans the range.
6. **Some country is coming back and some is going backwards, and it is not organised by
   management.** The strongest improver on the property is a grazed paddock. Eight parts meet the
   recovering criterion; five survive dropping the two wettest years.
7. **It is organised by geography.** Decline clusters in the east — 12 of 16 declining parts are
   in the Bala group. Recovery and persistently-poor country are both south-western. The centre is
   almost entirely unremarkable. We do not know why.

**What we cannot say, and should say we cannot:** whether management changed the water regime.
That is the chain the managers care about. We have four post-management water years and they are
unusually wet — one is the wettest year in the whole thirty-five-year record and another the
sixth wettest, with mean inundation of 43.6% against 22.8% across the preceding thirty-one.
Separating a management effect from that would be hard with any method.

---

## 2. How to read this register

Each item gives the **claim** it supports (numbered from §1), a **draft caption** in client
language, and its **status**. Captions are drafts to be edited, not finished text — but they are
written at the level of finish the deliverable needs.

---

## 3. The deliverables

### Maps

**M1 · The property and its paddocks** — `T1_A_zone_map_named` · claim 1 · EXISTS
> Every paddock on Gayini, coloured by how it is grazed. The four green paddocks are the
> conserved ones. They share a name but not a location — the furthest two sit thirty kilometres
> apart, in three different parts of the property.

**M2 · Where the monitoring sites are** — `T2_G_plot_paddock_coverage` · claims 2, 5 · EXISTS
> The 66 monitoring sites against the paddock boundaries. More than half the conserved-paddock
> sites are inside a single paddock, Bala 29ca. All fifteen standard-grazing sites fall on the
> grey country, which has no paddock boundary at all — so standard grazing has never been
> measured as a management type.

**M3 · Which country stays green** — `T2_B2_duration_map` · claim 3 · EXISTS
> For every 25-metre square, the share of observed years in which total vegetation cover exceeded
> 70%. The most persistent country forms broad connected areas. **The 70% line is a chosen cut, not a
> natural boundary in the data** — a sweep across plausible thresholds shows a smooth decline with no
> break, so the area labelled "persistent" moves substantially with the cut. Squares with fewer than
> ten valid years are left blank, and the brightest shading saturates where cover exceeded the line in
> every observed year.
>
> *(Caption replaced 3 Aug 2026, P3-1/P3-3. The previous wording claimed the
> pattern forms broad areas "rather than following paddock boundaries" — the figure draws no paddock
> boundaries, so that comparison could not be seen. The chosen-cut clause is new.)*

**M4 · Country coming back and going backwards** — `T13_D1_part_state_map_and_scatter` · claims 4, 6, 7 · EXISTS
> Each part of each paddock, compared against similar country elsewhere on Gayini. Solid colour
> means the result holds when the two wettest years are removed; hatched means it does not.
> Between three and fifteen parts are recovering depending on how strictly you draw the line —
> eight at the line we set in advance — and it is the same parts throughout. Of those eight, five
> survive dropping the two wettest years and three do not; the three shown as unclassified are the
> ones that do not. Decline clusters in the east, recovery in the south-west.

**M5 · Cover and water, side by side** — `M5_dual_grain_floor_and_flood` · claims 3, 5 · EXISTS
> The same two measurements drawn twice — once with each paddock as a single value, once with each
> paddock broken into its vegetation types. The two rows look alike, which is the point: water
> organises cover more strongly than any management boundary does. The two columns do not, which is
> the second point: a paddock average hides a median of 12.8 percentage points of difference between
> the parts of the same paddock, and up to 40.

**M5b · How much cover each paddock carries against what its water predicts** —
`M5b_paddock_residual_from_expectation` · claims 3, 4 · EXISTS
> Blue is more than expected from water alone, red is less. Bala 29ca sits further below expectation
> than any paddock except Dinan 10 — which is grazed, and almost exactly as dry.

### Figures

**F1 · Thirty-five years, paddock by paddock** — `T2_E_paddock_trajectories` · claims 1, 2 · EXISTS
> Each conserved paddock as its own line against the grey band of the sixty grazed paddocks. A
> line inside the band is behaving like ordinary grazed country. In the floodplain country all
> four sit inside the band for the whole record; elsewhere Bala 29ca sits well below and climbs
> towards it.

**F2 · The same record, average cover** — `T2_E_paddock_trajectories_mean` · claim 1 · EXISTS
> The same paddocks measured by average cover rather than by their poorest patches. Here every
> conserved paddock sits inside the grazed band throughout — which is why the poorest-patch
> measure is the one we use.

**F3 · The gap, year by year** — `F3_annual_gap_series` · claim 2 · EXISTS
> The difference between the conserved paddocks and the grazed median, one point per year for
> thirty-five years. Without Bala 29ca the line is flat: there is no trend towards or away from
> grazed country at all.

**F4 · Which side moved** — `T2_F_gap_decomposition` · claim 2 · EXISTS
> The gap narrowed for a different reason in each vegetation type — in one the conserved side
> improved, in another the grazed side declined, in the third both fell together. And it is not
> only a wet-year effect.

**F5 · Cover against water, all 64 paddocks** — `F5_cover_vs_water_64_paddocks` · claims 3, 4 · EXISTS
> Each paddock's poorest-patch cover against how often it floods. The line is what we would
> expect from water alone. Bala 29ca sits furthest below that line of any paddock on the
> property except one — and that one is grazed.

**F6 · Grazing intensity does not order the results** — `T6_A_three_arm_grid` · claim 6 · EXISTS
> Three management types compared within similar country. If heavier grazing reduced cover, the
> standard-grazing rows would sit below the grey band. They sit at or above it in six of nine
> comparisons.

**F7 · Bala 29ca, part by part** — right panel of `T13_D1` · claims 4, 5 · EXISTS
> The three parts of Bala 29ca against every other part of comparable country. Two are among the
> lowest of their kind and improving fastest; the third is ordinary.

### Tables

**T1 · The four conserved paddocks, side by side** — `T1_conserved_paddock_comparison` · claims 1, 2, 5 · EXISTS
> One row per conserved paddock: what country it holds, how often it floods, how its cover
> compares to expectation, whether it is improving, and how many monitoring sites it has. The
> four are not alike, and Bala 27ca has no sites at all.

**T2 · The recovering and declining parts** · claim 6 · EXISTS (T13 Gate C)
> Every part of the property that is unusually low for its kind, unusually improving, or
> unusually declining — with the paddock it sits in and how it is grazed.

**T3 · What we do not know** — `Gayini_what_we_dont_know.md` · all claims · EXISTS (written page, pack root)
> The boundary of what this pack can support: what the analysis cannot tell you, and the record
> of our own checks failing and being caught.
>
> *(Caption and status replaced 3 Aug 2026, P4-2. The previous wording promised "every limitation …
> and whether it can be fixed", which the page cannot keep, and described T3 as the limitations
> register. T3 is a written page in the pack root — not the limitations register and not a workbook
> sheet.)*

---

## 4. The two things that need care when explaining

Both are real and neither can be avoided. Both are worth rehearsing before the tenth.

**The two "floors".** Two different measurements share a name and they are not comparable. One
asks *within a paddock in one year, how much cover do the poorest patches carry* — that is the
one every result here uses. The other asks *for one patch across thirty-five years, what does it
hold in its worst years*. Say "the poorest patches" or "the worst years" and never the bare word
floor, and the confusion cannot arise.

**Standard deviations within community.** Where we say a part is "unusually low", we mean low
compared to the spread of similar country, not compared to the property. This matters because
the spread differs: the same score is about twelve percentage points of ground in the chenopod
country and about six in the floodplain. The plain-language version is *"low for its kind of
country"*, and the map caption must state the amounts.

---

## 5. What stays internal — and why that is correct

The following exist to make the numbers trustworthy, not to be presented. **None of it needs
explaining to Adrian, and none of it should appear in a deliverable.**

| internal apparatus | what it is for |
|---|---|
| `dim_headline_number`, **100 rows** (97 pinned, 3 deliberately unpinned) | one pinned definition per headline number, with the range it takes under alternatives |
| the reproduction test, **80 of 97 pinned numbers independently re-derived, 0 value drifts** | re-derives each covered pinned number by an independent path and fails on drift |
| the three denominators and dominance counts | so a composition share can never be quoted without its denominator |
| ddof conventions on the residual SD | which spread statistic the "is this large" scale uses |
| `is_rollup`, the intercept spread correction | stopping two incomparable quantities being read as one |
| the six pin decisions | recorded choices where several answers were defensible |
| `assert_state`, the render guards | what a map is willing to claim, and a build that fails if a drawn number stops matching its source |

**The test this passes:** every client-facing item in §3 has a plain caption. Nothing in the list
above needs one, because none of it is a result — it is the machinery that makes the results
reproducible. If Adrian asks how we know the numbers are right, the answer is:
*every headline number is registered with its definition and the reasoning behind it, and a
separate test re-derives those numbers from source by an independent path and fails if any drifts.
It currently covers 80 of the 97 pinned numbers, and **not one registered number has drifted** — every
one of the 17 it does not cover is a number for which an independent derivation has not yet been
written, not a number that failed. The 17 are tracked as an open item.*

> **Figures corrected 3 August 2026 (RPT-SCOPE P1-1).** This section previously read "88 rows" and
> "57 of 71 numbers independently re-derived". Both were wrong: **57 appears nowhere in the data**,
> and 71 is the count that *reproduces*, not the denominator. Live truth, read from
> `Output/tables/RPTSCOPE_reproduction_status.csv` and not from the test's summary string (I-36):
> **100 registered · 97 pinned · 80 recomputed and agreeing · 82.5% coverage · 0 value drifts.**
>
> **These counts are a COPY and will go stale the moment anything registers a row — they moved twice in one session (82.1% → 82.5%). The Adrian pack workbook REGENERATES them live at build time from `dim_headline_number` and `Output/tables/RPTSCOPE_reproduction_status.csv`, and THE WORKBOOK IS AUTHORITATIVE OVER THIS REGISTER.** Quote the workbook, not this line. (REP-PAGE4's lesson a third time: a number in a document is a copy; a number read at render time is a fact.)

---

## 6. What is left

**The register lists sixteen items.** With M3 included following the REM-1 render check, all sixteen
exist. Three items named in the earlier contents workbook — M4b, D1 and D2 — are deliberately not in
this set: M4b is folded into M4's caption, and D1 and D2 are internal apparatus under §5 rather than
client deliverables.

Note that sixteen items resolve to **fourteen distinct files**: F7 is a panel of M4's figure, and T3
has no file of its own.

T7 remains the first thing to drop if time runs short — its GeoPackage serves Adrian's LiDAR test
rather than the client deliverable, and its stated purpose needs T3, which has never been built. M3
no longer depends on it: the recolour it was waiting for is presentational, not a correctness fix.

The three gaps v1 named — F3, F5 and T1 — were all built on 31 July. T1 in particular did the job
predicted for it: laid side by side, the four conserved paddocks are visibly not alike, which is
the point the whole analysis turns on.

**What is left is not building things. It is checking them.** QA-2b, the render and caption audit,
is scheduled for 5 August and is now the largest single risk to the pack — because every caption in
this register was written before the item it describes was finished, and several describe figures
that have since changed.

## 7. What this register is not

Not a plan and not a schedule — `Gayini_path_to_Aug10_tracker.xlsx` remains the spine. This says
what the output is and what each piece means, so that the tracker's tasks can be judged by
whether they move a named deliverable.

Nothing here is finished. After 10 August there is scope to refine every caption, rebuild every
figure in the deck palette, and add the items deferred to T3, T7 and the post-deadline tidy-up.
