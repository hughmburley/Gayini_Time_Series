# T12 — Gate C · diagnostics & falsification pack (STOP)

**Task:** T12 — DEA Land Cover Level 3 extraction, spec **v4**, Gate C (all seven items).
**Date:** 28 July 2026
**Nature:** read-only diagnostics — **no classification** (`dea_cultivation_class` is Gate D). No pre-existing object modified; `dim_management_zone` history NULL 64/64 (verified). Additive: 4 figures registered in `figure_asset` (271→275, idempotent).
**Script:** `scripts/13_dea_landcover/T12_gateC_diagnostics.R`; figures registered by `register_T12_gateC_figures.py`. Tables → `Output/tables/T12_DEA_*.csv` (gitignored; referenced by path). Figures → `figures/diagnostics/T12_DEA_*.png`.

> **The §2.7 stopping rule is evaluated by a human at this gate, not by CC and not by code.** This report presents the pack and its honest reads; it does not decide the stopping rule.

---

## Item 1 — CTV persistence as a FRACTION of valid years (§2.9), the stopping-rule test

Per-pixel `persistence_frac = CTV years / valid years` (NA-aware: off-property cells can have valid years < 38). Two windows, **separate figures, never shared axes**:

- **Full record 1988–2025 (the RESULT), on-property, n = 956,916:** ever-CTV **96.93%**, `frac ≥ 0.50` 45.5%, **`frac ≥ 0.75` 1.21%**, max frac **0.947** (no pixel is CTV in all 38 years).
- **8-year pilot subset (RECONCILIATION ONLY):** ever-CTV **75.86%** — exact match to spec §1(a). Not evidence about the property.

**§2.9.3 verdict (full record): NO separated high-persistence mode.** [`T12_DEA_persistence_fraction_full_1988_2025.png`]

**Method note — a real trap, resolved.** The raw 20-bin (0.05) histogram carries a **granularity sawtooth**: `k/38` fractions (spacing 0.026) clash with 0.05-wide bins, so some bins capture two `k/38` values and others one, producing spurious single-bin dips (e.g. 0.525 sits at 6.67% between 12.53% and 12.58%). The mechanical "local min in a 0.05 bin" test **false-positived** on this. The spec evaluates *"the smoothed density"*; smoothing at the 0.05 scale (Gaussian KDE, `bw = 0.05`, which bridges the `k/38` spacing) removes the artifact and returns **no local minimum in [0.30, 0.70] → SEP MODE FALSE**. The underlying shape is **broad-unimodal** (peak ~0.5) that **decays to ~0 above frac 0.75** — there is no distinct high-persistence peak.

