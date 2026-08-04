# FIG3 Part A — reference-state figure producers: code review

**Read-only.** 4 August 2026 · DOC-3 §0 standing conditions applied: `mode=ro`, no registry write, no
re-render, no producer edit. **Nothing changed. No preferred option proposed.**

---

## 0 · Two conditions to record before the findings

**The V11 on disk does not match the hash in the spec.**

| | |
|---|---|
| spec | `019b32126e4d28956979d92f31430f6fef329ea2a6efbb257926219d60ce7f1f` |
| **file** | **`4109e7c4467cd441a73df64764234626aead8667d18bd377a7516e66d4bc794c`** |

`docs/reports/Gayini_RS_methods_doc_V11.docx` · 10,991,979 bytes · mtime **21:53** ·
**Word lock file present, mtime 21:55.** The document is open and has been saved since the spec was
written. Part A reviews producers rather than text, and the figure inventory is unchanged — 28 media,
28 captions, 1–28 — so the review stands. **But the figure-to-producer mapping below was taken from
the file on disk, not from the file the spec hashed.**

**All 14 figures identified; 12 by exact checksum against `figure_asset`, 2 by filename** (Figures 18
and 27, resampled on embedding so no hash match).

---

## 1 · The set — producer, entry point, registered title

**Seven producers, all in `scripts/12_zone_stratum/`. Every title below is a registered string in
`figure_asset.title`, so any title change moves a registry row.**

| Fig | File drawn | Producer | Registered title | Device | DPI |
|:--:|---|---|---|---|:--:|
| 15 | `T1_A_zone_map_named.png` | `T1_gateB1_figures.R:65` | T1 A zone map named | 11 × 9 | 150 † |
| 16 | `T2_G_plot_paddock_coverage.png` | `T2_gateG_figure.R:86` | T2 G plot-to-paddock coverage | 12 × 8 | 150 † |
| 17 | `T13_D1_part_state_map_and_scatter.png` | `build_T13_gateD_figures.R:247` | T13 Gate D — paddock parts by state, pre-registered cut ±1.0… | 17 × 8.5 | **200** |
| 18 | `T13_D2_part_state_map_sensitivity.png` | `build_T13_gateD_figures.R:287` | T13 Gate D — state map at the 0.75 and 1.25 cuts… | 18 × 7.5 | **200** |
| 19 | `M5_dual_grain_floor_and_flood.png` | `build_T11_v2_dual_grain.R:194` | T11 v2 — cover floor and flood frequency at paddock and part grain | 15 × 11 | **200** |
| 20 | `M5b_paddock_residual_from_expectation.png` | `build_T11_v2_dual_grain.R:280` | T11 v2 — paddock residual from the registered cover-water expectation line | 11 × 8 | **200** |
| **21** | `T2_E_paddock_trajectories.png` | `T2_gateE_figures.R:90` | **T2 E paddock floor trajectories** | 14 × 6 | 150 † |
| **22** | `T2_E_paddock_trajectories_mean.png` | `T2_gateE_figures.R:97` | T2 E paddock mean-cover trajectories | 14 × 6 | 150 † |
| **23** | `F3_annual_gap_series.png` | `build_adrian_pack_T1_F3_F5.R:253` | F3 — annual conserved-grazed gap, all four / excluding Bala 29ca / Bala 29ca alone | 11 × 7 | **200** |
| **24** | `T2_F_gap_decomposition.png` | `T2_gateF_figure.R:75` | T2 F reference-gap decomposition | 11 × 9 | 150 † |
| 25 | `F5_cover_vs_water_64_paddocks.png` | `build_adrian_pack_T1_F3_F5.R:332` | F5 — paddock cover floor against flood frequency, 64 paddocks, registered expectation line | 11 × 7.5 | **200** |
| **26** | `T6_A_three_arm_grid.png` | `T6_gateE_figures.R:181` | **T6 A three-arm floor grid** | 13 × 9 | 150 † |
| 27 | `T6_B_three_arm_mean.png` | `T6_gateE_figures.R:191` | T6 B three-arm mean-cover grid | 13 × 9 | 150 † |
| 28 | `T1_conserved_paddock_comparison.png` | `build_adrian_pack_T1_F3_F5.R:189` | T1 — the four conserved paddocks side by side | 14 × 7 | **200** |

† **DPI is not set at the call site** and falls to the helper default `dpi = 150`
(`R/gayini_figure_register.R:29`, applied line 36). **Two titles carry the bare word "floor"** —
Figures 21 and 26 — so the C6b vocabulary change and the registry row move together.

