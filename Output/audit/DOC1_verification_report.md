# DOC-1 — verification of the methods document

**Read-only audit. Nothing in the document was changed; no analysis was run; no registry was written.**
Spec: `docs/reports/CC_spec_DOC1_document_verification_v2.md`.
Gate records: `DOC1_gateA_verify_answers.md` · `DOC1_gateB_value_claims.md` · `DOC1_gateC_figures_methods.md` ·
`DOC1_gateD_substitution.md` · claim table `DOC1_claim_check.csv` (224 rows) · figure mapping
`docs/reports/DOC1_figure_manifest_v6.csv`.

**Audited input.** `docs/reports/Gayini_RS_methods_doc_V6.docx` · 9,821,125 bytes ·
modified 2026-08-04T13:15:07 · SHA-256 `63177e5fc45a9a02072abd654349d8d2eb75d9fb111db2c6260e4751e78e584b`.
Hash recorded at Gate 0 and re-checked at the open of Gates B, C and E — **unchanged throughout**, so every
verdict below attaches to one fixed version of the document. The title block reads "Draft v6", agreeing with
the filename; the spec's warning that the version string has been wrong before does not bite on this draft.

**The short version.** Two claims are contradicted, both support-level errors. Three method descriptions are
simpler than their implementations. Three figure-level defects. Five unstated conventions where the number is
right and a clause is missing. **And 127 of the 175 value and structural claims were never checked** — that
last number is the honest headline, and it should be read before any of the confirmations.

---

## 1 · CONTRADICTED claims

Two. Both were found by querying a source that had previously been read off a rendered figure, and both are
the same error: **a numerator from one support paired with a denominator from another.**

### 1.1 · §7.3 — "Six of the eight measurable strata meet the 0.20 reporting threshold"

**Found: five of eight.** Eight strata have a defined `median_r`; five reach 0.20 — Riverine mid and high,
Inland low, mid and high. The census `verdict` column reads `responds` for exactly those five.

**The 6 is the plot-support count.** `plot_verdict = 'responds'` holds for six of *nine* strata, the extra one
being Aeolian high, whose plot-support median *r* is 0.2644 against a census `median_r` of 0.1754.

Source: `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`, whose own header warns that
the `plot_*` columns are a *"PLOT-support benchmark (reference, not a target)"*. CLAUDE.md's C10 rule forbids
merging supports in one statement.

Correct at census support: **five of the eight measurable strata**, or five of nine counting the
never-flooding Aeolian low band.

**How it happened, and this is the part worth keeping.** The figure is not at fault. Figure 7 (`S26`) draws
both supports *deliberately* — a filled marker for census *r*, a **hollow diamond explicitly labelled
"Plot-support r (reference)"** — and its own caption names the exact stratum:
*"note Aeolian high (plots 'responds', census does not)"*. The figure was read without its caption, which is
the failure the caption exists to prevent. That is a lesson about how the document was assembled, not only a
wrong number.

### 1.2 · §6.5 — "Applying the 0.20 cut without the sign-consistency condition would classify some strata differently"

**Found: no stratum is classified differently.** `SIGN_FRAC = 0.70`
(`scripts/03_inundation_products/20_run_census_veg_wet_response.R:55`) and the minimum `sign_frac_pos` across
the eight measurable strata is **0.861**. The sign condition never binds on this data — the cut alone and the
full two-part rule both return the same five strata.

The two-part rule itself is real and is described correctly. What cannot be said is that it changes any
answer here.

---

## 2 · The VERIFY flags

**Current inventory: six flags, re-established from v6 rather than inherited from the previous draft** — and
matching the spec's expected table exactly. The eight answered at Gate A were against the pre-correction
draft; corrections closed three and opened two.

| # | § | status |
|---|---|---|
| 1 | §2 — provider metadata for the ingested products | **OPEN, external.** See §3.1 |
| 2 | §6.1 — regression diagnostics | **OPEN, needs new analysis.** See §3.2 |
| 3 | §6.5 — the A/B seasonal reductions | **CONFIRMED as flagged.** Two reductions exist: base = mean of available seasons; cross-check = JJA/SON with the base recomputed on the same cell set. The document describes the base series only, and now says so |
| 4 | §6.5 — the sign-consistency proportion | **ANSWERABLE, and now answered: `SIGN_FRAC = 0.70`.** The flag correctly directs the reader to the code. Note §1.2 above — the proportion never binds on current data |
| 5 | §12.3 — next-steps priorities not agreed | **ACKNOWLEDGED, not verifiable.** Whether a priority ordering has been agreed is not a property of the code or the database. No verification attempted and none is possible |
| 6 | References — unresolved citations | **OPEN, external.** See §3.3 |

