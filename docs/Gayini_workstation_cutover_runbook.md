# Gayini — workstation cutover runbook

*Design-seat runbook, 16 July 2026. Facts in §3 were measured against the live `Gayini_Results.sqlite`, not assumed.*

**Scope: the USB drive plugs into the workstation. All files come with it. Nothing is copied, nothing is moved, no paths change. This is a fresh-software-install job, not a data migration.**

**The laptop is untouched and remains fully functional. If the workstation stalls, carry on where you are.**

---

## 1. Why

| | Laptop (current) | Workstation |
|---|---|---|
| CPU | i5-8265U, 4c/8t, **running 1.40 GHz against a 1.80 base** (15 W mobile, throttling) | ~12 cores at desktop TDP |
| RAM | 15.8 GB, **96% used — ~0.6 GB free** | **64 GB** |

**RAM is the constraint. It is the only one that matters.** H2 sizing:

```
140 composites × 2134 × 1334        = 398.5M values
as int16 (after masking 255 -> NA)  = 797 MB   bare minimum
percentile needs all 140 per pixel  -> full cube resident, or chunk
realistic terra working set         ~ 2-4 GB
available on the laptop             ~ 0.6 GB     <- must chunk and spill
available on the workstation        ~ 64 GB      <- resident, no spill
```

**The USB drive is not the problem.** An earlier version of this runbook over-weighted it. The disk only hurts *because of* chunking: with 0.6 GB free, terra spills and re-reads the same 140 files in random blocks, repeatedly. Remove the chunking and the I/O profile changes completely:

```
read 140 FC rasters (1.3 GB)   -> ONCE, sequentially.  USB 3.0 ~5-15 s.  USB 2.0 ~40 s.
total_veg cube (797 MB int16)  -> resident in RAM.     No spill.
percentile over 140 values/px  -> CPU-bound, not I/O-bound
write 5 rasters (~57 MB)       -> once
```

A one-off sequential 1.3 GB read is nothing. And terra's temp directory defaults to `C:` anyway, so any residual spill lands on the workstation's NVMe rather than the USB.

