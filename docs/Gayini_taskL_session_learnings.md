# Gayini — Task L session: outcomes, findings & learnings

*Design-seat session, 20–23 July 2026. Written at session close as a handoff. Everything below is settled unless marked OPEN.*

**State at close:** `origin/main` at `71ac44d`. PR #12 (Gate E) and PR #13 (Task L) both merged. All work is on GitHub — nothing single-machine. Task L Gates 0–3.1 complete; Gates 4 (reports) and 5 (registration) outstanding.

---

## 1. What shipped

**Figures — 78 dashboards + 20 paddock own-clouds**

- Paddock family extended **4 → 21** (pinned canonical set; *not* derived from the 64-zone `management_zones` layer, which would have silently tripled it).
- Veg panel swapped from the old n=1 plot scatter to **community cloud + census unit marker**, one shared function for sites and paddocks.
- Marker = **mean over the unit's own census pixels**; reconciles **exactly** to the polygon `100·Σwet/Σvalid` (max |Δ| = 0 across all 68 placed units).
- Site panels **nest the paddock within the community cloud** (V2 translucent haze, α = 0.20): community grey → paddock haze → red ◆ site.
- Site inset highlights the site's paddock in red; paddock veg-map legend retired (boxplot carries the community-hue key).
- **Paddock own-clouds** (`OwnCloud_paddock_*`) are the per-paddock report centrepieces — a paddock has thousands of pixels so it sustains its own cloud; a site (1–17 px) can only be a marker.

**Honest degradation, everywhere**

- 39 sites get paddock haze · 9 marker-only (no paddock) · 9 note-only (no census px) · 1 haze+note (GA_022). Reconciles to 57.
- 4 sites rest on ≤5 census pixels → explicit thin-n note. Never suppress the count.
- Mara 13 (Woodland-majority, 54.3%) marked on its dominant *focus* community with a title-level flag; own-cloud **deferred** to the Gate 4 treed decision.

**Correctness fix — the most important thing in the session**

The sparse-bin safeguard was **inverted**: when *no* flood-frequency bin cleared the 500-pixel floor, the ELSE branch fit the k=10 GAM across the **whole range** — worst support producing the most fitting. **4 of 20 own-clouds carried fabricated tails** (Bala 26ca, Dinan 6, Mara 7, Mara 8 — 5 lines). Now returns density-only. Dashboards provably unaffected (full communities always clear the floor at low flood).

---

## 2. Findings worth carrying

**Metric**
- **p05 floor confirmed as the shipping headline — now evidence-based, not assumed.** The flood signal is largest at p05 (Inland dynamic range ~40 pp) and **compresses toward the median** (~27 pp at p20). Typical cover is high regardless; the floor is where flooding shows up.

**Correction to a project-level belief**
- Community **floor** ordering is **Inland ≫ {Aeolian ≈ Riverine}** — *not* a clean dry<mid<wet. Aeolian and Riverine are indistinguishable at the floor (Aeolian marginally higher). The dry-vs-mid distinction lives in **exposure** (flood freq 6/13/28 pixel · 9/22/50 plot), **not floor level**. Recorded in `established_data_facts.md` §9.
- **Refugia restated ~4,300 → ~6,460 ha** (Gate E D8, native-grid correction). ~4,300 is superseded.

**Per-unit observations** (in `docs/Gayini_taskL_figure_observations.md` — narrative material for Gate 4)
- **Bala 6** — the cleanest split: Riverine essentially flat at ~38–41% floor while Inland climbs 43 → ~73% over the *same* water. One management unit, two ecological stories.
- **Bala 12 vs Bala 8/11** — both Inland-dominant, different curves: Bala 12 a dip-then-rise S-curve to a ~82 plateau; Bala 8/11 a smooth monotone rise to ~65. "Inland floodplain" is not one curve.
- **Mara 7** — the wiggle was an artifact, not ecology (see the fix above).
- **GA_022** — `dim_plot` says Inland; its 16 footprint pixels are classified otherwise. **OPEN data-side task** — affects its gradient placement and any community rollup.

---

## 3. Method & discipline learnings

**Support layering is now three-deep on one dashboard, by design.** Each unit carries three different flood-frequency numbers: plot support (1 ha, any-water), 1 km neighbourhood mean, and pixel census. For GA_019: 48.57 / ~37 / 41.6. All correct, all different, each labelled with its support. Reports lead with **one** headline (plot support) and let the others be panel context.

**Sparse-data safeguards can invert.** Always read the ELSE branch. A cutoff that truncates when support is adequate but fits everything when support is absent is worse than no safeguard.

**Audit before fixing.** Mara 7 was spotted visually; the audit found **4 of 20** affected. Patching the symptom would have shipped three more fabricated curves.

**Percentile choice is a science decision, not a knob.** Running p05/p10/p20 as a diagnostic (rather than switching) produced defensible evidence *and* surfaced the ordering correction.

**Scale nesting works, and the paddock scale earns its place.** Paddock-scale own-clouds show things community-scale figures cannot (Bala 6, Bala 12 vs 8/11). Sites are too small — marker only.

---

## 4. Process learnings — including what went wrong

**What worked**

- **Recon-first gating with STOPs.** Every gate found something the previous framing had wrong: the stale #21 label, `spatial_review_flag` being 23 not 5, one generator (no separate D1, no F5c dependency), Mara 13's Woodland dominance, the 4/20 fabricated tails. None of these would have surfaced without a read-only gate ahead of the build.
- **Version-stamped spec + echo-back.** CC read only lines 77–136 at Gate 2 and skipped the echo; hardening the rule caught it, and every later gate echoed correctly.
- **Change reports on build gates** (standing rule) — plus the **figure observations log**, which is the thing change reports *can't* capture: what the outputs show, as distinct from what changed.
- **Letting CC stage and commit.** GUI tick-box staging under-committed twice (1 of 7 files, then 5 of 15). Scripted staging with a dry-run did not.

