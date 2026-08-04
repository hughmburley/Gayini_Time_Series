# LID-1 — Task U shippability audit

**Version:** v1 · 4 August 2026 · design seat
**Task:** audit every Task U artefact and classify what may ship, in what deliverable, at what status
**Deadline:** 10 August. The pack is SEALED at v1.1 `2206ec20…`.
**Read-only on the database and on Task U's outputs.** This gate changes nothing.

---

## 0. What this gate is for, and the two rules that bound it

Task U produced twenty registered rasters, two registered denominators, two figures and a body of
findings. **Every raster carries `qa_status = REVIEW`.** The question is not whether the work is
good — it is disciplined work with pre-registered rules and owned defects. The question is
**precisely which parts of it may leave the project, in which document, and carrying what status.**

### Rule 1 — Nothing LiDAR enters the Adrian pack.

The pack is sealed, hash-verified, and its through-line does not depend on LiDAR. The Gate E
argument now rests on flood ranks 3, 6, 31 and 61 of 64, computed from
`fact_zone_veg_annual.flood_frac_pct` and pinned. **Reopening a sealed client deliverable to add
REVIEW-status material is not a trade worth making**, and the precedent for what happens when
REVIEW material reaches client prose is on the record.

**Do not propose a pack change. If the audit finds something that seems to demand one, report it as
a finding and stop.**

### Rule 2 — The R6 / F2 result does not appear in any reference-state context.

Task U summary §5 F2 reports that Bala 29ca's residual is positive in all three communities
(+1.57, +9.61, +1.15) and that the reference-state anomaly dissolves. **Those fits use the census
temporal p05.** Spec §6 makes `census_by_zone_stratum.veg_p05_mean` a STOP for any reference-state
purpose, and the design seat's own re-run on `veg_p05_spatial` at part grain gives Bala 29ca
residuals of −29.04 and −18.67 in Aeolian and Riverine, against R6's +1.57 and +9.61.

**The metric question is real, predates R6, and must not be settled knowing which paddock the answer
exonerates.** F2 may be described in the methods document as an exploratory cross-metric sensitivity
whose direction is open. It may not appear as a finding, a conclusion, or a qualification on any
reference-state claim.

---

## Gate L1 — Verify the summary, using its own instructions

`Gayini_LiDAR_TaskU_summary.md` §11 already specifies its cross-check. **Execute it as written.**
Report as the discrepancy table it asks for: claim · document value · artefact value · verdict.

Additions to §11's list:

**L1-1 · The 13.33% figure and the census 8.00% figure are different quantities. Confirm it.**
The design seat previously checked 13.33% against `census_by_zone_stratum`, obtained 8.00%, and
wrongly concluded it did not reproduce. Establish and report both, with denominators:

| | source | denominator |
|---|---|---|
| woody community share | census cells in Floodplain Woodland / Forest | mapped census area |
| measured woody cover | LiDAR FPC > 0 at either epoch | Task U both-valid, 85,882.6 ha |

**They are not comparable and neither supersedes the other.** Log the design seat's mis-diagnosis —
a check run against a source that could not detect what it was looking for, which is I-42's shape,
with the source named as the design seat.

**L1-2 · The ten pending headline numbers.** Summary §9 records *"2 denominators registered; 10
further rows ruled and pending insertion at closeout C1."* Report whether they were inserted. Live
state is 101 rows with 2 Task U rows. **If they were ruled but not inserted, that is I-40's shape
again and it goes in the report — do not insert them.**

**L1-3 · U-I14.** Summary §8 expects it outstanding in both stream documents — the Bala 26ca signal
is two instruments on one 40 ha fragment, not two independent lines. Confirm.

**L1-4 · `legend_status`.** Unconfirmed on FPC and height rows. Report how many of the 20 rasters
carry an unconfirmed legend, and which.

**STOP. Report before Gate L2.**

---

## Gate L2 — Classify every artefact for shippability

Emit `Output/tables/LID1_shippability.csv`, one row per Task U artefact — 20 rasters, 2 figures,
2 registered numbers, the tables, the GeoPackage if one exists, and each document.

| column | |
|---|---|
| `artefact` | path or `number_id` |
| `type` | raster · figure · number · table · document · vector |
| `qa_status` | as registered |
| `verified` | DS-V · CC · DB · unverified |
| `denominator` | which of the three, or n/a |
| `ship_to` | `DATA_HANDOVER` · `METHODS_DOC` · `INTERNAL_ONLY` · `HOLD` |
| `status_that_travels_with_it` | the caveat that must accompany it, verbatim |
| `reason` | one line |

**Classification rules, applied not invented:**

