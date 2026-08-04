# DOC-1 — Verification of the methods document

**Version:** v2 · 4 August 2026. Supersedes v1 in place.
**Type:** READ-ONLY AUDIT. No edits to the document, no new analyses, no re-renders, no registry writes.
**Input:** the current methods document in `docs/reports/`. **Record the filename, size, modified time and SHA-256 of the file actually audited in the Gate 0 output.** Do not rely on the version string in the title block — it has been wrong before.
**Output:** `Output/audit/DOC1_verification_report.md` plus `Output/audit/DOC1_claim_check.csv`.
**Re-read this spec in full and echo the current gate verbatim before starting it.**

**Changes in v2:** the input is identified by location and recorded by hash rather than named by version, because the document version changes as findings are applied while the spec's identity does not. Gates A and B (priority list) are recorded as complete. Gate C's scope is narrowed from rediscovery to confirmation.

---

## Why this exists

The methods document is the explanatory layer over the delivery pack: it states what was measured, how each statistic was computed, and what each figure shows. It was written at the design seat from a database snapshot and from reading the rendered figures. **It has not been checked against the producing code.**

Two failure modes matter. A claim may be wrong — a number mis-transcribed, a method described in a way the code does not implement. Or a claim may be unverifiable — stated at a precision nothing available can confirm. Both need finding, and the second is easy to overlook because it reads as confidently as the first.

**You are not improving this document.** Do not rewrite, do not correct, do not suggest better wording. Report what is true, what is false, and what cannot be determined. Corrections are a separate task at the design seat.

---

## Status

| Gate | State |
|---|---|
| **0 · Extraction** | COMPLETE — 204 claims in `DOC1_claim_check.csv`; extractor committed at `DOC1_extract_claims.py` |
| **A · VERIFY flags** | COMPLETE — `DOC1_gateA_verify_answers.md` |
| **B · Priority values** | PARTIAL — 41 of the priority list checked, 40 CONFIRMED, 0 CONTRADICTED, 1 unresolved. `DOC1_gateB_value_claims.md`. Three items remain, below |
| **C · Figures and methods** | NOT STARTED |
| **D · Substitution** | NOT STARTED |
| **E · Report** | NOT STARTED |

**Do not re-verify anything already recorded CONFIRMED.** The settled set is: the five expectation-line constants, the three largest residuals and the two derived standard-deviation statements, the eight gap-series values, the five part-classification counts, the nine community standard deviations and part counts, the census structure, the three threshold-sweep areas, and the six Bala 29ca values.

**The document has been corrected since Gates A and B ran.** Eleven changes were applied at the design seat from those findings. Gate C confirms the corrected text against the code; it does not rediscover the gaps.

---

## Gate 0 · Extract the claims · **STOP** *(complete)*

Parse the document and build `DOC1_claim_check.csv`, one row per quantitative or methodological claim:

`claim_id`, `section`, `page_ref`, `claim_text`, `claim_type`, `stated_value`, `stated_units`, `figure_ref`, `verdict`, `found_value`, `source_object`, `source_query`, `evidence`, `notes`

`claim_type` is one of **value** (a number), **method** (how something was computed), **structural** (a count, a scope, a field name), or **interpretive** (a statement about meaning, not directly checkable).

Interpretive claims are recorded but not verified. Note only whether the values they rest on are.

Claims are extracted at sentence rather than paragraph level. This yields more rows than a human count would, and that is deliberate: a verdict attaches to the specific sentence that is wrong, which matters when one sentence in a paragraph is contradicted and the rest are sound.

**On re-running against a later draft:** the extractor is re-runnable and its output diffable. Re-extract and diff rather than re-reading, and carry forward existing verdicts for claims whose text is unchanged.

---

## Gate A · The VERIFY flags · **STOP** *(complete)*

Answer each flagged passage from the code, naming file and line.

**The flag inventory must be re-established for each draft, not inherited.** Corrections remove flags and add them. At the time of writing the expected inventory is six flags plus one front-matter sentence explaining the marker:

| Section | Expected |
|---|---|
| §2 — provider metadata for the ingested products | retained |
| §6.1 — regression diagnostics | retained |
| §6.5 — undocumented A/B seasonal reductions | new |
| §6.5 — unstated sign-consistency proportion | new |
| §12.3 — next-steps priorities not agreed | retained |
| References — six unresolved citations | retained |

A count differing from this is itself a finding.

Flags of the form "this has not been agreed" are statements about the document's status rather than checkable claims. Record them as acknowledged and say why no verification was attempted.

---

## Gate B · Verify the value and structural claims

For every `value` and `structural` claim, assign a verdict:

| Verdict | Meaning |
|---|---|
| **CONFIRMED** | Reproduced from a named source object with a runnable query |
| **CONTRADICTED** | A different value was found. Record both |
| **UNVERIFIABLE** | No object or query can produce it. Say why |
| **STALE** | Correct when written, superseded since. Record both and the date of change |

Populate `source_object` and `source_query` for every CONFIRMED row. **A verdict without a runnable query is not a verification.**

Flag any claim whose value is registered in `dim_headline_number` but whose stated precision differs from the pinned value.

**Where a value depends on an unstated convention, record it even when the number is right.** Three such cases were found in the first pass — a sample-versus-population standard deviation split between sections, an unstated pixel-weighting behind an aggregate, and a denominator that did not match the counts in its own sentence. None was a wrong number; each needed a clause.

### Remaining at Gate B

