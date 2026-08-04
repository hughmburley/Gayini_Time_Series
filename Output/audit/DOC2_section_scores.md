# DOC-2 Gate A — section scores

**Read-only.** 4 August 2026 · `Gayini_RS_methods_doc_V8.docx`, SHA-256 `d4b95bd9…56b7` ·
62 headings · 8,621 words.

**Scored against the stated reader:** clever, engaged, not across the details — a land manager, a trust
officer, a scientist from another field. Accuracy and expression are scored **independently**.

**§7.3 is scored as it stands**, not as it will read after the queued seasonal-reduction correction.

---

## The headline: this is an accurate document with six correctable expression faults

**Accuracy is high and mostly earned.** Every DOC-1 finding that could be applied has been applied, and
applied precisely — the ddof conventions, the pixel-weighting behind 51.1, the "of 118" denominator, the
farm-boundary footprint behind 3.03%, both Figure 10 drawing caveats, the plot-versus-census support split,
and all three method descriptions found simpler than their implementations. **§6.5 and §6.6 now describe
their code correctly, including the coverage gate and the second truncation rule.** The front-matter
verification status is exemplary practice: it states 127 claims unchecked and that nothing establishes there
is no further contradiction.

**Two accuracy defects survive, and both are internal contradictions rather than errors against source** —
the document disagreeing with itself, which is exactly the class DOC-1 did not look for.

**Six sections diverge by two or more points.** Those are the highest-value corrections available: they need
an editor, not an analyst.

---

## Scores

**A** = accuracy /5 · **E** = expression /5 · **Δ** flags a divergence of 2 or more.

