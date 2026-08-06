# Methods document V11.2 → V12 — change list

**Baseline:** `Gayini_RS_methods_doc_V11_2.docx` **as manually edited at the design seat**, 5 August
2026.

| | |
|---|---|
| SHA-256 | `38922896942c4e1a861c39e550533e05af1142ee0e9afb7c9014e01fae1bb6b2` |
| Size | 10,597,696 bytes · 46 pages · 28 figures · 5 sections |

**This is the authority. It is not what `build_v11.py` emits.** That producer built V11.2 from V10;
layout edits were then made in Word and exist only in the file above. The V10 chain is closed —
see the superseded header on `Gayini_V10_to_V11_change_list.md`.

**Consequence, stated once.** The methods document does not currently regenerate from a script.
V12's producer operates on the baseline above rather than on V10, so the chain restarts here. Every
edit below is declared in this list; nothing is made by hand in Word without a row.

---

## Status key

`OPEN` · `APPLIED` · `BLOCKED` — waiting on a verification or a ruling

---

## A · Layout

| # | Change | Status |
|---|---|:--:|
| A1 | **p20 → portrait.** §8 opening and the dashboard panel table. Landscape, no figure. | OPEN |
| A2 | **p24 → portrait.** §9 opening and the five-step roadmap. Landscape, no figure. | OPEN |
| A3 | **p31 → portrait.** §10 opening and the Bala 29ca table. Landscape with two-thirds of the page empty below the table. | OPEN |
| A4 | **Figure 21 and its text on one page.** Figure on p32 carries 67 words; its five paragraphs are all on p33. Let the figure sit at the top and the text run beneath across the break, rather than forcing the whole passage after the image. Reducing the figure below 8.66 in gives back what the restack bought and is the second choice. | OPEN |
| A5 | **Figure 22 and its text on one page.** Same split across p34–35, same remedy. | OPEN |
| A6 | **Rule to apply throughout:** a page carrying no figure is portrait; a page carrying a figure wider than tall is landscape. Figures 21 and 22 are the standing exception and stay portrait. | OPEN |

## B · Structure

| # | Change | Status |
|---|---|:--:|
| B1 | **New §11 · Spatially structured vegetation response.** Text drafted at `Gayini_S11_spatial_structure_draft.md`. **BLOCKED on S11-VERIFY** — ten quantities come from an unregistered design-seat pilot and any that fail come out rather than get softened. | BLOCKED |
| B2 | **Renumber:** limitations → §12, implications → §13, positioning → §14. All cross-references move. | OPEN |
| B3 | **Figure 15 and Figure 16 into §1.** The study area section currently has no map; the first map is Figure 15 on p25, twenty pages after the property is described. Figures 1 and 2 are diagrams, not maps. | OPEN |
| B4 | **Bala 29ca table → paragraph.** Five rows of sentence fragments in two columns — an argument, not data. A reader should not parse a layout to follow a chain of reasoning. The §8 panel table stays tabular; it is genuinely a table. | OPEN |

## C · Figures

