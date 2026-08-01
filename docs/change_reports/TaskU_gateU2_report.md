# Task U · Gate U2 — The two LiDAR epochs in the 35-year Landsat record · **DRAFT**

**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md`, Gate U2
**Date:** 1 August 2026 · **Status:** DRAFT
**Scripts:** `scripts/14_lidar/U2_epoch_context.py` · `scripts/14_lidar/U2_epoch_context_figure.R`
**Artefacts:** `Output/tables/taskU_gateU2_{epoch_context,bala_reference,series_35yr}.csv` ·
`Output/figures/task_U/U2_epoch_context_35yr.png` (registered `figure_u2_epoch_context_35yr`)

No new data. Every number is queried from `Gayini_Results.sqlite`, read-only. No table
or view modified or dropped.

**Every later interpretation of change is conditioned on this table.**

---

## 1 · The flight-month gap is a water-year gap, and it is structural

`dim_time` establishes that the project water year **starts in July**. Gate U0.6
established that flight months are **unrecoverable from the delivery** — no readme, no
delivery note, no dated TIFF tags.

A calendar-2009 capture therefore falls in **WY2008** if flown January–June and
**WY2009** if flown July–December. The same holds at 2021. **Each epoch has two
candidate water years and this gate reports both for every metric.** Collapsing to one
would invent a fact the delivery does not carry.

This is not a formality. It changes the answer.

## 2 · The headline — direction is robust, magnitude is not

Farm grain, whole property (zoned), `series_variant = mean_of_seasons`, pixel support.
Percentile rank is against the full 35-year distribution.

| Metric | WY2008 | WY2009 | WY2020 | WY2021 |
|---|---|---|---|---|
| `veg_p05_spatial` | **30.87** · low · **pctile 0.0** | 51.71 · low · 5.9 | 61.50 · typical · 38.2 | 66.24 · typical · 50.0 |
| `veg_median` | **54.36** · low · **pctile 0.0** | 68.16 · low · 2.9 | 77.50 · typical · 35.3 | 81.27 · typical · 50.0 |
| gauge 410040 mean flow (ML/d) | **886.7** · low · **pctile 0.0** | 1,536.3 · low · 8.8 | 3,504.7 · typical · 47.1 | **15,290.2** · high · **pctile 100.0** |

**The direction survives the ambiguity.** Under *either* candidate water year, 2009 is a
low-cover, low-flow epoch and 2021 is typical-to-high. T-3's expectation — 2009 at the
end of the Millennium Drought, 2021 after the 2016 and 2020–21 floods — is confirmed
quantitatively, not merely asserted.

**The magnitude does not survive it.** Farm `veg_p05_spatial` at the 2009 capture is
**30.87 or 51.71** depending on the flight month — a **20.8 pp spread**, larger than most
effects this project reports. Gauge flow at the 2021 capture is **3,505 or 15,290 ML/day**,
a factor of 4.4.

**Worst case, stated plainly:** if the 2009 flight was Jan–Jun and the 2021 flight
Jul–Dec, the comparison is **the record minimum of the 35-year series against the record
maximum flow** — percentile 0.0 against percentile 100.0 on the gauge. That is the
starkest hydrological contrast the record can produce, and it is one of four equally
admissible readings.

**Consequence, to be carried into every change statement in U-Q3 and U-Q4c:** any FPC or
height gain between the epochs is confounded with drought recovery, and the size of that
confound is itself uncertain by a factor of several. This does **not** block the task —
U-Q1 is a *within-epoch between-paddock* contrast and is largely immune, which is why the
spec ranks it first.

### Per community

| Community | metric | WY2008 | WY2009 | WY2020 | WY2021 |
|---|---|---|---|---|---|
| Aeolian | flood % | 0.13 low | 6.64 high | 6.04 high | 7.09 high |
| | `veg_p05_spatial` | 23.51 low | 39.89 low | 49.39 typical | 56.42 high |
| Riverine | flood % | 0.27 low | 5.02 typical | 19.48 high | 30.59 high |
| | `veg_p05_spatial` | 22.24 low | 41.10 low | 50.29 low | 56.57 typical |
| Inland | flood % | 0.30 low | 6.56 low | 29.82 typical | **64.05 high** |
| | `veg_p05_spatial` | 35.92 low | 57.25 low | 67.27 typical | 71.19 typical |

Note the Aeolian tercile labels: 6.64% reads "high" for Aeolian because that community's
35-year distribution is compressed near zero. **The tercile is within-community and must
never be read across communities** — 6.64% in Aeolian and 64.05% in Inland are both
"high" and are not the same thing.

---

## 3 · The four Bala reference paddocks — and an unexpectedly hard number

U-Q1 depends on these. `veg_p05_spatial`, within-zone spatial, pixel support:

| Water year | 26ca | 27ca | 28ca | **29ca** |
|---|---:|---:|---:|---:|
| WY2008 | 30.7 | 29.8 | 34.5 | **22.1** |
| WY2009 | 67.4 | 58.4 | 54.5 | **31.0** |
| WY2020 | 61.6 | 61.1 | 67.7 | **49.6** |
| WY2021 | 69.5 | 66.0 | 67.3 | **55.8** |

**Bala 29ca is the lowest of the four in every one of the four candidate windows**, by
8.6 to 23.5 pp. Consistent with the 27 July finding, and now established inside the
specific windows the LiDAR will be read in.

Annual wet fraction, same paddocks — **this is the number worth stopping on**:

| Water year | 26ca | 27ca | 28ca | **29ca** |
|---|---:|---:|---:|---:|
| WY2008 | 0.6 | 0.0 | 0.0 | 0.1 |
| WY2009 | 24.5 | 1.5 | 18.3 | 13.2 |
| WY2020 | 56.1 | 26.7 | 37.2 | **10.6** |
| WY2021 | **80.8** | **68.7** | **65.9** | **13.9** |

**In WY2021 — the wettest year in the gauge record — Bala 29ca flooded at 13.9% while
its three neighbours flooded at 66–81%.** It receives roughly **one fifth** the
inundation of the paddocks it is grouped with, in the year the difference is easiest to
see.

This is the strongest direct evidence yet for the standing finding that Bala 29ca's
floor deficit is **substantially explained by dryness** rather than by management
history. It does not settle U-Q1 — that is what the LiDAR structure test is for, and a
cleared paddock could also be a dry one — but it sharpens what U-Q1 must distinguish:
**not "is 29ca different" (it is, on every axis) but "is 29ca's difference structural or
hydrological".**

A trap this table exposes: 29ca's own tercile labels read **"high"** for flood at WY2009,
WY2020 and WY2021, because they are computed against **29ca's own** 35-year
distribution, which is compressed low. Absolutely it is the driest of the four by a wide
margin. **Within-paddock and between-paddock terciles are different statements** and the
CSV carries both the value and the rank so they cannot be confused.

---

## 4 · The figure

`Output/figures/task_U/U2_epoch_context_35yr.png`, three stacked panels over
WY1988–2022: farm cover (`veg_p05_spatial` and `veg_median`), per-community annual wet
fraction, and gauge 410040 mean flow.

Each LiDAR capture is drawn as a **two-water-year shaded band**, not a line, because the
flight month is unrecoverable. Marked at water year, per spec.

Built in **R**, not Python: matplotlib is not installed in this environment and adding it
would introduce a second figure stack alongside the project's R+ggplot2 one.
`gayini_write_and_register_figure()` writes and registers in **one transaction**, which
is the rule that stopped figures landing on disk unregistered — so using it is strictly
better than the alternative, not merely equivalent. Palette is the committed C1
community set (dry ochre → teal → wet blue) plus the committed `total_veg` green and
neutral grey; deliberately not viridis.

One defect found and fixed on review: the gauge series and the Inland community were
both `#2166AC`. They sit in different facets but share one legend, and two unrelated
series in one colour is a legibility defect regardless. Flow moved to `#08306B`, the
darkest blue of the committed sequential ramp. The re-render changed the registered
checksum (`7d11da7e` → `031df794`), which is a third incidental demonstration that
`INSERT OR REPLACE` converges.

