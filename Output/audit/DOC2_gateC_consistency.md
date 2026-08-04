# DOC-2 Gate C — targeted claim checking and the consistency sweep

**Read-only.** 4 August 2026 · `Gayini_RS_methods_doc_V8.docx`, SHA-256 `d4b95bd9…56b7` ·
SQLite `mode=ro`, `PRAGMA query_only=1`.

**The check DOC-1 did not perform: does the document agree with itself?** Every numeric token appearing in
more than one section was extracted and compared. 146 distinct tokens; **31 appear in two or more sections**,
one in seven.

---

## 1 · Cross-section consistency — eleven quantities agree everywhere

These carry the document and are stated identically wherever they appear:

| quantity | sections | verdict |
|---|---:|---|
| 64 paddocks / zones | 7 | consistent |
| 1,080,157 census cells | 3 | consistent |
| 118 parts / 115 supported | 4 | consistent — and M4/F7 now reads *"Of the 115 parts carrying sufficient support"*, closing DOC-1's denominator mismatch |
| 66 monitoring plots | 4 | consistent |
| 85,911 ha property | 2 | consistent |
| 24.97 m grid | 3 | consistent |
| −16.8 Bala 29ca residual | 3 | consistent across §6.1, M5b and F5 |
| −15.1 Dinan 10 residual | 2 | consistent |
| 6.62 residual SD | 2 | consistent |
| r = 0.71 | 2 | consistent |
| gauge 410040 | 2 | consistent |

60 grazed + 4 ungrazed = 64 also reconciles across M1, F1 and §4.5.

**No quantity was found stated at two different values.** The defects below are of a different kind: the same
number on a different basis, or the same number doing different jobs.

---

## 2 · The trends and the expectation line are fitted on 1988–2022, and the document says 1988–2023

**This is the significant finding of the gate.**

The document states its record as **1988 to 2023** in §1, §2, §4.5, §7.1, §7.4 and §13. Every trend statistic
in `dim_headline_number` carries `period_label = '1988-2022'`:

```
floor_flood_slope_64pdk                     1988-2022
t10_bala29ca_raw_floor_trend                1988-2022
t10_bala29ca_water_adjusted_floor_trend     1988-2022
t10_gap_annual_slope_{A_all4,B_excl29ca,C_29ca}   1988-2022
t10_{grazed,ungrazed}_median_adj_trend      1988-2022
```

**`floor_flood_slope_64pdk` is the expectation line.** The line every residual in Sections 9 and 10 is
measured against — the hinge of the whole reference-state argument — is fitted over a window one year
shorter than the record the document declares, and **no section says so.**

This is very likely correct rather than an error: the final water year is plausibly incomplete for the
annual cover series. **But the document nowhere states that its census results and its trend results rest on
different windows**, and a reader comparing §7's census statements with §6.1's line has no way to know.

**What it needs:** one clause, wherever the record is first declared, saying that percentile and census
results use 1988–2023 while trend and expectation-line statistics use 1988–2022, and why.

---

## 3 · §4.5's plot period 1988–2026 — real, and describing a different object from the results

The design-seat hypothesis is **confirmed**: the ground network genuinely runs past the satellite record.

| object | extent |
|---|---|
| `fact_plot_observation.date_midpoint` | **1988-01-01 → 2026-01-01** |
| `fact_plot_year.water_year` | 1988-1989 → 2024-2025 |
| **`v_plot_year_analysis_spine.water_year`** | **1988-1989 → 2022-2023** |

**But the table's 1988–2026 is not the period of the plot results the document reports.** Every plot-support
number in the document — the plot medians in Figure 7, the plot verdicts, the 66-plot spine — comes from
`v_plot_year_analysis_spine`, which **ends 2022-2023**. The support table states the raw observation extent
in a row whose other columns describe the analysis.

**A clause rather than a fix, as predicted — but the clause has to name which record 2026 refers to**, or the
row implies plot results three years fresher than they are.

---

## 4 · Two collisions where the same number does different work

**`0.556` appears in three sections doing three jobs.** §6.2 introduces it as a generic worked example
(*"A slope of +0.556 pp/yr indicates…"*); §6.3 reports it as Bala 29ca's actual water-adjusted trend; T1
gives it as the upper end of the four-paddock range. All correct. A reader meeting the worked example first
will not know they are later reading the same number as a result.

**`500` collides across three sections with two meanings.** §6.6 and the Figure 6 caption use *500 cells* as
the sparse-bin threshold; §7.5 states the green-share drawn area as *approximately 500 ha*. Unrelated
quantities, numerically identical, three sections apart.

Neither is an error. Both are the kind of coincidence that makes a careful reader stop.

---

## 5 · Targeted checks against source

### CONFIRMED

