# T8 Gate B / C / D — `dim_headline_number`, reproduction test, `is_rollup`

**Task:** reference-state T8, per `T8_gateA_pin_decisions.md` v1 (auth) > `T8_T9_T10_gateA_decisions.md` v1 > spec v1.
**Date:** 28 July 2026 · **Prior:** SHA f9c62ba (sixth-pin STOP)
**Sixth pin answered:** #9 **AREA-WEIGHTED**. Gate B proceeded.
**Additive only:** new table, view recreated with one added column (rows unchanged), two additive columns on an existing table. No builder run, no row deleted, no rename.
**Verification:** live query / reproduction-test output below.

Session start: on `main`, up to date with `origin/main`, main has not moved.

---

## Gate B — `dim_headline_number` (35 rows, additive)

Built by `scripts/11_database/build_T8_gateB_dim_headline_number.py`. Schema per spec, **with two deviations both required by the amendments:**

- **`pinned_value` is NULLABLE** (spec said NOT NULL). PIN 3 requires the three periodised numbers to be written with `pinned_value` NULL and a blocked note — the NOT NULL constraint would forbid exactly what PIN 3 asks. `spread_min`/`spread_max` are populated on every non-NULL row (0 missing).
- **Added `support_level` and `caveat` columns** to reuse `v_presentation_headlines_live` semantics (decisions §2). *Place the two objects disagree:* `v_presentation_headlines_live.source_artefact` is an **output file path**; `dim_headline_number.source_object` is a **DB view/table name** — deliberately different (these numbers are re-derived from DB objects, not read from files).

The catalogue's 18 numbers expand to **35 scalar rows** (vector numbers — by-community, by-band, by-arm — become one testable row each). Pins applied:

