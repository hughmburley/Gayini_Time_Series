# RUN · UNZONED v3 · 10 August 2026

Spec: `docs/reference_update/Gayini_CC_spec_UNZONED_v3.md`. Schema per Ruling DP.

**COMPLETE.** Arm A, Arm B §§4.1–4.5, the STOP resolved by the design seat, Ruling EK's
both-sides refit, **§4.6**, and the §6 assembly. Findings note:
`Output/unzoned/UNZONED_v3_findings_note.md` (Arm B first, Arm A second).

Ground: **unzoned standard-grazing country** — set stocking, a designed treatment arm.
Never a reference, a control, or unmanaged, in any column, file, caption or sentence here.

---

## 1 · Decisions needed

**Two, both at the Arm B STOP, and one of them the spec pre-registered as a stop.**

**BOTH RESOLVED by the design seat, 10 August. D1 → OLS-within leads, and Ruling EK
issued; D2 → no fit, and Ruling EL issued. Recorded below as raised, with the resolution
attached, rather than rewritten.**

**D1 · §4.4's point estimate moved materially, so which estimate leads §4.6 and the
findings note?** The spec expects the AR(1) refit to *widen the interval and hold the
point estimate*. It did neither.

| | slope | interval | width |
|---|---:|---|---:|
| OLS-within, pixel-weighted | **+0.2106** | cluster bootstrap, 10,000 draws, **[+0.1611, +0.2657]** | 0.1045 |
| GLS AR(1) errors | **+0.1436** | model-based **[+0.1268, +0.1604]** | 0.0336 |

The point estimate falls **−31.8%**. The intervals are **not comparable** and I will not
report the GLS one as "narrower" without that attached: one is a cluster bootstrap over
patches, the other is a model-based asymptotic SE. A narrower GLS interval is **not**
evidence that serial correlation does not matter — it is a different question answered by
a different device. What is real is the **point-estimate move**, and §4.4 says that stops
for review.

My reading, offered not assumed: **φ = +0.4817** is substantial, the effective n is ~15 of
35, and a third of the OLS slope is being carried by serially correlated structure. I
would lead with **+0.1436** and carry +0.2106 beside it. But the comparator +0.1613 is an
OLS-within figure, so **the like-for-like comparison is +0.2106 against +0.1613**, and
swapping estimators mid-comparison would be the exact error §5 forbids.

**RESOLVED — Ruling EK.** *Where a sensitivity analysis is run on one side of a stated
comparison, it is run on the other side before either result is reported.* The asymmetry
was the real problem: one side had a serial-correlation sensitivity and the other did not,
so the 31.8% drop could not be read at all. **EK run, and it settles cleanly:**

| side | OLS-within | GLS AR(1) | move | φ |
|---|---:|---:|---:|---:|
| unzoned patches | **+0.2106** | +0.1436 | **−31.8%** | +0.482 |
| real parts (comparator) | **+0.1613** | +0.1120 | **−30.5%** | +0.434 |

**A 1.3 pp difference in the proportional move.** The AR(1) sensitivity is a property of
**annual floor series generally**, not of unzoned ground. Reported once as a caveat on
both sides; **the +0.2106 against +0.1613 comparison stands undisturbed**. The real-part
OLS-within also **reproduces the spec's stated +0.1613 at +0.161271**, so the comparator
is verified rather than quoted. **OLS-within leads the findings note. AR(1) is a
sensitivity, never a correction** — §5 holds: the two estimators are not two estimates of
one number.

**D2 · §1.1's fork failed. Is the size-matched branch satisfied by reporting alone?** The
branch says run Arm A on all patches *and additionally* report the size-matched subset.
Done — but **no community reaches ten surviving patches** (Aeolian 3, Inland 2, Riverine
6), so under v2 §2.3 rule 3 **none is fitted** and the branch yields counts, not a fit.
That is a defensible terminus and it is where I stopped. If a fit was wanted at any
smaller n, it is a ruling, not a judgement call I should make.

**RESOLVED — no fit, and Ruling EL.** *A selection rule that survives nothing is a
limitation, not a null cell.* The three counts must be carried into the findings note as
a constraint on what Arm B §4.6 can claim: **the between-unit test cannot be
size-controlled on this data at all** — and §1.1 has just established that size carries a
real slope on this metric, and one that lives *inside* Inland rather than between
communities. Written into §6 as a note-level obligation, not left in a table.