**§7.2's headline pair — reproduced exactly from the rasters.** Inland Floodplain, across-cell median of
each stored percentile per 10-pp flood bin:

| | document | reproduced |
|---|---|---|
| p05 across the gradient | ~45% → 79% | **44.95 → 79.82** |
| p50 across the gradient | ~78% → 91% | **77.75 → 91.24** |
| *"the floor moves roughly 34 points against the median's 13"* | 34 / 13 | **34.9 / 13.5** |

All four values and both differences. No Inland bin is truncated, so the drawn range is the full gradient.

**T1 · Bala 26ca 45.3%** → 45.29% pixel-weighted over non-treed strata. **Bala 29ca 8.5%** → 8.53%.
**§8.1 · Bala 23 long-run 39%** → 38.60%.

**§6.1 / T1 ranks 3rd, 6th, 31st, 61st** → `ref_paddock_flood_rank_bala26ca` 3, `_bala28ca` 6,
`_bala27ca` 31, `_bala29ca` 61.

**F4 · +8.4 / +13.5 / −0.8** → `gap_change_all_aeolian` 8.4, `_riverine` 13.5, `_inland` −0.8, exactly.
The non-flood counterparts are pinned at 9.7 / 12.3 / 0.6 — all positive, which supports the text's
*"narrowing present in both flood and non-flood years"* and confirms that a positive gap change is a
narrowing of a negative gap. **The claim is right; Gate A's point stands that the convention is not stated
here.**

### UNVERIFIABLE — one, and reported as such rather than as a contradiction

**§11.2's *"mean inundation of 43.6% against 22.8% across the preceding thirty-one years"*.** No pin exists
and I could not identify the aggregation basis. An unweighted zone-community derivation gives 37.94% and
19.36% — **but that derivation is demonstrably the wrong one** (see below), so this is recorded as a
derivation I could not establish, **not** as a number disproved. The 4-year / 31-year split reconciles to 35.

---

## 6 · A methodological note that earns its place

My first attempt at the ungrazed flood-frequency ranks used an unweighted mean of
`fact_zone_community_flood_annual` and produced ranks **19 / 21 / 30 / 59** against the document's
**3 / 6 / 31 / 61**. That looked like four contradictions in the document's most-quoted rank family.

**The document was right and my derivation was wrong.** The correct basis is the pixel-weighted mean over
non-treed strata in `census_by_zone_stratum`, which reproduces Bala 26ca at 45.29% and Bala 29ca at 8.53% —
matching both the text and the registry.

**A wrong derivation produces a confident, plausible, wrong contradiction**, and it produces four of them at
once. That is why §11.2 above is reported as unverifiable rather than contradicted: the one time an
unweighted basis was tested against a known answer at this gate, it failed. Same discipline as DOC-1's
refusal to reason from the nearest plausible pin.

---

## 7 · Coverage, stated plainly — and the front matter is now stale

**v8 holds 260 claims: 111 value, 90 structural, 51 method, 8 interpretive. Value + structural = 201.**

The document grew: v6 had 175 value and structural claims, v8 has **201** — §4.5 Support and the
restructured references added 26.

| | |
|---|---|
| checked at DOC-1 (priority list, against v6) | **48** |
| newly checked at this gate | **12 distinct claims**, plus consistency verified across 31 repeated quantities |
| **checked in substance, against v8's 201** | **~60** |
| **unchecked** | **~141** |
| carrying a verdict in `DOC1_claim_check.csv` | 26 value/structural (31 verdicts including method rows) |

**The front matter's verification statement is out of date.** It reads *"checked 48 of the 175 value and
structural claims in this document"*. Both numbers were correct for v6 and neither is correct for v8 — the
denominator is now 201. **Nothing updates that sentence when the document is rebuilt**, so it will drift
further with every version. It is the one place in the document that reports its own audit coverage, and it
is the sentence most likely to be quoted back.

**The honest headline is unchanged in kind: roughly 141 of 201 value and structural claims have never been
checked, and nothing establishes that no further contradiction sits among them.**

---

## Summary

**No quantity is stated at two different values anywhere in the document.** The consistency sweep found no
outright disagreement — which is a real result, and it is why the two defects it did find are worth acting on.

**Both are basis mismatches rather than value errors:** the trend statistics and the expectation line are
fitted on 1988–2022 while the document declares 1988–2023, and §4.5's plot period describes the raw
observation record where its row describes the analysis.

**Five targeted numbers confirmed exactly**, including §7.2's headline pair reproduced from the rasters and
F4's three gap changes reproduced from the registry. **One unverifiable**, reported as such because the
derivation is unestablished rather than the number disproved.

**One stale self-report:** the front matter's "48 of the 175" no longer describes v8.
