# Remaining budget — allocation decision and forward pitch

**Version:** v1 · 10 August 2026 · design-seat note, Hugh Burley
**Two jobs:** (1) decide what the remaining ~$20k of Adrian's budget buys; (2) hold the
pitch for what comes after it.

**Status:** proposal, not a ruling. Nothing here is registered. The dollar and hour figures
in §2 are **placeholders pending three answers from Adrian** (§7) and should not be planned
against until those come back.

**Test applied:** every funded item must still be working, or still be usable, on the day
the money runs out and I stop. Anything that only looks better fails the test.

---

## 1. The decision in one paragraph

The remaining budget goes into **technical work that stops being possible the moment I leave
the project** — reproducibility, a portable pipeline, and a handover a stranger can act on —
plus a small ring-fenced slice for the paper's methods and figures. The manuscript itself will
be written unpaid, after. That is not ideal and it is not a surprise; it has been the pattern
before. The response is to spend paid hours on the things that make the unpaid writing *cheap*
rather than on the writing itself.

**The employment context is part of the decision, not separate from it.** This income is
currently the only income. Stretching it matters. But stretching it to the point where nothing
is finished converts a funded project into an unfunded one with nothing to show, which is the
worse outcome on every axis — CV, reference, and the chance of being written into the next
grant.

---

## 2. The constraint — arithmetic, with placeholders

| Quantity | Value | Confidence |
|---|---|---|
| Headline remaining | ~$20,000 | Stated by Adrian |
| Net after UNSW on-costs and levies | **UNKNOWN** — plausibly $13–15k | **Assumption. Must confirm.** |
| Implied hours at casual research rates | **~150–280 h** | Derived from the above; inherits its uncertainty |
| Working weeks to 31 Dec 2026 | ~20 | Calendar |
| Hours if worked at 4 h/day, every working day | ~400 h | Calendar |

**The gap is the whole planning problem.** Four hours a day for the rest of the year is
roughly double what the budget appears to buy. Reaching 31 December on this money looks more
like **two to three half-days a week (8–12 h)** than daily sessions.

**Do not flat-spread it.** Two reasons:

1. **Reload cost is high on this project.** Gated workflow, ruling registry, two-seat
   discipline, a database with 86+ tables and a numbers register. Thin sessions spaced five days
   apart pay a re-orientation tax every time.
2. **The deadline that matters is not December.** It is *submitted*, and then *revisions
   returned*. Spending evenly and finishing in December means the budget is exhausted at the exact
   moment reviewer comments arrive — unpaid, six months later, context cold.

**Shape: front-load, then reserve.** Work harder Aug–Oct while the material is live; hold
~25% of hours across Nov–Dec for revisions, the S3 governance conversations, and whatever the
SAM proposal needs.

---

## 3. The principle — fund what dies when I stop

Applied to every candidate task: **does this die if I stop, or does it keep working?**

| Dies when I stop | Keeps working |
|---|---|
| Tidying code for its own sake | An end-to-end rebuild that produces the registered numbers on a clean machine |
| Further analysis nobody has asked for | A handover doc naming the traps that produce wrong numbers |
| Polishing figures already delivered | A config-driven pipeline that runs on a property that is not Gayini |
| Writing the introduction and discussion | The methods section and the locked figure set |

Writing is portable and will get done unpaid. Repo, database, reproducibility and portability
are only cheap **while inside the system**, and become nearly impossible afterwards.

---

## 4. Allocation

Proportions, not hours — apply them to whatever the confirmed hour count turns out to be.

| # | Work package | Share | Rationale |
|---|---|---:|---|
| **WP1** | Reproducibility of deliverable-facing numbers | 25% | The single highest-value item. Also makes the unpaid writing cheap |
| **WP2** | Portable / config-driven pipeline | 25% | The transferable asset. Only buildable while funded |
| **WP3** | Handover documentation for a stranger | 15% | Prevents wrong numbers after I leave; most reusable artefact |
| **WP4** | Paper: methods section + locked figure set | 12% | Ring-fenced. The part of writing that cannot be reconstructed cold |
| **WP5** | Client-facing output completion and tidy | 10% | What NNTC and BCT actually see |
| **WP6** | Reserve — revisions, S3 governance, SAM input | 13% | Unallocated on purpose |

