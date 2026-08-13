# DOC-2 — Section review, scoring, and reference-state assessment

**Type:** READ-ONLY. No edits to the document. No new analyses. No registry writes.
**Input:** the current methods document in `docs/reports/` (v8 at the time of writing). Record filename, size, modified time and SHA-256 in the Gate 0 output.
**Outputs:** `Output/audit/DOC2_section_scores.md`, `Output/audit/DOC2_review.md`, and an updated `DOC1_claim_check.csv`.
**Re-read this spec in full and echo the current gate verbatim before starting it.**

---

## Why this exists, and why you are not editing the document

DOC-1 verified claims against code. This task asks a different question: **is each section accurate, and is it well expressed for its reader?**

**The document is generated from a build script held at the design seat, not hand-authored.** Any edit made directly to the `.docx` would be overwritten on the next rebuild with no record of what was lost. Report findings; corrections are applied at the design seat and appear in the next version.

The remaining work before delivery is refinement, explanation and cross-checking. Not new analysis. If a finding would require new analysis to act on, name it in one line and move on.

---

## The reader

Write your assessment against this reader: **clever, engaged, and not across the details.** A land manager, a conservation trust officer, a scientist from another field. Not a remote-sensing specialist and not a statistician.

That reader should be able to follow what was measured, why it was measured that way, and what it does and does not support — without looking anything up. Where a section fails that test, say how, specifically.

---

## Gate 0 · The VERIFY sweep · **STOP**

Locate every passage marked **VERIFY** in the current document. For each:

| Field | Content |
|---|---|
| Section | Where it sits |
| Text | The flag verbatim |
| Status | CLOSED, CLOSEABLE, or OPEN |
| Evidence | What settles it, or what would |
| Effort | If closeable, what closing it takes |

**CLOSED** — already answered by earlier work and the flag should be removed.
**CLOSEABLE** — answerable from the repository or database within this task.
**OPEN** — requires something outside the repository: provider metadata, a citation, new analysis, or a decision.

Close every CLOSEABLE flag in this gate. **Do not attempt the OPEN ones.** Two were established at DOC-1 as unclosable without new work — the regression diagnostics and the unsourced citations — and re-litigating them wastes the gate.

**Re-establish the inventory rather than inheriting DOC-1's.** Corrections have added and removed flags since. A count differing from expectation is itself a finding.

**STOP.**

---

## Gate A · Score every section · **STOP**

Produce `DOC2_section_scores.md`: one row per numbered section and subsection, scored on two independent axes.

### Accuracy, out of 5

| Score | Meaning |
|---|---|
| **5** | Every claim verified against source; nothing unsupported |
| **4** | Verified, with one minor unstated convention or imprecision |
| **3** | Substantially supported; contains at least one claim that cannot be verified from available sources |
| **2** | Contains a claim that overstates what the evidence supports |
| **1** | Contains a claim contradicted by source |

### Expression, out of 5

Scored against the reader above.

| Score | Meaning |
|---|---|
| **5** | Clear on first reading; a non-specialist could restate it correctly |
| **4** | Clear, with one term or step that assumes knowledge not supplied |
| **3** | Followable but requires re-reading, or leans on jargon where plain wording exists |
| **2** | Likely to be misread, or states a conclusion the text does not support in plain terms |
| **1** | Not comprehensible to the stated reader |

**Score the two independently.** A section can be entirely accurate and poorly expressed, and that combination is the most useful thing this gate can find — it is correctable without touching the analysis.

For every score below 4 on either axis, give **one sentence** on what would raise it. Not a rewrite. A diagnosis.

Add a column flagging any section where the two scores differ by 2 or more. Those are the highest-value corrections available in the remaining time.

**STOP** for review before Gate B.

---

## Gate B · The reference-state material

The reference-state analysis is the document's largest single body of work: Sections 6.1, 6.2, 6.3, 6.4 and the whole of Sections 9 and 10. Assess it as a body rather than figure by figure.

### B1 · Does it read as a connected argument?

The material makes a sequence: the obvious comparison between ungrazed and grazed paddocks does not work; a hydrological expectation replaces it; on that basis management category does not order the results while geography does.

**Does the document actually make that sequence, or does it present a series of figures and leave the reader to assemble it?** Report where the connective tissue is missing. This is the single most useful judgement in this gate.

### B2 · Better figures on disk

Gate D of DOC-1 searched for substitutions serving claims the document already makes and found one. **Widen the question slightly:** is there a registered figure that would explain an existing claim better, even where the current figure is not wrong?

Search `figure_asset` filtered to `superseded_flag = 0`, and the presentation decks. For each candidate report the claim it serves, what it would replace, and why it explains better.

**Still bounded.** No new figures, no new analysis, nothing serving a claim the document does not make. If the honest answer is that the current figures are the best available, say so — that is a useful finding and Gate D already established it once.

### B3 · Explanation quality

For each reference-state figure, judge whether the surrounding text tells the reader what to look at. A caption that describes the axes is not the same as text that says what the pattern is and what it means.

Name the three figures where better explanation would gain most.

---

## Gate C · Targeted claim checking

127 value and structural claims remain unchecked from DOC-1. **Do not attempt them all.** Check the ones most exposed, in this order:

1. Any number a reader is likely to repeat aloud — areas, percentages, counts, ranks
2. Any number appearing in more than one section, checked for agreement between them
3. Any number in Sections 9 and 10, since those carry the reference-state argument
4. Any number in a figure caption not already checked

**Consistency between sections is the check DOC-1 did not perform.** Claims were verified against source individually; nobody has checked whether the document agrees with itself. Where the same quantity appears twice, confirm both instances match and are stated on the same basis.

Update `DOC1_claim_check.csv` with verdicts. Report the new coverage figure plainly: how many of 175 are now checked, and how many remain.

---

## Gate D · Report

`DOC2_review.md`:

1. **VERIFY sweep** — the table, with closed flags marked
2. **Section scores** — the full table, plus the sections where accuracy and expression diverge
3. **Reference-state assessment** — B1, B2, B3
4. **New verdicts** — anything CONTRADICTED first, then unverifiable, then confirmed
5. **Cross-section inconsistencies** — where the document disagrees with itself
6. **Coverage** — claims checked, claims remaining, stated plainly
7. **What cannot be closed in this task**, and what each would need

Order the report by what most needs fixing, not by document order.

---

## Standing rules

Read-only on the document · SQLite `mode=ro` with `PRAGMA query_only=1` · never re-run the builder · no new analyses · **run in your own git worktree** · commit straight to main per CLAUDE.md, explicit named paths only, never `git add -A` · re-probe the registries at Gate D · **STOP at each gate**.

Confirm no Word lock file is present before Gate 0.
