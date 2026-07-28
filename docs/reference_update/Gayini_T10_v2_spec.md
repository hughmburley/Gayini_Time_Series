# T10 v2 — What remains after water

**Version:** v2 · 28 July 2026
**Status:** STANDALONE. Supersedes the T10 section of `Gayini_reference_state_specs_T7_T11.md` v1
and the T10 amendments in `T8_T9_T10_gateA_decisions.md` §3. Read this document alone; there is
no precedence chain.
**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Depends on:** T1, T2, T6, T8 (all complete). T9 complete and its result changes this spec — see §2.
**Blocks:** deck slides 7–8 via I-29.
**Context:** `Gayini_reference_state_methods.md` v2 §5, §7 (L-4), §8, §9.

Standing rules: additive writes only · never re-run the builder · resolve paths from the
database, never hardcode · never merge support levels in one figure · commit to main and push
per gate per CLAUDE.md · re-read this spec in full and echo it verbatim at the start of every
gate.

---

## 1. Spine anchor

| | |
|---|---|
| **Serves** | The deck's central claim, and L-4 in the limitations register |
| **Claim under test** | That Bala 29ca's floor is low **beyond what its water regime predicts** |
| **Why we are doing this** | The floor tracks mean annual inundation across the property. Bala 29ca is the fourth-driest paddock at 8.5% against a grazed median of 28.6%, and the deck's §5 table compares whole paddocks with no adjustment. Separately, the five-period split those numbers use is produced by no script in the repository (I-29), so they cannot currently be reproduced at all. |
| **What would falsify it** | If Bala 29ca's residual is near zero, its low floor is fully explained by dryness and the deck's central slide must be withdrawn. **That is an acceptable outcome and is to be reported as readily as a positive one.** |
| **Spine return** | An annual gap series with a fitted trend, replacing the unreproducible five-period table; and a 64-paddock residual table registered in `dim_headline_number` |

## 2. What changed since v1, and why the framing is different

**v1 called wetness a confound. That was wrong and the wording matters.** T9 tested whether
unmasked open water was depressing the floor and falsified it: wet pixels carry more cover at
every percentile (+24.4 pp at p05), and wet pixels are *under*-represented among the bottom-5%
pixels that set each paddock-year's floor. Inundation greens this floodplain.

So water is not an artefact contaminating the measurement. **Water is the ecological driver of
the floor.** Drier paddocks genuinely carry lower floors because they genuinely carry less
cover in their worst ground. The between-paddock relationship is therefore the main effect, not
noise to be removed, and this task measures **what remains after it** — not whether a
contaminated signal survives cleaning.

Practical consequence: a paddock sitting below its predicted floor is the interesting object.
The residual is the result, not a robustness check on something else.

---

## 3. Gate A — COMPLETE, recorded here for the echo

Ran 28 July, SHA 7fe6808. **Finding: the five-period derivation does not exist.** All 429
tracked text files searched for the five boundary years {1992, 2002, 2012, 2018, 2022}; only
Task J (2018 bank-cut periods) and T12 (DEA sensor eras) carry three or more, and both are
different splits. `T2_gateE_figures.R:106,117` writes a two-window report instead (early ≤1997,
late ≥2013, ±2 pp narrows/widens/holds). Logged as **I-29 (BLOCK)**. Not rebuilt, per instruction.

Do not repeat Gate A. Proceed to Gate B.

---

## 4. Gate B — the annual gap series

**The five-period table is not to be rebuilt as the primary result.** Its boundaries are uneven
(5, 10, 10, 6 and 4 years), undocumented, and of unknown provenance relative to when the data
was seen. Replace it rather than reconstruct it.

### 4.1 Primary output

One gap value per water year, 1988–89 to 2022–23, computed under the pinned definitions from
`dim_headline_number` (PIN 2): **paddock grain, year-first ordering, `mean_of_seasons`.**

For each water year: gap = mean of the reference paddocks' `veg_p05_spatial` minus the median
across the 60 `grazing_excluded = 0` paddocks. Three series:

| series | reference set |
|---|---|
| A | all four reference paddocks |
| B | the three excluding Bala 29ca |
| C | Bala 29ca alone |

For each series report **slope, intercept, r, standard error of the slope, and n**. Use ordinary
least squares on water year. Report the residual series so autocorrelation is visible; **do not
compute a p-value** — 35 consecutive annual observations are not independent and a naive p would
be misleading. If a serial-correlation adjustment is wanted later that is a separate decision.

### 4.2 Sensitivities, reported beneath the primary

The same three series aggregated four ways, to show the boundary choice does not carry the
result:

- deck five-period: 1988–92 / 1993–2002 / 2003–12 / 2013–18 / 2019–22
- equal decades: 1988–96 / 1997–2005 / 2006–14 / 2015–22
- equal thirds: 1988–99 / 2000–11 / 2012–22
- two-window (the one with a script): ≤1997 and ≥2013

Plus the whole of 4.1 repeated under `series_variant = 'jja_son'`.

### 4.3 Predictions to check — NOT targets

Design-seat figures, computed in a chat session with no registration. **Recompute
independently. If your value disagrees, yours stands and the disagreement is the finding.**