| § | Section | A | E | Δ | What would raise the low score |
|---|---|:--:|:--:|:--:|---|
| — | Front matter / verification status | 5 | 5 | | |
| 1 | Study area and scope | 5 | 5 | | |
| 2 | Data sources | 4 | 4 | | Two resampling methods are named without saying why they differ; a reader cannot tell that the choice is dictated by whether a surface is continuous or categorical |
| 3 | The analytical substrate | 5 | 5 | | |
| 3.1 | Stratification | 5 | 4 | | "Within-community terciles" carries the section's key caveat but "tercile" is never glossed as thirds |
| 4.1 | Ground cover | 5 | 5 | | |
| 4.2 | Inundation | 5 | 5 | | |
| 4.3 | Percentiles | 5 | 5 | | The best-written section in the document for this reader |
| 4.4 | The two floors | 5 | 4 | | Bala 29ca arrives as a worked example with no statement of why that paddock is the one used |
| 4.5 | Support | 4 | 4 | | Accuracy: the plot row reads **1988–2026** where every other row reads 1988–2023 — unexplained, and 2026 is the current year. Expression: "118 (115 **supported**)" uses *supported* in a second sense inside the section that defines *support* |
| 5 | Why the floor rather than the mean | 5 | 5 | | |
| 6 | Statistical methods (intro) | 5 | 5 | | |
| 6.1 | The expectation line, and what a residual is | 5 | 4 | | "(ddof = 0)" is meaningless to this reader and buys nothing where it sits; residual SD and residual standard error both appear without being distinguished |
| 6.2 | Trends over time | 4 | 4 | | The +0.556 worked example is silently Bala 29ca's actual adjusted trend, which §6.3 then reports as a result; the same number does two jobs without signalling |
| **6.3** | **Water-adjusted trend** | **5** | **3** | **Δ2** | **"Residual" means a different object here than in §6.1** — there, a paddock's departure from the property-wide line; here, a year's deviation within one unit's own water fit. The text never distinguishes them, and §6.1 has just spent 420 words teaching the first meaning |
| 6.4 | Community-scaled scores | 5 | 4 | | "Pre-registered" is load-bearing — it is what makes the ±1.0 cut credible — and is never explained |
| 6.5 | Same-year response | 3 | 4 | | **A VERIFY flag states the sign-consistency proportion "is not stated here" two paragraphs after the section states it is 0.70.** The flag is false about its own document |
| **6.6** | **Smoothed response curves and descriptive tests** | **5** | **3** | **Δ2** | The closing paragraph describes a second truncation rule belonging to a figure it then says **does not appear in this document**; the reader is given a rule for something they will never see, and cannot tell why |
| 7 | Census results (intro) | 5 | 5 | | |
| 7.1 | Flooding is variable, episodic, and not trending | 5 | 4 | | "None non-stationary" carries a verdict and the term is defined nowhere in the document |
| **7.2** | **Flooding sets the drought floor** | **2** | **4** | **Δ2** | **The Figure 6 caption says "bins containing fewer than 500 cells are dropped" — per-bin exclusion — while the body two paragraphs below correctly describes cumulative truncation.** The caption states the rule DOC-1 established was wrong |
| 7.3 | Response consistency varies along the gradient | 4 | 5 | | Accuracy: the count is right but does not name which seasonal reduction it belongs to (correction already queued). Expression is exemplary — the plot/census disagreement is explained rather than hidden |
| **7.4** | **Where cover persists** | **5** | **2** | **Δ3** | **A sentence is broken:** *"the difference between the panels is the difference between the panels indicates where cover falls furthest in poor seasons."* A duplicated clause has made it ungrammatical |
| 7.5 | Retained cover and living cover are different quantities | 5 | 4 | | At 624 words the longest section, doing three jobs — green share, the overlay, threshold dependence — with no signal to the reader when it moves between them |
| 8 | Unit dashboards | 5 | 5 | | |
| 8.1 | Paddock dashboards | 5 | 5 | | |
| 8.2 | Site dashboards | 5 | 5 | | |
| 9·M1 | Management zones and grazing treatment | 5 | 5 | | |
| 9·M2 | Monitoring network against management zones | 5 | 5 | | |
| 9·M4/F7 | Paddock parts by state | 5 | 4 | | The caption stacks two derived quantities — community-scaled level and water-adjusted trend — that the reader meets cold |
| 9·M5 | Cover and water at two grains | 5 | 5 | | |
| 9·M5b | Departure from hydrological expectation | 5 | 5 | | The limitation paragraph is a model of the form |
| 10·F1 | Paddock floor trajectories | 5 | 5 | | |
| 10·F2 | The same record on mean cover | 5 | 5 | | |
| 10·F3 | Annual gap to grazed country | 5 | 4 | | The nomenclature note is essential and arrives after the reader has met "three-paddock series" twice |
| 10·F4 | Decomposition of gap change | 4 | 3 | | The sign convention for "gap" is stated in F3 but not here, so *"the gap change of +8.4 percentage points"* followed by *"the narrowing"* reads as a contradiction unless the reader recalls the gap is negative |
| 10·F5 | Cover floor against flood frequency | 5 | 5 | | |
| 10·F6 | Three-arm comparison within strata | 5 | 4 | | "Inferred-standard arm" and "plot-confirmed subset" are used before either is defined |
| 10·T1 | The four ungrazed paddocks compared | 5 | 5 | | The design note explaining the deliberate omission is excellent |
| T2 | Part classification, full listing | 5 | 5 | | |
| **T3** | **Statement of limitations** | **5** | **2** | **Δ3** | **A listed deliverable whose status is "In preparation"** in a document being circulated; the reader cannot tell whether something is missing or forthcoming, and the entry points at Section 11 as its "current content" |
| 11.1 | Description and attribution | 5 | 5 | | |
| 11.2 | The management–water chain | 5 | 5 | | |
| 11.3 | Absent data | 5 | 5 | | |
| 11.4 | Measurement constraints | 5 | 5 | | |
| 11.5 | Design constraints | 5 | 5 | | |
| 12.1 | What the results imply | 5 | 5 | | |
| 12.2 | Gaps in order of consequence | 5 | 5 | | |
| 12.3 | Next steps | 4 | 5 | | The LiDAR bullet predates the reference-state stream's handoff and its supporting review; not re-audited here |
| **13** | **Positioning** | **3** | **5** | **Δ2** | **The section's whole argument rests on "the regional flow-decline literature", which is listed in "Required and not yet sourced".** Well written, and currently unsupported |
| R1 | References · Data products | 4 | 5 | | Product identifiers absent; correctly flagged |
| R2 | References · Regional context | 5 | 5 | | |
| R3 | References · Vegetation and grazing | 5 | 5 | | |
| R4 | References · Required and not yet sourced | 5 | 5 | | Honest and specific; names what each missing source supports |
| R5 | References · Software | 3 | 4 | | No version is given for anything, including **mgcv**, which §6.6 names as the fitting engine for every dashboard curve |

