# SPAT-1 — findings note

**Measuring the thing every figure in this project asserts.** 10 August 2026.
Spec `docs/spatial/Gayini_CC_spec_SPAT1.md`. Run record `Output/runs/RUN_SPAT1_20260810.md`.

**Metric:** `veg_p05_temporal_mean` throughout. **`veg_p05_spatial` does not appear in this
task at all** — a quantile *across* a unit's cells changes meaning as the unit changes size,
which on a scale ladder is not a confound to measure but a definitional change that would
make the ladder meaningless.

**Extent:** 61,654.9 ha analysed of an 85,910.8 ha property (72%). Named together
throughout (EQ).

---

## 1 · The headline

Every figure in this project carries a version of *"intervals are display only"*, *"~1M
pixels is sampling uncertainty, not independent n"*, *"neighbouring units may share
conditions, so the band is if anything too narrow"*. **None had been measured.**

**Both halves are true. One by a factor of 65, the other by about 15%.**

| | nominal n | effective n | intervals too narrow by |
|---|---:|---:|---|
| pixel census, Inland | 717,627 | **170** | **65×** |
| paddock × community areas | 100 | **74.9** | 1.16× |
| paddocks | 64 | 59.1 | 1.04× |
| unzoned tracts | 39 | 34.6 | 1.06× |

**The pixel-grain caveat understated the problem; the unit-grain caveat overstated it.**
Nobody could have guessed which way round that would fall.

**The mechanism.** `n_eff` saturates at `1/ρ̄`. The property is ~55 km across and residual
structure reaches ~1–3 km, so most pairs are uncorrelated, ρ̄ is tiny, and the pixel census
caps near 170 **however many cells it has**. A hundred units are already few enough that the
same ρ̄ barely bites.

---

## 2 · How far structure reaches

Spherical, isotropic, median of ten seeds:

| community | range | ten-seed spread | model adequacy |
|---|---:|---|---|
| Aeolian Chenopod | **1,110 m** | 1,069–1,172 | **pseudo-R² +0.26 — poor** |
| Riverine Chenopod | **2,983 m** | 2,865–3,111 | **+0.55 — poor** |
| Inland Floodplain | **3,217 m** | 2,892–3,779 | +0.78 — adequate |

**Structure reaches kilometres, not metres.** That settles the question the spec posed.

### 2.1 · The non-stationarity is a FINDING, not only a caveat

**Aeolian's variogram peaks at 7.9 km and falls 39.5% by 20 km. Riverine's peaks at 4.9 km
and falls 22.5%.** A variogram that rises and falls is not a stationary field reaching a
sill — it is **the signature of large-scale structure in the residuals that the water axis
does not capture.**

**That is a direct answer to a question asked earlier in the day: is the pattern
geographically structured? Yes — and there is a gradient in the part water does not
explain.** In two of the three communities, cover has organised spatial structure left over
after water is accounted for, at scales of 5–8 km.

**It is not detrended away.** Detrending would remove the finding to rescue the estimate.
The estimate is reported with its adequacy attached instead, and the adequacy travels into
every caveat derived from it.

**What it costs:** for Aeolian and Riverine the fitted range summarises a shape the data
does not have, so their ranges and every `n_eff` derived from them are **indicative**.
Inland's are measured.

### 2.2 · Anisotropy — strong, and not averaged away

| community | 0° (E–W) | 45° | 90° | 135° | max/min |
|---|---:|---:|---:|---:|---:|
| Aeolian | **5,766 m** | 681 | 753 | 1,767 | **8.5** |
| Riverine | 4,122 | 2,866 | 3,064 | 3,329 | 1.4 |
| Inland | 7,343 | **unresolved beyond 20 km** | 1,658 | 2,958 | — |

This is a floodplain and water moves along paths. **Inland's north-east direction had not
decayed within the 20 km measured** — under Ruling EN that is not a range, the fitted
37.7 km is withheld, and what it licenses is the statement that structure persists past
20 km along that axis. An isotropic average would understate reach along the water and
overstate it across.

---

## 3 · The effective n, by two independent routes

Clifford–Richardson is derived for the variance of a **mean**. Every use this project will
make of the number is to widen a **slope** interval, whose inflation depends on the spatial
structure of *x* as well as of the residuals — and *x* is a flood-frequency surface. So a
second, independent route was run before anything used the first: a **spatial block
bootstrap on 5 km blocks**, larger than the largest fitted range.

| community | n_eff (mean, Clifford–Richardson) | n_eff (slope, block bootstrap) | ratio |
|---|---:|---:|---:|
| Aeolian | 159.7 | 118.9 | 0.74 |
| Riverine | 74.0 | 90.1 | 1.22 |
| Inland | 170.2 | 302.6 | 1.78 |

**They agree within the pre-registered factor of two**, so the pinned numbers stand and
their caveats gained a line naming the slope figure. **Use the slope figure when widening a
slope interval.**

**These are order-of-magnitude quantities, not precise ones.** At 8 km blocks the same
bootstrap gives 89 / 55 / 197 — 25–35% lower. The block-size choice moves the answer, so
read these as *"of order 100–300, not of order 100,000"*, which is the claim that matters.

**All thirteen are pinned** in `dim_headline_number` as `spat1_n_eff_*`, each caveat
carrying method, fitted range, model form, ten-seed spread, maximum lag, the isotropy
assumption, the model adequacy and the slope cross-check. `SPAT1_effective_n.csv` carries
each row's `number_id`. Any interval computed from them **cites the `number_id` at the point
of quotation** (CZ).

---

## 4 · The scale ladder

