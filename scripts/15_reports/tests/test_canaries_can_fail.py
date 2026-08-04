"""Prove the four contract canaries can FAIL.

They have only ever passed. Passing is not the same as being able to fail — a canary that
has never been made to fire is the same object as a check nobody has tested.

Ruling J governs the fixture: a check that ERRORS is not a check that CATCHES. Breaking the
schema so the recompute raises would prove only that the code path is reachable. Drift
detection needs a fixture that returns a WRONG VALUE the check must reject. So this mutates
DATA, not structure: `fact_zone_veg_annual.veg_p05_spatial` is scaled for one zone, which
moves the page-1 paddock floor while every query still runs and every column still exists.

THE LIVE DATABASE IS NEVER TOUCHED. The fixture is a copy in a temp directory, and
report_data.py is pointed at it with GAYINI_ROOT. This session is read-only on the real DB.

Run:  python tests/test_canaries_can_fail.py     (from scripts/15_reports)
"""
import os, shutil, sqlite3, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MOD  = os.path.dirname(HERE)
sys.path.insert(0, MOD)
from config import DB                                          # noqa: E402

ZONE  = 'Bala 29ca'
SCALE = 1.05          # small enough to be plausible drift, far outside the 0.011 tolerance


def run_data_layer(root):
    env = dict(os.environ, GAYINI_ROOT=root)
    r = subprocess.run([sys.executable, 'report_data.py', '--paddocks', ZONE],
                       cwd=MOD, env=env, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def build_fixture(root, mutate):
    dst = os.path.join(root, 'Output', 'database')
    os.makedirs(dst, exist_ok=True)
    db = os.path.join(dst, os.path.basename(DB))
    shutil.copy(DB, db)
    if not mutate:
        return db
    con = sqlite3.connect(db)                    # the COPY, opened writable — never the original
    fid = con.execute('select zone_fid from dim_management_zone where zone_name=?',
                      (ZONE,)).fetchone()[0]
    n = con.execute('update fact_zone_veg_annual set veg_p05_spatial = veg_p05_spatial * ? '
                    'where zone_fid=? and series_variant=\'mean_of_seasons\'',
                    (SCALE, fid)).rowcount
    con.commit(); con.close()
    print(f'    fixture: scaled veg_p05_spatial by {SCALE} on {n} rows for {ZONE}')
    return db


def main():
    assert os.path.exists(DB), f'live DB not found at {DB}'
    before = os.path.getmtime(DB), os.path.getsize(DB)
    fails = []

    print('  control — unmutated copy:')
    with tempfile.TemporaryDirectory() as root:
        build_fixture(root, mutate=False)
        code, out = run_data_layer(root)
        ok = code == 0 and 'canary OK' in out
        print(f'    exit {code}  {"OK  " if ok else "FAIL"}  (canaries should pass)')
        if not ok:
            fails.append(f'control run failed; the fixture harness is wrong:\n{out[-800:]}')

    print('  drift — veg_p05_spatial scaled:')
    with tempfile.TemporaryDirectory() as root:
        build_fixture(root, mutate=True)
        code, out = run_data_layer(root)
        line = next((l for l in out.splitlines() if 'CANARY FAIL' in l), '')
        ok = code != 0 and 'CANARY FAIL' in out
        print(f'    exit {code}  {"OK  " if ok else "FAIL"}  {line.strip()[:150]}')
        if not ok:
            fails.append(f'a wrong value did NOT trip a canary — drift would ship:\n{out[-800:]}')

    after = os.path.getmtime(DB), os.path.getsize(DB)
    if before != after:
        fails.append('THE LIVE DATABASE CHANGED — this test must never write to it')
    else:
        print(f'  live DB untouched (mtime and size unchanged)')

    if fails:
        print('\nFAILED:')
        for f in fails:
            print('   ', f)
        sys.exit(1)
    print('\na wrong value trips the canary · the live DB is untouched · 2 pass · 0 fail')


if __name__ == '__main__':
    main()
