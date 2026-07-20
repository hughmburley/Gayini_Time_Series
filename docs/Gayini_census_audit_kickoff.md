# Census Audit — chat kickoff

*Paste the section below into a NEW chat. Read the two notes first — they change what you upload and set the guardrails.*

---

## Before you paste: upload the right files

An audit is only as good as what it audits against. **The project currently has the wrong versions of several spine files** (checked 17 Jul):

| File | Project state | Action |
|---|---|---|
| `Gayini_established_data_facts.md` | ✅ current (16 Jul) | fine |
| `Gayini_output_structure.md` | ✅ | fine |
| `Tier2_TaskH_all_pixel_census.md` | 🔴 **v1 "first cut"** — predates every decision | **replace with v4**, or upload v4 to the chat |
| `Gayini_pixel_census_data_contract.md` | ✗ missing | upload |
| `taskI_deck_stocktake_20260717.md` | ✗ missing — **this IS the figure audit** | upload |
| `tier2H_gate1_verified_20260715.md` | ✗ missing | upload |
| `Gayini_Results.gpkg` (in project) | 🔴 **corrupt sidebar copy** | ignore it |
| `Gayini_Results.sqlite` | ✗ missing | **upload the sound copy** — the audit needs it |
| all `tier2H_*.csv` result tables | ✗ none | **upload** — these are the evidence claims trace to |

**The audit cannot run without the sqlite and the result tables.** Everything else it can reason about from the docs, but reconciliation needs the actual numbers.

## The guardrail: this chat REVIEWS, it does not BUILD

The census is **complete and on `main`.** This chat exists to confirm the spine hangs together as one object — not to extend it, not to rebuild figures, not to re-open settled decisions.

**Two hard stops:**
1. **No figure rebuilds.** Several presentation figures do need census versions (the stocktake lists them) — but that is **Task J, and it is gated on Adrian's answers to the bundle.** Three of his four questions decide what those figures *are*. Rebuilding now is guaranteed rework. The audit's job on figures is to **confirm the gap is captured**, not to close it.
2. **`Gayini_established_data_facts.md` §10 is settled.** If the audit thinks a §10 answer is wrong, that's a finding to report — not a licence to re-litigate it.

**The chat ends** when it produces one of: *"spine reconciles end-to-end, every headline backed by a committed table"* — or a defect list. It is not a standing chat. When the question is answered, it closes.

---

## Paste into the new chat

> New chat: **audit of the all-pixel census — the project spine.** You're in the design-and-review seat; any execution is a separate fresh Claude Code session.
>
> **The census is complete and merged to `main`** (Task H: Track A + Track B; commit `51aeaa3`; smoke test 99 pass). This chat does **not** build or extend it. It answers one question and then closes:
>
> **Does the census spine reconcile end-to-end, and is every published headline backed by a committed table?**
>
> Green light, or a defect list. Nothing else.
>
> **Read first — do not re-derive:** `Gayini_established_data_facts.md` (the measured-facts reference — **§10 is a settled table, do not re-open it**), the Task H spec **v4** (not the "first cut" — that's superseded), the pixel census data contract, and the Task I deck stocktake.
>
> **Two hard stops:**
> - **No figure rebuilds.** Presentation figures that still show sampled/40-plot data (the stocktake lists them: F2, F3, F4, F6, the sampling overlays) are **Task J, gated on Adrian's bundle answers.** Confirm the gap is captured; do not close it.
> - **Settled decisions stay settled** (§10): 9/0/0, option-2 bands, parquet store, plot-vs-pixel support, `MIN_SEASONS=50`. A disagreement is a *finding*, not a re-open.
>
> **The audit — four checks, report and stop:**
>
> **1. Does the spine reconcile to itself?** The census exists as a parquet, a DB table, a set of rasters, and a facts doc. Confirm they still agree now they're all on `main` together:
> - `gayini_pixel_census_8058.parquet` → **1,080,157 rows**, `diff = 0` against `census_stratum` for all 11 strata *(this is the real independent-path check, not the vacuous `veg_regime_class` one)*
> - parquet community means → **6.08 / 12.91 / 27.99** (facts §9)
> - `flood_zone` cross-tab → facts §9 within **0.05 pp**
> - `valid_years == 35` for every focus row; monotone `p05 ≤ … ≤ p50`
>
> **2. Is every headline backed by a committed table?** For each, trace to a file **on `main`**, not a prose sentence in a json:
> - **F6 = 9/0/0** → `12_run_census_trend_test.R` output + the F6 verdict tables
> - **54.1% false-positive** → `tier2H_h32_sample_power_1000draws.csv` *(this one was prose-only until it was caught — confirm it's now committed at `Output/tables/`)*
> - **per-year 0.04% → 84.7%** → the per-year cut table
> - **floor is 97% dead / ~4,300 ha green** → the paired PV table
> - **the staircase, absolute zones** → the flood-zone crosstab
> - Flag any headline whose evidence is prose-only or gitignored. That's the C9 pattern; it has recurred twice.
>
> **3. Is the figure-tracking state captured?** From the Output census: **330 current analytical figures, 0 registered**; the registry tracks 139 superseded MODIS/MER figures. Confirm this is (a) true and (b) already captured as a task (it's Task K, the restructure). Do not fix it here — just confirm it isn't lost.
>
> **4. Are the right files where they should be?** The spine docs (facts, contract, specs, stocktake) are **untracked, on the working drive only** — a fresh clone has none of them. Confirm that's the *known, accepted* state (evidence + gating inputs tracked; reference docs drive-only) and not an accident. If any *evidence* table is drive-only rather than committed, that's a defect (check #2 catches it).
>
> **Verify against the data, not the reports** — three prose claims were wrong across Task H and every one was caught by reading a table. Where you assert a reconciliation, show the number.
>
> **Deliverable:** a one-page audit verdict — reconciles ✓/✗ per check, a defect list if any, and an explicit **"spine is sound, safe to build site reports and Task J on top"** or **"these N defects block."** Then the chat is done.

---

## Why this scope and not more

The census ran across ~15 exchanges and was verified gate-by-gate, in pieces, by the design seat. **Nobody has asked "does the whole thing hang together" in one pass** now that it's all merged. That's the gap this fills — and it matters because site reports, pre/post, and Task J all consume the census. One audited source beats three chats re-deriving.

But it is a **review, not a residence.** The census is finished. The risk of a "dedicated spine chat" is that it becomes a place to keep polishing something that's done — the exact circularity flagged earlier. Four checks, a verdict, close.
