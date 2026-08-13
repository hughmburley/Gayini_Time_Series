# REPORTS — R-7 · 64 paddock reports built · combination matrix

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Builder:** v1.5 (unchanged logic; `--all-paddocks` added) · **DB read-only.** No write attempted.
**Built: 89 documents — 64 paddock, 25 site. 477 figures. NOT SHIPPED.**

```
lint_builder.py        0 error · 0 warn                          exit 0
verify_batch.py        32 match · 0 changed · 0 missing           exit 0
check_scope_claims.py  clean across all 89                        exit 0
check_page_fill.py     343 pages · 0 above 92% · 124 below 70%    exit 0
tests/                 10 assertions · 4 files · 0 fail           exit 0
```

`verify_batch` still reproduces the original 32 exactly, which is the point: **R-7 added
documents and changed nothing about the ones already verified.** The 57 new documents are
outside the manifest and I have deliberately **not** re-fingerprinted — the set is not ratified,
and re-fingerprinting twice is two chances to regenerate instead of diff. Recommend
re-fingerprinting at 89 once you have read the sample.

---

## 1. Feasibility — re-derived, not taken

Every claim confirmed independently against the database and the GeoPackage.

| | |
|---|---|
| zones in `dim_management_zone` | **64** |
| with a full 35-year series (`mean_of_seasons`, 1988–2022) | **64** · none incomplete |
| with a residual in `v_zone_floor_flood_residual` | **64** · none missing |
| with ≥1 classified part | **64** · none missing |
| with a C1 render (via `c1_slug`) | **21** |
| taking a locator | **43** |
| **paddocks with no map** | **0** |

**One nuance the "sound enough for a locator" claim hides.** Six zones have ≤6 vertices, but only
**Bala 29ca is genuinely undrawable** (0.6 m extent) — and it has a C1 render, so it never needs
the locator. The other five have real extents (1,100–3,520 m): crude, but drawable. Of the 43
locator paddocks, three are bare polygons — **Bala 7/10** (6 vertices), **Mara 11** (5), **Mara 9**
(6). Vertex counts across all 64 run min 5 · median 18 · max 213. So the claim holds, and the
three crude locators are worth an eye in the sample read.

**R-7 is encoded as a query, not a list.** `--all-paddocks` selects from `dim_management_zone`.
A typed list of 64 names is precisely a literal standing in for a derived value, which is the
defect class this module exists to remove.

---

## 2. The combination matrix

**Five of the eight cells are populated. Three are empty — and that is a finding.**

| communities | sites | map | n | |
|---|---|---|---|---|
| single | none | c1 | **0** | *empty* |
| single | none | locator | **24** | Bala 13, Bala 15, Bala 22, Bala 24, Bala 25, Bala 27ca … +18 |
| single | some | c1 | **3** | Bala 17, Bala 19, Bala 21 |
| single | some | locator | **0** | *empty* |
| multi | none | c1 | **5** | Dinan 1, Dinan 6, Dinan 10, Dinan 12, Mara 13 — **never built before** |
| multi | none | locator | **19** | Bala 1, Bala 2, Bala 5, Bala 14/16, Bala 18, Bala 7/10 … +13 |
| multi | some | c1 | **13** | Bala 12, Bala 20, Bala 23, Bala 26ca, Bala 28ca, Bala 29ca … +7 |
| multi | some | locator | **0** | *empty* |
| | | | **64** | every unit placed |

**No ninth cell.** Every `map_kind` is `c1` or `locator`; the composition fallback never fired,
because no paddock's geometry was degenerate *and* lacking a C1 render.

**Page model holds exactly:** 27 single-community × 4 pages, 37 multi × 5 pages. Nothing off spec.

### Against your predictions

| | predicted | actual |
|---|---|---|
| no-sites page | 48 | **48** ✓ |
| locator map | 43 | **43** ✓ |
| no sites **with** a C1 render | 5 | **5** ✓ |
| single-community | 25 | **27** |

Single-community is **27, not 25**. The two extra are Bala 15 and Mara 3 — see §3, where the
same two paddocks produce a prose finding for the same underlying reason.

### The empty cells matter more than the full ones

**The locator never fires for a paddock that has sites — 0 of 43.** All 43 locator paddocks have
zero sites and `sites_drawn: false`.

**So D-2's true branch is still latent across the entire 64-paddock set,** and its correctness
rests entirely on `tests/test_caption_branches.py`. That is now the only thing standing behind it.

**And my own c1_slug fix is why.** Under the old slug, `Bala 8/11` (1 site, 1,551 ha) was looked
up as `Bala_8-11`, missed its render, and fell to the locator — the single unit in all 64 that
would have exercised D-2 live. The fix moves it to the C1 path. Two correct fixes interacted to
close the only live case. Worth knowing before anyone concludes from a clean run that the branch
is exercised.

---

## 3. Degradation output — what I could not attribute

Structurally the set is clean: **no** empty composition, **no** unclassified parts, **no** null
residual, **no** part with a null share or area, **no** series shorter than 35 years, **no** band
table below 2 rows, **no** figure drawn from a single point. Every distribution is tight —
`n_parts` {1: 27, 2: 23, 3: 14}, bands {2: 2, 3: 62}, series length {35: 64}.

