# RUN · PARTSCATTER · 9 August 2026

Spec: `docs/reference_update/Gayini_CC_spec_PARTSCATTER_update.md`. Schema per Ruling DP.

**Delivered:** `Output/figures/temporal/PARTSCATTER_part_temporal_p05_vs_water.png`
2000 × 1125 px (13.333 × 7.5 in at 150 dpi), 16:9, drops into a slide without rescaling.
Registered `figure_partscatter_part_temporal_p05_vs_water`, checksum `599e5df3be46…`.

**Second pass, amendments A1–A5, accepted and rendered once.** No metric changed, no unit
changed, nothing refitted. Two new *quantities* were computed — both from the same cells
already in hand, neither touching an axis: `veg_p05_within_sd` (the opacity channel) and
`r_across_areas` (the legend correlation). First-pass checksum `173fdd2d0945…`, kept here
so the two renders can be told apart.

---

## 0 · Amendments A1–A5

| # | asked | done |
|---|---|---|
| **A1** | opacity = within-area spread of the per-cell 5th percentile, high spread more opaque, ramp ≈0.45–1.0, legend says it **in words** | `veg_p05_within_sd`, a **spatial** spread across an area's own cells — the same cells y averages over. Ramp exactly 0.45–1.0. Legend title reads *"Variation within the area / darker areas vary more internally"*, and the footnote says it again in a full clause. Observed range **3.40 – 23.23** |
| **A2** | caption full plot width, edge to edge | wrap widened 168 → 245 chars against `caption.position = "plot"`. The legend column no longer costs it a fifth of the page |
| **A3** | *"vegetation community"* written out | legend title, subtitle and footnote. No *"veg community"* anywhere on the face |
| **A4** | caption split into subtitle + ordered footnote, article register | subtitle as issued; footnote in the seven-item order, led by the shortened support clause. Cuts made: *census cells*, *supports are never mixed*, *minor units*, and *no cause is attributed* as a bare phrase |
| **A5** | per-community **r**, no fit statistic | `n` and `r` in the legend for the two fitted communities; Aeolian reads *"range too narrow to fit"*. The licensing clause is in the footnote. **No R², pooled or per-community** |

**A1 carried the one comprehension risk and it is answered twice.** Opacity conventionally
reads as confidence, so the boldest points here are the *least* internally consistent —
the opposite of what a reader expects. The legend title states it and the footnote states
it again: *"the more varied the area, the more solid the point — so the boldest points are
the least internally uniform, not the most certain."* The ramp is floored at 0.45 rather
than near-transparent because this is a **fourth** channel on a figure already carrying
colour, size and position, and the least-varied areas must not drop off the page.

`veg_p05_within_sd` is **not a standard error.** It does not shrink as an area gets
larger, and it is a spread across space, not across time. Both statements are in the
registered caption so the channel cannot be re-read later as precision.

**A5's suppression is deliberate and recorded.** Aeolian's r is **−0.161** across a
1–12% water range. It lives in `PARTSCATTER_community_support.csv` and in this report;
it is not on the face. Printed beside +0.70 and +0.71, a Council reader sees dry country
doing worse with more water — which a correlation of that size across that range cannot
say. The table carries an `r_suppression_note` column stating exactly that, so the
decision is legible to whoever opens the file next rather than living only here.

---

## 1 · Decisions needed

**One, and it is not blocking: I hold no issued text for Ruling EB.** It was cited as
standing for QUICKWINS-1 and UNZONED-1, and as the rule the INVENTORY-1 session's
`c2a2627` ran against. Neither task is this one and nothing in this render depends on it,
so I proceeded — but §9's rule is that a ruling number without issued text is not a
ruling, and I did not act on it. **EB's text is wanted before either of those tasks
starts.** The eleven in §9 plus EH are what this seat holds.

Every fork carried a pre-registered rule and each was executed or overridden in place.
The two items below are recorded for the design seat, not blocking.

- **The client's "eight vegetation communities" has no product behind it.** The 115 is
  ours — PARTREG's part count at a 33-cell floor — but it covers **three** non-treed
  communities, not eight. The slide pairs our part count with a community count from a
  different layer. The figure states that it shows three; whether the client's slide is
  corrected is his call.