| series | predicted slope | predicted r |
|---|---|---|
| A — all four | +0.273 pp/yr | 0.770 |
| B — excluding Bala 29ca | +0.057 pp/yr | 0.222 |

If B holds, the convergence is a single-paddock artefact in the same way the gap is — without
Bala 29ca the gap is not merely small, it is not narrowing either. That would change the deck's
timing slide substantively, not just re-source it.

### 4.4 STOP

Report the three series, the trend statistics, the four sensitivity aggregations, and the
`jja_son` repeat. Do not proceed to Gate C without review.

---

## 5. Gate C — the residual table

### 5.1 Three fits, not one

At paddock grain, 64 paddocks, `veg_p05_spatial` averaged over 35 years against mean annual
`flood_frac_pct` over the same span, `mean_of_seasons`:

1. **Bivariate.** Floor on flood frequency. Continuity with the registered
   `floor_flood_slope_64pdk` (+0.548) and `floor_flood_r_64pdk` (0.710).
2. **With community.** Floor on flood frequency plus dominant community as a categorical.
   This tests whether the relationship is really a community difference wearing a wetness
   coat — Aeolian is dry and low, Inland is wet and high, so the bivariate fit could be
   picking that up.
3. **Within Inland only.** The one community with enough paddocks to fit alone.

**Prediction to check, not a target:** the relationship survives within Inland at roughly
n = 55, slope +0.503, r = 0.680 — close to the pooled fit, which would mean the relationship is
not primarily a community artefact. Verify independently.

### 5.2 The Aeolian problem — read before choosing a model

Assigning each paddock its dominant community gives Inland 55 of 64, Riverine 6, **Aeolian 3**.
Bala 29ca is one of the three. So any community-adjusted residual for Bala 29ca rests on n = 3,
and the community term for Aeolian is estimated from Bala 29ca plus two others.

**This is a real limitation of fit 2 and must be reported alongside it, not discovered later.**
If the Aeolian term is unstable, say so and prefer the bivariate residual with the caveat
stated, rather than reporting a community-adjusted number whose adjustment rests on three
observations including the paddock under test.

Also report, for context, how crude the dominant-community assignment is: the share of each
paddock's pixels falling in its assigned community, and how many paddocks are below 60%.

### 5.3 Primary output

A **64-row table**, one per paddock: name, treatment, mean floor, mean flood frequency,
predicted floor, residual, and rank by residual. Identify explicitly:

- the four reference paddocks
- **Dinan 10** — grazed, 5.1% inundation, 40.4% floor. Bala 29ca's apparent near-twin on
  wetness. If both sit at similar residuals, a dry grazed paddock and a dry ungrazed paddock
  are behaving the same way, which is itself the answer to the deck's question.

Report the residual standard deviation so a reader can judge whether any individual residual is
large.

### 5.4 The one number this task exists to produce

Bala 29ca's residual, with its standard error, from the model chosen in 5.2. State it plainly
next to the raw −42.3 pp gap the deck currently reports, and say what fraction of that gap
survives.

### 5.5 STOP

Report all three fits, the diagnostic on the Aeolian term, and the 64-paddock table.

---

## 6. Gate D — register

Additive rows into `dim_headline_number` for: the three annual trend slopes and r values, the
chosen regression's slope and r, Bala 29ca's residual, and Dinan 10's residual. Every row
carries `spread_min`/`spread_max` from the sensitivities in 4.2 and the alternative fits in
5.1, per the T8 pattern.

Update the three PIN 3 rows — `bala29ca_floor_gap_periodwise`,
`bala29ca_floor_gap_periodwise_jja_son`, `ref_grazed_floor_gap_3pdk_periodwise` — setting
`decision_note` to record that they are superseded by the annual trend and naming the
superseding `number_id`. **Leave `pinned_value` NULL.** They are not to be revived.

Extend `test_T8_headline_reproduction.py` to cover the new rows. It stays standalone and is not
wired into the smoke test (I-19).

---

## 7. Acceptance criteria

- [ ] Three annual series, 35 values each, with slope, r, SE and n
- [ ] Four sensitivity aggregations plus the `jja_son` repeat
- [ ] The two Gate B predictions independently recomputed, agreement or disagreement stated
- [ ] Three fits at Gate C, with the Aeolian n = 3 limitation reported
- [ ] Dominant-community assignment quality reported
- [ ] 64-paddock residual table, reference paddocks and Dinan 10 identified
- [ ] Bala 29ca's residual stated against the raw −42.3 pp gap
- [ ] New rows in `dim_headline_number` with spreads; PIN 3 rows annotated, still NULL
- [ ] Reproduction test extended and passing; fires on a broken fixture
- [ ] No builder run, no registered row deleted, no rename
- [ ] Change report in `docs/change_reports/`

## 8. Exit condition

Review bundle `Output/review_bundles/reference_state_T10_residuals.zip` containing: the annual
series as CSV, the 64-paddock residual table as CSV, the trend and regression statistics, the
Gate B/C/D change reports, and a before/after table for any `dim_headline_number` row whose
value changes.

If Gate C shows Bala 29ca's residual is near zero, **say so in the change report headline**.
A null here withdraws the deck's central claim, and that needs to be the first thing read, not
a conclusion buried under the method.