---

## 2 · Checks

Every one can fail; each halts its script.

| check | tests | result |
|---|---|---|
| **Gate 1 mask** | unzoned non-treed cell count against Ruling DB | **193,229** exactly, 12,048.1 ha |
| **Gate 1 relabelling** | the patch labelling REBUILT from census coordinates against `UNZONED_gate1_patch_inventory.csv` | **625 patches, 0 unmatched ids, 0 cell-count mismatches, 0 community mismatches** |
| **Arm A water axis** | patch mean of the census parquet's counted per-cell `flood_freq_pct` against the mean over years of Gate 1's independently built series | **max 0.0000 pp** over all 625 patches and over the 93 supported |
| **`valid_years`** | constant 35, without which the x identity fails | `[35]` |
| **Arm B patch-years** | rebuild from the `.npy` against the stored `UNZONED_stageA1_patch_year.csv` | **3,253 = 3,253, 0 unmatched**, max value diff 1.4e-14 — *after the correction in §3* |
| **Arm B pooled fit** | recomputed by an independent code path against the earlier A1 run's published slope | **+0.210573 vs +0.210573**, diff 2.8e-17 |
| **§1.1 comparator** | the spec's −2.01 recomputed from `PARTREG_part_residuals.csv` rather than quoted | **−2.014** — reproduces |
| **EJ · opacity direction** | on the BUILT plot, three assertions, both figures | A1 and A2: rho **−1.0000**, ramp **0.450–1.000**, mark-to-value pairing correct |

**Gate 1 is verified, not rebuilt.** The spec says to verify presence and reproduction.
The one thing Gate 1 never persisted is the pixel→patch mapping — it labels in memory and
writes only the inventory and the series — so the labelling was reproduced from census
coordinates alone and checked against the inventory. **No raster was opened**: connectivity
needs a lattice, and an affine translation does not change which cells touch. The grid
spacing was *measured* from the coordinates, not assumed.

---

## 3 · Overrides

**Three. The first changed a number.**

**O1 · The Arm B year filter was wrong, and the check caught it.** I first dropped only
patch-years whose values were NaN. That kept **U0562's 1991**, where a spatial 5th
percentile had been computed over **four valid cells** of a 64-cell patch and stored as
90.15. It is not NaN, so a null test passes it — and it is not the same quantity as the
p05 over 64 cells sitting in every other year of that patch's series. **A year counts only
if it has ≥ 30 valid cells**, which is Gate 1's own rule, and the earlier A1 run applied
it. Corrected; 3,254 → 3,253 rows, and the reproduction check then passed exactly.
Worth keeping because the row was *not missing and not malformed* — it was a real number
of the wrong construction, which no null check can see.

**O2 · §4.5's ordering was compared against the wrong estimator, by me, on the first
pass.** §4.5's table gives the real parts' community figures under the heading **"within-part
median"**. I compared them against the **pooled pixel-weighted** community fits and
reported the ordering as simply inverted. On the median — the quantity the prediction was
actually made about — **Aeolian is the highest of the three, as predicted**. Both orderings
are now reported, because they genuinely differ and the difference is itself the finding.

**O3 · §1.1's fork needed a like-for-like residual, which the literal reading does not
give.** §1.1 says to regress the residual *against the PARTSCATTER smoother*, which is
per-community. The **−2.01 comparator is a residual against a single pooled line**. Two
differently-constructed residuals compared as though they were one is the error this
project keeps finding, so **both** definitions are computed and the fork is decided on the
like-for-like one. It makes no difference to the branch — per-community +1.16, pooled-line
+2.68, both against −2.01 — but the fork should not have rested on a coincidence.

---

## 4 · Disagreements

**§1.1's expectation failed, and it failed in an interesting direction.**

| residual | pooled | Aeolian | Riverine | Inland |
|---|---:|---:|---:|---:|
| **temporal**, per-community smoother | **+1.16** | +3.03 | −1.55 | +2.81 |
| **temporal**, pooled line *(like-for-like)* | **+2.68** | +1.46 | −1.54 | +3.57 |
| **spatial** comparator, pooled line | **−2.01** | −7.64 | −4.41 | −0.23 |