- **`metric_id` is NULL on this row**, as on every row both registrar paths write. Held
  under DJ, carried forward untouched.

## 2 · Checks

Both are checks that can fail: each halts the prepare step on drift past its tolerance.

| check | what it tests | tolerance | result |
|---|---|---|---|
| **1 · paddock grain** | the census route reproduces the **published** `v_zone_floor_flood_residual.mean_flood` the client has already seen on the 64-paddock figure | 0.05 pp | **max 0.004983 pp**, mean 0.002531, over 64 paddocks |
| **2 · part grain** | the census route reproduces PARTREG's independently built part-year `inund_pct` series, averaged over years | 0.35 pp | **max 0.000012 pp**, mean 0.000004, over 100 parts |
| **3 · denominator** | `valid_years` constant, without which the x identity does not hold | exact | `[35]`, all 1,080,157 cells — halts otherwise |
| **4 · registration** | registered checksum against the file on disk, first-50-MB SHA-256 | exact | match; `path_exists = 1`, all five qualifiers present |

**Why check 1 matters more than its size suggests.** The x axis is computed as the mean
over a part's cells of the census parquet's **counted** per-cell `flood_freq_pct`. That
is exactly equal to the mean over years of the part's within-year wet share, because
both sides are `100 / (35·N) × Σ wet_years`, and `valid_years = 35` everywhere. The
identity is algebra, not approximation — but it is the *cell population* that could
still differ, and check 1 is what proves it does not. The residual 0.005 pp is the
published view's own rounding, not a population difference.

**Ruling DM.** Water comes from the census **parquet** (COUNTED-8058, the analysis source
of truth), never the census **view**. No interpolated surface enters this figure.

## 3 · Overrides

**One, and it changed the output. It is now Ruling EH** — accepted and promoted by the
design seat, and written into `docs/Gayini_issues_log.md` because it binds every future
per-community figure, not only this one:

> A per-community smoother is fitted only where the community's central 10th–90th
> percentile of the water axis spans a usable range; min-to-max does not qualify a fit.
> Both measures are retained as columns so any exclusion is auditable.

**The smoother fork's range test.** Spec §3 pre-registers: *if a community's water axis
spans too narrow a range to support a smoother, draw its points without a fitted line.*
I first wrote that as **min-to-max span ≥ 10 pp**. Aeolian Chenopod clears it — 12 parts,
10.87 pp — and would have been given a line.

It should not be. Eleven of its twelve areas lie between **1.0% and 6.1%** wet; the
twelfth sits at 11.9% and manufactures the entire margin by itself. Within the bulk,
r = **−0.16** and the tercile means are flat and slightly *falling* (47.6 → 45.3 → 44.6).
A loess there is a curve drawn across a gap by one observation — precisely what the
fork exists to prevent.

**The test is now the central 10th–90th percentile of the water axis, ≥ 10 pp**, which no
single point can fabricate. Aeolian: **4.39 pp — no line**. Riverine 22.94, Inland 29.05,
both drawn. `PARTSCATTER_community_support.csv` keeps **both** measures plus a
`passes_superseded_minmax_rule` column, so the exclusion is auditable and the letter of
the original rule stays visible beside the rule that replaced it.

This also lands where the project already stood: PARTREG found both chenopod slopes span
zero across ranges too narrow to establish a pattern, and Ruling DA forbids *"monotone in
every community"*. A fitted Aeolian line would have asserted on the face what the record
says is unsupported.

## 4 · Disagreements

**The kickoff's expected HEAD was one commit stale — not divergence, and not a halt.**
The brief names `c0af6f3` as the last commit and calls anything else a halt condition.
HEAD is `076d152`. It is **not** divergence: `HEAD == origin/main` exactly (0 ahead,
0 behind), it is a linear descendant of `c0af6f3`, authored by Hugh at 16:05 today, and
its subject — *"EE fourth string: the grey cloud is the community, not the paddock"* —
continues the very EE pass the brief describes as finished, touching only
`RUN_DASH3_20260809.md` and `R/gayini_dash2_panels.R`. §0's halt is *unresolved*
repository divergence; nothing here is unresolved. The design seat wrote the brief
between that commit and this session. **Proceeded, and said so before writing any code.**

