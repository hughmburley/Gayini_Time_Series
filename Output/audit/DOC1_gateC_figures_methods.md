# DOC-1 Gate C — figure and method claims

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no writes, no re-renders, no new analysis.

**Audited input:** `docs/reports/Gayini_RS_methods_doc_V6.docx` · 9,821,125 bytes · modified 2026-08-04T13:15:07 ·
SHA-256 `63177e5fc45a9a02072abd654349d8d2eb75d9fb111db2c6260e4751e78e584b`.
Word lock released before the gate; hash re-checked at gate open and unchanged from Gate 0.

**Result in one line:** the three corrected method descriptions are confirmed against the code, C3 and C4 are
both settled from source, and the method-versus-implementation test found **three further descriptions
simpler than their implementations** plus **two figure defects**. No stated value was found wrong at this gate.

---

## C4 · The percentile-fan endpoints — **settled: the communities genuinely stop**

Reproduced the binning of `scripts/03_inundation_products/28_build_veg_water_percentile_fan.R:87-108`
from the same four rasters — the wet and valid annual stacks, `total_veg_p05_8058`, and
`veg_regime_class_8058` — with the script's own constants (`BIN_W = 10`, `MIN_BIN_N = 500`, the nine focus
codes). The reproduction yields **988,829 focus pixels**, matching the persistence README's non-treed count
with finite p05 exactly, which is the check that the pipeline was reproduced and not merely re-imagined.

| community | last drawn bin | bins beyond the cut | pixels beyond | **well-populated bins discarded** |
|---|---|---|---|---|
| Aeolian | 40–50% (cut drawn at 50%) | 50–60: **260** · 60–70: **251** · 70–80: **60** | 571 (0.74% of Aeolian) | **none** |
| Riverine | 60–70% (cut drawn at 70%) | 70–80: **67** · 80–90: **2** | 69 (0.036% of Riverine) | **none** |
| Inland | 90–100% | — | 0 | **none** — no truncation occurs at all |

**Every bin beyond every cut is itself sparse.** Cumulative truncation discards nothing that per-bin
exclusion would have kept, so on this data the two rules coincide and the endpoints are **genuine community
limits, not artefacts**. The stronger statement can be restored, and the evidence is the table above:
Aeolian country essentially ceases above 50% flood frequency (571 of 77,544 pixels) and Riverine above 70%
(69 of 193,658).

**One caveat that should travel with the restored statement.** The Aeolian endpoint bin holds **exactly 500
pixels** against `MIN_BIN_N = 500`. The test is `n >= MIN_BIN_N`, so it is retained by a margin of zero. One
pixel fewer and the Aeolian curve would end a full 10-pp bin earlier, at 30–40%. The endpoint is correct as
drawn, and it is sitting exactly on the knife edge — worth knowing before the number is built upon.

**§7.2's own statements, checked.** *"The Aeolian panel terminates near 45% flood frequency and the Riverine
panel near 65%"* — **CONFIRMED**: points are plotted at bin centres, which are 45 and 65. *"Under the
cumulative truncation rule … these endpoints mark where each community's cell counts first fall below the
retention threshold"* — **CONFIRMED** as a description of the mechanism.

---

## C3 · The two named checks

### The three-arm grid — Gate B's unresolved pair, now settled from source

Both quantities reproduce from `T6_gateE_figures.R`, which computes them at render time.

| quantity | document | reproduced | source |
|---|---|---|---|
| raw gap, Aeolian | **−32.0** | **−32.044** | mean over 35 years of (arm line − grazed-zone median line) |
| adjusted gap, Aeolian | **−10.5** | **−10.462** | area-weighted band mean, = pin `ref_grazed_floor_aeolian` −10.46 |

**Both CONFIRMED.** The raw gap is `mean(arm veg_p05_spatial − per-year median of the grazed zones)` over the
35 years, from `fact_three_arm_stratum_veg_annual` (`regime_band='ALL'`, `series_variant='mean_of_seasons'`)
against `fact_zone_community_veg_annual` filtered to `grazing_excluded=0`, `below_min_support=0` — script
lines 18–23 and 116–120.

