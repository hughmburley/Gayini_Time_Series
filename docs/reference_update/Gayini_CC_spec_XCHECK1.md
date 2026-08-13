# CC spec XCHECK-1 — the cross-artefact review

**Design seat · 7 August 2026.** Runs after pack v1.3 is sent. Ruling AX applies: runs to
completion, reports once, registers nothing.

**v2, same date** — adds §5A, the two unzoned figures, which go to Adrian alongside the pack.

---

## 0 · What makes this different from every review this week

**Every review so far checked one artefact at a time. This checks whether artefacts agree with each
other.**

That distinction is not academic. Every error caught in the last three days was a **cross-artefact
disagreement**, and none of them was findable by reading one thing carefully:

| error | the disagreement |
|---|---|
| `veg_p05` label | producer selects `veg_p05_spatial`, legend names the census temporal floor |
| `flood (% yrs)` label | producer averages a within-year share, label states a between-year denominator |
| conserved paddocks / parts | scatter caption against map caption |
| stale manifest | manifest against `figure_asset` |
| row-count derivations | stated identity against arithmetic |
| CLAUDE.md "all 18 rasters" | prose against a table that had grown to 45 |

**Each was invisible inside its own artefact and obvious across a pair.** So this task is
constructed as pairs, and a check that reads only one side of a pair does not count.

**One standing rule.** Where a pair disagrees, **report both sides and say which is authoritative**.
Do not reconcile, do not pick the one that looks newer, and do not fix — except where §6 says
otherwise.

**Scope.** Everything in pack v1.3, the three single-page residual maps, the bootstrap figure, the
two unzoned figures, and the eight sampled paddock reports named in §5.

---

## 1 · Pair A — caption text against what the producer plots

**Not whether the caption reads well. Whether it is true of the figure it sits under.**

For every figure listed in scope, take each caption in the register and check three things against
the producer that renders it:

**1.1 · Every number traces to a fit.** Each figure in the caption resolves to a `fit_id`, a
`number_id`, or a named table and column. **A number that cannot be traced is reported as untraced**
— not assumed correct because it looks familiar.

**1.2 · Every axis label names the quantity the producer selects.** Read the SELECT statement, not
the variable name in the plotting call. **This is the check that found Ruling AY**, and it found it
twice in one legend block. Apply it to every axis, every colour scale, and every legend key across
all figures in scope.

Specifically: any label containing a **denominator** — "% yrs", "per year", "of years", "of cells" —
is checked against the denominator the producer actually divides by. **A wrong denominator stated in
words is worse than an ambiguous label**, because it forecloses the reader's doubt.

**1.3 · Every claim about the figure is visible in the figure.** If the caption says a line is dashed
for comparison, the line is dashed and labelled. If it says parts are ringed, they are ringed. **If
the caption describes something removed in a rebuild, that is a defect** — the cropping-era line
lost its annotation in one rebuild and the caption went on referring to it.

**Report per figure**: numbers traced / untraced, labels agreeing / disagreeing, claims visible /
not.

---

## 2 · Pair B — the ground-cover schematic against the ground-cover metadata record

**These document the same processing chain and were written about eight weeks apart.**

`SCHEM1_figure25_axis_chain` and its companion pictorial against
`Output/metadata/Gayini_metadata_ground_cover.md` §6.

**2.1 · Step for step.** The metadata record's five chunks against the schematic's boxes. Every step
in one appears in the other, in the same order, with the same parameters — resampling method, grid,
CRS, cell side, percentile.

**2.2 · Number for number.** The footprint ladder appears in both. 85,911 → 67,349 → 61,655 → 49,607
ha, and 795,602 cells at 24.970268 m. **Every rung must agree between the two, and both must agree
with the live database.**

**2.3 · Where they disagree, the schematic is the older one.** Report the disagreement; do not edit
either.

**2.4 · The same pass on the inundation record**, against whatever schematic content covers the water
chain. **Ruling AY has already established that the flood label was wrong in one figure** — check
whether the same wrong denominator appears anywhere in the schematic, the metadata record, or the
methods document.

**2.5 · Then widen it.** Ruling AY corrected two labels in one producer. **Search every producer and
every registered caption for the same two families of error**: a label naming `veg_p05` where the
quantity is `veg_p05_spatial`, and any label stating a denominator of years where the quantity is a
within-year share. Report every instance found, with file and line. **Do not fix any of them.**

---

