# T10 Gate D — register the trends, residuals, temporal arm, and per-community decomposition

**Task:** T10 v2 §6 + amendment A1, and the design-seat additions on the Gate C acceptance.
**Date:** 28 July 2026 · **Prior:** SHA acc1365 (Gate C)
**Scope:** Gate D — additive registration + reproduction-test extension + exit bundle. STOP after.
**Verification:** live builder output + reproduction-test run below. All pinned values computed live.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Headline (carry it with the numbers)

The reference-state result reduces to one paddock, and that paddock's recovery is real and largely non-hydrological — **but it is not unique, not uniform across the reference set, and not large against the within-group spread.** Registered so the qualifiers travel with the number.

---

## The three design-seat additions — all reproduce exactly, all now registered

1. **Two of four reference paddocks are declining relative to their water:** Bala 26ca **−0.109**, 27ca **−0.337**, 28ca +0.080, 29ca +0.556 (adjusted floor trend, pp/yr). Registered: `t10_ungrazed_median_adj_trend` **−0.014** with the within-ungrazed range (−0.337 … +0.556) in the caveat.
2. **The strongest improver-beyond-water is grazed:** Bala 15 **+0.646** > Bala 29ca +0.556; Mara 1 +0.522. Noted on `t10_grazed_median_adj_trend` **−0.151**.
3. **Group medians read against within-group spread:** ungrazed −0.014 vs grazed −0.151 — a 0.14 pp/yr between-group difference against a −0.337…+0.556 within-ungrazed range. Both registered so the difference cannot be quoted without its spread.

## The new computation — the recovery is *located* (all predictions reproduced to the decimal)

Bala 29ca's floor trend decomposed by community (`fact_zone_community_veg_annual`, min 30 px/cell):

| community | 29ca level vs community median | rank | 29ca floor trend | property median trend |
|---|---|---|---|---|
| Aeolian | **−32.1** | 1/17 | **+0.560** | +0.222 |
| Riverine | **−24.9** | 2/37 | **+0.564** | −0.282 |
| Inland | −5.8 | 10/61 | −0.216 | −0.211 |

The recovery is in Bala 29ca's **dry western thirds** (Aeolian, Riverine — both starting lowest/near-lowest in their community and rising), while its **Inland third tracks the property median exactly** in both level (−5.8, rank 10/61) and trend (−0.216 vs −0.211). This makes the disturbance question specific and ground-checkable: **was the drier western part of Bala 29ca cleared or cropped**, not the paddock as a whole.

**Reference-set composition** (registered `t10_refset_inland_share_*`): Bala 26ca 98.1% Inland, 27ca 100%, 28ca 83.1%, 29ca 34.6% (33.1 Riverine / 32.3 Aeolian). Inland is the property's highest-floor community (median 73.1 vs Aeolian 61.5, Riverine 59.5), so **three of four reference paddocks sit almost entirely in the easiest community; only Bala 29ca spans the property's range** — and it is the one showing the recovery, in its hard-community parts.

## Registered rows (24 new; 2 re-registered; 3 annotated)

`dim_headline_number`: **35 → 59 rows.** New `t10_*`: three annual trend slopes + r (A/B/C, spread from `jja_son`); Bala 29ca and Dinan 10 cross-sectional residuals; the water-adjusted floor trend **+0.556 (spread [0.556, 0.678] current↔lagged, SE 0.126)** — the number that decides the claim; Bala 29ca raw floor trend / water slope / flood trend; six per-community rows; two group medians; four composition shares.