**The adjustment is area-weighted within stratum, exactly as described. CONFIRMED.** Weights are non-treed
stratum area per wetness band from `census_by_zone_stratum`, combined over low/mid/high (lines 33–53). The
equal-weighted alternative gives **−11.167** and is recorded only as a spread endpoint. All nine label values
reproduce their `dim_headline_number` pins, and the script asserts this at render and stops on drift.

**A stale comment in the producing code.** `T6_gateE_figures.R:112` reads *"On Aeolian these are -30.9 and
-10.5"*. The adjusted value is right; **the raw value is not** — the code one line below computes −32.044.
The document is correct and the comment in the code that produces it is wrong. Not a document defect; a
trap for the next reader of that script.

**The Gate B caution was justified.** The nearest registered pin, `t10_bala29ca_aeolian_level_deficit` = −32.1,
sits within 0.06 of the true −32.044 — close enough that reasoning from it would have produced a
right-looking number attached to the wrong object. It is a different quantity that happens to be adjacent
because Bala 29ca is the only ungrazed paddock in Aeolian country.

### The green-share and persistence-overlay figures

**Green-share definition — CONFIRMED.** `green_frac_pct = 100 × PV / total_veg`, read **paired in the season
that sets each cell's total-vegetation 5th-percentile order statistic**, on the native 30 m EPSG:3577 grid,
`MIN_SEASONS >= 50`. Matches `Output/tables/taskM_green_at_floor_area.csv` and the persistence README, and
the caption states it correctly.

**Areas and overlap**, computed from the two shipped 8058 surfaces at `PIXEL_AREA_HA = 0.062351428`:

| layer | pixels | area |
|---|---|---|
| total-cover floor ≥ 75 (blue) | 127,819 | **7,969.70 ha** |
| green-share floor ≥ 50 (green) | 8,020 | **500.06 ha** |
| both (yellow) | 6,513 | **406.09 ha** |

- **"The two surfaces largely do not coincide"** — Jaccard **5.04%**. **CONFIRMED overall, but the statement
  is asymmetric and the asymmetry matters.** 94.90% of the persistent total-cover surface is *not*
  majority-green — which is the direction the document means, and the next sentence
  (*"Most country that retains high total cover … retains it as dry material"*) states it correctly and is
  **CONFIRMED**. But **81.21% of the green-share surface *is* inside the total-cover surface**. Read
  symmetrically, the two surfaces do substantially coincide; read as "most persistent cover is not green",
  the claim is right.
- **"The areas satisfying both criteria are small, linear"** — **CONFIRMED, and more strongly than the bounding
  -box geometry first suggested.** 406.09 ha is 0.66% of the non-treed 61,655 ha. The decisive measure is
  inscribed width: the yellow class is **nowhere wider than 149.8 m**, area-weighted mean **116.8 m** (≈4.7
  census cells), against **1,708 m maximum and 893 m mean** for the blue surface. It is genuinely narrow
  country, not a small blob.
- **"and follow the channel network"** — **UNVERIFIABLE, and the document says so itself.** No channel or
  watercourse layer is registered anywhere in the project (issues log T3-I5), so alignment cannot be
  demonstrated. §Limitations states this explicitly. The assertion precedes its qualification by two
  sentences, which is a presentation choice rather than an error.

---

## Figure defects

### **F-1 · Figure 10's 5 ha statement does not hold for the class it draws in yellow**

The caption reads *"Connected components smaller than 5 ha removed."* True of each **input** surface —
both ship with **zero** components under 5 ha. It is **not** true of the **intersection** as drawn:
**20 of the yellow class's 50 components are smaller than 5 ha**, totalling 28.5 ha. Intersecting two
filtered surfaces reintroduces sub-threshold fragments; the filter was applied before the intersection,
not after. The caption describes the inputs and the reader applies it to the output.

### **F-2 · The green layer in Figure 10 is 500 ha; the text beside it quotes 6,458 ha**

Figure 9's discussion states the green-share extent as **6,458 ha, measured at native 30 m** — correct, and
correctly labelled. Figure 10 draws the green-share layer from the **8058** surface **after** the 5 ha
component filter: **500.06 ha**. The same nominal object differs by a factor of **13** between adjacent
figures, and nothing tells the reader that the green they see is not the 6,458 ha just quoted.

