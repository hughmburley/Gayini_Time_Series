# Gayini — status change, 11 August 2026

**Purpose:** a single note to relay into the other analysis threads (design seats, CC, report
stream) so they are working from the same picture. The project's funding and publication
position changed materially between 7 and 11 August. The science did not.

**Read this before issuing any further build instruction.** Several standing task specs are
now out of scope.

---

## 1. What changed, in five lines

1. **The Gayini analysis is complete as a funded engagement.** Adrian considers it to have run
   its course. No further budget from him for Gayini work.
2. **All Gayini work from here is unpaid** until the Western NSW LiDAR processing engagement
   begins — a few weeks away, and separately funded.
3. **The 10 August presentation landed well.** BCT, NNTC and Kathy were positive; Richard's
   stated priority was demonstrating delivery, and that was achieved.
4. **The forward route runs through Richard Kingsford and his PhD student**, who is working on
   closely related ground. A clean handover is the live task.
5. **No new money is on the table.** Any further Gayini funding would come via a
   Kingsford–Fisher discussion we are not party to.

---

## 2. Provenance discipline on the Kingsford email

The email of 11 August is short and warm. **Quotable content:** thanks for the workshop; BCT,
NNTC and Kathy were impressed; it builds on the Gayini platform; there are things to discuss
about the outcomes BCT wants and how that is managed; the team convinced BCT it is delivering,
which he names as the most important thing; a catch-up will be organised.

**Not in the email, and must not be attributed to it:**

- Any statement about a "big insights" paper. That reading comes from the meeting and from
  Adrian's relay, not from this text. Record it against its actual source.
- Any statement about funding, in either direction. The email is silent on money.
- Any reference to the remote-sensing thread specifically, or to any individual contributor.

**What can reasonably be inferred, flagged as inference:** no new money is signalled; the line
about outcomes BCT wants and how it is managed is consistent with the UNSW–BCT scope tension
already noted; the absence of any forward commitment is information, but weak information — this
is a thank-you note, not a decision.

*Per I-43: a ruling is only a ruling if it can be quoted. Applies to client email as much as to
design-seat messages.*

---

## 3. Consequences by thread

| Thread | Status | Action |
|---|---|---|
| **Funded Gayini analysis** | Closed | No new build tasks. Nothing that changes a number |
| **Publication (S1)** | Downgraded, not dead | See §4 |
| **S2 scaling** | Parked indefinitely | Was always post-S1. No sponsor, no funding |
| **S3 biodiversity / model validation** | Parked, still the best independent option | Blocked on plot data and ICIP, not on hours. Costs nothing to leave open |
| **Handover to the Kingsford student** | **The live task** | Capped scope, §5 |
| **Gayini Data Hub** | Contribution route exists | Adrian controls what goes in, deliberately. Offer, do not push |
| **LiDAR Western NSW** | Next paid work | Prepare for it. Not Gayini |
| **TRACE-1 / RETRO-1** | Out of scope | Specs written, but these are funded-project hygiene. Do not run unpaid |
| **Pack v1.3, QA2, REPORT2, remaining CC specs** | Out of scope | Same reasoning |

---

## 4. On the paper

The realistic position: **a "big insights" paper is not coming out of this quickly, and probably
not out of the Gayini result alone.** Reasons, stated plainly:

- The result is cross-sectional and correlational, with no post-management drought to test
  against — the four post-cut water years are unusually wet (mean inundation 43.6% against 22.8%
  before, including the wettest year in the record).
- Adrian is sceptical that a robust statistical model of the inundation–cover relationship is
  achievable given management and ENSO confounding, and that scepticism is not unreasonable.
- Manuscript work would be unpaid, on evenings, without institutional backing.

**What remains true and worth preserving:** the metric claim — that the flood signal lives in the
cover floor rather than the mean — is the genuinely transferable contribution, it replicates four
ways, and it aligns with how national ground-cover reporting already works. That does not expire
because this engagement ended. It can be published later, from a stronger position, possibly with
a second site.

**Recommendation:** do not attempt the manuscript now. Preserve the ability to write it — which is
what the handover documentation does anyway — and revisit if the LiDAR work or a Kingsford
engagement provides a platform.

---

## 5. Standing instruction — the handover, and its cap

**Scope: two to three days total, spread over a fortnight, then stop regardless of state.**
Write the cap down; unpaid scope drifts.

**In scope:**

- **Handover document for a stranger.** The traps that silently produce wrong numbers:
  two-metric prohibition; percentiles do not subtract; the uint8 nodata trap; `MIN_SEASONS = 50`
  doing two jobs, including stopping the product inventing cover over the lake; mapped 67,349 ha
  vs true farm 85,911 ha; inundation frequency (between-year) vs within-year wet extent;
  circularity between cover and CSIRO condition.
- **README:** clone to running pipeline. What the data is, where it comes from, run order.
- **Attribution:** authorship, date, citation line, and a plain statement of what is reusable
  and on what terms.

**Out of scope:**

- Full reproducibility hardening. Worth 25% of a funded budget; not worth unpaid weeks.
- The portable / config-driven pipeline. This is the commercial asset and the last thing to
  build for free.
- Any new analysis, figure, or registered number.
- Anything not directly usable by the student.

**Route:** through Adrian, not directly to the student. He is the contact and the work was done
under his budget.

---

## 6. What has NOT changed

The scientific record stands. Nothing in this note revises a finding.

- Inundation frequency raises the lower tail of ground cover rather than its typical level.
  Census p05 40.5 → 77.1% against p50 73.1 → 89.7%; fan compresses 32.6 → 12.6 pp.
- Replicates at pixel, part, paddock and unzoned grains; 100% of 93 unzoned patches slope
  positive; held-out unzoned country entered no fit.
- Between-unit and within-unit slopes answer different questions and are not two estimates of
  one number.
- No directional trend in inundation across 9 of 9 non-treed strata. Ratified.
- CSIRO condition is near-binary, uncorrelated with inundation, and runs opposite the flood
  gradient.
- All analytical prohibitions remain in force — two-metric, five-qualifier, additive-only.

---

## 7. Open questions

- **Reuse and IP terms, in writing.** More urgent now, not less: the pipeline is about to be
  handed to a PhD student at the funding institution. Ask while doing them a favour
- **Is the paper happening at all, and if so unpaid?** Determines whether evening work has a target
- **Has the Gayini remote-sensing PhD position been filled, and by this student?**
- **Data Hub:** what would Adrian actually want contributed, and on what terms
- **SAM proposal (05/2026–05/2029):** is there a role. Ask before December
- **LiDAR engagement:** start date, scope, rate

---

## 8. Superseded

- `Gayini_remaining_budget_and_forward_pitch_20260810.md` — §§2–7 (the $20k allocation) are
  **void**; the budget does not exist. §8 (IP and ICIP) and §9 (forward pitch) **stand and are
  more relevant now, not less.**
- `Gayini_three_candidate_studies_20260810.xlsx` — S1–S3 remain scientifically sound. All
  timelines, effort estimates and sequencing assumed a funded window and are void.

---

*Compiled 11 August 2026. Proposal and status only — nothing registered, no number revised.*
