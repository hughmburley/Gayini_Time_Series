# DOC-2 Gate B — the reference-state material as a body

**Read-only.** 4 August 2026 · `Gayini_RS_methods_doc_V8.docx`, SHA-256 `d4b95bd9…56b7`.
Scope: §6.1–6.4 and the whole of Sections 9 and 10 — 12 figures, roughly 2,300 words.

---

## B1 · Does it read as a connected argument?

**No. The argument is present, correct, and split across the document with its middle missing.**

The sequence is made in exactly two places, and neither is where the evidence sits.

**Step 1 and step 2 are in §6.1 — a methods section.** The opening two sentences do the whole job:

> *"Comparing paddocks directly on cover confounds management with hydrological position. Three of the four
> ungrazed paddocks rank 3rd, 6th and 31st of 64 on flood frequency while the fourth ranks 61st, so a direct
> comparison would substantially measure landscape position."*

That is the entire case for abandoning the obvious comparison and replacing it with a hydrological
expectation — and it is stated once, in a section headed *"The expectation line, and what a residual is"*,
which a reader looking for findings will skip.

**Step 3 is in §12.1 — an implications section**, six sections later:

> *"Management category does not order the results, while geography does."*

**Between them, Sections 9 and 10 carry the evidence and carry no argument at all.**

### The connective tissue is measurably absent

Words of orienting text between a section heading and its first figure:

| section | words |
|---|---:|
| 7 · Census results | 45 |
| 8 · Unit dashboards | 164 |
| **9 · Management-unit analysis: maps** | **0** |
| **10 · Management-unit analysis: figures** | **0** |
| 12 · Implications and next steps | 35 |

**Sections 9 and 10 open with a heading and go straight to Figure 14 and Figure 19.** They are the largest
body of evidence in the document and the only two sections that tell the reader nothing before showing them
something.

### The figures do argue — individually

This is not a weak body of work. Several figure texts are models of the form:

- **F2 / Figure 20** — *"A control rather than a result… The signal visible in Figure 19 is absent."*
- **M5 / Figure 17** — *"The two rows resemble one another closely — inundation organises cover more
  strongly than any management boundary. The two columns do not."*
- **T1 / Figure 25** — *"The four do not constitute a usable reference set"*, with a design note explaining
  that no average is shown **because averaging them is the specific error the table exists to prevent.**

Each is a step in the sequence. **Nothing in the document says they are steps, or in what order, or what
they add up to.** A reader assembles the argument or does not, and most will not.

### Three structural faults behind it

**1 · The sections are divided by how the evidence is drawn, not by what it shows.** "Management-unit
analysis: **maps**" and "Management-unit analysis: **figures**" — maps *are* figures, and the reader cannot
infer from either heading what the section is for. The split is a rendering distinction serving the build,
not the reader. It is also why neither section can carry an argument: there is no claim that "the maps"
jointly establish.

**2 · The reader meets residuals five figures before they meet the line.** Figure 18 (M5b) maps every
paddock's departure from the expectation line. Figure 23 (F5) is the expectation line — the scatter, the
fit, the band. **The map of departures precedes the thing they depart from.** §6.1 defines the concept, but
the figure that makes it visible arrives after the figure that assumes it.

**3 · The decisive finding is filed as a caveat.** F1 / Figure 19's limitation note reads:

> *"The improvement in Bala 29ca begins approximately thirty years before conservation management commenced."*

That single sentence is what forecloses attributing the reference-state signal to grazing exclusion. It is
the most consequential statement in Sections 9 and 10, and it appears in a limitation paragraph beneath a
figure, in the same register as *"cultivation history is unavailable"*.

### What would fix it

**Two paragraphs, one at the head of Section 9 and one at the head of Section 10**, saying what the section
is about to demonstrate and how it follows from the last. Nothing else in this gate is as cheap or as
high-yield: the argument already exists, correct and complete, in §6.1 and §12.1. It simply never travels
with the evidence.

---

## B2 · Registered figures that would explain an existing claim better

**Four candidates.** All are registered, `superseded_flag = 0`, path exists, and all serve claims the
document already makes. **Nothing was substituted.**

### 1 · `T3_B_area_vs_threshold.png` — for §7.5's threshold-dependence claim · **strongest**

**Claim served:** *"A sweep across candidate thresholds found no natural break, plateau or bimodality in
either surface — the qualifying area declines smoothly… Around the operational cut a ±5 percentage point
shift changes the total-cover area by a factor of three: 12,641 ha at 70, 8,300 ha at 75, 4,179 ha at 80."*

**Currently:** three numbers in prose, no figure.

**Why it explains better:** the claim is about the *shape of a curve* — that it has no knee — and a reader
cannot verify the absence of a break from three points on it. The registered figure is that sweep. This is
the clearest case in the document of a visual claim carried by prose. Its registered caption also already
carries the warning that this is not the green-share floor.

### 2 · `T13_D2_part_state_map_sensitivity.png` — for M4/F7's nesting claim