The spec's table says the temporal metric's size sensitivity is *"expected to be slight"*
because a mean's expectation does not shift with n. **It is not slight. It is 1.33× the
spatial metric's in magnitude and points the other way.**

**It is also NOT a composition effect, and that is the decisive comparison.** On the
spatial floor the pooled −2.01 was mostly community composition: **Inland alone was −0.23**,
indistinguishable from zero, which is why v2 could say the out-of-sample test was cleanest
exactly where most of the unzoned ground is. **The temporal metric does the opposite.
Inland alone is +3.57 — larger than the pooled +2.68.** The size relationship is *inside*
the community, not between communities, and it is strongest in the one community this
task's result rests on.

The mechanism reading, offered as such: the spatial floor's negative slope is at least
partly **mechanical** — a 5th percentile over more cells reaches further into the tail. The
temporal mean has no such mechanism, so its **+3.57 within Inland is not an artefact of the
statistic at all**; it says bigger units sit in systematically different country. That
makes it a *harder* problem than the one the spec expected, not a softer one: a mechanical
bias could be reasoned about, a geographic confound cannot.

**What it does to the Inland result — stated as an expectation to read against, never
subtracted** (v2 §2.3, spec §5). The unzoned Inland tracts have a median of **1,473 cells**
against the zoned Inland parts' **8,452** — **0.76 decades smaller**. At +3.57 pp per
decade, **size alone would put them about 2.7 pp BELOW the paddock line.** They sit
**0.30 pp** below it. So the observed offset is far smaller than size alone predicts, and
the generalisation result survives the fork rather than depending on it being ignored.
The size slope's r is 0.21 — loose — so this is an expectation, not an arithmetic.

**Amendment: §1.1's outcome now reaches both figure faces.** The pre-registered fork fired
and the captions carried no size statement. Both A1 and A2 now say that size is not
neutral on this measure and is not corrected for anywhere, give the +3.6 pp per decade
figure for Inland, and state that these tracts are much smaller than the paddock areas.
A2 additionally carries the expectation-versus-observation sentence above. A reader
comparing the two figures needs it, and the size-matched branch producing no fitted
community makes it more necessary, not less.

**This does not invalidate Arm A** — the fork pre-registered exactly this branch, no
residual is adjusted for size in either branch, and the offsets below are reported as
descriptive distances, not tests.

**The unzoned Aeolian country is wetter than every zoned Aeolian part**, so it gets **no
comparison at all** rather than an extrapolated one. Both its tracts sit at 13.5% and 15.7%
wet; the zoned Aeolian parts span 1.0–11.9%. The loess returns NA there and **the NA is
honoured**. A number could have been produced by extending the curve; it would have been
fiction.

---

## 5 · Artefacts

### Arm A · the between-place scatter on the temporal metric

| path | what |
|---|---|
| `Output/figures/unzoned/UNZONED_A1_unzoned_patches_temporal_p05_vs_water.png` | figure A1, unzoned alone, registered `9c0cd5bb04fa…` |
| `Output/figures/unzoned/UNZONED_A2_zoned_and_unzoned_temporal_p05_vs_water.png` | figure A2, both sets, registered `fe1b303d42bc…` |
| `Output/unzoned/UNZONED_v3_size_robustness.csv` | §1.1, both residual definitions plus the recomputed comparator |
| `Output/unzoned/UNZONED_v3_armA_scatter_input.csv` | the 39 plotted patches, qualifiers as columns |
| `Output/unzoned/UNZONED_v3_armA_all_patches.csv` | all 625, with every support flag |
| `Output/unzoned/UNZONED_v3_armA_selection_counts.csv` | the three §3.1 rules |
| `Output/unzoned/UNZONED_v3_armA_size_matched.csv` | v2 §2.3 rule 3 |
| `Output/unzoned/UNZONED_v3_armA_community_support.csv` | EH range + patch-count gates, both stated |
| `Output/unzoned/UNZONED_v3_armA_descriptive_offsets.csv` | §3.4 — offsets, never residuals |
| `Output/unzoned/UNZONED_v3_plot_overlay_summary.csv` | §2's plot join, plot support, kept separate (C10) |
| `scripts/12_zone_stratum/UNZONED_v3_armA_prepare.py` · `R/diag/UNZONED_v3_armA_figures.R` · `R/diag/UNZONED_v3_size_robustness.R` | producers |

