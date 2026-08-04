# DOC-1 handover — Gates B (remaining), C, D, E

**For a fresh session.** The prior session reached its context limit at Gate B and handed back cleanly, which was the right call.

## What is done

Committed and in `Output/audit/`:

- `DOC1_gateA_verify_answers.md` — all eight VERIFY flags answered from the code
- `DOC1_gateB_value_claims.md` — 41 priority values, 40 CONFIRMED, 0 CONTRADICTED, 1 unresolved
- `DOC1_claim_check.csv` — 204 extracted claims
- `DOC1_extract_claims.py` — the extractor, re-runnable and diffable

Read all four before starting. **Do not re-verify what is already CONFIRMED.**

## The document has changed — use v6

Gate A's findings have been applied at the design seat. `Gayini_RS_methods_doc_v6.docx` supersedes both the file the prior session audited and the v5 build. Save it to `docs/reports/` and use it for everything below.

Eleven corrections were made, all from Gate A or Gate B findings:

| Section | Correction |
|---|---|
| §2 | States that fractional cover and inundation are ingested external products; VERIFY flag reworded to say provider metadata is required and cannot come from the code |
| §3.1 | Tercile caveat made unconditional; cross-referenced to the absolute zones as the comparable alternative |
| §4.4 | The 51.1% temporal floor now stated as pixel-weighted, with the 55.6% unweighted alternative given |
| §6.1 | Residual SD stated as population convention (ddof = 0); slope standard error 0.069 added |
| §6.1 | Diagnostics flag reworded — they are not computed anywhere, not merely unreported; the three-fit robustness check noted |
| §6.3 | Rewritten. Two-stage form given as equations; flood term stated as continuous flood fraction; **"controlling for water" replaced with "the trend in what water does not explain"**, with the orthogonality caveat; near-zero-variance guard added |
| §6.4 | Community SDs stated as sample convention (ddof = 1), with the ddof difference from §6.1 made explicit |
| §6.5 | Rewritten. Pearson named; all four exclusion rules and the stratum coverage rule given; **the two-part responds rule stated**; 0.20 described as a chosen default; new flag for the undocumented A/B seasonal reductions and one for the unstated sign-consistency proportion |
| §6.6 | GAM spec given (thin-plate, k = min(10, n−1), REML, unweighted); **sparse-bin rule corrected to cumulative truncation** |
| §7.1 | Mann–Kendall α = 0.10 stated, with the Theil–Sen 90% complement |
| §7.2 | Truncation claim corrected — see below |

**The §7.2 correction is the one to note.** The prior draft asserted that the Aeolian and Riverine panels end where they do because those communities do not occupy the wetter gradient. Under cumulative truncation a curve ends at the first sparse bin regardless of what lies beyond, so that inference did not follow. The text now states what the endpoints mark and says the community question is not established by the figure.

**A check worth running:** are those endpoints in fact cumulative-truncation artefacts, or do the communities genuinely stop? Reading the bin counts per community answers it, and if the communities do stop there the original statement can be restored with evidence.

## Gate B — three items remaining

1. **§7.3 response values** — r 0.16 to 0.39 and the wet-minus-dry deltas +4.0 to +11.1. Source identified as `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`. **Highest-value remaining item**: these were read off the rendered figure rather than queried.
2. **The 3.03% median green share** — cell count and area are corroborated; the median itself is not yet re-derived.
3. **The −32.0 / −10.5 three-arm pair** — carried to Gate C by the prior session. Do not guess at it there either.

## Gate C — the priority is method-versus-implementation

Three gaps were identified at Gate A and carried forward. Each is now corrected in v6, so **the Gate C task is to confirm the corrected text matches the code**, not to rediscover the gap:

- The responds rule (§6.5)
- The sparse-bin rule (§6.6)
- The two-stage estimator's meaning (§6.3)

Then the figure checks as specified: caption accuracy against the producing code for all 25 figures, and the two named checks on Figure 24 (the raw and adjusted three-arm gaps, and that the adjustment is area-weighted within stratum) and Figures 9 and 10 (green-share definition, areas, and overlap).

**Figure numbering is fixed in v6.** The prior session found 20–25 used twice and 14–19 unused; the build now auto-numbers, and v6 has 25 figures with 25 distinct numbers. Cross-references are corrected. Re-check rather than assume.

## Gates D and E as specified

Gate D stays narrow: substitution for claims already made, not addition. Gate E reports.

## Two things that cannot close in this task

Both were established at Gate A and neither is a text problem:

- **Regression diagnostics** are not computed anywhere. Closing that flag requires running them, which is new analysis and out of scope.
- **Six citations** require external sourcing. The Dawson et al. (2016) paper named as the design template for §6.1 appears nowhere in the repository — not in code comments, not in any document. §6.1's method is a plain bivariate OLS with no attribution in the code, so whether that citation belongs there at all is a design-seat question, not a repository one.

Report both as open rather than attempting to resolve them.

## Standing rules

Read-only on the document · SQLite `mode=ro` · never re-run the builder · no new analyses · re-probe the registries at Gate E · commit straight to main per CLAUDE.md, explicit paths only, never `git add -A`.
