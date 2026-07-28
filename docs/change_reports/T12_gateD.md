# T12 — Gate D · cultivation assessment (classification)

**Task:** T12 — DEA Land Cover Level 3 extraction, spec **v4** §2.4 + §2.5, `rule_version = 'T12_prereg_v2_20260728'` (v4 is numeric-only; the rules are the v2 pre-registration, unchanged).
**Date:** 28 July 2026
**Writes:** additive — `fact_dea_cultivation_assessment` (320 rows = 64 zones × 5 classified eras) and read-only view `v_dea_zone_landuse_summary`. **No threshold moved, no rule reinterpreted.** `dim_management_zone` history NULL 64/64 (verified). Idempotent (320→320).
**Script:** `scripts/11_database/build_T12_gateD_assessment.py`.

> **Reported exactly as the pre-registered rule produced it. Nothing was tuned to the fact that Gate C looked decisive, and nothing was tuned to suppress false positives.** A pre-registered rule false-positiving on this layer is itself the finding.

---

## 1. `dea_cultivation_class_final` counts by era

| era | indeterminate | no_evidence | possible | **likely** |
|---|---|---|---|---|
| 1988–1992 | 64 | – | – | – |
| 1993–2002 | 64 | – | – | – |
| 2003–2012 | 64 | – | – | – |
| **2013–2018** | 9 | 32 | 22 | **1** |
| **2019–2022** | 9 | 36 | 18 | **1** |