**One finding, and it shipped in the original 32.**

`n_parts` and the non-woodland composition disagree for 3 paddocks, because a community can
appear in the census yet fall below the support rule for part classification:

| | parts | composition | page-1 prose |
|---|---|---|---|
| **Bala 28ca** | 2 | 3 | *"spans **3** kinds of country — 83% Inland Floodplain · 17% Riverine · **0% Aeolian**"* |
| Bala 15 | 1 | 2 | *"is **entirely** Inland Floodplain country"* (Riverine 0.27%) |
| Mara 3 | 1 | 2 | *"is **entirely** Inland Floodplain country"* (Aeolian 0.02%) |

**Bala 28ca announces three kinds of country on page 1 and lists two in the parts table on page 3**,
with the third named at *0%*. A reader who counts will find one missing. This is the *"caption
asserting something absent"* class, it is **1 of 64**, and it was in the delivered 32-document
set — Bala 28ca is one of the original seven — where it went undetected through every gate,
including mine.

More broadly, **6 of 64** paddocks name a community below 1% in page-1 prose, down to 0.02%:
Bala 15, Bala 28ca, Bala 8/11, Dinan 4, Dinan 7, Mara 3.

Both are **design-seat**: what the prose asserts, and the plain-language register. Flagged, not
changed. The mechanical options are to suppress composition entries below a threshold, or to
drive the page-1 count from `parts` rather than `composition` — but which is right depends on
whether a 0.05% sliver of Aeolian is something Nari Nari should be told about.

**One transient, now handled.** Over 89 conversions LibreOffice failed once (`Dinan 3`,
*"Could not find platform independent libraries"*) and converted the same file cleanly on its
own. `check_page_fill.py` now **retries once** before recording an error: a build must not fail
on a LibreOffice startup hiccup, and two attempts still fail a genuinely broken document.

**Page fill across all 89:** 343 pages, **0 above 92%**, 124 below 70%. No spill risk anywhere in
the full set. The dead-space count rose from 12/83 to 124/343 because the new units are thinner —
advisory under R-1, and yours. **No layout was adjusted.**

---

## 4. Nominated stratified sample — 12 documents

One per populated cell, chosen as the **median-area** member so the cell is represented by a
typical unit rather than an extreme, plus the named and special cases.

| # | unit | cell | area | pages | why |
|---|---|---|---|---|---|
| 1 | **Dinan 1** | multi/none/c1 | 781 ha | 5 | the combination **never built before** (n=5) |
| 2 | **Bala 1** | multi/none/locator | 631 ha | 5 | largest cell (n=19) |
| 3 | **Bala 28ca** | multi/some/c1 | 1,371 ha | 5 | largest cell (n=13) **and** the 3-vs-2 prose finding |
| 4 | **Bala 4** | single/none/locator | 348 ha | 4 | largest cell (n=24) — the modal document of the set |
| 5 | **Bala 17** | single/some/c1 | 746 ha | 4 | smallest populated cell (n=3); 5-vertex geometry |
| 6 | **Mara 22a** | single/none/locator | 99 ha | 4 | **you named it** — thinnest single-community no-sites unit |
| 7 | **Mara 1** | multi/none/locator | **53 ha** | 5 | **thinnest unit overall**, yet 2 communities and 5 pages |
| 8 | **Bala 8/11** | multi/some/c1 | 1,551 ha | 5 | slash name; **the only paddock c1_slug changes** |
| 9 | **Bala 7/10** | multi/none/locator | 248 ha | 5 | slash name; no C1 exists; 6-vertex locator |
| 10 | **Bala 14/16** | multi/none/locator | 547 ha | 5 | slash name; no C1 exists |
| 11 | **Bala 29ca** | multi/some/c1 | 2,287 ha | 5 | the only document where the §8.1 gap fix is visible (45 → 14) |
| 12 | **Mara 3** | single/none/locator | 616 ha | 4 | the *"entirely X"* prose case in a **new** unit |

**On Mara 22a and thin units.** You asked to see one before deciding, and I have not suppressed
anything. But Mara 22a at 99 ha is not the extreme case — **Mara 1 is 53 ha and gets a 5-page
report**, because it has two communities and therefore a parts page. If the question is whether a
thin unit earns a document, the pair to compare is Mara 1 against Mara 22a: the thinner one is
the longer one. Both are in the sample for that reason.

All twelve are at `Output/reports/Gayini_paddock_report_<slug>.docx`, with PDFs alongside.

---

## 5. Not shipped · still open

- **Not re-fingerprinted at 89** — deliberate, pending your sample read.
- **Not shipped**, per instruction.
- **Per-paddock output folders** — not started; awaiting your written ruling, now 64 folders.
- Scope-lock string from `RPTSCOPE_number_contract.csv` (§3 item 3).
- Methods document (§4); figure registration (§5) — session 1, now 477 figures plus
  `T10_annual_gap_series.csv`.
- The 12→124 dead-space pages: yours, untouched.
