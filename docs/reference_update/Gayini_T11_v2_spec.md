# T11 v2 — The same country, two ways of looking at it

**Version:** v2 · 31 July 2026. Supersedes the T11 section of
`Gayini_reference_state_specs_T7_T11.md` v1. Standalone; no precedence chain.
**Depends on:** T10 Gate C, T13 (complete). Part polygons and paddock polygons both exist.
**Blocks:** nothing. Feeds the Adrian pack as item M5.

Standing rules apply. Re-read in full and echo verbatim at the gate.

---

## 1. What changed from v1, and why

v1 specified two paddock-level choropleths — floor and flood frequency — to show that water
organises cover more strongly than management does.

That claim is right and the maps would show it. But learning L-01 says a paddock is not an
ecological unit, and T13 demonstrated it: fourteen of 64 paddocks are below 75% single-community
dominance, and their parts behave differently enough that a paddock average describes no real
place. Drawing a paddock choropleth of Bala 29ca would colour one polygon with the mean of three
parts reading 67, 35 and 29.

**So T11 draws both grains side by side.** The figure then does two jobs rather than one: it
shows that water organises cover, and it shows what a paddock average costs. The second is L-01
rendered rather than asserted, and it is the more useful of the two for anyone who has to read a
paddock report.

## 2. Spine anchor

| | |
|---|---|
| **Serves** | Claim 3 of the through-line (water drives cover), and L-01 |
| **Claim under test** | None — descriptive. But if the two grains look alike, that is the finding and it should be said |
| **Why now** | Both geometries exist and are checked. The paddock polygons are the registered zone layer; the part polygons were built and verified at T13 Gate D (118 parts, 795,602 pixels enclosed, area reconciling to 3.7e-11, zero overlaps) |
| **Spine return** | Two registered figures for the Adrian pack |

## 3. Gate A — the dual-grain figure

**One figure, four panels, 2 × 2.** Rows are the variable; columns are the grain.

| | paddock grain (64) | part grain (115) |
|---|---|---|
| **vegetation floor** | mean `veg_p05_spatial` | mean `veg_p05_spatial` |
| **flood frequency** | mean `flood_frac_pct` | mean `flood_frac_pct` |

Sources: `fact_zone_veg_annual` for the paddock row, `fact_zone_community_veg_annual` joined to
`fact_zone_community_flood_annual` for the part row. `series_variant = 'mean_of_seasons'`
throughout, averaged over all 35 years, `n_pixels_valid >= 30`.

### 3.1 Requirements that carry the argument

- **Identical colour scale within each row.** The two floor panels must share one scale and the
  two flood panels another, or the comparison is meaningless. State the breaks in the caption.
- **A sequential ramp, not viridis.** Deck palette. Do not reuse the T13 state palette — these
  are continuous quantities, not classes.
- **The four conserved paddocks outlined** on all four panels, labelled once.
- **Bala 29ca and Dinan 1 labelled on the part-grain floor panel.** They are the two clearest
  demonstrations of what the paddock average hides.
- North arrow and scale bar, bottom right (the property runs SW–NE; the bottom-left corner sits
  on the Mara cluster — T13 Gate D found this the hard way).
- Out-of-scope ground in its own neutral fill with its own legend entry, **not white**. Same fix
  as T13 Gate D: white must not mean two things.

### 3.2 The number the figure exists to make visible

Design-seat computation, **a prediction to check, not a target**. For the 37 paddocks with more
than one supported part, the spread between a paddock's highest and lowest part floor:

| | |
|---|---|
| median within-paddock spread | **12.8 pp** |
| maximum | **40.2 pp** |

The five widest:

| paddock | paddock mean | parts | spread |
|---|---|---|---|
| Dinan 1 | 56.7 | Inland 69 · Aeolian 57 · Riverine 29 | 40.2 |
| Bala 29ca | 40.5 | Inland 67 · Riverine 35 · Aeolian 29 | 37.9 |
| Dinan 2 | 69.3 | Inland 77 · Riverine 44 | 32.2 |
| Dinan 3 | 50.2 | Inland 73 · Aeolian 64 · Riverine 42 | 31.2 |
| Dinan 13 | 52.9 | Inland 70 · Riverine 48 · Aeolian 45 | 24.6 |

Verify independently. If it holds, the median figure belongs in the caption — it is the single
number that says what the left column costs.

## 4. Gate B — the residual panel

A separate figure, **paddock grain only**, showing each paddock's residual from the registered
expectation line: observed floor minus (`floor_flood_intercept_64pdk` +
`floor_flood_slope_64pdk` × flood frequency). Read both constants from `dim_headline_number`;
**do not refit.**

Diverging scale centred on zero, scaled by `floor_flood_residual_sd_64pdk` (6.6208) so a reader
can see which paddocks are more than one SD from expectation. Bala 29ca (−16.80) and Dinan 10
(−15.06) labelled.

**State plainly in the caption why there is no part-grain equivalent:** the expectation line is
fitted across 64 paddocks and no part-grain fit has been registered. T13's `level_z` is a
different quantity — deviation from the community median, not from a water expectation — and the
two must not be presented as versions of the same thing.

## 5. Gate C — STOP

Report both figures, the spread verification, and the colour breaks used. Register via
`write_and_register_figure()`.

**Write to `Output/figures/`.** Do not create new top-level folders.

## 6. Captions

Plain language; these go into the Adrian pack as item M5 and will be read by someone who has not
seen the analysis. Draft, to be edited rather than used verbatim:

> **Figure 1.** The same two measurements, drawn twice. The left column shows each paddock as a
> single value; the right column breaks each paddock into its vegetation types. Top row is how
> much cover the poorest patches carry; bottom row is how often the ground floods. The two rows
> look alike, which is the point — water organises cover more strongly than any management
> boundary does. The two columns do not, which is the second point: a paddock average hides a
> median of 12.8 percentage points of difference between the parts of the same paddock, and up
> to 40. Dinan 1 reads 56.7 as a paddock; its three parts read 69, 57 and 29.

> **Figure 2.** How much cover each paddock carries against how much its water supply predicts.
> Blue is more than expected, red is less. Bala 29ca sits further below expectation than any
> paddock except Dinan 10 — which is grazed, and almost exactly as dry.

## 7. Acceptance

- [ ] Four panels, shared scale within each row, breaks stated
- [ ] Both geometries from the registered/verified sources; no re-derivation of either
- [ ] Conserved paddocks outlined on all four panels
- [ ] Out-of-scope fill distinct from white, own legend entry
- [ ] Spread figures verified independently, agreement or disagreement stated
- [ ] Residual panel uses registered intercept and slope; not refitted
- [ ] Caption states why there is no part-grain residual
- [ ] Both figures registered; written to `Output/figures/`
- [ ] No builder run, no existing object modified
