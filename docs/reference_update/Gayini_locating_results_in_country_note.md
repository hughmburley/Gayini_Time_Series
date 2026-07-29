# Locating results in country — the paddock-part pattern

**Version:** v1 · 28 July 2026
**Status:** OBSERVATION AND METHOD NOTE. The Bala 29ca decomposition is verified against the
database. **The property-wide scan in §5 is a design-seat pilot, unregistered, and is a
prediction to check — not a result.** Nothing here should be quoted in a deliverable until
built through a gate.
**Context:** T10 Gate C (SHA acc1365), `Gayini_reference_state_methods.md` v2.

---

## 1. Why this note exists

T10 Gate C produced a paddock-level answer: Bala 29ca's floor is 16.8 pp below what its dryness
predicts, and 82% of its recovery survives removing its own water response. Both true, both
useful, and neither tells a land manager anything they can act on or check.

Decomposing the same paddock by community turned it into a statement about a place. That
change — from *how much* to *where* — is worth recording as a method, because it is repeatable,
it is the register the client audience actually works in, and the pilot in §5 suggests it finds
things the paddock-level view conceals.

---

## 2. The observation

Bala 29ca is a three-way split: Inland 34.6%, Riverine 33.1%, Aeolian 32.3% of its non-treed
pixels — the most community-mixed paddock of the 64. Its parts behave completely differently.

| part of the paddock | floor vs that community's property median | rank | trend | community median trend |
|---|---|---|---|---|
| Aeolian third | **−32.1 pp** | **1 of 17** | **+0.560 pp/yr** | +0.222 |
| Riverine third | **−24.9 pp** | **2 of 37** | **+0.564 pp/yr** | −0.282 |
| Inland third | −5.8 pp | 10 of 61 | −0.216 pp/yr | −0.211 |

**The recovery is located.** It is in the Aeolian and Riverine thirds — both of which start as
the lowest or second-lowest on the property in their own community. The Inland third is
unremarkable in level and tracks the property median almost exactly in trend.

That is a coherent disturbance signature: a specific part of a paddock was badly degraded, that
part is recovering, and the rest behaves like everywhere else. A whole-paddock average conceals
it — the paddock-level floor of 40.5% is a mean of 29 / 67 / 35, and the paddock-level trend of
+0.682 pp/yr is a mean of +0.560 / −0.216 / +0.564.

**And it is now checkable on the ground.** The question for Ernest is no longer "was Bala 29ca
cleared or cropped" but "was the drier western part of Bala 29ca cleared or cropped." One of
those can be answered from a land-use record or an aerial photograph. The other cannot.

---

## 3. How it was derived

Five steps, all from objects already in the database. No new extraction.

1. **Choose the part, not the whole.** Use `fact_zone_community_veg_annual` (paddock × community
   × year), not `fact_zone_veg_annual` (paddock × year). Filter `n_pixels_valid >= 30` and
   `series_variant = 'mean_of_seasons'`.
2. **Compare each part against its own context.** A part's floor means nothing against the
   property median; it means something against the median of *the same community* across the
   property. Aeolian 61.5, Inland 73.1, Riverine 59.5 — these differ by more than most
   management effects, so comparing across them measures geology, not management.
3. **Do the same for trend.** Fit each part's floor on water year, and compare the slope to the
   median slope for that community. Communities are not on the same trajectory: Aeolian is
   rising (+0.222), Inland and Riverine falling (−0.211, −0.282).
4. **Read level and trend together.** Neither alone is informative. Low-and-rising is a
   different object from low-and-flat, and only the pair distinguishes them.
5. **State the answer as a place.** Name the part, name what is unusual about it, and end on
   something a person could go and verify.

**What made it work:** the comparison is *within context and across the property*, so the
question becomes "is this bit of country unusual for its kind of country" rather than "is this
paddock unusual." That is the question a land manager already asks.

---

## 4. The generalised pattern

Any paddock-part sits in one of four states, defined by its level against its community's
median and its trend against its community's median trend:

| | rising faster than its community | not rising |
|---|---|---|
| **low for its community** | **Recovering** — something happened, and it is coming back | **Persistently poor** — inherently low, or under ongoing pressure |
| **normal for its community** | Unremarkable | **Declining** — going backwards from a normal start |

Two properties make this useful beyond the reference-state question:

- **It is management-agnostic.** Nothing in the classification refers to grazing, zones or
  treatment. Management can then be tested *against* the classification rather than assumed by
  it — which is the reverse of every contrast this project has run so far, all of which started
  from the management layer and looked for a signal.
- **It is a map.** Every part has a polygon, so the four states can be drawn. That is a
  deliverable a farmer can read directly: here is country that is coming back, here is country
  going backwards, here is country that has always been poor.

---

## 5. Pilot scan — UNREGISTERED, A PREDICTION TO CHECK

Design-seat scan, 28 July, in a chat session and not through a gate. Thresholds chosen by hand
(**low** = more than 8 pp below the community median; **rising/falling** = more than 0.25 pp/yr
from the community median trend). **The thresholds are arbitrary and must be pre-registered or
swept before any of this is quoted.**