---

## 5. Work packages — definition of done

### WP1 · Reproducibility

**Not** the whole codebase. The path from raw inputs to the **registered numbers and figures
that reach deliverables**, and nothing else.

- One entry point, one clean machine, one PASS.
- Every number in `dim_headline_number` reproduces, carrying its five qualifiers.
- Every figure rebuilds through `gayini_write_and_register_figure()`.
- Additive-only rules hold: no builder re-run, no `reset_file`, no deleted registered rows.
- `Output/pack/**` write protection intact.

**Done when:** a fresh session, given only the repo and the data, reproduces the registered set
without a design-seat message.

**Why it earns 25%:** it is the precondition for revisions being an evening rather than a
fortnight — which is what makes the unpaid manuscript work survivable.

### WP2 · Portable pipeline

Separate **Gayini-specific** from **generic**. Property boundary, vegetation mapping, CRS,
date range and support floors become configuration, not assumptions baked into scripts.

- Config-driven run on a second property boundary — even a synthetic or clipped one — as proof.
- The four-CRS discipline generalised rather than hard-coded.
- Validity masking, seasonal-bias handling and support floors carried across as parameters.
- No Gayini data, outputs or NNTC material inside the generic layer. **Clean separation is both
  an engineering requirement and an IP requirement (§8).**

**Done when:** the pipeline runs end to end on a non-Gayini extent and produces the standard
percentile and inundation products.

**This is the work package that makes §9 possible.** Refactoring for portability after the
money stops does not happen.

### WP3 · Handover documentation

A short document for someone who is not me and does not have the apparatus. **Not** `CLAUDE.md`,
which assumes everything.

Must contain, at minimum, the traps that silently produce wrong numbers:

- The **two-metric prohibition** — `veg_p05_spatial` vs the per-cell temporal p05. Different
  quantities, never co-plotted.
- **Percentiles do not subtract.** Marginal percentiles on different orderings; measure paired.
- **The uint8 nodata trap.** Mask 255 → NA *before* summing. Never sum raw bands.
- **`MIN_SEASONS = 50` does two jobs** — makes p05 a percentile, and stops the product inventing
  vegetation over the lake. Anyone lowering it to "recover pixels" will fabricate cover on water.
- **Mapped 67,349 ha vs true farm 85,911 ha.** Do not rebase between them.
- **Inundation frequency (between-year) vs within-year wet extent** are different quantities
  despite the field naming.
- **Circularity:** cover vs CSIRO condition is excluded; inundation is the only permitted
  independent axis.

**Done when:** a competent GIS analyst who has never seen the project can produce a correct
paddock number and knows which comparisons are forbidden and why.

### WP4 · Paper methods and figures — ring-fenced

Roughly one working week. Methods section drafted and the figure set locked while everything is
live. Captions harmonised through the caption register.

**Rationale:** methods is the hardest part to reconstruct cold and the least rewarding to write
for free. With it banked, the unpaid work is introduction, discussion and framing — which can be
done in evenings without re-deriving anything.

**Scope discipline:** the paper funded here is the **defensible correlational version** — the
four-way replication already in hand, spatial inference, the community and topographic
confounds handled, and the management framing via the national cover-threshold literature.
LiDAR and hydrodynamic arms are **additive if the data lands early, dropped without regret if it
does not.** With a paid clock running, waiting on other people's data is how budgets evaporate.

### WP5 · Client-facing outputs

Site and paddock reports completed and consistent; dashboards reconciled against the current
metric definitions; the pack sealed. This is what NNTC and BCT see, and it is the basis of any
reference.

