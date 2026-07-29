# Gayini — questions we need answered, and what each one changes

**To:** Adrian Fisher
**From:** remote-sensing stream
**Date:** 29 July 2026

Ten questions. None needs more analysis — each one is a fact somebody holds, and each would
change what we can say. They are grouped by who is most likely to have the answer.

Every question states **what we do if we never get an answer**, because several of these may
never be settled and the reporting has to stand up either way. Nothing here blocks the
10 August deliverable. What they change is how strongly we can state the findings and how much
of the interpretation stays open.

**If only two get answered, make them Q1 and Q4.**

---

## For Ernest — land-use history

### Q1. Was the drier western part of Bala 29ca ever cleared, cropped or irrigated?

Not the paddock as a whole — specifically the western portion, the drier Aeolian and Riverine
country rather than the floodplain part.

**Why.** Bala 29ca produces essentially every reference-state result the project has. Its
vegetation floor sits 17 pp below what its dryness predicts, and it has been recovering for
thirty-five years at about 0.55 pp per year, of which 82% survives adjusting for its own water
supply — so the recovery is not simply the paddock getting wetter. Decomposed, the recovery is
located: the Aeolian third is the lowest of 17 comparable areas on the property and the Riverine
third the second lowest of 37, and both are climbing. The floodplain third is unremarkable and
behaves exactly like everywhere else.

That is what recovery from historical disturbance looks like. But we cannot distinguish it from
naturally poor country that happens to be improving, because the land-use record is empty.

**What changes.** If it was cleared or cropped, the whole reference-state picture resolves into
a recovery trajectory and Bala 29ca becomes the most interesting paddock on Gayini rather than
the most confusing. If it was not, the low floor is a natural feature and the "conserved
paddocks as reference" design has no remaining support at all.

**A photograph would probably settle it.** Anything pre-1988 covering the western part of the
paddock.

**If we never find out.** We report it as observed: this country is unusually bare for its kind
and has been steadily improving for thirty-five years, and we do not know why. That is honest
and it is still the most striking thing in the dataset — it just cannot be attributed.

### Q2. Which paddocks were cropped, cleared or irrigated, and roughly when?

Any resolution at all — a list, a map, a recollection. Even "these six were under irrigation in
the nineties" would be transformative.

**Why.** The question this project was commissioned to answer is whether formerly-cropped
paddocks are converging on the condition of conserved ones. The paddock table has five columns
waiting for exactly this — `cropping_history`, `land_use_era`, `irrigation_status`,
`history_source`, `history_confidence` — and all five are empty for all 64 paddocks. We
substituted the grazing layer, which exists, for the land-use history, which does not. **Every
result we have reported is not-grazed versus grazed, not conserved versus formerly-cropped.**

**What changes.** It makes the commissioned question answerable for the first time. We would
also be able to run it blind: we are classifying every part of every paddock as recovering,
stable or declining using only satellite cover and water data, before any land-use labels
arrive. If the recovering areas turn out to be the formerly-cropped ones, that is a strong
result precisely because we could not have tuned it.

**Timing matters here in a way it usually doesn't.** The classification has to be fixed *before*
the land-use data arrives for that test to be clean. We are doing it this week.

**If we never find out.** The commissioned question stays unanswerable and we say so plainly.
The report becomes a description of which country is recovering and which is not, without
attributing cause — weaker, but defensible, and arguably more useful to a manager than a
contested attribution.

### Q3. Is there anything unusual about Bala 27ca?

Cleared, scalded, salt-affected, historically flooded differently, anything.

**Why.** Two independent products disagree about it in a way we cannot resolve. On satellite
ground cover it is the most ordinary conserved paddock we have — almost exactly the cover its
water supply predicts. On the CSIRO habitat-condition product it is two-thirds hard zero, median
condition 0.000, and completely static across seventeen years. It is fully mapped, entirely
floodplain country, and it holds no monitoring plots at all.

**What changes.** Either the condition product has a problem in that paddock, which is a serious
caveat on the biodiversity work, or there is something real on the ground that ground cover
cannot see. We would rather know which before either deck says anything about it.

**If we never find out.** We report the disagreement as a disagreement. Two products, two
different anomalous paddocks, no agreement on which is odd — which is itself strong evidence
that the four conserved paddocks are not a coherent reference set.

---

## For Nari Nari

### Q4. Is the unzoned country grazed more than the rotational paddocks, less, or not at all?

About 30,700 hectares — 36% of Gayini — sits in no management zone. Some of it is outside the
mapped area entirely; the rest is inside but unfenced or unallocated.

