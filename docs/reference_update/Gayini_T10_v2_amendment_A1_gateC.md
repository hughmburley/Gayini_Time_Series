# T10 v2 — amendment A1 to §5 (Gate C)

**Version:** A1 · 28 July 2026
**Amends:** `Gayini_T10_v2_spec.md` v2, §5 only. All other sections stand unchanged.
**Trigger:** Gate B result (SHA a104661) — series B flat at +0.057 pp/yr, series C at +0.919.
**Effect:** §5 gains a temporal arm, §5.4 is widened. §5.1, §5.2, §5.3 are unchanged.

---

## Why

Gate B established that the entire reference-versus-grazed trajectory is Bala 29ca: series B
shows no trend, series C rises at +0.919 pp/yr. The deck's timing slide now rests wholly on
one paddock's 35-year recovery.

**§5 as written cannot test that claim.** It fits each paddock's *mean* floor against its *mean*
flood frequency across 64 paddocks. That is cross-sectional: it answers whether Bala 29ca's
floor is low **for how dry it is**. The claim Gate B produced is temporal: whether Bala 29ca's
floor is **rising for reasons other than water**.

The question is live rather than theoretical. Design-seat check, **a prediction to verify, not
a target** — Bala 29ca's own flood frequency trends **+0.304 pp/yr (r = 0.268)** over the
record, while Bala 26ca, 27ca, 28ca and the grazed median all trend slightly negative (−0.301,
−0.099, −0.424, −0.117). Bala 29ca is the only reference paddock getting wetter. The trend is
weak and probably cannot carry a +0.919 pp/yr floor recovery, but it must be tested rather than
assumed.

**Do not estimate the explained share by multiplying the cross-sectional slope (+0.548) by the
temporal flood trend.** Between-paddock and within-paddock slopes are different quantities and
need not agree; doing so would be an ecological-inference error. Fit the within-paddock
relationship directly.

---

## New — §5.6 The temporal arm

For **each of the 64 paddocks** independently, using `fact_zone_veg_annual`,
`series_variant = 'mean_of_seasons'`, 35 water years:

### 5.6.1 Within-paddock water adjustment

1. Regress that paddock's annual `veg_p05_spatial` on the same year's `flood_frac_pct`.
   Report slope, r and n per paddock. This is the **within-paddock** water response, and it is
   a different quantity from the 64-paddock cross-sectional slope in §5.1 — report both and do
   not conflate them.
2. Take the residuals from that fit and regress them on water year. Report slope, r and
   SE(slope) per paddock. This is the paddock's floor trend **after** removing its own
   year-to-year water response.
3. Report the raw floor trend on water year per paddock, so raw and adjusted sit side by side.

No p-values, for the reason given in §4.1 — the annual series are serially correlated.

### 5.6.2 The three numbers this arm exists to produce

For **Bala 29ca**, stated plainly and together:

| | |
|---|---|
| raw floor trend | (expected near the series C value, +0.919 pp/yr) |
| within-paddock water response | slope of floor on same-year flood fraction |
| water-adjusted floor trend | the number that decides the claim |

**If the adjusted trend is close to the raw trend**, Bala 29ca's recovery is not hydrological
and the "recovering from historical disturbance" reading survives — which makes Ernest's
land-use history the decisive outstanding input.

**If the adjusted trend collapses toward zero**, the recovery is Bala 29ca getting wetter, the
deck's timing slide must be rewritten, and the reference-state framing loses its last
substantive result. **Report that in the change report headline if it happens** — same rule as
§8.

### 5.6.3 Property-wide output

A **64-row table**: paddock, treatment, raw floor trend, within-paddock water slope,
water-adjusted floor trend, and rank by adjusted trend. Identify the four reference paddocks
and Dinan 10.

This is the F-4 analysis from the results catalogue, and it stands on its own regardless of
what Bala 29ca does: it says which paddocks are improving or declining **beyond what their
water regime explains**, which is a better candidate for a management signal than any raw
contrast in this project has produced. Report the distribution, not only the reference
paddocks.

### 5.6.4 Two things to check and report, not work around

- **Paddocks with little flood variation.** Where a paddock's `flood_frac_pct` barely varies
  across 35 years, step 1 has almost nothing to fit and the adjustment is meaningless. Report
  the within-paddock standard deviation of flood fraction alongside each row, and flag any
  paddock where the water response is estimated from negligible variance rather than silently
  reporting a number.
- **Lag.** The floor may respond to the *previous* year's water rather than the current year's;
  the project's census work found a lag structure. Run step 1 a second time against
  `flood_frac_pct` lagged one year and report both. If the lagged fit is materially better for
  most paddocks, say so — that is a finding about the system, and it changes which adjustment
  should be preferred.

---

## Widened — §5.4

§5.4 previously asked for one number: Bala 29ca's cross-sectional residual against the raw
−42.3 pp gap. It now asks for **two**, presented together, because the deck makes two separate
claims:

| deck claim | slide | the number that tests it |
|---|---|---|
| Bala 29ca sits 42 pp below the grazed median | 7 | cross-sectional residual (§5.4 original) |
| The gap has been narrowing since 1988 | 8 | water-adjusted floor trend (§5.6.2) |

State each against the raw figure it qualifies, and say what fraction of each survives.

---

## Acceptance criteria — additions to §7

- [ ] Within-paddock water response fitted for all 64 paddocks, current and one-year lag
- [ ] Water-adjusted floor trend for all 64 paddocks, with SE
- [ ] 64-row table, reference paddocks and Dinan 10 identified, ranked by adjusted trend
- [ ] Within-paddock flood-fraction variance reported per row, low-variance paddocks flagged
- [ ] Bala 29ca's three numbers stated together per §5.6.2
- [ ] Both §5.4 numbers stated against the raw figures they qualify
- [ ] The design-seat flood-trend prediction (+0.304 pp/yr, r 0.268) independently checked;
      agreement or disagreement stated

## Exit condition — addition to §8

The Gate C review bundle gains the 64-row temporal table as CSV, and the per-paddock
within-paddock fit statistics for both the current-year and lagged specifications.
