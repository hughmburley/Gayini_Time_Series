# PACK-1 — Assemble the delivery pack by copy from manifest

**Owner:** RS / CC · **Effort:** 3 h · **Target:** 3 Aug · **Depends on:** AUD-1 v2 (manifest)
**Blocks:** QA-2b (5 Aug), the 10 August delivery
**Type:** ASSEMBLY BY COPY. Source files are never moved, renamed in place, edited or re-registered.
**Re-read this spec in full and echo it verbatim at the start of every gate.**

---

## Why by copy, and why this matters

The pack is a **derived artefact**, rebuilt from a manifest in minutes, not a folder that work migrates into.

`write_and_register_figure()` writes to its script-configured path and registers in one transaction. Between now and 10 August there will be re-renders — DECK-1 v4, QA-2b fixes, the REP-5 batch of 60 paddock reports. **Moving files does not move the renderers.** Every re-render after a migration would land back at the old path, register there, and the "delivery" folder would go quietly stale while looking complete. That failure is invisible: the file is present, it is simply not the current one.

Copy-from-manifest avoids it entirely. Source paths stay valid, the registries stay true, renderers keep working, and assembly can be re-run on the morning of the tenth so the pack is current **by construction** rather than by vigilance.

The pattern already exists in the repo: `build_review_bundle.py` is manifest-driven. Follow it.

---

## Gate 0 — Inputs · **STOP**

Confirm on disk, do not assume:

- `Output/audit/AUD1_pack_manifest_draft.csv` exists, with `ship_flag` populated on every row.
- `Gayini_deliverables_register.md` **v2 or later** — the source of truth for item IDs, titles, claims and captions.
- Every `SHIP` row's `source_path` exists and its SHA-256 matches the manifest value.

**Stop and report if:** any `SHIP` row has a checksum mismatch (the file changed after the audit), any row still reads `DECIDE` (the design seat has not ruled), or the manifest's audit window overlaps another writing session and `concurrent_write = Y` rows remain unresolved.

Do not work around a missing input. List it and stop.

---

## Gate A — Resolve the manifest

Produce `Output/pack/manifest_resolved.csv` — the manifest with design-seat decisions applied.

- `DECIDE` rows must arrive resolved to SHIP or HOLD **by the design seat**, recorded in the row with who decided and why. CC does not resolve them.
- **HOLD rows are carried into the manifest with their reason, not deleted.** A dropped item must be visibly dropped; an item that silently vanishes cannot be noticed missing.
- Every SHIP row must carry `pack_item_id`, `item_title` and `claims_served` from register v2.

### Two decisions that must be explicit before assembly

**M3 — the persistence map.** Register v2 marks it SPECIFIED, needing the T7 recolour; T7 is the tracker's first task to drop and its stated purpose depends on spec T3, never built. The register already states the fallback: *if M3 does not land, the pack ships with seventeen items and loses nothing a Nari Nari reader depends on.* Either M3 ships with a real file or M3 is removed from the contents listing. **Shipping a pack whose own contents page says SPECIFIED or REBUILD PENDING is not an option** — it advertises an incomplete deliverable.

**Category H — internal apparatus.** Register v2 §5 lists what exists to make the numbers trustworthy and must not be presented: `dim_headline_number`, the reproduction test, the denominators and dominance counts, ddof conventions, `is_rollup`, the six pin decisions, the render guards. **No H artefact enters the pack**, even as an appendix. If Adrian asks how we know the numbers are right, the answer is the register's one sentence, not a folder of scaffolding.

---

## Gate B — Assemble by copy

Build into `Output/pack/Gayini_RS_pack_YYYYMMDD/`, a **new dated directory each run**. Never assemble into a directory that already has contents.

```
Gayini_RS_pack_20260803/
  00_START_HERE.md
  01_maps/          M1 … M5b
  02_figures/       F1 … F7
  03_tables/        T1 … T3
  04_documents/     methods and questions, if shipping
  _manifest.csv     what is here, where each file came from, checksums
```

Rules:

