# REPORTS — R-12 · register of the composition sentence

**Session:** report batch, third concurrent seat · **Date:** 5 August 2026
**Builder:** v1.6 → **v1.7** · **DB read-only.** No write attempted.
**Not shipped. Not re-fingerprinted — see §3.**

```
lint_builder.py        0 error · 0 warn                        exit 0
check_scope_claims.py  clean across 89                         exit 0
check_page_fill.py     343 pages · 0 above 92% · 124 below 70%  exit 0
tests/                 12 assertions · 4 files · 0 fail         exit 0
```

---

## 1. (a) and (b) adopted, (c) declined as ruled

One sentence, **37 of 64** documents — every multi-community paddock. The 27
single-community reports do not carry it.

```
Bala 28ca   spans two kinds of country — 83% Inland Floodplain and 17% Riverine.
Bala 29ca   spans three kinds of country — 35% Inland Floodplain, 33% Riverine and 32% Aeolian.
Bala 8/11   spans two kinds of country — over 99% Inland Floodplain and under 1% Riverine.
Dinan 4     spans three kinds of country — 62% Inland Floodplain, 37% Riverine and 1% Aeolian.
```

The three-community case is the one that shows why (b) was right: `35% Inland Floodplain,
33% Riverine and 32% Aeolian` is a sentence. The middot version was a header fragment sitting
inside prose.

`short` is retained everywhere, per (c).

## 2. The check had to move with the wording

`check_scope_claims.py` matched `spans (\d+) kinds`. Under R-12(a) that pattern stops matching,
and the failure mode is the bad one: the check would not have *failed*, it would have found no
sentence at all and fallen silent on 37 documents. It now accepts **both** forms and maps the
word back to a number, so a regression to numerals is caught rather than quietly tolerated, and
an unparseable count is itself reported. The `r8_count` and `r8_zero_pct` fixture anchors moved
with it; all six scope cases still fire.

That is the same shape as the `.flags` sidecar and the `~$` lock file: a check that stops
applying without stopping.

## 3. R-9 and R-11 have not reached me — nothing re-fingerprinted

The ruling batches this diff "with R-9 and R-11". **I have never received either.** What I hold
is R-1 to R-8, and now R-12.

So the code change is committed and verified, and **no re-fingerprint has been taken.** The
batch is 89 documents, still unshipped, still carrying the original-32 manifest as its only
tripwire. When R-9 and R-11 arrive I will apply them and re-fingerprint once, as intended.

Against that original-32 manifest the build now reads **26 match · 6 changed**, and the six are
accounted for exactly:

| document | why |
|---|---|
| Bala 26ca, Bala 28ca, Bala 29ca, Dinan 10, Dinan 8 | R-12 — multi-community, so they carry the sentence |
| Bala 15 | R-8 — single-community with a trace clause |

Bala 27ca is single-community with no trace and is unchanged; all 25 site reports are unchanged.

## 4. Outstanding

- **R-9 and R-11** — not received.
- Re-fingerprint at 89, once those land.
- The 12-unit sample read (R-7 step 5) — unchanged, and now also carries R-8 and R-12 wording.
- Per-paddock output folders — still queued, still not started.
- Scope-lock string from `RPTSCOPE_number_contract.csv`; methods document; figure registration.