---

## 3 · UNVERIFIABLE claims

### 3.1 · §2 — FC algorithm version, cross-sensor calibration, Landsat 7 SLC-off

No code in this repository computes fractional cover; the rasters are ingested as an external product.
Repo-wide search for `SLC`, `scan.?line`, `slc_off`, `calibration`, `JRSRP`, `Guerschman`, `fc_version`
returns nothing describing any of the three. `dim_source_product` carries one line per product and no version
string, DOI, calibration statement or SLC-off handling.

**What would be needed:** the provider's product metadata. Cannot be closed from this repository.

*Worth noting:* `dea_landcover_l3` — the product that produced a **negative** result — carries a full
identifier (`ga_ls_landcover_class_cyear_3 v2.0.0`). The two headline products are documented to a lower
standard than the one that was discarded.

### 3.2 · §6.1 — regression diagnostics

**Not computed anywhere.** Repo-wide search for `shapiro`, `breusch`, `leverage`, `hat_`, `cooks`: zero hits.
Residual normality, constant variance across the flood-frequency range and per-paddock leverage are assessed
in no script. The flag is correct: they are unreported because they were never computed.

**What would be needed:** running them — new analysis, out of scope. A different robustness check does exist
(three alternative fits whose intercept spread is registered) and is not a substitute.

### 3.3 · References — six citations

The repository holds no bibliography. The Dawson et al. (2016) distance-to-reference paper named as the
design template for §6.1 appears **nowhere** — not in the reference list, not in a code comment, not in any
document — and §6.1's method as implemented is a plain bivariate OLS with no attribution in the code.
**Whether that citation belongs there at all is a design-seat question, not a repository one.**

### 3.4 · Figure 10 — "and follow the channel network"

**No channel or watercourse layer is registered anywhere in the project** (`spatial_layer_asset`, 9 rows) or
present under `Input/` (issues log T3-I5). The only hydrological geometry is `irrigation_bank_cuts`, which is
Task J irrigation infrastructure and would be a category error as a substitute.

The document's own limitations paragraph states this. The assertion precedes its qualification by two
sentences.

### 3.5 · Figure 8's extent — unverifiable, and the reason decides the substitution

Asked to check whether `M1_veg_percentile_maps_p05_p50.png` covers the same extent as the current Figure 8.
**The check cannot be run.** `S_floor_and_typical_mapped.png` **is not on disk anywhere in the repository and
has no producing script** — it exists only as bytes inside the docx and the source deck. Its extent is
unknowable from here.

The same is true of all four unregistered figures: **Figures 2, 3, 5 and 8 have no file on disk and no
producer in the repository.** They are not merely unregistered; they are **unreproducible**.

That does not answer the extent question, but it does settle the decision, and in a stronger direction than
extent equivalence would have: the current figure can never be re-rendered or checked by anyone from this
repository, and M1 can — M1 is cropped and masked to the property boundary, "All-pixel census, EPSG:8058,
24.97 m" (`taskM_gateD_M1_percentile_maps.R:46,90`). **Recommendation stands, on provenance rather than on
established extent equivalence.** Stated plainly so the swap is not recorded as extent-verified when it is not.

---

## 4 · STALE claims

**None found in the document.**

One stale artefact was found **in the code**, and it would have made a correct document look wrong:
`scripts/12_zone_stratum/T6_gateE_figures.R:112` reads *"On Aeolian these are -30.9 and -10.5"*. The adjusted
value is right; the raw value is the pre-correction figure from before the early-August F6 remediation. The
query one line below computes **−32.044**. The query was updated; the comment was not. Logged as **D1-I3**.

---

## 5 · Figure and caption defects

### F-1 · Figure 10's 5 ha statement does not hold for the class it draws in yellow