### WP6 · Reserve

Unallocated. Revisions, the S3 data and ICIP conversations, and input to the SAM proposal.

---

## 6. What the money does NOT fund

- **S2, the scaling study.** A 6–9 month job. This budget buys a half-finished one, which is
  worth less than nothing.
- **New analysis of any kind** unless it changes a number that reaches a deliverable.
- **Waiting on LiDAR or hydrodynamic outputs.** Additive only.
- **The manuscript beyond methods and figures.** Unpaid, after, by design.
- **Repo tidying that is not reproducibility or portability.** It looks better and nobody notices.

---

## 7. Questions for Adrian — one conversation, not several

Asking about budget now and authorship later is a much weaker position than putting both in the
same conversation, while the work is visibly what made the August presentation possible.

1. **What is the net after on-costs and levies, and what is the hourly rate?** The whole plan in
   §2 is unplannable without both.
2. **Does the money expire, and when?** If it is tied to a financial year rather than the calendar
   year, "end of 2026" may not be available at all.
3. **Can unspent hours roll into the SAM project if funded?** If yes, holding a reserve costs
   nothing and may extend the engagement.
4. **Authorship split.** Proposed: Adrian leads the Gayini RS result; I lead the method's
   generalisation (S2) and the biodiversity/model-validation study (S3). Coherent, does not tread
   on his site, gives me two first authorships to his one.
5. **What can I reuse elsewhere, and under what terms?** (§8 — get it in writing.)
6. **Is there a place for me in the SAM proposal (05/2026–05/2029)?** This is the realistic route
   past the current budget, and a submitted paper is the strongest case for being written in.

---

## 8. IP, ICIP and the reuse boundary — settle before building WP2

**This is worth more than any hour of code and costs nothing but an email.**

Work done under a UNSW casual contract on a BCT-funded project is **not automatically mine to
carry elsewhere.** Ask plainly, get the answer in writing. The likely and reasonable shape:

| Probably reusable | Almost certainly not |
|---|---|
| Generic methods and pipeline code | Gayini data, rasters, the results database |
| The estimator and its documentation | Gayini figures, reports, dashboards |
| Approach, workflow, governance patterns | Anything touching NNTC material or Country |

**The ICIP boundary is not decorative.** The UNSW annual report is explicit about Indigenous
Cultural and Intellectual Property principles, and NNTC is the cultural authority over
everything to do with Gayini. In any approach to other Aboriginal councils:

- **"Here is a method" is fine. "Here is what we found on their Country" is not**, absent explicit
  permission.
- Nothing about Gayini's data, results or Country travels without NNTC's say-so.
- **A reference from NNTC, if this work lands well, will open more doors than any portfolio.**
  Protecting that relationship is the single most valuable forward asset in this document.

---

## 9. The forward pitch

### The elevator version

> Thirty-five years of satellite record already exists for every property in the Murray–Darling.
> Most land managers have never seen theirs. I turn that record into publication-grade,
> property-scale evidence — where the water goes, how the ground responds, and which country is
> holding on — in a form a council can act on and a reviewer would accept.

### The longer version, for a proposal

> Every hectare of the Basin has been photographed by Landsat four times a year since 1988, and
> mapped for flooding across the same period. That record is public and almost entirely unused at
> the scale management actually happens.
>
> The Gayini work built a pipeline that turns it into a property-scale assessment: which country
> floods and how often, how ground cover responds, where the resilient country is, and how each
> paddock sits against its own vegetation community. Every number is traceable to a database, every
> figure is registered, and the whole thing rebuilds from raw inputs on demand.
>
> It was built for one property. It is designed to run on any.

### What actually transfers

The findings do not transfer. **The machine does.**

