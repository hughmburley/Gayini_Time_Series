# Gayini — repo root audit and GitHub audit spec

**Date:** 29 July 2026 · **Deadline:** 10 August 2026
**Companion to:** `CLAUDE.md` (rewritten 29 Jul) · `Gayini_spec_catalogue_and_archive_list_20260729.md`
**Status:** the root audit below is read from the uploaded files and the repo listing. **The GitHub
audit in §3 is a spec, not a result** — every number in it is a question, not a claim.

---

## 1. Root file audit — do we need them all?

Repo root holds 8 folders and 11 files, 125 commits. Verdict: **three removals, one move, two
rewrites, one decision.**

| Item | Last touched | Verdict | Why |
|---|---|---|---|
| `CLAUDE.md` | yesterday | **KEEP — replace** | Rewritten today; drop in the new version |
| `README.md` | last month | **KEEP — rewrite** | See §2. Contradicts the repo as it now exists |
| `Gayini.Rproj` | last month | **KEEP** | RStudio project, correct and minimal |
| `LICENSE` | last month | **KEEP — but confirm the choice** | See §1.3 |
| `.gitignore` | 2 days ago | **KEEP** | Actively maintained. Reconcile against §3 Gate B |
| `run_spine_smoke_test.R` | 3 days ago | **KEEP — fix** | Permanently red (I-10, I-11). A test that always fails is ignored exactly like one that always passes |
| `run_db_validation.R` | 2 weeks ago | **KEEP as is** | The best-designed check in the repo: post-build guard + spine validation, read-only, exits 1 on failure. This is what the smoke test should look like |
| `demo_spine.R` | 2 weeks ago | **REMOVE — verify first** | A demo at repo root implies a supported entry point. Confirm nothing `source()`s it, then archive |
| `github_push_audit_plan.md` | last month | **ARCHIVE** | Dated 25 June, written when `.git` was empty and the repo not yet initialised. **Its central recommendation has since been reversed** — see §1.1 |
| `DESCRIPTION` | last month | **DECIDE** | See §1.2 |
| `NAMESPACE` | last month | **DECIDE** | See §1.2 |
| `figures/diagnostics/` | yesterday | **MOVE — contract violation** | See §1.4 |
| `Output/` | 5 days ago | **KEEP — but document the reversal** | See §1.1 |
| `R/` `config/` `docs/` `scripts/` `tests/` `tools/` | current | **KEEP** | Correct structure |

### 1.1 `Output/` is committed, and two documents say it isn't