Per §2.9.3, **no significance test is used**: at n ≈ 957k a unimodality p-value (Hartigan's dip etc.) rejects at any threshold regardless of effect size, so it would decorate rather than decide.

*(The pilot 8-year figure shows `SEP MODE TRUE`, but that is a `k/8` discreteness artifact — only 8 possible fractions, spacing 0.125 > bw — and the pilot is reconciliation, not the stopping-rule window.)*

## Item 2 — farm CTV vs flood & veg, 1988–2025

[`T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png`] Property CTV% (calendar year) against area-weighted `flood_frac%` and `veg_mean` (water year). **Adjacent-year CTV swing = 7.58× (≫ 3×)** → §2.7 condition 3 met. Consistent with §1(b): CTV tracks neither flood nor cover cleanly.

## Item 3 — zone-level correlations (both water-year alignments, §6)

64-zone table (`T12_DEA_zone_correlations.csv`). `corr(dea_ctv_pct, flood_frac_pct)`: **align A (wy = cy) median 0.132**, only **3/64 zones |r| ≥ 0.5**; **align B (wy = cy−1) median −0.140**. CTV is **not** strongly flood-driven at zone level (echoes the pilot's 0.070). The two alignments disagree in sign at the median — reported per §6; ~3 zones would be §2.5-downgraded at Gate D.

## Item 4 — zone false-positive floor (`dea_ctv_floor` = mean CTV 2023–25)

`T12_DEA_zone_floor_table.csv`, sorted. **Unweighted mean 6.72%, 28 of 64 paddocks > 5%** (both = spec §1(c)); range **0.01% (Bala 22) → 30.69% (Bala 5)**. This is the per-zone floor that feeds Gate D §2.2.

## Item 5 — suspect-year sensitivity (all years vs §2.6-excluded)

`T12_DEA_suspect_year_sensitivity.csv`:

| headline | all years | non-suspect (2013–2025) |
|---|---|---|
| ever-CTV % | 96.93 | 85.54 |
| persistence frac ≥ 0.75 % | 1.212 | 0.58 |
| adjacent-year swing (×) | 7.58 | 7.58 |
| separated mode? | FALSE | FALSE |

Dropping the suspect 1988–2012 block does **not** change the qualitative picture (still no separated mode, still high swing).

## Item 6 — the four reference paddocks (the reason the task exists)

`T12_DEA_reference_paddocks.csv`, full record. **Bala 29ca: 1988–1992 mean CTV = 71.0% → 2013–2025 mean 25.0% → 2023–25 floor 12.3%.** But **all four** reference paddocks read high CTV in 1988–92 (26ca 45%, 27ca 76%, 28ca 55%, 29ca 81% in 1988) — squarely inside the **Landsat-5-TM-only suspect window** (§2.6). This is the signature of the observation-density artifact §2.6 warns of, not evidence of cultivation, and CTV measures spectral instability, not land use. **Low-confidence by construction; must be reported as such.** It is suggestive of the "Bala 29ca recovering from pre-record disturbance" hypothesis but cannot, from DEA alone, support it.

## Item 7 — positive control, on- vs off-property (§2.10) — the load-bearing result

[`T12_DEA_positive_control.png`] Control = raster extent − property − 500 m buffer, `scope = 'off_property_control'`, n = 2,317,022. **One panel; hard scope stop observed** (no external land-use join, no naming off-property holdings, no extent extension, no §2.4 classification of control pixels).

| | on-property | off-property control |
|---|---|---|
| ever-CTV % | 96.9 | 94.9 |
| **persistence frac ≥ 0.75 %** | **1.21** | **5.60** |
| max frac | 0.947 | **1.000** (pixels CTV every year) |
| adjacent-year swing (×) | 7.58 | 7.87 |

Both distributions are broad-unimodal (neither has a *separated* mode); the difference is a **distinctly fatter high-persistence tail** in the control — the irrigated cropping country toward Hay/Maude, on the same floodplain / flood regime / sensor history. **The CTV class does register persistent cultivation where it exists; Gayini does not have it.** This is exactly the §2.10 distinction: the on-property null is *"Gayini has no persistent cultivation,"* not *"the detector is broken."* The panel is not ambiguous and was not re-cut.

## What the pack says about the §2.7 stopping rule (for the human to weigh)

The three §2.7 conditions:
1. **No separated high-persistence mode** (full record, smoothed density) — **met.**
2. Fewer than five zones `dea_likely_cultivated` — not computed (Gate D); but max on-property frac 0.947, only 1.21% ≥ 0.75, and the low floor make many `likely` calls improbable.
3. **Farm-mean CTV swings > 3× between adjacent years** (7.58×) — **met.**

Read plainly, the evidence points to a **documented negative** — DEA Land Cover carries no usable land-use signal at Gayini — and it comes with a **working positive control**, which makes it a strong null rather than a bare one. The single pull the other way, Bala 29ca's 71% CTV in 1988–92, sits in the least-reliable window and is CTV, not cultivation. **That evaluation is the human's to make, per §2.7.**

**STOP — Gate C diagnostic pack complete. Awaiting the human's stopping-rule decision. Gate D (classification) runs only if Gate C clears.**
