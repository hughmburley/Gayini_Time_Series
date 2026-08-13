# Task ladder — the updated regression, Thursday 6 to Sunday 9 August

**Deadline context.** Adrian's meeting is Friday 7 August; this ladder runs alongside and after it.
The project deadline is Monday 10 August. **Target for the regression package: Saturday 8 August,
with Sunday as the buffer.** Reasoning in §5.

**Two CC seats are live.** The methods/analysis seat holds SCHEM-1, PARTREG and the DATA package;
the report seat holds the batch and R-16. **They must not both write to `report_figs.py`.** Confirm
the report seat's worktree before either writes again.

---

## The critical path, stated once

**PARTREG Stage 1 is the only long pole.** Everything else is either already built, small, or
downstream of it.

```
SCHEM-1 registration ──┐
SCHEM-2 production  ───┤
Derivation note     ───┼──> all short, none blocks
Attribute table     ───┘

PARTREG Stage 1 ──> GATE ──> Stage 2 (per-year) ──> Stage 3 (periods)
   the long pole      ^
                      |
              the real decision point
```

---

## Thursday 6 — tonight

**CC · methods seat**

| | task | why now |
|---|---|---|
| **T1** | **Issue PARTREG Stage 1.** Amended: it switches to the *parallel* part branch, not down a chain — `fact_zone_community_veg_annual` already holds 8,142 rows over 118 parts. Much of the extraction exists. | The long pole starts first |
| T2 | SCHEM-1 registrar — Python, `INSERT OR REPLACE`, on `register_taskM_gateC_assets.py`'s pattern | Ruling AO. Unblocks the schematic |
| T3 | Register SCHEM-1 with the title and caption from Ruling AP | Ruling AP |

**Design seat · tonight**

| | task |
|---|---|
| T4 | **The Figure 25 derivation note for Adrian.** Two pages. Mostly assembly — CC's `FIG25_lineage_and_package_plan.md` Part 1 and the DATA README already carry it in plain language |
| T5 | Amend PARTREG for the parallel-branch correction before it goes out |

---

## Friday 7 — Adrian's meeting day

**CC · methods seat**

| | task | gate |
|---|---|---|
| **F1** | **PARTREG Stage 1 runs.** Part × year table, both axes summarised, weighted and unweighted fits, percentile sweep p05–p50, community slopes, bootstrap | **STOP — report before registering** |
| F2 | SCHEM-2 production version: swap the four structural cover sheets for real thumbnails from the 581 MB stack; add the render-time assertions SCHEM-1 has | after F1 is running |

**Design seat**

| | task |
|---|---|
| F3 | Review Stage 1 output. **This is the decision point — see §3** |
| F4 | The attribute table spec, if not already covered by the DATA package's residual table |

**End of Friday: Stage 1 is either approved or being re-run.**

---

## Saturday 8 — the target

**Morning · CC**

| | task |
|---|---|
| S1 | Register Stage 1 outputs; build the three-panel scatter coloured by community |
| **S2** | **PARTREG Stage 2 — the 35 per-year regressions**, slope and intercept against year with bootstrap intervals per year |

**Afternoon · design seat**

| | task |
|---|---|
| S3 | Write the Stage 1 and Stage 2 figure text |
| **S4** | **Assemble the regression package for Adrian** — §4 |
| S5 | Send |

**If Stage 1 slipped on Friday, S2 moves to Sunday and the package ships without it.**

---

## Sunday 9 — buffer, and Stage 3 if it is free

| | task |
|---|---|
| U1 | **PARTREG Stage 3** — the three periods as summaries of the annual series, common part set, three residual maps |
| U2 | Fold the part-grain result into the methods document as V14, if Stage 1 changed anything material |
| U3 | Contingency for anything that slipped |

**Stage 3 is explicitly not promised to Adrian for this package.** It is the weakest of the three
— six post-2018 years — and it is a summary of Stage 2 rather than new evidence.

---

## 3 · The decision point on Friday

Stage 1 can come back three ways and they need different Saturdays.

**A · The part-grain slope is close to the registered 52.7 + 0.548.** Best case. The paddock-grain
line is confirmed at finer grain, N goes from 64 to ~115, and the package is straightforward.
**Proceed as planned.**

**B · The part-grain slope differs materially.** **This is a finding, not a failure** — it would mean
the paddock-grain expectation line is an aggregation artefact, which is exactly §11's argument
arriving as evidence. But every residual in the delivery pack is measured against that line, so it
needs a design-seat ruling before anything ships. **Costs half of Saturday morning; Stage 2 moves to
Sunday.**

**C · The community slopes diverge.** The pooled line is misspecified and the figure needs three
lines rather than one. **Changes the figure, not the schedule.**

**Pre-register the response now, before we see it:** in case B we report both fits side by side and
say plainly which grain each existing result rests on. We do not retire the paddock-grain line
three days out from a deadline.

---

## 4 · Deliverables — what Adrian actually receives

### Already built and needing nothing

- **`Output/pack/DATA/`** — 11 files, 649 MB, checksum-verified both sides. The rasters and the
  residual table he asked for directly.
- **`FIG25_lineage_and_package_plan.md`** — the plain-language derivation, already written.

### To ship Saturday

| | deliverable | state |
|---|---|---|
| **D1** | **The methods schematic**, registered | SCHEM-1 rendered, awaiting registrar |
| **D2** | **The pictorial companion** | prototype built; needs real cover thumbnails |
| **D3** | **The Figure 25 derivation note**, two pages | tonight |
| **D4** | **The part-grain regression** — ~115 points, coloured by community, with the 64-paddock line shown for comparison | Stage 1 |
| **D5** | **The percentile sweep** — p05 to p50, closing an open project decision with evidence | Stage 1 |
| **D6** | **The per-year slope series** — 35 fits, no period boundaries | Stage 2 |
| **D7** | **The part-level attribute table**, joinable to paddock and community polygons | Stage 1 |
| **D8** | **A one-page cover note** stating what changed, what it means, and what is still open | Saturday |

### Explicitly not in this package

Stage 3's three periods. The §11 figure. The caption collapse. Anything requiring the land-use maps.

---

## 5 · Saturday or Sunday

**Saturday, with Sunday as the buffer** — and the reason is Stage 1's gate.

If Stage 1 lands Friday and comes back case A, Saturday is comfortable: register, plot, write, send.
If it comes back case B, Saturday morning goes to the ruling and the package still ships Saturday
evening without Stage 2.

**Promising Sunday would consume the buffer as schedule.** With a Monday deadline and two live CC
seats, the buffer is worth more than the extra deliverable — and D6 is the only thing that would
gain from the extra day.

**Tell Adrian Saturday, and say Stage 2 may follow Sunday.** That is honest, it front-loads the part
he needs for the article, and it leaves the Monday deadline untouched.

---

## 6 · What could go wrong, and the response

| risk | response |
|---|---|
| Stage 1 reveals the part branch needs re-extraction rather than re-summarising | Ship D1–D3, D7 Saturday; regression follows Sunday |
| The two CC seats collide on `report_figs.py` | Confirm the report seat's worktree tonight, before either writes |
| Case B needs more than a morning | Report both fits, rule after the deadline |
| The 581 MB cover stack makes SCHEM-2's thumbnails slow | Ship SCHEM-2 with the structural texture and its honest label |

**Nothing on this ladder touches the 10 August deliverable.** The pack is sealed at v1.2, the
methods document is at V13, and both are independent of everything above.