- **PIN 2 (#1):** `ref_grazed_floor_gap_4pdk_1988_92` = **−13.1**, `spread_min` −14.8 / `spread_max` −9.1; jja_son −11.2 recorded as a sensitivity in the caveat, same number_id.
- **PIN 1 (#6/#7):** ref-grazed by community pinned to the **band mean** (ALL rollup retired). #6/#7 agree within ≤0.7 pp equal-vs-area; pinned area-weighted for consistency with #9.
- **PIN 1 + sixth pin (#9):** three-arm floor deficit pinned **area-weighted** = −0.9 / +1.2 / +1.3; equal-weighted −4.8 / +4.3 / +5.9 recorded as spread endpoints with the over-weighting note.
- **PIN 3 (#2/#3/#4):** `pinned_value` NULL, `decision_note` = "BLOCKED on I-29; superseded by T10 Gate B annual trend."
- **PIN 5 (#17):** split into `unzoned_inside_mapped_ha` (12,150.1), `property_outside_mapped_ha` (18,561.5), `total_no_management_zone_ha` (30,711.6, derived).
- **PIN 4 (#5):** `bala29ca_ref_plot_share_pct` = 54.17 (13/24), source now `plot_paddock`.
- **#17 regression:** independently recomputed (`floor_flood_slope_64pdk` +0.548, `floor_flood_r_64pdk` +0.710), `decided_by` CC per §3a — **not reconciled** to the chat figure; T10 Gate B re-registers with SE.

### PIN 1 materially changes deck slide 10 — stated explicitly

Retiring the `ALL` rollup roughly **halves the floor deficits** (`Output/tables/T8_before_after.csv`):

| number | deck (ALL rollup) | pinned (band mean) | delta |
|---|---|---|---|
| ref_grazed_floor_aeolian | −19.6 | **−10.5** | +9.1 |
| ref_grazed_floor_riverine | −11.7 | **−4.5** | +7.2 |
| ref_grazed_floor_inland | +1.1 | +1.1 | −0.0 |
| ref_grazed_mean_cover_riverine | −0.8 | **+1.4** | +2.2 |

The pooled `ALL` row reintroduces the drier-skew confound `T6_gateB_extract.R` designs out (reference paddocks sit in drier bands than their comparators), so the deck's larger deficits were partly that confound.

### Sixth pin consequence — the "no ordering" result is stronger

Area-weighted, the three management arms sit **within ~2 pp of each other** on the floor (−0.9 / +1.2 / +1.3) versus the deck's −4.8 / +4.3 / +5.9. Equal weighting handed the n=1 Aeolian stratum (Bala 29ca alone, 7.8% of area, largest deficits) a third of a property-level number — the same mechanism PIN 1 rejected in the `ALL` rollup. **"Grazing intensity does not register" is now a stronger claim, and the ordering survives either weighting.** The consistency claim moves to the weighting-free counts: inferred-standard ≥ 14-day in **6 of 9** strata, plot-confirmed **8 of 9**.

---

## Gate D — `is_rollup` on `v_three_arm_gap_decomposition`

The view was a trivial passthrough (`SELECT * FROM fact_three_arm_gap_decomposition`); recreated as `SELECT *, CASE WHEN regime_band='ALL' THEN 1 ELSE 0 END AS is_rollup`. **Rows unchanged: 144 → 144; `sum(is_rollup)` = 36** (the 3 communities × 4 arms × 3 windows of `ALL` rows). `decision_note` on the affected `dim_headline_number` rows records that the `ALL` rows are not for treatment contrasts. No rows deleted.

## PIN 4 — paddock identity added, deck confirmed

`plot_management_overlay` gained additive `zone_fid` / `zone_name`, populated from the verified `plot_paddock` join (`Output/tables/T8_pin4_plot_paddock.csv`). Populated for **48 / 66** plots (the 18 unmatched are outside the zone layer — the standard-grazing set). Reference plots per paddock: Bala 26ca 3, 28ca 8, **29ca 13**, 27ca 0 = 24. **"13 of 24 (54%)" confirmed by an independent centroid-in-polygon join (9473→8058), 0 mismatch vs `plot_paddock`.**

## PIN 5 — the 29 ha resolved

194,865 unzoned-inside pixels × **0.062351428** (`gayini_params.PIXEL_AREA_HA`, derived) = **12,150.1 ha** (correct); × 0.0625 (nominal 25 m) = 12,179.1 ha — the T1-spec figure rode in on the `0.0625` error (C-08). Three disjoint numbers now exist; **30,712 ha (35.7% of the property) is in no management zone** — new to deck and methods (design-seat action to add).

---

## Gate C — reproduction test (drift guard)

`scripts/11_database/test_T8_headline_reproduction.py` re-derives each pinned number from its `source_object` under the recorded qualifiers (independent code path) and asserts equality within tolerance (0.05 pp; 1 ha for areas; exact for counts; 0.005 for slope/r). Blocked NULL rows skipped.

```
$ python scripts/11_database/test_T8_headline_reproduction.py
T8 reproduction: PASS - all 32 pinned numbers reproduce within tolerance   (exit 0)
```

**Every check must be able to fail — demonstrated.** `--break` copies the DB, corrupts one pinned value by +5, and runs against the copy (real DB untouched):

```
$ python scripts/11_database/test_T8_headline_reproduction.py --break
[--break fixture] checked 32; DRIFT rows: 1
   DRIFT  ref_grazed_floor_gap_4pdk_1988_92: pinned=-8.07 recomputed=-13.07
```

The drift is caught. **Not wired into `run_spine_smoke_test.R`** — per I-10/I-11 the smoke test has inverted-polarity / permanently-red checks and must not be modified to force a hook; this test runs standalone and exits non-zero on drift, suitable for the `lint_guardrails.py` acceptance path. Wiring is a post-deadline T5 item (I-19).

---

## Acceptance / invariants
- `dim_headline_number`: 35 rows, 3 pinned-NULL (blocked), spread non-null on all pinned rows.
- `v_three_arm_gap_decomposition`: 144 rows (unchanged), `is_rollup` present, sum 36.
- `plot_management_overlay`: additive `zone_fid`/`zone_name`, 48/66 populated.
- Reproduction test passes (32/32) and fires on a broken fixture.
- No builder run; no registered row deleted/modified; no rename. Idempotent (INSERT OR REPLACE; ADD COLUMN guarded).
- Review bundle built (exit condition) — see `Output/review_bundles/reference_state_T8_headline_number/`.

## Sequencing note
Per the design-seat sequencing change, **this stream stops here.** T10 Gate B, T7 and T11 are **not** started — they are reference-state-only and no client deliverable (the 66 site + 21 paddock reports due 10 August) depends on them. T8 was finished now because the 21 paddock reports will quote paddock-level floor numbers from these same objects; pinning before they are built is cheaper than after.