Two operations compound: reproject-then-threshold rather than threshold-then-reproject (issues log **T3-I1**,
already a standing rule — the README warns the 8058 area is 3,744.20 ha and must not be quoted as measured),
then the 5 ha filter, which removes ~87% of what remains because the surface is narrow strips.

The blue layer has the same structure at a much smaller magnitude: the text quotes **8,300 ha** at t = 75
from the threshold sweep, the figure draws **7,969.70 ha** after the component filter — a 330.7 ha, 4%
difference.

**Neither is a false sentence.** Every value is correct where it is stated, which is why this belongs here
and not in the contradicted list. It is a caption that omits the operation standing between the number in
the text and the shape on the page.

---

## C1 · The corrected method descriptions

### Confirmed against the code

| § | claim | verdict |
|---|---|---|
| 6.5 | two-part rule: median *r* ≥ 0.20 **and** sign consistency | **CONFIRMED** — `20_run_census_veg_wet_response.R:218`, `R_RESPOND = 0.20`, `SIGN_FRAC = 0.70` |
| 6.5 | four exclusion rules for a defined *r* | **CONFIRMED** — 25 paired years, non-degenerate variance both series, ≥1 wet and ≥1 dry, finite |
| 6.6 | sparse-bin rule is **cumulative truncation**, every bin beyond discarded regardless of count | **CONFIRMED** — `cumprod(as.integer(n >= MIN_BIN_N)) == 1L`, line 108, exactly as described |
| 6.3 | two sequential stages, equations as given | **CONFIRMED** — `build_T13_gateB_measures.py:46-47` |
| 6.3 | water term is continuous flood fraction, not binary | **CONFIRMED** — `flood_frac_pct` from `fact_zone_community_flood_annual` |
| 6.3 | *"the trend in what water does not explain"*, with the orthogonality caveat | **CONFIRMED** — the caveat is stated correctly and is the non-obvious branch |
| 6.3 | near-zero-variance units flagged unreliable | **CONFIRMED** — line 78 |
| 6.1 | residual SD 6.62 on the **population** convention (ddof = 0); RSE 6.73; SE(slope) 0.069 | **CONFIRMED** — registered 6.621 / 6.727 / 0.0691 |
| 6.4 | community SDs are **sample** (ddof = 1), explicitly contrasted with §6.1 | **CONFIRMED** — the clause Gate B asked for is present and correct |
| 6.4 | pre-registered cut ±1.0 σ, alternatives at 0.50 / 0.75 / 1.25 / 1.50 | **CONFIRMED** — `CUTS = [0.50, 0.75, 1.00, 1.25, 1.50]`, `REGISTERED_CUT = 1.00` |
| 6.6 | GAM: thin-plate, *k* = min(10, distinct flood values − 1), REML, unweighted | **CONFIRMED** — `gayini_veg_water_census_panels.R:51-52` |
| 6.6 | shaded interval is a 95% confidence band on the fitted curve | **CONFIRMED** — `fit ± 1.96 × se.fit`; pointwise, not simultaneous |
| 7.1 | Mann–Kendall α = 0.10, Theil–Sen CI at the complementary 90% | **CONFIRMED** |
| 7.1 | Aeolian low never floods, reported as a vacuous case | **CONFIRMED** — 26,786 of 26,786 pixels never wet |
| 3.1 | tercile caveat unconditional; absolute zones at fixed 10 / 25 / 50 | **CONFIRMED** |
| 6.1 | slope 0.548 → 5.5 pp per 10% (5.48); r 0.71 → r² ≈ 0.50 (0.504) | **CONFIRMED** |

All three corrections and all four additions hold. **Nothing that was corrected was corrected wrongly.**

### Defects found by applying the test to the remaining method claims

#### **M-1 · §6.6 — the other GAM figure uses a different *rule*, not just a different threshold**

The document says: *"A different figure in the wider analysis applies a threshold of 2,000 cells on
5-percentage-point bins."* That describes a different **threshold and bin width** and implies the same
cumulative rule. It is not the same rule.

