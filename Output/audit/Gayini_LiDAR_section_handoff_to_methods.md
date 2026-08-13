# LiDAR section — handoff to the methods-doc stream

**From:** reference-state stream · **Date:** 4 August 2026
**For:** the LiDAR section of `Gayini_RS_methods_doc_V5.docx`
**Status of the underlying work:** Task U closed at `main:c4b4fb7`. Every Task U raster carries
`qa_status = REVIEW`. Gate L1 cross-checked the work on 4 August: **nine of nine independently
verified claims reproduced, most to the last decimal.**

---

## 0. Read this before taking any number

**Take every number from this document, not from the Task U reports.** Gate L1 found five
discrepancies and the corrections may not have been committed yet. In particular
`TaskU_gateU1_report.md` currently carries a stale density value that was computed before a bug fix
and never refreshed. The values below are the corrected ones.

**Two rules bind the whole section:**

1. **LiDAR foliage projective cover and Landsat total vegetation cover are never differenced, never
   shared on an axis, and never described as validating one another.** FPC is projected cover of
   vegetation above a height threshold — effectively woody. Landsat total cover is surface cover
   including grass and litter. They are complementary because they measure different things, and
   that is the entire reason the LiDAR is useful.
2. **The three denominators are never interchanged.** Property area is context only and is never a
   statistical denominator. Every change statistic uses Task U both-valid. Concordance work, had it
   run, would use census ∩ LiDAR.

---

## 1. Placement — ruled

**A standalone section between the present §11 Limitations and §12 Implications**, pushing
implications and positioning back one.

The reason is structural rather than chronological. §11.4 states that *"species, structure and
ecological condition are not observable in these products."* LiDAR is the only instrument the
project holds that addresses that, so the section answers the limitation immediately after it is
stated and immediately before the next steps it changes.

---

## 2. What the section can say

### 2.1 What Task U was, and was not

Task U used finished JRSRP LiDAR raster products **as an interpretive lens on the Landsat results.**
It was not a LiDAR analysis. It consumed delivered rasters, did not touch point clouds, and
generated no LiDAR product of its own. Point-cloud processing, canopy height model generation,
biomass and gap-probability modelling were all explicitly out of scope.

The rationale is worth stating plainly, because it is the section's justification: **two Landsat
products agreeing is circular; a Landsat product and a LiDAR product agreeing is corroboration.**

### 2.2 The delivery

**61 files — 47 GeoTIFFs plus 14 locally generated sidecars — totalling 178.0 GiB.** Three
epoch/zone folders:

| folder | epoch | EPSG | files | GiB |
|---|---|---|---:|---:|
| 2009, GDA94 / MGA55 | 2009 | 28355 | 16 | **86.83** |
| 2021, GDA2020 / MGA54 | 2021 | 7854 | 16 | **60.42** |
| 2021, GDA2020 / MGA55 | 2021 | 7855 | 15 | **30.75** |

*(Corrected at Gate L1. The Task U summary states 88.9 / 61.4 / 27.5; counts and totals were already
right.)*

**2021 is one capture delivered as two complementary map-zone tiles**, not two datasets. Sensors are
Leica ALS-50 in 2009 and ALS-80 in 2021.

Products present: DEM, maximum height, intensity, ground mask, classification and first-return
density at 50 cm; seven height percentiles at 5 m; foliage projective cover at 10 m; hillshade and
canopy surface model at 50 cm. A pit-free canopy height model is **absent**, which is immaterial
because the canopy surface model is DEM-subtracted and the percentiles give height above ground
directly.

**Six height percentiles were usable, not seven.** The lowest percentile has no 2021 z55 tile, which
is why that folder holds fifteen files rather than sixteen — a 2021 mosaic of it would be
single-tile by construction, so it is excluded from the height ladder.

**Capture dates are unrecoverable** — no readme, no delivery note, no dated file tags. This is the
single largest unresolved limitation of the task and should be stated as such.

### 2.3 The common frame

