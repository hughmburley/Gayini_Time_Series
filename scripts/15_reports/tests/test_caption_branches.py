"""Prove the locator caption's site-marker branch can fire — both ways.

Why this exists. Before v1.3 the caption read a `{slug}_maploc.flags` sidecar that
report_figs.py never wrote, so `drawn` was permanently false and the true branch was
unreachable. The July bug (a caption promising markers a figure had suppressed) was
fixed by making the branch impossible rather than by wiring it to the record. That
inverts the fault: a locator that DOES draw markers gets captioned as not drawing them.

A branch that cannot be made to fire is not a branch. This test drives the real
report_build.js over a fixture and asserts BOTH captions appear, so neither branch can
rot unnoticed.

Run:  python tests/test_caption_branches.py        (from scripts/15_reports)
Exits non-zero on failure.
"""
import json, os, re, shutil, subprocess, sys, tempfile, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD  = os.path.dirname(HERE)
sys.path.insert(0, MOD)
from config import UNITS_DIR, FIGS_DIR                      # noqa: E402

DONOR = 'Bala 26ca'          # real paddock: 3 sites, so n_sites > 0 in both branches
G     = DONOR.replace(' ', '_').replace('/', '-')

TRUE_TEXT  = 'White squares are the monitoring sites reported here.'
FALSE_TEXT = 'they are not drawn here because the stored paddock outline is too simplified'


def visible_text(docx_path):
    x = zipfile.ZipFile(docx_path).read('word/document.xml')
    return re.sub(rb'\s+', b' ', re.sub(rb'<[^>]+>', b' ', x)).decode('utf8', 'replace')


def build_with(sites_drawn, root):
    """Assemble a fixture repo root, force the locator branch, run the real builder."""
    units = os.path.join(root, 'Output', 'reports', '_units')
    figs  = os.path.join(root, 'Output', 'figures', 'reports')
    docs  = os.path.join(root, 'Output', 'reports')
    for d in (units, figs):
        os.makedirs(d, exist_ok=True)

    src_unit = os.path.join(UNITS_DIR, f'paddock_{G}.json')
    if not os.path.exists(src_unit):
        sys.exit(f'STOP: fixture donor missing — run report_data.py first ({src_unit})')
    shutil.copy(src_unit, os.path.join(units, f'paddock_{G}.json'))

    # Copy the donor's figures, then force the locator path: the builder prefers
    # mapc1, so it must be absent and maploc must exist.
    for f in os.listdir(FIGS_DIR):
        if f.startswith(G + '_') and f.endswith('.png'):
            shutil.copy(os.path.join(FIGS_DIR, f), os.path.join(figs, f))
    mapc1 = os.path.join(figs, f'{G}_mapc1.png')
    maploc = os.path.join(figs, f'{G}_maploc.png')
    if os.path.exists(mapc1):
        shutil.move(mapc1, maploc)
    if not os.path.exists(maploc):
        sys.exit('STOP: fixture has no map figure to rename')

    json.dump({G: {'map_kind': 'locator', 'sites_drawn': sites_drawn,
                   'neighbours_drawn': 0, 'sites_expected': 3}},
              open(os.path.join(figs, 'figs_meta.json'), 'w'), indent=1)

    env = dict(os.environ, GAYINI_ROOT=root)
    r = subprocess.run(['node', 'report_build.js'], cwd=MOD, env=env,
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f'STOP: builder failed for sites_drawn={sites_drawn}\n{r.stdout}\n{r.stderr}')
    out = os.path.join(docs, f'Gayini_paddock_report_{G}.docx')
    if not os.path.exists(out):
        sys.exit(f'STOP: builder produced no document at {out}')
    return visible_text(out)


def main():
    fails = []
    for drawn, must, must_not in ((True,  TRUE_TEXT,  FALSE_TEXT),
                                  (False, FALSE_TEXT, TRUE_TEXT)):
        with tempfile.TemporaryDirectory() as root:
            txt = build_with(drawn, root)
        got_must     = must in txt
        got_must_not = must_not in txt
        ok = got_must and not got_must_not
        print(f'  sites_drawn={str(drawn):5s} -> '
              f'{"OK  " if ok else "FAIL"}  present={got_must}  contaminated={got_must_not}')
        if not ok:
            fails.append(f'sites_drawn={drawn}: expected {must!r}, present={got_must}, '
                         f'opposite-branch text present={got_must_not}')

    if fails:
        print('\nFAILED — the caption branch is not wired to figs_meta.json:')
        for f in fails:
            print('   ', f)
        sys.exit(1)
    print('\nboth caption branches fire · 2 pass · 0 fail')


if __name__ == '__main__':
    main()