## 2 · Shared helpers — a common change costed once

**Three producer generations, distinguished by what they source:**

| generation | sources | producers | figures |
|---|---|---|---|
| **current** | `gayini_params.R` + `gayini_figure_register.R` + `gayini_assert_rendered.R` | `build_adrian_pack_T1_F3_F5.R`, `build_T13_gateD_figures.R`, `build_T11_v2_dual_grain.R` | **17, 18, 19, 20, 23, 25, 28** |
| middle | register + assert | `T6_gateE_figures.R` | 26, 27 |
| earliest | register only | `T1_gateB1_figures.R`, `T2_gateE_figures.R`, `T2_gateF_figure.R` | 15, 21, 22, 24 |
| — | register + params | `T2_gateG_figure.R` | 16 |

**All fourteen route through one save helper**, `gayini_write_and_register_figure()`. A change to
device default, DPI default or registration behaviour is **one edit for the whole set**. A change to
title, palette or annotation is **per producer** — seven of them, or fewer by the pairings below.

**Producers drawing more than one figure in scope** — one edit covers both:
`T2_gateE_figures.R` (21, 22) · `T6_gateE_figures.R` (26, 27) · `build_T13_gateD_figures.R` (17, 18) ·
`build_T11_v2_dual_grain.R` (19, 20) · **`build_adrian_pack_T1_F3_F5.R` (23, 25, 28)**.

---

## 3 · Figure 23 — the generation ahead, and what it would take to bring 21, 22, 26 across

**Producer: `build_adrian_pack_T1_F3_F5.R`, which also draws Figures 25 and 28.** Those three are one
generation and one edit.

**What makes it a generation ahead, as coded:**

1. **It sources `gayini_params.R`** — constants come from the parameter module rather than literals.
2. **It sources `gayini_assert_rendered.R`** — the QA-2a guard that asserts drawn strings carry their
   source values, so a label cannot silently drift from the number it names.
3. **It writes explanatory prose into the figure.** Line 171 renders
   *"Bala 29ca is the driest paddock on the property and has the second-lowest cover of 64, while …"*
   — the plain-language explanation the spec observes in the caption is **in-figure text**, not a
   document caption.
4. **`dpi = 200` is set at the call site** rather than inherited at 150.
5. **Its registered titles are already plain-language and already say "conserved"** — *"the four
   conserved paddocks side by side"*, *"annual conserved-grazed gap, all four / excluding Bala 29ca /
   Bala 29ca alone"*.

**To bring 21, 22 and 26 to the same pattern:**

| element | 21 / 22 (`T2_gateE`) | 26 (`T6_gateE`) | cost class |
|---|---|---|---|
| plain-language registered title, "conserved" | title is `T2 E paddock floor trajectories` — bare "floor", no vocabulary | `T6 A three-arm floor grid` — same | **label only**, but **moves a registry row** |
| in-figure explanatory text | absent | absent | **layout within the same computation** — a `geom_text`/`labs(subtitle=)` addition using values already computed |
| `gayini_params.R` | not sourced | not sourced | label only — no literal constants found in either that would change a number |
| `gayini_assert_rendered.R` | **not sourced** | **sourced already** (line 13) | 21/22: adding it is a new guard over existing values, no recomputation |
| `dpi = 200` at call site | inherited 150 | inherited 150 | label only |

**None of it requires recomputation.** The quantities Figure 26 would annotate are already computed
and already asserted (`T6_gateE_figures.R:128-131`). The quantities Figure 21 would annotate — line
shares per paddock-community — are **not** currently computed in `T2_gateE_figures.R` and would be a
new derivation from `census_by_zone_stratum`; that one item is category three.

---

## 4 · Figure 24 — windows as coded, and the annual equivalent

**`scripts/12_zone_stratum/T2_gateF_figure.R`.** Windows are hard-coded in the producer and stored in
the fact table:

```
line 10   # Change = late (>=2013) minus early (<=1997), pp. Reference sits BELOW grazed (gap<0).
line 39   title = "A. Gap-change decomposition: which side moved (pp, 1988-97 -> 2013-22)"
line 58   "Change = late (WY>=2013) minus early (WY<=1997)."
```

`fact_three_arm_gap_decomposition.window` carries exactly three values: **`all`, `early_8897`,
`late_1322`**. So the early window is **WY1988–1997 inclusive**, the late window **WY2013–2022
inclusive**, and **the fifteen water years 1998–2012 contribute to neither panel.**

