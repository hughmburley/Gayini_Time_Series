"""Re-run the two DOC-1 audit classes against the BUILT documents (handoff §8.4).

Why this exists rather than a read-through. §8.4 asserts *"Checked 4 Aug: no such construction
in the batch"* and *"Checked 4 Aug: band areas reconcile to the stated in-scope area to 0.0 ha
in all seven paddocks"*. Those checks were made in a sandbox, against a database snapshot, by
the seat that wrote the claim — and a claim of that kind should not survive a seat change on
its own authority. Gate 0 recorded them as outstanding, not done. This makes them repeatable.

The two classes, both from DOC-1 Gate B/C:

  C10 · never pair a numerator at one support with a denominator at another. Plot support is
        the site figures and the site table (v_plot_year_analysis_spine); pixel support is
        every paddock headline (fact_zone_veg_annual, v_census_by_zone_stratum). DOC-1 §7.3
        said "six of the eight measurable strata" — six being the plot count and eight the
        census count.

  FOOTPRINT · an area or a share must name the footprint it is over. DOC-1's 3.03% green share
        is over 86,385 ha (farm boundary, native 30 m, treed included) while persistence areas
        in the same paragraph are over 61,655 ha non-treed — one paragraph, two denominators,
        neither stated. In these reports "the property" must denote a COUNTABLE SET (the 64
        paddocks, the 57 non-treed sites), never an area.

What this does NOT do: it cannot read meaning. It checks constructions that are mechanically
detectable and reconciles the numbers that can be reconciled. A clean run is evidence, not
proof — the same status §8.4's own claim should have had.

Run:  python check_scope_claims.py        (from scripts/15_reports)
"""
import glob, json, os, re, sys, zipfile
import pandas as pd
from config import DOCS_DIR, UNITS_DIR, TABLES
from docxset import built_docx

TOL_HA = 0.05          # band areas are printed to 0 dp; reconcile the underlying values
findings = []


def _ordinal(n):
    return f'{n}{"th" if 10 <= n % 100 <= 20 else {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")}'


def water_label(n, of):
    """REPORT-2 §3.2's pre-registered vocabulary, transcribed from the spec.

    Deliberately a SECOND implementation of waterPhrase(), not a shared one: a check that
    imports the thing it checks tests only that the code ran. Transcribed from the ruling, so
    a drift in either implementation shows up as a mismatch here."""
    p = n / of
    if n == 1:
        return f'lowest of {of} for its water'
    if n == 2:
        return f'second-lowest of {of} for its water'
    if p <= 0.10:
        return f'among the lowest of {of} for its water'
    if p <= 0.25:
        return f'low for its water — {_ordinal(n)} of {of}'
    if p <= 0.75:
        return f'about what its water predicts — {_ordinal(n)} of {of}'
    if p <= 0.90:
        return f'high for its water — {_ordinal(n)} of {of}'
    return f'among the highest of {of} for its water'


def add(level, check, where, msg):
    findings.append((level, check, where, msg))


CELL_END = '‖'      # sentinel: a table-cell or paragraph boundary


def visible(path):
    """Extract text, PRESERVING cell and paragraph boundaries.

    A flat strip makes adjacent table cells look like one sentence. The first version of this
    checker did exactly that and reported Bala 29ca's parts table as a footprint defect: the
    Area cell ("739 ha") and the comparison cell ("lowest of 17 on the property") are different
    columns, and "17 on the property" is a countable set — correct usage. Matching across a
    boundary that is not a boundary in the source is I-47's shape at one remove, so the fix is
    to give the extractor the boundary, not to loosen the rule.
    """
    x = zipfile.ZipFile(path).read('word/document.xml').decode('utf8', 'replace')
    x = re.sub(r'</w:(?:tc|p)>', CELL_END, x)
    t = re.sub(r'<[^>]+>', ' ', x)
    return re.sub(r'[ \t]+', ' ', t).replace('&apos;', "'").strip()