The caption reads *"Connected components smaller than 5 ha removed."* True of each **input** surface — both
ship with zero components under 5 ha. **Not true of the intersection as drawn: 20 of the yellow class's 50
components are smaller than 5 ha, totalling 28.5 ha.** The filter ran before the intersection, not after.

### F-2 · Figure 10's green layer is 500 ha; the text beside it quotes 6,458 ha

| layer | area drawn |
|---|---|
| total-cover floor ≥ 75 (blue) | 7,969.70 ha |
| green-share floor ≥ 50 (green) | **500.06 ha** |
| both (yellow) | 406.09 ha |

Figure 9's discussion states the green-share extent as **6,458 ha at native 30 m** — correct, and correctly
labelled. Figure 10 draws it from the **8058** surface **after** the 5 ha filter: **500.06 ha**. The same
nominal object differs by a factor of **13** between adjacent figures, with nothing telling the reader.

Two operations compound: reproject-then-threshold rather than threshold-then-reproject (issues log **T3-I1**,
already a standing rule), then the component filter, which removes ~87% of what remains because the surface
is narrow strips. The blue layer has the same structure at 4%: text quotes 8,300 ha from the sweep, figure
draws 7,969.70 ha.

**No sentence here is false**, which is why these are figure defects rather than contradictions.

### F-3 · Four figures have no provenance record of any kind

Figures **2** (`C1_checkerboard_farm.png`, §3.1), **3** (`S_annual_wet_extent_flow.png`, §7.1), **5**
(`H6_absolute_flood_zones.png`, §7.1) and **8** (`S_floor_and_typical_mapped.png`, §7.4) match no
`figure_asset` row by checksum or filename, **and** are absent from disk, **and** have no producing script.
All four came from `Gayini_Veg_samples_ALLPIXEL_v6_20260724.pptx`.

**Figure 5 is the load-bearing one:** it is the absolute-zones figure that §3.1 and §7.1 both cite as the
comparable alternative to the within-community terciles — the thing the tercile caveat points at — and it has
no provenance record anywhere. Logged as **D1-I4**.

### Verified clean

**Numbering and cross-references.** 25 captions, numbered 1–25, each number used exactly once, no gaps,
ascending document order. All 13 body cross-references resolve. The extra `Figure 6.` occurrence flagged at
Gate 0 is a body cross-reference, confirmed by parse rather than assumed. 16 of the 25 figures are never
referenced in body text, which makes those captions load-bearing.

**Figure-to-file mapping.** All 25 manifest hashes verified present in the v6 package, no media unclaimed,
one-to-one. Of the 25: **15 resolve to a registered asset by hash, 6 by filename** (resampled for embedding),
**4 by neither** (F-3 above).

---

## 6 · Method descriptions that do not match implementation

All three corrected descriptions — the responding-stratum rule, the sparse-bin rule, the two-stage estimator —
**were confirmed correct against the code**, together with the four additions made alongside them (the ddof
conventions, the Mann–Kendall α, the GAM specification, the tercile statement). Nothing that was corrected was
corrected wrongly. Applying the same test to the remaining method claims found three more.

### M-1 · §6.6 — the other GAM figure uses a different *rule*, not just a different threshold

The document says *"A different figure in the wider analysis applies a threshold of 2,000 cells on
5-percentage-point bins"* — a different threshold and bin width, implying the same cumulative rule.

`scripts/03_inundation_products/24_build_figA_floor_gradient_density.R:97-98`:

```r
supported <- cnt$upper[cnt$Freq >= MIN_BIN_N]
ff_cut    <- if (length(supported)) max(supported) else 100
```

That is **the last bin anywhere meeting the threshold** — a sparse bin mid-range is jumped over. It is the
permissive rule §6.6 was corrected to stop describing, still live in a second figure. A reader applying
§6.6's cumulative rule to that figure would truncate earlier than it does.

### M-2 · §6.5 — the classification rule has three gates, not two

`20_run_census_veg_wet_response.R:216-220` gates first on NA (`undetermined`), then on
`resp_cov < 100 × MIN_RESP_COVERAGE` (`coverage_limited`, `MIN_RESP_COVERAGE = 0.50`), then applies the
two-part test. **A stratum in which fewer than half the cells yield a defined *r* cannot be classified as
responding at all**, whatever its median and sign consistency.

