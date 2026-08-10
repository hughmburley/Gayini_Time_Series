# UNZONED v3 — findings note

**Does the cover-and-water relationship hold on country that never entered a fit?**
10 August 2026. Spec `docs/reference_update/Gayini_CC_spec_UNZONED_v3.md`.
Run record: `Output/runs/RUN_UNZONED_V3_20260810.md`. Manifest: `UNZONED_v3_manifest.csv`.

**The ground.** 12,048 ha carrying a vegetation-community label and 35 years of cover and
water, excluded from every fit for one reason: no management zone was drawn over it.
**It is unzoned standard-grazing country** — set stocking, a designed treatment arm in the
UNSW annual report. It is **not** a reference set, **not** a control, and **not**
unmanaged. **All fifteen standard-grazing monitoring plots sit on it** (18 of the 66 plots
in total), which is why that arm had never been reported above plot support: it had no
paddock to belong to.

**Written Arm B first because Arm B is the stronger test.** Arm A is the cheaper run and
the more legible figure, and it was executed first; the order of execution is not the
order of argument.

**Two metrics, and they never mix.** Arm B uses `veg_p05_spatial` — a percentile across a
unit's cells within a year, averaged over years. Arm A uses `veg_p05_temporal_mean` — each
cell's percentile across the record, averaged over the unit's cells. **Every number below
names which.** They are never co-plotted, differenced, or called by one word.

---

## 1 · Arm B — the within-patch test

### 1.1 · The least equivocal result in the task

**Every one of the 93 supported patches slopes positive.** All three communities, smallest
slope **+0.016**, median **+0.135**. There is no subset of this ground on which more water
does not come with more cover in the poorest seasons. Before any estimator argument, that
is the result.

### 1.2 · The pooled within estimate

**+0.2106** (r +0.331, 3,253 patch-years, 93 patches), against the real parts' **+0.1613**.
Cluster bootstrap over 10,000 draws: **[+0.1611, +0.2657]**.

**The cluster is the patch, and that is not the real-part choice.** The real-part estimate
clusters on `zone_fid`; there is no paddock on this ground. Patches near one another are
not independent, so this interval is, if anything, **too narrow**. Named, not fixed.

The prediction was "near +0.16". **Partly held:** same sign, same order of magnitude, but
**+31%** on the like-for-like comparison, and the real-part value sits essentially **on the
lower bound** of the unzoned interval. "Near +0.16" is true only at the edge.

### 1.3 · The AR(1) sensitivity applies to both sides, and that is what makes it readable

Residual lag-1 autocorrelation is **+0.399** (median), an effective n of about **15 of 35
years**. Refitting with AR(1) errors moves the unzoned estimate to **+0.1436**, a **−31.8%**
fall — which the spec pre-registered as a finding that stops for review.

**It stopped, and the stop was productive.** The comparator had had no such refit, so the
drop was uninterpretable: a property of annual floor series everywhere, or something about
unzoned ground, with nothing in hand to tell them apart (**Ruling EK**). Run on both sides:

| side | OLS-within | GLS AR(1) | move | φ |
|---|---:|---:|---:|---:|
| unzoned patches | +0.2106 | +0.1436 | **−31.8%** | +0.482 |
| real parts | +0.1613 | +0.1120 | **−30.5%** | +0.434 |

**1.3 pp apart.** The sensitivity is a property of **annual floor series generally**, not of
unzoned ground. It is a caveat on both sides at once, and **the +0.2106 against +0.1613
comparison stands undisturbed**. OLS-within leads; AR(1) is a sensitivity and never a
correction. *(The real-part +0.1613, carried in prose across three specs, reproduces at
+0.161271 — now a verified number rather than a quoted one.)*

### 1.4 · The community ordering depends on the estimator, and that is the finding