**The three counting rules (§3.1).** 625 patches → **93** supported (≥25 yrs of ≥30 valid
cells) → **39** at the 500-cell PARTSCATTER floor, 11,478.3 ha. A bare 33-cell threshold
gives **91**. The support rule and the bare threshold nearly coincide (93 vs 91) while the
500-cell floor removes more than half — this ground is **observable but small-grained**.
At a median of 293 cells the spec expected the floor to bite hard, and it did.

| community | patches at the floor | ha | water range % | 10–90 span | smoother | r |
|---|---:|---:|---:|---:|---|---:|
| Inland Floodplain | **29** | 7,738.4 | 4.6 – 40.5 | 19.51 | **drawn** | **+0.719** |
| Riverine Chenopod | **8** | 3,013.9 | 3.3 – 41.2 | 23.39 | no — under ten patches | +0.531 *(not printed)* |
| Aeolian Chenopod | **2** | 726.1 | 13.5 – 15.7 | 1.77 | no — under ten **and** fails EH | n/a |

**§3.4 descriptive offsets — not residuals, not a test.**

| community | median offset | quartiles | tracts compared |
|---|---:|---|---:|
| Inland Floodplain | **−0.30 pp** | −4.84 to +3.66 | 28 of 29 |
| Riverine Chenopod | **+1.99 pp** | +0.27 to +8.57 | 7 of 8 |
| Aeolian Chenopod | **no comparison** | — | 0 of 2 |

**Inland is the result.** 7,738 ha of country that entered no fit sits **0.3 pp** from the
paddock relationship at the median, and its own internal correlation, **+0.719**, is within
0.02 of PARTSCATTER's Inland **+0.701**. The relationship generalises to ground it was
never fitted on — and Inland is where most of the unzoned hectares are.

**§2's plot join.** **18 of 66** monitoring plots fall on unzoned ground: **all 15
standard-grazing plots**, plus 3 14-day grazing plots. So the standard-grazing arm has
never had a paddock to belong to — which is exactly why it had never been reported above
plot support. This table is the join to every plot-support result and is kept at plot
support, never mixed into a pixel-support figure (C10).

### Arm B · the within-patch replication · §§4.1–4.5

| path | what |
|---|---|
| `Output/unzoned/UNZONED_v3_armB_patch_year.csv` | 3,253 patch-years, the fitted table |
| `Output/unzoned/UNZONED_v3_armB_per_patch_slopes.csv` | §4.1, 93 patches |
| `Output/unzoned/UNZONED_v3_armB_slope_distribution.csv` | §4.1 distribution + share positive |
| `Output/unzoned/UNZONED_v3_armB_within_fits.csv` | §§4.2–4.3, pooled and per community |
| `Output/unzoned/UNZONED_v3_armB_serial_correlation.csv` | §4.4 lag-1 and effective n |
| `Output/unzoned/UNZONED_v3_armB_ar1_fit.csv` | §4.4 GLS AR(1) |
| `Output/unzoned/UNZONED_v3_armB_community_comparison.csv` · `_predictions.csv` | §4.5 |
| `scripts/12_zone_stratum/UNZONED_v3_armB_within.py` · `_predictions.py` · `R/diag/UNZONED_v3_armB_ar1.R` | producers |

**§4.1 — the slope distribution. 100% positive, everywhere.**

| scope | n | min | Q1 | median | Q3 | max | share + |
|---|---:|---:|---:|---:|---:|---:|---:|
| all | 93 | +0.016 | +0.088 | **+0.135** | +0.202 | +5.821 | **100%** |
| Aeolian | 15 | +0.025 | +0.115 | +0.227 | +0.564 | +5.821 | 100% |
| Riverine | 24 | +0.053 | +0.094 | +0.129 | +0.195 | +1.303 | 100% |
| Inland | 54 | +0.016 | +0.084 | +0.134 | +0.182 | +0.545 | 100% |

