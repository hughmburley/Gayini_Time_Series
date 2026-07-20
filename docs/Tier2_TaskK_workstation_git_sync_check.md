# Task K — Workstation sync check

*Design seat. Execution: Claude Code **on the workstation**. Read-only reconnaissance — no fixes without a gate.*

**Read first:** `docs/CLAUDE.md`, `docs/Gayini_established_data_facts.md`, and the most recent `docs/change_reports/*` if any are present.

---

## 0. Why this task exists

The workstation has a **byte copy** of the laptop repo — code **and** the full 1.57 GB `Output/` (rasters, census parquet, `Gayini_Results.sqlite`, `Gayini_Results.gpkg`). The goal is to confirm the **code** is in sync with `github.com/hughmburley/Gayini_Time_Series` **without losing the copied `Output/`**, which is NOT on GitHub.

> 🔴 **Do not `git clone` over the existing copy, and do not clone into a fresh folder and abandon this one.**
> GitHub does not contain `Output/` (commit rule: code and small tables only, never rasters/large spatial files). A fresh clone yields synced code next to an **empty `Output/`** — destroying the copied data. The copied `Output/` is the expensive, hard-to-regenerate part. **Preserve it.** Reconcile the code around it.

This is reconnaissance. **Report; do not fix.** Every step is read-only except the explicitly-flagged `git fetch` (network read, no working-tree change) and the optional `git pull --ff-only` in §4, which runs **only** if its preconditions hold and is the one convergence action permitted.

## 1. Confirm we're in the right place

```
pwd
git rev-parse --show-toplevel      # is this a git repo at all?
git remote -v                       # does origin point at hughmburley/Gayini_Time_Series?
```

**If `git rev-parse` fails** — the copy did not bring a working `.git/` (a byte copy can miss or corrupt it). Stop and report. This is the one case where a clone-beside-and-migrate-Output plan is needed, and it's a human decision, not an automatic one.

**If `origin` is missing or wrong** — report the actual remote. Do not change it without confirmation.

## 2. Git state of the copy — before touching the network

```
git status                          # clean, or uncommitted changes the copy captured?
git log --oneline -5                # local HEAD
git branch -vv                      # current branch + its upstream tracking
git rev-parse HEAD
git stash list                      # did the copy capture stashed work?
```

Report:
- Current branch and HEAD short-SHA.
- **Working tree clean?** If not, list every modified/untracked path. A byte copy captures laptop work-in-progress verbatim — uncommitted edits, half-finished files. These are real and must not be discarded silently.
- Detached HEAD? Report it.
- Any stashes.

## 3. Compare against GitHub — network read only

```
git fetch origin                    # updates remote-tracking refs ONLY; no working-tree change
git log --oneline -5 origin/main    # or the correct default branch
git rev-list --left-right --count HEAD...origin/main
```

`git fetch` is safe: it moves `origin/*` refs, never your files or commits. The `rev-list` line gives `<ahead> <behind>` — commits the copy has that GitHub doesn't, and vice versa.

Four outcomes, report which:

| ahead | behind | meaning | action |
|---|---|---|---|
| 0 | 0 | in sync | nothing to do |
| 0 | N>0 | GitHub ahead — laptop pushed work the copy predates | §4 pull |
| N>0 | 0 | **copy ahead — laptop has unpushed commits captured in the byte copy** | 🔴 §5 |
| N>0 | M>0 | **diverged** | 🔴 §5, human decision |

> 🔴 The **ahead > 0** cases matter most. If the copy carries commits not on GitHub, they exist **only on the workstation now** (the laptop may or may not still have them). A careless "reset to origin to be safe" would delete them. **Never `git reset --hard`, never force anything, in this task.**

## 4. Converge — ONLY if clean and strictly behind

Run this **only if**: working tree is clean (§2) **and** ahead = 0, behind > 0 (§3).

```
git pull --ff-only origin main
```

Fast-forward only — it cannot create a merge commit or rewrite history, and it **does not touch `Output/`** (nothing under `Output/` is tracked beyond small tables, and a fast-forward only advances to commits that already exist on the remote). This is your standing convention.

If `--ff-only` **refuses**, the branches have diverged despite appearances — stop, report, go to §5. Do not escalate to a merge or rebase.

