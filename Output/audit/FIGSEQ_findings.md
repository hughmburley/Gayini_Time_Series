# FIGSEQ — figure sequencing and caption backing, V12

**Read-only.** 6 August 2026 · `mode=ro`, `PRAGMA query_only=1` · no writes, no renders, no
document or producer edit.

**Input.** `docs/reports/Gayini_RS_methods_doc_V12.docx` · 10,604,897 bytes ·
2026-08-05T18:06:06 · SHA-256 `c3051c0c9400e7caa0e1a8c173806491fd2c7ceb21393651d0f71a18229e5650` ·
28 media · 28 captions. Hash re-checked at the end of the run: unchanged.

**Registry state at the run:** `dim_headline_number` 123 · `figure_asset` 297 · `table_asset` 5 ·
`report_asset` 60.

**One condition to record.** The document moved *during recon* — 12:17 / 10,604,746 at first
listing, 18:06 / 10,604,897 seconds later, with a Word lock present. Everything below is the
18:06 file.

---

# Part A · Sequencing

## A1 · Dependency graph — three violations, not one

"Depends on" = the caption or passage uses a quantity, line, classification or threshold that
another figure establishes.

| Fig | Depends on | Order |
|:--:|---|---|
| 15, 16, 17 | — | — |
| 18 | 17 — the classification it re-cuts | ok |
| 19 | 17 — 115 of 118 parts | ok |
| **20** | **25** — "the registered expectation line"; 6.62 pp residual SD | **VIOLATION** |
| **21** | **26** — "Figure 26 draws all three… a two-arm picture that Figure 26 corrects" | **VIOLATION** |
| **22** | 21 (ok), and **26 / 27** — −32.0, −10.5, −4.1, −2.3 | **VIOLATION** |
| 23 | 21, 22 — the grain note | ok |
| 24 | 23 — "as Figure 23 shows" | ok |
| 25 | — (establishes the line) | — |
| 26 | — | — |
| 27 | 26 — "drawn to match Figure 26" | ok |
| 28 | 25 — its residual column | ok |

**1 · Figure 20 → Figure 25.** The known instance. Residuals mapped five figures before the line
is fitted. Figure 25's own passage states the dependency: *"the departures mapped in Figure 20 and
tabulated in Figure 28 are departures from it."*

**2 · Figure 21 → Figure 26.** Figure 21's passage tells the reader its own two-arm picture is
corrected by a figure five pages later. Explicit, and acknowledged in the text.

**3 · Figure 22 → Figures 26 / 27.** Figure 22 quotes **−32.0 / −10.5 / −4.1 / −2.3** — arm-versus-
comparator quantities that Figures 26 and 27 establish, in arm vocabulary Figure 26 defines. Four
numbers arrive four pages before the figure that produces them.

**Violations 2 and 3 both point at Figure 26 and are structural:** §10 places the whole-paddock and
part-grain conserved/grazed material before the three-arm material that qualifies it. **Neither is
reachable by swapping 20 and 25.**

## A2 · Roadmap against the document

**Roadmap order as written: 28, 25, 20, 19, 21, 23, 22, 26, 17 — nine figures.**

The FIGSEQ spec stated it as *28, 15, 25, 20, 19, 21, 23, 22, 26, 17*. **The document's roadmap does
not mention Figure 15.** Corrected at the design seat on receipt.

| roadmap position | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| roadmap | 28 | 25 | 20 | 19 | 21 | 23 | 22 | 26 | 17 |
| document | 17 | 19 | 20 | 21 | 22 | 23 | 25 | 26 | 28 |
| agree | ✗ | ✗ | **✓** | ✗ | ✗ | **✓** | ✗ | **✓** | ✗ |

**Three of nine positions agree** — 20, 23, 26. The two are near a reversal at the ends: the roadmap
opens on 28 and closes on 17; the document opens on 17 and closes on 28.

**Five figures in §§9–10 appear in the roadmap not at all:** 15, 16, 18, 24, 27.

## A3 · Cross-reference cost — **marginal**

36 in-text cross-references total, caption openers excluded.

| | references that change |
|---|---:|
| **(a) swap 20 and 25 only** | **4** — three to Figure 20, one to Figure 25 |
| **(b) reorder §§9–10 to roadmap order** | **28** — every reference to figures 15–28 |
| unaffected either way | 8 — references to figures 1–14 |

Heaviest targets: Figures 21, 22 and 26 at five references each; Figure 28 at four.

**These are MARGINAL costs.** An earlier framing treated the 28 as already committed on the grounds
that four figure cuts would renumber everything above 10 regardless. **Those cuts are recommended in
FIG2 and sit BLOCKED in the V12 change list — they have not been ruled.** Amended at the design seat
(Ruling AI amendment, 6 Aug) and recorded here as marginal unless and until the cuts are ruled.

## A4 · Could anything move without renumbering?

**No.** Captions appear in strictly ascending numeric order 1–28, without exception. **Position and
number are the same thing in this document, so any reorder is a renumber** — the A3 costs are
unavoidable rather than optional.

---

