# REPORTS — R-16 · the gap figure states its variable, not a pattern

**Session:** report batch, third concurrent seat · **Date:** 5 August 2026
**Builder:** v1.8 → **v1.9** · **DB read-only.** No write attempted.

```
lint_builder.py        0 error · 0 warn                       exit 0
verify_batch.py        32 match · 0 changed · 0 missing        exit 0
check_scope_claims.py  clean (8 checks)                        exit 0
check_page_fill.py     83 pages · 0 above 92% · 12 below 70%   exit 0
tests/                 16 assertions · 4 files · 0 fail        exit 0
```

Applies to the shipped 32. R-9, R-11, R-13, R-14 remain held on `hold/r13-r9-r11`.

---

## 1. Every figure in the ruling re-derived, and confirmed

| | ruling | measured |
|---|---|---|
| widening (slope < −0.05) | 26 | **26** |
| flat (\|slope\| ≤ 0.05) | 19 | **19** |
| closing (slope > 0.05) | 19 | **19** |
| title wrong | 45 of 64 | **45 of 64** |
| \|r\| < 0.3 | 41 of 64 | **41 of 64** |
| Bala 26ca | flat, r = −0.01 | slope −0.0027, r **−0.006** |
| Bala 27ca | widening, slope −0.176 | slope **−0.1758**, r −0.350 |

In the shipped set, **Bala 26ca falls below the r cut as well as being flat** — so it loses the
trend line entirely, not just the title. Bala 27ca sits at r = −0.350, above the cut, so its line
stays and the caption says it widened.

## 2. (a) Title states the variable

`"Closing the gap, year by year"` → **`"Cover compared with the rest of the property, year by
year"`**. A title that names the variable cannot be wrong for any paddock.

Set at 9.0 pt rather than the 10.5 the other figures use: at 54 characters on a 5.4 in canvas the
larger size clipped its own last word — caught on the first render, not shipped.

## 3. (b) The pattern moved to the caption, derived, with slope and correlation

Following the standing rule this figure was breaking — *give the slope and the correlation, and
stop there*. No p-value, no verdict.

```
Bala 15    Across the record the difference narrowed (+0.779 points a year, correlation 0.72).
Bala 27ca  Across the record the difference widened (−0.176 points a year, correlation −0.35).
Bala 29ca  Across the record the difference narrowed (+0.919 points a year, correlation 0.85,
           read from the results registry).
Bala 26ca  Year-to-year movement is larger than any trend running through it (−0.003 points a
           year, correlation −0.01), so no trend line is drawn: on this measure the paddock
           neither gained on the rest of the property nor fell behind it.
```

Bala 29ca alone says *read from the results registry*, because its slope is the registered
`t10_gap_annual_slope_C_29ca` and that is what the figure draws.

**The direction and the draw/omit decision are settled once, in `report_data.py`, and both the
figure and the caption read them.** Computing them in each place would let a caption describe a
trend the figure did not draw — R-8's failure in a new costume. The two cuts (0.05, 0.30) have
one home; neither consumer sees them.

## 4. (c) No trend line where it means nothing

Below r = 0.30 the dashed line and **both endpoint labels** are omitted. The labels mattered as
much as the line: they were read off the *fitted line*, not off the series, so they presented a
fitted value as a measurement. Bala 26ca now shows a series that visibly does not move with
nothing drawn through it, which is what you asked for.

## 5. The label collision — fixed by position, not by nudge

Two faults, both structural:

- the endpoint labels used a fixed offset and are now placed **outward from the line** and
  clamped inside the axes;
- *"level with the rest of the property"* sat at a fixed right-hand offset. It labels the **zero
  line**, so it now sits against it, at whichever end the series runs furthest from zero — the
  end where the space beside the zero line is free.

My first attempt put it at the foot of the axes, which on an all-negative series captioned a
line at the opposite edge of the plot. Caught on render.

## 6. `gap_slope_derived` is back — with a reader

It was removed at v1.3 *because nothing read it*. R-16 gives it one, so it returns with
`gap_r_derived` alongside. That is the condition on which it was withdrawn being met, not a
reversal. Both are rounded to 6 dp on emission: the v1.3 problem was `np.polyfit`'s last-bit
ordering differing between machines at the 15th significant figure, and rounding far beyond the
3 dp the caption prints makes the record stable without touching what a reader sees.

Also fixed while there: `trend +{sl:.3f}` hardcoded the plus sign. Only Bala 29ca carries a
registered slope and it is positive, so it never bit — but a negative re-pin would have rendered
`+−0.919`.

## 7. The check, and the fixture that exposed a fault in it

`check_scope_claims.py` gains check H: the caption's direction must match the unit record, a
caption must never describe a trend line the figure did not draw, and both the slope and the
correlation must be present.

**The fixture found a hole in my own check first.** I had guarded the no-line branch with
`'narrowed' in capt and 'neither' not in capt` — and the no-line caption contains *"neither
gained … nor fell behind"* in an unrelated clause, so the guard suppressed the very finding the
check exists for and the injected defect passed. Matching a fragment that collides with text
which is not the claim is **I-47's shape**. Now matched on the assertion itself — *"the
difference narrowed"* / *"the difference widened"* — which appears only in the line-drawn branch.

```
r16_gap_pattern  exit 1  OK   ERROR [R-16] Bala 26ca
                 caption asserts "the difference narrowed" where no trend line is drawn
```

Eight scope cases now, all correct, `none` still passing.

## 8. Diff and re-fingerprint

7 changed — every paddock report, since every one carries a gap caption. 25 site reports
untouched. Verified against the same control as before: **Bala 27ca shows 9 blocks against the
delivered v1.0, of which 7 are the pre-manifest changes it showed as the control and 2 are R-16**
— the caption sentence, and *"the dashed line is the fitted trend"* → *"that trend"*. My first
pass counted one block per document and missed the second because it did not match the substring
test; corrected before re-fingerprinting. Nothing unaccounted.

Re-fingerprinted **once**, v1.9: `7 moved · 0 new · inventory 5 C1 · 25 D2`, then
`32 match · 0 changed · 0 missing`.

## 9. Third instance of the class

A generated assertion that does not consult the data beside it — R-2's bars coloured against
their own label, Dinan 10's pronoun, and now this title. All three were caught by comparing the
generated text against the record it describes, and all three now have a check that does that
comparison. Worth adding to `RB-I1` alongside the reachability note and the pattern-that-falls-
silent, which is the same family from the checking side.
