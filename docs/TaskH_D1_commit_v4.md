# D1 — commit the v4 census spec to `main`

*Task spec for Claude Code. Design seat, 20 Jul 2026. Closes defect D1: the authoritative Task H spec (`Tier2_TaskH_all_pixel_census_v4.md`) exists chat-side but was never committed — a fresh session picks up v1. **Doc/git only. No code, no DB, no builder.***

**Workflow: additive, gated, held.** Branch `taskh-d1-commit-v4` off `main`; commit; **do not merge** — hand back for human merge. **No AI authorship attribution** (no `Co-Authored-By:`).

---

## 0. Precondition — v4 must be on disk first

The v4 file must already be present at **`docs/Tier2_TaskH_all_pixel_census_v4.md`** (Hugh saves the design-seat copy there before this task runs). **Verify it exists and report its content SHA-256.** If it is absent, STOP — do not reconstruct it.

Confirm the on-disk copy is the intended v4 by spot-checking three anchors: §3.2 farm 85,910.8 ha / mapped 67,349.332 ha; §4.7 H6 zone table; §6 corrections C1–C9.

---

## 1. What to do

### 1.1 Prepend a dated supersession header to v4 — do NOT edit the body

v4 was written before the F6 verdict was finalised. **§4.3.2 and acceptance-gate item 8 still say "8/1/0" and instruct "STOP if the verdict changes."** The census verdict is **9/0/0** — the lone Riverine-low non-stationary flag was a 40-point sparsity artefact (54.1% false-positive across 1,000 random draws). Committing v4 verbatim would reintroduce a stale expectation the result now contradicts.

**Prepend** this note above the title (do not alter the body text — the body is committed for provenance):

```
> **SUPERSESSION NOTE (2026-07-20).** §4.3.2 and §7 item 8 carry the pre-finalisation
> "8/1/0" F6 expectation and a "STOP if it changes" instruction. The census verdict is
> **9 no-trend / 0 non-stationary / 0 directional** — the Riverine-low non-stationary
> flag was a 40-point sparsity artefact (54.1% false-positive across 1,000 draws).
> Where the body below reads 8/1/0, read 9/0/0. See docs/change_reports/ for the finding.
> The body is retained unedited for provenance.
```

### 1.2 Banner v1–v3 as superseded

- **v1** carries no superseded banner — add one.
- **v2, v3** point backward ("Supersedes vN") but are not themselves marked superseded — add a forward banner.

Add to each of `v1`/`v2`/`v3` a one-line header directly under their title:
```
> **SUPERSEDED by Tier2_TaskH_all_pixel_census_v4.md (2026-07-20). Retained for provenance.**
```
Do not otherwise edit v1–v3.

### 1.3 Commit

Stage v4 + the three banner edits. Commit on `taskh-d1-commit-v4`, message e.g. `docs: commit Task H census spec v4; mark v1-v3 superseded (D1)`. Held — do not merge.

---

## 2. Out of scope (do not do here)

- **C9** (`docs/archive/` gitignore + Task F doc commits) — separate doc/git task.
- Any correction to v4's C-status (e.g. C2 rasters are now registered) — v4 is committed as-is + header; the change reports carry the current state.
- No code, DB, builder, or figure work.

## 3. Report

Short. Content SHA of the on-disk v4; the header text added; confirmation v1–v3 banners applied; the commit SHA on the held branch; the compare URL for the PR.

## 4. Guardrails

- Doc/git only. Prepend the v4 header; do **not** edit v4's body. Banner v1–v3 only.
- Additive; no deletes. Branch-and-PR, held. No AI authorship attribution.
