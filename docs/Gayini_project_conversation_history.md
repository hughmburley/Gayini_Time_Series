# Gayini Remote Sensing — Consolidated Conversation & Direction History

*A running record of the project's direction-setting conversations, compiled 24 July 2026. Purpose: to hold the whole arc in one place — governance, the analytical pivots, and each round of Adrian Fisher's feedback — so that any session (human or Claude Code) can see how we got here and what the current direction is.*

*The final section (§5) is the current live direction. Everything before it is context for how we arrived.*

---

## 1. Governance and the client relationship (standing context)

- **Nari Nari Tribal Council runs Gayini and is the client.** They obtained control of the property in 2013, though the timing of the actual land-management changes remains uncertain (we have been assuming ~mid-2019; the irrigation bank cuts are dated 2018).
- **Nari Nari has an agreement with the Biodiversity Conservation Trust (BCT)**, which pays UNSW by contract.
- **The 1 ha plots and their measurement protocols were specified by BCT**, not by us. UNSW follows their protocols. This is why the plots are fixed anchors rather than a design we can revise.
- **BCT's actual question is whether grazing and biodiversity can co-exist** — similar to work at UTAS. Worth keeping in view: our current framing does not answer this directly.

**Implication that persists:** the audience is a land-management client, not only a journal. Findings need to be framed for people making decisions about country.

## 2. The early task list (pre-pivot)

Two substantial data tasks were set, both still relevant:

1. **Incorporate Flow_MER remote-sensing inundation code** (Andres Sutton) into the workflow — a more thorough inundation treatment to compare against ours.
2. **Obtain NSW water gauge data** for the relevant Murrumbidgee gauges, 1988–present, flow-type data only. Existing extractors were to be used rather than built (MDBA_Gauge_Getter, bomWater). **Status: done** — gauge flow is now in the database (1988–2023) and appears on the site dashboards as background context.

Also flagged early: Adrian would build a **difference DEM from 2009 and 2021 LiDAR** to show what earthworks Nari Nari have done. That LiDAR work has now matured into something more important (see §5).

## 3. The 15 July pivot — from sampling to all-pixel census

The largest single direction change in the project. Adrian's view, reviewing the sampling-based slides:

- **Use ALL the pixels, not a sample.** For the veg × wetness matrix, the flood-trend analysis, the lag-correlation analysis and the response matrix. "A pure geospatial approach, not a statistical one."
- **Build total-vegetation percentile rasters** — lower percentiles (5/10/20/30/50) rather than mean or median. The rationale is ecological: if something survives when vegetation is generally struggling, that signals a healthy ecosystem. *This became the project's most productive single idea (see §4).*
- **All-pixel figures must change form** — no thousand-point scatterplots; use confidence bands and heat-map/kernel-density displays.
- **CSIRO HCAS/LOOC-B may be compared with inundation, never with ground cover** (circularity — both derive from Landsat reflectance).
- **Exclude treed Floodplain Woodland/Forest** from ground-cover interpretation; show the exclusion on a map.
- **Dashboards are a genuine Nari Nari deliverable**, ideally as per-site reports combining narrative context, Earnest's nearmap land-use attribution, and Gayini management input.

**And the critical caveat, raised then and still live:** Landsat fractional cover measures *cover*, not *structure* or *identity*. Early-record cover could be irrigated cropping (wheat, cotton); later-record cover could be re-established native chenopod. A trend in cover may be a trend in land use, not condition. Adrian's conclusion at the time: Landsat FC may not resolve management effects as hoped — but **the null result could still tell a story**, and higher-resolution structural data (LiDAR, nearmap) would be the next resort.

## 4. What the census delivered (the results Adrian saw on 24 July)

The pivot worked, and it resolved the caveats that dominated the earlier deck:

- **Flood trend (S21): 9 no-trend / 0 non-stationary / 0 directional.** Flooding is flood-pulse driven, not trending. Critically, the census *explained* the earlier sample-era anomaly: the Riverine-low "episodic jump" was a 40-point sparsity artefact (p<0.05 in 541/1000 random 40-point draws against a nominal 5%). The census adds no temporal power but removes within-year measurement error — which is why the false flag fell away.
- **Coverage (S12):** the sampling-density question dissolved; Inland Floodplain is 66.44% of the *mapped* farm (67,349 ha of the 85,911 ha property).
- **Response gradient (S24/S26):** dry→wet strengthening sharpened at census (r 0.17 → 0.23 → 0.35). Key distinction established: **r measures consistency, not magnitude** — the driest bands show the *largest* per-flood cover gains but the *lowest* r (saturation, not "no effect"). Aeolian-low never floods in 35 years, so same-year response is not measurable there — a result, not a gap.
- **THE HEADLINE — the signal is in the floor.** The p05 (worst-season cover) climbs steeply with flood frequency (~45→78%), while p50 (typical cover) is nearly flat (~75→90%). The percentile fan is tall where flooding is rare and **compresses** where flooding is frequent. Mean or median cover would have hidden this entirely. This is a drought-resilience signal.
- **Lag (S25):** ~3-month peak response, but **plot support only** (n = 2–17 plots, 2014–2025) because per-pixel sub-annual inundation exists only from 2014 and isn't built. Never merged with the all-pixel results.
- **Dashboards:** site and paddock scale, each placing the unit against its own community's distribution and against the community GAM floor curve, with gauge flow as background. The floor–flooding relationship *replicates* within individual paddocks (6k–32k pixels), not just in the pooled census.