## 3 · Pair C — metadata counts against the live database

**Re-run after all the rebuilds.** The last pass verified 12 of 13 and the 13th was wrong and came
from CLAUDE.md — stale prose that was true when written.

**3.1 · Every count, area and row figure in both metadata records**, re-derived from the database by
a query written for this check, not by re-reading the number the document already states.

**3.2 · The two derivations that failed arithmetic before.** `fact_zone_veg_annual` 2,240 = 64 × 35
complete on `mean_of_seasons`, 2,116 on `jja_son`, 4,356 total. `fact_zone_community_veg_annual`
4,130 = 118 × 35 complete, 4,012, 8,142 total. **Confirm both identities still multiply out**, and
that the 118 absent part-years remain 75 in WY1993, 32 in WY1996, 7 in WY1994, 4 elsewhere across
78 parts.

**3.3 · Every prose claim containing "all", "every", "none" or a bare count.** These are the class
that goes stale silently as a table grows. The CLAUDE.md raster sentence is the worked example:
**it was true when written.** Check each against its table today, in both metadata records, the
covering note, and the data dictionary.

**3.4 · The three wetness gradients table** — 9 / 22 / 50 at plot support, 6.1 / 12.9 / 28.0 across
the whole non-treed census, 4.5 / 14.1 / 30.2 on the PARTREG axis inside paddocks. Re-derive all
three and confirm the scope attached to each is the scope that produced it.

---

## 4 · Pair D — the manifest against the world

**4.1 · Manifest against disk.** Every member's SHA-256, re-hashed. Fifteen members: thirteen
manifested plus the manifest and `SUPERSESSION.md`.

**4.2 · Manifest against the registrar.** Every file with a registry row agrees with it. Every file
without one is marked as such in the manifest.

**4.3 · Manifest against what a caption or metadata record asserts from.** **This is the check v1.2
failed** — it asserted its community counter-finding from a coefficients table it did not ship.
For every table cited anywhere in the pack's prose, confirm it is in the pack.

**4.4 · The pack against the sealed hash.** `c844807a57023ad4…`. **If it differs, something wrote to
a sealed pack** and that is a halt.

---

## 5 · Pair E — the eight paddock reports against the registered table

**The sample, chosen to show the method rather than flatter it:**

| report | why it is in the sample |
|---|---|
| Bala 26ca | conserved — and its Inland part reads "ordinary" while sitting 3rd of 61 once water is allowed for |
| Bala 27ca | conserved |
| Bala 28ca | conserved — 45th of 61 on raw cover, **5th of 61** on water-adjusted |
| Bala 29ca | conserved — the three-thirds argument, and the one report whose story survives intact |
| Dinan 10 | reversal, dry end: "second-lowest of 61" and ordinary for its water |
| Bala 6 | reversal, dry end |
| Mara 11 | reversal, dry end: 7th of 61 on cover, 54th once water is allowed for |
| Bala 15 | the sub-support sliver — the parts page is absent and should not be |

**Two of the four conserved paddocks are among the sixteen whose column reverses.** A
"conserved plus a few grazed" sample lands them in front of Adrian either way, so they are in
deliberately.

**5.1 · Check against `PARTREG_part_residuals.csv` by an independent path.** Not against the report
builder's own inputs — that only confirms the builder agrees with itself. Query the registered table
directly and compare to the rendered document.

Every part's area, cover floor, rank, and label. Every whole-paddock figure. Every count.

**5.2 · The reversal is stated, not silent.** Each of these reports carries a "compared with the same
country elsewhere" column that ranks raw cover without holding wetness constant. **Report, for each
sampled report, what that column says and what the water-adjusted rank would be.** REPORT-2's caveat
sentence is not yet applied; **this check establishes exactly where it needs to go.**

**5.3 · Bala 15's absent parts page.** Confirm the second part exists, is below support, and that the
report currently presents as a single-community paddock. Same for Bala 28ca's 10-cell Aeolian
fragment.

**5.4 · Bala 29ca is the control.** Its Aeolian third sits at the 53rd wetness percentile of its
community, so it should read rank 1 of 17 on **both** bases; its Riverine third 2 of 37 on both. Only
its Inland third moves, 10 → 48. **If Bala 29ca's two dry thirds move, the join is wrong** and
everything in §5 is suspect.

---

## 5A · The two unzoned figures

`UNZONED_F1_between_units_two_sets.png` and `UNZONED_F2_within_response.png`. They go to Adrian
alongside the pack, as a separate provisional attachment.

