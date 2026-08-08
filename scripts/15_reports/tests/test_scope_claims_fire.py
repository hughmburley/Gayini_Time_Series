"""Prove check_scope_claims.py fires — it has only ever returned clean.

§8.4's two claims now pass under an independent re-run, which is the right outcome and also the
least informative one: a checker that has only ever agreed with the thing it checks has not been
shown to disagree with anything. This injects each defect class into a copy of the real batch and
asserts the checker rejects it.

One injection per defect class — see CASES at the foot of the file for the current list. Each
is a WRONG VALUE the checker must reject, not merely an input that makes it crash: a fixture
that only breaks the code path proves reachability, not detection (Ruling J).

Nothing under Output/ is modified: the fixture is a temp GAYINI_ROOT holding doctored copies.

Run:  python tests/test_scope_claims_fire.py     (from scripts/15_reports)
"""
import glob, json, os, re, shutil, subprocess, sys, tempfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD  = os.path.dirname(HERE)
sys.path.insert(0, MOD)
from config import DOCS_DIR, UNITS_DIR, TABLES                  # noqa: E402
from docxset import built_docx                                  # noqa: E402


def doctor_docx(src, dst, old, new):
    """Rewrite one visible string inside word/document.xml."""
    zin = zipfile.ZipFile(src)
    hit = False
    with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                s = data.decode('utf8')
                if old in s:
                    s, hit = s.replace(old, new, 1), True
                data = s.encode('utf8')
            zout.writestr(item, data)
    return hit