**§§4.2–4.3.** Pooled within **+0.2106** (r +0.331, residual SD 13.82, 3,253 obs, 93
patches). Cluster bootstrap **on the patch**: 2,000 draws [+0.1618, +0.2621]; 10,000 draws
[+0.1611, +0.2657]. **The cluster is the patch and that is not the real-part choice**,
which clusters on `zone_fid` — there is no paddock on this ground. Stated as a column on
every fit row, not substituted silently.

**§4.4.** Median residual lag-1 **+0.399** → effective n **15.0 of 35** (real parts +0.364
→ 16.3). GLS AR(1): **+0.1436**, φ **+0.4817**. See D1.

**§4.5.**

| prediction | verdict | observed |
|---|---|---|
| pooled within near +0.16 | **PARTLY HELD** | +0.2106 OLS-within, **+31%** on the like-for-like comparison; +0.1613 sits essentially **on the lower bound** of the unzoned interval |
| Aeolian > Riverine > Inland | **PARTLY HELD** | on the **median**: aeolian > inland > riverine — Aeolian highest as predicted, the other two tied at 0.005 apart. **Pixel-weighted the ordering reverses** and puts Aeolian last |
| close to 100% positive | **HELD** | **100.0%**, all 93, smallest +0.016 |

**The estimator decides the community answer, and that is the finding.** Aeolian's median
is carried by small patches — one slopes **+5.821** — while its weighted fit is carried by
its few large ones. Aeolian is first by median and last by pixel weight. Neither is wrong;
they are different questions, and any figure or table stating a community ordering has to
say which estimator produced it (§5).

---

### Arm B · §4.6, the between-unit prediction

Both registered lines **applied, never refitted**, and both **reproduce from their stored
sources** — 115-part 52.697196 / 0.547274 from `PARTREG_part_regression_coefficients.csv`,
64-paddock 52.652934 / 0.547838 from `dim_headline_number`. They agree to 0.03 pp on every
patch.

| community | n | mean residual | *size alone predicts* | reading |
|---|---:|---:|---:|---|
| Aeolian | 15 | +7.36 | *+9.93* | at or below the size expectation — claims nothing beyond it |
| Riverine | 24 | +0.12 | *+4.08* | below its size expectation — on the line |
| Inland | 54 | **+5.11** | *+0.27* | far exceeds what size predicts |
| pooled | 93 | +4.19 | — | mixes three communities whose size slopes differ 30-fold |

**The pre-registered call goes against the artefact reading.** v2 §2.3 fixed it in advance:
a pooled offset near +2.4 **with Inland near zero** is the size artefact; an Inland offset
materially away from zero is not. Observed pooled +4.19 with **Inland +5.11**.

**But EL's per-community bound needed one correction, and it moved the number.** The design
seat's framing — Aeolian and Riverine bounded by steep size slopes, Inland interpretable
because its slope is ≈0 — is right about the slope and incomplete about its **support**.
Those slopes were estimated on the **real parts**, and real Inland parts start at **588
cells**, while **28 of 54 supported unzoned Inland patches (52%) sit below that**. Applying
Inland's ≈zero slope there extrapolates it outside its measured range — the same refusal
Arm A makes on the water axis. Aeolian and Riverine are the reverse: their real parts run
to 33 and 43 cells, so all but one of their patches are inside the measured range. **The
two criteria rank the communities oppositely.**

**Tested rather than argued.** Inland's residual declines monotonically with size —
**+8.51 → +4.44 → +4.27 → +3.11** across size quartiles — a size component the −0.23 slope
could not detect because it was never estimated below 588 cells. **It halves and then
plateaus; it does not vanish.** In-range (26 patches) Inland is **+3.39** against a size
expectation of +0.27. **The headline figure is +3.39, not +5.11**, and it is still not
explained by size on any available estimate.

**v2 §4.2–4.4.** Unzoned between-unit fit (a description, never a replacement): slope
**+0.4869**, intercept 57.6838, r +0.690, residual SD 4.13, bootstrap **[+0.2763, +0.6245]**
clustered on the patch. Against the real parts' +0.5473 [+0.3599, +0.7504] — **the intervals
overlap, and no difference is read into an overlap.** The corroboration test **does not
replicate**: 2 of 3 community slopes below pooled, Riverine sits above. Reported; nothing
proposed.

