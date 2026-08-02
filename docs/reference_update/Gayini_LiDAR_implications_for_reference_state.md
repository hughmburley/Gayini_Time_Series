# What the LiDAR week means for reference state

**To:** the reference-state stream · **From:** CC · **Date:** 2 August 2026
**Depth:** `docs/LiDAR/TaskU_findings_note.md`. **You should not need to read the Task U
change reports.**

Five items. Everything else Task U did — the sensor step-change test, the DEM offset, the
mosaic bug, Gates U0/U1/U3 — **does not touch reference state.** It lives in
`docs/change_reports/TaskU_gate*.md` and is not summarised here.

---

## 1 · The four reference paddocks are not a block · **lead with this**

They are **~30 km apart**, strung along the floodplain: Bala 29ca at the far west, 28ca in
the middle, 26ca and 27ca to the east. They span different vegetation communities, a **~9 m
regional fall**, and — per Gate U2 — hydrological regimes differing by a factor of **five**
in wet fraction in the wettest year in the gauge record (29ca 13.9% against 66–81%).

They have been analysed as a reference **set**: one condition, four replicates. **They are
not one condition.**

> **This is the physical explanation for T2 Gate E.** Gate E established *that*
> distance-to-reference was undefined as specified — the within-reference spread exceeds
> the reference-versus-grazed contrast in 6 of 9 strata (I-02). This establishes *why*:
> the reference paddocks differ from each other mainly in **where they sit and how wet
> they are**, not in condition.

A further trap the same observation exposes: **absolute elevation cannot be read as flood
susceptibility across this extent.** 29ca is the *lowest* ground in absolute terms and the
*least* flooded, because over 30 km of floodplain elevation tells you where you are along
the river, not how high you sit above the local surface.

*Source: §1c, a timeboxed prose-only DEM inspection. No metric, no derived surface,
nothing registered.*

## 2 · R6 — a candidate for the redefined metric · **a proposal, not a conclusion**

R6 places each paddock on a **within-community fit of floor against long-run flood
frequency**, at pixel support, over all non-treed census pixels, and reports the signed
residual against the fit's own scatter.

That is a distance-to-reference metric which **conditions on exactly the two things §1
shows make the reference set heterogeneous** — community and hydrology — instead of
assuming them away. Gate E asked for a redefinition before the trajectory work could
resume; R6 was run to check one paddock and doubles as the candidate.

**It is not adopted, and nothing is built on it here.** The pre-registration guard,
verbatim:

> Redefining distance-to-reference is a design-seat decision. It must be **pre-registered
> before any trajectory number is computed**, justified on **grounds stated independently
> of its effect on the answer**, and **both versions must be reported.** No paddock is
> excluded from a fit on the basis of its own residual, and a fit is not re-specified
> after its residuals are seen.

Detail and the fits: `docs/reference_update/Gayini_R6_bala_floor_flood_placement.md`.

## 3 · The reference-state anomaly has dissolved — a result, not a loss

Since 27 July the stream has carried an awkward finding: **Bala 29ca alone sits 42 pp
below** the grazed median while its three companions track it. Every reference-state result
traced to that one paddock, and the leading explanation — clearing predating the satellite
record — was untestable and waiting on Ernest.

**R6 closes it.** 29ca's residual is **positive in all three communities: +1.57, +9.61,
+1.15** — at or slightly above what its dryness predicts, and at or above the grazed median
in every community it occupies.

**U-Q4a agrees from the other direction.** LiDAR structure at paddock grain makes 29ca
unremarkable to mildly above average: it is one of the **minority of Riverine zones
carrying any non-zero upper-tail structure at all in 2009**, and mid-range in Inland. That
is the opposite of the suppressed 2009 canopy a cleared-and-regrowing paddock should show.

> **Frame it as confirmatory.** The 42 pp gap was **composition and hydrology**. Flood
> frequency sets the floor; 29ca floods at a fifth its neighbours' rate; its floor is where
> the project's own headline mechanism predicts. **The result that appeared to threaten the
> headline turns out to be an ordinary instance of it** — and it is the cleanest L-01
> demonstration the project has.

**The low-power caveat travels with this and must not be dropped.** Chenopod shrubland
cleared sixty years ago and never re-treed looks like chenopod shrubland never cleared, at
5 m, in a height product. The clearing hypothesis is **not disproved — it is no longer
needed.** Ernest's answer would still say something the LiDAR cannot.

## 4 · Bala 26ca · **open, named, not investigated**

Two independent products put 26ca below its neighbours in **Riverine**, in the same
direction:

- **R6** — residual **−17.41 pp** (−1.44 SD), n = 636 px
- **U-Q4a** — structurally poorest of the four: zonal p90 = **0.00 m, 0th percentile, at
  both epochs**

Both rest on small samples and **neither has been built on.** 26ca's Inland part, 51×
larger, sits at +0.59 — essentially on the curve. So this is a small, atypical corner of
one paddock.

It is recorded (**U-I14**) because two independent lines agreeing is worth more than either
alone, and this is the kind of observation that gets lost. **Not investigated before
10 August.**

Note the direction it cuts: the paddock with a real negative residual is **26ca, not
29ca**. Any rule written to exclude "the anomalous reference paddock" would now exclude a
different one than the project expected — which is a reason to write the rule before
looking again, not after.

## 5 · S6 — the cover-versus-structure caveat weakens · relevant if the deck touches it

> **Only 13.33% of the property — 11,449 ha of 85,882.6 — carries any woody LiDAR cover
> at all.**

The drought floor, the project's headline metric, is therefore measured on country that is
**87% non-woody by area**. The floor is overwhelmingly a **ground-layer** signal, not a
canopy one — which **weakens the S6 cover-versus-condition caveat across most of the
property.**

It does not settle it. The refugia concordance (U-Q2) that would test whether persistent
floor concentrates *inside* that 13.33% was **not run** and is deferred past 10 August. But
the finding bounds it in advance: **at most 13.33% of the property could have a woody
explanation for its floor.**

---

## What this note does not carry

The sensor step-change test and its two null results; the change-detection floor; the
withdrawn +0.303 m vertical offset and U3.7's failure; the U-I11 mosaic bug; Gates U0, U1,
U3, U3.6. **None of it touches reference state.**
It lives in `docs/change_reports/TaskU_gate*.md` and in the findings note.
