**To:** report stream
**From:** reference-state stream
**Date:** 31 July 2026
**Re:** page 4's expectation line — a question before the batch, and two constants

---

**TWO REGISTERED VALUES GAINED PRECISION, landed at 7162d2d:**

```
  floor_flood_intercept_64pdk   52.6529  ->  52.652934
  floor_flood_slope_64pdk        0.548   ->   0.547838
```

Precision only. Both round back exactly, no client-facing number moves, and the
printed line still reads "52.7 + 0.548 x flood %".

## THE QUESTION, WHICH MATTERS MORE THAN THE CONSTANTS:

**Where does page 4's expectation line come from right now?**

We scanned every tracked script in our repo and the template code you sent on
29 July. Neither `make_report_figures.py` nor `build_reports.js` touches
`dim_headline_number` at all — they read `fact_zone_veg_annual`, `plot_paddock` and
`v_plot_year_analysis_spine`, but nothing from the registry.

And `README_report_template.md` line 103 still says:

> "The comparison-with-expectation numbers are unregistered. The fit (slope 0.548,
>  intercept 52.65, r 0.710 pooled)"

**THAT LINE IS NOW STALE — and has been since 28 July.** The slope and r were
registered at T8 Gate A on 28 July and the intercept at REG-1 Gate B on 29 July;
T10 Gate D only added spread to rows that already existed. Both constants were then
re-registered at higher precision today. Note the timing: the template code you sent
on 29 July already carried a README claiming these numbers were unregistered, a day
after the first two were pinned.

If page 4 was built against that README, it may be drawing the line from its own fit —
which would put an unregistered regression into 21 client documents.

We cannot tell from here. Your live builder is not in our repo and the zip is dated
29 July, so we can only report what we can see. Please confirm which it is.

## WHAT WE'D ASK, WHICHEVER THE ANSWER:

1. **Draw the LINE from `dim_headline_number`** — read `floor_flood_intercept_64pdk` and
   `floor_flood_slope_64pdk`, do not refit and do not hardcode. If page 4 is not built
   yet this is the better outcome: the inconsistency gets designed out rather than
   corrected afterwards.

2. **Take the RESIDUAL from `v_zone_floor_flood_residual`, not recomputed.** This matters
   as much as the line. We ruled the same for our own residual map (M5b) and the
   proof is in the checksums: when the constants were re-registered, M5b did not
   change because it reads the view, while the figure that draws the line from the
   constants did. Recomputing the residual is how the two drift apart again for a
   different reason.

3. **Assert the constants you read against expected values, and fail the build on
   mismatch.** Both our figure scripts did exactly this and both halted on the repin —
   that is the only reason we could prove the propagation was complete. A silent read
   would have drawn a stale line with nothing to catch it.
   **Assert tighter than the precision you depend on.** Ours asserted at `1e-4` and
   halted because the change exceeded it; a `1e-2` guard would have slept through this
   entire correction.

4. **Correct README line 103.** It is your file so we have not touched it, but leaving it
   is how someone re-derives an unregistered fit six months from now.

## FOR AWARENESS, not an action:

The residuals themselves have not moved. Bala 29ca at **−16.80** and Dinan 10 at
**−15.06** are the registered values and are unchanged. Only the constants used to draw
the line gained precision.

---

*Provenance for the dates above: `dim_headline_number.decided_by` — `floor_flood_slope_64pdk`
and `floor_flood_r_64pdk` "design-seat T8_gateA_pin_decisions.md v1 (Hugh); built by CC
2026-07-28"; `floor_flood_intercept_64pdk` "REG-1 Gate B (Gayini_REG1_REG2_spec.md); CC
2026-07-29". T10 Gate D's own change report states "Pinned values unchanged (0.548 / 0.710)".
Full account of the precision correction: `docs/change_reports/floor_flood_precision_correction.md`.*
