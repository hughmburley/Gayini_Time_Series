# Reference-state stream → report stream — reply

**From:** reference-state stream (T1/T2/T6/T8/T9/T10)
**To:** report stream
**Date:** 29 July 2026
**Re:** your note of 29 July, and the Bala 29ca / GA_036 drafts
**Bottom line:** your §5 blocker is half-cleared already, one item on page 4 must change, and
§3.1 is right but smaller than you feared.

---

## 1. Your hard blocker — partly solved before you asked, one item worse than you thought

Your §5 was written against the pre-Gate-D state. **T10 Gate D (SHA `e26abb4`) registered the
expectation apparatus**, so most of it is no longer unregistered:

| object | status |
|---|---|
| `floor_flood_slope_64pdk` = 0.548, spread [0.498, 0.548] | registered |
| `floor_flood_r_64pdk` = 0.710, spread [0.680, 0.710] | registered |
| Bala 29ca cross-sectional residual −16.80 | registered |
| Dinan 10 residual −15.06 | registered |
| water-adjusted floor trend +0.556, SE 0.126 | registered |

Three things are genuinely outstanding, and the third is not a gap but a defect:

- **The intercept (52.65) is not registered.** You need it to draw the line. We will add it.
- **The 64-paddock residual table exists only as CSV.** It should be a queryable object so the
  batch does not read a file. We will promote it.
- **The five-period trajectory is not unregistered — it is superseded, permanently.** It is
  PIN 3 in `dim_headline_number`, `pinned_value` NULL, blocked on I-29. There is no producing
  script anywhere in the repository and the boundaries (5, 10, 10, 6, 4 years) have no
  provenance. **It will never be registered.**

**Page 4 must switch to the annual series.** T10 Gate B produced it and it is registered:
reference set +0.273 pp/yr (r 0.770), Bala 29ca alone +0.919 (r 0.846), excluding Bala 29ca
+0.057 (r 0.222). No boundaries, one value per water year, and the underlying series is in
`Output/tables/T10_annual_gap_series.csv`. It is a better figure than the five-period table as
well as a defensible one.

The last of those three numbers is worth your attention for the client text: **without Bala 29ca
the reference paddocks show no trajectory relative to grazed ground at all.** Not a small gap
slowly closing — nothing happening.

## 2. Your §3.1 — you are right, and we tested how much it costs

Adding community composition to the cross-sectional regression:

| model | flood slope | Bala 29ca residual | rank |
|---|---|---|---|
| flood only | +0.548 | −16.80 | 2 of 64 |
| flood + composition | +0.374 | **−14.59** | 2 of 64 |

Composition explains about 2.2 pp of the 16.8 — real, 13%, and the rank does not move. Your
instinct was correct and the figure survives it. Keep it, with the qualifier you already have.

**The larger consequence is for page 4, not the residual.** The flood slope falls by a third
once composition is in the model. A single expectation line from flood alone is a fair
approximation for a 98%-Inland paddock and a poor one for a paddock that is a third of each —
which is the paddock your pilot is built on. See §4.1.

*(Design-seat figures. Predictions to check, not targets.)*

## 3. Your §3.3 — denominator settled, and you should use yours

Our 14 counted the three focus communities on non-treed in-scope pixels. Your 17 included the
Other/minor class. Both correct; neither is the right default for both audiences.

**For client text, yours is better.** Shares that sum to the whole paddock are more honest than
shares renormalised onto the analysed subset. A reader told "58% Riverine, 37% Inland" will
assume that is the paddock, not the part of the paddock we chose to analyse. Say "5% other" and
the sentence is true.

**For analysis, ours is right**, because the analysed strata are the three focus communities.

The composition view we owe you (§4.2) will carry both, with the denominator named in each
column. L-01 §1 will state which it used.

## 4. What we are building, in order

### 4.1 Part-grain expectation — the one real new analysis

Fit floor against flood **within each community** across the 115 paddock-parts, so every part
gets its expectation from like country. This makes page 4 the same analysis as page 3, at the
same grain, and removes the composition problem by construction rather than adjusting for it.

It is also the honest answer to your §3.1: rather than qualifying a whole-paddock residual, give
each part its own.

### 4.2 Registration and plumbing

Intercept registered; 64-paddock residual table promoted to a DB object; composition view with
a dominance column at both denominators. None of it is analysis — it is the plumbing that turns
your two documents into 77 without re-deriving anything.

### 4.3 A question back on the site reports

Page 2 of the site report rests on plot support with the any-water rule, which will not match
paddock flood frequency — you have that in a footer. Confirm nothing else on that page needs a
paddock-grain number it cannot have. We would rather find that now than at report 40.

## 5. Your page 3 ruling — run it everywhere, let it degrade

You proposed running page 3 for the 14 mixed paddocks and dropping it above 75%. We would run
it in all 21 and let it shrink.

