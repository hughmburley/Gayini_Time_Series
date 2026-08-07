# XCHECK-1 — the cross-artefact review

**7 August 2026.** Ruling AX: run to completion, report once, register nothing. **Nothing was fixed** —
no factual contradiction *inside a single shipped artefact* was found, which is the only exception §6
allows. Everything below is reported.

Read-only on the database throughout. Nothing written to `Output/pack/**`.

---

## List 1 · What a reader of this pack could be misled by today

Ordered by how likely a reader is to hit it.

**1 · Two conserved paddock reports call a part "ordinary" that is third and fifth worst on the
property once water is allowed for.** Bala 26ca's Inland part reads **"21st of 61 — ordinary"**; on
the water-adjusted basis it is **3rd of 61**. Bala 28ca's reads **"45th of 61 — ordinary"**; adjusted
it is **5th of 61**. The reports state the raw rank only and attach the word *ordinary* to it. Both
paddocks are conserved, so both are the ones Adrian is most likely to open. **This is the single most
misleading thing in the material.**

**2 · The headline figure's x-axis states a denominator of years on a quantity measured in cells.**
`F5_cover_vs_water_64_paddocks.png` — Figure 25 — plots `mean_flood`, the mean over years of
`flood_frac_pct`, under **"Mean annual flood frequency (% of years wet)"**, and its registered caption
says *"largely set by how often it floods"*. Same family as Ruling AY, on the project's most-shown
figure. In pack v1.2 and in the methods document at V13.

**3 · The QGIS style in the sealed pack does not match the printed maps.** Known and reported
yesterday: `geodata/PARTREG_part_residuals.qml` in `c844807a…` spans ±27.64 against the printed
±32.36. Fixed at source; the sealed copy is superseded by the loose attachment.

**4 · The ground-cover metadata record quotes numbers from a table that does not ship.** The
usable-season figures — 3.465 of 4, 64.6%, WY1994 at 2.243 — are asserted from
`tier2H_g1a_annual_veg_valid_seasons.csv`, which is not in the pack. **This is the v1.2 failure mode
repeating in a new artefact.**

**5 · Bala 15's report presents a two-part paddock as single-community without saying so.** Only
Inland is named; the Riverine sliver (23 cells, below support) is absent and no sentence explains
that something was withheld. A reader concludes the paddock is one community.

---

## List 2 · What could not be cross-checked

**Anything asserted in one place only cannot be cross-checked, and is read rather than verified.**

- **Both unzoned figures, almost entirely.** No registry row, no manifest entry, no register caption —
  so §§1–4's pairs have no second side. What *could* be checked was: the axis quantities against the
  producer, and every number against the R-side fits. What could not: any caption claim, because the
  caption is the producer.
- **Bala 6 and Mara 11 reports** — not present in the 32-report folder on disk, so two of the eight
  sampled reports were checked against the registered table only in the direction *table → expected
  value*, never against a rendered document.
- **The corrected dual-grain figure** — not re-rendered, because its producer registers as it renders.
  The corrected labels exist in source and nowhere else.
- **The QGIS rendering itself.** The `.qml` check reproduces the classification arithmetic and the
  colours faithfully, but QGIS has still never opened the file.
- **`PARTREG_S2_part_period_attributes.csv` and `T2_in_scope_points.csv`**, cited in pack prose and
  not shipped — cited as provenance pointers rather than as sources of quoted numbers, but the
  citation is one-sided either way.

---

## §1 · Pair A — caption text against what the producer plots

| figure | numbers traced | labels agreeing | claims visible |
|---|---|---|---|
| three periods | 12 of 12 | 2 of 2 | 4 of 4 |
| residual maps (3-panel + 3 single) | 5 of 5 | 1 of 1 | 3 of 3 |
| bootstrap | 14 of 14 | 2 of 2 | 5 of 5 |
| UNZONED F1 / F2 | 14 of 14 | 4 of 4 | see §5A |

**Every number in the two pack captions resolves** to a `fit_id`, a `number_id` or a named table —
the register carries a Sources block for each, and the three weighted R² values now carry
`cap_weighted_r2_*` ids.

**§1.3 passes on the item that failed before.** The dashed cropping-era line lost its annotation in
one rebuild while the caption went on referring to it; it now has a legend entry, and the claim is
checkable from the face.

---

## §2 · Pair B — schematic against metadata record

**§2.1 step for step.** SCHEM-1's boxes against the ground-cover record's five chunks: source → annual
reduction → resample → footprint → extraction. **Same order, same parameters** — bilinear once for
cover, nearest twice for water, 24.970268 m, EPSG:8058, 5th percentile across cells within a year.

**§2.2 number for number.** The footprint ladder agrees in all three places — schematic, metadata
record, live database: **85,911 → 67,349 → 61,655 → 49,607 ha**, 795,602 cells. No disagreement.

