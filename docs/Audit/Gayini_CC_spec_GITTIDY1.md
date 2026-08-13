# Gayini CC spec — GITTIDY-1

**Consolidate the repository onto `main` before it is archived.**
Design seat, 12 August 2026. Additive only. Two gates.

---

## 0 · Standing execution rule

Run to the STOP, report, wait. Recon first — `git fetch`, `git status`, `git log --oneline -10`.

**This is the last write to this repository before it becomes a read-only archive.** Everything here
is additive: **no deletion, no history rewrite, no force-push, no rebase, and no `git merge` of any
branch.** If a step appears to require any of those, stop and report.

Authored as Hugh Burley / hugh.burley@gmail.com. No AI attribution anywhere — not in a commit
message, not in a trailer, not in a file added by this task.

---

## 1 · Why a merge is the wrong instrument

Two branches carry real work that never reached `main`: `origin/tier2k-gate0-output-census` and
`origin/tier2k-gateA-archive`, holding commits `8778962` and `dc13650`. Neither is an ancestor of
HEAD. The 1,351-row census with its registry join, folder-shape analysis and checksum verification is
**invisible to anyone reading the repository**, and is about to be archived that way.

**They predate the 28 July "commit straight to main" rule**, so `main` has moved a long way since they
were cut. A branch merge would bring across the branch's version of every file it touches, including
files that have been superseded on `main` — silently reverting current work to reclaim old work.

**Extract the files and commit them as new paths.** That cannot revert anything, and it is the only
form of this task consistent with additive-only.

---

## 2 · Gate A — survey · **STOP**

Report, change nothing.

**From the two branches.** Every file each branch adds, with path, size and whether a file of that
path exists on `main` today. **Flag every collision** — a branch file whose path is already occupied.
Collisions do not travel to their original path; they go to a subfolder under §3 with the branch
noted. **Do not diff-and-choose.** A newer file on `main` wins by construction and nothing is
overwritten.

**Untracked files in the working tree.** `docs/Audit/` is untracked in its entirety — `check-ignore`
exits 1, so it was never ignored, only never committed. That covers the Gate B learnings, the
TRACE-1, RETRO-1 and HANDOFF-1/2 specs, the status change and the budget document. **List everything
untracked, with size**, not only that folder.

**Two things to check and report before anything is committed:**

- **Rate, fee, day-rate or invoice detail** in any untracked file. This repository may be read by the
  funding institution. Report the file and the line; **commit nothing that contains it** until the
  design seat rules.
- **`Gayini_remaining_budget_and_forward_pitch_20260810.md`** — sections 2 to 7 are void per the
  11 August status change; the budget they describe does not exist. Committing it as-is makes a void
  document look current in a repository about to be handed over. **Report it; do not add a header and
  do not commit it** in this gate. The design seat rules on whether it gets a superseded header or
  stays out.

**Also report:** any other unmerged remote branch, any stash, and whether the local and remote heads
diverge.

---

## 3 · Gate B — commit · **only after sign-off**

**Branch recovery.** Extract approved files with `git show <ref>:<path>`, written to
`Output/archive/taskK_gate0/` and `Output/archive/taskK_gateA/`. **Never check out the branch and
never merge it.** Add a one-page `README.md` in each folder: which branch and commit it came from,
what the work established, and the date. **The branches are left in place** — recovery is a copy, not
a migration, and the branch remains the provenance.

**Untracked files**, in three commits so the log stays legible:

1. `docs/Audit/` — the governance and audit record, minus anything §2 flagged
2. `Output/archive/**` — the recovered Task K work
3. Everything else approved, grouped sensibly

**Un-ignore under Ruling BB in the shape of CL** where needed. Verify with `git check-ignore -v`
**and by result** — `git status --porcelain` plus a dry-run `git add` staging exactly the intended
paths. A re-include placed above the exclusion that governs it is inert and re-reading the file
cannot tell the two apart (I-60).

**Every command whose result is relied upon runs separately and its output is queried.** Not chained.
A pipeline reports its last stage's status and launders everything upstream — which is how a commit
in this project once proceeded on an unverified staging check (R8).

**After each commit, confirm contents with `git show --stat`** before the next. Then push.

---

## 4 · Checks

- **Nothing is deleted.** Confirm `git diff --stat HEAD@{before}..HEAD` shows additions and
  modifications only, no deletions. If it shows a deletion, stop.
- **Coverage stated** (I-53): how many untracked files were examined against the total, and how many
  branch files against each branch's total.
- **Assert on the result, not the intent**: after pushing, re-query the remote and confirm both new
  folders and the untracked set are present.

---

## 5 · What this is not

It does not merge, rebase, squash, force-push, delete a branch, or rewrite any history. It does not
touch the handoff destination tree, the database, or any registered number. It does not edit the
budget document or decide what is sensitive.

**A collision list and a clean deletion-free diff are the evidence this ran correctly.**

**STOP at Gate A.**

---

**Rulings in force:** BB, CL, DP, DS.
**Patterns in force:** I-53, I-60, R8.
