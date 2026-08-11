# Gayini remote sensing — key takeaways

**A handover note for whoever picks this up next.**
Hugh Burley, August 2026. Written for a reader who is a good ecologist and not a remote-sensing
specialist.

> **Internal draft.** Requires review with the Nari Nari Tribal Council before any external
> sharing. Place and community names follow existing usage in the project's report stream; no new
> naming is introduced here.

---

## How to use this

The analysis covered 35 water years of Landsat fractional cover and inundation across the property.
This note is not a summary of it. It is the shorter and more useful thing: **what we found, what we
looked for and did not find, what will silently give you a wrong number, and what is worth reusing.**

**Read §3 first if you are short of time.** Findings tell you what we think; nulls tell you where not
to spend six months. The nulls are the part almost nobody writes down.

**§5 is the reason this note exists.** Our team's contribution is spatial — projections, supports,
zonal aggregation, autocorrelation. That work is done, it is on disk, and redoing it would be a poor
use of an ecologist's time.

---

## 1 · The single result

**Inundation frequency raises the *lower tail* of ground cover, not its typical level.**
Wetter country does not get as bare in the bad seasons; in a normal season it looks much like
anywhere else.

Across the census, from the driest to the wettest ground:

| statistic | dry end | wet end | change |
|---|---:|---:|---:|
| **p05** — the cover floor | 40.5% | 77.1% | **+36.6 pp** |
| **p50** — typical cover | 73.1% | 89.7% | +16.6 pp |

The gap between them compresses from **32.6 pp to 12.6 pp**. The floor rises about twice as fast as
the middle.

**Why this matters more than it looks.** If you summarise cover by its mean or median — which is the
default almost everywhere — the flood signal is roughly halved and you will conclude the relationship
is weak. It is not weak. It is in a different part of the distribution. This is the transferable
claim, and it is independent of Gayini.

**It replicates four ways**, each a different kind of evidence:

| grain | evidence |
|---|---|
| Pixel | the census gradient above |
| Part / paddock | between-unit regression across management units |
| Within unit, over time | the same sign inside units, so it is not purely a between-place artefact |
| Unzoned country | **100% of 93 patches slope positive**, on ground carrying no management polygon and entering no fit |

The unzoned replication is the strongest of the four, because that country was never used to build
anything.

**One thing to get right before quoting slopes.** The between-unit slope and the within-unit slope
answer *different questions* and are not two estimates of one number. Between-unit asks whether
wetter places have higher floors. Within-unit asks whether a place's floor rises in wetter periods.
Both are positive; the between-unit slope is roughly three times the within-unit one. Reporting
either as "the" slope is an error.

---

## 2 · What else holds

- **Inundation shows no directional trend** over the record, in 9 of 9 non-treed strata. Variation is
  episodic and climate-paced, not a trend. Any framing built on "flooding has declined here" is not
  supported by this dataset.
- **The floor is almost entirely dead material** — about 97% non-photosynthetic at p05, measured
  paired (see §4). Roughly 4,300 ha has a majority-green floor; that ground is a small and
  interesting minority.
- **Cover has a strong seasonal structure independent of water.** Winter–spring against summer–autumn
  moves p05 by about **+10.85 pp** and p50 by about half that. This is farm-wide and cannot be
  flood-driven — which is a second, independent demonstration that the floor is the more responsive
  statistic.
- **Community ordering is not a clean dry-to-wet gradient.** Inland sits well above Aeolian and
  Riverine, which are close to each other. Do not assume the vegetation ordering and the water
  ordering are the same axis.

---

## 3 · What we tested and did **not** find

**This section is the one that saves time.** Each of these was a real line of inquiry that closed.

**Conservation status does not predict condition.** Three of the four conserved paddocks are
statistically indistinguishable from grazed ground. The apparent reference-versus-grazed gap is
almost entirely one paddock, and the gap predates conservation by roughly three decades. *"Conserved"
is a management category, not a condition state.* Do not build an analysis that assumes otherwise.

> **Traceable as written.** The one-paddock result rests on the annual gap series — correlation 0.77
> across all four conserved paddocks, 0.22 with that paddock excluded, 0.85 for it alone — and on the
> three per-community floor trends inside it, which run +0.56, −0.22 and +0.56. All of those are
> produced by committed scripts and covered by the reproduction test. **Two things nearby are not:**
> any paddock *rank*, and anything about Dinan 10. Do not quote either without checking §6.