- **1988–2012 (all three eras): every zone `dea_indeterminate`** — each era overlaps the §2.6 suspect window (1988–2012, all suspect-flagged) for >50% of its years. The window the task exists for is, by the pre-registered rule, uninterpretable.
- **Only 2013–2018 and 2019–2022 survive** the §2.4 indeterminate rule (as anticipated).
- The **9 indeterminate** zones in those two eras are the paddocks with **< 3,000 DEA pixels** (§2.4): Bala 7/10, Bala 9, Mara 4, Mara 5a, Mara 8, Mara 13, Mara 18, Mara 20, Mara 22a. *(Note: Mara 20 — the pilot's 63.6 pp headline — is 1,667 px, so it lands `indeterminate` here, not `likely`. The rule as written excludes it.)*

## 2. Every zone reaching likely / possible (pre-downgrade), named

Both windows are periods of **known-zero cultivation**, so every row below is a **false positive** of the pre-registered rule.

| zone | era | excess pp | maxc≥30 | mean CTV | corr_flood(A) | corr_veg(A) | downgraded | class |
|---|---|---|---|---|---|---|---|---|
| **Mara 17** | 2013–2018 | 40.2 | 4 | 42.3 | −0.13 | 0.25 | 0 | **likely** |
| **Bala 6** | 2019–2022 | 26.6 | 4 | 52.8 | −0.04 | 0.07 | 0 | **likely** |
| Dinan 14 | 2019–2022 | 50.3 | 2 | 54.1 | 0.14 | −0.02 | 0 | possible |
| Mara 6 | 2013–2018 | 41.0 | 3 | 41.2 | −0.22 | 0.16 | 0 | possible |
| Mara 22 | 2013–2018 | 39.3 | 2 | 41.7 | 0.27 | 0.15 | 0 | possible |
| Mara 7 | 2013–2018 | 39.1 | 3 | 43.1 | −0.02 | 0.20 | 0 | possible |
| Mara 3 | 2013–2018 | 38.8 | 3 | 39.9 | −0.09 | 0.18 | 0 | possible |
| Dinan 3 | 2019–2022 | 36.6 | 2 | 44.5 | 0.29 | 0.27 | 0 | possible |
| Bala 21 | 2013–2018 | 36.0 | 2 | 36.4 | −0.35 | −0.11 | 0 | possible |
| Bala 17 | 2013–2018 | 35.7 | 2 | 42.5 | 0.10 | 0.21 | 0 | possible |
| Mara 6 | 2019–2022 | 34.5 | 2 | 34.7 | −0.22 | 0.16 | 0 | possible |
| Bala 19 | 2013–2018 | 33.3 | 4 | 37.0 | −0.08 | 0.13 | 0 | possible |
| Mara 15 | 2013–2018 | 32.6 | 3 | 39.8 | −0.16 | 0.09 | 0 | possible |
| Bala 2 | 2019–2022 | 32.6 | 2 | 57.1 | 0.08 | 0.17 | 0 | possible |
| Dinan 8 | 2019–2022 | 32.4 | 2 | 44.3 | 0.34 | 0.37 | 0 | possible |
| Dinan 14 | 2013–2018 | 31.4 | 4 | 35.2 | 0.14 | −0.02 | 0 | possible |
| Mara 9 | 2013–2018 | 30.6 | 3 | 36.0 | 0.08 | 0.16 | 0 | possible |
| Bala 17 | 2019–2022 | 30.3 | 2 | 37.1 | 0.10 | 0.21 | 0 | possible |
| Bala 19 | 2019–2022 | 28.7 | 2 | 32.5 | −0.08 | 0.13 | 0 | possible |
| Mara 19 | 2019–2022 | 27.3 | 2 | 28.9 | 0.11 | −0.07 | 0 | possible |
| Dinan 4 | 2013–2018 | 27.2 | 2 | 36.9 | 0.13 | 0.41 | 0 | possible |
| Bala 27ca | 2019–2022 | 25.9 | 2 | 39.5 | −0.00 | 0.25 | 0 | possible |
| Bala 1 | 2019–2022 | 25.9 | 2 | 41.8 | 0.12 | 0.30 | 0 | possible |
| Dinan 9 | 2013–2018 | 25.2 | 3 | 35.9 | 0.26 | 0.33 | 0 | possible |
| Dinan 1 | 2013–2018 | 25.0 | 4 | 28.1 | 0.29 | 0.32 | 0 | possible |
| Dinan 11 | 2019–2022 | 24.4 | 2 | 30.6 | 0.06 | 0.22 | 0 | possible |
| Dinan 13 | 2019–2022 | 24.0 | 2 | 27.5 | −0.20 | 0.13 | 0 | possible |
| Dinan 13 | 2013–2018 | 23.7 | 2 | 27.2 | −0.20 | 0.13 | 0 | possible |
| Mara 9 | 2019–2022 | 23.0 | 2 | 28.4 | 0.08 | 0.16 | 0 | possible |
| Dinan 8 | 2013–2018 | 22.4 | 3 | 34.3 | 0.34 | 0.37 | 0 | possible |
| Bala 2 | 2013–2018 | 21.8 | 4 | 46.3 | 0.08 | 0.17 | 0 | possible |
| Bala 8/11 | 2019–2022 | 20.9 | 2 | 27.8 | −0.29 | 0.16 | 0 | possible |
| Dinan 7 | 2013–2018 | 19.5 | 3 | 34.8 | 0.32 | 0.39 | 0 | possible |
| Dinan 2 | 2019–2022 | 19.3 | 2 | 21.7 | 0.41 | 0.29 | 0 | possible |
| Bala 27ca | 2013–2018 | 18.4 | 2 | 32.0 | −0.00 | 0.25 | 0 | possible |
| Dinan 6 | 2013–2018 | 17.1 | 3 | 30.7 | 0.10 | 0.19 | 0 | possible |
| Bala 6 | 2013–2018 | 14.8 | 4 | 41.0 | −0.04 | 0.07 | 0 | possible |
| Dinan 6 | 2019–2022 | 14.7 | 2 | 28.4 | 0.10 | 0.19 | 0 | possible |
| Bala 5 | 2019–2022 | 14.4 | 2 | 45.1 | 0.14 | 0.24 | 0 | possible |
| Bala 1 | 2013–2018 | 14.2 | 3 | 30.2 | 0.12 | 0.30 | 0 | possible |
| Bala 3 | 2019–2022 | 13.3 | 2 | 42.7 | 0.04 | 0.27 | 0 | possible |
| Bala 29ca | 2013–2018 | 10.2 | 2 | 22.4 | 0.26 | 0.18 | 0 | possible |

(Full 320-row table incl. `no_evidence`/`indeterminate` and align-B correlations: `v_dea_zone_landuse_summary`.)

## 3. §2.5 falsification test — caught nothing (and that is the point)

**0 downgrades.** No likely/possible zone reaches |corr_ctv_flood| ≥ 0.5; the maximum is **0.413** (Dinan 2). The pre-registered flood-correlation guard is **blind to these false positives** — exactly because, per §1(b), CTV is a spectral-instability detector responding to bare↔green transitions in *both* drought dry-down and flood green-up, so it does not correlate with the flood record. A guard keyed on flood correlation cannot catch a false positive that isn't flood-driven. Align A (wy = cy) and align B (wy = cy−1) agree on the downgrade for every zone (§6: no material disagreement).

## 4. The methodological finding

A **pre-registered cultivation classifier**, applied to Gayini in **2013–2025 when cultivation was known to be zero**, returns **2 `dea_likely_cultivated` and 40 `dea_possible_cultivated`** paddock-eras — and its built-in falsification test downgrades **none** of them. This is a sharper result than the persistence histogram: it shows the DEA CTV layer manufactures cultivation classifications on ground where there is none, and that the natural guard against it (flood correlation) does not fire. It goes in the limitations register as a worked demonstration, not just a caveat.

## 5. §2.7 stopping rule — all three inputs now available (human decides)

| condition | source | status |
|---|---|---|
| 1 · no separated high-persistence mode | Gate C | **met** |
| 2 · **fewer than five zones `dea_likely_cultivated`** | **Gate D: 2 zones** | **met** |
| 3 · farm-mean CTV swings > 3× adjacent years | Gate C (7.58×) | **met** |

All three conditions are satisfied. Read plainly, this is the **documented negative** the §2.7 rule defines — strengthened by the working §2.10 positive control (off-property cropping *does* register persistent CTV that Gayini lacks) and now by the false-positive demonstration above. **Per §2.7 the call is the human's, not CC's and not the code's.** If you confirm the null: close T12 with one methods slide, one limitations-register row, and the §9 spine return (no S5 land-use variable gained). The two `likely` and 40 `possible` zones must never be described as cultivated on DEA evidence (§2.8) — they are recorded false positives.

**STOP — Gate D complete and verified. Awaiting your §2.7 decision to close T12.**