The repo listing shows `Output/` as a tracked directory, last committed **5 days ago** ("Task M
Gate D: two deck figures, dual-grid floor distribution"). Two documents disagree:

- **`README.md`:** *"Generated outputs live under `Output/` and are also ignored by Git."*
- **`github_push_audit_plan.md` (25 Jun):** *"Do not push `Input/`, `Output/`, `data_intermediate/`…"*
  — `Output/` measured at 423 files, 145 MB.

Committing `Output/` may well be the right call — CLAUDE.md's standing rule is *"`Output/` is the
record; `docs/` is never a result"*, and a record that isn't versioned isn't much of a record. But
**the decision was never written down**, so the two documents that describe the repo now describe a
repo that doesn't exist, and a fresh session reading either will draw the wrong conclusion.

The risk is not the decision; it's the drift between the decision and the documents — the same class
of failure as the number pollution. **Action:** confirm what is actually tracked under `Output/`
(§3 Gate B), then state the rule explicitly in README and CLAUDE.md: which subtrees are committed,
which are ignored, and why. The hard line stays — no rasters, no `.sqlite`, no large spatial data.

### 1.2 `DESCRIPTION` and `NAMESPACE` — commit or delete

README is candid about these: *"package-ready scaffolding only; workflow scripts still source helper
files directly from `R/`."* So they describe a package structure the repo does not use. That is
harmless until someone believes them — at which point `R/` looks like package code with an export
surface, and it isn't.

Two honest options: commit to the package model (move helpers behind `NAMESPACE`, make
`devtools::load_all()` the entry point), or delete both and let `R/` be a helpers folder that scripts
`source()`. **Recommend delete** — the package migration is not an August 10 job, and scaffolding
that lies is worse than no scaffolding. Deleting is reversible; the files are three lines each.

### 1.3 `LICENSE` — a governance question, not a legal one

Worth one deliberate look, because of what this repo contains. The outputs carry
*"Internal review — not for external release. Cultural sensitivity: review required with the Nari
Nari Tribal Council"*, and README records spatial review flags on six named plots. If `LICENSE` is a
permissive open-source licence, it grants rights over material whose release is explicitly gated on
a third party's review.

The licence probably covers only the code, and the repo is probably private — both of which would
make this a non-issue. But it is worth confirming rather than assuming, and it belongs to Nari Nari
and BCT to decide, not to the repo. **Action:** read the LICENSE, confirm the repo's visibility, and
if culturally sensitive outputs are tracked, raise the hosting question with BCT explicitly rather
than inheriting a default. This is a five-minute check that would be very expensive to get wrong.

### 1.4 `figures/diagnostics/` at root — a live contract violation

`Gayini_output_structure.md` acceptance criterion 4 is **"Nothing at `figures/` root."** There is a
`figures/diagnostics/` directory at *repo* root, outside `Output/` entirely, committed **yesterday**
("T12 close-out"). So the newest work is writing to a location the output contract forbids.

This is exactly how the 330 unregistered ladder figures happened: a default `out_dir` nobody
noticed. CLAUDE.md already records the cause — *nine functions default to `out_dir = "Output/figures"`*
— and this is a second instance one level further out.

**Action:** move the contents into `Output/figures/diagnostics/`, update any registry rows, and add a
smoke-test check that fails if any `figures/` directory exists outside `Output/`. That check is
cheap, and unlike `archive_absent` it asserts the invariant that is actually wanted.

---

## 2. `README.md` — what it should say

The current README describes the Stage 5 rationalisation and nothing since. It does not mention the
database, `CLAUDE.md`, the census, the deliverables, or the deadline. Three specific corrections:

1. **"`Output/` … ignored by Git"** — false, per §1.1.
2. **Step 1 is "run `run_spine_smoke_test.R`"** — that script exits 1 on a pre-existing structural
   check. A new reader's first action is a failing test with no explanation.
3. **No mention of `Gayini_Results.sqlite` as the authoritative store**, which is the single most
   important fact about the repo.

A README for this repo should be short and answer four questions: what the project is and who it
serves; where the authoritative data lives (the SQLite, the external parquet, the registered
rasters); how to orient (read `CLAUDE.md`, then `docs/Gayini_project_lineage_and_learnings.md`); and
what is safe to run (`run_db_validation.R` after a rebuild; nothing heavy casually). Keep the Safety
Notes section — it is the best part of the current file — and correct the `Output/` line.

---

## 3. GitHub audit — gate spec for Claude Code

Yes, it is in order. 125 commits, two machines, a reversed push policy, and a repo that now tracks
its own outputs — that combination has never been audited since `git init`.

**This spec is read-only through Gate C.** Nothing is moved, removed, rewritten or force-pushed.
Standing rules apply: re-read this spec in full and echo it verbatim at the start of every gate ·
commit straight to `main` at each gate STOP and report the SHA · no AI-attribution trailers ·
additive only.

**Scope note:** the June `github_push_audit_plan.md` audited the *filesystem before* the repo
existed. This audits the *repository as it now is*. They are different questions; do not reuse its
numbers.

### Gate A — What is tracked · STOP

No writes beyond the report.

1. `git ls-files | wc -l`, and a breakdown by extension and by top-level directory (count + total
   size). **Report the ten largest tracked files by path and size.**
2. **Assert the hard exclusions.** Report explicitly, one line each: is any `.sqlite`, `.parquet`,
   `.tif`, `.img`, `.jp2`, `.gpkg`, `.shp` or `.zip` tracked? Path and size for every hit.
3. **`Output/` breakdown** — what is tracked under it, by subdirectory, count and size. This is the
   §1.1 question and the report must answer it plainly.
4. Total repo size on disk vs `.git` size. A `.git` much larger than the working tree means
   something large is in history (Gate B).
5. `figures/` outside `Output/` — full listing, and whether any row in `figure_asset` points into it.

**STOP.** The `Output/` policy decision is a human call and it depends on 1–3.

### Gate B — History and `.gitignore` reality · STOP

1. **Largest blobs ever committed**, whether or not still present:
   `git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '$1=="blob"' | sort -k3 -nr | head -30`
   A large blob in history is permanent in every clone even after deletion. **Report it; do not
   rewrite history to fix it** — that is a separate, dangerous decision.
2. **Tracked-but-ignored files**: `git ls-files -i -c --exclude-standard`. These are files added
   before `.gitignore` covered them; `.gitignore` does not retroactively untrack.
3. `.gitignore` vs reality — every pattern, and whether anything matching it is tracked anyway.
4. **Secrets and machine leakage** — grep tracked files for `D:\\`, `E:\\`, `DESKTOP-`, hostnames,
   `password`, `token`, `api[-_]?key`, `secret`, and any credential-shaped string. CLAUDE.md already
   records five absolute `D:\` paths in `spatial_layer_asset`; confirm whether any tracked *file*
   carries them too.
5. **Commit authorship** — `git log --format='%an <%ae>'  | sort | uniq -c`. Confirm one author.
   Then grep all commit messages for `Co-Authored-By`, `Generated with`, `Claude`, `AI` — the
   standing rule is commits are authored solely by Hugh, and this is the only way to verify it held
   across 125 commits and two machines.
6. **Branches** — local and remote, merged and unmerged, with last-commit dates. Task H once held a
   branch `tier2h-track-a-census`; report whether it or any other stale branch still exists.
7. **Force-push / rewrite evidence** — any dangling or unreachable commits (`git fsck --lost-found`),
   reported not repaired.

**STOP.**

### Gate C — Documentation and registry integrity · STOP

1. **Broken doc pointers.** Extract every `docs/…` and `Output/…` path referenced in `CLAUDE.md`,
   `README.md` and every live doc under `docs/`; report which do not exist. CLAUDE.md was rewritten
   today against an archive sweep that has not run yet, so **misses are expected here** — the report
   is the checklist for finishing the sweep.
2. **Registry ↔ disk.** For all four asset tables: count rows, count `path_exists = 0`, and
   recompute checksums using **`sha256_first50()` — the builder's convention, not whole-file
   `digest`.** State which convention each comparison used; a whole-file hash against a truncated
   record mismatches spuriously on every file over 50 MB.
3. **Orphans** — files under `Output/` present on disk and registered nowhere, by subdirectory. The
   last count was 1,039 (78%); report the current number and whether it moved.
4. **`docs/` inventory** — every file, with its in-file version/date header where one exists, and a
   flag for any file with no header. Cross-check against the archive list in
   `Gayini_spec_catalogue_and_archive_list_20260729.md` and **report disagreements** rather than
   acting on either.

**STOP.**

### Gate D — The two safe fixes (writes, narrow)

Only after A–C are reviewed, and only these:

1. **Move `figures/diagnostics/` → `Output/figures/diagnostics/`.** Move, never copy-and-delete.
   Update `figure_asset.path` for any affected row in the same transaction. Re-run the broken-pointer
   check: **0 before, 0 after** is the acceptance test.
2. **Add the two checks that should exist:** a smoke-test assertion that no `figures/` directory
   exists outside `Output/`, and the T8 Gate C decimal-pp lint — grep `docs/` and the deck build
   scripts for bare `\d+\.\d+ *pp` strings and flag any not present as a `number_id` in
   `dim_headline_number`. **Prove each fires on a deliberately broken fixture and paste the failure
   output into the change report.** A check that has never failed has not been tested.

Everything else from Gates A–C goes to the issues log with a disposition. **Do not**: rewrite
history, untrack anything under `Output/`, delete `DESCRIPTION`/`NAMESPACE`/`demo_spine.R`, touch
`run_spine_smoke_test.R`'s `archive_absent` polarity, or change repo visibility. Those are human
decisions and three of them are one-way doors.

### Acceptance

- [ ] Report at `docs/change_reports/github_audit_<date>.md`, leading with anything wrong
- [ ] Gate A questions 2 and 3 answered explicitly, not by implication
- [ ] Checksum method stated per comparison
- [ ] `Gayini_Results.sqlite` SHA-256 recorded at start and end of the run, both in the report,
      **byte-identical**
- [ ] Every finding carries a disposition: fix now · issues log · human decision
- [ ] Committed to `main` at each gate STOP, SHA reported

---

## 4. Order

1. Drop in the new `CLAUDE.md`.
2. Run the archive sweep (61 files) and create `docs/decisions/` **before** it runs.
3. GitHub audit Gates A–C, read-only. Expect it to take one session.
4. Decide the three human calls: `Output/` policy · `DESCRIPTION`/`NAMESPACE` · licence and
   visibility.
5. Gate D fixes, README rewrite.
6. Then the report rollout, which is the deadline.

Steps 1–2 are today. Step 3 is worth doing before 10 August precisely because it is read-only — it
cannot break anything, and finding out afterwards that a 5 GB `.jp2` sits in history, or that a
culturally sensitive output has been on a third-party host since June, would be considerably worse.