## 5. Adrian update — 24 July 2026 (CURRENT DIRECTION)

This conversation reframes the project's scientific story. The census results are accepted; the question is now what story they serve.

### 5.1 New data arriving

- **Ernest's land-use attribute table** from aerial imagery — to be combined with DEA Landsat data. **DEA L3 is confirmed acceptable and we now have that data.**
- **Adrian's LiDAR model** is finding areas of the farm with shrubs 1–3 m tall — effectively **a lignum swamp that may be permanently wet and possibly permanently green.**

### 5.2 The immediate testable idea — refugia × LiDAR overlap

**Do our "always green" refugia coincide with Adrian's LiDAR lignum swamp?**

This is the single most actionable item, and it is a genuine convergence: our census identified a persistently high vegetation floor from *spectral* data; Adrian's LiDAR identifies structurally distinct 1–3 m shrubland from *structural* data. If they overlap, two independent sensors agree — which directly attacks the structure-vs-condition caveat that has limited the whole project.

Specifics recorded:
- The lignum swamp is **the large wet area near the centre of the farm**, with a hard border against the next paddock.
- It sits within **the ungrazed exclusion area (the "pink paddocks")**.
- **Action: produce a map of areas that have always been green, from ground-cover data alone**, then overlay the LiDAR structural map.

### 5.3 The new analytical frame — reference-state trajectory

Adrian proposes reframing the analysis as a **comparison between conserved and formerly-cropped paddocks**:

- The **pink paddocks** (farming always excluded) serve as the **reference state**.
- The **formerly cropped/grazed paddocks** were degraded over time.
- **The question:** since management changed (since the irrigation banks were cut), is the vegetation and condition of the formerly-cropped paddocks becoming *more like* the conserved paddocks over time? Are they on a **trajectory of improvement toward a reference state?**

This is a materially better question than "is there a trend?" because it has a built-in control and a defined target.

Related refinements:
- **Consider each site's land-use history.** If a site was previously irrigation storage, is there evidence it is being restored toward chenopod shrubland? **Are different past vegetation types being restored to the same, or different, end states?**
- **Focus the science article on individual paddocks where management history is known.** If logical water–vegetation–management patterns can be found at paddock scale, those learnings might generalise across the farm. *Whole-farm generalisation has so far been difficult* — this is an explicit acknowledgement that the paddock is the right unit for the causal story.

### 5.4 The template — Dawson et al. (2016)

Adrian named his paper with Sam Dawson as the model:

> Dawson, S.K.; **Fisher, A.**; Lucas, R.; Hutchinson, D.K.; Berney, P.; Keith, D.; Catford, J.A.; **Kingsford, R.T.** (2016). Remote sensing measures restoration successes, but canopy heights lag in restoring floodplain vegetation. *Remote Sensing* 8(7), 542. https://doi.org/10.3390/rs8070542

**Why it is the right template** (and it is a close fit):

- Same team lineage (Fisher, Kingsford), same basin, same problem — a **formerly cultivated floodplain wetland on a regulated river** (Pillicawarrina, Macquarie Marshes).
- **The design is exactly what Adrian is now proposing:** a chronosequence of fields at different land-use intensities (never cleared → chain cleared → bulldozed → cultivated 1 year → cultivated 3+ years → cultivated 12+ years), compared against **intact reference vegetation as a fixed restoration target**.
- **The metric is a similarity distance to reference**, not a trend: Euclidean distance between each restoring pixel's fractional-cover time series and the target community's. This is directly transferable to "are formerly-cropped paddocks converging on the pink paddocks?"
- **Its headline result is inundation-dependent restoration:** many fields showed little sign of similarity to target vegetation *until after inundation*, even where agricultural use had already ceased. **Inundation was crucial for restoration.**
- **Land-use intensity governed recovery.** Fields cleared or cultivated for one year recovered well; fields cultivated 3+ years recovered partially; fields cultivated >12 years showed few signs of recovery and may need to be managed toward a *different, drier* target community (black box grassland) rather than the original one.
- **It pairs Landsat FC with LiDAR canopy height models** — using structure to resolve what spectral data cannot. Canopy height *lagged* fractional-cover recovery. This is precisely the Landsat-cover-vs-structure problem we have been wrestling with, already solved once by the same group.
- It also standardised comparisons **against a moving target** — reference areas measured at the same dates, so drought and inundation affect both equally. Directly relevant to our climate-confound problem.