**The four reference paddocks are not four replicates.** They sit roughly 30 km apart, across three
vegetation communities, with several metres of regional fall between them. They differ by position in
the landscape at least as much as by management. "Distance to reference condition" is not well
defined on this property.

**CSIRO habitat condition is near-binary and uncorrelated with inundation** (r ≈ +0.03), and runs
*opposite* the flood gradient. The accompanying threatened-species layer equals 100 × the condition
layer cell for cell — it carries no independent species information. Both are modelled surfaces, not
observations.

**Cover and condition cannot be cross-validated against each other.** The condition model uses
cover-like inputs, so comparing them is circular. Inundation is the only permitted independent axis.

**Residual-based attribution does not clear the published bar.** The RESTREND family of methods
requires roughly R² > 0.3 to be interpretable; within-unit fits here sit at about 0.17 (linear) to
0.24 (log). We therefore refuse to attribute residual variation to management, and say so. If a
reviewer raises it, this is a stated position, not an oversight.

**LiDAR cannot detect the change we care about.** Two acquisitions, but the change-detection floor is
about **9.7 pp** against an observed difference of about **0.26 pp** — a factor of forty. The LiDAR is
useful for structure and terrain context; it is not useful for change over this interval.

**Sparse plot designs cannot see this signal.** A 40-point design returns a false positive on the
order of **54%** of the time on this property. This is why the project moved to an all-pixel census.
If you are designing field sampling to test a cover–water relationship here, take this seriously.

**Two of three communities are spatially non-stationary.** Only Inland Floodplain produces a
well-behaved variogram; Aeolian and Riverine show large-scale residual structure the water axis does
not capture. Any model treating residuals as independent across the property is misspecified.

---

## 4 · Traps that silently produce wrong numbers

Each of these has produced a wrong answer at least once, and none of them throws an error.

**Percentiles do not subtract.** `p05(total)` and `p05(green)` are marginal percentiles on different
orderings — the season setting the total floor need not be the season setting the green floor.
Subtracting them gave "99% dead"; the correct paired measurement gives about 97%, and the ratio is
not constant. **Measure paired:** take the other band's value in the season that sets your target
statistic.

**The uint8 nodata trap.** In uint8, `255 + 255 = 254` and `255 + 50 = 49`. Both wrap silently. A
naive `band2 + band3` fabricates entirely plausible cover values at every nodata pixel, and 254
survives any check that only looks for negatives. **Mask 255 → NA before summing. Never sum raw
bands.** Then assert the sum lies in [0, ~110] — and if it fires, diagnose rather than widen the
bound. It does fire, at 147, and that is real.

**`MIN_SEASONS = 50` does two jobs.** It makes p05 a meaningful percentile, and it stops the product
inventing vegetation over open water. Lowering it to "recover pixels" will fabricate cover on the
lake. Leave it.

**Two different metrics share one name pattern.** Inundation *frequency* is between-year
(wet years ÷ valid years). `inundation_annual_occurrence_pct` is a *within-year area* metric despite
the name. They are not interchangeable.

**Support is not encoded in any metric name.** The same quantity at plot support and pixel support
gives genuinely different numbers — roughly 9 / 22 / 50% against 6 / 13 / 28% across the three
communities. **Both are correct.** A 1-ha plot counts as wet if any of its ~16 pixels is wet, so the
plot figure is necessarily higher. Never place both in one figure, and always label which support you
are using.

**Two percentile products exist and must never be compared.** A per-cell temporal percentile and a
spatial percentile of a temporal mean are different quantities. They look comparable and are not.

**Mapped area ≠ property area.** The classified census covers **67,349 ha**; the property is
**85,911 ha**. Roughly 21.6% is unmapped, and a further large fraction of the mapped area carries no
management polygon. Whichever you use as a denominator changes the answer, so state it every time.

**The grid is not the farm.** The percentile rasters are masked to the fractional-cover extent, and
about two-thirds of their valid pixels are outside Gayini. Summarise to the property, not the raster.

**Reprojection rules do not transfer between layer types.** Binary masks use nearest neighbour;
continuous cover surfaces use bilinear. Copying one rule to the other corrupts the layer quietly.

**One vegetation classification is canonical.** The four-class simplified grouping is the analysis
classification. A five-class variant exists in the project files and must not be used for analysis.

---

## 5 · The spatial machinery — what is worth reusing

This is where the reusable value sits.

### Four things that are genuinely pipelines

Re-runnable as new years accumulate, on the same or similar inputs:

1. **Fractional cover → seasonal composites → per-pixel temporal percentile stack.** The core
   product. Extends by adding water years.