Every product was warped **once** to EPSG:8058 into new files; no original was mutated. Bilinear for
continuous surfaces, nearest for classified. Two coordinate systems new to the project were added,
taking the project's list to six.

**Co-registration between epochs: r = 0.897298, peaking at zero offset**, with a one-pixel shift in
any direction costing about 0.11 of r. Independently reproduced to six decimals.

**The three denominators:**

| name | value | use |
|---|---|---|
| property | 85,910.8 ha | context only — never a statistical denominator |
| **Task U both-valid** | **85,882.6 ha** | every change statistic |
| census ∩ LiDAR | 67,268.0 ha | concordance work (not run) |

Both-valid is 99.97% of the property. **Do not round it to "the whole property"** — the 28.2 ha
shortfall is what makes it a measured figure rather than an assumption. Both denominators are
registered in the results database.

**The LiDAR reaches 18,533 ha further than the Landsat census does**, which is why anything crossing
a census product with a LiDAR product must be computed on the intersection rather than on either
extent alone.

### 2.4 The central methodological problem — state it before the epochs

**Two acquisitions twelve years apart measure change between two dates. They cannot attribute it.**
One of the two dates falling after a management change does not make them a before-and-after
comparison. This belongs in the section's opening, not among its caveats, because a reader meeting
"2009 and 2021" beside "management changed in 2019" will draw the line themselves.

Three specific problems compound it:

- **The sensor changed.** Different point density, scan pattern and return discrimination between
  ALS-50 and ALS-80. A sensor difference produces effects of the same magnitude as the change being
  looked for — the same failure mode as a satellite sensor change masquerading as real change, and
  it was treated with the same suspicion.
- **The two dates are not equivalent points in the record.** 2009 sits at the end of the Millennium
  Drought; 2021 follows the 2016 and 2020–21 flood years. **This is what Figure U2 shows.**
- **A stable-ground test was mandatory before any change number, and it returned a verdict:
  whole-of-property change is not interpretable.** The change-detection floor is **9.659 percentage
  points** against an observed mean change of **+0.2569** — a factor of 38.

**The floor's full name is load-bearing and the section must not shorten it.** It is a
**change-detection floor on vegetated ground at 500 m grain**. It conflates sensor difference with
real ecological change, it is derived from the treed-stable control, and it is an **upper bound on
the sensor effect, never an estimate of it**. **It is never written as a "sensor floor", and no
change below 9.659 pp is claimed anywhere.**

The instrument step is measurable and does not scale: property-median first-return density rose from
**1.0622 to 1.4672**, about 38% more returns per unit area. Regressing the cover offset on that
density difference gives R² of 0.0120 and 0.000088 with slopes of **opposite sign** — **no
correction is derivable and none was proposed.**

*(1.4672 is the corrected value. Published Task U reports carry 1.4855, computed on a partial 2021
mosaic before a bug fix and never refreshed. The qualitative claim — roughly 40% more returns per
unit area — is unchanged.)*

### 2.5 What was tested and what was not

Three questions were ranked before the work began:

- **Does structure explain the Bala 29ca reference-state anomaly?** Run. See §3.
- **Are the persistent-floor refugia woody or ground-layer?** **Not run, deferred.** Two decision
  rules for it were pinned in advance and remain unexercised.
- **Does 2009→2021 change show land use?** Nulls; the difference-DEM component deferred.

**A question deferred against a pre-registered rule is a stated scope, not a gap** — but it must be
stated.

### 2.6 The one quantitative result that bears on a stated limitation

**11,449.25 ha of the 85,882.6 ha both-valid area — 13.33% — reads foliage projective cover above
zero at either epoch.**

Independently reproduced from the delivered rasters on a separate code path.

This bounds a limitation the assessment already states. The cover floor is measured on country that
is **87% non-woody by area**, so the floor is overwhelmingly a ground-layer signal rather than a
canopy one. It does not settle the question — the refugia concordance test that would settle it was
not run — but it bounds it in advance: **at most 13.33% of the property could have a woody
explanation for its floor.**

