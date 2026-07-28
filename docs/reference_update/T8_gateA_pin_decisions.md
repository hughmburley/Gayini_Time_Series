# T8 Gate A — pin decisions

**Version:** v1 · 28 July 2026
**Amends:** `Gayini_reference_state_specs_T7_T11.md` v1, `T8_T9_T10_gateA_decisions.md` v1
**Responds to:** T9 addendum + T8 Gate A session, SHA ec81bdc

T9 addendum accepted — L-3 closed by direct measurement. T8 Gate A accepted, spread table
accepted. Five pins below. **Pin 1 changes deck numbers materially; read it first.**

---

## PIN 1 — `regime_band='ALL'` vs band mean (#6, #7, #9)

**Pin the BAND MEAN. Retire the `ALL` rollup from every treatment contrast.**

The `regime_band='ALL'` row pools across wetness bands. Pooling is precisely what the
stratification exists to prevent: `T6_gateB_extract.R` line 3 states wetness is controlled by
construction and the Gate A drier-skew confound is designed out. Taking the pooled row for a
treatment contrast reintroduces the confound the design removed.

The direction of the spread confirms this rather than being incidental. Pooled gives Aeolian
−19.6 and Riverine −11.7; band mean gives −11.2 and −4.4. The pooled version **inflates** the
reference deficit, which is exactly the signature of reference paddocks sitting in drier bands
than their comparators. That is the confound, visible in the spread.

**This roughly halves the mean-versus-floor numbers on deck slide 10.** That is a real change
to a headline, not a rounding adjustment, and it must be reported as such in the change report.

Two sub-questions for Gate B:

- Report the band mean **both equal-weighted across the three bands and area-weighted**. Either
  is defensible — both average already-controlled within-band deficits, so neither
  reintroduces confounding — but if they differ by more than 1 pp that difference becomes a
  sixth pin and should come back here before Gate B writes.
- The `ALL` rows stay in the view. Flag them with `is_rollup` per the original Gate D and
  record in `decision_note` that they are not to be used for treatment contrasts.

---

## PIN 2 — grain, order and variant (#1)

**Pin: zone grain · year-first · `mean_of_seasons`.**

- **Zone grain**, because the claim's unit is the paddock. "Three of the four reference
  paddocks are indistinguishable from grazed ground" is a statement about paddocks. The
  zone × community grain splits a paddock into pieces and re-weights toward paddocks that
  span more communities, which is a different question.
- **Year-first** — median across the 60 grazed paddocks within each year, then averaged over
  the period. The deciding argument is consistency with the figures: the grey comparator band
  on T2_E, T6_A and T6_B is computed per year. A headline that uses a different order from the
  figure beneath it is the failure this task exists to fix.
- **`mean_of_seasons`** primary; register `jja_son` as a sensitivity on the same `number_id`
  rather than as a separate number.

This pins #1 at **−13.1 pp**, the value the deck reports, with `spread_min` −9.1 and
`spread_max` −14.8 recorded.

---

## PIN 3 — periodisation (#2, #3, #4) — DEFER, MARK BLOCKED

**Do not pin these.** Write the rows with `pinned_value` NULL and a `decision_note` of
"BLOCKED on I-29; superseded by T10 Gate B annual trend."

Pinning a value whose producing script does not exist would defeat the purpose of the table.
These three numbers are replaced, not fixed, when T10 Gate B lands.

---

## PIN 4 — provenance gap (#5, "13 of 24 in Bala 29ca") — RE-DERIVE, DO NOT PIN YET

`plot_management_overlay.source_feature_id` holds the treatment **class**, not the paddock, so
the number is not re-derivable as CC found. This is a genuine provenance gap on a number that
appears on deck slide 5 and is annotated onto the `T2_G` figure.

Small task, before Gate B writes:

> Spatially join the 66 plot centroids from `plots_current_summary` (reproject from EPSG:9473
> per the standing CRS rule) against `management_zones`, and report the count of reference
> plots per reference paddock.

**Report whatever the join returns. Do not target 13.** If the answer differs, that is a
finding and both the deck slide and the T2_G figure annotation are wrong. Add the paddock
identity to the overlay table as an additive column so the number is derivable in future.

---

## PIN 5 — conflated "missing area" — SPLIT INTO TWO NUMBERS

Not one number with a caveat. Two `number_id` rows, with labels that cannot be confused:

| label | value | source |
|---|---|---|
| Unzoned area inside the mapped census | 194,865 px · 12,150 ha · 18.0% of mapped | `census_by_zone_stratum`, `zone_fid IS NULL` |
| Property area outside the mapped census | 18,562 ha · 21.6% of property | 85,911 ha stated property minus 67,349 ha mapped census |

They are disjoint by construction. **Add a third derived row: total property in no management
zone, 30,712 ha, 35.7%.** Over a third of the property is in no paddock, and that figure
appears nowhere in the deck or the methods document. It belongs in both.

One discrepancy to resolve while pinning: the T1 spec states 12,179 ha for the unzoned area;
`census_by_zone_stratum` sums to 12,150 ha. A 29 ha difference, almost certainly a pixel-area
constant. Resolve it against the derived constant in `gayini_params` and record which is
correct — this is exactly the class of drift the pin exercise is meant to catch.

---

## Next

**Go for T10 Gate B+C.** Independent annual-trend fit, no reconciliation to the chat
regression, 64-paddock residual table as the headline output. I-29 blocks deck slides 7–8, so
this is the critical path to 10 August.

Order: PIN 4 join (small) → T8 Gate B → T10 Gate B+C → T7 → T11.

My two remaining predictions are still unchecked and remain predictions: annual gap trend
+0.273 pp/yr r=0.770 across all four reference paddocks, and +0.057 pp/yr r=0.222 excluding
Bala 29ca. If the second holds, the convergence is a single-paddock artefact in the same way
the gap is, and the deck's timing slide needs rewriting rather than re-sourcing.