That third gate is absent from the document. It does not bind on current data — the lowest coverage among the
eight measurable strata is 58.76% — so **no number changes**. It is a third condition in the very passage
corrected to add the second.

### M-3 · §6.6 — the Kruskal–Wallis is at plot support, inside a census-support section

§6.6 describes the dashboards' GAM as fitted *"across all census cells of a community"*, then says the
dashboards *"also report a Kruskal–Wallis test across communities on flood frequency"*, with no change of
support signalled. `R/gayini_dashboard_panels.R:328`:

```r
kw <- stats::kruskal.test(flood_frequency_pct ~ simplified_vegetation_group, data = freq_by_plot)
```

`freq_by_plot` is **plot support**, and the grouping is the 4-class `simplified_vegetation_group`, not the
three non-treed communities §3.1 defines. One panel carries a census-support smooth and a plot-support
significance test, described as though they shared a support. The code also labels the result
**"(descriptive)"**; the document does not. Same family as §1.1.

### Observation · §6.1 — "read at render time" is true, and is not the whole mechanism

No render path hardcodes the regression constants in place of reading the registry — the claim is
**CONFIRMED**. Both R render paths then assert the registry against hardcoded literals
(`stopifnot(abs(INT - 52.652934) < 1e-6, …)`). Good drift protection, worth knowing it is there: a legitimate
re-pin does not flow through to the figures, it **stops the render**.

---

## 7 · Unstated conventions — the number is right, a clause is missing

Five. None is an error; each would have prevented a reader from reproducing or comparing the value.

| # | where | the convention |
|---|---|---|
| 1 | §6.4 against §6.1 | Community SDs are **sample** (ddof = 1); the residual SD is **population** (ddof = 0). Visibly different at the stated precision — population would give 11.564 / 10.712 / 5.979. **Now stated in v6** |
| 2 | §4.4 | Bala 29ca's 51.1% temporal floor is **pixel-weighted** across the paddock's non-treed strata; the unweighted mean of the same strata is 55.6%. **Now stated in v6** |
| 3 | §M4 | *"Of 118 parts, 8 … 16 … 14 … 77"* — the four counts sum to **115**, the supported parts. The three unsupported are excluded from every count while 118 is the stated base |
| 4 | §7.4 green share | **3.03% is over the farm boundary at native 30 m — 959,833 px, 86,384.97 ha, treed included.** The persistence areas in the same paragraph are non-treed, 61,655 ha. One paragraph, two denominators differing by 40% |
| 5 | §7.3 / §6.5 | The **plot-versus-census support split**, exposed by contradiction §1.1 and running through §6.6 as M-3 |

**A trap in a source artefact, not in the document.** `Output/tables/taskM_green_at_floor_area.csv` is
tidy-long and repeats `mask = green_frac_pct > 50` on **every** row, including `green_frac_pct_median`. That
median is over all 959,833 valid floor pixels, not the majority-green subset — a median of that subset would
exceed 50 by construction. Anyone re-deriving 3.03% from the mask on its own row will fail to reproduce it.
Logged as **D1-I2**.

---

## 8 · Substitution candidates

Searched `figure_asset` (297 rows, filtered to the 158 not superseded), `table_asset` (5 rows) and the figure
manifest. **Nothing was substituted.**

| | claim served | recommendation |
|---|---|---|
| **Figure 8** | §7.4 per-cell p05 and p50 on a shared 0–100 scale | **Swap** to `M1_veg_percentile_maps_p05_p50.png` — registered, not superseded, caption already carries the census/EPSG/never-differenced qualifiers. Replaces an unreproducible extract. **Not extent-verified** — see §3.5 |
| **Figure 6** | §7.2 percentile fan | **Refuse** `FigA_floor_gradient_density.png`. Registered and superficially a natural alternative, but it implements the permissive `max(supported)` rule of **M-1**, which the document does not describe |
| **Figure 7** | §7.3 response matrix | **Keep.** No alternative improves on it, and it already carries the correction the text needs (§1.1). `S24` shows less; `S25` is a different question at plot support |
| **Figures 9, 10** | §7.4 green share and persistence | **No better figure; better captions already exist in the registry.** `T3_C`'s registered caption opens *"NO HEADLINE THRESHOLD … refugial extent is a CONTINUUM and every cut here is a chosen one"*, bearing directly on **F-2**. `T3_B2`'s carries the green-share order-statistic definition in full |
| **Figures 2, 3, 5** | §3.1, §7.1 | **No registered alternative exists.** Named, not developed. There is no registered absolute-zones figure anywhere |