**§2.4 / §2.5 — the widened sweep. This is the section with findings.**

### The two Ruling AY families, swept across every producer and every registered caption

**Family 1 — a label naming `veg_p05` where the quantity is `veg_p05_spatial`: ONE instance, already
ruled.**

`build_T11_v2_dual_grain.R:133`, corrected under AY. Every other `veg_p05` label checked resolves to
a producer that genuinely reads the census temporal floor:

- `24_build_figA_floor_gradient_density.R`, `26_…scatter_deck.R`, `27_…quantile_bands_deck.R`,
  `28_…percentile_fan.R` all read `total_veg_p05_8058.tif` — the temporal p05. **Labels correct.**
- `T1_gateD_figure.R` reads `v_zone_stratum_treatment_contrast`, which is built on
  `census_by_zone_stratum.veg_p05_mean` — temporal. **Label correct.**
- The T3 caption family says *"census `veg_p05`, the across-series 5th percentile"* explicitly.
  **Correct, and a model for how to name it.**

**Family 2 — a label stating a denominator of YEARS on a within-year share: THREE instances, one new.**

| # | site | what it plots | what the label says |
|---|---|---|---|
| 1 | `build_T11_v2_dual_grain.R:136` | `AVG(flood_frac_pct)` | `flood (% yrs)` — **ruled, AY** |
| 2 | its registered caption | same | *"how often the ground floods"* — **ruled, AY** |
| **3** | **`build_adrian_pack_T1_F3_F5.R:309`** | **`mean_flood` from `v_zone_floor_flood_residual`** | **"Mean annual flood frequency (% of years wet)"** |
| **3b** | **its registered caption, `figure_f5_cover_vs_water_64_paddocks`** | same | ***"largely set by how often it floods"*** |
| **3c** | **`PACK1_build_workbook.py:80, 85, 125`** | the same fit, r = 0.71 | ***"How often a paddock floods correlates with its floor"*** |

**Instance 3 is the design seat's report-stream sighting, and it is the same figure as Figure 25.**
Its **y-axis is correct** — `"Cover floor, veg_p05_spatial (%)"` — while its x-axis is wrong. The
producer named the cover quantity precisely and got the water quantity's denominator wrong in the
same `labs()` call.

**3c matters because it shipped.** The pack v1.2 workbook carries the same framing three times, so
the error is in delivered prose, not only in a figure.

**The pattern, stated.** Every instance is on the **water** side, and every one is in the
**zone/part-grain chain that uses `flood_frac_pct`**. Not one is in the census chain that uses
`flood_freq_pct`, where the between-year language is correct. **The error is not random: it is what
happens when a newer within-year quantity inherits the vocabulary of the older between-year one.**

**Two counter-examples worth keeping**, because they show the convention working:

- `figure_taskJ_F4`: *"Wet extent is per-year spatial coverage, **NOT** the headline between-year
  flood frequency."*
- `figure_u2_epoch_context_35yr`: *"it is **NOT** the census temporal `veg_p05`, which is a different
  object."*

---

## §3 · Pair C — metadata counts against the live database

**10 of 10 counts re-derived and agreeing**, by queries written for this check rather than by
re-reading the documents.

Both derivations still multiply out: **2,240 = 64 × 35** plus 2,116 = **4,356**; **4,130 = 118 × 35**
plus 4,012 = **8,142**. The 118 absent `jja_son` part-years remain **75 in WY1993, 32 in WY1996, 7 in
WY1994, 4 elsewhere**.

**§3.3 — the "all / every / none" class.** The 8058 raster counts the metadata record states, 45 total
and 29 confirmed, **still agree today**. CLAUDE.md still says "all 18" and is still stale, unedited by
design. No new instance of the class found in either metadata record, the covering note or the data
dictionary.

**§3.4 — the three gradients** re-derived: **4.5 / 14.1 / 30.2** on the PARTREG axis, matching the
inundation record, with the scope attached to each correct.

---

## §4 · Pair D — the manifest against the world

| check | result |
|---|---|
| §4.1 manifest against disk | 13 rows, **no file's hash has moved** since assembly |
| §4.1 members | **15** = 13 manifested + manifest + `SUPERSESSION.md` |
| §4.2 against the registrar | **7 of 7** registered files agree; **6** marked NOT REGISTERED |
| §4.4 sealed hash | **`c844807a57023ad4…` INTACT.** Nothing wrote to the sealed pack |

**§4.3 — asserted-from, and this is where it fails.** `tier2H_g1a_annual_veg_valid_seasons.csv` is
quoted for three numbers in the ground-cover record and **is not in the pack**. Two further tables are
cited as provenance pointers and not shipped: `PARTREG_S2_part_period_attributes.csv` (data
dictionary) and `T2_in_scope_points.csv` (ground-cover record, chunk 5). The coefficients table that
v1.2 failed on **is** shipped this time.