**Why.** All fifteen standard-grazing monitoring plots fall on this country, so standard grazing
has never been measured as a treatment. When we do measure it, the vegetation floor on that land
sits **at or above** the rotationally grazed paddocks in six of nine vegetation-and-wetness
strata, and in eight of nine for the subset we can confirm holds standard-grazing plots.

Two readings fit equally well and the data cannot choose. Either grazing intensity does not
register in this metric at all, or that country is grazed *less* — remote, unwatered, unfenced —
in which case the ordering is real and our labelling is backwards.

**What changes.** It decides which of two opposite interpretations goes in the report. This is
the single largest interpretive uncertainty we are carrying, and no amount of further analysis
will touch it. It is a question of fact about how the place is run.

**If we never find out.** We present both readings and say the data cannot distinguish them.
Honest, and unsatisfying to read.

### Q5. What does Nari Nari most want to know about this country?

**Why.** We have been answering a question about reference states and convergence. That may not
be the question the people managing the place would ask. We now have thirty-five years of annual
cover and flooding for every part of every paddock, and we can answer a fairly wide range of
questions with it — but we would rather aim it at something useful than deliver a well-built
answer to the wrong question.

**What changes.** Possibly the shape of the next phase of work.

**If we never find out.** We deliver what was specified.

---

## For whoever holds the water records

### Q6. What environmental water has been delivered to Gayini, when, and where?

Volumes and timing by year if they exist, and which parts of the property each delivery was
aimed at.

**Why.** This is the question we think the managers actually care about and cannot currently
answer. Management does not change vegetation directly — it changes the water regime, and water
drives the vegetation. We have spent this project testing management against vegetation and
finding mostly composition and wetness effects, which is the wrong link in the chain.

We have a method that would work. For the 2018 bank cuts we fitted a flow law on 24 placebo
dates with 2018 held out, achieving R² = 0.864, then scored 2018 out of sample. The same
approach could ask whether the property floods more than upstream flow predicts since management
changed.

**What changes.** It would let us test management → water directly rather than inferring
management → vegetation. Delivery volumes as a covariate would make it considerably stronger.

**If we never find out.** We say that whether management has changed the water regime is
untested, and that our vegetation results cannot answer it. Given we have only four water years
since management changed — two of which contain the largest natural floods in the record — the
honest expectation is that we could not distinguish a management effect from a wet run even with
the data. **That is worth saying out loud rather than leaving as an implied gap.**

### Q7. Was the 2018 bank-cut work followed by any change in where water goes?

**Why.** We analysed the cuts and found the post-cut years wetter, but in line with how wet those
years were generally — no detectable effect beyond climate. If anyone observed a change on the
ground that our satellite record did not pick up, that is important and it would tell us the
method is not sensitive enough.

**If we never find out.** The existing descriptive finding stands as it is.

---

## For the records — BCT, station, or Jana

### Q8. Stocking rates, or DSE per hectare, by paddock and year.

**Why.** We are comparing "14-day rotational" against "standard" grazing without knowing whether
they differ in intensity at all. If they do not, the comparison is between two labels rather than
two treatments, and several results become uninterpretable rather than null.

**What changes.** It would tell us whether the grazing contrast means anything. It might also
explain why grazing intensity does not order the vegetation floor.

**If we never find out.** We report the grazing comparison as a comparison of management
categories, not of grazing pressure, and say so.

### Q9. Jana's irrigation bank-cut shapefiles.

**Why.** Two things need them. The matched analysis of the 2018 cuts cannot be completed without
confirmation of the layer. And separately, the biodiversity product finds about 15,000 hectares
scoring zero habitat condition in eight compact interior blocks, 40% of it on country with no
vegetation class and no management zone — a pattern most consistent with cleared or developed
land. Irrigation infrastructure would help confirm or rule that out.

**If we never find out.** One component of the bank-cut analysis stays incomplete and is reported
as such. The zero blocks stay unexplained.

### Q10. Why does Bala 27ca have no monitoring plots?

**Why.** It is one of four conserved paddocks and one of three carrying the central finding that
the conserved paddocks are indistinguishable from grazed ground. Having no ground observation in
it is a real limitation. If the omission was deliberate — inaccessible, atypical, already
known — that is useful information about the paddock.

**If we never find out.** We note it as a limitation, which we are doing anyway.

---

## What we are doing in the meantime

Nothing here is on the critical path to 10 August. The reports are being built on what we have,
with the gaps stated rather than filled by assumption, and every number traced to the database.

The two that would change the most are **Q1** and **Q4** — one paddock's history, and whether
30,700 hectares are grazed. If those two arrive even after the tenth, several findings get
considerably stronger.

The rest we will make do without, and say so where it matters.
