# REG-1 — intercept spread correction (additive)

**Date:** 29 July 2026 · **Prior:** SHA 21f1119
**Trigger:** design-seat catch — `floor_flood_intercept_64pdk` was registered with `spread_max = 54.7363`, the **+community** model's intercept, which is the fitted value for the reference category at flood=0 (category-conditional), **not** an alternative estimate of the overall intercept. A `spread_max` is read as an uncertainty bound, so an incomparable value there is misleading.

**Fix (additive; convergent re-registration via the Gate B builder):**

| field | before | after |
|---|---|---|
| `pinned_value` | 52.6529 | 52.6529 (unchanged) |
| `spread_min` | 52.6529 | 52.6529 |
| `spread_max` | **54.7363** | **54.5840** |

Spread is now the **bivariate (52.6529)** and **within-Inland (54.5840)** intercepts only — both plain bivariate fits, one on a subset, so genuinely comparable. `decision_note` records that the +community intercept **54.7363 is excluded because it is category-conditional** (and states the value so it is not lost), and that — unlike the slope — the intercept is not comparable across the three models. The slope rows are unaffected: a slope coefficient *is* comparable across the three models, so `floor_flood_slope_64pdk`'s 0.498–0.548 spread stands.

**Verification:** reproduction test still passes at **65** (pinned value unchanged; only the spread/note moved). Exit bundle rebuilt — `reference_state_reg1_reg2_report_plumbing.zip`, all acceptance green.

Additive only: one existing row's spread + decision_note updated via INSERT OR REPLACE; no pinned value changed, no row deleted, no other object touched.
