"""Prove check_page_fill.py's ERROR branch fires, and that dead space does not fail a build.

Under R-1 this is the ONLY check in the module that can fail a build, so it is the one that
most needs proving. It has never fired on real output: no page of either build exceeds 92%.
A threshold that has only ever been under-run is not a threshold, it is a constant.

Two assertions, because R-1 has two halves:
  1. an over-full page (>92%) EXITS 1  — the functional failure must fail the build
  2. a real report with dead space      EXITS 0  — whitespace must NOT fail the build

Run:  python tests/test_page_fill_fires.py     (from scripts/15_reports)
"""
import glob, os, shutil, subprocess, sys, tempfile

if not (shutil.which('node') or shutil.which('node.exe')):
    sys.exit('STOP: node not on PATH. The over-full fixture is built by the real docx package; '
             'without node this test cannot run, and a test that cannot run must not look like '
             'one that passed. Install Node or add it to PATH.')

HERE = os.path.dirname(os.path.abspath(__file__))
MOD  = os.path.dirname(HERE)
sys.path.insert(0, MOD)
from config import DOCS_DIR                                     # noqa: E402


def run_check(paths):
    r = subprocess.run([sys.executable, os.path.join(MOD, 'check_page_fill.py'), *paths],
                       cwd=MOD, capture_output=True, text=True, env=dict(os.environ))
    return r.returncode, r.stdout + r.stderr


def main():
    fails = []

    # ---- 1. over-full page must FAIL
    with tempfile.TemporaryDirectory() as tmp:
        g = subprocess.run(['node', os.path.join(HERE, 'make_overfull_docx.js'), tmp],
                           capture_output=True, text=True)
        docx = os.path.join(tmp, 'FIXTURE_overfull.docx')
        if not os.path.exists(docx):
            sys.exit(f'STOP: fixture not generated\n{g.stdout}\n{g.stderr}')
        code, out = run_check([docx])
        pct = [l for l in out.splitlines() if 'FIXTURE_overfull' in l and '%' in l]
        ok = code == 1 and 'may spill in Word' in out
        print(f'  over-full page   -> exit {code}  {"OK  " if ok else "FAIL"}'
              f'   {pct[0].strip() if pct else "(no page line)"}')
        if not ok:
            fails.append('an over-full page did not fail the build — the ERROR branch is dead')

    # ---- 2. dead space must NOT fail
    real = sorted(glob.glob(os.path.join(DOCS_DIR, 'Gayini_paddock_report_*.docx')))
    if not real:
        sys.exit('STOP: no built paddock reports to check — run the batch first')
    code, out = run_check(real)
    n_dead = out.count('dead space') and [l for l in out.splitlines() if 'below' in l]
    ok = code == 0
    print(f'  real reports     -> exit {code}  {"OK  " if ok else "FAIL"}'
          f'   {(n_dead[0].strip() if n_dead else "")}')
    if not ok:
        fails.append('dead space failed the build — R-1 says whitespace is advisory only')

    if fails:
        print('\nFAILED:')
        for f in fails:
            print('   ', f)
        sys.exit(1)
    print('\nspill fails the build · dead space does not · 2 pass · 0 fail')


if __name__ == '__main__':
    main()