| | Aeolian | Riverine | Inland | ordering |
|---|---:|---:|---:|---|
| within-patch **median** | **+0.227** | +0.129 | +0.134 | aeolian > inland > riverine |
| **pixel-weighted** within | +0.148 | **+0.291** | +0.200 | riverine > inland > aeolian |
| real parts, within-part median *(comparator)* | +0.350 | +0.218 | +0.140 | aeolian > riverine > inland |

**On the median — the quantity the prediction was made about — Aeolian is highest, as
predicted.** Riverine and Inland swap, separated by 0.005, which is a tie rather than an
ordering. **Pixel-weighted, the ordering reverses and puts Aeolian last.** Its median is
carried by small patches, one sloping **+5.821**; its weighted fit is carried by its few
large ones.

**Which estimator is used decides the answer.** Neither is wrong. Any statement of a
community ordering must name the estimator that produced it.

### 1.5 · The between-unit test (§4.6)

Both registered lines were **applied, never refitted**, and both **reproduce from their
stored sources**: the 115-part line 52.697196 + 0.547274, the 64-paddock line 52.652934 +
0.547838. The two agree to 0.03 pp on every patch, so only the 115-part figures are quoted
below.

**Residual against the registered line, all supported patches:**

| community | n | mean residual | *what size alone predicts* | reading |
|---|---:|---:|---:|---|
| Aeolian | 15 | **+7.36** | *+9.93* | at or below the size expectation — **claims nothing beyond it** |
| Riverine | 24 | **+0.12** | *+4.08* | below its size expectation — **on the line** |
| Inland | 54 | **+5.11** | *+0.27* | **far exceeds** what size predicts |
| pooled | 93 | +4.19 | — | mixes three communities whose size slopes differ 30-fold; read the rows above |

**The pre-registered call goes against the artefact reading.** v2 §2.3 fixed it in advance:
*a pooled offset near +2.4 with Inland near zero **is** the size artefact; a pooled offset
near zero, or an Inland offset materially away from zero, is **not**.* Observed: pooled
**+4.19**, Inland **+5.11**. **Inland is materially away from zero, so this is not the size
artefact the prediction described.**

### 1.6 · Where EL bites, and where it does not — with one correction

**Ruling EL** bounds what this section may claim: the size-matched subset survives nothing
(Aeolian 3, Inland 2, Riverine 6 — none at ten), so **the between-unit test cannot be
size-controlled on this data at all**. But EL binds the three communities **differently**
and must not be applied as a blanket:

- **Aeolian (−7.64 pp/decade) and Riverine (−4.41)** have steep spatial-floor size slopes.
  Their results stay bounded, and Aeolian's +7.36 is fully accounted for by size.
- **Inland (−0.23)** has a size slope indistinguishable from zero, so its all-patches
  result should be interpretable without size matching.

**That last point needs one correction, and it changes the number.** Those slopes were
estimated on the **real parts**, and the real Inland parts **start at 588 cells** — while
**28 of the 54 supported unzoned Inland patches (52%) sit below that.** Applying Inland's
≈zero slope there extrapolates it outside the range on which it was measured, which is the
same refusal Arm A makes on the water axis. Aeolian and Riverine are the reverse: their
real parts run down to 33 and 43 cells, so all but one of their patches sit inside the
measured range.

**The two criteria rank the communities oppositely** — Inland is safest on slope magnitude
and least safe on range of support.

**Tested directly.** Inland's residual **declines monotonically with patch size**:

| size quartile | median cells | mean residual |
|---|---:|---:|
| Q1 smallest | 60 | **+8.51** |
| Q2 | 294 | +4.44 |
| Q3 | 954 | +4.27 |
| Q4 largest | 3,099 | **+3.11** |

**It halves, and then plateaus — it does not vanish.** Restricted to the 26 patches inside
the real-part size range, Inland's residual is **+3.39**, against a size expectation of
+0.27. **So the Inland result survives in weakened form: about +3.4 pp rather than +5.1 pp,
and not explained by size on any available estimate.** The headline figure to quote is
**+3.39**, not +5.11.

### 1.7 · The corroboration test does not replicate

