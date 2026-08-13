# Pack captions — the twelve remaining, and the v1.2 re-assembly

**Design seat · 5 August 2026.** Closes QA-2b.
**F1, F2, F3 and F6 were written yesterday** (`Gayini_reference_state_figure_text_FINAL_20260804.md`).
**F4 is cut** — see §3. **T3 is a written page, not a caption.**

Every caption states one claim a non-specialist can follow, names its support, and carries no number
that is not registered or declared.

---

## 1 · The twelve

### T1 · `T1_conserved_paddock_comparison.csv` — the four conserved paddocks side by side

> **The four paddocks with grazing excluded, compared on every axis we can measure.**
>
> They are not one condition. Ranked by how often they flood they sit **3rd, 6th, 31st and 61st of
> 64** — Bala 26ca and Bala 28ca in the wettest tenth of the property, Bala 29ca in the driest 5%.
> They also differ in size, in which kinds of country they hold, and in how many monitoring sites
> they carry.
>
> *Read this before any comparison of conserved against grazed ground. A reference state is only
> useful if it describes one thing, and this one does not.*

### T1_render · `T1_conserved_paddock_comparison.png` — T1 as a picture

> **The same four-paddock comparison, drawn.**
>
> Same content as T1, for putting on a slide. Where the two differ, T1 is the authority.

### T2 · `T13_gateC_classification.csv` — every part of the property, to look up

> **All 115 paddock-parts with sufficient record, each classified against what its own kind of
> country does at its own level of flooding.**
>
> A part is one paddock's portion of one vegetation community. **8 are recovering, 16 declining, 14
> persistently poor and 77 unremarkable.** Three of the 118 parts fall below the support rule and
> are absent — Bala 15's Riverine portion, Bala 28ca's Aeolian portion, and Mara 3's Aeolian
> portion.
>
> *This is the lookup table behind the maps. The classification is definition-sensitive: see M4b.*

### M1 · `T1_A_zone_map_named.png` — where the paddocks are

> **All 64 management zones, named, coloured by grazing treatment.**
>
> Sixty are under 14-day rotational grazing and four have grazing excluded. **All four conserved
> paddocks are in the Bala block**, so "not grazed" and "in Bala" describe the same ground and no
> analysis here can separate them.
>
> *The standard-grazing land carries no mapped zone and does not appear on this map at all.*

### M2 · `T2_G_plot_paddock_coverage.png` — where the monitoring sites are

> **The 66 monitoring sites against the management zones.**
>
> **Fifteen standard-grazing sites fall outside every mapped zone** — not one is inside a paddock
> boundary. That is why the third grazing regime has never previously been reported at paddock
> scale, and why the site and paddock reports exclude it.
>
> *The exclusion is stated rather than accidental, but it is still an exclusion.*

### M3 · `T2_B2_duration_map.png` — which country stays green longest

> **The share of years each place held cover above the working threshold.**
>
> Longest-held cover follows the channels and depressions rather than the paddock boundaries.
>
> *No headline area figure should be quoted from this map. Persistent cover does not fall into
> classes — sweeping the threshold produces a smooth decline with no natural break, and a five-point
> move either side of the working cut changes the mapped area by a factor of three.*

### M4 · `T13_D1_part_state_map_and_scatter.png` — which parts are coming back, which are going backwards

> **The 115 parts mapped by state, with the scatter they were classified from.**
>
> **Decline clusters in the east; recovery and persistently poor country in the south-west.** The
> pattern is geographic and it does not follow management: conserved and grazed parts appear in
> every state.
>
> *Why geography organises this and management does not is not established here.*

### F7 · same file — Bala 29ca, part by part

> **Bala 29ca's three parts, in the same classification.**
>
> The paddock is roughly a third Inland Floodplain, a third Riverine and a third Aeolian, and **its
> parts behave in opposite directions** — the Aeolian portion sits far below its community's typical
> level, the Inland portion only a little below.
>
> *Any whole-paddock number for Bala 29ca is an average across three communities that disagree.
> Decompose before interpreting.*

### M4b · `T13_D2_part_state_map_sensitivity.png` — how the classification moves when the cut moves

> **The same classification at looser and tighter thresholds.**
>
> The count of recovering parts runs from **3 to 15** across the range tested, and **8 at the
> registered cut**. The sets are strictly nested — parts enter and leave as the cut moves, but never
> swap places.
>
> *Treat the eight as one defensible answer rather than the only one. Five of the eight survive
> removing the two wettest years.*