def build_fixture(root, mode):
    docs = os.path.join(root, 'Output', 'reports')
    units = os.path.join(docs, '_units')
    os.makedirs(units, exist_ok=True)
    for f in glob.glob(os.path.join(UNITS_DIR, '*.json')):
        shutil.copy(f, units)
    for f in built_docx(DOCS_DIR):
        shutil.copy(f, docs)
    # REPORT-2's ranks table resolves from GAYINI_ROOT too, so the fixture needs its own copy
    # or the unmutated case fails on a missing file rather than passing clean.
    tables = os.path.join(root, 'Output', 'tables')
    os.makedirs(tables, exist_ok=True)
    ranks = os.path.join(TABLES, 'REPORT2_part_ranks.csv')
    if os.path.exists(ranks):
        shutil.copy(ranks, tables)

    target = os.path.join(docs, 'Gayini_paddock_report_Bala_28ca.docx')
    if mode == 'property_area':
        tmp = target + '.tmp'
        if not doctor_docx(target, tmp, 'In plain terms',
                           'The property covers 67,349 ha'):
            sys.exit('STOP: injection anchor not found in the fixture document')
        os.replace(tmp, target)
    elif mode == 'band_area':
        p = os.path.join(units, 'paddock_Bala_28ca.json')
        r = json.load(open(p, encoding='utf8'))
        r['bands'][0]['ha'] = r['bands'][0]['ha'] + 40.0      # plausible, not absurd
        json.dump(r, open(p, 'w', encoding='utf8'), indent=1)
    elif mode == 'r8_count':
        # page 1 claims a kind of country that page 3 does not show — the pre-R-8 defect
        tmp = target + '.tmp'
        if not doctor_docx(target, tmp, 'spans two kinds of country',
                           'spans three kinds of country'):
            sys.exit('STOP: R-8 count anchor not found in the fixture document')
        os.replace(tmp, target)
    elif mode == 'r8_zero_pct':
        tmp = target + '.tmp'
        if not doctor_docx(target, tmp, '17% Riverine', '17% Riverine and 0% Aeolian'):
            sys.exit('STOP: R-8 zero-percent anchor not found in the fixture document')
        os.replace(tmp, target)
    elif mode == 'r15_parts_verdict':
        # the PRE-FIX Dinan 10 sentence, verbatim: recovery attributed to the bare parts,
        # a singular subject with a plural verb, and no area
        t2 = os.path.join(docs, 'Gayini_paddock_report_Dinan_10.docx')
        tmp = t2 + '.tmp'
        if not doctor_docx(t2, tmp,
                'anywhere on the property, and neither is coming back. Riverine is coming back, '
                'but that is 59 ha — 7% of the paddock — and the whole-paddock figure '
                'does not move with it. ',
                'anywhere on the property — and one of them are coming back. '):
            sys.exit('STOP: R-15 anchor not found in the fixture document')
        os.replace(tmp, t2)
    elif mode == 'r16_gap_pattern':
        # the pre-R-16 assertion: a closing gap claimed on a paddock whose gap does not move.
        # Bala 26ca has slope -0.003, r -0.01 - no trend line is drawn for it at all.
        t2 = os.path.join(docs, 'Gayini_paddock_report_Bala_26ca.docx')
        tmp = t2 + '.tmp'
        if not doctor_docx(t2, tmp,
                'Year-to-year movement is larger than any trend running through it',
                'Across the record the difference narrowed'):
            sys.exit('STOP: R-16 anchor not found in the fixture document')
        os.replace(tmp, t2)
    elif mode == 'report2_direction_flip':
        # REPORT-2 §2: rank 1 = largest shortfall on BOTH columns. A silent direction flip is
        # the hardest error here to catch downstream, because every label still reads as valid
        # English — "among the highest of 61 for its water" on the part that is the worst.
        # Reverse the water rank in the ranks table and the built labels must stop matching.
        import csv as _csv
        p = os.path.join(tables, 'REPORT2_part_ranks.csv')
        rows = list(_csv.DictReader(open(p, encoding='utf8')))
        for x in rows:
            x['rank_water'] = str(int(x['n_of']) + 1 - int(x['rank_water']))
        with open(p, 'w', encoding='utf8', newline='') as fh:
            w = _csv.DictWriter(fh, fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
    elif mode == 'report2_missing_rank':
        # The pre-guard builder fell through to "among the highest" for a part with no rank.
        # Bala 29ca's Aeolian third is rank 1 of 17 — the WORST of its community — and rendered
        # exactly that way. Inject that sentence back and the check must reject it.
        t2 = os.path.join(docs, 'Gayini_paddock_report_Bala_29ca.docx')
        tmp = t2 + '.tmp'
        if not doctor_docx(t2, tmp, 'lowest of 17 for its water',
                           'among the highest of 17 for its water'):
            sys.exit('STOP: REPORT-2 missing-rank anchor not found in the fixture document')
        os.replace(tmp, t2)
    elif mode == 'r17_gap_prose':
        # the PRE-R-17 sentence: page-4 prose asserting no change above a caption stating a
        # widening of -0.176 pp a year. Five of seven shipped reports read this way.
        # Anchored inside ONE run: the slope is bold and therefore a run of its own, so a
        # phrase spanning it cannot be matched in document.xml at all.
        t2 = os.path.join(docs, 'Gayini_paddock_report_Bala_27ca.docx')
        tmp = t2 + '.tmp'
        if not doctor_docx(t2, tmp, ' has widened its gap, at ',
                ' has neither closed nor widened its gap to any degree the record can '
                'distinguish, at '):
            sys.exit('STOP: R-17 gap-prose anchor not found in the fixture document')
        os.replace(tmp, t2)
    elif mode == 'r17_at_expectation':
        # plainTerms' pre-fix default on Bala 15, whose residual is -17.62 - the largest
        # shortfall on the property - telling its reader the paddock is at expectation.
        t2 = os.path.join(docs, 'Gayini_paddock_report_Bala_15.docx')
        tmp = t2 + '.tmp'
        if not doctor_docx(t2, tmp,
                'carries less cover than comparable country once its water is allowed for',
                'carries about the cover its water would predict'):
            sys.exit('STOP: R-17 at-expectation anchor not found in the fixture document')
        os.replace(tmp, t2)
    elif mode == 'two_rules':
        tmp = target + '.tmp'
        # the sentence the spec requires in every report
        if not doctor_docx(target, tmp, 'will not match', 'will agree'):
            sys.exit('STOP: two-rules anchor not found in the fixture document')
        os.replace(tmp, target)
    return root


def run(root):
    env = dict(os.environ, GAYINI_ROOT=root)
    r = subprocess.run([sys.executable, 'check_scope_claims.py'], cwd=MOD, env=env,
                       capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


CASES = [
    ('none',           0, None,          'unmutated copy must pass'),
    ('property_area',  1, 'footprint',   '"the property" given an area must be rejected'),
    ('band_area',      1, 'footprint',   'band areas that do not sum must be rejected'),
    ('two_rules',      1, 'C10',         'a missing two-flood-rules sentence must be rejected'),
    ('r8_count',       1, 'R-8',         'page 1 claiming more kinds than page 3 shows must be rejected'),
    ('r8_zero_pct',    1, 'R-8',         'a community printed at 0% must be rejected'),
    ('r15_parts_verdict', 1, 'R-15',     'recovery attributed to parts that are not recovering must be rejected'),
    ('r16_gap_pattern', 1, 'R-16',       'a closing gap asserted where the gap does not move must be rejected'),
    ('report2_direction_flip', 1, 'REPORT-2', 'a reversed water rank must be rejected'),
    ('report2_missing_rank', 1, 'REPORT-2',   'the pre-guard "among the highest" label on the worst part must be rejected'),
    ('r17_gap_prose',    1, 'R-17',      'page-4 prose contradicting its own caption must be rejected'),
    ('r17_at_expectation', 1, 'R-17',    'an at-expectation claim on a paddock beyond one residual SD must be rejected'),
]


def main():
    fails = []
    for mode, want_code, want_tag, why in CASES:
        with tempfile.TemporaryDirectory() as root:
            build_fixture(root, mode)
            code, out = run(root)
        tag_ok = want_tag is None or f'[{want_tag}' in out
        ok = code == want_code and tag_ok
        line = next((l for l in out.splitlines() if 'ERROR' in l), '').strip()
        print(f'  {mode:15s} exit {code}  {"OK  " if ok else "FAIL"}  {line[:110]}')
        if not ok:
            fails.append(f'{mode}: expected exit {want_code} and [{want_tag}] — {why}')

    if fails:
        print('\nFAILED:')
        for f in fails:
            print('   ', f)
        sys.exit(1)
    print(f'\nall {len(CASES)} scope-claim cases behave correctly · 0 fail')


if __name__ == '__main__':
    main()