**Does an annual-series equivalent exist, and can it be produced without recomputation?**

**It exists, and it is already drawn — as Figure 23.** `F3_annual_gap_series.png` is the same
quantity, per water year, from `build_adrian_pack_T1_F3_F5.R:253`, and it carries three series
(all four / excluding Bala 29ca / Bala 29ca alone). The underlying annual data is
`fact_three_arm_stratum_veg_annual`, which holds every water year at arm × community grain.

**So no recomputation is required for an annual equivalent of Figure 24's content — the annual
series is the previous page.** What Figure 24 adds beyond it is the *which-side-moved* split
(conserved side vs grazed side) and the flood / non-flood split, and those two decompositions have
no annual equivalent currently drawn.

*(That the annual equivalent is the previous page is the mechanical half of Part B finding 1. The
ruling on F4 is not mine to make and nothing here proposes one.)*

---

## 5 · Figure 26 legibility — the fix is a narrower canvas, not a wider one

**The in-panel labels are `size = 2.5`** (`T6_gateE_figures.R:155`), on a **13 in** device, in a theme
at `base_size = 10`.

ggplot text `size` is in millimetres: **2.5 mm ≈ 7.1 pt** at device scale. The landscape section's
usable text box is ~**10.30 in**, so a 13 in figure is scaled by **10.30 / 13 = 0.792** on placement:

**Effective placed size ≈ 5.6 pt.** That is below the ~6–7 pt floor for reliable print legibility,
which is consistent with the observation that the nine values are readable only in the prose.

**The relationship is counterintuitive and worth stating plainly: the figure is scaled *down* on
placement, so a *narrower* authored canvas yields *larger* placed text.**

Two routes, both **label-and-layout only, no recomputation**:

| route | change | placed size |
|---|---|---|
| **narrow the device** | 13 in → **≈ 8.1 in** wide, label unchanged at 2.5 | ≈ 9 pt |
| **enlarge the label** | keep 13 in, raise label 2.5 → **≈ 4.0** | ≈ 9 pt |

For a 10 pt target: device ≈ 7.3 in, or label ≈ 4.5. **Narrowing the device also compresses the
3 × 3 facet grid horizontally**, which the second route does not — the two are not equivalent beyond
the text.

*(The deck cut at line 233 uses `size = 2.9` on an 11 in device — ≈ 8.2 pt at device, ≈ 7.7 pt placed.
That variant is already close to legible and is not one of Figures 26/27.)*

---

## 6 · Bala 29ca — where it is drawn without visual distinction

**Figures in scope where Bala 29ca is drawn as one of four conserved paddocks in the same weight:**

| Fig | How it is drawn | Distinguished? | Mechanism available |
|:--:|---|---|---|
| **21** | `geom_line(aes(colour = paddock), linewidth = 0.9)` — four conserved lines, identical weight, discrete colour scale | **No** | **Yes, cheap.** `paddock` is already an aesthetic mapping; adding `linewidth`/`alpha` mapped to the same variable with a manual scale is a scale addition, no recomputation |
| **22** | same code path, `yv = "veg_mean"` | **No** | same |
| 19, 20 | `build_T11_v2_dual_grain.R:114` choropleth; `:126` labels **Bala 29ca and Dinan 1** by name; `:22` `REF <- c(...)` outlines all four conserved alike (`:114` `refpoly … linetype = "22"`) | **Partly** — named in a label, not weighted | Yes — the `refpoly` layer already separates conserved from grazed; a second layer for 29ca is a filter and a linewidth |
| 17, 18 | `build_T13_gateD_figures.R:25` `NOT_ASSERTED <- list(zone = "Bala 29ca", comm_prefix = "Inland")` — 29ca **is** singled out, as a suppression of an assertion rather than a visual emphasis | **No, visually** | Yes — the zone is already isolated in a named constant |
| 15 | no 29ca reference in the producer | **No** | Colour is by treatment; a per-zone override would be new |
| 24 | no 29ca reference in the producer | **No** | Draws arms, not paddocks — see below |

**Two figures where the question does not apply as posed:**

- **Figure 26** draws `aes(colour = arm_lab)` — **one aggregated line per arm per community, not four
  paddock lines.** Bala 29ca is not drawn separately; it is *inside* the conserved arm. The Aeolian
  conserved arm **is** Bala 29ca after the support rule, and the producer already says so at line 134:
  `"\n(n=1: Bala 29ca)"`. Nothing to distinguish; the label already names it.
