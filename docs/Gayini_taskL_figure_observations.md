# Gayini — Task L figure observations

*What the veg×water figures SHOW — narrative material for the Gate 4 per-unit reports.
Distinct from the change reports (which record what CHANGED). Observations only; numbers
read off the census clouds/GAM lines (p05 floor unless noted). Started 2026-07-23.*

> Method reminder: y = veg **p05 floor** (worst-season cover a pixel holds); x = between-year
> flood frequency; grey = pixel density; coloured line = community-hue GAM ±95% CI. Percentiles
> are plotted, never differenced. "Cover, not condition" — high cover ≠ healthy Country.

---

## One paddock, two communities responding differently

- **Bala 6 — the cleanest split.** Riverine and Inland share the same paddock (and the same
  flood range), yet respond oppositely: **Riverine is essentially flat at ~38–41%** floor across
  its whole flood range, while **Inland climbs 43 → ~73%** over the same water. One management
  unit, two ecological stories — the Inland floodplain floor is rescued by flooding; the Riverine
  chenopod floor barely moves. (Diagnostic confirms the split holds at p10/p20 but narrows as both
  lift — it is *starkest at the p05 floor*.)

## Same community, contrasting curve shapes

- **Bala 12 vs Bala 8/11 — both Inland-dominant, different curves.**
  - **Bala 12** (15,571 px): a **dip-then-rise (S-curve)** — floor starts ~52% at near-zero
    flood, **dips to ~45% around 8–10%** flood frequency, then climbs steeply to a **high plateau
    ~82%**. The low-flood "valley" is unusual — the rarely-flooded pixels there hold *more* floor
    cover than the slightly-more-flooded ones.
  - **Bala 8/11** (24,880 px): a **smooth monotone rise** ~33 → ~65% plateau by ~45% flood, no
    dip, **lower plateau** than Bala 12.
  - Takeaway for reports: "Inland floodplain" is not one curve — paddock context (soil, micro-relief,
    connectivity) shapes both the floor level and the response form.

## Sparse-bin artifacts (a figure caveat, not ecology)

- **Mara 7 — Riverine line wiggled** (rose ~10%, dipped ~17%, spiked ~27%). **Was a sparse-bin GAM
  over-fit, not ecology** — Mara 7's Riverine subset is 686 px with **0 of 8 flood-freq bins reaching
  the 500-pixel floor** (largest bin 282), and the old cutoff logic fit a k=10 spline across the whole
  range on 1–23 points per mid/high bin. **RESOLVED (2026-07-23):** the generator now draws
  **density-only** when no bin clears the floor. The audit found this was **not unique to Mara 7 —
  4 of 20 own-clouds had such lines** (Bala 26ca, Dinan 6, Mara 7, Mara 8 — all secondary-community
  lines); all now density-only. Dominant-community lines were always well-supported and unchanged.
- **Dinan 10** short lines are honest by contrast: Aeolian 3/11 bins ≥500 (dense low end → short
  line), Riverine 1/11, Inland 2/11 — the lines correctly stop where support runs out.

## Percentile sensitivity (p05 vs p10 vs p20) — why p05 is the headline

- **The flood signal is largest at the p05 floor and compresses toward the median.** Dynamic range
  of the Inland response: **~40 pp at p05** (38→78) → ~27 pp at p20; Riverine ~24 pp → ~17 pp. The
  worst-season floor is where flooding shows up; typical/upper cover is high regardless. p05 is the
  most discriminating metric — keep it as the headline (science call for Hugh + Adrian).
- **Community ordering is Inland ≫ {Aeolian ≈ Riverine}, not a clean dry<mid<wet.** Mean floors —
  p05: Aeolian 46, Riverine 44, Inland 61; p10: 52.9 / 51.6 / 66.8; p20: 60.3 / 60.3 / 72.9.
  Aeolian and Riverine are indistinguishable at the floor (Aeolian marginally higher); only Inland
  separates. The dry vs mid distinction lives in *exposure*, not floor level.
- The **wiggle does not reduce at p10/p20** — it is a pixel-count problem, independent of which
  percentile is plotted. Fix it via support/k, not by changing the metric.

---

*Pending: sweep the remaining paddock own-clouds for other notable shapes (humps, plateaus,
zero-response communities) as Gate 4 report drafting proceeds.*