1. **§7.3 response values** — r from 0.16 to 0.39 and the wet-minus-dry deltas from +4.0 to +11.1. Source identified as `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`. **Highest-value remaining item:** these were read off the rendered figure rather than queried from source.
2. **The 3.03% median green share.** The cell count and area are corroborated against the persistence raster README; the median itself is not yet re-derived.
3. **The three-arm raw and adjusted gap pair** (−32.0 becoming −10.5). No pin exists under that description. The nearest registered values are a Bala 29ca T10 quantity and the positive `three_arm_floor_deficit_*` entries. **Carried to Gate C. Do not guess at it there either.**

---

## Gate C · Verify the figure and method claims

### C1 · Confirm the corrected method descriptions

Three method-versus-implementation gaps were found at Gate A and have since been corrected in the document. **Confirm the corrected text matches the code.** Do not rediscover the original gaps.

- The responding-stratum rule (§6.5) — now stated as a two-part rule
- The sparse-bin rule (§6.6) — now stated as cumulative truncation
- The two-stage estimator (§6.3) — now given as equations, with the orthogonality caveat

Also confirm the additions made alongside them: the population-versus-sample standard deviation conventions, the Mann–Kendall significance level, the GAM specification, and the tercile statement.

**A method described more simply than it is implemented is a defect** even when the number is right, because a reader will reproduce the description rather than the code. Apply that test to every `method` claim, not only the three above.

### C2 · Figure and caption checks

For each numbered figure:

- Does the source file exist, and is it registered?
- Is the caption accurate to what the figure actually draws? **Read the producing code, not the rendered image.** Check axis definitions, scope filters, and what is and is not drawn
- Are the numbers quoted in the surrounding text the numbers the figure displays?
- Is the declared support level correct?
- Do cross-references in the body text resolve to the figure they name?

Figure numbering is auto-generated in the current build after a collision in an earlier one. **Re-check rather than assume**, and verify that each number occurs once as a caption; additional occurrences should be body cross-references.

### C3 · Two named checks

**The three-arm grid.** The document explains that the visible line-to-band separation is the raw gap while the label is the within-stratum area-weighted adjusted gap. Confirm both quantities and confirm the adjustment is area-weighted within stratum as described. This is where Gate B's unresolved pair is settled.

**The green-share and persistence-overlay figures.** The document claims total-cover persistence and green-share persistence largely do not coincide, and that the country satisfying both is small and linear. Confirm the areas and the overlap, and confirm the green-share definition — photosynthetic over total vegetation, read paired in the season setting each cell's total-cover 5th percentile.

### C4 · One open interpretive check

The document previously inferred that two panels of the percentile fan end where they do because those communities do not occupy the wetter gradient. Under cumulative truncation a curve ends at the first sparse bin regardless of what lies beyond, so that inference did not follow and the text now states only what the endpoints mark.

**Reading the per-community bin counts settles it.** If the communities genuinely cease at those flood frequencies, the stronger statement can be restored with evidence. Report the counts either way.

---

## Gate D · Substitution check only · **STOP**

Narrow scope. Read the boundary carefully.

**In scope:** for a claim the document already makes, does a better-suited registered figure or table already exist? A figure that shows the same thing more directly, at a more appropriate support, or without a known drawing limitation.

**Out of scope:** proposing new analyses, new figures, new inundation work, or additional content the document does not currently claim. If a genuine gap becomes obvious, name it in one line and move on — do not develop it.

Search `figure_asset`, `table_asset` and the presentation decks. For each candidate report: which claim it would serve, which current figure it would replace, and why it is better. **Do not substitute anything.**

---

## Gate E · Report

`DOC1_verification_report.md`, structured as:

1. **CONTRADICTED claims**, most exposed first. This is the section read first
2. **The VERIFY flags**, one subsection each, with the current inventory stated
3. **UNVERIFIABLE claims**, with what would be needed to verify each
4. **STALE claims**, with both values and the date of change
5. **Figure and caption defects**
6. **Method descriptions that do not match implementation**
7. **Unstated conventions** — cases where the number is right but a clause is missing
8. **Substitution candidates** from Gate D
9. **Counts** — claims by type and verdict, and the proportion verified

State the verified proportion plainly. If a large share is unverifiable, that is the finding and it should not be buried under the confirmed ones.

Re-probe the registries at this gate and report any movement since Gate 0, with the audit window stated.

---

## Two things that cannot close in this task

Both were established at Gate A. Neither is a text problem, and neither should be attempted here.

- **Regression diagnostics** are not computed anywhere in the analysis. Closing that flag requires running them, which is new analysis.
- **Six citations** require external sourcing. The distance-to-reference paper named as the design template for the expectation line appears nowhere in the repository — not in code comments, not in any document — and the method as implemented is a plain bivariate ordinary least squares with no attribution in the code. Whether that citation belongs in the document at all is a design-seat question, not a repository one.

Report both as open.

---

## Standing rules

Read-only on the document · SQLite `mode=ro` with `PRAGMA query_only=1` · **never re-run the builder** · no new analyses · paths resolved from the DB, never hardcoded · check whether another session holds the database before starting and re-probe at Gate E · **STOP at each gate** · change report to `docs/change_reports/` · commit straight to main per CLAUDE.md, explicit named paths only, **never `git add -A`**.

If the document is open in Word during the audit, a mid-audit save will stale the extraction silently. Confirm no lock file is present before Gate 0.

## Identifiers

**DOC-1**, in the tracker namespace. Never use a bare `T`-number in outputs — always qualify as `pack item T1`, `figure prefix T1_`, or `spec T1`.
