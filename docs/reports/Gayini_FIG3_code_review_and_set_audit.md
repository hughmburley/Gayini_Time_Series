# FIG3 — reference-state figures: code review and set coherence

**Design seat · 4 August 2026 · against V11**
`019b32126e4d28956979d92f31430f6fef329ea2a6efbb257926219d60ce7f1f`

V11 changed the text and none of the images. **Part A** is a spec for CC to review the producing
code. **Part B** is the design seat's audit of how the fourteen reference-state figures work as a
set — done here, because it needs the argument rather than the code.

---

# Part A · CC spec — review the producers, propose, change nothing

**Read-only.** Standing conditions of DOC-3 §0 apply: `mode=ro`, no registry write, no re-render,
no producer edit. **Report and stop.**

## Scope

Figures 15–28 of V11 and their producers. Named where known:

| Fig | Producer |
|:--:|---|
| 21, 22 | `scripts/12_zone_stratum/T2_gateE_figures.R` |
| 26, 27 | `scripts/12_zone_stratum/T6_gateE_figures.R` |
| 17, 18 | T13 D1 / D2 producers |
| 23 | to be identified — a different generation from the rest |
| 15, 16, 19, 20, 24, 25, 28 | to be identified |

## What to report, per figure

1. **Producer, entry point and registered title.** Whether the title is a registered string, since a
   title change then moves a registry row.
2. **What the code computes versus what it draws.** Any quantity computed and discarded, or drawn
   from a source other than the one the caption declares.
3. **Hard constraints.** Device size, DPI, facet mechanism, anything set at the helper default
   rather than the call site.
4. **What is cheap and what is expensive.** Split proposals into: label and vocabulary only; layout
   within the same computation; and requiring recomputation. **The third category is almost
   certainly out of scope before 10 August, and saying so is a useful answer.**
5. **Whether the figure can carry its own result.** Several of these figures have their key numbers
   reported in the document's prose because the in-figure labels are too small to read. Report where
   that is a device-size problem and where it is a design problem.

## Specific questions

- **Figure 23** is a generation ahead of the others — plain-language title, "conserved", explanation
  in the caption. **Identify its producer and report what would be required to bring 21, 22 and 26
  to the same pattern.** If it shares helpers with the others, say which.
- **Figure 24** draws early and late window means. Report the window definitions as coded, and
  whether an annual-series equivalent exists or could be produced without recomputation. See Part B,
  finding 1.
- **Figure 26's** nine adjusted values are currently legible only in the document's prose. Report
  what device width would make the in-panel labels readable at the placed size.
- Report every figure in which **Bala 29ca is drawn without visual distinction from the other three
  conserved paddocks**, and whether the producer has a mechanism to distinguish it.
- Report which producers share helper functions, so a common change is costed once rather than
  per figure.

**Do not propose a preferred option.** Report what each would cost and let the design seat choose.

---

# Part B · Design-seat audit of the set

## Finding 1 — Figure 24 uses a method the project has ruled out · **priority**

Figure 24 draws *"change in the conserved-to-grazed gap between early (to 1997) and late (from
2013) windows."* That is a **period-boundary statistic**.

The report stream's standing rules, applied to the report batch on 4 August, include: **"No
period-boundary statistics. Annual series only."** The reason recorded there is exact — period
means made a 12-point annual swing look like a tidy 1.8-point gap, which is why PIN 3 was
abandoned and never registered. The report batch had *"first ten vs last ten: 33.7 → 52.4"*
removed for the same reason.

**Figure 24 is that method, in the methods document and in the delivery pack as item F4.**

There is a second problem stacked on it. Figure 23 establishes that the gap is *not changing* once
Bala 29ca is excluded — +0.057 pp/yr, r = 0.22, crossing zero. **Figure 24 then decomposes the
change in a gap the previous page says is not moving.** What it actually decomposes is Bala 29ca,
which Figure 23 has just separated out for that reason.

**Options, in order of preference:**

- **Cut F4 from the pack and Figure 24 from the document.** It supports no claim that Figures 23 and
  25 do not support better, and it uses a barred method.
- **Keep it and state the tension** — that the windows are a decomposition device rather than a
  trend statistic, that the change decomposed is Bala 29ca's, and that the project does not use
  period boundaries elsewhere. Three sentences, and weaker.

**This needs a ruling before the pack ships**, because F4 is a pack item and the pack's own
standing rules are what it contradicts.

## Finding 2 — the set's strongest claim is unstated

