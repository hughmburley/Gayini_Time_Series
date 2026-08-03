# Task J (2018 pre/post) — handoff to the next chat

*Written 18 Jul 2026, end of the Task J design session. This chat completed Task J Gates 1–5 and built the Adrian methods deck. Two things remain that need the **live workstation files** and so belong in a fresh chat.*

---

## Where Task J stands: DONE

- **Gates 1–5 complete, merged to `main`** on `github.com/hughmburley/Gayini_Time_Series` (branch `tier1j-prepost-placebo`, PR merged).
- **The finding:** the pre/post difference is ~86% explained by how wet the two windows were (flow law R² = 0.864, fitted on 24 placebo dates). 2018's residual is +7.51 pp, **rank 2 of 25** — one placebo (2005, deep drought, no treatment) exceeds it; the near-flow-twin placebo (2009, almost identical flow) falls well below it. **Not attributable to the cuts.** L03 (no control region) and the heteroscedastic-sd caveat (L43) both stand.
- **Figures:** J-F1 (2018 difference map), J-F2 (six-panel placebo ladder — the punchline), J-F3 (the law), J-F4 (annual wet-extent + flow). All deck-ready.
- **Limitations register:** `Gayini_limitations_register_20260718_v10.xlsx`, 43 rows. L33 rewritten to the pixel-support finding; L43 added.
- **Methods deck for Adrian:** `Gayini_prepost_methods_deck.pptx`, 9 slides, built this session.

**There is no more Task J analysis to run.** What follows is packaging and reuse, not analysis.

---

## Job 1 — Register Task J's rasters in `raster_asset`  (needs the live DB)

**Why it was deferred:** during the session, Task H was writing `raster_asset` concurrently on the workstation. Worktrees/branches isolate files, not the SQLite DB, so a concurrent write could lose a registration silently. It was correctly deferred to avoid a collision.

**Why it's actionable now:** H's site dashboards are done (per Hugh, this session), so the DB should be idle. Confirm nothing else is mid-write, then register.

**What to register** (9 continuous diff rasters + the 6 kept for J-F2 panels — confirm the on-disk set):
- Native `Output/rasters/task_J/diff_pp_2018_28355.tif` (EPSG:28355, FLT4S) — the authoritative one.
- The 8058 display reproject (bilinear) if it's kept.
- The 6 placebo-panel diff rasters (1994/1999/2004/2009/2014/2018) if retained on disk.

**Discipline (from this session's hard-won lessons):**
- Register from the **live workstation DB**, not any uploaded copy — the uploaded `Gayini_Results.sqlite` is stale relative to what H has written.
- SHA-256 via the builder's first-50-MB convention (match existing `raster_asset` rows).
- **Do NOT re-run the builder** — it rebuilds the DB from scratch and would destroy the manually-added Task H census rows. Additive registration only.
- All areas/counts stay labelled by CRS. Never quote hectares off the 28355 grid (it's +0.23% vs the 8058 census grid — MGA55 scale factor).

---

## Job 2 — Fold pre/post into the site reports  (needs the P6.1 generator, which doesn't exist yet)

This is a genuinely good reuse and Hugh flagged it. The whole-farm difference map (J-F1) has a natural **per-site** version.

**The element:** for each site, clip the 2018 `diff_pp` raster to that site's footprint and overlay that site's cut points from `cuts.shp`. Caption: "how flood frequency shifted around this site's cuts, 2018–2022 vs before."

**Two non-negotiable conditions (both from the register):**
1. **Carry the J-F1 caption discipline — "descriptive, not an effect."** Without it, a clipped site map silently becomes the causal claim the whole task disproved. This is the single biggest risk in the reuse.
2. **Cut points must use the ~645-distinct-sites framing, not "1,158 cuts."** 1,158 = rows; 940 = unique coordinates; ~645 = distinct sites (50 m linkage). And ideally resolve **L07** first — is the cut `Date` a *cut* date or a *survey* date? 218 of 940 locations carry both May and Sept 2018; the file is a 16-Jul export with only a `Date` field, quite possibly stripped of a fuller source.

**Blocker:** the P6.1 site-report generator is the roadmap's next rung and is **unstarted**. This element is a P6 enhancement, not buildable until the generator scaffold exists. The open question that gates the scaffold: **is a "site" one plot or a cluster?** (66 plots → 66 reports, or ~a dozen cluster reports.) One line to Adrian before scaffolding.

---

## Job 3 (small, off critical path) — the Jana email

Never sent, all session. Three questions, ~6 lines. Gates the *matched near/far DiD* (a possible Task J follow-up), not anything above:
1. Does the cut `Date` record when the cut was **made** or **surveyed**? (L07)
2. Are bank **lines / compartment polygons** available, not just points? (L10 — would let treatment be defined by connectivity instead of distance; management zones were tested as a proxy and rejected.)
3. Is `cuts.shp` an **export** of a richer source? (dbf has one field; internal header dated 16 Jul — likely not Jana's original.)

---

## Things the next chat should carry in (hard-won this session)

- **Read the tables, not the reports.** Every prose claim that was wrong this session (three in Gate 2/3, plus five "name stopped matching contents" traps: `farm_area_ha`, the wet-rule branch, `annual_occurrence_pct`, gauge `141.01`, `interval="day"`) was caught by opening the actual data. Verify CC's reports against the DB independently.
- **The 255 nodata trap** (`annual_valid_any` is `{1,255}`, no zero) — assert `valid ⊆ {1}+NA`, never `⊆{0,1}` (vacuous). Re-read every raster write from disk and assert; don't trust the write.
- **Uploaded binaries can be corrupt** — the project-sidebar `.gpkg` and a `.docx`-that-was-markdown both round-tripped through UTF-8. Trust the uploaded-via-chat copies; checksum transfers.
- **F6 trend gate:** the authoritative verdict is the **census** F6 (Task H P2.2), not the plot-based `tier1d` one (which reads 8/0/1 and is superseded). The census retired the lone Riverine-low flag as a 40-point sparsity artifact (54.1% false-positive rate). Gate came back null → **Phase D surface is not built** — that's the result.
- **H2/P4.1 has landed and passed** its seasonal-mix gate (verdict PASS, monotonicity 0 violations, no +100 offset in play). The FC-band blocker is resolved. So Track B (P4.3/P4.4 — the veg-vs-inundation lag, the B2 headline) is now unblocked, ahead of where the roadmap assumed.

## Roadmap position after this session

Next rung is **P6.1** (site-report generator — the un-gated deliverable, deadline-critical), with **P4.4** (census lag matrix — the science headline) now reachable since P4.1 came in clean. Registration (Job 1) and the site-report pre/post element (Job 2) both slot into P6.