**Resolved by the design seat:** the call was correct and the brief was at fault. Expected
commits are henceforth stated as **a prior to report against, not a halt condition**.

**The INVENTORY-1 session did perform a git operation.** The brief said it would not.
`c2a2627` landed on `main` mid-task, unpushed at the time. It staged **two explicit
paths** and absorbed nothing of this task's untracked work, so no harm — but the
concurrent-session rule exists for exactly the class of accident it came close to.

**Three defects were on the first rendered face and none showed in the exit code.**
Caught by opening the PNG, per I-40 / I-60:

1. **The subtitle ran off the right edge of the canvas** — its second line was cut
   mid-sentence at *"…too narrow a range of wetness to show a"*. Unwrapped text on a
   wider-than-usual canvas. Now `strwrap`ped to 150 and three lines.
2. **Both smoother bands were grey**, so between 17% and 30% wet — where they overlap —
   neither could be attributed to its line. Each band is now tinted to its own community.
3. **The caption called all 38 excluded areas "woodland or forest".** They are not:
   **34** are woodland/forest and **4** are *Other / minor units*, which leave by the
   `regime_band <> 'context'` test rather than the canopy one. Fixed at source — the
   prepare step now writes `PARTSCATTER_excluded_communities.csv` and the producer reads
   the split and asserts it sums to 38, so the wrong sentence cannot be rewritten.

Defect 3 is the one worth keeping: the number was right and the *reason attached to it*
was wrong, which is the shape of the AY/AZ label family this register already tracks.

## 5 · Artefacts

| path | what |
|---|---|
| `Output/figures/temporal/PARTSCATTER_part_temporal_p05_vs_water.png` | the deliverable, registered |
| `scripts/14_diag/PARTSCATTER_prepare.py` | the regrouping job and its four checks |
| `R/diag/PARTSCATTER_figure.R` | the render and the one-transaction registration |
| `Output/temporal/PARTSCATTER_scatter_input.csv` | 100 parts, five qualifiers as columns |
| `Output/temporal/PARTSCATTER_community_support.csv` | per-community n, ranges, smoother decision, both span rules |
| `Output/temporal/PARTSCATTER_reconciliation_chain.csv` | the §2 chain, counts and areas |
| `Output/temporal/PARTSCATTER_excluded_communities.csv` | the 34/4 split |
| `Output/temporal/PARTSCATTER_dropped_parts.csv` | the 18 areas below the floor |
| `docs/reference_update/Gayini_caption_register.md` | figure section + both labels |

### The reconciliation chain (§2, §7)

| step | areas | cells | ha |
|---|---:|---:|---:|
| all paddock × community areas inside the 64 paddocks | **156** | 885,292 | 55,199.2 |
| non-treed | **118** | 795,602 | 49,606.9 |
| at or above the 500-cell floor | **100** | 792,862 | 49,436.1 |
| plotted | **100** | 792,862 | 49,436.1 |

Excluded: 34 Floodplain Woodland / Forest (84,952 cells, 5,296.9 ha) · 4 Other / minor
units (4,738 cells, 295.4 ha) · 18 below the floor (2,740 cells, 170.8 ha — **0.34%** of
non-treed ground, sizes 1–495; 11 Riverine, 7 Aeolian).

**Against the client's 115: we plot 100.** The 115 is reproduced exactly by our own
PARTREG series — 118 non-treed parts, 115 carrying ≥ 25 water years of ≥ 30 valid cells,
at a **33-cell** floor — over the **same three** communities, not eight. The difference
between 115 and 100 is the size floor alone. **Nothing was adjusted to reach 115.**

### Per community (§7)

| community | parts | paddocks | cells min–max | water range % | 10–90 span | smoother | r | within-area spread |
|---|---:|---:|---:|---:|---:|---|---:|---:|
| Inland Floodplain | 61 | 61 | 588 – 32,399 | 5.9 – 58.9 | 29.05 | **drawn** | **+0.701** | 3.40 – 23.23 |
| Riverine Chenopod | 27 | 27 | 623 – 22,565 | 3.0 – 33.3 | 22.94 | **drawn** | **+0.708** | 4.35 – 19.58 |
| Aeolian Chenopod | 12 | 12 | 615 – 16,554 | 1.0 – 11.9 | **4.39** | **not drawn** | −0.161 *(not printed)* | 5.33 – 15.08 |

