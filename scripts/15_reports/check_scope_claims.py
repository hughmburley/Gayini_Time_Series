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
from config import DOCS_DIR, UNITS_DIR
from docxset import built_docx

TOL_HA = 0.05          # band areas are printed to 0 dp; reconcile the underlying values
findings = []


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


def main():
    for fn in (check_band_areas, check_property_is_a_set,
               check_support_separation, check_site_counts, check_composition_prose,
               check_parts_verdict, check_gap_caption):
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