**Read this before starting: the pairwise method mostly does not apply here, and that is the first
finding.** These figures are unregistered, outside the manifest, and hold their caption text in the
producer rather than the caption register. So most of §§1–4's pairs have no second side to check
against. **Report what can be cross-checked and what can only be read** — do not let a single-sided
read be counted as verified.

### 5A.1 · The two Ruling AY label families, applied here

**Cover axes.** F1 reads *"cover in the poorest patches"*, F2 reads *"cover floor, demeaned within
the unit"*. **Confirm both resolve to `veg_p05_spatial` in the producer**, not the census temporal
floor. Neither names a quantity explicitly, which is safer than naming the wrong one — but confirm
it, and say so.

**Water axes.** Both read *"share of the unit's cells seen wet"*, which is the correct within-year
framing. **Confirm the producer divides by cells and not by years.** This is the family that was
wrong in `build_T11_v2_dual_grain.R`.

### 5A.2 · Every number on both faces, traced

To `UNZONED_stageA1_fits.csv`, `WITHIN1_fits.csv`, `UNZONED_gate1_size_distributions.csv` or
`UNZONED_gate1_patch_inventory.csv`. At minimum:

+0.2106 · +0.1613 · 3,253 patch-years · 4,025 part-years · 93 patches · 115 parts · 91/91 · 115/115 ·
4,486 cells · 293 cells · the 1.18-decade gap · the registered line `52.653 + 0.548 × x` · the two
patches with only two distinct wetness values · the 2 patch and 3 part slopes exceeding 0.8.

**An untraced number is reported as untraced.**

### 5A.3 · Does F1 show what it says?

F1's whole purpose is that the size gap **shows** rather than being stated. It states a median gap of
1.18 decades — 4,486 cells against 293 — while the size key runs 100 · 1,000 · 10,000 · 30,000, so
those two medians sit about one key step apart.

**Check whether the marker area scaling renders that gap visibly at the printed size.** If it does
not, the figure asserts in words something the eye cannot see, and that is worth knowing before it is
used to make the point.

### 5A.4 · F2 panel A's point count

It draws 3,253 + 4,025 = **7,278 points**, above the display rule's threshold for all-pixel figures,
where the convention is bands or a kernel density rather than raw points.

Internal and provisional, so it stands. **Record it as a known limitation** so it is not rediscovered
if these ever move toward a pack.

### 5A.5 · The caption-source question

Every pack figure now reads its caption from `Gayini_caption_register.md`, and that design caught a
real parser bug on its first render. F1 and F2 do not.

**Report whether they should be moved to the register and what it would cost. Do not move them.**

### 5A.6 · What must not change

**F1's red DESCRIPTIVE ONLY banner stays exactly as written.** It is the only thing preventing the
figure being read as Stage A2, which has not run. It survives any tidying pass.

**The `PROVISIONAL · unregistered · for reference, not for onward circulation` stamp stays on both.**

**Neither figure is registered in `figure_asset` and neither enters the manifest.** If either appears
to need registering, that is a change of status and a design-seat decision, not a review finding.

---

## 6 · What to fix, and what to report

**Fix nothing.** One exception: a **factual contradiction inside a single shipped artefact** — the
class of the conserved paddocks/parts error, where one sentence disagrees with another sentence in
the same file. Fix those, list them, and say what changed.

**Everything else is reported.** Especially:

- anything in V13 or any sealed artefact — **V13 stays sealed**, findings go to the V14 change list
  beside C4 and C6
- anything requiring a registration — gated under AX
- anything in `Output/pack/**` — the deny rule holds and **a task that appears to need to write there
  is a task that is wrong**

---

## 7 · The report

Six sections — one per pair, plus §5A. Each carries: what was checked, how many agreed, and every
disagreement with both sides quoted and the authoritative one named.

**Then one list at the front: what a reader of this pack could be misled by today.** Ordered by how
likely a reader is to hit it, not by how hard it was to find.

**And a second list: what could not be checked**, and why. The pairs above are the ones with two
sides available. Anything asserted in only one place cannot be cross-checked and should be named as
such rather than counted as verified.

**The unzoned figures will dominate that second list**, because they have no registry row, no
manifest entry and no register caption. That is the correct outcome for a provisional artefact and it
is worth stating plainly: **they are read, not verified**, and the report should say which of their
claims rest on a single source.
