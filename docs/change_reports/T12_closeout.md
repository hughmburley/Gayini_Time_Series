# T12 — close-out · documented negative (§2.7 fired)

**Task:** T12 — DEA Land Cover Level 3 extraction, spec v4. **Outcome: documented negative** — DEA Land Cover carries no usable land-use signal at Gayini. A complete and successful result per §2.7.
**Date:** 28 July 2026
**Confirmed by:** the human at the Gate D STOP (§2.7 evaluated: all three conditions met; independent recomputation matched — same 2 zones, same counts, same era pattern).

---

## 1. Methods slide — the sensor-era gap is the figure

`figures/diagnostics/T12_DEA_sensor_era_gap.png` (+ `Output/tables/T12_DEA_sensor_era_gap.csv`). **DEA CTV discriminates cultivated (off-property) from uncultivated (on-property) ground only where Landsat observation density is adequate.** Off-minus-on mean CTV %, by sensor era (independently reproduced, matches to 0.1 pp):

| sensor era | off − on CTV (pp) |
|---|---|
| L5-only 1988–99 | **+0.7** |
| L5+L7 2000–02 | −7.2 |
| L5deg+L7 2003–10 | −0.3 |
| L7-only 2011–12 | −0.1 |
| L8+L7 2013–21 | −2.4 |
| **L8+L9 2022–25** | **+9.2** |

Known irrigation country and a conservation floodplain are indistinguishable (or wrong-signed) in every era but the last, and both collapse with sensor availability in step. **Never write "the class works" or "validated detector."**

## 2. The second finding — a pre-registered guard aimed at the wrong hypothesis

A pre-registered classifier returned **42 zone-era classifications (2 `likely`, 40 `possible`)** on zero-cultivation ground, and its §2.5 falsification test caught **none** (max |corr_flood| = 0.413). **Why:** §2.5 tested flood correlation because GA names flood green-up as the CTV failure mode; here the mechanism is **observation density**, and a flood-correlation guard is structurally blind to it. Pre-registered, correctly executed, aimed at the wrong hypothesis — the finding, not an embarrassment. The §2.4 support rule *did* work: Mara 20 (63.6 pp excess) is excluded at 1,667 px < 3,000. Full detail: `docs/change_reports/T12_gateD.md`, `docs/Gayini_limitations_register_additions_T12.md`.

## 3. §9 spine return

*(No dedicated spine-return-log file exists in the repo; recorded here as the durable cross-session record.)*

| field | value |
|---|---|
| **Stopping rule (§2.7)** | **FIRED** — documented negative. (1) persistence distribution broad-unimodal, **no separated high-persistence mode**; (2) **2 zones `dea_likely_cultivated` < 5**; (3) farm-mean CTV adjacent-year swing **7.58× > 3×**. |
| **Classifications** | 2 `dea_likely_cultivated` + 40 `dea_possible_cultivated` zone-era calls — **all false positives** (2013–2025, cultivation known zero). |
| **Persistence bimodal?** | No — broad-unimodal, decays to ~0 above frac 0.75. |
| **S5 land-use variable** | **NOT gained.** DEA Land Cover contributes no usable land-use history variable to S5. It remains the *backup* line that failed; Ernest's nearmap interpretation is the primary and only decisive route. |

## 4. §2.8 restated (binding)

The 2 `likely` and 40 `possible` zone-era calls **must never be described as cultivated anywhere, in any deliverable, at any confidence level.** They are **recorded false positives**. Write **"42 zone-era classifications", never "42 zones"** (zones recur across the two eras). Promotion to `cropping_history` requires Ernest's table — never DEA.

## 5. Bala 29ca — NOT resolved

In 1988–92 the class separates cropped from uncropped land by **0.7 pp** (§1). Bala 29ca's 71% CTV in that window is therefore **not** support for the historical-disturbance hypothesis — it is the observation-density artefact in the least-reliable era. **Do not let 71% CTV read as evidence.** Ernest's land-use table remains the only decisive route.

## 6. `cropping_history` NULL 64/64 — a finding, not a gap

All five RESERVED columns stay NULL on all 64 zones — verified at every gate. This is now **recorded with evidence**: DEA Land Cover was tested as a substitute and cannot fill them. The empty column is a finding (DEA is not a land-use record), not unfinished work.

## 7. Maps + figure registration

Two maps built and registered, both observing the off-property disclosure constraint (landscape scale, **no cadastral boundaries, no holdings named**):
- `T12_DEA_persistence_map.png` — per-pixel CTV persistence fraction 1988–2025.
- `T12_DEA_class_snapshots.png` — Level 3 class 1990/2005/2016/2024, official QML palette (CTV #acbc2d, NTV #0e7912, NS #f3ab69, Water #4d9fdc); visibly shows the class's year-to-year instability.

**All T12 figures registered in `figure_asset` (7 total):** 4 Gate C (`run_id='T12_gateC'`) + 3 close-out (`run_id='T12_close'`). No T12 figure is unregistered.

## 8. Housekeeping

- **CLAUDE.md updated (single edit, I-27):** DB shape 6→9 `spatial_layer_asset`, 126→166 `raster_asset`, 255→278 `figure_asset`, the T12 `dea_` objects, and the standing git rule (commit-straight-to-main, push per gate; retires the branch/PR flow).
- **Gate B farm/community-as-separate-tables: confirmed by the human, closed, no rework.**
- Invariants at close: `dim_management_zone` history NULL 64/64; additive-only throughout; builder never run; no registered row deleted.

**T12 done.** Next: the 66 site reports (Deliverable 2), the 10 August deliverable.