115 paddock-parts have 25 or more years of support, from all 64 paddocks:

| state | parts |
|---|---|
| Recovering | 7 |
| Persistently poor | 17 |
| Declining | 8 |
| Unremarkable | 83 |

The seven recovering parts:

| paddock | community | level vs median | trend vs median | treatment |
|---|---|---|---|---|
| Bala 29ca | Riverine | −24.9 | +0.845 | **not grazed** |
| Bala 15 | Inland | −24.0 | +0.815 | grazed |
| Dinan 10 | Riverine | −14.3 | +0.737 | grazed |
| Dinan 13 | Riverine | −11.1 | +0.493 | grazed |
| Bala 29ca | Aeolian | −32.1 | +0.339 | **not grazed** |
| Dinan 9 | Riverine | −10.9 | +0.285 | grazed |
| Dinan 1 | Riverine | −30.2 | +0.252 | grazed |

### Three things to check, because if they hold they matter

**Recovery is not a management category.** Five of the seven recovering parts are grazed. Bala
29ca is distinctive in holding *two* of them and in having the largest level deficits, but it
is not doing something no grazed country is doing.

**Recovery is a place.** Four of the seven — Bala 29ca (twice), Dinan 9, Dinan 10, Dinan 13 —
sit within 13.5 km of each other in the south-west, most within 10 km. Bala 29ca abuts Dinan 7
at 3.6 km and Dinan 9 at 5.9 km. Bala 15 (23.8 km away) and Dinan 1 (25.6 km) are outside the
cluster. If this holds, the recovery signature is a **neighbourhood phenomenon in the western
block**, and Bala 29ca is a member of it rather than an exception to it. That would reframe
the reference-state finding substantially.

**Recovery is concentrated in Riverine.** Five of seven are Riverine parts, in the community
with the most negative median trend (−0.282). Riverine country is generally going backwards
while a handful of its worst parts come forward — which is a different and more interesting
statement than either half alone.

### And one that shows the method earning its place

Dinan 10's **whole-paddock** water-adjusted trend is +0.020 pp/yr — indistinguishable from
nothing, rank 55 of 64. Its **Riverine part** is one of the strongest recovering parts on the
property at +0.737. The paddock-level average concealed it entirely. If the scan holds, that is
the argument for the method in one line.

---

## 6. The phrasing standard

Adopt across all client-facing material — site reports, paddock reports, and the Nari Nari
deliverables.

**Write results as places, not as measurements.**

| instead of | write |
|---|---|
| "Bala 29ca has a veg_p05_spatial residual of −16.8 pp" | "The drier western part of Bala 29ca carries less ground cover than anywhere comparable on the property" |
| "the water-adjusted floor trend is +0.556 pp/yr" | "it has been coming back steadily for thirty-five years, and not because it is getting more water" |
| "n_ref = 1, so no community-level claim can rest on it" | "only one ungrazed paddock has any of this country in it, so there is nothing to compare it against" |

Four rules:

1. **Name the part, not the unit.** "The western third of Bala 29ca", not "Bala 29ca".
2. **Compare to like country.** "Lower than other Riverine country", not "lower than the
   property average". People know their own country is different from the next block over, and
   a comparison that ignores that reads as wrong even when it is arithmetically right.
3. **Say level and direction together.** "Low, and coming back" is the finding. Either alone
   is half of it.
4. **End on something checkable.** A result a person could go and look at is a result they can
   act on, correct, or reject. The measure of a well-phrased finding is that someone who
   disagrees knows exactly where to go and look.

Technical precision does not disappear — it moves. Metric names, support levels, thresholds
and provenance belong in the methods section and the figure footers. The headline sentence
carries the place and the direction.

---

## 7. To make this real

The scan in §5 is not a result and must not be quoted. To become one it needs, as a gated task:

- **Pre-registered thresholds**, or a sweep reporting how the four counts move across a range.
  Choosing 8 pp and 0.25 pp/yr after seeing the data is exactly the forking-paths problem I-29
  raised about the five-period boundaries, and it must not be repeated here.
- **Support and stability checks** per part — minimum years, minimum pixels, and whether the
  trend is robust to dropping the two biggest flood years.
- **Serial-correlation handling.** Same issue as T10 §4.1: 35 consecutive annual observations
  are not independent, so no naive p-values.
- **The map.** The four states drawn on the paddock-part polygons, which is the deliverable
  this is ultimately for.
- **Registration** in `dim_headline_number` for anything quoted.

Suggested as **T13**, after 10 August. **No T13 spec has been written** — this section is a
sketch of what one would need to contain, not a draft. The substrate table (115 paddock-parts,
`T10_gateC_percommunity.csv`, tracked producer script) now exists, so a spec is the only
missing input. It does not block any client deliverable, and it should
not be started until the site and paddock reports are out.

**One caution against enthusiasm.** This pattern is appealing partly because it tells a good
story, and a good story is exactly when to be most careful. The thresholds are hand-chosen, the
scan is unreplicated, and the geographic clustering rests on four paddocks. If it survives
pre-registered thresholds and a support check, it is worth building on. If it does not, it goes
in the issues log and this note records why.