Three figures test one hypothesis at three different units:

| Fig | Unit | Answer |
|:--:|---|---|
| 21 | paddock-community part | conserved parts sit inside the grazed band except Bala 29ca's |
| 23 | whole paddock | the gap is flat and crosses zero |
| 26 | arm × wetness stratum | the arms do not order, and run backwards |

**They agree. Nothing in the document says so.**

On a project whose most expensive lesson is L-01 — that the unit of analysis changes the answer —
a conclusion that survives three changes of unit is the most persuasive result in the section.
Currently the three figures sit five pages apart and a reader has to notice it unaided.

**Recommendation: one paragraph at the head of §10**, after the Bala 29ca table: the same question
is asked at three units and returns the same answer, and that stability is the finding rather than
any one of the three. **Cheap, text-only, and it is the section's best sentence.**

## Finding 3 — the metric control is shown twice and omitted twice

Figure 22 is the mean-cover control for Figure 21. Figure 27 is the mean-cover control for Figure
26. Figures 23 and 25 have no control and the document does not say why.

Making the same methodological point twice, five pages apart, is redundancy. Making it for two of
four figures without stating the rule is arbitrary.

**Recommendation: keep Figure 22, cut Figure 27** — as already proposed in FIG2 — **and state the
rule once**: the control is drawn at part grain, and the mean-cover values for the three-arm
comparison are reported in the Figure 26 text rather than drawn.

## Finding 4 — Bala 29ca is everywhere and distinguished nowhere

Bala 29ca appears in Figures 17, 19, 20, 21, 22, 23, 25, 26 and 28. **Only Figure 23 separates it
visually.** Everywhere else it is one of four conserved paddocks in the same palette weight.

The section's whole argument is that one of the four carries the result. **The figures currently
argue the opposite by drawing them alike.**

**Recommendation: one visual convention across the set** — Bala 29ca heavier and fully saturated,
the other three lighter in one family. This is the highest-value change per unit of effort in the
figure work, it is a palette change rather than a recomputation, and it makes the section's central
point visible rather than asserted.

## Finding 5 — §9 and §10 are split by how figures are drawn, not by what they show

The document says this outright: *"Sections 9 and 10 divide the figures by how they are drawn
rather than by what they show. That division is one of convenience and carries no argument."*

That is a confession rather than a fix, and it appears immediately after a roadmap that lists the
argument in a different order from the figures.

**Recommendation, in order of cost:**

- **Cheapest:** delete the confession and retitle — §9 *"Where the units are and how they differ"*,
  §10 *"Whether management can be distinguished"*. The existing figure order fits those two headings
  better than it fits maps-versus-figures.
- **Better, if time allows:** reorder to the roadmap's five steps.

## Finding 6 — the figures do not carry their own results

Figure 26's nine adjusted differences are legible only in V11's prose. Figure 21's line shares —
Bala 26ca's Riverine portion at 1.9% — are stated in text because they are not on the figure. In
both cases the document is compensating for a figure that cannot be read at its placed size.

A figure reproduced outside this document loses its result. §1's note on figures claims the
opposite: that in-figure annotation exists *"so that a figure remains self-explanatory if reproduced
outside this document."* **For Figure 26 that claim is currently false.**

## Finding 7 — nothing shows the post-management period

The question managers care about is what changed after 2019. §11.2 explains why it cannot be
answered. **No figure in §9 or §10 shows the four post-management years at all** — the only figure
that marks the window is Figure 3, forty pages earlier.

**Recommendation: a forward pointer, not a new figure.** One sentence in §10 sending the reader to
Figure 3 and §11.2. Six days out, a new figure here would be the wrong call.

---

## Priority

| | Change | Cost | Where |
|:--:|---|---|---|
| 1 | **Rule on Figure 24 / pack item F4** | ruling | blocks the pack |
| 2 | Bala 29ca visual convention across the set | palette, one pass | producers |
| 3 | Three-units-one-answer paragraph at §10 head | one paragraph | V11.1 |
| 4 | Retitle §9 and §10, delete the confession | two headings, one deletion | V11.1 |
| 5 | Cut Figure 27, state the control rule | text + cut | V11.1 |
| 6 | Forward pointer to Figure 3 and §11.2 | one sentence | V11.1 |
| 7 | Figure 26 legibility | device width | producers |

**Items 3, 4, 5 and 6 are text and can go into V11.1 tonight without touching a producer.** Items 2
and 7 are the figure work. Item 1 is a decision.