Two reports with different page counts invites a reader to wonder what is missing from the
shorter one. And for a single-community paddock the degraded version is a useful sentence rather
than filler: *"this paddock is entirely Inland floodplain country, so the figures below describe
it directly."* That tells a manager something true and reassuring, and it costs three lines
rather than a page.

## 6. Step 1 — the four conservation paddocks

Better supported than your note assumes:

| paddock | dominance | sites (total / treed / reportable) | page 3 | residual |
|---|---|---|---|---|
| Bala 26ca | 98% Inland | 3 / 0 / **3** | one-liner | −8.70 |
| Bala 27ca | 100% Inland | **0 / 0 / 0** | one-liner | −0.91 |
| Bala 28ca | 83% Inland, 17% Riverine | 8 / 0 / **8** | two parts | −8.31 |
| Bala 29ca | 35 / 33 / 32 | 13 / 3 / **10** | three parts, substantive | −16.80 |

**21 site reports, not 24** — three of Bala 29ca's are treed. **Bala 27ca has no sites at all**,
so it needs the graceful-degradation path on page 5 as well as page 3. It is also the paddock
with the smallest residual (−0.91) and one of the two declining relative to water (−0.337 pp/yr
adjusted), so it is a genuinely different story from Bala 29ca and should not be written to the
same template narrative.

## 7. Reconciliation against the source of truth

Agreed, and we would like to make it a standing mechanism rather than an intention.

Both streams already have the pieces. `dim_headline_number` carries `source_object`, `grain`,
`aggregation_order`, `series_variant`, `scope_filter`, `denominator` and `pixel_constant` for
every headline number, and `test_T8_headline_reproduction.py` re-derives all 56 from source by
an independent path and exits non-zero on drift.

Two proposals:

1. **Run the reproduction test before every report batch**, not only after analysis changes. It
   takes seconds and it is the only thing standing between a stale number and 77 documents. It
   is deliberately not wired into the smoke test (I-19 — the suite carries permanently-red
   checks), so it must be run explicitly.
2. **Adopt your scope lock, enforced from the database rather than by convention.** Your §3.2 is
   the best diagnosis anyone has written of this failure — three defensible flood frequencies and
   three defensible floors for one paddock, all correct, all invisible to a reader. Since
   `scope_filter` already exists on every pinned row, a report figure can state its scope by
   reading it rather than by someone remembering. We will adopt the same lock on the deck.

Your point about *the floor* naming two different objects is well taken and we have carried it
into the methods document. In client text we will follow your lead and never use the word bare.

## 8. A correction to the framing — and it is ours, not yours

Your managers are right and we have been answering an adjacent question.

The chain that matters is **management → water regime → vegetation**. We have spent T1, T6 and
T10 testing management → vegetation directly, and found what that design can find: not much,
mostly composition and wetness. That water drives cover is not a finding — it is the premise,
and stating it as a result reads as naive to anyone who works the country.

**What the project can say about management → water:**

- **Task J tested it directly** for the 2018 bank cuts, and it is the most rigorous design in the
  project. A flow law fitted on 24 placebo dates with 2018 held out, R² = 0.864, 2018 scored
  out-of-sample at residual +7.51 pp, rank 2 of 25. Framed descriptively — the post-cut years
  were wet, and the change is in line with how wet they were. Not a causal claim, deliberately.
- **F6 found no directional trend in inundation** across 35 years, 9 no-trend / 0
  non-stationary / 0 directional — with the caveat that the Aeolian-low verdict is vacuous
  because those pixels never flood at all.

**What it cannot say, and why.** Whether property-scale management changed the water regime
needs a counterfactual we do not have. Gayini's water arrives via Murrumbidgee flows and
environmental delivery decisions, and separating a delivery decision from a wet year requires
either a control property or a long post-change record. We have four post-management water years
and two of the biggest natural floods in the record sit inside them.

**What could be tried, and its likely answer.** Task J's flow-law method generalises: fit
property inundation extent on upstream gauge flow using pre-management years, then score the
post-management years out of sample. If the property floods more than flow predicts, that is a
management signal on water rather than on vegetation. With four post-years the honest expected
outcome is *cannot distinguish* — but a well-designed null is a publishable answer and a better
one than the vegetation contrast has produced. If the environmental-delivery volumes exist as a
covariate, it improves considerably.

**For the reports, this should change the wording, not the content.** Rather than presenting
water as an explanation for vegetation, present it as the thing the managers act on. What the
reports can honestly say is: here is how much water this country got, here is how the vegetation
responded, and here is which parts responded differently from comparable country. Whether
management changed the water is a question the deck should state as open rather than answer.

## 9. Provenance

Everything here traces to `Gayini_Results.sqlite`. The composition regression in §2 is
design-seat work computed 29 July, unregistered, and is a prediction to check. Task J figures
from `Gayini_prepost_2018_methods.md` §§3.5, 4. F6 from `Gayini_established_data_facts.md`.
Site counts from `plot_paddock` joined to `dim_plot.treed_plot_flag`.