`24_build_figA_floor_gradient_density.R:97-98`:

```r
supported <- cnt$upper[cnt$Freq >= MIN_BIN_N]
ff_cut    <- if (length(supported)) max(supported) else 100
```

That is **the last bin anywhere meeting the threshold** — a sparse bin in the middle of the range is
*jumped over*, and everything beyond it up to the last supported bin is kept. It is the permissive rule
that §6.6 was corrected to stop describing, still live in a second figure. A reader applying §6.6's
cumulative rule to that figure would truncate earlier than the figure does.

#### **M-2 · §6.5 — the classification rule has three gates, not two**

The corrected text states two conditions. `20_run_census_veg_wet_response.R:216-220` has three:

```r
if (is.na(median_r) || is.na(sign_frac)) return("undetermined")
if (resp_cov < 100 * MIN_RESP_COVERAGE)  return("coverage_limited")   # MIN_RESP_COVERAGE = 0.50
if (median_r >= R_RESPOND && sign_frac >= SIGN_FRAC) return("responds")
```

**A stratum in which fewer than half the cells yield a defined *r* cannot be classified as responding at
all**, whatever its median and sign consistency. That gate is absent from the document. It does not bind on
current data — the lowest coverage among the eight measurable strata is 58.76% — so **no number changes**.
But it is a third condition, in the very passage that was corrected to add the second.

#### **M-3 · §6.6 — the Kruskal–Wallis is at plot support, inside a census-support section**

§6.6 describes the dashboards' GAM as fitted *"across all census cells of a community"*, then says
*"The dashboards also report a Kruskal–Wallis test across communities on flood frequency"* — with no
change of support signalled. `R/gayini_dashboard_panels.R:328`:

```r
kw <- stats::kruskal.test(flood_frequency_pct ~ simplified_vegetation_group, data = freq_by_plot)
```

`freq_by_plot` is **plot support**, and the grouping is the 4-class `simplified_vegetation_group`, not the
three non-treed communities §3.1 defines. So one panel carries a census-support smooth and a plot-support
significance test, described in one paragraph as though they shared a support. CLAUDE.md's C10 rule requires
the support be stated wherever the metric appears. The code also labels the result **"(descriptive)"**; the
document does not.

#### **Observation · §6.1 — "read at render time" is true, and is not the whole mechanism**

*"The regression constants are registered and read at render time by every figure that draws them"* —
**CONFIRMED**: no render path hardcodes the constants in place of reading the registry. Both R render paths
then **assert** the registry against hardcoded literals:

```r
stopifnot(abs(INT - 52.652934) < 1e-6, abs(SLP - 0.547838) < 1e-6, abs(SD - 6.6208) < 1e-4)
```

Good drift protection, and worth knowing that it is there: a legitimate re-pin does not flow through to the
figures, it **stops the render**. That is the correct default, but it is not what "read at render time"
conveys on its own.

---

## C2 · Figures and captions

### Numbering and cross-references — clean

- **25 captions, numbered 1–25, each number used exactly once, no gaps, in ascending document order.** The
  collision found in the earlier build is resolved and the auto-numbering holds.
- The **extra `Figure 6.` occurrence flagged at Gate 0 is a body cross-reference**, as predicted — confirmed
  by parse, not assumed.
- **All 13 body cross-references resolve** to a figure that exists. No reference points at a missing number.
- **16 of the 25 figures are never referenced in body text.** Not a defect — the document is built so
  captions carry the figures — but it means those captions are load-bearing and are the only place the
  reader is told what they are looking at.

### Caption-versus-code — done for four figures, blocked for the rest

Captions verified against producing code this gate: **Figure 6** (percentile fan, C4), **Figure 9** (green
share at the floor), **Figure 10** (persistence overlay, two defects above), **Figure 24** (three-arm grid,
C3). §7.1's statements about the Figure 5 absolute zones are also confirmed.

**The remaining figures are blocked, and the blocker is structural, not effort.** The check requires knowing
which artefact each caption was rendered from. **There is no build script for this document in the
repository** — searching `*RS_methods_doc*` and `methods_doc` across `scripts/` and `R/` returns nothing, and
the embedded media are numbered `image1.png` onward with no source names. The figure-to-file mapping exists
only at the design seat.