---

## 5 · What this gate does and does not license

**Licensed.** Reading 2009 as a drought epoch and 2021 as a typical-to-wet one, in every
later sentence, with the water-year ambiguity named.

**Not licensed.** Any statement about the *size* of a 2009→2021 change that does not
carry the flight-month caveat. The candidate windows differ by 20.8 pp in farm cover and
4.4× in flow; a change statistic quoted without that range is a statistic quoted to a
precision the data does not have.

**Not licensed.** Comparing tercile labels across communities or across paddocks. Every
label in these tables is computed against that unit's own 35-year distribution.

---

## 6 · Open, not blocking

The three questions to Adrian stand, and **question 2 is now the expensive one**: flight
months would collapse four candidate readings to two and remove the 20.8 pp / 4.4×
spread from every change statement in the task. It was a nicety at Gate U0; after this
table it is the single cheapest improvement available to Task U.

1. Vertical datum of each `bb0`.
2. **Flight months at each epoch** — upgraded in value by this gate.
3. What is `254` in the `d5` `bb3`/`bb4` bands (D-U3).

## 7 · Acceptance criteria touched

- [x] Gate U2 table delivered before any change interpretation
- [x] Both epochs placed against the 35-year distribution, per community and at farm grain
- [x] Gauge 410040 context reported
- [x] The four Bala reference paddocks reported explicitly
- [x] One table, one figure; epochs marked at **water year**, not month
- [x] Plot support and pixel support never merged — every figure in this gate is pixel support and says so
- [x] Change report in `docs/change_reports/`, committed