**One structural note, so it is not read as an endorsement.** `table_asset` holds **5 rows** against 297
figures. The "does a better registered *table* exist" half of this gate has almost no search space, and the
absence of table substitutions is **a property of the registry, not a verdict on the document.**

---

## 9 · Counts, and the coverage that matters

### The claim table

| type | count | CSV verdict recorded |
|---|---|---|
| value | 96 | |
| structural | 79 | |
| **value + structural** | **175** | **24** (22 CONFIRMED, 2 CONTRADICTED) |
| method | 43 | 8 recorded; **all 43 examined at Gate C** |
| interpretive | 6 | recorded, not verified, by spec |
| **total** | **224** | |

### Coverage, stated plainly

**48 of the 175 value and structural claims were checked across Gates B and C. 127 were not.**

**That is 72.6% of the checkable claims unchecked**, and it is the headline of this audit. The 46 confirmations
are confirmations of a **priority list**, not of the document. A reader who takes "46 CONFIRMED, 2
CONTRADICTED" as the coverage figure will conclude the document is 96% verified. It is not: it is **27%
verified on the value and structural claims**, with a 4% contradiction rate *within the checked subset*.

The two contradictions were both found in the checked subset, and both in material read off figures. **Nothing
establishes that the 127 unchecked claims contain no third.** The priority list was chosen to cover the
numbers most likely to reach a deliverable, which is the right selection — but it is a selection.

Method claims are the better-covered half: **43 of 43 examined**, 16 corrected or added descriptions confirmed
against code, 3 found simpler than their implementations.

**Figures: 25 of 25 mapped and reconciled; 4 of 25 captions verified against producing code.** The remaining
21 are unblocked now that the manifest exists but were not done.

### Registry re-probe

**Audit window: 4 August 2026, 11:55 to 15:45.** No registry snapshot was taken at Gate 0, so movement is
reported against CLAUDE.md's 29 July baseline.

| object | now | CLAUDE.md, 29 Jul | delta |
|---|---|---|---|
| tables / views | 93 / 35 | 86 / 30 | +7 / +5 |
| `raster_asset` | 191 | 166 | **+25** |
| `figure_asset` | 297 | 278 | **+19** |
| `dim_headline_number` | **101** | 59 | **+42** |
| `report_asset` | 60 | 59 | +1 |
| `spatial_layer_asset` · `census_asset` · `dim_management_zone` · `dim_metric` | 9 · 2 · 64 · 45 | unchanged | 0 |
| `table_asset` | 5 | not recorded | — |

**The database was written during this audit** — `mtime` 2026-08-04T15:30:45, after the Gate B and Gate C
queries. **Every pin cited anywhere in this audit was therefore re-verified at Gate E against the current
file: all ten hold, none moved.** No pin has appeared for the three-arm raw gap; the only value near it
remains `t10_bala29ca_aeolian_level_deficit` = −32.1, a different object.

**CLAUDE.md's recorded DB shape is stale** — it states 86 tables / 30 views / `figure_asset` 278 /
`dim_headline_number` 59 against a live 93 / 35 / 297 / 101. `dim_metric.support` remains NULL on 36 of 45
rows, exactly as recorded.

---

## Two things that could not close, as specified

- **Regression diagnostics** — not computed anywhere; closing the flag requires running them, which is new
  analysis. **Open.**
- **Six citations** — require external sourcing. Whether the Dawson et al. (2016) attribution belongs in §6.1
  at all is a design-seat question. **Open.**

## What the audit could not reach

- **127 value and structural claims**, above.
- **21 of 25 captions** against producing code — unblocked by the manifest, not done.
- **Figure 8's extent** — unverifiable from this repository (§3.5).
- **The four unreproducible figures** — no file, no producer, no registry row.