PARTREG's counter-finding is that **all three** community slopes sit below the pooled
slope, so the pooled line is steepened by between-community differences rather than
within-community response. On this independent set, with a different unit construction:

| | unzoned between-slope | below unzoned pooled (+0.4869)? | PARTREG real-part slope |
|---|---:|---|---:|
| Aeolian | +0.3021 | yes | −0.3085 |
| Riverine | **+0.5351** | **no — above** | +0.3475 |
| Inland | +0.4159 | yes | +0.2852 |

**Two of three, not three of three. The pattern does not hold here.** Reported as observed;
nothing proposed. A finding that rested on one sample still rests on one.

### 1.8 · The unzoned ground described in its own right

A line fitted **to the unzoned patches** — a description, never a replacement for the
registered line: slope **+0.4869**, intercept 57.6838, r +0.690, residual SD 4.13, n 93,
bootstrap **[+0.2763, +0.6245]**.

Against the real parts' **+0.5473 [+0.3599, +0.7504]**: **the intervals overlap.** An
overlap is a result. **No difference is read into it.**

---

## 2 · Arm A — the between-place scatter on the temporal metric

**39 patches** clear the 500-cell PARTSCATTER floor, 11,478 ha. Only **Inland** is fitted:
Riverine has 8 patches and Aeolian 2, both under the ten-patch rule, and Aeolian also fails
Ruling EH's range test at 1.77 pp.

**The result this arm existed to produce.** Unzoned **Inland** country — 7,738 ha that
entered no fit — sits **0.30 pp** below the paddock relationship at the median (quartiles
−4.84 to +3.66, 28 of 29 tracts inside the paddock wetness range), and its own internal
correlation is **+0.719** against PARTSCATTER's **+0.701**. Riverine sits **+1.99 pp** above
(7 of 8).

**Aeolian gets no comparison at all.** Both its tracts sit at 13.5% and 15.7% wet; the
zoned Aeolian parts span 1.0–11.9%. The smoother returns no value there and **the absence
is carried rather than filled** — a number could have been produced by extending the curve
past the country it was fitted on, and it would have been fiction. The figure says so on
its face.

### 2.1 · §1.1's fork fired, and it fired inside Inland

The temporal metric was expected to be nearly size-insensitive, because a mean's
expectation does not shift with n. **It is not.**

| | pooled | Aeolian | Riverine | **Inland** |
|---|---:|---:|---:|---:|
| **temporal** metric | **+2.68** | +1.46 | −1.54 | **+3.57** |
| **spatial** floor | −2.01 | −7.64 | −4.41 | **−0.23** |

**It is 1.33× the spatial metric in magnitude, points the other way, and it is not
composition.** On the spatial floor the pooled −2.01 was mostly community composition —
Inland alone was −0.23 — which is what let v2 say the out-of-sample test was cleanest where
most of the unzoned ground is. **The temporal metric inverts that: Inland alone is +3.57,
larger than pooled.** The size relationship lives *inside* the community, and inside the
one community carrying this arm's result.

The spatial floor's negative slope is at least partly **mechanical** — a 5th percentile over
more cells reaches further into the tail. The temporal mean has no such mechanism, so
**+3.57 is not an artefact of the statistic**; it says larger units sit in systematically
different country. **A mechanical bias can be reasoned about; a geographic confound
cannot.**

### 2.2 · Two readings of the Inland offset, and neither is claimable

The unzoned Inland tracts are **0.76 decades smaller** than the zoned Inland parts (median
1,473 cells against 8,452). At +3.57 pp per decade, **size alone would put them about 2.7 pp
below** the paddock line. **They sit 0.30 pp below it.** That arithmetic supports two
readings:

1. **The relationship simply holds here** — the observed offset is small and the
   generalisation is real.
2. **This country carries a higher floor than paddock country of equivalent size** — the
   tracts sit about 2.4 pp above where size alone would put them.