**What went wrong — worth not repeating**

1. **A false premise survived a dozen turns.** "Gate E is not merged" entered the spec as a ⚠ finding, sourced from a CC change report that *inferred* it from a branch pointer. It was wrong — Gate E merged via PR #12. A whole merge-order plan was built on it. **Lesson: the version-echo discipline protects a spec's currency, not its accuracy. Claims that assert something about the world need verifying against data the same as any other claim — especially when they arrive labelled "finding."**
2. **A commit that lied, and a misread log.** `1cc07b01`'s TortoiseGit message listed 7 files but staged only `.gitignore` — including the D2 registrar, the code that mutated the DB. When shown the log I read the *message* rather than the changed-files pane and confirmed it as fine, despite the stats line saying `modified = 1`. **Lesson: read the file list, not the commit message.**
3. **PR #8 previously merged leaving six commits behind.** Two independent partial-capture events. **Verify contents after each merge, not just the green tick.**

---

## 5. Why so much time went on Git — and how to stop it

Three sources, honestly:

- **Real accumulated debt.** Three workstreams of uncommitted work had piled up (D2 unpushed since the 20th, Task L uncommitted across five gates, plus the believed-unmerged Gate E). That backlog was real and had to be cleared once.
- **A phantom problem.** The false Gate E premise invented a sequencing constraint that didn't exist, and the `1cc07b01` partial commit needed genuine forensics.
- **Too many round-trips on low-risk steps.** Holding staging and committing at arm's length added exchanges on actions that were reversible and already reviewed.

**For next time:**

- **Commit and push at the end of each gate**, not in a batch at the end of the workstream. A gate that ends without a commit is a gate that hasn't finished.
- **CC stages, commits, and pushes the branch.** Human clicks Merge in the browser. That keeps the review gate where it matters and removes the manual staging that mis-fired twice.
- **The auth is now sorted** (PAT cached), so pushing is no longer a blocker.

---

## 6. Next session

**Immediate (5 min, queued with CC)**
1. Fix the stale figure: `established_data_facts.md` **L34 still says "~4,300 ha"** while L273 says ~6,460 supersedes it. The doc currently states a headline number two ways.
2. Grep the repo for remaining `4,300` / `4300` / `≈5%` refugia references — the old number has already propagated into the main results deck.

**Then, in order**
3. **Gate 5 — registration.** Additive `figure_asset` upsert for the 78 dashboards + 20 own-clouds (`run_id='taskL_...'`), same pattern as the D2 registrar. Never the builder. Also promote `run_gate3_rollout.R` from scratch to `scripts/07_figures_dashboards/` alongside the registrar — it's the recipe that produced the shipping figures.
4. **Adrian's summary figures** (spec in §7 below).
5. **Gate 4 — per-unit reports.** The Nari Nari deliverable. Report structure schematic and the three-frame comparison table are designed; the figure observations log is the narrative backbone.

**OPEN items (not urgent)**
- 22 `docs/tasks/*.md` exist on one machine only — a backup question, not a tracking one.
- GA_022 label/pixel mismatch — its own data-side task.
- Mara 13's report treatment + the 9 treed sites' reports — Gate 4 decisions.
- Whole-farm community×wetness 2-D key must live at the front of the main report (the paddock legends were retired on that assumption).
- Total-veg annualisation (Adrian's request) — parked; needs the FC product/band semantics pinned first.

---

## 7. Carried forward: the Adrian summary-figure spec

*Written this session, not yet built. Dependency (the density-only fix) is now satisfied.*

**(A) NEW — "scale × percentile" robustness matrix.** `SUMMARY_scale_x_percentile_matrix`, landscape ~13×9 in, 300 dpi. **3 rows (scale) × 3 columns (percentile p05/p20/p50):**
- Row 1 FARM — all census focus pixels pooled, one line.
- Row 2 COMMUNITY — three community-hued lines.
- Row 3 PADDOCK — 21 paddock lines as thin spaghetti, coloured by dominant community, α ~0.5.

Rules: **lines only, no grey density** (nine clouds would be unreadable); **common fixed y-axis across all nine** (the compression toward p50 *is* the finding); shared x = between-year flood frequency; sparse-tail rule per line (post-fix: density-only means no line); column headers glossed in plain language (p05 "worst-season floor" → p50 "typical"). Subtitle carries the takeaway: *the floor–flooding relationship holds at every scale and compresses toward the median — p05 is the most discriminating metric.*

**(B) METHODS FIGURE REGISTER** — `docs/Gayini_methods_figure_register.md`. One row per core methods figure: `figure_id | what DECISION it backs | support (census/plot) | path | run_id | audience`. Seed with S12, S21, S24, S26, S25, FigA, GAM p05/p50, qband p05/p50, percentile fan, plus (A).

Two things to flag to Adrian when presenting:
- **S25 (the ~3-month lag) is the weakest evidential link** — plot support, n = 2–17, Aeolian on 2–3 plots, IQR crossing zero at lag 9. Everything else in the pack is all-pixel census. Worth saying out loud rather than letting it sit unqualified beside census-backed neighbours.
- **S24/S26 contain a genuine support disagreement** — on Aeolian high, the plots say "responds" and the census does not. Already captioned; worth walking him to rather than leaving to be spotted.
