# Task U — what the LiDAR changed

> **SUPERSEDED IN PART — 4 August 2026, design seat.**
> The conclusion that the reference-state anomaly has dissolved rests on a
> comparison this project prohibits. R6's residuals are computed on the census
> temporal p05 (`census_by_zone_stratum.veg_p05_mean`); the deficit they are
> compared against is computed on `veg_p05_spatial`. Re-running R6's own logic on the
> pinned metric gives Bala 29ca residuals of −29.04 and −18.67 in Aeolian and
> Riverine, against R6's +1.57 and +9.61, with the Aeolian community fit reversing
> sign. The anomaly is neither confirmed nor dissolved. The metric question is real,
> predates this work, and is open.
> See `Gayini_R6_metric_review_20260802.md`.


**To:** design seat · **From:** CC · **Date:** 2 August 2026
**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md` + amendment log
**Evidence:** change reports for Gates U0–U3, U3.7/§1c/U-Q4a, and
`docs/reference_update/Gayini_R6_bala_floor_flood_placement.md`

---

## Why we did it

The project's central caveat is that Landsat fractional cover measures **cover, not
structure**, so it cannot separate land-use change from ecological condition. Every
limitation in the register traces back to it. LiDAR is the only dataset we hold that
measures structure directly, so it was brought in as **an interpretive lens on the
Landsat results** — not as a LiDAR analysis. Two Landsat products agreeing is circular;
a Landsat product and a LiDAR product agreeing is corroboration.

**The headline is not what the LiDAR shows. It is what the LiDAR does to two standing
problems.**

**S6 — the cover-versus-condition boundary — is weakened across most of the property.**
**The reference-state anomaly has dissolved, and the project's own headline mechanism is
what dissolved it.**

---

## 1 · The reference-state anomaly no longer needs explaining

Since 27 July the project has carried an awkward finding: three reference paddocks track
the grazed median, and **Bala 29ca alone sits 42 pp below**. Every reference-state result
traced to that one paddock, and the leading explanation — clearing or cropping predating
the satellite record — was untestable and waiting on Ernest.

Two independent lines now close it.

**The spine predicts it.** Flood frequency sets the drought floor. Bala 29ca floods at
roughly **one fifth** its neighbours' rate — 13.9% against 66–81% in the wettest year in
the gauge record. Fitting floor against long-run flood frequency **within community**
(rule R6, pre-registered), 29ca's residual is **positive in all three communities**:
+1.57, +9.61, +1.15. Its floor is where the mechanism says it should be.

**The structure agrees.** LiDAR height at paddock grain finds 29ca structurally
unremarkable to mildly above average: one of the minority of Riverine zones carrying any
non-zero upper-tail structure at all in 2009, and mid-range in Inland. That is the
opposite of the suppressed 2009 canopy a cleared-and-regrowing paddock should show.

> **The 42 pp gap was composition and hydrology.** 29ca is much drier than the paddocks
> it was grouped with, and it is a three-community mosaic. **The result that appeared to
> threaten the project's headline is an ordinary instance of it.**

The clearing hypothesis is not disproved — it is **no longer needed**. And the structural
test has genuinely low power against old clearing on treeless country: chenopod shrubland
cleared sixty years ago and never re-treed looks like chenopod shrubland. **Ernest's
answer would still say something the LiDAR cannot.**

## 2 · S6 is weakened across most of the property

U-Q2's refugia concordance was **not run** — deferred past 10 August. But the gate that
would have set it up produced the finding anyway, from a different product:

> **Only 13.33% of the property — 11,449 ha of 85,882.6 — carries any woody LiDAR
> cover at all.**

The drought floor, the project's headline metric, is therefore measured on country that
is **87% non-woody by area**. The floor is overwhelmingly a **ground-layer** signal, not
a canopy one. That is one of the two outcomes U-Q2 was built to distinguish, arriving
early and independently — and it **bounds** U-Q2 before it runs: at most 13.33% of the
property could have a woody explanation for its floor.

It does not settle U-Q2. Refugia could concentrate inside that 13.33%, which is what the
concordance would test.

## 3 · Two null results on change, both reportable

Both were pre-authorised as legitimate outcomes. Both are findings, not omissions.

**Whole-of-property cover change is not interpretable.** The change-detection floor on
vegetated ground is **9.7 FPC pp at 500 m grain** against an observed **0.257 pp** — the
floor exceeds the signal by a factor of 38.

**Height change is not separable from drought recovery.** No control on this property can
distinguish twelve years of real regrowth from the sensor step between the two aircraft.

The sensor did change measurably — about **40% more returns per unit area** in 2021 — but
the cover offset **does not scale** with that difference (R² of 0.012 and 0.0001), so no
correction is derivable and none was applied.

## 4 · What the LiDAR could not say

**There is no stable vegetated ground on Gayini between these two dates.** 2009 is the
Millennium Drought trough — the record minimum for farm cover — and 2021 follows the
2016 and 2020–21 floods. Everything green grew. That is a property of the delivery, not
a defect of method, and it is why the change tests could not be sharpened.

**Flight months are unrecoverable** from the delivery — no readme, no delivery note, no
dated metadata. Because the water year starts in July, each capture spans two candidate
water years, leaving a **20.8 pp** spread in cover and a **4.4×** spread in flow on any
change statement. Worst case the comparison is the record minimum against the record
maximum.

**The vertical offset is not spatially uniform.** Stable ground gives +0.303 m with a
2.4 cm scatter, which looked like a clean calibration — but a plane in x and y explains
**41%** of its variance, with an implied tilt of **13.5 cm** across the property. The
scalar calibration is withdrawn and no corrected surface exists. It may not be an
artefact at all: twelve years and three flood sequences on an actively depositing
floodplain could produce real differential sedimentation, and we cannot separate that
from a datum tilt.

## 5 · Three findings that outran the task

**The reference paddocks are not a set** — *reference-state stream.* They are ~30 km
apart, spanning different communities, a 9 m regional fall, and hydrological regimes
differing fivefold. They have been analysed as one condition with four replicates.
**This is the physical explanation for T2 Gate E**, which found the reference set too
heterogeneous for distance-to-reference to be defined and has blocked the trajectory work
since 27 July. Gate E established *that*; this establishes *why*.

**R6 is a candidate for the redefined metric** — *reference-state stream.* It computes a
residual from a within-community floor-versus-flood fit, which conditions on exactly the
two things that make the reference set heterogeneous instead of assuming them away.
Offered as a **proposal, not a conclusion**: redefining distance-to-reference is a
design-seat decision, needs pre-registering before any trajectory number, and must be
justified on grounds independent of its effect on the answer with both versions reported.

**Bala 26ca, Riverine** — *open observation, not investigated.* Two independent products
put it below its neighbours in the same direction: R6 gives a residual of −17.41 pp, and
the structural test makes it the poorest of the four at both epochs. Both on small samples;
neither built on. Recorded so it can be picked up deliberately rather than rediscovered.

## 6 · After 10 August

- **U-Q4b** refugia concordance — not run, deferred.
- **U-Q4c** difference DEM and earthworks — not run, deferred. Note that Task J's L10 is
  blocked on **provenance** — Jana's confirmation of what the bank shapefile represents —
  which a DEM does not supply, so the "unblock" is weaker than it first looked.
- A **planar de-trend** of the vertical offset, if the difference DEM is ever built. No
  stable-ground pixels fall inside the `d4`/`d5` seam, so the seam is untested.
- Whether the 13.5 cm tilt is **real differential sedimentation** — scientifically
  interesting in its own right.
- **Adrian:** vertical datum of each DEM; flight months; and what `254` means in the `d5`
  classification bands. Flight months are the cheapest improvement available — knowing
  them removes the 20.8 pp / 4.4× spread from every change statement.

---

**Bottom line.** The LiDAR did not produce a change map, and on this property it was never
going to. What it did was remove the one result that appeared to contradict the project's
headline, and show that the headline metric is measured on ground where the central caveat
mostly does not bite. Both are confirmatory, and neither depends on a number the LiDAR
alone produced.
