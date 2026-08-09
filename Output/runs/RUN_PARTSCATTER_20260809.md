# RUN · PARTSCATTER · 9 August 2026

Spec: `docs/reference_update/Gayini_CC_spec_PARTSCATTER_update.md`. Schema per Ruling DP.

**Delivered:** `Output/figures/temporal/PARTSCATTER_part_temporal_p05_vs_water.png`
2000 × 1125 px (13.333 × 7.5 in at 150 dpi), 16:9, drops into a slide without rescaling.
Registered `figure_partscatter_part_temporal_p05_vs_water`, checksum `173fdd2d0945…`.

---

## 1 · Decisions needed

**None outstanding.** Every fork carried a pre-registered rule and each was executed or
overridden in place. The two items below are recorded for the design seat, not blocking.

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

**One, and it changed the output.**

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

| community | parts | paddocks | cells min–max | water range % | 10–90 span | smoother |
|---|---:|---:|---:|---:|---:|---|
| Inland Floodplain | 61 | 61 | 588 – 32,399 | 5.9 – 58.9 | 29.05 | **drawn** |
| Riverine Chenopod | 27 | 27 | 623 – 22,565 | 3.0 – 33.3 | 22.94 | **drawn** |
| Aeolian Chenopod | 12 | 12 | 615 – 16,554 | 1.0 – 11.9 | **4.39** | **not drawn** |

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

- **Nothing in the spec is outstanding.** §§2–7 are complete.
- **Held under DJ, untouched as instructed:** Bala 23 inset overlapping its map panel
  title · four locator paths needing consolidation · `metric_id` NULL on both registrar
  paths (this run adds a 279th such row) · the unexercised `gayini_area_map` locator
  parameter · EA/EC compliance on the `report_figures` producer.
- **Not started, correctly:** INVENTORY-1, QUICKWINS-1, UNZONED-1.
- **`figure_asset` cannot carry the five qualifiers as columns.** It has no
  `scope_filter` / `pixel_constant` / `denominator` / `period_label` field, so they are
  written into `provenance_note` verbatim and as columns in the scatter-input CSV. Noted
  rather than fixed — a schema change is not this task's business two days out.

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

**Not cited, and not available:** no ruling number was used for which this seat holds no
issued text. §9 carries eleven; all eleven are quoted above or were checked and found
not to bind.