2. **Inundation scenes → counted flood-frequency surface + annual wet/valid layers.** Note *counted*,
   not interpolated — an earlier interpolated surface was wrong and was replaced.
3. **Census join** — every pixel assigned to zone, part, paddock and community, emitted as Parquet
   (~1.08 million rows). This is the substrate everything else reads.
4. **Zonal summary** — any metric over any polygon set, with support recorded.

### Things that are one-off analyses, not infrastructure

The reference-state comparison, the CSIRO condition work, the dashboards and site reports, and the
LiDAR structural work. All are documented and none should be mistaken for a pipeline.

### The parts that are hard to redo

Worth knowing exist before rebuilding them:

- **The projection discipline.** Seven coordinate systems in play across source products. The
  canonical analysis grid, the inundation stack, the cover source and the plot centroids are each in
  a different one. The rules for moving between them are not obvious and getting one wrong is silent.
- **Large-raster streaming.** The stacks do not fit in memory; they are read through windowed
  streaming rather than loaded.
- **Validity handling.** Per-scene nodata is highly variable — median about 2%, mean about 14%,
  and 22 scenes above 30%. The validity layer is presence-only, so absence is encoded as nodata and
  not as zero. Treating it as a 0/1 mask destroys the counts.
- **Support floors and their sensitivity.** The valid-year threshold is effectively non-binding at
  the chosen setting — it removes about 0.025% of pixels. That is a design choice, not a constraint,
  and it is worth knowing it is not doing hidden work.
- **Variogram analysis by community**, per §3.

---

## 6 · Numbers to re-check before quoting externally

The project keeps a registry of pinned numbers, each carrying its support level, scope filter, pixel
constant, denominator and period label. **A number without those five qualifiers is not usable** — it
cannot be compared to anything else safely. If you take a number from a figure caption rather than
the registry, assume it is missing at least one.

**The registry is in better shape than its own test reports.** The reproduction test prints a summary
line reading *"72 DRIFTED of 81 checked"*, and that line is misleading: a row with no derivation path
is appended to the failure list without incrementing the counter, so the 72 are not among the 81 —
81 + 72 = 153, the pinned rows. The accurate statement is that **of 153 pinned numbers, 81 have a
derivation path and all 81 reproduce within tolerance, and not one number disagrees with its
recomputation.** The remaining 72 have no derivation path in the test. That is a coverage gap that
widened as the registry grew, not a correctness problem.

**One class of number is not traceable, and it is worth knowing which.** An audit traced every
registered number to the code that writes it. Most resolved cleanly. Three groups did not:

- **A batch of paddock-composition and adjusted-trend numbers** — the `s11_` family — matches no
  script, no document and no table anywhere in the repository, and cites a draft that was never
  committed. Most are *redundant*: a tracked database view independently produces the same community
  shares, and the per-community floor trends have produced equivalents. **But four things do not:**
  everything concerning Dinan 10; the per-community level *ranks* for the mixed paddock; the
  all-paddock counts (how many paddocks fall in each dominance band, how many carry a negative
  adjusted trend); and the all-paddock median adjusted trend of about −0.148. A produced grazed-only
  median of about −0.151 exists and **is not a substitute** — different scope, coincidentally close.
- **Paddock flood-frequency ranks.** These resolve only into code that *reads* them. Nothing writes
  them. The reproduction test can re-derive them; no committed script does.
- **A periodised reference-state table** in earlier presentation material, whose producing script
  cannot be located. **Do not reuse those period values.** No finding in this note depends on them.

**The practical rule: a rank, a paddock count, or anything about Dinan 10 should be re-derived before
it is quoted.** Everything else in §1 to §3 traces to committed code.

Two smaller items to resolve if they matter to you: the unzoned area has two figures in the record
(about 12,150 ha and about 12,179 ha, almost certainly a pixel-area constant applied inconsistently),
and the ratio between the between-unit and within-unit slopes has been quoted from a working
calculation rather than a registered one.

---

## 7 · Attribution and reuse

Analysis and code by Hugh Burley, produced under contract to UNSW for the Nari Nari Tribal Council
and the Biodiversity Conservation Trust, 2026. Data sources are third-party (Landsat-derived
fractional cover; inundation surfaces; CSIRO modelled condition products) and carry their own terms.

Reuse terms to be confirmed in writing before redistribution. Cultural material and any output
identifying places on Country require Nari Nari Tribal Council review before external use.

*Questions about this note go via Adrian Fisher.*