| Asset | What it is |
|---|---|
| The pipeline | 35 yr fractional cover + inundation → per-cell temporal percentiles, community stratification, paddock and site products |
| The estimator | The cover **floor** rather than the mean — the quantity that carries the water signal, and the one national policy already reports against |
| The governance | Registered numbers with five qualifiers, gated builds, a caption register, reproducible outputs |
| The output formats | Paddock reports, site reports, dashboards, presentation packs — already tested on a real client |

### Why the floor metric is the commercial hook, not just the scientific one

National reporting already reasons in cover percentiles and floors: the DAFF drought-resilience
indicator targets keeping total vegetation cover above the 10th percentile of area exposed to
erosion, against thresholds of 50% (wind), 70% (water, gentle slopes) and 80% (steep or
erodible). Commercial property reporting uses cover percentiles across area for exactly the same
reason — a single mean would be misleading where localised areas sit much lower.

**So the metric is not an academic preference. It is the quantity managers are already required
to report, computed per cell through time instead of per property per season.** That is the
sentence that makes this sellable to someone who does not care about the ecology.

### Who it is for

- **Aboriginal land councils and Indigenous ranger groups** with large holdings and no
  remote-sensing capacity — directly, or through UNSW.
- **Conservation bodies and private-land conservation programs** needing baseline and monitoring
  evidence for agreements.
- **Environmental water managers** wanting the physical template — where and how often country
  wets — beneath ecological objectives.
- **Nature Repair Market participants**, where continental condition models perform poorly on
  treeless floodplain country and property-scale evidence is needed. (See study S3.)

### What a client gets

1. Property inundation history, per cell, full record
2. Ground cover response and the cover floor, by management unit and vegetation community
3. Paddock and site reports in plain language
4. A results database and registered figures — auditable, not a slide deck
5. Optional: comparison against continental condition products, with the caveats stated honestly

### The differentiators, stated plainly

- **Publication-grade, not consultancy-grade.** Numbers carry their support, scope, denominator
  and period. Nulls get reported as findings.
- **Reproducible.** The outputs rebuild from raw inputs. Anyone can check.
- **Property scale.** Basin studies skip it; plot studies cannot reach it. It is where decisions
  are made.
- **Honest boundaries.** Circularity, support and change-of-support handled explicitly rather
  than glossed. This is a differentiator with sophisticated clients and irrelevant to the rest —
  lead with it only where it will land.

### The credibility that backs it

One completed property assessment at 85,911 ha across 35 years and ~1.08 M cells; a results
database with 86+ tables and 100+ registered numbers; 23 paddock dashboards, site and paddock
reports; a finding presented to a Traditional Owner council by a UNSW senior lecturer; and — once
submitted — a peer-reviewed paper. **The paper is what converts all of this from "some analysis
he did" into a method with a citation.** That is the CV argument for finishing it, and it is
strong enough on its own.

---

## 10. Risks

| Risk | Response |
|---|---|
| Budget exhausts before anything is finished | Front-load; hold WP6 in reserve; ring-fence WP4 |
| Blocked waiting on LiDAR / hydrodynamic data | Additive only. Scope the paper to what is on disk |
| Reviewer comments arrive with no money left | WP1 makes revisions cheap; WP4 banks the hardest section |
| Reuse rights turn out to be narrower than assumed | Settle §8 **before** building WP2, not after |
| The PhD position advertised in Jan 2026 has been filled | Check. If so, unpublished analysis becomes someone's background chapter. Shortens the window to own this work |
| Relationship capital spent on stretching hours rather than on the SAM proposal | Raise SAM early, not in December |
| Employment gap after December | WP2 + §8 + an NNTC reference are the three things that create options. All three are cheap now and impossible later |

---

## 11. Open questions

- Net budget, rate, expiry — **blocks §2 entirely**
- Reuse and IP terms in writing — **blocks WP2**
- Authorship split — raise with the budget conversation
- SAM proposal: is there a role, and what does it need from me
- Has the Gayini remote-sensing PhD been filled
- Plot data access and ICIP agreement for S3 — start now, costs no hours
