# T4 — Spine evidence workbook and claims register

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** v1 · 25 July 2026
**Depends on:** T1, T2, T3 (built last)
**Blocks:** manuscript drafting

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine §2 — **all sections**; spine §9 (durability) |
| **Claim under test** | That every number in the manuscript can be traced to a query against `Gayini_Results.sqlite` |
| **Why we are doing this** | Not ingestion convenience. The real job is that correction **C-1** does not happen three more times. A number labelled "~4,300 ha majority-green" survived in project prose, decks and conversation for weeks while meaning something ten times different from what it said, because no object anywhere mapped the claim to the query that produced it. This task builds that object. It is also the durability requirement: after this contract ends, the DB should still answer the science questions without the chats, decks or working files. |
| **What would falsify it** | Any spine claim that cannot be expressed as a query. Those are flagged, not quietly narrated around — a claim with no query behind it is either wrong, unfinished, or not actually evidence. |
| **Spine return** | Final reconciliation of spine §4 against computed values. Any mismatch is a spine revision, not a workbook footnote. |

---

## Two deliverables

### 1. `claim_register` — a DB table (the durable artefact)

```
claim_register
  claim_id          TEXT PRIMARY KEY   -- 'S3.01'
  spine_section     TEXT               -- 'S3'
  claim_text        TEXT               -- as it appears in the manuscript
  value_numeric     REAL
  value_text        TEXT
  units             TEXT
  support_level     TEXT               -- MUST be populated; see spine §3
  source_object     TEXT               -- view/table/raster it comes from
  source_query      TEXT               -- the SQL that reproduces it
  computed_date     TEXT
  status            TEXT               -- 'verified' | 'provisional' | 'blocked' | 'retired'
  caveat            TEXT               -- travels with the number, always
  supersedes        TEXT               -- claim_id of what it replaces
```

`source_query` holds **runnable SQL**, not a description of where the number came from. The test of this table is that someone can copy a query out of it, run it against the DB, and get the number back. If they cannot, the row is not finished.

`caveat` is a required field for any claim with a live limitation. The C-1 failure was partly a caveat that lived in a different document from its number.

### 2. `Gayini_spine_evidence_workbook.xlsx` — the human-readable index

One sheet per spine section, plus registers. Every sheet header states the support level. Every numeric cell that could be recomputed is written as a **live formula against a data sheet**, not as a pasted constant — same convention as `Gayini_all_pixel_census_summary.xlsx`, so the arithmetic is auditable rather than asserted.

| Sheet | Contents | Support |
|---|---|---|
| `00_README` | How to use; the support ladder; the never-merge rule | — |
| `01_S1_flood_trend` | 9/0/0 verdict by stratum; trend statistics | stratum |
| `02_S2_gradient` | Community × band flood frequency; areas on both bases | stratum |
| `03_S3_floor` | Floor vs median by flood-frequency bin; **the 2.2× ratio**; fan compression | pixel |
| `04_S4_paddock` | Per-paddock floor–flood relationship; replication evidence | paddock |
| `05_S5_reference` | Zone × stratum matched contrasts; trajectory inputs | paddock × stratum |
| `06_S6_bounds` | Limitations cross-reference (43 rows, v10) | — |
| `07_always_green` | Full threshold sweep; selected threshold flagged | pixel |
| `08_support_register` | Every figure → its support level | — |
| `09_claim_register` | Mirror of the DB table | — |
| `10_gaps` | Blocked claims and what unblocks each | — |

The workbook is a **rendering** of the DB, per spine §9 rule 1. If the two disagree, the DB is right and the workbook is stale.

---

## Gates

### Gate A — Claim extraction · **STOP**

Read the spine document and extract every quantitative claim into a draft register. For each, attempt to write the SQL that reproduces it.

Expected output is a three-way split, and **the second and third categories are the valuable ones**:

- **Reproducible** — SQL written, value matches.
- **Reproducible but mismatched** — SQL written, value differs from the spine. **Every one of these is a C-1 in progress.** Report each individually with both values; do not reconcile silently.
- **Not reproducible** — no query can produce it. Either the underlying object does not exist (flag as blocked, name what would unblock it) or the claim is narrative rather than quantitative (mark as such).

**STOP.** The mismatch list is the single most important output of this entire task. Review before proceeding.

### Gate B — Build `claim_register`

Populate the table. Every row must have `support_level` and `source_query`. Rows that cannot get a query are entered with `status = 'blocked'` and the blocker named — **they are not omitted**, because an absent row looks like a claim that was never made.

Additive `INSERT OR REPLACE` on `claim_id`. **No builder re-run.**

### Gate C — Build the workbook

Generate from live DB queries. No hardcoded values anywhere in the build script; if a number cannot be queried it does not go in the workbook.

Where a sheet reports areas, show **both** the mapped basis (67,349.3 ha) and the true-farm basis (85,910.8 ha) as separate columns. Never rebase one into the other.

### Gate D — Reconciliation · **STOP**

Produce a reconciliation report: every spine §4 row against its computed value, with a diff column. Target is diff = 0 on all reproducible claims.

Any non-zero diff is a **spine revision**, logged in the Spine Return table of the spine document — not a footnote in the workbook. The spine is the authority; the workbook reports on it.

**STOP.**

---

## Acceptance criteria

- [ ] `claim_register` populated; every row has `support_level` and either a runnable `source_query` or `status = 'blocked'` with a named blocker.
- [ ] Every `source_query` executes against the DB and returns its stated value. **Test this mechanically — do not eyeball it.**
- [ ] Workbook builds from live queries with zero hardcoded values.
- [ ] Both area bases present wherever areas are reported.
- [ ] Support level stated in every sheet header.
- [ ] Reconciliation report produced; all diffs either zero or logged as spine revisions.
- [ ] Re-run produces an identical workbook.
- [ ] No existing table or view modified or dropped.
- [ ] Change report in `docs/change_reports/`, committed.

## Standing rules

Additive only · no builder re-run · paths from DB · the DB is the authority, the workbook is a rendering · branch and PR with human review · no AI attribution in commits.
