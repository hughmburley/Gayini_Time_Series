# T13 — Which country is coming back, and which is going backwards

**Version:** v1 · 29 July 2026
**Spine:** `Gayini_path_to_Aug10_tracker.xlsx`, Tasks sheet
**Depends on:** REG-1 Gate C (`fact_zone_community_part_summary`, 115 parts), T10 (complete)
**Blocks:** nothing. **Time-limited:** see §1.
**Context:** `Gayini_learning_L01_unit_of_analysis.md`,
`Gayini_locating_results_in_country_note.md`, `Gayini_reference_state_methods.md` §9

Standing rules apply. Re-read this spec in full and echo it verbatim at the start of every gate.

---

## 1. Why this runs now

The classification below uses only satellite cover and water. If it is fixed **before** the
land-use history arrives from Ernest, then testing whether the recovering parts turn out to be
the formerly-cropped ones is a blind test. Once the labels exist, every threshold choice is
open to the charge that it was tuned, and there is no way to prove otherwise.

That is the entire reason for the timing. Nothing else on the board degrades if it slips.

## 2. Pre-registration — read before writing any code

**Everything in §5 and §6 is fixed now and must not change after any result is seen.** If a
threshold turns out to be awkward, that is reported as a finding, not adjusted.

**Declaration of contamination.** A pilot scan was run at the design seat on 28 July using
hand-chosen cuts (8 pp on level, 0.25 pp/yr on trend). It produced 7 recovering, 17 persistently
poor, 8 declining, 83 unremarkable. **Those cuts are abandoned.** They were chosen after seeing
the data, which is the defect this spec exists to avoid, and they are recorded here only so that
nobody later mistakes a rule tuned to reproduce them for an independent one.

The rule in §5 is deliberately different in kind — scaled to each community's own spread rather
than a fixed percentage-point value. **If it produces a materially different set from the pilot,
the new result stands and the difference is reported.** Do not reconcile to 7.

**The primary output is continuous, not categorical.** The four states in §6 are a labelled
convenience for the map and the client text. The registered result is the pair of continuous
measures per part. This means the headline does not depend on any threshold at all.

## 3. Gate A — annual flood at part grain · STOP

**This does not exist and must be built.** `fact_zone_community_veg_annual` carries no wet or
valid columns, and `census_by_zone_stratum` holds only a static 35-year flood frequency. Without
an annual series at part grain, a part that is simply getting wetter is indistinguishable from
one recovering — the confound T10 removed at paddock grain, and Bala 29ca is the only reference
paddock whose own flood frequency is rising.

Extract wet and valid annual counts at **paddock × community × water year**, using the same
pixel set, encoding and support rule as `T2_gateB_extract.R`: the 795,602 in-scope zoned
census centroids, `valid_any == 1`, `wet_any == 1`, `n_pixels_valid >= 30`.

This is the existing T2 Gate B extraction with one additional grouping key. **Do not re-run the
builder. Do not modify `fact_zone_community_veg_annual`** — write a new additive table.

**Reconciliation check:** summing the new part-grain wet and valid counts across communities
within a paddock-year must reproduce `fact_zone_veg_annual.wet_pixels` and `valid_pixels` for
that paddock-year. Report the maximum absolute difference. **Expected: 0.** A non-zero difference
means the part grain does not partition the paddock and must be reported, not absorbed.

**STOP.**

## 4. Gate B — the continuous measures

For each of the 115 parts, using `mean_of_seasons`, ≥25 years, `n_pixels_valid >= 30`:

| measure | definition |
|---|---|
| `level` | mean `veg_p05_spatial` over the record |
| `level_dev` | `level` minus the median `level` of all parts in the same community |
| `level_z` | `level_dev` divided by the SD of `level_dev` within that community |
| `trend_raw` | OLS slope of annual `veg_p05_spatial` on water year |
| `water_slope` | OLS slope of annual `veg_p05_spatial` on that part's own annual flood fraction |
| `trend_adj` | slope of the residuals from `water_slope` on water year — the trend after removing the part's own water response |
| `trend_dev` | `trend_adj` minus the median `trend_adj` of all parts in the same community |
| `trend_z` | `trend_dev` divided by the SD of `trend_dev` within that community |

