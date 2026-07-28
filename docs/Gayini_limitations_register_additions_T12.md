# Limitations register — staged additions (T12)

Same convention as the T2/T6 staging files: `Gayini_limitations_register_*.xlsx` (v10) is
gitignored (project knowledge). These entries are staged in tracked Markdown for merge into
the register. Do **not** create a competing .xlsx. Task T12 closed as a **documented negative**
(spec v4 §2.7 fired); these rows are the durable record of *why*.

---

## L-T12-a — DEA Land Cover CTV discriminates cultivated from uncultivated ground only where Landsat observation density is adequate

| field | value |
|---|---|
| **Limitation** | DEA Land Cover Level 3's Cultivated Terrestrial Vegetation (CTV) class separates known irrigation country (off-property) from the Gayini conservation floodplain (on-property) **only in the final sensor era**. Off-minus-on mean CTV gap by era: **L5-only 1988–99 +0.7 pp · L5+L7 2000–02 −7.2 · L5deg+L7 2003–10 −0.3 · L7-only 2011–12 −0.1 · L8+L7 2013–21 −2.4 · L8+L9 2022–25 +9.2**. Two landscapes that differ principally in land use are **indistinguishable, or wrong-signed, in every era but the last**, and both track sensor availability in step. |
| **Why it matters** | The signal in CTV is dominated by observation density, not land use. The pre-record window the task was commissioned to interrogate (1988–92, L5-only) is precisely where the class cannot tell cropped from uncropped ground (0.7 pp). |
| **Support / scope** | pixel; on-property = property boundary; off-property control = raster extent − property − 500 m buffer; period = 1988–2025 by sensor era. |
| **Evidence** | `Output/tables/T12_DEA_sensor_era_gap.csv`; figures `T12_DEA_sensor_era_gap.png`, `T12_DEA_positive_control.png`, `T12_DEA_class_snapshots.png`. Positive control §2.10. |
| **Status** | **Closed finding** (documented negative). Reported, not worked around. Do **not** write "the class works" or "validated detector". |

## L-T12-b — WORKED EXAMPLE: a pre-registered falsification test aimed at the wrong hypothesis catches nothing

| field | value |
|---|---|
| **Limitation** | The pre-registered §2.4 classifier returned **42 zone-era classifications (2 `likely`, 40 `possible`)** on ground with **zero cultivation** (2013–2025). Its own §2.5 falsification test — downgrade any zone whose CTV correlates with the flood record at \|r\| ≥ 0.5 — **downgraded none** (max \|corr_flood\| = **0.413** across all 64 zones; align A and B agree). |
| **Why it matters (state the mechanism)** | §2.5 tested **flood correlation** because GA's documentation names flood green-up as the CTV failure mode. **That is not the failure mode here** — the mechanism is **observation density** (L-T12-a), and a flood-correlation guard is *structurally blind* to it. The guard was pre-registered, correctly executed, and **aimed at the wrong hypothesis.** That is the methodological finding, not an embarrassment — and a sharper one than the persistence histogram. Note the §2.4 **support rule DID work**: Mara 20, the strongest apparent candidate at 63.6 pp excess, is excluded at **1,667 px** against the 3,000-px bar. |
| **Evidence** | `fact_dea_cultivation_assessment`, `v_dea_zone_landuse_summary`; `docs/change_reports/T12_gateD.md`. |
| **Status** | **Closed finding.** Write **"42 zone-era classifications", never "42 zones"** (zones recur across the two eras). |

## L-T12-c — Bala 29ca is NOT resolved by DEA; §2.8 promotion bar; `cropping_history` NULL is a finding

| field | value |
|---|---|
| **Bala 29ca** | **Not resolved.** In the 1988–92 window the class separates cropped from uncropped land by only **0.7 pp** (L-T12-a), so Bala 29ca's 71% CTV in that window is **not** support for the historical-disturbance hypothesis — it is the observation-density artefact §2.6 warns of, in the least-reliable era, from a class that measures spectral instability, not land use. **Do not let 71% CTV read as evidence.** Ernest's ground-referenced land-use table remains the **only decisive route**. |
| **§2.8 (restated, binding)** | The 2 `likely` and 40 `possible` zone-era calls **must never be described as cultivated anywhere, in any deliverable, at any confidence level.** They are **recorded false positives**. Promotion to `dim_management_zone.cropping_history` requires Ernest's nearmap interpretation and is a separate, later, human decision — never DEA-derived. |
| **`cropping_history` NULL 64/64** | Now a **finding, not unfinished work**: DEA Land Cover cannot fill it (that was the test, and it failed by design of the data, not the build). The five RESERVED columns stay NULL, deliberately, awaiting Ernest's table. |
| **Status** | Open external data request (Ernest's land-use table) — same as I-04; T12 adds the evidence that DEA is not a substitute for it. |
