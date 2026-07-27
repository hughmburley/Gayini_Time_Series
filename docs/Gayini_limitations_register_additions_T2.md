# Limitations register — staged additions (T2)

**Why this file exists:** `Gayini_limitations_register_*.xlsx` (v10, 43 rows) is **not
in the repo working tree** — it is gitignored (`*.xlsx`) and lives in project knowledge.
So these two entries cannot be written into the .xlsx from here. They are staged in
tracked Markdown, with the fields a register row needs, to be pasted into the register
(or provide the .xlsx and they can be written directly). Do **not** create a competing
.xlsx — that is discrepancy class #1.

Both are **scientific limitations** (they constrain what the analysis can claim), which
is why they belong in the limitations register, not the build issues log.

---

## L-T2-a — Reference condition is, at plot support, mostly one paddock

| field | value |
|---|---|
| **Limitation** | The reference (No-grazing) condition as *seen by the plot network* is **54% one paddock**: Bala 29ca holds **13 of 24** reference plots (`plot_paddock`; the other three reference paddocks hold 3 / 8 / 0). That same paddock, Bala 29ca, carries the **lowest** reference `veg_p05` trajectory in **two of three** communities (Aeolian and Riverine; `v_reference_gap_decomposition`). |
| **Why it matters** | The reference state is meant to be the benchmark the grazed paddocks are compared against. If one atypically-low paddock dominates the plot-support reference, both the level and the "gap narrows" reading are driven by it, not by the No-grazing treatment. |
| **Support** | plot (and pixel). **This is the plot-support analogue of T1's pixel-weighting problem** (T1 Gate D: the Riverine floor contrast was one paddock, Bala 29ca, at pixel support). **The two supports fail the same way, not independently** — so agreement between them is not corroboration. |
| **Evidence** | `plot_paddock` / `v_plot_paddock` (13 of 24), `v_reference_gap_decomposition` (per-community reference levels), figure `T2_G_plot_paddock_coverage.png`, `T2_E_paddock_trajectories.png`. |
| **Testable from RS?** | Partially — the heterogeneity is quantified; whether it biases the conclusion is a design/spine decision (links to open issue I-02). |
| **Status** | Open. Feeds the distance-to-reference metric decision (spine, I-02). |

## L-T2-b — Grazing intensity is unknown (rotation interval ≠ stocking rate)

| field | value |
|---|---|
| **Limitation** | "14-day grazing" names a **rotation interval, not a stocking rate**. The analysis has no measure of grazing *intensity* (DSE/ha, stocking rate, grazing-day count) for any paddock. |
| **Why it matters** | If intensity is low, the grazed-vs-not-grazed contrast may simply be **too small to detect** — which would explain the T1 null (no robust grazing effect on the floor) **more simply than paddock identity does** (L-T2-a). The two explanations are currently indistinguishable. |
| **Support** | all (treatment is metadata, per the standing convention that grazing is metadata not a covariate). |
| **Testable from RS?** | **No.** Remote sensing cannot recover stocking rate. |
| **Data needed** | Per-paddock stocking rates / DSE per ha / grazing-day counts over 1988–2023. **Flag as an external data request** (to the land manager / Nari Nari, alongside the cut-date and land-use requests). |
| **Status** | Open — external data request. Untestable until intensity data is supplied. |