def sentences(t):
    """Sentence boundaries AND cell/paragraph boundaries both end a claim."""
    return [s.strip() for s in re.split(r'(?<=[.;]) |' + CELL_END, t) if s.strip()]


# ---------------------------------------------------------------- A. band areas reconcile
def check_band_areas():
    """§8.4's own claim, re-derived: band areas must sum to the stated in-scope area."""
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        tot = sum(b['ha'] for b in r['bands'])
        d = abs(tot - r['area_ha'])
        if d > TOL_HA:
            add('ERROR', 'footprint', r['unit'],
                f'band areas sum to {tot:.3f} ha but area_ha is {r["area_ha"]:.3f} '
                f'(difference {d:.3f} ha)')
        else:
            print(f'  band areas reconcile  {r["unit"]:11s} '
                  f'{tot:10.3f} ha vs {r["area_ha"]:10.3f} ha   diff {d:.4f}')


# ---------------------------------------------------------------- B. "the property" is a set
AREA_NEAR_PROPERTY = re.compile(
    r'(?:the property[^.]{0,60}?\d[\d,]*\s*ha\b|\d[\d,]*\s*ha\b[^.]{0,40}?the property)', re.I)


def check_property_is_a_set():
    for p in built_docx(DOCS_DIR):
        for s in sentences(visible(p)):
            if AREA_NEAR_PROPERTY.search(s):
                add('ERROR', 'footprint', os.path.basename(p),
                    f'"the property" used with an area: {s[:160]}')


# ---------------------------------------------------------------- C. supports stay separated
TWO_RULES = 'will not match'
# a paddock-support flood figure and a site-support one in the SAME sentence
PADDOCK_FF = re.compile(r'floods in \d[\d.]*% of years|under water in \d[\d.]*% of years', re.I)
SITE_FF    = re.compile(r'saw water in \d[\d.]*% of years|site (?:floods|flooded) in \d', re.I)


def check_support_separation():
    docs = built_docx(DOCS_DIR)
    missing = []
    for p in docs:
        t = visible(p)
        if TWO_RULES not in t:
            missing.append(os.path.basename(p))
        for s in sentences(t):
            if PADDOCK_FF.search(s) and SITE_FF.search(s):
                add('ERROR', 'C10', os.path.basename(p),
                    f'paddock-support and site-support flood figures in one sentence: {s[:160]}')
    if missing:
        add('ERROR', 'C10', f'{len(missing)} document(s)',
            'the "two flood rules differ" sentence is absent — the spec requires it in every '
            f'report: {", ".join(missing[:4])}')
    else:
        print(f'  two-flood-rules sentence present in all {len(docs)} documents')


# ---------------------------------------------------------------- D. site counts are counts
def check_site_counts():
    """"N of the property's monitoring sites" — N must be this paddock's reported site count,
    and the denominator must be the SITE NETWORK, never a pixel or area total."""
    pat = re.compile(r"(\d+) of the property's monitoring sites")
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        for m in pat.finditer(visible(p)):
            if int(m.group(1)) != r['n_sites']:
                add('ERROR', 'C10', r['unit'],
                    f'document says {m.group(1)} sites, unit record has n_sites={r["n_sites"]}')