**The size slope's r is 0.21. It will not carry an extrapolation, so neither reading can be
claimed.** The honest statement is that **the observed offset is small, the size expectation
is loose, and the two cannot be distinguished on this data.** Both are on the figure's face,
because leaving only the first invites someone to find the second later and think it was
missed. **Nothing is adjusted for size anywhere in either arm.**

---

## 3 · What the two arms together support

**They agree that the relationship generalises, and they are confounded in opposite
directions in the community carrying both results.** Inland's size sensitivity is **−0.23**
on the spatial floor and **+3.57** on the temporal metric. Two metrics whose size confounds
point opposite ways, on two different unit constructions, reaching the same conclusion:
**the cover-and-water relationship holds on ground that entered no fit.**

**That is a triangulation argument, not a repetition.** A confound that could manufacture
the result on one metric would have to work in reverse to manufacture it on the other.

**Precisely what triangulates is the RELATIONSHIP, not the LEVEL.**

- **The response triangulates.** Within-patch +0.2106 against +0.1613; between-unit +0.4869
  against +0.5473 with overlapping intervals; Arm A's Inland r +0.719 against +0.701.
- **The level does not, and that is its own finding.** On the temporal metric unzoned Inland
  sits **on** the paddock relationship (−0.30 pp). On the spatial floor it sits **above** the
  registered line (**+3.39** in-range). The same ground, the same community, two metrics,
  two different answers about level. Reported as observed; **no cause is attributed**, and
  it is exactly the ambiguity §2.2 declines to resolve.

---

## 4 · Limitations

- **The between-unit test cannot be size-controlled on this data** (Ruling EL). No community
  survives size matching ten deep. This bounds Aeolian and Riverine hard; for Inland the
  binding constraint is instead **range of support** — half its patches are smaller than any
  real Inland part, so the in-range figure (+3.39) is the defensible one.
- **The cluster is the patch, not the paddock.** Neighbouring patches share conditions, so
  every interval here is, if anything, **too narrow**. Named, not fixed.
- **35 years are not 35 independent observations** — effective n ≈ 15. Applies to both sides
  of every within comparison (§1.3).
- **A single figure of merit does not exist for the community ordering** (§1.4).
- **No p-values, no significance tests, anywhere.** Slopes, r, residual SD, share positive,
  bootstrap quantiles.
- **No management claim and no condition claim.** This is standard-grazing country, but so
  is other ground, and nothing here compares grazing regimes. A residual is a departure from
  a fitted expectation — not condition, and not management.
- **The two floor metrics are never two views of one number** and no output pairs them.

---

## 5 · Every pre-registered prediction against what happened

| # | prediction | source | outcome |
|---|---|---|---|
| 1 | the temporal metric is nearly size-insensitive | spec §1.1 | **FAILED.** +2.68 pooled, **+3.57 Inland**, against −2.01 spatial. Not composition |
| 2 | pooled within slope near +0.16 | spec §4.5 | **PARTLY HELD.** +0.2106, +31%, comparator on the interval's lower bound |
| 3 | community ordering Aeolian > Riverine > Inland | spec §4.5 | **PARTLY HELD.** Aeolian highest on the median as predicted; the other two tied; the weighted ordering reverses |
| 4 | close to 100% of patches positive | spec §4.5 | **HELD. 100.0%**, all 93, smallest +0.016 |
| 5 | pooled offset +2.4 pp with Inland near zero = size artefact | spec §4.6 / v2 §2.3 | **NOT THE ARTEFACT.** Pooled +4.19 with **Inland +5.11** (+3.39 in-range) — materially away from zero, which the prediction defined as *not* the artefact |
| 6 | AR(1) widens the interval, point estimate holds | spec §4.4 | **FAILED both ways**, on **both** sides equally (−31.8% / −30.5%), so it is a property of the series, not of this ground |
| 7 | all three community slopes below pooled (corroboration) | v2 §4.4 | **DOES NOT REPLICATE.** 2 of 3; Riverine sits above |

**Predictions to check, not targets. No result was adjusted toward any of them.**