**Timing:** H2 is the last heavy compute in Task H (H4's census parquet is ~1.08M × 16 — light; H6 is a reclassify). Doing this now, with only H2 pending, beats doing it later with H4/H5/site reports in flight.

**Cheap fallback:** the laptop has **14 days uptime at 96% RAM**. A reboot likely frees 8–10 GB and may make H2 viable locally if the workstation stalls.

## 2. 🔴 The one step that can break everything: the drive letter

The repo currently lives at **`D:\Github_repos\Gayini`**, and `spatial_layer_asset` has **five absolute paths hardcoded to `D:`**:

```
spatial_001  plots_source      D:\Github_repos\Gayini\Input\shapefiles.zip
spatial_002  gayini_boundary   D:\Github_repos\Gayini\Input\shapefiles.zip
spatial_003  vegetation_units  D:\Github_repos\Gayini\Input\shapefiles.zip
spatial_004  management_zones  D:\Github_repos\Gayini\Input\shapefiles.zip
spatial_005  gauge_sites       D:\Github_repos\Murrumbidgee_Gauge_Workflow\Output\database\gayini_murrumbidgee_gauges.sqlite
```

**If the drive mounts as `E:` on the workstation, all five break.** If it mounts as `D:`, everything works untouched.

> **Plug the drive in. Check the letter. If it is not `D:` — Disk Management → right-click the volume → *Change Drive Letter and Paths* → set `D:`.** Thirty seconds.

The irony is worth naming: the hardcoded absolute paths flagged as defect **C12** are exactly what makes this cutover zero-effort — *provided the letter matches*. It works by luck, but the luck is enforceable.

**Corollary: do NOT copy the repo to `C:\repos\Gayini`.** That would break those five rows and force C12 today. Keep it on `D:`; defer C12 until after the presentation.

> ⚠️ **`spatial_005` points at a *sibling repo*** (`Murrumbidgee_Gauge_Workflow`). Confirm it is on the same USB drive — the README notes *"External biodiversity and gauge companion databases are imported when present at the expected sibling repo paths."* Check for a biodiversity sibling too.

## 3. Verified facts

| Registry | Rows | Absolute paths | On cutover |
|---|---:|---:|---|
| `raster_asset` | 102 | **0** | ✅ relative — `Output/rasters/...` |
| `figure_asset` | 139 | **0** | ✅ relative |
| `report_asset` | 38 | **0** | ✅ relative |
| **`spatial_layer_asset`** | 5 | **5** | ⚠️ fine **only if the drive is `D:`** — see §2 |

**Checksums:** `raster_asset` carries **100 SHA-256 checksums across 102 rows** — and **nothing has ever verified them**. That makes environment validation nearly free (§6). The only two rows without checksums are the *original* 28355 stack (`stack_annual_wet_any_1988_2023`, `stack_annual_valid_any_1988_2023`) — a pre-existing gap, not Track A's; both new 8058 rows are checksummed.

## 4. Do NOT migrate the chats

Your architecture settles this: **"Claude Code does not accumulate memory across sessions; CLAUDE.md, MEMORY.md, and repo docs serve as the cumulative memory system."**

The drive already carries CLAUDE.md, the task specs, `Gayini_established_data_facts.md`, the data contract and the change reports. **That is the memory.** Fresh install, fresh sessions.

> If you ever did want transcripts: they live at `~/.claude/projects/<project>/<session-id>.jsonl` on the **machine that created them** — they are *not* on the USB drive, and session-ID lookup is scoped to the project directory. Since the path stays `D:\Github_repos\Gayini`, the project key (`D--Github-repos-Gayini`) would actually match if you copied `~/.claude/projects/D--Github-repos-Gayini/` across. **Still not worth it** — start fresh and hand over the docs.

## 5. 🟡 The real risk: this is your only copy

`Input/` and `Output/` are **gitignored**. GitHub has your code. It does **not** have:

- ~1.3 GB of FC source rasters
- the inundation stack
- `Gayini_Results.sqlite` / `.gpkg`
- every derived raster Track A produced

**A single USB drive is the sole copy of all of it**, on a four-week critical path, about to be unplugged and carried between machines. That is not a performance argument — it is durability.

**One command. Insurance only. Nothing reads from it.**

```powershell
robocopy "D:\Github_repos" "C:\backup\Github_repos" /E /Z /MT:8 /R:2 /W:5 `
         /LOG:"$env:USERPROFILE\gayini_backup.log"
if ($LASTEXITCODE -ge 8) { Write-Error "backup FAILED - see the log" } else { "backup OK" }
```

Cold copy on the NVMe. Does not touch paths, does not break `spatial_layer_asset`, does not change the workflow. Run it and forget it.

## 6. Install list — this is the whole job

- [ ] **Claude Code** — install, sign in, `claude --version` returns
- [ ] **R** + **declared dependencies** ← *this is the environment test*
- [ ] **VS Code** + Claude Code extension (if you want the panel; the CLI alone is fine)
- [ ] **git** (for pull/push; the repo itself is already on the drive)
- [ ] **Rtools** if any dependency compiles from source

**Nothing is copied. Nothing is cloned.** The repo, the data and the database are already there.

## 7. Validate the environment

### 7a. Checksum verify — proves the data reads correctly on the new machine

```r
library(DBI); library(digest); library(dplyr)
setwd("D:/Github_repos/Gayini")                # asset paths are RELATIVE to repo root
con <- dbConnect(RSQLite::SQLite(), "<path>/Gayini_Results.sqlite")

ra <- dbGetQuery(con, "SELECT raster_asset_id, path, checksum_sha256
                       FROM raster_asset WHERE checksum_sha256 IS NOT NULL") |>
  mutate(exists = file.exists(path),
         actual = ifelse(exists, vapply(path, digest, "", algo = "sha256", file = TRUE), NA),
         ok     = !is.na(actual) & actual == checksum_sha256)

print(filter(ra, !ok))                          # anything here = a bad or unreadable file
stopifnot(all(ra$exists)); stopifnot(all(ra$ok))
message(sum(ra$ok), "/", nrow(ra), " rasters verified against raster_asset checksums")
```

**Expected: 100/100 pass.** (102 rows, 2 without checksums — §3.)

> Worth committing as a permanent release check. Nothing currently verifies `checksum_sha256` or `path_exists` after build — a gap independent of the cutover.

### 7b. Spatial layers resolve

```r
sl <- dbGetQuery(con, "SELECT layer_name, path FROM spatial_layer_asset")
sl$exists <- file.exists(sl$path)
print(sl)                                       # all 5 must be TRUE
stopifnot(all(sl$exists))                       # if FALSE -> wrong drive letter (§2)
```

**This is the drive-letter check in code.** A `FALSE` here means the volume didn't mount as `D:`.

### 7c. Spine smoke test

Expect the **one pre-existing `scripts/10_downstream_optional/` failure**. Anything *else* is an environment problem, not a pre-existing one — that distinction is the whole point of running it.

## 8. Order of operations

1. **Let H2 finish — or fail — on the laptop.** Don't unplug mid-run.
2. **Plug the drive into the workstation. Confirm it mounts as `D:`.** Force it if not (§2).
3. **Backup robocopy to `C:\backup`** (§5). Insurance.
4. **Install Claude Code + R + dependencies** (§6). ⏱️ **Timebox ~2 hours** — see §9.
5. **Checksum verify** (§7a) → expect 100/100.
6. **Spatial layers resolve** (§7b) → all 5 TRUE.
7. **Spine smoke test** (§7c) → only the known failure.
8. **Go.**

## 9. If it stalls

**Timebox step 4 to ~2 hours.** If R packages or Claude Code aren't running by then:

- Unplug, go back to the laptop (**reboot first** — that frees 8–10 GB).
- Do the workstation properly **after the presentation**.

"Test the clean environment" turning into "debug R package installs all day" is the failure mode, and four weeks out you can't afford it. **The drive is the repo — carrying it back is the rollback.**

## 10. Working split, once running

| | Runs on | Needs |
|---|---|---|
| **Design seat** (Claude chat) | **laptop** — stays convenient, works on the go | documents, small results tables, QA jsons. **No data.** |
| **Execution** (Claude Code) | **workstation** | the drive, the compute |

**The design tier never needed the hardware** — every verification this session ran on a few MB of uploaded files. The laptop loses nothing.

**On remoting:** the Claude Code **VS Code extension has known problems over Remote-SSH** (it resolves local paths against the remote workspace; the feature request is still open). The **CLI on the remote works fine**, and the desktop app has an SSH option. Given Windows → Windows, **plain RDP into the workstation and run VS Code + Claude Code natively there** is the low-risk path — it sidesteps the extension bug entirely.

Note: session history is **siloed per surface** (desktop app, CLI, VS Code extension each keep their own list). Matters less for you than most — the repo docs are the memory system.

**The drive is single-attach.** Only one machine can hold it at a time — so "chat on the laptop, code on the workstation" is the *only* split available while the drive is plugged in over there. That's fine: it's already your workflow.

---

## Acceptance

- [ ] Drive mounts as **`D:`** — `D:\Github_repos\Gayini` resolves
- [ ] Backup to `C:\backup` complete, robocopy exit < 8
- [ ] Claude Code installed, signed in, `claude --version` returns
- [ ] R + declared dependencies install cleanly ← *the environment test*
- [ ] **Checksum verify: 100/100**
- [ ] **All 5 `spatial_layer_asset` paths resolve**
- [ ] Smoke test shows **only** the pre-existing `scripts/10_downstream_optional/` failure
- [ ] Laptop untouched; drive is the rollback