Mapping captions to files by matching their wording against `figure_asset` titles would be **guessing**, and
a wrong mapping produces a confident verdict about the wrong figure — the same failure C3 was protected from
by not reasoning from the nearest plausible pin. **Reported as blocked. What would unblock it: the figure
manifest used to assemble the document, or filenames added to the caption metadata.**

The registration half of the check is blocked by the same gap: `figure_asset` holds 278 rows and I cannot say
which 25 of them are these without the mapping.

---

### C2 completion — the manifest arrived, and the mapping is exact

`docs/reports/DOC1_figure_manifest_v6.csv` (25 rows) closes the blocker. **Verified independently rather
than accepted:** all 25 `sha256_embedded` values are present among the 25 `word/media/` entries of the v6
package, no media file is unclaimed, the correspondence is one-to-one, and figure numbers 1–25 each occur
once. The mapping is therefore exact.

**Reconciliation against `figure_asset` — the split is not the one predicted, and the difference is the finding:**

| resolves by | count | detail |
|---|---|---|
| **hash** (unmodified, byte-identical to a registered asset) | **15** | all 12 `Output/pack/` figures, plus Figures 6 and 7 (supplied unmodified) and **Figure 1** |
| **filename only** (registered, but resampled for embedding) | 6 | Figures 4, 9, 10 and the three dashboard renders 11–13 |
| **neither** | **4** | **Figures 2, 3, 5, 8** |

Expected was 12 clean hash matches and 13 by filename. Found **15 and 6, with 4 resolving by neither**.

**F-3 · Four figures in a client-facing document have no registry row.** Figures **2**
(`C1_checkerboard_farm.png`, §3.1 stratification), **3** (`S_annual_wet_extent_flow.png`, §7.1), **5**
(`H6_absolute_flood_zones.png`, §7.1) and **8** (`S_floor_and_typical_mapped.png`, §7.4) match no
`figure_asset` row by checksum **or** by filename. All four were extracted from
`Gayini_Veg_samples_ALLPIXEL_v6_20260724.pptx`. Figure 5 is the absolute-zones figure §3.1 and §7.1 both
cite as the comparable alternative to the terciles, so it is load-bearing. These are unregistered artefacts
reaching a deliverable.

**Minor · Figure 1's embedding note and its hash disagree.** The manifest records *"resampled to 2000 px long
edge"*, yet its embedded bytes hash-match the registered `Output/figures/M2_all_pixel_method.png` exactly.
Either the resample was a no-op or the note is inherited from its provenance group. Changes nothing;
worth one correction in the manifest so the note is not trusted later.

**Registry movement.** `figure_asset` now holds **297 rows** against the **278** recorded in CLAUDE.md.
Movement is expected between tasks; flagged here so Gate E's re-probe has a starting figure and an
attributable delta rather than a surprise.

**Caption-versus-code for the remaining 21 figures is now unblocked but not done.** Four were verified at
this gate (6, 9, 10, 24). With the manifest in place the remaining 21 are tractable — each caption can be
read against its named source file's producing script. Scoping that is a design-seat call given the
deadline; it is a bounded piece of work, not an open-ended one, and it is the last incomplete part of C2.

## Carried forward

- **Regression diagnostics** (§6.1) and **six citations** — open, as established at Gate A. Neither closes here.
- **The figure manifest** — needed before C2 can complete. This is the one thing Gate C could not do.
- **Gate D** is unaffected: substitution candidates are searched from `figure_asset` against claims, which does
  not require knowing which figure is currently in the document — only what the document claims.

## Counts at this gate

**Method claims examined: 43 (all of them).** 16 corrected or added descriptions confirmed against code ·
**3 found simpler than their implementation** (M-1, M-2, M-3) · 1 observation · the rest are general
statements of technique carrying no implementation to check.

**Figure claims: numbering and cross-references complete and clean · 4 of 25 captions verified against
producing code · 21 blocked on the figure manifest · 2 defects found (F-1, F-2).**

**C3 and C4 both settled from source.** No value claim was found wrong at this gate; the two contradictions
in this audit remain the two found at Gate B.