---

## §5 · Pair E — the eight paddock reports against the registered table

Checked by querying `PARTREG_part_residuals.csv` directly and comparing to text extracted from the
rendered `.docx`, not against the builder's own inputs.

**§5.4 — the control passes exactly.** Bala 29ca's Aeolian third is **1 of 17 on both bases**; its
Riverine third **2 of 37 on both**; only its Inland third moves, **10 → 48**. Precisely as
pre-registered. **The join is right and §5's findings stand.**

**§5.1 — every rank in every readable report matches the registered table.**

| report | raw rank, as printed | water-adjusted | move |
|---|---|---:|---:|
| Bala 26ca · Inland | **"21st of 61 — ordinary"** | **3** | −18 |
| Bala 26ca · Riverine | "13th of 37 — ordinary" | 15 | +2 |
| Bala 28ca · Inland | **"45th of 61 — ordinary"** | **5** | −40 |
| Bala 28ca · Riverine | "14th of 37 — ordinary" | 16 | +2 |
| Bala 29ca · Aeolian | "lowest of 17" | 1 | 0 |
| Bala 29ca · Riverine | "second-lowest of 37" | 2 | 0 |
| Bala 29ca · Inland | "among the lowest of 61" (10) | 48 | +38 |
| Dinan 10 · Inland | "second-lowest of 61" | 30 | +28 |
| Dinan 10 · Aeolian | "second-lowest of 17" | 2 | 0 |
| Bala 15 · Inland | "lowest of 61" | 1 | 0 |

**§5.2 — the reversal is silent, and the caveat sentence belongs on the raw-rank line itself.** Every
report states the raw rank and none states the adjusted one. **The word attached to the raw rank is
"ordinary"**, which is where the harm is: it is an interpretation, not a number, and it is wrong for
Bala 26ca and Bala 28ca. REPORT-2's caveat needs to sit **immediately beside the "— ordinary"
verdict**, not in a footer.

**A count to reconcile.** At a threshold of *any part moving 20 or more ranks within its community*,
**25 paddocks reverse**, not sixteen. The design seat's sixteen uses an unstated threshold. Both are
reported; neither is authoritative until the threshold is defined.

**§5.3 — the two slivers behave differently.**

- **Bala 15** names **only Inland**, has **no parts page**, and carries **no sentence** saying a
  second part exists below support. It reads as a single-community paddock and is not one.
- **Bala 28ca** names all three communities and **does** have a parts page — so its 10-cell Aeolian
  fragment is handled differently from Bala 15's 23-cell Riverine one. **Two sub-support slivers, two
  treatments.** Neither report uses the words "not assessed" or "below support".

---

## §5A · The two unzoned figures

**The pairwise method mostly does not apply, and that is the first finding.** No registry row, no
manifest entry, caption held in the producer. Most of §§1–4 has no second side.

**§5A.1 — both label families are clean.** The producer reads **`veg_p05_spatial`** and never the
census temporal `veg_p05`; the water axis reads `inund_pct`, which is `100 × wet_pixels ÷
valid_pixels` — **a cell denominator**, and the axis says *"share of the unit's cells seen wet"*. The
family that was wrong in `build_T11_v2_dual_grain.R` is right here.

**§5A.2 — every number traces.** +0.2106, +0.1613, 3,253, 4,025, 93, 115, 91/91, 115/115, 4,486, 293,
1.18 decades, and the registered line all resolve to `UNZONED_stageA1_fits.csv`, `WITHIN1_fits.csv`,
the per-patch/per-part slope tables or `dim_headline_number`. **No untraced number.**

**§5A.3 — F1 does not show what it says, quite.** Marker area is `6 + 150·√(cells/32,399)`. The two
medians the figure names come out at **20.3 pt² and 61.8 pt²** — an **area ratio of 3.0× and a
diameter ratio of 1.75×, for a 15.3× difference in cells.** The gap is visible but heavily
compressed, and the figure states 1.18 decades in words while the eye sees less than a doubling of
width. **The claim that the size gap "shows rather than being stated" is only partly true.**

**§5A.4 — 7,278 points on panel A**, over the display convention's threshold for all-pixel figures
where bands or a density are the rule. Internal and provisional, so it stands. **Recorded as a known
limitation.**

**§5A.5 — should they move to the register?** They should, and the cost is small: the producer already
imports nothing from it, so it is one `blocks()` call per text block plus a register section — roughly
the work done for the maps figure. The argument for is that the register caught a real parser bug on
its first render. The argument against is that these are provisional and may never ship. **Not moved.**

**§5A.6 — unchanged, as required.** F1's red DESCRIPTIVE ONLY banner is present and verbatim. The
`PROVISIONAL · unregistered · for reference, not for onward circulation` stamp is on both. Neither is
in `figure_asset`; neither is in the manifest.