**r is computed on the data, across areas, never taken from the smoother.** What licenses
it as a number rather than a decoration is the parts-equal-paddocks column: 61/61, 27/27,
12/12. Every area inside a community comes from a different paddock, so the units the
correlation runs over are independent. **No R², pooled or per-community** — a fit
statistic is a coefficient (§3), deviance explained is not comparable across smoothers
that chose different effective degrees of freedom, and a pooled R² would largely be
measuring that Inland country is both wetter and greener than Aeolian country: true, and
not what this figure claims. **PARTSCATTER-2, after Monday.**

**Does the paddock figure's dominance problem move to a new grain? No — it improves, but
it does not vanish.** At paddock grain 55 of 64 units were Inland-dominant (86%). At part
grain Inland is 61 of 100 (61%), and Riverine gains a genuinely usable 27 parts spanning
30 pp of water — enough to carry its own line, which it could not do before. Aeolian
gains representation (12 parts, visible as its own colour) but **not** range: it remains
dry country and 11 of its 12 areas sit below 7% wet. So the colour now means something
for two of the three communities and identifies the third without asserting a slope
through it.

### Two findings worth keeping

- **Within every fitted line, each part comes from a distinct paddock** — parts = paddocks
  is 61/61, 27/27, 12/12. 62 of the 100 parts do share a paddock with another plotted
  part, but always in a *different* community. So L-01 clustering is real across the
  figure and **absent inside each community's line**. The caption states exactly that
  rather than hedging generically.
- **The wet end of the Inland line rests on one area.** Bala 22, 58.9% wet, the only
  Inland part above 50%. Disclosed on the face — the same disclosure the paddock figure
  carries, and the reason the band flares there.

## 6 · Not done

- **Nothing in the spec or the amendments is outstanding.** §§2–7 and A1–A5 are complete.
  Nothing was shipped-without.
- **Held under DJ, untouched as instructed:** Bala 23 inset overlapping its map panel
  title · four locator paths needing consolidation · `metric_id` NULL on both registrar
  paths (this run adds one more such row) · the unexercised `gayini_area_map` locator
  parameter · EA/EC compliance on the `report_figures` producer.
- **Also held under DJ — the five-qualifier schema gap.** `figure_asset` has no
  `scope_filter` / `pixel_constant` / `denominator` / `period_label` column, so four of
  the five are written into `provenance_note` **as prose**. The rule is therefore
  satisfied by text rather than by schema, which means **it cannot be queried** — no
  `SELECT` can find every figure at a given denominator, and drift in one of them cannot
  be detected by anything but reading. A registry change for next week, not a
  two-days-out edit.
- **Not started, correctly:** INVENTORY-1, QUICKWINS-1, UNZONED-1. The latter two need
  EB's issued text first.
- **PARTSCATTER-2** (fit statistics done properly, per-community and pooled) is deferred
  past Monday by decision, not by omission.

## 7 · Rulings

**Applied:** **AZ / CX** — x is the share of cells seen wet, mean over years; never
labelled a between-year frequency, on the face or in the registry. **DA** — each
community's own supported range is stated; *"monotone in every community"* is not
written, and the community that would have made it false gets no line. **DM** — water from
the census parquet, not the view. **DP** — this schema. **DS** — every script written to a
file and parse-checked before rendering; no heredoc. **EA** — no `veg_p05`, `fit_id`,
`number_id`, issue code, ruling letter or path on the face. **EC** — y is the registered
canonical label verbatim; x is registered as the new canonical for the part-grain water
quantity. **L-01** — stated precisely, including where it does *not* bite. **C10** — pixel
support throughout, no plot measurement. **§8** — `veg_p05_spatial` never appears and the
word *"floor"* is absent from the face; the paddock figure is additive-only and stands.

**Newly in force: EH**, quoted at §3, issued on this task's override and written to
`docs/Gayini_issues_log.md` because it binds every future per-community figure.

**Not cited, and not available: EB.** No issued text is held for it. It was named as
standing for QUICKWINS-1 and UNZONED-1 and as the rule `c2a2627` ran against; neither is
this task, nothing here depends on it, and it was not acted on. §9 carries eleven, plus
EH: all twelve are quoted above or were checked and found not to bind.