1. **Copy, never move.** Source files remain in place, untouched.
2. Rename on copy to `{pack_item_id}_{descriptive_name}.{ext}` — `M5b_paddock_residual_from_expectation.png`. The pack is read by someone who does not know the internal naming.
3. **Re-verify SHA-256 after copy** against the source. Record both in `_manifest.csv`.
4. **Do not re-render, re-export, downsample, crop or convert anything.** If a file is the wrong format or size, that is a defect for the design seat, not something to fix silently during assembly.
5. Write `_manifest.csv` with: `pack_item_id`, `packaged_filename`, `source_path`, `sha256_source`, `sha256_packaged`, `registered`, `register_status`, `claims_served`, `assembled_utc`.
6. **No registry writes.** The pack is a copy; it is not a new registered object.

---

## Gate C — The contents document

Generate `00_START_HERE.md` **from register v2**, not from the stale `Gayini_Adrian_pack_contents.xlsx`.

Structure, following the register's own architecture:

1. **What this is** — one paragraph.
2. **The through-line** — the numbered claims from register v2 §1, verbatim. This is the story vehicle; it does the work no folder structure can.
3. **What we cannot say** — register v2's paragraph on the water-regime question, verbatim. It is not a caveat to be softened; it is the honest answer to the question the managers most care about.
4. **The items** — one row per shipped item: ID, title, filename, the claim it supports, and its caption from register v2.
5. **Two things that need care when explaining** — the two "floors" and standard-deviations-within-community, from register v2 §4, verbatim.

Three hard requirements:

- **The date field must be filled.** The stale workbook shipped `Date | __ August 2026`. An unfilled placeholder in the first cell of a client folder is the kind of defect that costs more credibility than any analytical caveat.
- **Every shipped item appears; no unshipped item appears.** The contents document describes the folder it sits in, not a plan.
- **Never the bare word "floor"** in any client-facing text. Register v2 §4 and report handoff §7.4 both require plain-language descriptions — "the poorest patches" or "the worst years". Two different measurements share that name and are not comparable.

Also verify and correct in passing: register v2 §1 announces six sentences and lists seven. Whichever is right, the shipped text must be internally consistent.

---

## Gate D — Verification · **STOP**

Emit `Output/pack/PACK1_verification.md`:

1. Item count shipped, against register v2's stated count, with the difference explained.
2. Checksum table — source versus packaged, every row. Any mismatch is a hard stop.
3. HOLD list with reasons — what did not ship and why.
4. Every shipped item has a caption in `00_START_HERE.md`: yes/no per item.
5. Confirmation that no category H artefact is present.
6. Confirmation that no source file was moved, modified or re-registered — verified by comparing source checksums against the AUD-1 manifest.

**STOP.** The pack passes to QA-2b only after this report is reviewed.

---

## Re-run before delivery

Assembly is repeatable and **must be re-run on 10 August before anything leaves**, into a fresh dated directory.

The re-run's job is to catch divergence: if any source file changed after the 3 August assembly, its checksum will differ and the re-run reports it. That is the whole reason for copy-plus-checksum rather than migration — a migrated folder has nothing to compare against and cannot tell you it has gone stale.

Deliver the newest dated pack directory. Keep the earlier ones; they are the record of what was assembled when.

---

## Acceptance criteria

- [ ] Every manifest row resolved to SHIP or HOLD; no `DECIDE` remains
- [ ] Every SHIP row present in the pack, correctly renamed
- [ ] Source and packaged checksums match on every row
- [ ] `_manifest.csv` complete
- [ ] `00_START_HERE.md` generated from register v2, date filled, every shipped item captioned
- [ ] No item in the contents document that is absent from the folder, and none absent that is present
- [ ] The bare word "floor" appears nowhere in client-facing text
- [ ] No category H artefact present
- [ ] M3 either ships with a real file or is absent from the contents listing — no "pending" status visible to a client
- [ ] **No source file moved, modified, re-rendered or re-registered**
- [ ] Re-run into a fresh directory produces an identical pack apart from timestamps

---

## Standing rules

Copy only, never move · no registry writes · **never re-run the builder** · paths resolved from the manifest and the DB, never hardcoded · rasters and large spatial data never committed · change report to `docs/change_reports/` · branch and PR, the human merges · commits authored by Hugh, no AI attribution trailers.

## Identifiers

**PACK-1**, in the tracker namespace. Never use a bare `T`-number in outputs: qualify as `pack item T1`, `figure prefix T1_`, or `spec T1`.
