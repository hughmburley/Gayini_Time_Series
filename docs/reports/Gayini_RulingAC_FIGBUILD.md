# Ruling AC · FIG-BUILD — rebuild the reference-state figures

**Design seat · 4 August 2026 · AUTHORISED BUILD.** This supersedes FIG3 Part A, which asked for a
review. **No review. Change the code, re-render, re-register.**

> **Ruling AC.** `scripts/12_zone_stratum/T2_gateE_figures.R` and `T6_gateE_figures.R` are
> authorised for modification. Figures 21, 22 and 26 are re-rendered and re-registered under the
> specification below. Ruling Z's three-line precondition applies. One STOP, at scratch render,
> before the registry write.

**Target generation:** Figure 23. It already does everything below. Where this spec is ambiguous,
copy Figure 23.

---

## 1 · What changes, all three figures

### 1.1 Vocabulary — Ruling Z applies

| Now | Becomes |
|---|---|
| `not grazed (reference)` | `conserved` |
| `reference vs grazed` | *(drop from titles entirely)* |
| `unzoned mapped (inferred standard)` | `unzoned — standard grazing (inferred)` |
| `unzoned, plot-confirmed (8/15)` | `unzoned — plot-confirmed (8 of 15)` |
| `veg_p05_spatial (%)` | `Cover in the poorest patches (%)` |
| `veg_mean (%)` | `Average cover (%)` |

**In `T6_gateE_figures.R` lines 85, 99 and 236 change together.** Line 99 is the colour map and is
keyed on the label literal; editing 85 alone silently drops the arm's colour.

### 1.2 Titles — a question, not a code

| Fig | New title |
|:--:|---|
| 21 | **Does conserved country hold more cover in its poorest patches than grazed country?** |
| 22 | **The same comparison, on average cover instead of the poorest patches** |
| 26 | **Does grazing intensity show up in the cover floor?** |

One line of subtitle, no more. Everything currently in the four-line subtitle and the code footnote
moves to the document caption, which V11 already carries. **Delete the footnote block.**

`T2_gateE_figures.R:85` and `T6_gateE_figures.R:176` are **registered titles** — the registry rows
move with them. Re-register; do not edit in place.

### 1.3 Bala 29ca is drawn as the outlier it is

**This is the single most important change in this spec.** The section argues that one of the four
conserved paddocks carries the entire result; the figures currently argue the opposite by drawing
all four alike.

| series | colour | weight |
|---|---|---|
| Bala 26ca, 27ca, 28ca | one muted grey-green, `#7C837E`, **all three the same colour** | 0.5 |
| **Bala 29ca** | deep petrol-teal, `#0F3947` | **1.1** |
| grazed comparator band | unchanged grey | unchanged |

**Yes, the three become indistinguishable from one another. That is the finding.** Three paddocks
behave as a group and one does not. Identify them with **direct labels at the right-hand end of each
line**, and delete the legend.

Apply the same convention to Figure 26's conserved arm where Bala 29ca is the sole member: annotate
the Aeolian panel `conserved arm = Bala 29ca alone`.

---

## 2 · Figures 21 and 22 — restack

- `facet_wrap(~comm, nrow = 1)` → **`facet_wrap(~comm, ncol = 1)`**. One community per row.
- Device **14 × 6 in → 8 × 10.5 in**, dpi 150 set **at the call site**, not inherited.
- Shared x-axis drawn once beneath the bottom panel. Common y-axis retained; add `common vertical
  scale` to the subtitle.
- Community name inside each panel, top left. Drop the facet strip.
- Flood-year shading in every panel, unchanged.

**Per-panel annotation, bottom left of each panel:**

- `n = <count> grazed parts` — the number of grazed paddock-community parts in that community's band.
- For each conserved line, its share of its paddock, printed at the direct label:
  `Bala 26ca (1.9% of paddock)`, `Bala 28ca (16.8%)`, `Bala 29ca (34.6% / 33.1% / 32.3%)` by panel.

**The share matters.** Bala 26ca's Riverine line is 1.9% of that paddock and currently draws at the
same weight as a third of another. A reader cannot see that without being told.

**I will add the portrait section to the document generator** so the restacked figures land at
~6.7 × 8.8 in rather than being scaled into the landscape box. That is my half and it happens when
yours lands.

---

## 3 · Figure 26 — do not restack, make it readable

A 3 × 3 facet grid in portrait gives ~2.2 in panels, worse than now. Keep `facet_grid(arm_lab ~
comm)`.

- Device **13 × 9 → 13.5 × 9**, and **widen the placed size to the full landscape text box (10.3
  in)**.
- **The nine adjusted values are the result of this figure and must be its most legible element.**
  They are currently readable only in the document's prose, which makes §1's claim that a figure
  stays self-explanatory outside this document false for Figure 26. Increase the annotation size
  until the adjusted value is readable at placed size; the raw gap and `n` may stay smaller.
- Keep the two-quantity explanation but move it to one subtitle line: *the visible gap is raw; the
  labelled value is adjusted for water within wetness bands.*

---

## 4 · Rounding

Values printed on any figure are rounded **once, from source**, never from a pinned registry value —
§4.6(b) of V11. Two of these numbers sit on boundaries: the inferred Riverine adjusted difference is
**+7.9** from source 7.947, and the Aeolian conserved mean-cover raw gap is **−4.1** from −4.050.
**Do not print +8.0 or −4.0.**

---

## 5 · Gate

**One STOP.** Render all three to a scratch path, report back with the three files, and wait. No
registry write, no pack copy, no document embed until the design seat has seen them.

On approval: re-register via `write_and_register_figure()`, additive only, and report the new
`figure_asset` rows and checksums.

---

## 6 · Out of scope

Figures 15–20, 23, 24, 25, 27 and 28 are **not** touched by this ruling. Figure 23 is already the
target generation. **Figure 24 is under a separate decision** — it draws early and late window means,
which is a period-boundary statistic the project has ruled out elsewhere, and it decomposes a change
Figure 23 shows is not occurring. That ruling is coming; do not pre-empt it.

---

## 7 · What good looks like

Set the new Figure 21 beside the current Figure 23. If a reader cannot tell they came from the same
project, the rebuild is not finished.