- **Figures 23, 25, 28** — `build_adrian_pack_T1_F3_F5.R` **already separates it**: Figure 23 draws
  Bala 29ca as its own series against the excluding-29ca series, and the producer carries seventeen
  references to it including in-figure explanatory text.

**Cost, if one convention is applied across the set:** Figures 21 and 22 are one edit in one producer
and are pure scale additions. Figures 17–20 are a second edit in two producers, each with the zone
already isolated in code. Figure 15 is the only one with no existing hook. **None requires
recomputation.**

---

## 7 · What the code computes and discards

Checked per producer for quantities computed and not drawn:

- **`T6_gateE_figures.R`** computes **both** the raw gap and the adjusted deficit for **all nine arm ×
  community cells** (lines 116–125), draws all nine as panel labels, and asserts both against
  `dim_headline_number` before rendering (lines 68–79, 128–131). **Nothing discarded.** It also
  computes `n_units` from the `regime_band = 'ALL'` row (line 39–40) — the geometry-basis count behind
  **I-52**.
- **`T2_gateE_figures.R`** computes the grazed IQR band and median per community-year and the four
  conserved series. **It does not compute line shares** — Figure 21's 1.9% Riverine fragment is
  stated in the document prose and has no in-figure source. That is a **design** gap, not a device-size
  gap: the number does not exist in the producer.
- **`T2_gateF_figure.R`** reads `window IN ('all','early_8897','late_1322')` and draws two panels —
  which-side-moved and flood/non-flood. All three window values are used; nothing discarded.
- **`build_adrian_pack_T1_F3_F5.R`** reads the registered expectation-line constants and
  `stopifnot()`s them against literals at line 266 — so a legitimate re-pin **stops the render**
  rather than flowing through (recorded at DOC-1).

**No figure was found drawing from a source other than the one its caption declares.**

---

## 8 · Whether each figure carries its own result

The spec's §1 claims in-figure annotation exists *"so that a figure remains self-explanatory if
reproduced outside this document."*

| Fig | Carries its result? | Which problem |
|:--:|---|---|
| 26 | **No** — nine values rendered at ≈5.6 pt placed | **Device size.** The values are on the figure; they cannot be read. §5 above |
| 21 | **No** — line shares are not on the figure at all | **Design.** The quantity is not computed in the producer |
| 22 | Partly — the collapse is visible; the −4.1 / −2.3 pair is prose-only | Design — same producer, same gap |
| 23, 25, 28 | **Yes** — plain titles and in-figure explanatory text | — |
| 24 | Partly — values are drawn as bar labels at 11 × 9, ≈0.94 scale | Adequate |
| 17–20 | Yes — authored at 200 dpi and 15–18 in wide | — |

**The split is clean: Figure 26 is a device-size problem with a two-route fix; Figures 21 and 22 are a
design problem, because the numbers the prose supplies are not computed by the producer.**

---

## 9 · Cost classes

**Category 1 — label and vocabulary only.** Registered-title changes on Figures 21, 22, 26, 27
(each moves a `figure_asset` row) · `dpi` at call site · Figure 26's label size · the "reference" →
"conserved" strings in `T6_gateE_figures.R` **lines 85, 99 and 236 together**, per Ruling Z.

**Category 2 — layout within the same computation.** Figure 26's device width · the Bala 29ca visual
convention on Figures 21, 22 and 17–20 · in-figure explanatory text on 21, 22, 26 using values already
computed · adding `gayini_assert_rendered.R` to `T2_gateE_figures.R`.

**Category 3 — requires recomputation. Out of scope before 10 August, and saying so is the answer.**
Figure 21's per-line area shares · any annual-series decomposition of Figure 24's which-side-moved and
flood/non-flood splits · Figure 15 per-zone emphasis, which has no existing hook.

**One cross-cutting constraint:** every one of the fourteen routes through
`gayini_write_and_register_figure()`, so any re-render **re-registers**, changing 14 checksums —
and, per **I-50**, the current renders already predate the last commit to their producers, so a
re-render of any of them starts from a base that does not reproduce.

---

## What this report does not do

No preferred option is proposed, per the spec. Part B's findings 1–7 are design-seat items and no
ruling is anticipated here — including on Figure 24, where §4 reports only the mechanical position:
the windows as coded, and that an annual equivalent already exists as Figure 23.