**Claim served:** *"Between three and fifteen parts meet the recovering criterion depending on the cut, and
it is the same parts throughout."*

**Why it explains better:** "the same parts throughout" is a nesting claim, and the registered caption states
the property precisely — *"The recovering set is strictly nested across the full 0.50–1.50 sweep — parts
enter and leave as the cut moves but are never swapped, so the cut governs how many parts are called
recovering, not which."* The figure demonstrates what the text asserts.

### 3 · `D1_paddock_Dinan_10_slide_data.png` — for M5b's twin argument

**Claim served:** *"Dinan 10 is Bala 29ca's hydrological twin — a grazed paddock of closely comparable flood
frequency and comparable shortfall — indicating that Bala 29ca's departure is not unique to its management
status."*

**Why it explains better:** this is the single most load-bearing inference in the reference-state material —
it is what prevents Bala 29ca's shortfall being read as a grazing result — and it is carried entirely by one
sentence. The Dinan 10 dashboard is already rendered and registered, in the same layout as Figures 11 and 12.

**Reported, not recommended.** It would either sit alongside Figure 12 or replace it, and replacing it loses
the wet-versus-dry contrast Figure 12 exists to make. That trade is a design-seat call.

### 4 · `S_veg_water_gam_p05.png` — for §6.6's GAM description · **weakest, with a caveat**

**Claim served:** §6.6 describes the GAM, its basis, its band and what the band does and does not mean —
across 401 words with no figure. The reader first sees a GAM curve inside a dashboard panel in Figure 11.

**Caveat that disqualifies it as-is:** the registry row carries **no caption and `support_level` is NULL**.
It would need both before use, and populating them is a registry write and out of scope here.

### One near-miss worth recording so it is not repeated

**`T3_A1_two_metrics.png`** — "the two floor metrics side by side with their full definitions" — looks like
the figure §4.4 lacks. **It is not.** Its registered caption shows the **green-share floor against the
total-cover floor**, which is §7.5's distinction, not §4.4's spatial-versus-temporal pair. The two
"two floors" pairs in this project are different pairs, and matching this figure to §4.4 by its title would
have put the wrong figure under the section DOC-1 called the most-confused pair of numbers in the project.

**Named in one line, not developed:** §4.4's spatial-versus-temporal floor pair has **no registered figure
anywhere**, and it is the pair the document says must never be conflated.

### Registration status of the current 25, re-checked against v8

**15 of v8's 25 embedded images are byte-identical to a registered asset** — the same 15 as v6.
`M1_veg_percentile_maps_p05_p50.png` is **not** among them, so DOC-1 Gate D's recommended swap for Figure 8
either has not been applied or was applied with resampling. **Which cannot be determined without a v8 figure
manifest**, and I have not assumed either way.

---

## B3 · Explanation quality, and the three that would gain most

Most reference-state figures are well served by their text. Figures 17, 20 and 25 are the strongest —
each states the pattern and what it means, not the axes.

### 1 · Figure 23 (F5) — the expectation line itself

**The hinge of the entire argument, explained in 97 words**, and placed five figures after the map of
departures from it. Its text — *"Cover follows water across the property, r = 0.71. Ungrazed paddocks are
not systematically displaced from the line"* — states the result correctly and does not tell the reader that
this line is the instrument every residual in Sections 9 and 10 is measured against. **Everything else in
the reference-state material is downstream of this figure and the text does not say so.**

### 2 · Figure 19 (F1) — where the decisive finding is filed as a caveat

The interpretation describes what is visible; the limitation note carries *"The improvement in Bala 29ca
begins approximately thirty years before conservation management commenced."* **That is the finding, not a
limitation of it.** A reader who skims limitation notes — which is what limitation notes invite — will miss
the sentence that forecloses the grazing-exclusion reading.

### 3 · Figure 22 (F4) — readable as its own opposite

The sign convention for "gap" is stated under **Figure 21** and not repeated here, so this text reads:
*"the gap change of +8.4 percentage points"* … *"Panel B shows the narrowing"*. A positive change and a
narrowing are the same thing only if the reader remembers the gap is negative — mean −2.07 pp, stated one
figure earlier. **Without that, the paragraph appears to contradict itself in consecutive sentences.**

---

## Summary

**B1 — the argument does not travel with the evidence.** It is made in §6.1 and concluded in §12.1; Sections
9 and 10 hold twelve figures and **zero words** of orienting text. Two paragraphs would close it. The
sections are also split by rendering type rather than by claim, the reader meets residuals before the line
they come from, and the finding that forecloses the grazing attribution sits in a limitation note.

**B2 — four registered figures would explain existing claims better**, one strongly
(`T3_B_area_vs_threshold` for a claim about a curve's shape currently carried by three numbers). One
near-miss recorded. §4.4 has no figure and no registered candidate exists.

**B3 — Figures 23, 19 and 22** are where better explanation gains most: the hinge figure under-explained,
the decisive finding filed as a caveat, and a paragraph that reads as its own opposite.