**Means: accuracy 4.7 · expression 4.5.**

---

## The six divergent sections, in priority order

These are correctable without touching the analysis. Four are pure editing.

### 1 · §7.4 — A5 E2 — a broken sentence (Δ3)

> *"Plotted on a shared scale, the difference between the panels is the difference between the panels
> indicates where cover falls furthest in poor seasons."*

A duplicated clause. **This is a build artefact, not an authoring error** — which matters, because it means
the generator can emit ungrammatical output and nothing catches it. Worth a check over the other generated
paragraphs before v9.

### 2 · T3 — A5 E2 — a deliverable marked "In preparation" (Δ3)

The Tables section lists T3 with *"Status. In preparation."* Nothing is inaccurate. But a reader reaching a
listed table and finding it absent cannot tell whether it was omitted, forgotten, or is coming. Either the
entry states plainly that Section 11 **is** the statement of limitations for this version, or it comes out.

### 3 · §7.2 — A2 E4 — the caption contradicts the body (Δ2)

Figure 6's caption: *"Bins containing fewer than 500 cells are dropped."* The body, two paragraphs later:
*"Bins are retained only up to the first bin containing fewer than 500 community cells; every bin beyond
that point is discarded."* **These are different rules**, and the caption states the permissive one that
DOC-1 established the code does not implement. The correction reached §6.6 and the §7.2 body but not the
caption. **This is the only accuracy score below 4 that is an error rather than an absence.**

### 4 · §6.3 — A5 E3 — "residual" means two different things (Δ2)

§6.1 spends 420 words establishing that a residual is a paddock's departure from the property-wide
expectation line. §6.3 then uses "the residuals from stage 1" to mean a year's deviation within a single
unit's own water fit. Both are correct; the reader has no way to know they are different objects. One clause
distinguishing them would fix it.

### 5 · §6.6 — A5 E3 — a rule for a figure the reader will never see (Δ2)

The closing paragraph describes a second truncation rule, then says *"Neither of those figures appears in
this document."* The passage exists because DOC-1 found the two rules conflated, and it is right that the
distinction be recorded — but as written it reads to this reader as an unexplained digression. Stating **why**
it is there (that a related figure elsewhere in the project uses a different rule and the two must not be
confused) converts a digression into a warning.

### 6 · §13 — A3 E5 — the best-written section rests on an unsourced citation (Δ2)

Positioning is the section a reviewer will read first and the one that places the whole assessment. Its
argument — that no trend inside the window is *consistent with* regional decline predating it — depends
entirely on the flow-decline literature, which is listed as not yet sourced. **The prose is doing work the
citations do not yet support.** This is the divergence with the shortest path to closure: one reference.

---

## Two patterns worth naming

**Every accuracy defect found at this gate is the document disagreeing with itself**, not with source: the
§7.2 caption against its own body, and §6.5's VERIFY flag against its own text. DOC-1 verified claims
against code individually and would not have caught either. That is the case for Gate C's consistency
sweep, and it is where I would spend the remaining checking effort.

**Expression fails hardest exactly where the analysis is most careful.** §6.3, §6.6 and §7.5 score lowest on
expression and 5 on accuracy — they are the sections where the most methodological care was taken, and the
care is what makes them dense. The fix is never to simplify the method; it is to say in one plain sentence
what the method does before saying precisely what it is. §4.3 already does this and is the model.