- **Chosen regression re-registered** (per T8's recorded intent "T10 re-registers"): `floor_flood_slope_64pdk` gains spread **[0.498, 0.548]** (bivariate / +community / within-Inland), `floor_flood_r_64pdk` **[0.680, 0.710]**. **Pinned values unchanged (0.548 / 0.710)** — so there is no before/after value change to report (exit §8): the T10 rows are all new, and the only edits to existing rows are added spread and appended notes.
- **PIN 3 rows annotated, still NULL:** `bala29ca_floor_gap_periodwise`, `_jja_son`, `ref_grazed_floor_gap_3pdk_periodwise` → `decision_note` = "SUPERSEDED by T10 Gate B annual trend `t10_gap_annual_slope_{C_29ca,B_excl29ca}`. Not to be revived." `pinned_value` untouched.

## Gate C reproduction test extended

`test_T8_headline_reproduction.py` gains `recompute_t10()` — an independent re-derivation of every reproducible T10 row.

```
$ python scripts/11_database/test_T8_headline_reproduction.py
T8 reproduction: PASS - all 56 pinned numbers reproduce within tolerance   (exit 0)
$ python ... --break
[--break fixture] checked 56; DRIFT rows: 1   (drift caught; real DB untouched)
```

Stays standalone, not wired into the smoke test (I-19 / I-10 / I-11).

## Exit bundle

`Output/review_bundles/reference_state_T10_residuals.zip`: annual series CSV (+ jja_son), the 64-paddock cross-sectional residual table, the 64-paddock temporal table, the per-community table, trend/regression statistics, the `dim_headline_number` T10 rows exported, and the Gate B/C/D change reports. **No before/after value-change table** — no existing pinned value changed (stated above, per the exit-condition "say so rather than shipping it" rule).

## Invariants
- Additive: 24 new rows via INSERT OR REPLACE; 2 rows re-registered (spread/note only, values unchanged); 3 PIN 3 rows annotated (pinned_value NULL untouched). No builder run, no row deleted, no rename. Idempotent.
- The producing scripts are tracked — the annual trend (Gate B) and the residual/temporal arms (Gate C) now have scripts, closing the I-29 "no script" defect for everything that supersedes the five-period table.

## Correction (design-seat review, independently verified) — withdrawing the "twin separation" flag

My Gate C/D closing flag — that the temporal arm "cleanly separates the genuinely-recovering ungrazed paddock from its grazed dry twin, the sharpest management-relevant contrast the project has produced" — **is withdrawn.** It does not survive decomposition, and it is exactly the error L-01 warns about (`Gayini_learning_L01_unit_of_analysis.md`): a paddock-grain claim lifted from an average over unlike country.

Decomposed by shared community (trend as deviation from that community's property-median trend; all figures reproduced to the decimal):

| community | Bala 29ca (ungrazed) | Dinan 10 (grazed) |
|---|---|---|
| Riverine | +0.845 | **+0.737** |
| Aeolian | **+0.339** | +0.000 |
| Inland | −0.005 | **+0.143** |
| composition (I/R/A) | 34.6 / 33.1 / 32.3 | 27.9 / 7.0 / 65.1 |

Their **Riverine country behaves almost identically** — both recover strongly, one grazed, one not. Across the three shared communities they are near-identical in one, Bala 29ca leads in one, and **Dinan 10 leads in the third.** The paddock-level separation (+0.556 vs +0.020) is **composition, not behaviour**: Bala 29ca is a third Riverine — the community where both paddocks recover strongly — while Dinan 10 is 7% Riverine and 65% Aeolian, where it tracks the community median to three decimals; its whole-paddock average is dominated by country doing exactly what its neighbours do.

**Restated:** *Comparable country in the two paddocks behaves comparably; the paddock-level difference is composition. Bala 29ca's Aeolian third is the one part that differs from its grazed counterpart* (+0.339 vs +0.000) — a genuine like-for-like difference, but one paddock against one paddock in one community, and to be stated that way, not as a management contrast.

The paddock-grain numbers registered above are correct and correctly registered; it is the claim built on top of them that was wrong. This is L-01 recurring on the project's own flagship contrast — and the reason the substrate below now exists.

## Substrate — the full paddock-parts table (report/bundle only, not registered)

`Output/tables/T10_gateC_percommunity.csv` extended from 3 rows to **all 115 paddock-parts** (every paddock × community with ≥25 years and ≥30 px/cell). Per part: level, level vs community median + rank, trend, trend vs community-median trend, treatment, and the paddock's I/R/A composition shares. Community part counts: Aeolian 17, Riverine 37, Inland 61. **Not classified, not thresholded, not registered** — thresholds are pre-registered T13 decisions, not this task's. This is the table the flag-check needed and the substrate T13 will build on.

## STOP
Gate D complete; the closing flag corrected and the paddock-parts substrate delivered. Waiting for review. **Reference-state stream closes after this until after 10 August** (T7, T11 not started).
