# T12 — v4 numeric correction · change report

**Task:** T12 — DEA Land Cover Level 3 extraction, spec **v4** (numeric correction only; no rule changes — no threshold in §2.4/§2.5/§2.7/§2.9/§2.10 moves).
**Date:** 28 July 2026
**What changed:** one recorded `UPDATE` to `dim_source_product.caveat` for `product_id='dea_landcover_l3'` — a row **this task created at Gate A**. The Gate A caveat carried the v1 wording "false-positive floor … = 6.7% of property", which was a **paddock-unweighted** mean mislabelled as a property figure. v4 states both figures with their denominators.
**Legitimacy:** an explicit, recorded correction to a T12-created row; nothing deleted, so it is consistent with additive-only. Reported here with before/after rather than fixed quietly.
**Script:** `scripts/13_dea_landcover/T12_v4_correct_source_product_caveat.py` (check/execute, idempotent — UPDATE to a fixed target; only the `caveat` column touched, no other row).

## Before → after (`dim_source_product.caveat`, `dea_landcover_l3`)

**BEFORE (v1 text, written at Gate A):**
> …Measured false-positive floor at Gayini 2023-2025 (cultivation known zero) **= 6.7% of property**. GA use constraint…

**AFTER (v4 text):**
> …Measured false-positive floor at Gayini 2023-2025, when cultivation is known to be zero: **10.57% of property (area-weighted); 6.72% as an unweighted mean across the 64 paddocks; 28 of 64 paddocks above 5%. Always state the denominator.** GA use constraint…

Live `SELECT` after the UPDATE confirmed: caveat contains `10.57%` = True; contains `6.7% of property` = False; `product_name/sensor_family/method_summary` unchanged.

## Why this is the honest direction

10.57% (area-weighted property) is **larger** than the 6.72% previously quoted, so the correction **weakens** rather than strengthens the case against DEA CTV. Confirmed at Gate B: the two figures are a support distinction (area-weighted property share vs unweighted paddock mean), not a discrepancy — both reconcile exactly to the data (`fact_dea_landcover_farm_year` = 10.57%; unweighted mean of the 64 `fact_dea_landcover_zone_year` 2023–25 floors = 6.72%; 28 of 64 > 5%).

`dea_ctv_floor` (§2.2) is per-zone and **unaffected**; no Gate D threshold moves.
