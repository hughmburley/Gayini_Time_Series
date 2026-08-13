# Gayini — stocktake and Sunday task list

**9 August 2026.** Adrian presents to the Nari Nari Tribal Council and BCT on Monday 10 August.
Design seat working document.

---

## 1 · What Adrian asked for, and what exists

### From 8 August

| his words | status |
|---|---|
| *"Can you share with me the raster of flood frequency?"* | **Closed.** `flood_frequency_counted_8058.tif` built, registered (`raster_asset` 192), three verifications passed, in the share folder. The interpolated one he already has is now documented as a display surface. |
| *"Those are all annual. Can you share the flood freq data that you used for this map?"* | **Closed.** Same file. |
| *"I'd like to include some examples"* of cover and inundation over time | **Closed.** Nine EXEMPLAR-1 figures, part grain, pixel support both axes, correct labels, locators. Plus the dashboards and `U2_epoch_context_35yr` he already holds. |
| *"I'm not sure that maps of the residuals are a good idea"* | **Closed.** Dropped, agreed in writing. |
| The three steps — per-cell percentiles, area averages, plot against inundation | **Closed.** TEMPORAL-1 complete. Scatter registered, four tables, reuse audit clean. |
| *"I think it might be better I just concentrate on showing examples of areas with different veg cover and inundation time series"* | **Closed.** That is precisely what EXEMPLAR-1 is. |

### From 5 August — asked, never answered

He sent four questions with the methods pack and got no reply. **These are still open and one of them is
the most Monday-relevant item in the chain.**

1. *"Does the order make sense? Easy to change"*
2. *"How can we improve the language / framing? Our position is that management category does not
   order the results while geography does, and that we cannot say why...yet"*
3. ***"What are some BCT / Nari Nari questions we could anticipate?"***
4. *"Any jargon to cut / explain?"*

**Question 3 is worth more to him on Monday than any new figure.** He is standing in front of the
traditional owners and the funder with ten minutes of material. Twenty minutes of our time gives him
the questions he will actually be asked and short, honest answers.

### What he told us about the bar

29 July: *"I just want to show the Nari Nari and BCT that we are doing lots of things, so I don't
need to have clear results."* The goal is confidence and momentum, not a finished paper.

---

## 2 · What we hold that he has not seen

- Nine EXEMPLAR-1 figures (cover and water over time, part grain, correct labels)
- The TEMPORAL-1 scatter — his own method, his own axes
- `flood_frequency_counted_8058.tif` and the corrected DATA-1 README
- The community × flood-bin table, the unit table, the reconciliation table
- The surface provenance list — 19 artefacts, producer and water surface named

---

## 3 · Sunday task list, in priority order

### A · Paddock sheet v2 — three units *(highest value, do first)*

**Rebuild the D1 sheets for Bala 26ca, 28ca and 29ca as a new product.** Not a re-render — Ruling BL
stands and the 81 existing sheets are untouched. A new v2 sheet for three units is additive.

Why these three: he already holds them, so a v2 shows improvement on figures he has looked at rather
than asking him to learn a new artefact.

**What changes, and each of these answers something he raised:**

- **Cover and water on the same ground.** The v1 cover panel is plot-built (a few hectares); the
  water panel is the whole polygon. v2 draws both from the part table — same cells, same years,
  pixel support. This is the substantive fix, not a relabelling.
- **Correct water labelling** — *how much of this country went under water each year*, per AZ and CX.
- **Split by community where the paddock is mixed.** Bala 29ca is roughly thirds; one panel per
  community present above ~10% share. This makes L-01 visible rather than argued, and it is the
  clearest one-slide answer to why a fence line is not an ecological boundary.
- **The paddock's position on the TEMPORAL-1 scatter** — his own metric, his own axes, showing where
  this unit sits among the 64.
- **`support_level` populated**, and the five qualifiers present.

Assembled from existing producers: the EXEMPLAR-1 two-panel shape, the D1 locator, the TEMPORAL-1
scatter. Nothing new is computed.

### B · Answers to the four questions from 5 August *(cheap, high return)*

A short document, not a deck. Question 3 gets the most space: anticipated Nari Nari and BCT questions
with a plain answer to each. Candidates worth preparing —

- *Is the country getting better or worse?*
- *Does conservation management show up in the satellite record?* (the honest answer is the null, and
  how to say it without it sounding like failure)
- *What does this say about where water should go?*
- *Can you tell us about our specific paddock?*
- *What can't this data tell us?*

Question 2 already has our position — water organises the country, management category does not order
the results, and we cannot yet say why. That is a defensible headline and it needs one paragraph of
plain wording he can read aloud.

### C · The email *(design seat, not CC)*

Carries: the corrected raster; the seasonal-basis correction against the 35 values he was told; the
nine exemplars; the scatter on his method; and answers to the four questions. Sent Sunday, not Monday
morning.

### D · A one-page "what changed and why" note *(if time)*

Short, plain, for him rather than for the record. The corrections found and fixed before he saw them
are the evidence that the work is being checked — worth stating once, without dwelling.

---

## 4 · Not tomorrow

- Recutting the terciles (DQ — documented trade-off, does not move before Monday)
- Annual-basis percentile rasters (deferred, awaiting a ruling)
- Re-rendering the 81 dashboards (BL stands)
- SPAT-1, GLM-1, the out-of-sample validation, REPORT-2
- Backfilling run records for EXEMPLAR-1, TEMPORAL-1, DELIVER-1

---

## 5 · The honest position

Everything Adrian asked for exists. The remaining risk is not analytical — it is that the work sits
in a repository and a share folder rather than in his hands, and that four questions he asked four
days ago are still unanswered.

Tomorrow is packaging and correspondence, not analysis.