# ---------------------------------------------------------------- E. R-8 composition prose
# R-12(a): the count is a word, not a numeral. Both forms are matched so the check catches a
# regression to numerals rather than silently failing to find the sentence at all.
NUMWORD = {w: i for i, w in enumerate(
    ['no', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten'])}
SPANS = re.compile(r'spans (\d+|[a-z]+) kinds of country')


def spans_count(m):
    """The N in 'spans N kinds', word or numeral. None if unparseable — which is itself a
    finding, not something to swallow."""
    tok = m.group(1)
    return int(tok) if tok.isdigit() else NUMWORD.get(tok)
ENTIRELY = re.compile(r'\bis entirely\b')
ZERO_PCT = re.compile(r'\b0% [A-Z]')


def check_composition_prose():
    """R-8: page 1 must count the parts page 3 will show, not the census communities.

    Enforced against the DOCUMENT, not the unit record, because the claim is about what the
    reader sees. A percentage that rounds to 0 and the word "entirely" over a trace are the
    two ways the old sentence was wrong; both are checked."""
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        t = visible(p)
        n_parts = len(r['parts'])
        trace = r.get('trace_communities', [])

        m = SPANS.search(t)
        if m and spans_count(m) is None:
            add('ERROR', 'R-8', r['unit'],
                f'"spans {m.group(1)} kinds of country" — count not parseable as a number')
        elif m and spans_count(m) != n_parts:
            add('ERROR', 'R-8', r['unit'],
                f'page 1 says {m.group(1)} kinds of country, {n_parts} classified part(s)')
        if not m and n_parts > 1:
            add('ERROR', 'R-8', r['unit'],
                f'{n_parts} parts but no "spans N kinds" sentence')
        if ZERO_PCT.search(t):
            add('ERROR', 'R-8', r['unit'],
                f'a community printed at 0%: {ZERO_PCT.search(t).group(0)}')
        if trace and ENTIRELY.search(t):
            add('ERROR', 'R-8', r['unit'],
                f'"is entirely" used while a trace community exists '
                f'({", ".join(c["short"] for c in trace)})')
        if trace and 'to report on separately' not in t:
            add('ERROR', 'R-8', r['unit'],
                'a trace community exists but is not named in a trailing clause')


# ---------------------------------------------------------------- G. R-15 parts verdict
# The old sentence compared COUNTS — "is the number of recovering parts the same as the number
# of bare ones?" — and then said "they are coming back", attributing recovery to the bare parts.
# On Dinan 10 the bare parts are Aeolian and Inland Floodplain, both Persistently poor; the one
# recovering part is Riverine at rank 6 of 37. So the check is on SET membership, computed from
# the unit record and tested against what the document says.
OF_THEM = re.compile(r'most bare country[^.]*?—\s*and\s+(?:they are|[a-z]+ of (?:them|those) (?:is|are))\s+coming back')
BAD_VERB = re.compile(r'\b(?:one|two|three) of (?:them|those) are coming back'
                      r'|\b(?:two|three)[^.]{0,60}\bsits close to the boundary'
                      r'|\bone\b[^.]{0,60}\bsit close to the boundary')


def check_parts_verdict():
    """R-15: the sentence must not attribute recovery to parts that are not recovering."""
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        if len(r['parts']) < 2:
            continue
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        t = visible(p)
        low = {x['short'] for x in r['parts'] if x['rank'] <= 2}
        rec = {x['short'] for x in r['parts'] if x['state'] == 'Recovering'}

        # the "and they/N of them are coming back" clause may only appear when the recovering
        # parts really are among the bare ones
        if OF_THEM.search(t) and not (rec and low and rec <= low):
            add('ERROR', 'R-15', r['unit'],
                f'the bare-parts sentence claims recovery among them, but bare={sorted(low)} '
                f'and recovering={sorted(rec)}')
        if BAD_VERB.search(t):
            add('ERROR', 'R-15', r['unit'],
                f'verb does not agree with its subject: '
                f'"{BAD_VERB.search(t).group(0)[:70]}"')
        # recovery outside the bare set must carry its area, or a reader scales 7% to 100%
        outside = [x for x in r['parts']
                   if x['state'] == 'Recovering' and x['short'] not in low]
        if low and outside and 'of the paddock' not in t:
            add('ERROR', 'R-15', r['unit'],
                f'{", ".join(x["short"] for x in outside)} is recovering outside the bare set '
                f'but the share of the paddock is not stated')


# ---------------------------------------------------------------- H. R-16 gap caption
DIR_WORD = {'closing': 'narrowed', 'widening': 'widened',
            'neither': 'neither narrowed nor widened'}


def check_gap_caption():
    """R-16: the gap figure must not assert a pattern the paddock does not have.

    The title used to read "Closing the gap, year by year" for all 64 — wrong for 45 of them,
    and live in two shipped documents. The pattern now lives in the caption and is derived, so
    the check is that the caption's direction matches the unit record, that the slope and the
    correlation are both given (the project's standing rule for describing a trend), and that a
    caption never describes a trend line the figure did not draw."""
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        if 'gap_direction' not in r:
            continue
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        t = visible(p)
        m = re.search(r'One point per water year[^‖]*', t)
        if not m:
            add('ERROR', 'R-16', r['unit'], 'the gap caption is missing')
            continue
        capt = m.group(0)

        want = DIR_WORD[r['gap_direction']]
        if r['gap_line_drawn']:
            if want not in capt:
                add('ERROR', 'R-16', r['unit'],
                    f'caption does not say "{want}" for a {r["gap_direction"]} gap')
            if 'no trend line is drawn' in capt:
                add('ERROR', 'R-16', r['unit'],
                    'caption says no trend line is drawn, but the figure drew one')
        else:
            if 'no trend line is drawn' not in capt:
                add('ERROR', 'R-16', r['unit'],
                    f'|r| = {abs(r["gap_r_derived"]):.2f} is below the cut so no line is drawn, '
                    f'but the caption does not say so')
            # Match the ASSERTION, not the bare word. A first version tested `'narrowed' in capt
            # and 'neither' not in capt`, and the no-line caption contains "neither gained ...
            # nor fell behind" in an unrelated clause — so the guard suppressed the very finding
            # the check exists for, and the fixture passed. Same shape as I-47: a fragment match
            # colliding with text that is not the claim.
            for phrase in ('the difference narrowed', 'the difference widened'):
                if phrase in capt:
                    add('ERROR', 'R-16', r['unit'],
                        f'caption asserts "{phrase}" where no trend line is drawn')
        if 'correlation' not in capt:
            add('ERROR', 'R-16', r['unit'],
                'a described trend must give its correlation as well as its slope')
        if 'points a year' not in capt:
            add('ERROR', 'R-16', r['unit'], 'the caption does not give the slope')


def check_water_rank_labels():
    """REPORT-2 §5: every water-adjusted label checked against the ranks table, independently.

    The label vocabulary is re-implemented here from the spec rather than imported from the
    builder, so this is a second path to the same wording and not a restatement of the first.
    Rank and count come from REPORT2_part_ranks.csv, never from the unit record.

    Two failure modes this is aimed at. A silent DIRECTION FLIP — rank 1 means largest shortfall
    on both columns, and a flip would be the hardest error in this batch to catch downstream,
    because every label would still read as valid English. And a MISSING rank: the builder's
    if-chain is exhaustive only for a finite rank, so before its guard existed an absent value
    fell through to "among the highest", the most favourable wording available. Bala 29ca's
    Aeolian third — rank 1 of 17, the worst of its community — rendered exactly that way."""
    csv = os.path.join(TABLES, 'REPORT2_part_ranks.csv')
    if not os.path.exists(csv):
        add('ERROR', 'REPORT-2', 'batch', f'{os.path.basename(csv)} not found — '
            'the labels cannot be checked against anything')
        return
    d = pd.read_csv(csv)
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        if len(r['parts']) < 2:
            continue                      # single-part paddocks carry no parts table
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        t = visible(p)
        rows = d[d.paddock_name == r['unit']]
        if len(rows) != len(r['parts']):
            add('ERROR', 'REPORT-2', r['unit'],
                f'{len(r["parts"])} parts in the report, {len(rows)} in the ranks table')
            continue
        for _, x in rows.iterrows():
            want = water_label(int(x.rank_water), int(x.n_of))
            if want not in t:
                add('ERROR', 'REPORT-2', r['unit'],
                    f'{x.community_short} should read "{want}" '
                    f'(rank {int(x.rank_water)} of {int(x.n_of)}) and does not')
            # The two columns are different quantities and must not be conflated: where the
            # ranks differ, the cover label must NOT also be the water label.
            if int(x.rank_water) != int(x.rank_floor) and want == water_label(
                    int(x.rank_floor), int(x.n_of)):
                add('WARN', 'REPORT-2', r['unit'],
                    f'{x.community_short} ranks {int(x.rank_floor)} on cover and '
                    f'{int(x.rank_water)} for its water, but both land on the same wording')


def check_gap_prose_matches_caption():
    """R-17: page 4's gap prose and page 4's gap caption must not contradict each other.

    R-16 settled direction and draw/omit once and rewrote the CAPTION to read them; gapText, the
    prose directly above it, was missed and still keyed on a registered slope only Bala 29ca has.
    Five of the seven shipped reports asserted "has neither closed nor widened its gap" above a
    caption reading "the difference widened (-0.176, correlation -0.35)".

    The test is agreement on whether there is a change at all, not on wording — the two are
    written in different registers on purpose, and pinning the phrasing here would make this
    check fire on any future rewording rather than on a disagreement."""
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        if 'gap_direction' not in r:
            continue
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        t = visible(p)
        prose = re.search(r'Measured year by year[^‖]*', t)
        capt = re.search(r'One point per water year[^‖]*', t)
        if not prose or not capt:
            add('ERROR', 'R-17', r['unit'], 'the gap prose or its caption is missing')
            continue
        prose_change = 'neither closed nor widened' not in prose.group(0)
        capt_change = ('the difference narrowed' in capt.group(0)
                       or 'the difference widened' in capt.group(0))
        if prose_change != capt_change:
            add('ERROR', 'R-17', r['unit'],
                f'page 4 prose says the gap {"changed" if prose_change else "did not change"} '
                f'but its own caption says it {"changed" if capt_change else "did not"}')
        # The record's own direction is the arbiter of which way, where a change is claimed.
        if prose_change and r['gap_direction'] in ('closing', 'widening'):
            want = 'closed' if r['gap_direction'] == 'closing' else 'widened'
            if f'has {want} ' not in prose.group(0):
                add('ERROR', 'R-17', r['unit'],
                    f'gap is {r["gap_direction"]} but the prose does not say it {want}')


def check_at_expectation_claim():
    """R-17: page 1 must not tell a paddock it carries about what its water predicts unless it does.

    plainTerms' default said exactly that without consulting the residual, so it reached any
    paddock whose parts were neither Recovering nor uniformly Declining. Bala 15's residual is
    -17.62 — the largest shortfall on the property — and its page 1 carried the claim."""
    CLAIM = 'carries about the cover its water would predict'
    for f in sorted(glob.glob(os.path.join(UNITS_DIR, 'paddock_*.json'))):
        r = json.load(open(f, encoding='utf8'))
        if r.get('residual') is None or not r.get('fit'):
            continue
        slug = r['unit'].replace(' ', '_').replace('/', '-')
        p = os.path.join(DOCS_DIR, f'Gayini_paddock_report_{slug}.docx')
        if not os.path.exists(p):
            continue
        sd = r['fit']['resid_sd']
        if CLAIM in visible(p) and abs(r['residual']) > sd:
            add('ERROR', 'R-17', r['unit'],
                f'page 1 claims the paddock carries about what its water predicts, but its '
                f'residual is {r["residual"]:+.2f} against a residual SD of {sd:.2f}')


def main():
    for fn in (check_band_areas, check_property_is_a_set,
               check_support_separation, check_site_counts, check_composition_prose,
               check_parts_verdict, check_gap_caption, check_water_rank_labels,
               check_gap_prose_matches_caption, check_at_expectation_claim):
        fn()
    err = [f for f in findings if f[0] == 'ERROR']
    print()
    for level, check, where, msg in findings:
        print(f'  {level:5s} [{check:9s}] {where:30s} {msg}')
    print(f'\n{len(err)} error · {len(findings) - len(err)} warn')
    if not findings:
        print('  clean — band areas reconcile, "the property" is a set, supports stay separated')
    sys.exit(1 if err else 0)


if __name__ == '__main__':
    main()