### M5 · `M5_dual_grain_floor_and_flood.png` — cover and water, at two grains

> **The same relationship drawn for whole paddocks and for paddock-parts.**
>
> Paddock averages conceal parts moving in opposite directions. **A paddock is a stock-and-water
> unit, not an ecological one**, and where the two grains disagree the part is the more honest
> answer.
>
> *The two panels are not numerically comparable and should never be quoted against one another.*

### M5b · `M5b_paddock_residual_from_expectation.png` — which paddocks beat or miss their water

> **Each paddock's distance from what its flooding predicts, mapped.**
>
> Positive means more cover in the poorest patches than its water would predict. The largest
> shortfalls are **Bala 15 at −17.6 percentage points, Bala 29ca at −16.8, and Dinan 10 and Dinan 13
> at −15.1 and −15.0** — effectively tied, and both grazed.
>
> *A shortfall is a question, not a verdict. No land-use history exists for any paddock.*

### F5 · `F5_cover_vs_water_64_paddocks.png` — cover against water across all 64 paddocks

> **Cover in the poorest patches against flood frequency, one point per paddock.**
>
> **The relationship accounts for about half the variation between paddocks** (r = 0.71). This line
> is the expectation every residual in M5b is measured against, and it is why comparing paddocks
> requires adjusting for water first.
>
> *Fitted across all 64 paddocks including the four conserved ones. It is a description of this
> property, not a general law.*

---

## 2 · Where a number appears, it is registered

| Caption | Numbers | Status |
|---|---|---|
| T1 | 3 / 6 / 31 / 61 of 64 | registered, four `number_id`s |
| T2 | 8 / 16 / 14 / 77 of 115; 118; 3 unsupported | registered; the three named at `071fd79` |
| M1 | 64 / 60 / 4 | declared |
| M2 | 66 sites; 15 standard-grazing outside zones | declared |
| M3 | none quoted — deliberately | — |
| M4b | 3–15; 8 registered; 5 of 8 on wet-year removal | registered ladder, `071fd79` |
| M5b | −17.6 / −16.8 / −15.1 / −15.0 | three registered; **Dinan 13 has no `number_id`** |
| F5 | r = 0.71 | registered |

**One flag: Dinan 13's −15.0 carries no registry identifier.** It is reproduced in DOC-3 and named
in V11.1 under Ruling Y. Either register it during the assembly pass or drop it from the M5b caption
and keep "effectively tied with a fourth grazed paddock".

---

## 3 · The v1.2 re-assembly — CC

Cannot run until the captions above are in `PACK1_item_list.csv`.

1. **Drop F4** (`T2_F_gap_decomposition.png`). **17 items → 16.** Period-boundary windows are barred
   elsewhere in the project, and it decomposes a change F3 shows is not occurring. It stays in the
   methods document, demoted.
2. **Re-copy from registered sources**, which have moved since assembly: `T2_E_paddock_trajectories.png`,
   `T2_E_paddock_trajectories_mean.png`, `T6_A_three_arm_grid.png`. Registry state `ab39c4a`.
3. **Regenerate** `PACK1_item_list.csv`, `00_START_HERE.md` and the workbook Contents sheet from the
   item list, so the three cannot disagree.
4. **Re-run** `PACK1_final_number_check` over all captions, new and existing.
5. **Re-verify** every checksum source-to-copy.
6. **Seal as v1.2.** Quarantine `Gayini_Adrian_pack_20260803.zip` and
   `Gayini_Adrian_pack_v1.1_20260804.zip` — three zips on disk is discrepancy class #1.
7. Report the item count, the number-check result, and the new zip's SHA-256.

**Reading order after F4 leaves:** T3 → T1 → T1_render → T2 → M1 → F5 → F3 → M5b → M4 → F7 → M4b →
M5 → F1 → F2 → F6 → M2 → M3.

---

## 4 · Also for the covering note

The methods document is now **V11.1**, `f455c46d9580…`, 51 pp. The reference-state figures are
rebuilt and the reference-state text is new. **The unit reports give flood frequency as a
within-paddock range** — the wettest and driest hectares — rather than a paddock mean, which is a
third framing alongside the census and polygon footprints declared in §4.2b. Adrian will see both;
say so before he asks.