### §6 assembly

`UNZONED_patch_summary.csv` (625 rows, both floor metrics named distinctly, within-patch
slope, descriptive offset, residuals against both registered lines, all four support
flags) · `UNZONED_regression_coefficients.csv` (13 fits, **every row naming WITHIN or
BETWEEN**, stackable with PARTREG) · `UNZONED_patches_epsg8058.gpkg` (625 polygons, **area
closes to 12,048.1 ha against the cell count**) · `UNZONED_v3_data_dictionary.md` ·
`UNZONED_v3_findings_note.md` · `UNZONED_v3_manifest.csv` (30 artefacts, first-50-MB
SHA-256). **The community-slope coefficients are in the manifest** — the PARTREG pack
omitted exactly those and §6 says it must not repeat.

**One defect found and fixed in my own manifest:** it listed itself, so its own row carried
the *previous* version's checksum — worse than no row at all in a checksum file. The
manifest now excludes itself. The `.gpkg` is not version-controlled, consistent with every
other spatial output in the repo.

## 6 · Not done

- **Nothing in the spec is outstanding.** Both arms, §4.6 and every §6 item are delivered.
- **Queued, not done — the Ruling EM audit.** Enumerate every validity filter in the
  pipeline, state for each whether it tests **presence** or **support**, and flag the ones
  testing only presence. Post-deadline but **ahead of the analytical queue**: a filter that
  admits a four-cell percentile is upstream of everything.
- **No community was fitted in the size-matched branch** (D2). **Under Ruling EL this is a
  findings-note obligation, not a table cell:** the between-unit test cannot be
  size-controlled on this data at all, which bounds what §4.6 may claim.
- **Ruling EM is a standing obligation on every validity filter in this project**, not
  just Arm B's. Filters written as null tests elsewhere may admit values computed over too
  few inputs. Not audited here — recorded in the issues log.
- **Held under DJ, untouched:** the five-qualifier schema gap (Ruling EI — these figures
  carry the five in `provenance_note` as prose, same as PARTSCATTER) · `metric_id` NULL on
  both registrar paths · the Bala 23 inset · the four locator paths · the
  `gayini_area_map` parameter · EA/EC on the `report_figures` producer.

---

## 7 · Rulings

**Applied.** **AZ / CX** — x is the share of cells seen wet, mean over years; never a
between-year frequency. **DA** — each community's own supported range is stated and no
figure claims a pattern in the community that has none. **DB** — 193,229 unzoned non-treed
cells, verified, and the unit and community populations are kept apart. **DM** — water from
the census **parquet**, counted-8058. **DP** — this schema. **DS** — every script written to
a file and parse-checked; no heredoc. **EA** — no internal identifiers on either face.
**EB** — checked before every git operation; `main` had not moved and no second session was
live. **EC** — canonical labels, identical to PARTSCATTER's so the two read as a pair;
"vegetation community" written out. **EH** — Aeolian excluded on the central-range test
(1.77 pp). **EJ** — three assertions on the built plot for both figures. **C10** — the plot
overlay is plot support and is never mixed into a pixel-support figure. **I-40** — the
size-robustness claim, the −2.01 comparator, Gate 1's labelling and the earlier run's
fits were all *measured*, not accepted. **I-42** — the reproduction checks are shown able
to catch: the patch-year check **did** catch a real defect (§3, O1) on its first run.

**§5's prohibitions observed.** The within and between slopes are never presented as two
estimates of one number; every fit row names its estimator. The two floor metrics never
share a figure or a column pair — Arm A is `veg_p05_temporal_mean` throughout, Arm B is
`veg_p05_spatial` throughout, and each output names which. No management claim, no
condition claim, no p-values. The ground is called unzoned standard-grazing country
everywhere.

**Issued in response to this run, 10 August, and written to
`docs/Gayini_issues_log.md`:** **EK** — a sensitivity run on one side of a comparison is
run on both before either result is reported. **EL** — a selection rule that survives
nothing is a limitation, not a null cell. **EM** — a validity filter tests the quantity's
support, not only its presence; a value computed over too few inputs is missing data that
does not present as missing.

**Not cited, and not available:** none. All fourteen ruling texts in §8 are held, plus
EK, EL and EM.