| # | Change | Status |
|---|---|:--:|
| C1 | **Cut Figures 9, 10, 13 and 27.** 28 → 24. Rationale and the full renumbering map in `Gayini_FIG2_necessity_audit_and_rebuild_spec.md`. **DECLINED — Ruling AL, 6 Aug 2026.** All 28 figures stay. The methods document is background for Adrian to understand the work and the client will not see it; on that basis the case for removing figures that are individually sound does not hold, and improving them is preferred to cutting them. FIG2's recommendation closes as declined, **not deferred.** | CLOSED — DECLINED |
| C2 | **Figure 26 y-axis furniture.** Row labels plus axis title still take too much width. Producer change, report stream. | OPEN |
| C3 | **New figure for §11** — three rows, Bala 27ca / Bala 29ca / Dinan 10, reusing the report stream's parts-page producer. Add a whole-paddock marker and each part's area share. **BLOCKED with B1.** | BLOCKED |
| **C4** | **Figure 20's caption is stale in one clause — carried to V14.** `M5b_paddock_residual_from_expectation.png` states *"There is deliberately NO part-grain version of this map: the expectation line is fitted across the 64 paddocks and **no part-grain fit has been registered**."* Three part-grain fits are now registered (`partreg_s1_slope_115parts`, `partreg_s2_slope_cropping_era`, `partreg_s2_slope_post_management`) and three part-grain residual maps exist (`figure_partreg_s2_residual_maps`). **The rest of the caption still holds** — in particular its warning that T13's `level_z` is a different quantity and must not be shown as a version of the same thing. **Ruling AQ, 6 Aug 2026: DO NOT EDIT.** The pack is sealed at v1.2 and the methods document at V13; this is recorded in the ledger for **V14** rather than corrected in place. Full finding: `docs/reference_update/Gayini_PARTREG_findings.md` §7.1. | **OPEN — V14** |
| **C5** | **`PACK1_zip.py` seals by tree glob — an ARMED TRAP, not a defect. Ruling AR, 6 Aug 2026.** Line 48 is `files = sorted(p for p in PACK.rglob("*") if p.is_file())`, so a re-seal takes whatever is in `Output/pack/` at the time. It now holds **`DATA/` (649 MB)**, **`PARTREG/` (56 MB)** and three undeclared root files — a methods draft matching neither V12 nor V13, a deck, and a PowerPoint lock file. A v1.3 would ship ≈720 MB against v1.2's 4.35 MB, including a stale document and a lock file. **Nothing is currently wrong: v1.2 is sealed at `71ae2464f0464cb5…` and untouched, and the trap only fires on a re-seal nobody has asked for.** **DO NOT FIX NOW** — changing a sealing script three days from the deadline, on a pack already delivered, is the wrong trade. **Post-deadline the fix is that the script takes an explicit item list rather than globbing the tree**, which is also what makes the seal reproducible. *(Tooling, not document content; recorded here on design-seat instruction so it sits beside C4 rather than only in a findings note.)* | **OPEN — post-deadline** |

## D · Caption collapse

| # | Change | Status |
|---|---|:--:|
| D1 | **One paragraph per figure.** Numbered caption becomes the bold lead-in; the separate explanatory paragraphs merge into it. Drafted and agreed for **Figures 7, 10 and 26**. | OPEN |
| D2 | **Apply to all 28 figures.** C1 is declined under Ruling AL, so every figure survives and there is no surviving-subset to wait for. **The caption collapse no longer waits on anything.** About 40% of current figure prose comes out, roughly a third of it relocating rather than disappearing. Carries [[I-55]] and [[I-56]]: per-caption `number_id` contracts are the same edit as rewriting the captions, so identity resolution and the collapse are one pass. | OPEN |
| D3 | **Where the removed material goes:** robustness checks → the methods subsection defining the criterion; numbers now legible on the figure → deleted; statements of which conclusion a figure supports → the through-line; lineage of a quantity used elsewhere → its first definition, referenced once. | OPEN |

## E · Through-line

| # | Change | Status |
|---|---|:--:|
| E1 | **A front-matter statement of the argument**, six sentences, after the verification status. The document currently states its through-line once, on p42, inside a section headed "This section is a draft for discussion". | OPEN |
| E2 | **§13.1 becomes the closing restatement of the same six.** Bookends. | OPEN |
| E3 | **Reconcile with the pack's through-line.** The pack and the deliverables register carry seven claims; the methods document carries three findings. Neither points at the other and Adrian holds both. | OPEN |
| E4 | **Questions appendix.** `Gayini_questions_draft.docx` before §14, reframed from named individuals to *the questions this assessment raised and who can answer them*. Replaces §13.2's gap table, which states what is missing without stating what would settle it. | OPEN |

---

## Carried, not scheduled

- The caption sweep in `build_v11.py` is still valid as a check and should be re-pointed at the new
  baseline. It runs on built XML and does not care what produced it.
- Eight `VERIFY` markers remain in the baseline, all pre-existing and declared in the front matter.
- Figure 10's two percentages have no producer and no `number_id`. If C1 is ruled, this resolves by
  removal.

---

## Completion

> **V12 SHA-256:** _not yet built_

Recorded here on build. **The baseline hash above and this hash are the only two points at which
this document's identity is fixed; between them it exists only as this list.**