**This is a different quantity from the census woody community share, and both belong or neither
does.** The census reports 8.00% of mapped cells in the Floodplain Woodland / Forest community, over
67,349 ha of mapped census area. The LiDAR reports 13.33% of measured foliage cover above zero, over
85,882.6 ha of both-valid area. **Different numerators, different denominators, different
instruments, neither superseding the other.** Crossing them produces figures that appear nowhere and
should not.

**This number has no registry identifier.** Ten Task U quantities were ruled for registration and
never inserted, and this is one of them. **Quote it with its denominator inline** — 11,449.25 ha of
85,882.6 ha both-valid — rather than pointing at a registry row.

### 2.7 The stated non-result

Task U's reading of the Bala 29ca reference-state anomaly is **exploratory and open.** It must be
described as such and not omitted.

**The figures below are quoted to show the size of the disagreement between two metrics, not as
measurements of the paddock's condition.** Their sources are internal working documents rather than
registered results. Suppressing the magnitudes would make the section less honest rather than more
careful: a reader told only that two metrics disagree cannot judge whether it matters, while a
reader shown +9.61 against −18.67 can see immediately that it does.

The LiDAR-adjacent analysis placed Bala 29ca's cover floor against long-run flood frequency within
each community and found its residual positive in all three. **That analysis uses the census
temporal 5th percentile.** The reference-state stream uses the spatial 5th percentile throughout,
and the two are different objects that this project's rules prohibit comparing. Re-running the same
logic on the pinned metric gives residuals of **−29.04 and −18.67** in two of the three communities,
against **+1.57 and +9.61** — with one community fit reversing sign.

**The anomaly is neither confirmed nor dissolved.** The metric question is real, predates the LiDAR
work, and is open. The honest statement is that two instruments measuring different things have not
yet been reconciled, and that reconciling them requires stating the criteria for choosing between
the two metrics **before** recomputing anything.

---

## 3. Figures — two, and both are methods figures

**No LiDAR map exists.** Gate U5 specified up to five figures and a spatial package; two figures
landed. That is the correct outcome for a methods section: both are methods diagnostics rather than
results, so nothing has to be argued from finding to method.

| figure | path | what it shows |
|---|---|---|
| **U2 · epoch context** | `Output/figures/task_U/U2_epoch_context_35yr.png` | the 35-year cover and flood series with 2009 and 2021 marked |
| **U3 · sensor step change** | `Output/figures/task_U/U3_sensor_step_change.png` | the stable-ground test, 500 m block statistics |

**U2 is the more important of the two and should lead the section.** It is §2.4's argument drawn —
the two acquisitions placed in the record they are being read against. A reader who sees 2009 at the
end of a drought and 2021 after two flood years will not need telling twice why a before-and-after
reading is unavailable.

Both figures are `qa_status = REVIEW` and both carry captions naming support level, denominator and
the not-comparable-to-Landsat warning. **Reproduce those captions rather than writing new ones.**

**Do not commission a new map for this section.** A foliage-cover extent map would earn its place,
but it is a build against REVIEW-status rasters on a closed task, and it is post-deadline work.

---

## 4. One change elsewhere in the document

**§12.3, "Structural comparison against LiDAR."** It currently reads as a next step requiring data.
**The data is held, processed, registered and cross-checked; it is the analysis that is
outstanding.** Specifically: the refugia concordance test is specified with its decision rules
pinned and unexercised, and the difference-DEM component is deferred.

That is a materially different — and more useful — statement to a client, and it should not be left
stale.

---

## 5. Governance, before anything leaves

**Fifty-centimetre terrain products reveal channels, earthworks and ground scarring that a Landsat
product does not.** This requires Nari Nari cultural review before any LiDAR-derived product is
shared externally. That is a governance decision, not a technical one, and it is not the methods
document's to make — but the section should record that the review is required.