# Part B · Caption and passage backing

**181 numeric tokens across 28 captions and 46 passage paragraphs.**

## B1 / B2 · No "no source"

Every quantity resolves. The 47 that did not auto-match were adjudicated individually and **all
reproduce**; several were tokenizer artefacts rather than quantities — `§7.4`, `Bala 28ca` → "28",
`1988–2022` → "2022", `52 to 78 metres`.

**Verified for the first time in this task** — no prior audit had checked them:

| | as written | found |
|---|---|---|
| Fig 4 | τ −0.12 to +0.14; p 0.24 to 1.00; nine strata no-trend | **−0.1227 to +0.1440** · **0.2363 to 1.0000** · 9/9 `no_trend` |
| Fig 16 | 48 in a zone / 18 not; 24 in conserved; 13 in Bala 29ca | **48 / 18 · 24 · 13** exact |
| Fig 28 | conserved adjusted trends −0.337 to +0.556 | **−0.337 to +0.556** exact |

**Reproduces but unregistered — roughly 30 distinct quantities.** The largest concentrations:
Figure 10's overlay set (94.9%, 81.2%, 150 m, 1,700 m, 406.09, 7,969.70, 500.06 — none carries a
`number_id`, as DOC-1 Gate C found); Figure 9's green-share set; Figure 6's percentile-fan
endpoints; and the −32.0 / −4.1 raw gaps, which are computed at render and deliberately unpinned.

## B3 · Relationship claims — all reproduce

Checked and holding as stated: *"three largest shortfalls"* with Dinan 13 fourth at two hundredths
behind; *"six of nine"* and *"eight of nine"* (Figure 26); *"between three and fifteen… strictly
nested"* with the ladder 3 / 4 / 5 / 8 / 10 / 15 (Figure 17); *"most of the apparent difference is
hydrological position"* (−32.0 → −10.5); *"the Aeolian panel carries a single conserved line…
because its Aeolian portion is 10 cells"* (Figure 21).

## B4 · Rank direction — clean

| rank as stated | source column | direction |
|---|---|---|
| "2nd of 64 in shortfall" (Fig 25); "three largest shortfalls" (Fig 20) | `v_zone_floor_flood_residual.rank` | rank 1 = largest shortfall — **matches** |
| "ranks 3rd of 64" / "61st" flood frequency (Fig 28, §9) | `ref_paddock_flood_rank_*` | descending, rank 1 = wettest — **matches** |

**The ascending `fact_zone_floor_temporal.rank_by_adjusted` column — the one that inverted in the
S11 draft — is quoted nowhere in V12.** Figure 28 gives the adjusted trends as a range, not a rank.
The defect did not reach this document.

## B5 · Support and grain — one gap

Figures 21 and 22 declare part grain explicitly; Figure 23 declares whole-paddock and flags the
change (*"The unit has changed"*); Figures 12–14 declare the polygon footprint; Figure 28 declares
the census footprint.

**Figure 26's passage says "part support"; its caption does not.** It is the figure whose nine
values are most quoted. *(Ruling AK, 6 Aug: one clause added at the design seat.)*

## The one item not clean

**Figure 11's elasticities — "13% at 78, 22% at 80, 40% at 82".** They are the persistence README's
13.5 / 22.5 / 40.4 **truncated, not rounded** — 13.5 rounds to 14, 22.5 to 23 or 22; only 40.4 → 40
is correct. They also do not reproduce from `T3_gateB1_threshold_sweep.csv` on a one-sided
difference, which gives **11.9 / 19.2 / 34.6** — so the README uses a definition that could not be
recovered, and the document is a second rounding away from it.

Two faults stacked: a second rounding (§4.6(b) forbids it) and a source whose derivation cannot be
reconstructed, in a document that declares every quantity traceable.

*(Ruling AJ, 6 Aug: the three elasticities are deleted. The claim they support — no natural break,
no plateau, no bimodality — is carried by 12,641 / 8,300 / 4,179 ha at 70 / 75 / 80, which do
reproduce, and by the median elasticity of about −5. The sweep's 11.9 / 19.2 / 34.6 are NOT
substituted until the README's definition is recovered or replaced.)*

---

## A limitation of this check, recorded as I-56

Part B's resolver matched **by value across 123 pins**. Of 98 "registered" hits, **51 matched more
than one pin** — "3" matches ten, "10" six, "5" five. **A value match establishes that a number
exists in the registry, not that the caption took it from there.**

**The count of 98 is therefore softer than it reads. The adjudicated findings are not** — those
were resolved individually. Remedy is the pack's, proven at PACK-1 v1.2: per-caption `number_id`
contracts, so resolution is by identity rather than value. Post-deadline. Logged **I-56**, in
I-53's family.

---

## Result

**Part B comes back clean, and that is a result rather than an absence of one.** V12's captions had
had one substantial rewrite and a build-time vocabulary assertion, and nothing had checked their
numbers against the registry until this task. **Nothing is unsupported, no rank is inverted, and
every relationship claim holds** — with the single exception of Figure 11's elasticities, now ruled
out of the document.