Report SE on both slopes. **No p-values** — 35 consecutive annual observations are not
independent, and a naive p would overstate significance. Report the residual series so the
autocorrelation is visible.

**Report, do not work around:** parts whose own flood fraction barely varies across the record,
where `water_slope` is estimated from negligible variance and the adjustment is meaningless.
Give the within-part SD of flood fraction on every row and flag any part below 2 pp.

**Also run the current-year and one-year-lagged water specifications** and report which fits
better for how many parts. At paddock grain the lag beat current for only 18 of 64; if the part
grain differs materially, say so — it is a finding about the system. **Current-year remains
primary regardless**, so the choice is declared in advance and not made on the result.

## 5. Gate C — the classification rule, PRE-REGISTERED

**Cut: ±1.0 on both z-scores.** Conventional, declared before any output is seen, and scaled to
each community's own spread rather than a fixed pp value that means different things in Aeolian
and Inland.

| | `trend_z` ≥ +1.0 | otherwise |
|---|---|---|
| `level_z` ≤ −1.0 | **Recovering** | **Persistently poor** |
| `level_z` > −1.0 | Unremarkable | **Declining** if `trend_z` ≤ −1.0, else Unremarkable |

**Mandatory sweep.** Report the four counts at cuts **0.50, 0.75, 1.00, 1.25, 1.50**, as a
table. The 1.00 result is the registered one; the sweep exists so a reader can see how much the
cut carries. **If the composition of the recovering set changes substantially across the sweep,
that is the headline finding about the method's stability and must be stated as such.**

**Robustness.** Re-run the whole classification excluding the two wettest water years and report
which parts change state. A classification that survives dropping the two biggest floods is worth
considerably more than one that does not.

**STOP** before Gate D.

## 6. Gate D — the map

The four states drawn on the paddock-part polygons. **This is the deliverable** — the most
directly usable thing this stream produces for a land manager: here is country coming back, here
is country going backwards, here is country that has always been poor.

Requirements: paddock boundaries drawn and labelled · the four reference paddocks distinguished ·
north arrow and scale bar · deck palette, not viridis · a companion panel showing the continuous
`level_z` against `trend_z` as a scatter, so the classification and the underlying measures sit
side by side · caption stating the cut, the sweep range, and that the states are a labelling of
continuous measures rather than categories in the data.

Second figure: the same map at the **0.75 and 1.25** cuts, small multiples, so the sensitivity is
visible rather than asserted.

**Naming.** Parts are places. Client text says *"the drier western part of Bala 29ca"*, not
*"the Aeolian part"* and never *"the low level_z part"*. Per
`Gayini_locating_results_in_country_note.md` §6.

## 7. Gate E — register and bundle

Additive: the part-grain flood table, a `fact_zone_community_part_classification` carrying both
continuous measures and the state at each swept cut, and rows in `dim_headline_number` for the
four counts at the registered cut with the sweep range as spread. Figures via
`write_and_register_figure()`. Extend the reproduction test.

Exit bundle `t13_paddock_part_classification.zip`: the classification table, the sweep table, the
robustness comparison, both figures, and the gate reports.

## 8. What this is not

It is **not** a management analysis. Nothing in the classification refers to grazing, zones or
treatment, deliberately — so that management can be tested *against* it later rather than
assumed by it. Any cross-tabulation with treatment is a separate task with its own gate.

It is **not** evidence of cause. A part that is low and rising has been through something. What,
and whether anyone did it, this cannot say.

## 9. Acceptance

- [ ] Part-grain annual flood table built; reconciliation to `fact_zone_veg_annual` reports max diff 0
- [ ] 115 parts with both continuous measures, SEs, flood-variance flags, lag comparison
- [ ] Classification at the pre-registered ±1.0 cut, plus the five-point sweep
- [ ] Robustness run excluding the two wettest years, with state changes listed
- [ ] Map at the registered cut, plus small multiples at 0.75 and 1.25
- [ ] Continuous scatter panel alongside the classified map
- [ ] Registered; reproduction test extended and firing on the fixture
- [ ] No builder run, no existing object modified, no p-values anywhere
