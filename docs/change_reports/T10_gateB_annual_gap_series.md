# T10 Gate B — the annual gap series (replaces the five-period table, I-29)

**Task:** T10 v2 §4, per `docs/reference_update/Gayini_T10_v2_spec.md` (standalone).
**Date:** 28 July 2026 · **Prior:** SHA 6e2450d
**Scope:** Gate B only. **READ-ONLY** — computes the annual series + trend stats + sensitivities; no DB write (register is Gate D). STOP at §4.4.
**Verification:** live output of `scripts/12_zone_stratum/T10_gateB_annual_gap_series.py` (the producing script I-29 said did not exist — now it does).

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Headline

**Without Bala 29ca the gap is not narrowing.** Series B (three reference paddocks, excl 29ca) fits a slope of **+0.057 pp/yr, r = 0.222** — flat. The narrowing the deck's timing slide reports is carried entirely by Bala 29ca (series C: +0.919 pp/yr, r 0.846). **The convergence is a single-paddock artefact, in the same way the gap is** (methods §5). This is the substantive change the spec (§4.3) said series B would force if it held — it holds, exactly as predicted.

---

## §4.1 Primary — annual gap series, `mean_of_seasons`

Per water year 1988–89 … 2022–23: gap = mean(reference `veg_p05_spatial`) − median(60 `grazing_excluded=0` paddocks). Pinned definition (`dim_headline_number` PIN 2): paddock grain, year-first, mean_of_seasons. OLS on water year; **no p-value** (35 serial obs are not independent — spec 4.1). Residual series in `Output/tables/T10_annual_gap_series.csv`.

| series | reference set | slope (pp/yr) | r | SE(slope) | n | intercept |
|---|---|---|---|---|---|---|
| **A** | all four | **+0.273** | **0.770** | 0.039 | 35 | −555.7 |
| **B** | three, excl 29ca | **+0.057** | **0.222** | 0.044 | 35 | −116.6 |
| **C** | Bala 29ca alone | **+0.919** | 0.846 | 0.101 | 35 | −1873.0 |

## §4.3 Predictions — independently recomputed, both AGREE

| series | predicted slope / r | computed slope / r | verdict |
|---|---|---|---|
| A — all four | +0.273 / 0.770 | **+0.273 / 0.770** | AGREE |
| B — excl 29ca | +0.057 / 0.222 | **+0.057 / 0.222** | AGREE |

Both design-seat predictions reproduce to three decimals from the pipeline. The standing amendment is honoured: these were recomputed independently (not reconciled), and they happen to match. **B holding is the finding** — the deck's convergence narrative rests on one paddock.

## §4.2 Sensitivities — four periodisations (period-mean of the annual gap, `mean_of_seasons`)

| periodisation | A (all 4) | B (excl 29ca) | C (29ca) |
|---|---|---|---|
| deck 5-period | −13.1 / −11.4 / −7.9 / −5.7 / −5.6 | −3.3 / −2.2 / −1.8 / −1.6 / −1.5 | −42.3 / −39.0 / −26.2 / −18.2 / −18.0 |
| equal decades | −13.2 / −9.8 / −7.1 / −5.5 | −3.2 / −2.2 / −1.6 / −1.2 | −43.5 / −32.6 / −23.5 / −18.5 |
| equal thirds | −12.6 / −8.0 / −6.2 | −2.9 / −1.5 / −1.8 | −41.8 / −27.3 / −19.6 |
| two-window (has a script) | −13.1 / −5.7 | −3.3 / −1.5 | −42.4 / −18.1 |

The boundary choice does not carry the result: A narrows, B stays flat and small, C narrows steeply under every periodisation. The deck 5-period row for A reproduces the deck's −13.1/−11.4/−7.9/−5.7/−5.6 exactly, so the annual series is continuous with (and supersedes) the unreproducible table.

## §4.1 repeat — `jja_son`

| series | slope (pp/yr) | r | SE(slope) | n |
|---|---|---|---|---|
| A | +0.193 | 0.489 | 0.060 | 35 |
| B | +0.051 | 0.199 | 0.044 | 35 |
| C | +0.766 | 0.796 | 0.106 | **32** |

Same story under the winter/spring window: B is flat (slope +0.051, r 0.199), the narrowing is Bala 29ca. (C loses 3 paddock-years to jja_son low-support drops — n=32; mean_of_seasons has the full 35.) The finding is robust to the seasonal window.

## Residuals / autocorrelation

Residual series written for A/B/C (both variants) to the CSVs. As the spec requires, no p-value is computed — the residuals are visibly serially correlated (episodic flood-pulse years cluster), so a naive OLS p on 35 consecutive annual observations would overstate significance. A serial-correlation-adjusted inference is a separate decision (spec 4.1), not taken here.

## STOP (§4.4)

Reported: three series with slope/r/SE/n, the four sensitivity aggregations, the `jja_son` repeat, and the two predictions (both AGREE). **Not proceeding to Gate C without review.**

Outputs (gitignored, for the Gate D bundle): `Output/tables/T10_annual_gap_series.csv`, `T10_annual_gap_series_jja_son.csv`, `T10_trend_statistics.csv`.

## Invariants
- No DB write, no builder, no registered row touched. Writes: this report + the producing script (tracked — resolves the I-29 "no script" defect for the annual series).