**Three cautions the paper itself supplies**, worth carrying over: it excluded flooded images because the FC algorithm doesn't apply to pixels containing surface water; it restricted to autumn/early-winter scenes to avoid phenological cycles; and its accuracy testing (15 sites) suggested a systematic bias — photosynthetic cover consistently overestimated, non-photosynthetic underestimated.

### 5.5 The audience problem — handle with care

Recorded plainly, because it shapes how results are framed:

- **Adrian is probably under pressure to find evidence that management since 2018 has had positive effects.**
- **We should therefore not discard the 2018 pre/post analysis** and may need to revisit it in more detail. Since 2018 Gayini has been wet — and probably wetter than before.
- **We need more time before we can definitively say management is having an effect.** Adrian was surprised we saw no effect at all.
- **We must craft results for the Gayini audience.** "No evidence, case closed" will not land well.
- **Adrian's own resolution:** potentially *subtle changes over time* — the paddock and reference-state ideas — are **more solid for telling logical stories than a simple pre/post analysis**.

This is not a request to manufacture a positive finding. It is a request to ask a better question than pre/post, one that has a real chance of detecting a genuine effect if one exists — and to report honestly within that better design.

---

## 6. Lining up the 24 July direction with our current findings

Where the new frame meets what we already have:

| Adrian's 24 July idea | What we already have | What's needed |
|---|---|---|
| Refugia ↔ LiDAR lignum swamp overlap | Census p05 floor surface (`veg_p05`, total cover at the floor); the **majority-green-floor** area — a *different* variable (green share of remaining cover, `green_at_floor` = `100 × PV ÷ total_veg > 50`), value + definition in `Output/tables/taskM_green_at_floor_area.csv`, not restated here; H6 flood-zone map | An "always green" map from ground cover alone; then spatial overlay with Adrian's LiDAR |
| Conserved (pink) vs formerly-cropped paddocks | Paddock dashboards with per-paddock census (6k–32k px); C1 checkerboards; flood + cover series per paddock | Paddock classification by management status; a Dawson-style distance-to-reference metric |
| Trajectory toward reference state | 35-yr per-pixel cover percentiles; per-paddock flood series | Time-series distance-to-reference, computed per period, per paddock |
| Site land-use history → restoration target | Site dashboards; census position vs community curve | Ernest's land-use attribute table (pending) |
| Paddock-scale story, then generalise | Paddock scatterplots showing the floor relationship replicates | Select the paddocks with known history; this is the article's spine |
| Don't discard 2018 pre/post | Existing pre/post bank-cuts analysis (suggestive, not causal; most difference explained by window wetness) | Reframe as one line of evidence inside the reference-state design, not the headline |

**The key reconciliation.** Our strongest current result — *the signal is in the floor* — is not in tension with Adrian's reference-state idea. It is the natural **metric** for it. Distance-to-reference computed on the **vegetation floor (p05)** rather than mean cover is likely to be far more sensitive to genuine recovery, because:

- the floor is where the flooding signal actually lives (p05 climbs ~45→78%; p50 is nearly flat);
- the floor is **harder to manufacture by a land-use switch** than mean cover — a cropped paddock can post high mean cover in a good year, but sustaining a high *worst-season* floor requires persistent perennial vegetation. That makes the floor metric *more* robust to the structure-vs-condition confound, not less.

That is the argument to make explicitly, and it is the bridge between our census result and Adrian's restoration framing.

**And the honest boundary stays.** Even in the reference-state design, we can show *convergence* without proving *causation* — the pink paddocks differ from cropped paddocks in more than management history (position on the floodplain, soil, inundation regime). Dawson et al. had the same limitation and handled it by being explicit about land-use intensity as the gradient and inundation as the enabling condition. We should do the same.

---

## 7. Immediate next steps arising

1. **Map "always green" areas from ground cover alone**, and overlay Adrian's LiDAR shrub-height model. Test the refugia/lignum-swamp hypothesis. *Highest value, most immediately testable.*
2. **Classify paddocks by management status** — conserved (pink) vs formerly cropped/grazed vs currently grazed — as the design variable.
3. **Prototype a Dawson-style distance-to-reference metric**, computed on the vegetation floor, per paddock, per period.
4. **Obtain Ernest's land-use attribute table** to give per-site history.
5. **Revisit the 2018 pre/post analysis** as a supporting line of evidence within the reference-state frame, not as the headline test.
6. **Select the article's paddocks** — those with the clearest known management history — and build the story there first.

## 8. Standing cautions to carry forward

- **Support discipline:** all-pixel results and plot-support results are never merged. Site markers on n≈1–17 census pixels are not reliable; paddock scale (6k–32k px) is where residual analysis has support.
- **~1M pixels are not independent n** (spatial and temporal autocorrelation). A narrow band is not certainty.
- **Landsat FC measures cover, not ecological condition.** The LiDAR overlap is our best route to addressing this, not a footnote that dismisses it.
- **Circularity:** CSIRO condition products derive from the same Landsat reflectance as our ground cover. Compare them against inundation, never against cover.
- **Mapped vs whole farm:** 67,349 ha mapped of 85,911 ha total. Do not rebase percentages between the two.