- **`DATA_HANDOVER`** — a registered raster with a checksum, a stated CRS, a stated denominator and
  plain-English semantics. It ships as data, `qa_status = REVIEW` stated on its face.
- **`METHODS_DOC`** — a method, a denominator, a rule, or a stated non-result. **Methods are
  shippable at REVIEW status; findings are not.**
- **`INTERNAL_ONLY`** — anything whose interpretation is open, including F2 and anything downstream
  of the sensor step-change verdict.
- **`HOLD`** — anything failing L1's cross-check, and anything with an unconfirmed legend.

**Acceptance:** every artefact classified exactly once · no row classified `DATA_HANDOVER` without a
checksum and a resolved CRS · no row classified `METHODS_DOC` that states a finding rather than a
method · every row carries the caveat that travels with it.

---

## Gate L3 — Recommend the methods-doc section

**Report a recommendation. Do not write the section — the methods document is edited elsewhere.**

Placement is ruled: **a standalone section between the present §11 Limitations and §12 Implications**,
pushing implications and positioning back one. The reason is structural, not chronological — LiDAR is
a lens held up to the census results, and §11.4 already states that structure is not observable in
Landsat products. The section answers the limitation immediately after it is stated, and immediately
before the next steps it changes.

Report, with sources, what the section can support:

**L3-1 · The delivery.** 47 GeoTIFFs, three epoch/zone folders, two epochs, two sensors
(ALS-50 2009, ALS-80 2021), the products actually present by stage code, and the products absent.
State the volume.

**L3-2 · The frame.** One warp to EPSG:8058, no original mutated, the three denominators and what
each is for, the co-registration result, the seam treatment. **The three denominators must never be
interchanged and the section must say so.**

**L3-3 · The central methodological problem, stated as such.** The sensor changed between epochs,
2009 sits at the end of the Millennium Drought and 2021 follows two flood years, and capture dates
are unrecoverable. **Report what the sensor step-change test concluded and the numeric floor below
which no change is claimed.**

**L3-4 · What was tested and what was not.** U-Q1 run; U-Q2 refugia concordance not run; U-Q3 nulls
with the DEM component deferred. **A question deferred is a stated scope, not a gap** — but it must
be stated.

**L3-5 · The measured woody extent**, with its own denominator, alongside the census woody community
share, with its denominator. **Both, or neither.** This is the one quantitative LiDAR result that
bears on a limitation the assessment already states, and it bears on it by bounding it: at most that
share of the property could have a woody explanation for its floor.

**L3-6 · The stated non-result.** Landsat fractional cover and LiDAR structure measure different
things. The reading of the Bala 29ca anomaly is exploratory, the two instruments disagree, the metric
question predates the LiDAR work, and no conclusion in either direction is offered. **The section must
say this plainly rather than omitting the question.**

**L3-7 · The change to §12.3.** *"Structural comparison against LiDAR"* currently reads as a step
requiring data. Report the wording change: the data is held, processed and registered, and it is the
analysis that is outstanding. **That is a materially different statement to a client and it should not
be left stale.**

**L3-8 · The two-epoch trap, stated before the epochs are.** 2009 and 2021 with management changing
in 2019 invites a before-and-after reading. Two acquisitions twelve years apart measure change between
two dates; they cannot attribute it, and one date falling after a management change does not make them
a controlled comparison. **This belongs in the section's opening, not its caveats.**

---

## Gate L4 — The handover package

Report only. Build nothing.

1. **Which rasters go**, at what resolution, and the total volume. 178 GiB of source is not a
   deliverable; the processed 8058 products are.
2. **A README specification** — CRS, pixel constant, epochs, sensors, stage codes in plain English,
   the three denominators, `qa_status = REVIEW` on its face, and what has not been validated.
3. **Whether a GeoPackage exists** per the Task U spec's Gate U5 item 2, and whether it is registered.
   `spatial_layer_asset` is an import registry — a build output registered there is a category error.
4. **The cultural governance flag.** Fifty-centimetre terrain reveals channels, earthworks and scarring
   that a Landsat product does not. **This requires Nari Nari review before anything leaves, and that
   is a governance decision, not a technical one.** Flag it at the top of the recommendation.

---

## Standing rules

Read-only throughout; `mode=ro` with `PRAGMA query_only=1`; probes at open and close. Additive only.
No LiDAR FPC and Landsat `total_veg` on a shared axis or differenced, ever. No wording implying either
sensor validates the other. Plot support and pixel support never merged. Every number carries support
level, scope filter, pixel constant, denominator and period label — and the both-valid intersection is
a denominator that must be named every time it is used.

Any number in this spec is a prediction to check. Where an independently computed value disagrees,
**the computed value stands and the disagreement is the finding** — which has now caught the design
seat three times.