Nested square blocks anchored to one origin. **The 250 m and 500 m rungs cannot physically
reach the 500-cell floor** — a 500 m block holds at most 400 cells — so they are counted and
not fitted, exactly as pre-registered. The fitted ladder begins at 1 km: **746 units at
1 km, 323 at 2 km, 129 at 4 km.**

### 4.1 · Slope against grain — and why both ladders had to be drawn

**Ruling EU.** Stage 0 measured the straight line departing from the GAM at the wet end
(median gap 1.51 pp on Inland, maximum 17–22 pp, 9.9% of cells over 5 pp). Averaging *x* and
averaging *y* within a block are not the same operation when *y* is curved in *x*, and the
discrepancy grows with block size — **so a climbing OLS ladder is exactly what curvature
produces with no scale effect at all.** Both ladders are therefore reported.

| community | OLS: cell → 1 km → 2 km → 4 km | GAM average slope | spread OLS / GAM | reading |
|---|---|---|---|---|
| **Inland** | +0.530 → +0.598 → +0.570 → +0.506 | +0.654 → +0.653 → +0.574 → +0.540 | 0.09 / 0.12 | **both flat — scale-invariant on a neutral unit** |
| **Riverine** | +0.513 → +0.552 → +0.506 → +0.540 | +0.875 → +0.825 → +0.702 → +0.540 | 0.05 / 0.34 | **slope survives aggregation, shape does not** |
| **Aeolian** | +0.259 → +0.179 → −0.006 → **−0.201** | +0.145 → −0.150 → −0.093 → −0.201 | 0.46 / 0.35 | **both move together — not curvature** |

**Inland is the result that carries a methods section.** The relationship is the same on a
4 km block as on a single 25 m cell — a far stronger claim than holding across the three
bespoke unit types the project happened to build.

**Riverine is a third case the pre-registration did not anticipate.** Its OLS slope is flat
across the ladder while its average marginal effect falls by 0.34. The straight line's
*slope* survives aggregation; the *shape* it approximates does not. Neither a clean scale
effect nor clean curvature.

**Aeolian's slope collapses and crosses zero by 4 km, and both ladders move together**, so
it is not an artefact of forcing a line through a curve. Its intervals are also the widest
on the figure — at 4 km it has few units and few independent super-blocks — so the collapse
is real in the point estimate and weakly constrained.

**The restricted ladder** (EU point 2), fitted only where |GAM − OLS| ≤ 2 pp, is reported
alongside. That range covers **99.9% of Aeolian cells, 84.7% of Riverine, 83.8% of Inland**;
the excluded 15–16% is the wet end in both chenopod communities.

### 4.2 · Level against grain — the cleanest read on UNZONED §1.1

UNZONED v3 §1.1 found the temporal metric's level rising **+3.57 pp per decade of size
within Inland**, measured on irregular parts where size and geography vary together and
could not be separated. **A regular grid separates them.**

| community | mean cover: cell → 4 km | change per decade |
|---|---|---:|
| Aeolian | 46.0 → 46.1 | **+0.01** |
| Riverine | 44.0 → 44.1 | **+0.05** |
| Inland | 61.0 → 58.5 | **−1.13** |

**Flat, and Inland's drift is the wrong sign.** Over the ladder's 2.2 decades, +3.57 pp per
decade would have produced a **+7.9 pp rise**; the observed change is **−2.5 pp**.

**So the +3.57 is geographic, not mechanical.** Bigger irregular units genuinely sit in
different country. **UNZONED §1.1's reading stands strengthened**, and the second of its two
undecidable readings — that unzoned ground carries a higher floor than paddock country of
the same size — is not resolved by this, but the aggregation explanation for the size slope
is now excluded.

---

## 5 · Every pre-registered prediction against what happened

| # | prediction | source | outcome |
|---|---|---|---|
| 1 | range under ~250 m → existing intervals roughly honest | §4.4 | **not this branch** |
| 2 | range 250 m – 2 km → pixel intervals badly narrow, unit intervals defensible | §4.4 | **Aeolian falls here (1,110 m)** |
| 3 | range > 2 km → unit intervals also too narrow, n_eff at part grain in the tens | §4.4 | **Riverine and Inland by the criterion.** Consequence only mildly borne out: n_eff 74.9 of 100 is "in the tens" but means 16% widening, not a collapse — **Ruling ET, the criterion and the consequence were separate claims and only one had been measured** |
| 4 | slope flat across the ladder → scale-invariant | §6.2 | **HELD for Inland**, and for Riverine's OLS but not its shape. **NOT held for Aeolian** |
| 5 | slope climbs with block size → modifiable areal unit effect | §6.2 | **not observed.** Aeolian *falls*; nothing climbs |
| 6 | level rises on a regular grid → +3.57 has a mechanical component | §6.2 | **NOT held** |
| 7 | level flat on a regular grid → +3.57 is geographic, UNZONED strengthened | §6.2 | **HELD** — +0.01 / +0.05 / −1.13 pp per decade |

**No result was adjusted toward any of these.**

---

## 6 · Limitations

- **Two of three communities are not second-order stationary** (§2.1). Their ranges and
  every `n_eff` derived from them are indicative. Inland's are measured.
- **`n_eff` is order-of-magnitude.** Block size moves it 25–35% (§3).
- **The isotropic `n_eff` assumes what §2.2 disproves.** An isotropic average of a
  directional field understates correlation along the long axis and overstates it across;
  the net effect is not signed a priori. The anisotropy is reported beside every number.
- **Nothing here is applied.** No interval widened, no estimate corrected, no existing
  figure re-rendered. Stage A and Stage B measure; what follows is a design-seat decision.
- **No cause is attributed.** A range is a distance over which residuals covary. It is not
  soil, not position, not management.
- **No p-values anywhere.**
