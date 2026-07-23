# Task L — merge & review checklist

*Design seat, 23 July 2026. Work through in order. Everything here is the **human** step: staging, commit, PR, merge. Nothing below is delegated to CC.*

**State going in:** two open PRs (Gate E, unmerged) + one large uncommitted branch (`tier2L-gate3-rollout`), plus one local-only commit on `main` from the D2 workstream. Three layers of unmerged state — clear them oldest-first.

---

## Step 0 — Sync `main` before anything else

The D2 registration commit (`1cc07b01`, "add '.gitignore'", 20 Jul) is **committed locally but never pushed** — the sign-in wall stopped it. So local `main` is one commit ahead of `origin/main`. Fix that first, or every subsequent merge happens against a `main` that GitHub and your machine disagree about.

- [ ] `git log --oneline origin/main..main` — expect exactly the one D2 commit.
- [ ] Push it. Expect a credential prompt: GitHub will **not** accept your account password at the git prompt — it needs a **Personal Access Token** (fine-grained, scoped to `Gayini_Time_Series`, `Contents: read/write`). Generate it in the browser, paste as the password.
- [ ] Confirm `origin/main == main` before proceeding.

> If the push still fails, **stop here**. Don't stack more merges on an unsynced main — sort auth first.

---

## Step 1 — Overlap check (do NOT skip)

Gate E and Task L both touch the veg×water method area. CC believes they don't collide (Task L re-derives from rasters and branched off `main`), but that's a belief, not a check.

- [ ] `git diff --stat main...tier2h-gateE-figure-build` — list Gate E's files.
- [ ] `git status --porcelain` on the Task L branch — list Task L's files.
- [ ] Compare the two lists. **Watch specifically for:** `R/gayini_veg_regime_functions.R` (the palette both rely on), `R/gayini_gradient_helpers.R`, and anything under `scripts/07_figures_dashboards/`.
- [ ] Zero overlap → proceed. Overlap → resolve it deliberately *before* merging either (decide which version wins, per file).

**Also verify a contradiction in CC's own file list:** `R/gayini_veg_water_census_panels.R` is reported as both **M** (modified) and **New**. It should be new-to-the-branch. Confirm with `git status` which it actually is — if it's genuinely modified, something pre-existed and you need to know what.

---

## Step 2 — Merge PR 1: Gate E