**Do not run this if the tree is dirty or the copy is ahead.** Converging would either fail or bury local work.

## 5. If ahead or diverged — STOP and report

Do not resolve automatically. Produce for the human:
- `git log --oneline origin/main..HEAD` — the local-only commits, by message.
- For each, `git show --stat <sha>` — what they touched. Flag any that touch **only** `docs/`, `scripts/`, or small tables (safe to push) vs anything unexpected.
- A recommendation: push from here, or reconcile against the laptop first. **The human decides.** The likely resolution is `git push origin main` from the workstation once the commits are confirmed as the intended laptop work — but that's a §-gated action, not part of this task.

## 6. Integrity of the copied Output/ — independent of git

Git tells you nothing about `Output/`, because `Output/` isn't tracked. Verify the copy landed intact:

```
git rev-parse HEAD                  # record for the report
```

Then, read-only:
- **`Output/` file count and total size.** Expect **~1,326 files, ~1.57 GB.** A short count means the copy dropped files.
- **`Gayini_Results.sqlite` opens and is a valid DB:** `sqlite3 Output/.../Gayini_Results.sqlite "PRAGMA integrity_check;"` → must return `ok`. Record the file's **SHA-256** and compare it to the laptop's if available. (Context: an earlier uploaded `.gpkg` copy was corrupt — a 957 KB file with a 686-million-page header. Byte copies of large binaries can truncate. Check both `.sqlite` and `.gpkg`.)
- **`Gayini_Results.gpkg`:** confirm it opens as SQLite and `PRAGMA integrity_check` returns `ok`. If it errors as "not a database", the copy is corrupt — report, do not attempt repair.
- Spot-check the biggest binaries exist and are non-truncated: the `fc_intermediate` cubes (expect ~381 MB and ~353 MB), `gayini_pixel_census_8058.parquet`.

## 7. The D:\ path assumption — will bite regardless of git

The DB and QA scripts carry **machine-pinned absolute paths** that only work if the repo sits at exactly `D:\Github_repos\Gayini`:
- `spatial_layer_asset` holds **5 absolute `D:\Github_repos\Gayini\...` paths** (facts §7, C12).
- `GAYINI_ROOT` defaults to hardcoded `D:/Github_repos/Gayini` in `scripts/09_qa/*`.
- `spatial_005` points into a **different repo** — `Murrumbidgee_Gauge_Workflow` — which may not exist on the workstation at all.

Report, read-only:
- The workstation's actual repo path (`git rev-parse --show-toplevel`). **Does it equal `D:\Github_repos\Gayini`?** If not, those 5 absolute paths and the QA default are already broken here.
- Whether a `Murrumbidgee_Gauge_Workflow` repo exists at the expected sibling path.

**Do not edit any paths.** This is a scoping finding for a later gate — but the human needs to know now, because it affects whether the DB build and QA scripts will run on this machine.

## 8. Deliverable

`docs/change_reports/taskK_workstation_sync_<date>.md`, committed. Structure:

1. **Verdict** — one line: is the workstation's code in sync with GitHub, and is the copied `Output/` intact?
2. **Git state** — branch, HEAD SHA, clean/dirty, ahead/behind counts. Which of the four §3 outcomes.
3. **Action taken** — `pull --ff-only` (if §4 fired) or "none — reported for human decision" (if §5). **Never claim a convergence that didn't happen.**
4. **Local-only commits** — if ahead, the §5 list.
5. **Output/ integrity** — file count, size, both `PRAGMA integrity_check` results, SHA-256 of `.sqlite` and `.gpkg`, big-binary spot check.
6. **D:\ path status** — repo path vs the `D:\Github_repos\Gayini` assumption; `Murrumbidgee_Gauge_Workflow` presence.
7. **What blocks heavy compute** — a plain list of anything that must be fixed before H4/veg-arithmetic can run here.

## 9. Hard limits

- **No `git clone`** over or beside this repo without human sign-off (§1 exception only).
- **No `git reset --hard`, no force-push, no rebase, no merge.** `pull --ff-only` is the only convergence action, under §4's preconditions only.
- **Nothing under `Output/` is moved, deleted, or modified.**
- **No path edits, no DB writes, no builder run.**
- Claude never appears as git author or co-author. No AI attribution in any commit.
- Branch-and-PR for the change report. Held for review.
