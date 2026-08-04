"""Prove check_scope_claims.py fires — it has only ever returned clean.

§8.4's two claims now pass under an independent re-run, which is the right outcome and also the
least informative one: a checker that has only ever agreed with the thing it checks has not been
shown to disagree with anything. This injects each defect class into a copy of the real batch and
asserts the checker rejects it.

Three injections, one per class:
  1. FOOTPRINT  "the property" given an area
  2. FOOTPRINT  a band area that no longer sums to the stated in-scope area
  3. C10        a document missing the two-flood-rules sentence

Nothing under Output/ is modified: the fixture is a temp GAYINI_ROOT holding doctored copies.

Run:  python tests/test_scope_claims_fire.py     (from scripts/15_reports)
"""
import glob, json, os, re, shutil, subprocess, sys, tempfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD  = os.path.dirname(HERE)
sys.path.insert(0, MOD)
from config import DOCS_DIR, UNITS_DIR                          # noqa: E402


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
    for f in glob.glob(os.path.join(DOCS_DIR, '*.docx')):
        shutil.copy(f, docs)

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