Gate E first: it's the older PR, and Task L's method descends from it (even though Task L doesn't depend on its commits).

- [ ] Review the Gate E PR on GitHub.
- [ ] Merge.
- [ ] Locally: `git checkout main && git pull` — confirm the Gate E commits are now on `main`.

---

## Step 3 — Rebase/merge Task L onto the updated main

Task L branched off `main` **before** Gate E landed. Now `main` has moved.

- [ ] `git checkout tier2L-gate3-rollout`
- [ ] Bring it up to date against the new `main` (merge or rebase, your preference — merge is safer with uncommitted work present).
- [ ] Resolve any conflicts. Given Step 1 came back clean, expect none.

---

## Step 4 — Read the four DRAFT change reports

Four reports, one per sub-gate. Read them as **claims to verify**, not summaries to skim. The load-bearing assertion in each:

| Report | The claim to check |
|---|---|
| `taskL_gate3_20260722_DRAFT.md` | 78 dashboards (57+21) + 20 own-clouds; archive was a **move** (124 files present in `_archive/`, absent from live dirs); the Gate-E-not-merged finding; the 10 unplaced sites named; GA_022 logged as a data-side task |
| `taskL_gate3_1_20260723_DRAFT.md` | the four refinements landed; **site breakdown reconciles to 57** (38 haze+marker · 1 haze+note (GA_022) · 9 marker-only · 9 note-only) |
| `taskL_gate3_1_alpha_20260723_DRAFT.md` | α = 0.20; the Mara 7 bin counts (686 px, 0/8 bins ≥500); the percentile diagnostic conclusions; findings log seeded |
| `taskL_gate3_1_wigglefix_20260723_DRAFT.md` | the **4/20 audit table** (Bala 26ca, Dinan 6, Mara 7, Mara 8 — 5 lines); the fix is scoped to own-clouds only (dashboards provably unaffected); p05 confirmed as evidence; the floor-ordering correction promoted to the facts doc |

- [ ] Read all four.
- [ ] **Spot-check one claim against the disk** rather than trusting all four reports — e.g. confirm `_archive/taskL_pre_rollout_20260722/` really holds 124 files, or open Mara 7's own-cloud and confirm the Riverine line is gone (density only).
- [ ] Rename all four: strip `_DRAFT` from the filenames.

**Judgment call:** four reports for one merge is fragmented, but they *are* the honest chronological record and each was a real STOP. My lean is keep them separate. Consolidating into one is defensible — just decide, don't default.

---

## Step 5 — Stage the right files

### Commit (code — 5 files)
- [ ] `R/gayini_veg_water_census_panels.R` (new — the two panel functions + fixes)
- [ ] `R/gayini_dashboard_compose.R`
- [ ] `R/gayini_dashboard_panels.R`
- [ ] `R/gayini_area_map.R`
- [ ] `scripts/07_figures_dashboards/12_build_dashboards.R`

### Commit (docs — 6 files)
- [ ] `docs/Gayini_established_data_facts.md` (§9 floor-ordering correction)
- [ ] `docs/Gayini_taskL_figure_observations.md` (new — the findings log)
- [ ] the four renamed change reports in `docs/change_reports/`
- [ ] `docs/Tier2_TaskL_dashboard_report_rollout.md` — **check this is current (v11)** on disk; if you've been saving my updates there, it's tracked and should go in

### Do NOT commit
- [ ] the 78 dashboard PNGs/PDFs, the 20 own-clouds, any zip — gitignored, stay on disk
- [ ] the `.sqlite` DB
- [ ] `Output/diagnostics/taskL_gate2/`, `taskL_gate3_1/`, `scratch_parity/` — scratch
- [ ] Confirm with `git status --porcelain` that **no** `.png` / `.pdf` / `.zip` / `.sqlite` is staged

**Optional decision — two evidence CSVs.** `paddock_dominant_community.csv` and `marker_reconciliation.csv` back assertions in the reports (the 20/21 focus split; the Δ=0 reconciliation). They currently sit in gitignored scratch dirs. My lean: **move them to `Output/tables/` and force-add** (`git add -f`), matching the D2 precedent — they're the evidence for claims that will otherwise only exist in prose. Skip if you'd rather keep the commit lean.

---

## Step 6 — Commit, push, PR

- [ ] Commit message: describe the task, not the first file. Something like:
      `Task L Gates 3/3.1: propagate all-pixel veg×water panel to 78 dashboards + 20 paddock own-clouds`
- [ ] Include in the body: the density-only fix (4/20 own-clouds had fabricated tails), p05 confirmed as headline, and the floor-ordering correction promoted to the facts doc.
- [ ] Push the branch; open the PR.
- [ ] Human review, then merge.

---

## Red flags — stop and reassess if any of these appear

- Step 0 push fails again → auth is unresolved; fix that before merging anything.
- Step 1 finds file overlap between Gate E and Task L → decide per file *before* merging either.
- A `.png` / `.sqlite` shows up staged → the gitignore isn't doing its job; investigate before committing.
- A spot-check in Step 4 disagrees with its change report → treat the report as unverified and re-check the rest.

---

## After the merge

1. **Gate 5** — additive `figure_asset` registration for the 78 + 20, against a clean merged tree. Note it must also reckon with Gate E's rows (which existed only in the working-tree DB) and the 57 stale D2 rows now pointing at archived paths.
2. **Summary figures for Adrian** — the scale × percentile matrix + methods figure register (dependency now satisfied: the density-only fix has landed, so the paddock row won't inherit fabricated curves).
3. **Gate 4** — per-unit reports. The findings log and the report template become the narrative backbone.

*Deliberately in that order: register before reporting, so reports embed registered figures.*
